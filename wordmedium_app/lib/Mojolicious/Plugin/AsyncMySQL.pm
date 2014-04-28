package Mojolicious::Plugin::AsyncMySQL;
use Mojo::Base 'Mojolicious::Plugin';

use Carp;
use DBI;
use AnyEvent;
use Digest::MD5 qw( md5_hex );

our $VERSION = '0.4';

my $CONNECTION_LIFETIME = 120; # the max time to reuse the connection (sec)
my $INSTANCE_NUM = 0;
my $DEBUG = 0;

my %mojo = (); # It uses only for Mojolicious

sub register {
    my $plugin = shift;
    my $app = shift;
    my $attr = shift;
    
    croak __PACKAGE__, ": missing input parameter (must be a hash reference)"
        unless $attr && ref($attr) eq 'HASH';
    croak __PACKAGE__, ": missing helper name"
        unless $attr->{helper};
    croak __PACKAGE__, ": the helper name already exists"
        if exists $mojo{$attr->{helper}};
    
    #my $server = sub { __PACKAGE__->connect($attr->{db}) };
    my $attr_name = '_asyncmysql_' . $attr->{helper};
    $mojo{$attr->{helper}} = __PACKAGE__->connect($attr->{dsn}, $attr->{username}, $attr->{password}, $attr->{options});
    $app->attr($attr_name => sub {return $mojo{$attr->{helper}}});
    $app->helper($attr->{helper} => sub { return shift->app->$attr_name });
}

sub connect {
    my $class = shift;
    my ($dsn, $login, $pass, $attr) = @_;
    
    my $dbh = DBI->connect($dsn, $login, $pass, $attr) ||
        croak __PACKAGE__, ": can't connect to database $dsn";
        
    my $handler = Mojolicious::Plugin::AsyncMySQL::Handler->new($dbh); # try to connect before using it
    
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
#    cd   => $cb
# });
#
# $dbh->query({
#    sql => $sql,
#    val => [],
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
    
    my $handler = $self->get_handler($args->{cb});
    
    $args->{attr}->{async} = 1;
    $handler->prepare($args);
    
    $handler->execute($args->{val});
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
    return $key;
}

sub get_handler {
    my $self = shift;
    my $cb = shift;
    my $key = shift;
    
    $self->{stack_cached}->{$key} = [] if $key && !$self->{stack_cached}->{$key}; # stack initialization for cached requests
    
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
    
    $self->{io} = AnyEvent->io( # circular reference!
        fh => $self->{dbh}->mysql_fd,
        poll => 'r',
        cb => sub {
            if ($self->{cb} && $self->{h}) {
                eval { $self->{cb}->($self->{h}->mysql_async_result, $self->{h}) };
                carp __PACKAGE__, ": callback error" if $@;
            } else {
                carp __PACKAGE__, ": missing callback function or database handler";
            }
            $self->{io} = undef; # break the circular reference to destroy the instance
        }
    );
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
    if($self->{stack_ref}) { # object in use - must be returned in the stack
        my $stack = $self->{stack_ref};
        $self->{stack_ref} = undef;
        $self->myclock(time);
        
        unless($self->{key}) {
            $self->{h} = undef;
        } elsif(ref($self->{h}) ne ref($self->{dbh})) { # flush the statement handler
            $self->{h}->finish if defined $self->{h}->fetchrow_array;
        }
        
        push @$stack, $self;
        carp "$self->{i} pushed in cache" if $DEBUG;
    } else { # object in the stack - must be destroyed if the stack is flushed
        $self->{h} = undef;
        $self->{dbh} = undef;
        carp "$self->{i} destroyed" if $DEBUG;
    }
    return;
}

1;

__END__


=encoding utf8

=head1 NAME

Mojolicious::Plugin::AsyncMySQL - Asynchronous MySQL queries


