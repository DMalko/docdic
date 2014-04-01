package Mojolicious::Plugin::SMTP;

use Carp;
use Mojo::Base 'Mojolicious::Plugin';
use SMTP::Sender;

our $VERSION = '0.1';

sub register {
    my $plugin = shift;
    my $app  = shift;
    my $attr = shift;
    
    croak __PACKAGE__, ": missing input parameter (hash reference)\n"
        unless ref($attr) eq 'HASH';

    if(exists $attr->{servers}) {
        # set of smtp servers
        $plugin->multi($app, $attr);
    } else {
        # single smtp server
        $plugin->single($app, $attr);
    }
}

sub single {
    my $self = shift;
    my $app = shift;
    my $conf = shift;
    
    my $smtp = SMTP::Sender->new($conf);
    my $attr_name = '_smtp';
    $app->attr($attr_name => $smtp);
    my $helper_name = $conf->{helper} || 'smtp';
    $app->helper($helper_name => sub { return shift->app->$attr_name() });
}

sub multi {
    my $self = shift;
    my $app = shift;
    my $conf = shift;
    
    for my $helper (keys %{$conf->{servers}}) {
        my $srvconf = $conf->{servers}->{$helper};
        my $smtp = SMTP::Sender->new($srvconf);
        my $attr_name = '_smtp_' . $helper;
        $app->attr($attr_name => $smtp);
        $app->helper($helper => sub { return shift->app->$attr_name() });
    }
}

1;
