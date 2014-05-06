package WordMedium::Dictionary;

use Mojo::Base 'Mojolicious::Controller';

sub translate {
    my $self = shift;
    my $word = shift;
    
    if ($self->is_authenticated) {
        #
    }
    
}


1;