=head1 SYNOPSIS

    use Mojolicious::Plugin::AsyncMySQL;

    $dbh = Mojolicious::Plugin::AsyncMySQL->connect(...);
    
    my $sql_1 = q{DELETE FROM table_name WHERE column_name_1 = ? AND column_name_2 = ?};
    my $sql_2 = q{SELECT * FROM table_name ORDER BY column_name_1 LIMIT 1};
    my $sql_3 = q{SELECT * FROM table_name WHERE column_name_1 = ? AND column_name_2 = ?};
    
    my $attr = {...}; # query attributes
    
    $dbh->do({
        sql  => $sql_1,
        val  => ['foo', 'bar'],
        cd   => sub {
            my ($rv, $dbh) = @_;
            ...
        }
    });
   
    $dbh->query({
        sql => $sql_2,
        val  => [], # not required
        cd  => sub {
            my ($rv, $sth) = @_;
            ...
        }
    });
   
    $dbh->query_cached({
        sql => $sql_3,
        val => ['foo', 'bar'],
        attr => $attr, # can be set only for query_cached()
        cd  => sub {
            my ($rv, $sth) = @_;
            ...
        }
    });


=head1 DESCRIPTION

This module is an L<AnyEvent> user, you need to make sure that you use and
run a supported event loop.

This module implements asynchronous MySQL queries and can be used as a
Mojolicious plugin. It doesn't spawn any processes.

=head1 INTERFACE 

The API has four methods: connect(), do(), query() and query_cached().

=over

=item connect(...)

This module uses L<DBD::mysql> which support only single asynchronous
query per MySQL connection. To overcome this limitation provided connect()
constructor makes a pool of objects constructed by DBI->connect().
Methods do(), query() and query_cached() reuse only the objects
which you don't use anymore. The pool size will increase under high load and
decrease while reducing the load.

=item

$dbh->do({
    sql  => $sql_statement,
    val  => [@bind_values],
    cd   => sub {
        my ($rv, $dbh) = @_;
        ...
    }
});

Prepare and execute a single statement like do() method of DBI package,
but takes the hash reference as an argument. The required hash keys
are 'sql' and 'cb' associated with the SQL statement and the callback function respectively.
The hash element 'val' associates with a reference to the bind values array and is not required.
After the statment execution the DBI database handle will returned to the callback function.

=item

$dbh->query({
    sql  => $scalar,
    val  => [@list],
    cd   => sub {
        my ($rv, $sth) = @_;
        ...
    }
});

This method combines prepare() and execute() DBI methods and returns the DBI statement handle
to the callback function. It takes the same argument as do() method.


=item

$dbh->query_cached({
    sql  => $scalar,
    val  => [@list],
    attr => $hash_ref,
    cd   => sub {
        my ($rv, $sth) = @_;
        ...
    }
});

This method combines prepare() and execute() DBI methods, but prepare() method will executed only ones
and cached at the separate connection pool. It can spare database server usage.
The handle attributes can be set using not requered hash element 'attr'. The attributes will be sent to
prepare() DBI method except 'mysql_use_result' and 'mysql_store_result' which will be applied before calling
execute() DBI method. The callback function will get the DBI statement handle. 

=back

=head2 SYNCHRONOUS QUERIES

To make synchronous query use usual DBI or Mojolicious::Plugin::Database.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

=head1 SUPPORT

Please report any bugs or feature requests through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Mojolicious-Plugin-AsyncMySQL>.
I will be notified, and then you'll automatically be notified of progress
on your bug as I make changes.

You can also look for information at:

=over

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Mojolicious-Plugin-AsyncMySQL>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Mojolicious-Plugin-AsyncMySQL>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Mojolicious-Plugin-AsyncMySQL>

=item * Search CPAN

L<http://search.cpan.org/dist/Mojolicious-Plugin-AsyncMySQL/>

=back


=head1 SEE ALSO

L<AnyEvent>, L<DBI>, L<AnyEvent::DBI>, L<AnyEvent::DBI::MySQL>


=head1 AUTHOR

Dmitry Malko  C<< <dmitry.malko@cpan.org> >>


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Dmitry Malko <dmitry.malko@cpan.org>.

This program is distributed under the MIT (X11) License:
L<http://www.opensource.org/licenses/mit-license.php>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
