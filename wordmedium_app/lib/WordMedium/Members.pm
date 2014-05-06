package WordMedium::Members;

use Mojo::Base 'Mojolicious::Controller';
use EV;
use Mojo::IOLoop;
use Mojo::IOLoop::Delay;
use Mojo::IOLoop::ForkCall;


sub authenticated {
    my $self = shift;
    
    #unless (defined $self->session($auth_session_key)) {
    unless ($self->is_authenticated) {
        $self->redirect_to('/');
        return;
    }
    
    return 1;
}

sub signup {
    my $self = shift;

    my $uname  = $self->req->param('uname')  || q{};
    my $email  = $self->req->param('email')  || q{};
    my $pass   = $self->req->param('pass')   || q{};
    my $repass = $self->req->param('repass') || q{};
    my $hs     = $self->req->param('hs_email');
    
    if ($hs) { # robot request detected
        $self->redirect_to('/');
        return 1;
    }
    
    unless ($uname && $email && $pass && $repass) { # please fill in all required fields
        $self->render(json => {msg => 'Please fill in all required fields.', msgtype => 'error'});
        return 1;
    }
    
    if ($uname eq $email) { # user name cannot be the same as your email
        $self->render(json => {msg => 'The user name cannot be the same as your email.', msgtype => 'error'});
        return 1;
    }
    
    if ($uname eq $pass) { # user name cannot be the same as your password
        $self->render(json => {msg => 'The user name cannot be the same as your password.', msgtype => 'error'});
        return 1;
    }
    
    $self->render_later;
    my $delay = Mojo::IOLoop::Delay->new;
    $delay->steps(
        sub {
            my $d = shift;
            
            my $end = $d->begin(0);
            $self->db->query({
                sql => q{SELECT uname, email FROM user WHERE uname = ? UNION SELECT uname, email FROM user WHERE email = ?},
                val => [$uname, $email],
                cb => sub {
                    my ($rv, $sth) = @_;
                    
                    while(my ($name, $mail) = $sth->fetchrow_array()) {
                        if($name eq $uname) { # check user name
                            $self->render(json => {msg => 'The user name already exists.', msgtype => 'error'});
                            $end->();
                            return;
                        }
                        if($mail eq $email) { # check user email
                            $self->render(json => {msg => 'The email already exists.', msgtype => 'error'});
                            $end->();
                            return;
                        }
                    }
                    $end->(1);
                }
            });
        },
        sub {
            my ($d, $last_ok) = @_;
            return unless $last_ok;
            
            if ($pass ne $repass) { # check password match
                $self->render(json => {msg => 'The password does not match the confirm password.', msgtype => 'error'});
                return;
            }
            
            my $end = $d->begin();
            my $crptpass = $self->bcrypt($pass);
            $self->db->do({
                sql => q{INSERT IGNORE INTO user VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)},
                val => ['\N', $uname, $email, $crptpass],
                cb => sub { $end->();}
            });
        },
        sub {
            my $d = shift;
            
            my $end = $d->begin(0);
            $self->db->query({
                sql => q{SELECT uid FROM user WHERE uname = ? AND email = ? LIMIT 1}, # `LIMIT 1` to speed up the query
                val => [$uname, $email],
                cb => sub {
                    my ($rv, $sth) = @_;
                    
                    my ($uid) = $sth->fetchrow_array();
                    unless (defined $uid) { # registration denied
                        $self->render(json => {msg => 'Registration denied.', msgtype => 'error'});
                        $end->();
                        return;
                    }
                    #$self->session($auth_session_key => $uid);
                    #$self->stash($auth_stash_key => $uid);
                    $self->authenticate($uid);
                    $self->render(json => {redirect => '/members/myhome'});
                    $end->(1);
                }
            });
        }
    );
    $delay->wait unless Mojo::IOLoop->is_running;
    return 1;
}

