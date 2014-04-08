package Mojolicious::Plugin::AsyncMySQL;
use Mojo::Base 'Mojolicious::Plugin';
use Carp;
use AnyEvent;
use DBI;
use Scalar::Util qw( weaken );

our $VERSION = '0.1';

my $TRUST_PERIOD = 60;

sub register {
    my $plugin = shift;
    my $app  = shift;
    my $attr = shift;
    
    croak __PACKAGE__, ": missing input parameter (must be a hash reference)\n"
        unless ref($attr) eq 'HASH';
    croak __PACKAGE__, ": missing helper name\n"
        unless exists $attr->{helper} && length($attr->{helper}) > 0;
    croak __PACKAGE__, ": wrong database config (must be a hash reference)\n"
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
        croak __PACKAGE__, ": can't connect to database $dsn\n";
        
    my $handler = Mojolicious::Plugin::AsyncMySQL::Handler->new($dbh);
    my $self = {
        dsn => $dsn,
        login => $login,
        pass => $pass,
        attr => $attr,
        cache => [$handler]
    };
    bless $self, $class;
}

sub connect {
    return shift;
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
    
    croak __PACKAGE__, ": missing callback function for `do` method\n"
        unless ($self->{cb} = pop @args) && ref($self->{cb}) eq 'CODE';
    
    (my $attr = shift @args) //= {};
    $attr->{async} //= 1;
    my $handler = $self->get_handler($self);
    $handler->set_h;
    $handler->{dbh}->do($statement, $attr, @args);
}

sub get_handler {
    my $self = shift;
    
    my $handler = pop @{$self->{cache}};
    if(!$handler || time - $handler->myclock > $TRUST_PERIOD) {
        my $dbh = DBI->connect(@$self{qw{dsn login pass attr}}) ||
            croak __PACKAGE__, ": can't connect to database $self->{dsn}\n";
        $handler = Mojolicious::Plugin::AsyncMySQL::Handler->new($dbh);
    }
    if(@{$self->{cache}}) {
        my $last_in_cache = @{$self->{cache}}[-1];
        # if the youngest cached handler is out of date then all cached handlers are out of date
        $self->{cache} = [] if time - $last_in_cache->myclock > $TRUST_PERIOD;
    }
    $handler->cache($self->{cache});
    
    return $handler;
}

1;

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
        cache => undef
    };
    
    croak __PACKAGE__, ": missing or wrong database handler (must be `DBI::db`)\n"
        unless $self->{dbh} && ref($self->{dbh}) eq 'DBI::db';
    
    $self->{io} = AnyEvent->io(
        fh      => $self->{dbh}->mysql_fd,
        poll    => 'r',
        cb      => sub {
            local $SIG{__WARN__} = sub { (my $msg=shift)=~s/ at .*//ms; carp "$msg\n" };
            if ($self->{cb} && $self->{h}) {
                $self->{cb}->($self->{h}->mysql_async_result, $self->{h});
            } else {
                croak __PACKAGE__, ": missing callback function or database handler\n";
            }
        }
    );
    
    bless $self, $class;
}

sub execute {
    my ($self, @args) = @_;
    
    croak __PACKAGE__, ": repeated calling an asynchronous function\n"
        if $self->{cb};
    croak __PACKAGE__, ": missing callback function for `execute` method\n"
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

sub cache {
    my $self = shift;
    my $cache = shift;
    if($cache) {
        $self->{cache} = $cache;
        weaken($self->{cache})
    }
    return $self->{cache};
}

sub myclock {
    my $self = shift;
    my $clock = shift;
    $self->{clock} = $clock if $clock;
    return $self->{clock};
}

sub DESTROY {
    my $self = shift;
    
    if($self->{cache}) { # object in use - must be returned in the cache
        my $cache = $self->{cache};
        $self->{cache} = undef;
        $self->myclock(time);
        $self->{cb} = undef;
        $self->{h} = undef;
        push @$cache, $self;
    } else {             # object in cache - must be destroyed
        $self->{dbh}->DESTROY();
    }

    return;
}

1;
