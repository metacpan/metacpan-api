use strict;
use warnings;
use lib 't/lib';

use Cpanel::JSON::XS       qw( decode_json );
use MetaCPAN::Server::Test qw( app GET test_psgi );
use MetaCPAN::TestServer   ();
use Test::More;

my $server = MetaCPAN::TestServer->new;

test_psgi app, sub {
    my $cb = shift;

    {
        my $module_name = 'CPAN::Test::Dummy::Perl5::VersionBump';
        ok( my $res = $cb->( GET "/package/$module_name" ),
            "GET $module_name" );
        is( $res->code, 200, '200 OK' );

        is_deeply(
            decode_json( $res->content ),
            {
                module_name => $module_name,
                version     => '0.02',
                file        =>
                    'M/MI/MIYAGAWA/CPAN-Test-Dummy-Perl5-VersionBump-0.02.tar.gz',
                author       => 'MIYAGAWA',
                distribution => 'CPAN-Test-Dummy-Perl5-VersionBump',
                dist_version => '0.02',
            },
            'Has the correct 02packages info'
        );
    }

    {
        my $dist = 'File-Changes-UTF8';
        ok( my $res = $cb->( GET "/package/modules/$dist" ),
            "GET modules/$dist" );
        is( $res->code, 200, '200 OK' );
        is_deeply(
            decode_json( $res->content ),
            {
                modules => ['File::Changes::UTF8'],
            },
            'Can list modules of latest release'
        );
    }
};

done_testing;
