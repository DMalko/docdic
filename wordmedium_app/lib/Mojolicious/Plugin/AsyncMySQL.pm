package Mojolicious::Plugin::AsyncMySQL;
use Mojo::Base 'Mojolicious::Plugin';

use Carp;
use DBI;
use AnyEvent;
use Digest::MD5 qw( md5_hex );

our $VERSION = '0.2';

my $CONNECTION_LIFETIME = 120; # the max time to reuse the connection (sec)

my $DEBUG = 1;
my $INSTANCE_NUM = 0;

sub register {
    my $plugin = shift;
    my $app = shift;
    my $attr = shift;
    
    croak __PACKAGE__, ": missing input parameter (must be a hash reference)"
        unless ref($attr) eq 'HASH';
    croak __PACKAGE__, ": missing helper name"
        unless exists $attr->{helper} && length($attr->{helper}) > 0;
    croak __PACKAGE__, ": wrong database config (must be a hash reference)"
        unless exists $attr->{db} && ref($attr->{db}) eq 'HASH';
    
    my $server = sub { __PACKAGE__->connect($attr->{db}) };
    my $attr_name = '_asyncmysql_' . $attr->{helper};
    $app->attr($attr_name => $server);
    $app->helper($attr->{helper} => sub { return shift->app->$attr_name });
}

sub connect {
    my $class = shift;
    my ($dsn, $login, $pass, $attr) = @_;
    
    my $dbh = DBI->connect($dsn, $login, $pass, $attr) ||
        croak __PACKAGE__, ": can't connect to database $dsn";
        
    my $handler = Mojolicious::Plugin::AsyncMySQL::Handler->new($dbh);
    
    my $self = {
        dsn          => $dsn,
        login        => $login,
        pass         => $pass,
        attr         => $attr,
        stack        => [$handler],
        stack_cached => {}
    };
    bless $self, $class;
}

sub lifetime {
    my $self = shift;
    my $t = shift;
    
    $CONNECTION_LIFETIME = $t if defined $t;
    return $CONNECTION_LIFETIME;
}

###
# $dbh->do({
#    sql  => $sql,
#    val  => [],
#    attr => $attr,
#    cd   => $cb
# });
#
# $dbh->query({
#    sql => $sql,
#    val => [],
#    attr => $attr,
#    cd  => $cb
# });
#
# $dbh->query_cached({
#    sql => $sql,
#    val => [],
#    attr => $attr,
#    cd  => $cb
# });
###

sub do {
    my $self = shift;
    my $args = shift;
    
    croak __PACKAGE__, ": missing callback function"
        unless exists $args->{cb} && ref($args->{cb}) eq 'CODE';
    
    my $handler = $self->get_handler($args->{cb});
    
    $args->{attr}->{async} = 1;
    $handler->do($args);
}

sub query {
    my $self = shift;
    my $args = shift;
    
    croak __PACKAGE__, ": missing callback function"
        unless exists $args->{cb} && ref($args->{cb}) eq 'CODE';
    
    my $sth_attr;
    if(exists $args->{attr}) {
        if(exists $args->{attr}->{mysql_use_result} || exists $args->{attr}->{mysql_store_result}) { # the attributes of the statement handle
            $sth_attr->{mysql_use_result} = delete $args->{attr}->{mysql_use_result}; 
            $sth_attr->{mysql_store_result} = delete $args->{attr}->{mysql_store_result};
        }
    }
    
    my $handler = $self->get_handler($args->{cb});
    
    $args->{attr}->{async} = 1;
    $handler->prepare($args);
    
    $handler->execute($args->{val}, $sth_attr);
    return 1;
}

sub query_cached {
    my $self = shift;
    my $args = shift;
    
    croak __PACKAGE__, ": missing callback function"
        unless exists $args->{cb} && ref($args->{cb}) eq 'CODE';
    
    my $sth_attr;
    if(exists $args->{attr}) {
        if(exists $args->{attr}->{mysql_use_result} || exists $args->{attr}->{mysql_store_result}) { # the attributes of the statement handle
            $sth_attr->{mysql_use_result} = delete $args->{attr}->{mysql_use_result}; 
            $sth_attr->{mysql_store_result} = delete $args->{attr}->{mysql_store_result};
        }
    }

### TODO: the next statement is slow and should be rewritten
    my $key = exists $args->{attr} ? md5_hex(join('', $args->{sql}, map {$_, $args->{attr}->{$_}} sort(keys %{$args->{attr}}))) : md5_hex($args->{sql});
    
    my $handler = $self->get_handler($args->{cb}, $key);
    
    if(!$handler->is_prepared) {
        $args->{attr}->{async} = 1;
        $handler->prepare($args);
    }
    
    $handler->execute($args->{val}, $sth_attr);
    return 1;
}

