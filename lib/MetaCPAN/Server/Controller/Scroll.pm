package MetaCPAN::Server::Controller::Scroll;

use strict;
use warnings;
use namespace::autoclean;

use Moose;
use Try::Tiny;

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
            else {
                # Is this the best way to get the body content?
                my $body = $req->body;
                $scroll_id = do { local $/; $body->getline }
                    if ref $body;
            }
            die "Scroll Id required\n" unless defined($scroll_id);
        }
        catch {
            chomp( my $e = $_[0] );
            $self->internal_error( $c, $e );
        };
    }

    my $res = eval {
        $c->model('CPAN')->es->transport->request(
            {
                method => $req->method,
                qs     => $req->parameters,

                # We could alternatively append "/$scroll_id" to the cmd.
                cmd => '/_search/scroll',

                # Pass reference to scalar as a non-ref will throw an error.
                data => \$scroll_id,
            }
        );
    } or do { $self->internal_error( $c, $@ ); };

    $c->stash($res);
}

1;
