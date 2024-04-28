package MetaCPAN::Server::Test;

use strict;
use warnings;

use HTTP::Request::Common qw( DELETE GET POST ); ## no perlimports
use MetaCPAN::Config      ();
use MetaCPAN::Server      ();
use Plack::Test           qw( test_psgi );          ## no perlimports
use Test::More;

use base 'Exporter';
our @EXPORT = qw(
    POST GET DELETE
    model
    test_psgi app
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

use MetaCPAN::Model ();

sub model {
    MetaCPAN::Model->new(
        es => (
            $ENV{ES_TEST}
                ||= MetaCPAN::Config::config()->{elasticsearch_servers}
        )
    );
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
