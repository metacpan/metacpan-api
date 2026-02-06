package MetaCPAN::Server::Test;

use strict;
use warnings;
use feature qw(state);

use Carp                     qw( croak );
use HTTP::Request::Common    qw( DELETE GET POST );    ## no perlimports
use MetaCPAN::ESConfig       qw( es_doc_path );
use MetaCPAN::Server         ();
use MetaCPAN::Server::Config ();
use MetaCPAN::Types          qw( ES );
use MetaCPAN::Util           qw( hit_total );
use Plack::Test;                                       ## no perlimports

use base 'Exporter';
our @EXPORT_OK = qw(
    POST GET DELETE
    es
    es_result
    test_psgi app
    query
);

# Begin the load-order dance.

my $app;

sub _load_app {

    # Delay loading.
    $app ||= MetaCPAN::Server->to_app;
}

sub prepare_user_test_data {
    _load_app();
}

sub app {

    # Make sure this is done before the app is used.
    prepare_user_test_data();

    return $app;
}

sub es {
    state $es = do {
        my $c = MetaCPAN::Server::Config::config();
        ES->assert_coerce( $c->{elasticsearch_servers} );
    };
}

sub query {
    state $query = MetaCPAN::Query->new( es => es() );
}

sub es_result {
    my ( $type, $query, $size ) = @_;
    $size //= wantarray ? 999 : 1;
    if ( !wantarray && $size != 1 ) {
        croak "multiple results requested with scalar return!";
    }
    my $res = es()->search(
        es_doc_path($type),
        body => {
            size  => ( wantarray ? 999 : 1 ),
            query => $query,
        },
    );
    my @hits = map $_->{_source}, @{ $res->{hits}{hits} };
    if ( !wantarray ) {
        croak "query did not return a single result"
            if hit_total($res) != 1;
        return $hits[0];
    }
    return @hits;
}

1;

=pod

# ABSTRACT: Test class for MetaCPAN::Web

=head1 EXPORTS

=head2 GET

L<HTTP::Request::Common/GET>

=head2 test_psgi

L<Plack::Test/test_psgi>

=head2 app

Returns the L<MetaCPAN::Web> psgi app.
