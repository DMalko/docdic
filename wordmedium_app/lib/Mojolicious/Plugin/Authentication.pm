package Mojolicious::Plugin::Authentication;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my $plugin = shift;
    my $app = shift;
    my $attr = shift;
    
    $attr->{session_key} ||= 'auth';
    $attr->{stash_key}   ||= '__auth__';
    
    $app->attr(auth_session_key => sub {return $attr->{session_key}});
    $app->attr(auth_stash_key => sub {return $attr->{stash_key}});
    
    $app->helper(authenticate => sub {
        my $self = shift;
        my $uid = shift;
        
        $self->session($attr->{session_key} => $uid);
        $self->stash($attr->{stash_key} => $uid);
        return 1;
    });
    
    $app->helper(logout => sub {
        my $self = shift;
        
        $self->session(expires => 1);
        delete $self->stash->{$attr->{stash_key}};
        delete $self->session->{$attr->{session_key}};
        return 1;
    });
    
    $app->helper(is_authenticated => sub {
        my $self = shift;
        return defined $self->session($attr->{session_key});
    });
    
    $app->helper(uid => sub {
        my $self = shift;
        return $self->session($attr->{session_key});
    });
    
#### !!!! is the hook helpful?
#    $app->hook(before_dispatch => sub {
#        my $self = shift;
#        
#        if (defined $self->session($attr->{session_key})) {
#            my $uid = $self->session($attr->{session_key});
#            $self->stash($attr->{stash_key} => $uid);
#        }
#        return 1;
#    });
}


1;
