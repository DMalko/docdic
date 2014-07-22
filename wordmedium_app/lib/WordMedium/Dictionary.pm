package WordMedium::Dictionary;

use Mojo::Base 'Mojolicious::Controller';

sub body {
    
}

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
                sql => q{SELECT body FROM card WHERE keyword = ? AND source = ? AND target = ? ORDER BY card_id},
                val => [$word, $source, $target],
                cb => sub {
                    my ($rv, $sth) = @_;
                    
                    my $trns = {};
                    while(my ($card_body) = $sth->fetchrow_array()) {
                        push @{$trns->{wordCard}}, $card_body;
                    }
                    $end->($trns);
                }
            });
        },
        sub { # extra dictionaries
            my ($d, $trns) = @_;
            
            my $end = $d->begin(0);
            
            $self->core->do({
                sql => q{UPDATE user SET pass = ? WHERE uid = ?},
                val => [$crptpass, $uid],
                cb => sub {
                    my ($rv, $dbh) = @_;
                    $end->($uid, $new_password);
                }
            });
        },
        sub { # extra dictionaries
            my ($d, $trns) = @_;
            
            unless (keys %$trns) {
                $self->render(json => {trn => '', msg => 'Ooops! No entry.', msgtype => 'error'});
                return;
            }
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
