package WordMedium;

use Mojo::Base 'Mojolicious';
use Net::SMTP::SSL;

# Dependences:
# 0. EV , AnyEvent ??? 
# 1. Mojolicious::Plugin::Database
# 3. Mojolicious::Plugin::Bcrypt
# 4. Net::SMTP::SSL (instead of sendmail-dependent Mojolicious::Plugin::Mail)
# 5. Mojo::IOLoop::ForkCall (run blocking functions asynchronously by forking)
# 6. Mojo::IOLoop::Delay (run non-blocking functions sequentially)
# 7. Mojolicious::Plugin::RenderFile (it does not read file in memory and just streaming it to a client)

#$ENV{MOJO_MODE} = 'production';
$ENV{MOJO_MODE} = 'development';

# App config
my $config_file = 'wmapp.conf';

# This method will run once at server start
sub startup {
    my $self = shift;

    # Configuration #
    my $config = $self->plugin('Config', { file => $config_file });
    
    # Secret #
    $self->secrets([$config->{secret}]);
    
    # Documentation browser under "/perldoc" #
    $self->plugin('PODRenderer');
    
    # Main domain #
    $self->helper(main_domain => sub { return shift->app->config->{main_domain}; });
    
    # Authentication #
    $self->plugin('Authentication', { session_key => 'auth', stash_key => '__auth__' });
    
    # Password generator #
    $self->plugin('RandomPassword', { helper => 'randpass', length => 10 });
    
    # Use strong encryption #
    $self->plugin('Bcrypt', {cost => 6});
    
    # SMTP SSL agent #
    $self->plugin('SMTP', { helper => 'smtp_ssl', server => $config->{smtp_server} });
    
    # Database access #
    my $dbcore = $config->{db_core}; # core
    my $dbdict = $config->{db_dict}; # dictionaries
    
#    $self->plugin('database', {
#        helper   => 'sync_db',
#        dsn      => join(':', @$dbcore{qw{schima driver name host port}}),
#        username => $dbcore->{user},
#        password => $dbcore->{pass},
#        options  => {RaiseError => 0, AutoCommit => 1, mysql_enable_utf8 => 1}
#    });
    
    $self->plugin('AsyncMySQL', {
        helper   => 'core',
        dsn      => join(':', @$dbcore{qw{schima driver name host port}}),
        username => $dbcore->{user},
        password => $dbcore->{pass},
        options  => {RaiseError => 0, AutoCommit => 1, mysql_enable_utf8 => 1}
    });
    
    $self->plugin('AsyncMySQL', {
        helper   => 'dict',
        dsn      => join(':', @$dbdict{qw{schima driver name host port}}),
        username => $dbdict->{user},
        password => $dbdict->{pass},
        options  => {RaiseError => 0, AutoCommit => 1, mysql_enable_utf8 => 1}
    });
    
    # Router #
    my $r = $self->routes;
    
    # Normal routes to controller #
    $r->route('/')->to('home#index');
    $r->route('/signup')->to('members#signup');
    $r->route('/signin')->to('members#signin');
    $r->route('/passreset')->to('members#passreset');
    
    $r->route('/translate')->to('dictionary#translate');
    
    $r->route('/test')->to('home#test');
    
    # Private routes to controller #
    my $members = $r->under('/members')->to('members#authenticated');
    $members->route('/signout')->to('members#signout');
    $members->route('/myhome')->to('home#myhome');
    $members->route('/translate')->to('users#groups')->route->to('dictionary#translate');
    
}

1;
