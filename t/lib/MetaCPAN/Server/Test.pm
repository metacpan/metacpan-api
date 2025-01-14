package MetaCPAN::Server::Test;

use strict;
use warnings;
use feature qw(state);

use HTTP::Request::Common        qw( DELETE GET POST );    ## no perlimports
use MetaCPAN::Model              ();
use MetaCPAN::Server             ();
use MetaCPAN::Server::Config     ();
use MooseX::Types::ElasticSearch qw( ES );
use Plack::Test;                                           ## no perlimports

use base 'Exporter';
our @EXPORT_OK = qw(
    POST GET DELETE
    es
    model
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

sub model {
    state $model = MetaCPAN::Model->new( es => es() );
}

sub query {
    state $query = MetaCPAN::Query->new( es => es() );
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
