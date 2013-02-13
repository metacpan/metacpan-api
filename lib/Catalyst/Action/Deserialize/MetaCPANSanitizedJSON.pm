package Catalyst::Action::Deserialize::MetaCPANSanitizedJSON;

use Moose;
use namespace::autoclean;
use Try::Tiny;
use MetaCPAN::Server::QuerySanitizer ();

extends 'Catalyst::Action::Deserialize::JSON';

around execute => sub {
    my ($orig, $self, $controller, $c) = @_;
    my $result;

    try {
        $result = $self->$orig($controller, $c);
        # if sucessfully serialized
        if( $result eq '1' ){
            # if we got something
            if( my $data = $c->req->data ){
                # clean it
                $c->req->data(MetaCPAN::Server::QuerySanitizer->new(
                    query => $data,
                )->query);
            }
        }
    }
    catch {
        my $e = $_[0];
        if( try { $e->isa('MetaCPAN::Server::QuerySanitizer::Error') } ){
            # this will return a 400 (text) through Catalyst::Action::Deserialize
            $result = $e->message;

            # this is our custom version (403) that returns json
            $c->detach("/not_allowed", [ $e->message ]);
        }
        else {
            $result = $e;
        }
    };

    return $result;
};

__PACKAGE__->meta->make_immutable;

1;
