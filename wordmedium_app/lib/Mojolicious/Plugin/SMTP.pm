package Mojolicious::Plugin::SMTP;
use Mojo::Base 'Mojolicious::Plugin';

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
    
    my $server = sub { __PACKAGE__->ini($attr->{server}) };
    my $attr_name = '_smtp_' . $attr->{helper};
    $app->attr($attr_name => $server);
    $app->helper($attr->{helper} => sub { return shift->app->$attr_name->send(shift) });
}

sub ini {
    my $class = shift;
    my $attr = shift;
    
    croak __PACKAGE__, ": wrong server config (`host`, `port`, `hello`, `login` and `pass` must be defined)\n"
        unless $attr->{host} && $attr->{port} && $attr->{hello} && $attr->{login} && $attr->{pass};
        
    my $self = {
        host  => $attr->{host},
        port  => $attr->{port},
        hello => $attr->{hello},
        login => $attr->{login},
        pass  => $attr->{pass}
    };
    bless $self, $class;
}

sub send {
    my $self = shift;
    my $arg = shift;
    
    croak __PACKAGE__, ": wrong send argument (must be a hash reference)\n"
        unless $arg && ref($arg) eq 'HASH';
    croak __PACKAGE__, ": wrong mail attributes (must be a hash reference)\n"
        unless exists $arg->{mail} && ref($arg->{mail}) eq 'HASH';
    croak __PACKAGE__, ": no callback function\n"
        unless exists $arg->{cb} && ref($arg->{cb}) eq 'CODE';
    
    my $mail = $arg->{mail};
    my $cb = $arg->{cb};
    
    my $smtp_ssl = sub { # Sendmail function
        my $smtp = Net::SMTP::SSL->new(
	    $self->{host}, 
	    Hello => $self->{hello}, 
	    Port => $self->{port},
	    LocalPort => 0,        # Necessary
	    Debug => 0
	);
	return undef unless defined $smtp;
	
        my $auth_return = $smtp->auth($self->{login}, $self->{pass});
        my $mail_return = $smtp->mail($mail->{from});
        my $to_return = $smtp->to($mail->{to});
        
        $smtp->data();
        $smtp->datasend("To: $mail->{to}\n");
        $smtp->datasend("From: $mail->{from}\n");    # Could be any address
        $smtp->datasend("Subject: $mail->{subject}\n");
        $smtp->datasend("\n");                     # Between headers and body
        $smtp->datasend($mail->{data});
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


__END__

=head1 NAME

Mojolicious::Plugin::SMTP - SMTP mail sender secured by SSL

=head1 VERSION

version 0.1

=head1 SYNOPSIS

Provides sending a mail by SSL SMTP server. 

    # Mojolicious
    sub startup {
        my $self = shift;
        
        $self->plugin('SMTP', {
            helper => 'smtp_ssl',
            server => {
                host  => 'smtp.mailserver.com',
                port  => 465,
                hello => 'HELLO',
                login => 'LOGIN',
                pass  => 'PASSWORD'
            }
        });
    }

    # in controller
    $self->smtp_ssl({
        mail => { # Mail attributes
            from    => 'from@your_mail.com',
            to      => 'to@destination_mail.com',
            subject => 'message subject',
            data    => "Your message body"
        },
        cb => sub { # Callback function
            my ($fc, $err, $res) = @_;
            # Do something here
            ...
        }
    });
    
=head1 CONFIGURATION

=over 2

=item 'helper'      helper name

=item 'server'      smtp server connection parameter:
HOST - the name of the remote host to which an SMTP connection is required;
PORT - port to connect to;
HELLO - SMTP requires that you identify yourself (this option specifies a string to pass as your mail domain);
LOGIN - user name for mail server;
PASSWORD - pasword for mail server;

=back

The required options are 'helper' and 'server'.

=head1 METHODS/HELPERS

A helper is created with a name you specified that can be used to send mails.

=head1 AUTHOR

Dmitry Malko, C<< <dmalko at cpan.org> >>

=head1 BUGS/CONTRIBUTING

Please tell me bugs if you find bug.

C<< <dmalko at cpan.org> >>

=head1 SUPPORT

You can also look for information at:

=over 3

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Mojolicious-Plugin-SMTP>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Mojolicious-Plugin-SMTP>

=item * Search CPAN

L<http://search.cpan.org/dist/Mojolicious-Plugin-SMTP/>

=back

=head1 ACKNOWLEDGEMENTS

*

=head1 LICENSE AND COPYRIGHT

Copyright 2014 Dmitry Malko.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut