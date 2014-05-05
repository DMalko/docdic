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
    
    # Password generator #
    $self->plugin('RandomPassword', { helper => 'randpass', length => 10 });
    
    # Use strong encryption #
    $self->plugin('Bcrypt', {cost => 6});
    
    # SMTP SSL agent #
    $self->plugin('SMTP', { helper => 'smtp_ssl', server => $config->{smtp_server} });
    
    # Database access #
    my $dbcore = $config->{dbcore};
    
    $self->plugin('database', {
        helper   => 'sync_db',
        dsn      => join(':', @$dbcore{qw{schima driver name host port}}),
        username => $dbcore->{user},
        password => $dbcore->{pass},
        options  => {RaiseError => 0, AutoCommit => 1, mysql_enable_utf8 => 1}
    });
    
    $self->plugin('AsyncMySQL', {
        helper   => 'db',
        dsn      => join(':', @$dbcore{qw{schima driver name host port}}),
        username => $dbcore->{user},
        password => $dbcore->{pass},
        options  => {RaiseError => 0, AutoCommit => 1, mysql_enable_utf8 => 1}
    });
    
    # Router #
    my $r = $self->routes;
    
    # Normal routes to controller #
    my $auth_bridge = $r->bridge('/')->to('authentication#check');
    $auth_bridge->route('/')->to('home#index');
    $auth_bridge->route('/signup')->to('authentication#signup');
    $auth_bridge->route('/signin')->to('authentication#signin');
    $auth_bridge->route('/signout')->to('authentication#signout');
    $auth_bridge->route('/passreset')->to('authentication#passreset');
    
    $r->route('/test')->to('home#test');
    
    # Private routes to controller #
    $auth_bridge->route('/members')->to('home#myhome');
    
}

1;