sub get_handler {
    my $self = shift;
    my $cb = shift;
    my $key = shift;
    
    my $stack = $key ? $self->{stack_cached}->{$key} : $self->{stack};
    my $handler = pop @{$stack};
    if(!$handler || time - $handler->myclock > $CONNECTION_LIFETIME) {
        my $dbh = DBI->connect(@$self{qw{dsn login pass attr}}) ||
            croak __PACKAGE__, ": can't connect to database $self->{dsn}";
        $handler = Mojolicious::Plugin::AsyncMySQL::Handler->new($dbh, $key);
        
    }
    $handler->catch($stack, $cb);
    
    if(@$stack) {
        my $last_in_cache = @{$stack}[-1];
        if(time - $last_in_cache->myclock > $CONNECTION_LIFETIME) {
            # if the youngest cached handler is out of date then all cached handlers are out of date
            if($key) {
                $self->{stack_cached}->{$key} = [];
            } else {
                $self->{stack} = [];
            }
        }
    }
    return $handler;
}


#################################################

package Mojolicious::Plugin::AsyncMySQL::Handler;

use strict;
use warnings;

use Carp;
use Scalar::Util qw( weaken );

sub new {
    my $class = shift;
    
    my $self = {
        dbh       => shift, # dbh
        h       => undef,
        cb        => undef,
        clock     => time,
        stack_ref => undef,
        key       => shift, # cache key (only for cached sth)
        io        => undef,
        i         => $DEBUG ? ++$INSTANCE_NUM : undef
    };
    
    croak __PACKAGE__, ": missing or wrong database handler (must be `DBI::db`)"
        unless $self->{dbh} && ref($self->{dbh}) eq 'DBI::db';
    
    $self->{io} = AnyEvent->io(
        fh => $self->{dbh}->mysql_fd,
        poll => 'r',
        cb => sub {
            if ($self->{cb} && $self->{h}) {
                eval { $self->{cb}->($self->{h}->mysql_async_result, $self->{h}) };
                carp __PACKAGE__, ": callback error" if $@;
            } else {
                carp __PACKAGE__, ": missing callback function or database handler";
            }
            $self->DESTROY;
        }
    );
    
    bless $self, $class;
}

sub do {
    my ($self, $args) = @_;
    $self->{h} = $self->{dbh};
    $self->{h}->do($args->{sql}, $args->{attr}, @{$args->{val}});
}

sub prepare {
    my ($self, $args) = @_;
    $self->{h} = $self->{dbh}->prepare($args->{sql}, $args->{attr});
}

sub execute {
    my ($self, $args, $attr) = @_;
    if($attr) {
        $self->{h}->{mysql_use_result} = $attr->{mysql_use_result} if exists $attr->{mysql_use_result};
        $self->{h}->{mysql_store_result} = $attr->{mysql_store_result} if exists $attr->{mysql_store_result};
    }
    $self->{h}->execute(@$args);
}

sub is_prepared {
    shift->{h} ? 1 : 0;
}

sub catch {
    my $self = shift;
    $self->{stack_ref} = shift;
    $self->{cb} = shift;
    return 1;
}

sub myclock {
    my $self = shift;
    my $clock = shift;
    $self->{clock} = $clock if $clock;
    return $self->{clock};
}

sub DESTROY {
    my $self = shift;
    
    $self->{cb} = undef;
    #$self->{io} = undef;
    my $io = $self->{io};
    if($self->{stack_ref}) { # object in use - must be returned in the stack
        my $stack = $self->{stack_ref};
        $self->{stack_ref} = undef;
        $self->myclock(time);
        $self->{h} = undef unless $self->{key};
        push @$stack, $self;
        carp "$self->{i} pushed in cache" if $DEBUG;
    } else { # object in the stack - must be destroyed if the stack is flushed
        $self->{dbh} = undef;
        $self->{h} = undef;
        carp "$self->{i} destroyed" if $DEBUG;
    }
    return;
}

#################################################

package Mojolicious::Plugin::AsyncMySQL::Container;

use strict;
use warnings;

use Carp;
use Scalar::Util qw( weaken );

sub new {
    my $class = shift;
    
    my $self = {
        clock   => time,
        handler => shift
    };
    
    bless $self, $class;
}

1;

__END__

