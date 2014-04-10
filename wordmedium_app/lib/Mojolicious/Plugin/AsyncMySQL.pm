package Mojolicious::Plugin::AsyncMySQL;
use Mojo::Base 'Mojolicious::Plugin';

use Carp;
use DBI;
use AnyEvent;

our $VERSION = '0.1';

my $CONNECTION_LIFETIME = 120; # the max time to reuse the connection (sec)

my $DEBUG = 1;
my $INSTANCE_NUM = 0;

sub register {
    my $plugin = shift;
    my $app  = shift;
    my $attr = shift;
    
    croak __PACKAGE__, ": missing input parameter (must be a hash reference)"
        unless ref($attr) eq 'HASH';
    croak __PACKAGE__, ": missing helper name"
        unless exists $attr->{helper} && length($attr->{helper}) > 0;
    croak __PACKAGE__, ": wrong database config (must be a hash reference)"
        unless exists $attr->{db} && ref($attr->{db}) eq 'HASH';
    
    my $server = sub { __PACKAGE__->ini($attr->{db}) };
    my $attr_name = '_asyncmysql_' . $attr->{helper};
    $app->attr($attr_name => $server);
    $app->helper($attr->{helper} => sub { return shift->app->$attr_name });
}

sub ini {
    my $class = shift;
    my ($dsn, $login, $pass, $attr) = @_;
    
    my $dbh = DBI->connect($dsn, $login, $pass, $attr) ||
        croak __PACKAGE__, ": can't connect to database $dsn";
        
    my $handler = Mojolicious::Plugin::AsyncMySQL::Handler->new($dbh);
    $handler->cached();
    
    my $self = {
        dsn   => $dsn,
        login => $login,
        pass  => $pass,
        attr  => $attr,
        cache => [$handler]
    };
    bless $self, $class;
}

sub lifetime {
    my $self = shift;
    my $t = shift;
    
    $CONNECTION_LIFETIME = $t if defined $t;
    return $CONNECTION_LIFETIME;
}

sub prepare {
    my ($self, $sql, $attr) = @_;
    
    $attr //= {};
    $attr->{async} //= 1;
    my $handler = $self->get_handler($self);
    $handler->set_h($handler->{dbh}->prepare($sql, $attr));
    return $handler;
}

sub do {
    my ($self, $statement, @args) = @_;
    
    my $cb = pop @args;
    croak __PACKAGE__, ": missing callback function for `do` method"
        unless $cb && ref($cb) eq 'CODE';
    
    (my $attr = shift @args) //= {};
    $attr->{async} //= 1;
    my $handler = $self->get_handler($self);
    $handler->set_h;
    $handler->set_cb($cb);
    $handler->{dbh}->do($statement, $attr, @args);
}

sub get_handler {
    my $self = shift;
    
    my $handler = pop @{$self->{cache}};
    if(!$handler || time - $handler->myclock > $CONNECTION_LIFETIME) {
        my $dbh = DBI->connect(@$self{qw{dsn login pass attr}}) ||
            croak __PACKAGE__, ": can't connect to database $self->{dsn}";
        $handler = Mojolicious::Plugin::AsyncMySQL::Handler->new($dbh);
    }
    $handler->uncached($self->{cache});
    
    if(@{$self->{cache}}) {
        my $last_in_cache = @{$self->{cache}}[-1];
        if(time - $last_in_cache->myclock > $CONNECTION_LIFETIME) {
            $self->{cache} = []; # if the youngest cached handler is out of date then all cached handlers are out of date
        }
    }
    return $handler;
}

1;
################################################

package Mojolicious::Plugin::AsyncMySQL::Handler;

use strict;
use warnings;

use Carp;

sub new {
    my $class = shift;
    
    my $self = {
        dbh => shift,
        h => undef,
        cb  => undef,
        clock => time,
        cache => undef,
        io => undef,
        i => $DEBUG ? ++$INSTANCE_NUM : undef
    };
    
    croak __PACKAGE__, ": missing or wrong database handler (must be `DBI::db`)"
        unless $self->{dbh} && ref($self->{dbh}) eq 'DBI::db';
    
    bless $self, $class;
}

sub execute {
    my ($self, @args) = @_;
    
    croak __PACKAGE__, ": repeated calling an asynchronous function"
        if $self->{cb};
    croak __PACKAGE__, ": missing callback function for `execute` method"
        unless ($self->{cb} = pop @args) && ref($self->{cb}) eq 'CODE';
        
    $self->{h}->execute(@args);
}

sub set_h {
    my $self = shift;
    my $h = shift;
    if($h){
        $self->{h} = $h;
    } else {
        $self->{h} = $self->{dbh};
    }
}

sub set_cb {
    my $self = shift;
    croak __PACKAGE__, ": repeated calling an asynchronous function"
        if $self->{cb}; 
    $self->{cb} = shift;
}

sub cached {
    my $self = shift;
    $self->{cache} = undef;
    $self->{io} = undef;
}

sub uncached {
    my $self = shift;
    $self->{cache} = shift;
    
    $self->{io} = AnyEvent->io(
        fh      => $self->{dbh}->mysql_fd,
        poll    => 'r',
        cb      => sub {
            my $cb = $self->{cb};
            my $h = $self->{h};
            $self->{cb} = undef;
            $self->{h} = undef;
            if ($cb && $h) {
                eval { $cb->($h->mysql_async_result, $h) };
                carp __PACKAGE__, ": callback error" if $@;
            } else {
                carp __PACKAGE__, ": missing callback function or database handler";
            }
            $self->{io} = undef;
        }
    );
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
    $self->{h} = undef;
    $self->{io} = undef;
    if($self->{cache}) { # object in use - must be returned in the cache
        my $cache = $self->{cache};
        $self->cached;
        $self->myclock(time);
        push @$cache, $self;
        carp  "$self->{i} pushed in cache" if $DEBUG;
    } else {             # object in a cache - must be destroyed if the cache is flushed
        $self->{dbh} = undef;
        carp  "$self->{i} destroyed" if $DEBUG;
    }
    return;
}

1;

__END__

