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
my $config_file = 'wordmedium.conf';

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
    
    # Password generator #
    ######################
    $self->plugin('RandomPassword', { helper => 'randpass', length => 10 });
    
    # SMTP SSL agent #
    ##################
    $self->plugin('SMTP', { helper => 'smtp_ssl', server => $config->{smtp_server} });
    
    # Database helper `db` #
    ########################
    my $dsn = "dbi:mysql:$config->{dbcore}->{name}:$config->{dbcore}->{host}:$config->{dbcore}->{port}";
    $self->plugin('database', { 
        dsn      => $dsn,
        username => $config->{dbcore}->{user},
        password => $config->{dbcore}->{pass},
        options  => {RaiseError => 1, AutoCommit => 1, mysql_enable_utf8 => 1},
        helper   => 'db'
    });
    
    # Use strong encryption #
    #########################
    $self->plugin('bcrypt', {cost => 6});
    
    # Authentication #
    ##################
    $self->plugin('authentication', {
        'autoload_user' => 1,
        'session_key' => 'auth_data',
        'load_user' => sub {
            my $self = shift;
            my $uid  = shift;
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
    
    # usage:
    # my $domain = $self->mydomain();
    $self->helper(mydomain => sub { return shift->app->config->{mydomain}; });
    
    
    # usage:
    # $self->passreset($uid, $new_password);
    $self->helper(passrst => sub {
        my $self = shift;
        my $uid = shift;
        my $pass = shift;
        
        my $crptpass = $self->bcrypt($pass);
        my $passreset = $self->db->prepare(q{UPDATE user SET pass = ? WHERE uid = ?});
	return 1 if $passreset->execute($crptpass, $uid);
        return undef;
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
