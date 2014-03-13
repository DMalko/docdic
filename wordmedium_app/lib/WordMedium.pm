package WordMedium;

use Mojo::Base 'Mojolicious';
# Dependences:
# 1. Mojolicious::Plugin::Database
# 2. Mojolicious::Plugin::Authentication
# 3. Mojolicious::Plugin::Bcrypt
# 4. Mojolicious::Plugin::Mail

# App domain
my $domain = 'wordmedium.com';

# App mails
my $smtp_server  = 'smtp.gmail.com';
my $support_mail = 'wordmedium.team@gmail.com';
my $support_pass = 'wordmedium';

# Database parameters
my $dbname = 'wmdb';
my $dbhost = 'localhost';
my $dbport = '3306';
my $dbuser = 'root';
my $dbpass = '';

# This method will run once at server start
sub startup {
    my $self = shift;
    
    $self->secrets(['In vino veritas, in aqua sanitas!']);
    
    # Documentation browser under "/perldoc" #
    ##########################################
    $self->plugin('PODRenderer');
    
    # Sendmail helper `mail` #
    ###########################
    $self->plugin(mail => {
        from => $support_mail,
        type => 'text/plain',
        how  => 'smtp',
        howargs => [ $smtp_server,
            AuthUser => $support_mail,
            AuthPass => $support_pass,
        ]
    });
    
    # Database helper `db` #
    ########################
    my $dsn = "dbi:mysql:$dbname:$dbhost:$dbport";
    $self->plugin('database', { 
        dsn      => $dsn,
        username => $dbuser,
        password => $dbpass,
        options  => {RaiseError => 1, AutoCommit => 1, mysql_enable_utf8 => 1, mysql_auto_reconnect => 1},
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
    $self->helper(mydomain => sub {
        my $self = shift;
        return $domain;
    });
    
    # usage:
    # my $password = $self->randpass($pass_length);
    # default password length is 10
    $self->helper(randpass => sub {
        my $self = shift;
        my $length = shift;
        
        $length ||= 10;
        # Avoids using confusing characters such as lower case L (l) and the number one (1), the letter 'O' and the number zero.
        my @chars = ('A'..'N','P'..'Z','a'..'k','m','n','p'..'z','2'..'9');
        my $password = '';
        for (0..$length) {
            $password .= $chars[int rand @chars];
        }
        return $password;
    });
    
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
    $r->route('/test')->over(authenticated => 1)->to('home#test');
    
}

1;
