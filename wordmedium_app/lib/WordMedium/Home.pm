package WordMedium::Home;

use Mojo::Base 'Mojolicious::Controller';

sub index {
    my $self = shift;

    $self->render_static('index.html');
}

sub myhome {
    my $self = shift;

    $self->render(text => "WELCOME!");
}

sub test {
    my $self = shift;

    $self->render(text => "TEST!");
}


1;
