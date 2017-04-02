use strict;
use warnings;

use Cpanel::JSON::XS qw( decode_json );
use MetaCPAN::Server::Test;
use MetaCPAN::TestServer;
use Test::More;

my $server = MetaCPAN::TestServer->new;
$server->index_permissions;

test_psgi app, sub {
    my $cb = shift;

    my $module_name = 'CPAN::Test::Dummy::Perl5::VersionBump';
    ok( my $res = $cb->( GET "/permission/$module_name" ),
        "GET $module_name" );
    is( $res->code, 200, '200 OK' );

   # The fakecpan 06perms doesn't have any authors who have co-maint, so can't
   # test that right now.

    is_deeply(
        decode_json( $res->content ),
        {
            co_maintainers => ['OALDERS'],
            module_name    => $module_name,
            owner          => 'MIYAGAWA',
        },
        'Owned by MIYAGAWA'
    );
};

done_testing;
