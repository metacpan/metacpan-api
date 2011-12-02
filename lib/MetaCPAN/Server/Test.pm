package MetaCPAN::Server::Test;

# ABSTRACT: Test class for MetaCPAN::Web

use strict;
use warnings;
use Plack::Test;
use HTTP::Request::Common qw(POST GET DELETE);
use JSON::XS;
use base 'Exporter';
our @EXPORT = qw(POST GET DELETE test_psgi app encode_json decode_json);

BEGIN { $ENV{METACPAN_SERVER_CONFIG_LOCAL_SUFFIX} = 'testing'; }

$FindBin::RealBin .= '/some';
my $app = require MetaCPAN::Server;
MetaCPAN::Server->model('User::Account')->put(
    {   identity      => [ { name   => 'pause',   key    => 'MO' } ],
        access_token => [ { client => 'testing', token => 'testing' } ]
    }, { refresh => 1 }
);
sub app {$app}

1;

=head1 ENVIRONMENTAL VARIABLES

Sets C<METACPAN_SERVER_CONFIG_LOCAL_SUFFIX> to C<testing>.

=head1 EXPORTS

=head2 GET

L<HTTP::Request::Common/GET>

=head2 test_psgi

L<Plack::Test/test_psgi>

=head2 app

Returns the L<MetaCPAN::Web> psgi app.
