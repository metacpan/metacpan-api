package MetaCPAN::Server::Test;

use strict;
use warnings;

use HTTP::Request::Common qw(POST GET DELETE);
use Plack::Test;
use Test::More 0.96;

use base 'Exporter';
our @EXPORT = qw(
    POST GET DELETE
    model
    test_psgi app
);

BEGIN { $ENV{METACPAN_SERVER_CONFIG_LOCAL_SUFFIX} = 'testing'; }

sub _prepare_user_test_data {
    ok(
        my $user = MetaCPAN::Server->model('User::Account')->put(
            {
                access_token =>
                    [ { client => 'testing', token => 'testing' } ]
            }
        ),
        'prepare user'
    );
    ok( $user->add_identity( { name => 'pause', key => 'MO' } ),
        'add pause identity' );
    ok( $user->put( { refresh => 1 } ), 'put user' );

    ok(
        MetaCPAN::Server->model('User::Account')->put(
            { access_token => [ { client => 'testing', token => 'bot' } ] },
            { refresh      => 1 }
        ),
        'put bot user'
    );

}

# Begin the load-order dance.

my $app;

sub _load_app {

    # Delay loading.
    $app ||= require MetaCPAN::Server;
}

my $did_user_data;

sub prepare_user_test_data {

    # Only needed once.
    return if $did_user_data++;

    _load_app();

    subtest 'prepare user test data' => \&_prepare_user_test_data;
}

sub app {

    # Make sure this is done before the app is used.
    prepare_user_test_data();

    return $app;
}

require MetaCPAN::Model;

sub model {
    MetaCPAN::Model->new( es => ( $ENV{ES} ||= 'localhost:9900' ) );
}

1;

=pod

# ABSTRACT: Test class for MetaCPAN::Web

=head1 ENVIRONMENTAL VARIABLES

Sets C<METACPAN_SERVER_CONFIG_LOCAL_SUFFIX> to C<testing>.

=head1 EXPORTS

=head2 GET

L<HTTP::Request::Common/GET>

=head2 test_psgi

L<Plack::Test/test_psgi>

=head2 app

Returns the L<MetaCPAN::Web> psgi app.
