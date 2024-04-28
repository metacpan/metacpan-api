package MetaCPAN::Server::Test;

use strict;
use warnings;

use HTTP::Request::Common    qw( DELETE GET POST );    ## no perlimports
use MetaCPAN::Model          ();
use MetaCPAN::Server         ();
use MetaCPAN::Server::Config ();
use Plack::Test;                                       ## no perlimports

use base 'Exporter';
our @EXPORT_OK = qw(
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

sub model {
    my $c = MetaCPAN::Server::Config::config();
    MetaCPAN::Model->new(
        es => { nodes => [ $c->{elasticsearch_servers} ] } );
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
