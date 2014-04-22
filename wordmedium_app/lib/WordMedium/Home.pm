package WordMedium::Home;

use Mojo::Base 'Mojolicious::Controller';

sub index {
    my $self = shift;

    $self->render_static('index.html');
}

sub test {
    my $self = shift;

    $self->render(text => "TEST!");
}

sub myhome {
    my $self = shift;

    $self->render(text => "WELCOME!");
}

1;
