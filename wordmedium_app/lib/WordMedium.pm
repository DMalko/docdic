package WordMedium;

use Mojo::Base 'Mojolicious';
use Net::SMTP::SSL;

# Dependences:
# 1. Mojolicious::Plugin::Database
# 2. Mojolicious::Plugin::Authentication
# 3. Mojolicious::Plugin::Bcrypt
# 4. Net::SMTP::SSL (instead of sendmail-dependent Mojolicious::Plugin::Mail)
# 5. Mojo::IOLoop::ForkCall (run blocking functions asynchronously by forking)

# App domain
my $domain = 'wordmedium.com';

# App smtp mail server
my $smtp_host  = 'smtp.gmail.com';
my $smtp_port  = 465;
my $smtp_login = 'wordmedium.team';
my $smtp_pass  = 'wordmedium';
my $smtp_hello = 'wordmedium.com';
my $smtp_from  = 'wordmedium.team@gmail.com';
my $smtp_to    = 'wordmedium.team@gmail.com';
my $smtp_sbj   = '';
my $smtp_msg   = '';

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
    
    # Sendmail helpers `smtp_ssl`, `mail` #
    #######################################
    # returns reference to sendmail function
    $self->helper(smtp_ssl => sub {
        my $self = shift;
        
        my $function = sub {
            my %attr = @_;
            
            $attr{host}    ||= $smtp_host;
            $attr{port}    ||= $smtp_port;
            $attr{login}   ||= $smtp_login;
            $attr{pass}    ||= $smtp_pass;
            $attr{hello}   ||= $smtp_hello;
            $attr{from}    ||= $smtp_from;
            $attr{to}      ||= $smtp_to;
            $attr{subject} ||= $smtp_sbj;
            $attr{data}    ||= $smtp_msg;
            
            my $smtp = Net::SMTP::SSL->new(
                $attr{host}, 
                Hello => $attr{hello}, 
                Port => $attr{port},
                LocalPort => 0,        # Necessary
                Debug => 0
            );
            return undef if !defined $smtp;
            
            my $auth_return = $smtp->auth($attr{login}, $attr{pass});
            my $mail_return = $smtp->mail($attr{from});
            my $to_return = $smtp->to($attr{to});
            
            $smtp->data();
            $smtp->datasend("To: $attr{to}\n");
            $smtp->datasend("From: $attr{from}\n");    # Could be any address
            $smtp->datasend("Subject: $attr{subject}\n");
            $smtp->datasend("\n");                     # Between headers and body
            $smtp->datasend($attr{data});
            $smtp->dataend();
            $smtp->quit;
            
            return 1 if $auth_return && $mail_return && $to_return;
            return undef;
        };
        return $function;
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
    $r->route('/test1')->to('home#test');
    $r->route('/test')->over(authenticated => 1)->to('home#test');
    
}

1;
