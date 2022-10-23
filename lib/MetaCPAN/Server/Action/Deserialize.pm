package MetaCPAN::Server::Action::Deserialize;
use Moose;
extends 'Catalyst::Action::Deserialize';
use Cpanel::JSON::XS qw(encode_json);

around serialize_bad_request => sub {
    my $orig = shift;
    my $self = shift;
    my ( $c, $content_type, $error ) = @_;

    $c->res->status(400);

    my $full_error
        = "Content-Type $content_type had a problem with your request.\n$error";
    $full_error =~ s{ at .*? line \d+\.\n\z}{};

    $c->stash( {
        rest => {
            error => $full_error,
        },
    } );

    return undef;
};

1;
