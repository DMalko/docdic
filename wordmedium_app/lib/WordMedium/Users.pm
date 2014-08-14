package Users;

use Mojo::Base 'Mojolicious::Controller';
use EV;
use Mojo::IOLoop;

sub groups {
    my $self = shift;
    
    $self->render_later;
    
    my %groups = ();
    my $uid = $self->uid;
    unless($uid) {
        $self->stash(ugroup => \%groups);
        return 1;
    }
    
    $self->core->query({
        sql => q{SELECT gname FROM group WHERE uid = ?},
        val => [$uid],
        cb => sub {
            my ($rv, $sth) = @_;
            while (my ($group) = $sth->fetchrow_array()) {
                $groups{$group} = 1;
            }
            $self->stash(ugroup => \%groups);
        }
    });
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
    return 1;
}


1;