sub signin {
    my $self = shift;
    
    my $uname  = $self->req->param('uname')  || q{};
    my $upass  = $self->req->param('pass')   || q{};
    my $hs     = $self->req->param('hs_email');
    
    if ($hs) { # robot request detected
        $self->redirect_to('/');
        return;
    }
    
    unless ($uname && $upass) { # please fill in all required fields
        $self->render(json => {msg => 'Please fill in all required fields.', msgtype => 'error'});
        return;
    }
    
    $self->render_later;
    $self->db->query({
        sql => q{SELECT uid, pass FROM user WHERE uname = ? OR email = ? LIMIT 1}, # `LIMIT 1` to speed up the query
        val => [$uname, $uname],
        cb => sub {
            my ($rv, $sth) = @_;
            my ($uid, $pass) = $sth->fetchrow_array();
            $sth->finish();
            
            unless ($uid) {
                $self->render(json => {msg => 'Wrong 1user name or password.', msgtype => 'error'});
                return;
            }
            
            if($self->bcrypt_validate($upass, $pass)) {
                #$self->session($auth_session_key => $uid);
                #$self->stash($auth_stash_key => $uid);
                $self->authenticate($uid);
                $self->render(json => {redirect => '/members/myhome'});
            } else {
                $self->render(json => {msg => 'Wrong user name or 1password.', msgtype => 'error'});
            }
        }
    });
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
    return 1;
}

sub signout {
    my $self = shift;

    #$self->session(expires => 1);
    #delete $self->stash->{$auth_stash_key};
    #delete $self->session->{$auth_session_key};
    $self->logout;
    $self->redirect_to('/');
    return 1;
}

sub passreset {
    my $self = shift;
    
    my $email = $self->req->param('email')  || q{};
    my $hs    = $self->req->param('hs_email');
    
    if ($hs) { # robot request detected
        $self->redirect_to('/');
        return 1;
    }
    
    my $delay = Mojo::IOLoop::Delay->new;
    $self->render_later;
    $delay->steps(
        sub { # check the user
            my $d = shift;
            my $end = $d->begin(0);
            $self->db->query({
                sql => q{SELECT uid FROM user WHERE email = ?},
                val => [$email],
                cb => sub {
                    my ($rv, $sth) = @_;
                    my ($uid) = $sth->fetchrow_array();
                    $sth->finish();
                    unless ($uid) {
                        $self->render(json => {msg => 'The email you entered does not belong to any account.', msgtype => 'error'});
                    }
                    $end->($uid);
                }
            });
        },
        sub { # update the password
            my ($d, $uid) = @_;
            return unless $uid;
            
            my $end = $d->begin(0);
            my $new_password = $self->randpass();
            #$self->app->log->debug("email: $email => new password: $new_password\n");
            my $crptpass = $self->bcrypt($new_password);
            $self->db->do({
                sql => q{UPDATE user SET pass = ? WHERE uid = ?},
                val => [$crptpass, $uid],
                cb => sub {
                    my ($rv, $dbh) = @_;
                    $end->($uid, $new_password);
                }
            });
        },
        sub { # send the email
            my ($d, $uid, $new_password) = @_;
            
            unless ($uid && $new_password) {
                $self->render(json => {msg => 'Password reset error.', msgtype => 'error'});
                return;
            }
            
            my $end = $d->begin();
            my $domain = $self->main_domain;
            $self->smtp_ssl({
                mail => { # mail attributes
                    from    => $self->app->config->{support_mail},
                    to      => $email,
                    subject => 'password recovery',
                    data    => "Your temporary password for $domain: $new_password\n\nPlease, change the password after signin.\n\nBest regards,\n$domain team"
                },
                cb => sub { # callback function
                    my ($fc, $err, $res) = @_;
                    if ($res) {
                        $self->render(json => {msg => "The email was sent to $email", msgtype => 'ok'});
                    } else {
                        $self->render(json => {msg => 'Internal error. Try again.', msgtype => 'error'});
                    }
                    $end->();
                }
            });
        }
    );
    $delay->wait unless Mojo::IOLoop->is_running;
    return 1;
}

1;
