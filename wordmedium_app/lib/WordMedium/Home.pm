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
		$self->render(json => {msg => 'Please fill in all required fields.'});
		return 1;
	}
	
	if ($uname eq $pass) { # user name cannot be the same as your email
		$self->render(json => {msg => 'The user name cannot be the same as your email.'});
		return 1;
	}

	# check user name
	if ($self->user2uid($uname)) { # user name already exists
		$self->render(json => {msg => 'The user name already exists.'});
		return 1;
	}
	
	# check email
	if ($self->user2uid($email)) { # email already exists
		$self->render(json => {msg => 'The email already exists.'});
		return 1;
	}
	
	# check password match
	if ($pass ne $repass) { # wrong password match
		$self->render(json => {msg => 'The password does not match the confirm password.'});
		return 1;
	}
	
	# create record
	my $crptpass = $self->bcrypt($pass);
	my $setuid = $self->db->prepare(q{INSERT INTO user VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)});
        unless ($setuid->execute('\N', $uname, $email, $crptpass)) { # registration denied
		$self->render(json => {msg => 'Registration denied.'});
		#$self->app->log->debug("registration denied!\n");
		return 1;
	}

	if ($self->authenticate($uname, $pass)) {
		# redirect to members page
		$self->render(json => {redirect => '/test'});
	} else {
		$self->render(json => {msg => 'The account is not created.'});
	}
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
	
	unless ($uname && $pass) { # please fill in all required fields
		$self->render(json => {msg => 'Please fill in all required fields.'});
		return 1;
	}
	
	if ($self->authenticate($uname, $pass)) {
		# redirect to members page
		$self->render(json => {redirect => '/test'});
	} else {
		# send message: wrong user name or password
		$self->render(json => {msg => 'Wrong user name or password.'});
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
		$self->render(json => {msg => 'The email you entered does not belong to any account.'});
		return 1;
	}
	
	my $domain = $self->mydomain();
	my $new_password = $self->randpass(10); # password length = 10
	#$self->app->log->debug("email: $email => new password: $new_password\n");
	if ($self->passrst($uid, $new_password)) {
		$self->render_later;            # prevent auto-render
		$self->mail(
			to      => $email,
			subject => 'password recovery',
			data    => "Your temporary password for $domain: $new_password\n\nPlease, change the password after signin.\n\nBest regards,\n$domain team"
		);
	} else {
		$self->render(json => {msg => 'Password reset error.'});		
	}
	return 1;
}

sub test {
	my $self = shift;

	$self->render(text => "TEST!");
}

1;
