package WordMedium;

use Mojo::Base 'Mojolicious';
use Net::SMTP::SSL;

# Dependences:
# 0. EV , AnyEvent ??? 
# 1. Mojolicious::Plugin::Database
# 2. Mojolicious::Plugin::Authentication
# 3. Mojolicious::Plugin::Bcrypt
# 4. Net::SMTP::SSL (instead of sendmail-dependent Mojolicious::Plugin::Mail)
# 5. Mojo::IOLoop::ForkCall (run blocking functions asynchronously by forking)

#$ENV{MOJO_MODE} = 'production';
$ENV{MOJO_MODE} = 'development';

# App config
my $config_file = 'wmapp.conf';

# This method will run once at server start
sub startup {
    my $self = shift;

    # Configuration #
    #################
    my $config = $self->plugin('Config', { file => $config_file });
    
    # Secret #
    ##########
    $self->secrets([$config->{secret}]);
    
    # Documentation browser under "/perldoc" #
    ##########################################
    $self->plugin('PODRenderer');
    
    # Main domain #
    ###############
    $self->helper(main_domain => sub { return shift->app->config->{main_domain}; });
    
    # Password generator #
    ######################
    $self->plugin('RandomPassword', { helper => 'randpass', length => 10 });
    
    # Use strong encryption #
    #########################
    $self->plugin('Bcrypt', {cost => 6});
    
    # SMTP SSL agent #
    ##################
    $self->plugin('SMTP', { helper => 'smtp_ssl', server => $config->{smtp_server} });
    
    # Database access #
    ###################
    my $dbcore = $config->{dbcore};
    $self->plugin('database', {
        helper   => 'db',
        dsn      => join(':', 'dbi', 'mysql', @$dbcore{qw{name host port}}),
        username => $dbcore->{user},
        password => $dbcore->{pass},
        options  => {RaiseError => 0, AutoCommit => 1, mysql_enable_utf8 => 1}
    });
    
    # Authentication #
    ##################
    $self->plugin('authentication', {
        'autoload_user' => 1,
        'session_key' => 'auth_data',
        'load_user' => sub {
            my ($self, $uid)  = @_;
            return {uid => $uid};
        },
        'validate_user' => sub {
            my ($self, $user, $password, $extradata) = @_;

            my $getuid = $self->db->prepare("SELECT uid, pass FROM user WHERE uname = ? || email = ?");
            $getuid->execute($user, $user);
            my ($uid, $pass) = $getuid->fetchrow_array();
            return $uid if $self->bcrypt_validate($password, $pass);
            return undef;
        }
    });
    
    # Authentication helpers #
    ##########################
    # usage:
    # my $user_hash = $self->uid2user($uid);
    $self->helper(uid2user => sub {
        my $self = shift;
        my $uid = shift;
        
        my $get_user = $self->db->prepare(q{SELECT uname, email, created FROM user WHERE uid = ?});
	$get_user->execute($uid);
	my ($uname, $email, $time) = $get_user->fetchrow_array();
        return {uname => $uname, email => $email, timestamp => $time} if $uname && $email;
        return undef;
    });
    
    # usage:
    # my $uid = $self->user2uid('user_name');
    # my $uid = $self->user2uid('user@email.com');
    $self->helper(user2uid => sub {
        my $self = shift;
        my $user = shift;
        
        return undef unless $user;
        my $get_uid = $self->db->prepare(q{SELECT uid FROM user WHERE uname = ? OR email = ?});
	$get_uid->execute($user, $user);
	my ($uid) = $get_uid->fetchrow_array();
        return $uid;
    });
    
    # Router #
    ##########
    my $r = $self->routes;
    
    # Normal route to controller #
    ##############################
    $r->route('/')->to('home#index');
    $r->route('/signup')->to('home#signup');
    $r->route('/signin')->to('home#signin');
    $r->route('/signout')->to('home#signout');
    $r->route('/passreset')->to('home#passreset');
    $r->route('/test1')->to('home#test');
    $r->route('/test')->over(authenticated => 1)->to('home#test');
    
}

1;
