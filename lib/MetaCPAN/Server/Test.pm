package MetaCPAN::Server::Test;

# ABSTRACT: Test class for MetaCPAN::Web

use strict;
use warnings;
use Plack::Test;
use HTTP::Request::Common;
use JSON::XS;
use base 'Exporter';
our @EXPORT = qw(POST GET test_psgi app decode_json);

BEGIN { $ENV{METACPAN_SERVER_CONFIG_LOCAL_SUFFIX} = 'testing'; }

my $app = require MetaCPAN::Server;
sub app { $app }


1;

=head1 ENVIRONMENTAL VARIABLES

Sets C<PLACK_TEST_IMPL> to C<Server> and C<PLACK_SERVER> to C<Twiggy>.

=head1 EXPORTS

=head2 GET

L<HTTP::Request::Common/GET>

=head2 test_psgi

L<Plack::Test/test_psgi>

=head2 app

Returns the L<MetaCPAN::Web> psgi app.