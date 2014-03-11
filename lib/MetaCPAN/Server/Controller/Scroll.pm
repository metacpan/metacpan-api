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

    # There must be a better way to do this.
    if ( !defined($scroll_id) ) {
        try {
            $scroll_id = do { local $/; $req->body->getline() };
        }
        catch {
            print STDERR $_[0];
        };

        $scroll_id = ''
            unless defined $scroll_id;
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
