package Mojolicious::Plugin::SMTP;
use Mojo::Base 'Mojolicious::Plugin';

use EV;
use Carp;
use Net::SMTP::SSL;
use Mojo::IOLoop::ForkCall;

our $VERSION = '0.1';

sub register {
    my $plugin = shift;
    my $app  = shift;
    my $attr = shift;
    
    croak __PACKAGE__, ": missing input parameter (must be a hash reference)\n"
        unless ref($attr) eq 'HASH';
    croak __PACKAGE__, ": missing helper name\n"
        unless exists $attr->{helper} && length($attr->{helper}) > 0;
    croak __PACKAGE__, ": wrong server config (must be a hash reference)\n"
        unless exists $attr->{server} && ref($attr->{server}) eq 'HASH';

    my $smtp = sub { Mojolicious::Plugin::SMTP->new($attr->{server}) };
    my $attr_name = '_smtp_' . $attr->{helper};
    $app->attr($attr_name => $smtp);
    $app->helper($attr->{helper} => sub { return shift->app->$attr_name->send() });
}

sub new {
    my $class = shift;
    my $conf = shift;
    
    croak __PACKAGE__, ": wrong connection attributes (needed `host`, `port`, `hello`, `login` and `pass`)\n"
	unless $conf->{host} && $conf->{port} && $conf->{hello} && $conf->{login} && $conf->{pass};
    
    my $self = {
        host  => $conf->{host},
	port  => $conf->{port},
	hello => $conf->{hello},
        login => $conf->{login},
        pass  => $conf->{pass},
    };
    bless $self, $class;
}

sub send {
    my $self = shift;
    my $attr = shift;
    my $cb = shift;
    
    return undef unless ref($attr) eq 'HASH' && ref($cb) eq 'CODE';
    
    my $smtp_ssl = sub {
        my $smtp = Net::SMTP::SSL->new(
	    $self->{host}, 
	    Hello => $self->{hello}, 
	    Port => $self->{port},
	    LocalPort => 0,        # Necessary
	    Debug => 0
	);
	return undef unless defined $smtp;
	
        my $auth_return = $smtp->auth($self->{login}, $self->{pass});
        my $mail_return = $smtp->mail($attr->{from});
        my $to_return = $smtp->to($attr->{to});
        
        $smtp->data();
        $smtp->datasend("To: $attr->{to}\n");
        $smtp->datasend("From: $attr->{from}\n");    # Could be any address
        $smtp->datasend("Subject: $attr->{subject}\n");
        $smtp->datasend("\n");                     # Between headers and body
        $smtp->datasend($attr->{data});
        $smtp->dataend();
        $smtp->quit;
        
        return 1 if $auth_return && $mail_return && $to_return;
        return undef;
    };
    
    my $fc = Mojo::IOLoop::ForkCall->new;
    $fc->run(
        $smtp_ssl, # Reference to sendmail function
        [],        # Arguments for sendmail function 
	$cb        # Reference to callback function
    );
    $fc->ioloop->start unless $fc->ioloop->is_running;
    return 1;
}

1;
