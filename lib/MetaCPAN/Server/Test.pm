package MetaCPAN::Server::Test;

# ABSTRACT: Test class for MetaCPAN::Web

use strict;
use warnings;
use Plack::Test;
use HTTP::Request::Common;
use JSON::XS;
use Encode;
use MetaCPAN::Script::Runner;
use base 'Exporter';
our @EXPORT = qw(GET test_psgi app tx decode_json);

use MetaCPAN::Script::Server;
my $config = MetaCPAN::Script::Runner->build_config;
$config->{es} = '127.0.0.1:9200';

sub app { MetaCPAN::Script::Server->new_with_options($config)->build_app; }


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

=head2 tx($res)

Parses C<< $res->content >> and generates a L<Test::XPath> object.