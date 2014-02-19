package WordMedium::Home;
use Mojo::Base 'Mojolicious::Controller';

sub index {
	my $self = shift;
	$self->render_static('index.html');
}

1;
