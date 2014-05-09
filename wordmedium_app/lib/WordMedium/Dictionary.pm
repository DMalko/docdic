package WordMedium::Dictionary;

use Mojo::Base 'Mojolicious::Controller';

sub translate {
    my $self = shift;
    
    my $word = $self->req->param('trn_query');
    my $source = $self->req->param('trn_source');
    my $target = $self->req->param('trn_target');
    unless ($word && $source && $target) {
        $self->render(json => {trn => ''});
        return;
    }
    
    $self->render_later;
    my $delay = Mojo::IOLoop::Delay->new;
    $delay->steps(
        sub {
            my $d = shift;
            
            my $end = $d->begin(0);
            $self->dict->query({
                sql => q{SELECT body FROM card WHERE keyword = ? AND source = ? AND target = ?},
                val => [$word, $source, $target],
                cb => sub {
                    my ($rv, $sth) = @_;
                    
                    while(my ($card_body) = $sth->fetchrow_array()) {
                        
                        
                        
                        
                        if(1) {
                            $self->render(json => {msg => 'The user name already exists.', msgtype => 'error'});
                            $end->();
                            return;
                        }
                        
                        
                        
                    }
                    $end->(1);
                }
            });
        },
    );
    $delay->wait unless Mojo::IOLoop->is_running;
    return 1;
    
    if ($self->is_authenticated) {
        #
        my $uid = $self->uid;
    }
    
    
}


1;
