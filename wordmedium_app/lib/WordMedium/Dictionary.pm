package WordMedium::Dictionary;

use Mojo::Base 'Mojolicious::Controller';

my $EXTRA_DICTIONARY_GROUP_NAME = 'extdict';

sub translate {
    my $self = shift;
    
    my $word = $self->req->param('trn_query');
    my $source = $self->req->param('trn_source');
    my $target = $self->req->param('trn_target');
    
    unless ($word && $source && $target) {
        $self->render(json => {msg => 'No word or phrase to translate.'});
        return;
    }
    
    $self->render_later;
    
    my ($trns, $extra);
    my $ingroups = $self->stash('ugroup') && (exists $self->stash('ugroup')->{$EXTRA_DICTIONARY_GROUP_NAME}) ? 1 : 0;
    
    #$self->app->log->debug("ingroups => $ingroups\n");
    my $delay = Mojo::IOLoop::Delay->new;
    $delay->steps(
        sub {# basic dictionary
            my $d = shift;
            
            my $end = $d->begin(0);
            $self->dict->query({
                sql => q{SELECT alias, body FROM card WHERE keyword = ? AND source = ? AND target = ? ORDER BY card_id},
                val => [$word, $source, $target],
                cb => sub {
                    my ($rv, $sth) = @_;
                    
                    while(my ($alias, $body) = $sth->fetchrow_array()) {
                        push @{$trns->{$alias}}, $body;
                    }
                    $end->();
                }
            });
            return 1;
        },
        sub {# extra dictionaries
            my $d = shift;
            
            my $end = $d->begin(0);
            if ($ingroups) {
                $self->dict->query({
                    sql => q{SELECT alias, body FROM dictionary WHERE keyword = ? AND source = ? AND target = ? ORDER BY card_id},
                    val => [$word, $source, $target],
                    cb => sub {
                        my ($rv, $sth) = @_;
                        
                        while(my ($alias, $body) = $sth->fetchrow_array()) {
                            push @{$extra->{$alias}}, $body;
                        }
                        $end->();
                    }
                });
            } else {
                $end->();
            }
            
            return 1;
        },
        sub {# guess and rendering
            my $d = shift;
            
            if ($trns || $extra) {
                $self->render(json => {word => $word, trn => $trns, extra => $extra});
            $self->app->log->debug("$trns->{WordMedium}[0]\n");
            } else { # let's guess what does the query means
# TO DO: fuzzy search across cards and dictionaries
# needed startup initialization of non-redundant keyword lists for `cards` and `cards+dictionaries` sets
                my $guess;
                if ($ingroups) {
                    # use non-redundant keyword list for cards+dictionaries 
                } else {
                    # use non-redundant keyword list only for cards
                }
                if ($guess) {
                    $self->render(json => {guess => $guess});
                } else {
                    $self->render(json => {msg => 'No translation.'});
                }
            }
            
            return;
        },
    );
    
    $delay->wait unless Mojo::IOLoop->is_running;
    return 1;
}


1;
