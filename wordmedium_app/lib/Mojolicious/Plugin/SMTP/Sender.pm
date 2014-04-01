package Mojolicious::Plugin::SMTP::Sender;

use strict;
use warnings;

use Carp;
use Net::SMTP::SSL;
use Mojo::IOLoop::ForkCall;

sub new {
    my $class = shift;
    my $conf = shift;
    
    croak __PACKAGE__." ERROR: input argument must be a hash reference\n"
	unless ref($conf) eq 'HASH';
    croak __PACKAGE__." ERROR: wrong connection parameters (needed `host`, `port` and `hello`)\n"
	unless $conf->{host} && $conf->{port} && $conf->{hello};
    
    my $self = {
        host => $conf->{host},
	port => $conf->{port},
	hello => $conf->{hello}
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
	
        my $auth_return = $smtp->auth($attr->{login}, $attr->{pass});
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
