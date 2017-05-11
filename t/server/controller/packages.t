use strict;
use warnings;

use Cpanel::JSON::XS qw( decode_json );
use MetaCPAN::Server::Test;
use MetaCPAN::TestServer;
use Test::More;

my $server = MetaCPAN::TestServer->new;
$server->index_packages;

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
                file =>
                    'M/MI/MIYAGAWA/CPAN-Test-Dummy-Perl5-VersionBump-0.02.tar.gz',
                author       => 'MIYAGAWA',
                distribution => 'CPAN-Test-Dummy-Perl5-VersionBump',
            },
            'Has the correct 02packages info'
        );
    }
};

done_testing;
