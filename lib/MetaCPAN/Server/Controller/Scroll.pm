package MetaCPAN::Server::Controller::Scroll;

use strict;
use warnings;
use namespace::autoclean;

use Cpanel::JSON::XS qw( decode_json );
use MetaCPAN::Util   qw(true false simplify_total);
use Moose;
use Try::Tiny qw( catch try );

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub index : Path('/_search/scroll') : Args {
    my ( $self, $c, $scroll_id ) = @_;
    my $req = $c->req;

    if ( !defined($scroll_id) ) {
        try {
            if ( my $qs_id = $req->param('scroll_id') ) {
                $scroll_id = $qs_id;
            }
            elsif ( ref( my $body = $req->body ) ) {
                my $content = do { local $/; $body->getline };
                eval { $content = decode_json($content); };
                $scroll_id = ref $content ? $content->{scroll_id} : $content;
            }
            die "Scroll Id required\n"
                unless defined $scroll_id && !ref $scroll_id;
        }
        catch {
            chomp( my $e = $_[0] );
            $self->internal_error( $c, $e );
        };
    }

    if ( $scroll_id eq 'FAKE_SCROLL_ID' ) {
        $c->stash( {
            _scroll_id => $scroll_id,
            _shards    => {
                failed     => 0,
                successful => 0,
                total      => 0,
            },
            hits => {
                hits      => [],
                max_score => undef,
                total     => 0,
            },
            timed_out => false,
            took      => 0,
        } );
        return;
    }

    my $res = eval {
        $c->model('ES')->scroll(
            scroll => $c->req->params->{scroll},
            body   => {
                scroll_id => $scroll_id,
            },
        );
    } or do { $self->internal_error( $c, $@ ); };

    simplify_total($res);

    $c->stash($res);
}

1;
