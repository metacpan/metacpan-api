use strict;
use warnings;
use lib 't/lib';

use Cpanel::JSON::XS qw( decode_json );
use MetaCPAN::Server::Test;
use MetaCPAN::TestServer;
use Test::More;

my $server = MetaCPAN::TestServer->new;

test_psgi app, sub {
    my $cb = shift;

    {
        my $module_name = 'CPAN::Test::Dummy::Perl5::VersionBump';
        ok( my $res = $cb->( GET "/permission/$module_name" ),
            "GET $module_name" );
        is( $res->code, 200, '200 OK' );

        is_deeply(
            decode_json( $res->content ),
            {
                co_maintainers => ['OALDERS'],
                module_name    => $module_name,
                owner          => 'MIYAGAWA',
            },
            'Owned by MIYAGAWA, OALDERS has co-maint'
        );
    }

    # Pod::Examples,RWSTAUNER,f
    {
        my $module_name = 'Pod::Examples';
        ok( my $res = $cb->( GET "/permission/$module_name" ),
            "GET $module_name" );
        is( $res->code, 200, '200 OK' );

        is_deeply(
            decode_json( $res->content ),
            {
                co_maintainers => [],
                module_name    => $module_name,
                owner          => 'RWSTAUNER',
            },
            'Owned by RWSTAUNER, no co-maint'
        );
    }
};

done_testing;
