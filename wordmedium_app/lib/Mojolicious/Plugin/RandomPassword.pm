package Mojolicious::Plugin::RandomPassword;
use Mojo::Base 'Mojolicious::Plugin';

use Carp;
use Data::Dumper;

our $VERSION = '0.1';

sub register {
    my $plugin = shift;
    my $app  = shift;
    my $attr = shift;
    
    croak __PACKAGE__, ": missing input parameter (must be a hash reference)\n"
        unless ref($attr) eq 'HASH';
    croak __PACKAGE__, ": wrong charset data format (must be an array reference)\n"
        if exists $attr->{charset} && ref($attr->{charset}) ne 'ARRAY';
    croak __PACKAGE__, ": missing helper name\n"
        unless exists $attr->{helper} && length($attr->{helper}) > 0;
    
    my $pass = sub { Mojolicious::Plugin::RandomPassword->new($attr->{charset}, $attr->{length}) };
    $app->log->debug("pass: ".Dumper($pass->())."\n");
    my $attr_name = '_randpass_' . $attr->{helper};
    $app->attr($attr_name => $pass);
    $app->helper($attr->{helper} => sub { return shift->app->$attr_name->password(shift) });
}

sub new {
    my $class = shift;
    my $chars = shift;
    my $len   = shift;
    
    return undef if $chars && ref($chars) ne 'ARRAY';
    # Avoids using confusing characters such as lower case L (l) and the number one (1), the letter 'O' and the number zero:
    $chars ||= ['A'..'N','P'..'Z','a'..'k','m','n','p'..'z','2'..'9'];
    my $self = {
        charset => $chars,
        setsize => scalar @{$chars},
        length  => $len ? $len : 10 # default password length
    };
    bless $self, $class;
}

sub password {
    my $self = shift;
    my $length = shift;
    
    $length ||= $self->{length};
    $length--;
    
    my $password = '';
    for (0..$length) {
        $password .= $self->{charset}->[int rand $self->{setsize}];
    }
    return $password;
}

1;

__END__

=head1 NAME

Mojolicious::Plugin::RandomPassword - random password generator

=head1 VERSION

version 0.1

=head1 SYNOPSIS

Provides generation a random password. 

    use Mojolicious::Plugin::RandomPassword;

    sub startup {
        my $self = shift;
        
        $self->plugin('RandomPassword', { 
            helper  => 'randpass',                                             # required
            charset => ['A'..'N','P'..'Z','a'..'k','m','n','p'..'z','2'..'9'], # optional
            length  => 10                                                      # optional
        });
    }

=head1 CONFIGURATION

=over 4

=item 'helper'      helper name

=item 'charset'     the character set which will be used to generate a password (must be a reference to an array)

=item 'length'      the password length (the default is 10)

=back

The only required option is 'helper', every other option is optional.

=head1 METHODS/HELPERS

A helper is created with a name you specified that can be used to generate random passwords.

=head1 AUTHOR

Dmitry Malko, C<< <dmalko at cpan.org> >>

=head1 BUGS/CONTRIBUTING

Please tell me bugs if you find bug.

C<< <dmalko at cpan.org> >>

=head1 SUPPORT

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Mojolicious-Plugin-RandomPassword>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Mojolicious-Plugin-RandomPassword>

=item * Search CPAN

L<http://search.cpan.org/dist/Mojolicious-Plugin-RandomPassword/>

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
