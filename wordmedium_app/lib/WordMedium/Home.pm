package WordMedium::Home;
use Mojo::Base 'Mojolicious::Controller';

sub index {
	my $self = shift;

	$self->render_static('index.html');
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
# TODO: add flash 'please fill in all required fields'
		$self->redirect_to('/');
		return 1;
	}
	
	if ($uname eq $pass) { # user name cannot be the same as your email 
# TODO: add flash 'user name cannot be the same as your email'
		$self->redirect_to('/');
		return 1;
	}

	# check user name
	if ($self->user2uid($uname)) { # user name already exists
# TODO: add flash 'user name already exists'
		$self->redirect_to('/');
		return 1;
	}
	
	# check email
	if ($self->user2uid($email)) { # email already exists
# TODO: add flash 'email already exists'
		$self->redirect_to('/');
		return 1;
	}
	
	# check password match
	if ($pass ne $repass) { # wrong password match
# TODO: add flash 'wrong password match'
		$self->redirect_to('/');
		return 1;
	}
	
	# create record
	my $crptpass = $self->bcrypt($pass);
	my $setuid = $self->db->prepare(q{INSERT INTO user VALUES ('\N', ?, ?, ?)});
        unless ($setuid->execute($uname, $email, $crptpass)) {
# TODO: add flash 'registration denied'
		$self->redirect_to('/');
#$self->app->log->debug("registration denied!\n");
		return 1;
	}
	
	$self->render(text => "USER IS CREATED!");
	return 1;
}

sub signin {
	my $self = shift;
	
	my $uname  = $self->req->param('uname')  || q{};
	my $pass   = $self->req->param('pass')   || q{};
	my $hs     = $self->req->param('hs_email');
	
	if ($hs) { # robot request detected
		$self->redirect_to('/');
		return 1;
	}
	
	if ($self->authenticate($uname, $pass)) {
# TODO: add redirect to members page
		$self->render(text => "WELCOME!");
	} else {
		$self->redirect_to('/');
	}
	return 1;
}

sub signout {
	my $self = shift;

	$self->session(expires => 1);
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
	
	my $uid = $self->user2uid($email);
	unless ($uid) {
# TODO: add flash 'wrong email'
		$self->redirect_to('/');
		return 1;
	}
	
	my $domain = $self->mydomain();
	my $new_password = $self->randpass(10); # password length = 10
	if ($self->passreset($uid, $new_password)) {
		$self->mail(
			to      => $email,
			subject => 'password recovery',
			data    => "\nYour temporary password for $domain: $new_password\n\nPlease, change the password after signin.\n\nBest regards,\n$domain team"
		);
# TODO: add flash 'email sent'
		$self->render(text => "Email was sent to $email");
	} else {
# TODO: add flash 'fault of password reset'
		$self->redirect_to('/');		
	}
	return 1;
}

sub test {
	my $self = shift;

	$self->render(text => "TEST!");
}

1;
