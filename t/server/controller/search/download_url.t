use strict;
use warnings;

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers;
use Test::More skip_all =>
    'Need to add CPAN::Test::Dummy::Perl5::VersionBump to CPAN::Faker and write tests';

test_psgi app, sub {
    my $cb = shift;

    # test ES script using doc['blah'] value
    {
        ok(
            my $res = $cb->(
                GET
                    '/download_url/CPAN::Test::Dummy::Perl5::VersionBump::Decrease'
            ),
            'GET'
        );
        my $json = decode_json_ok($res);

        use Data::Dump qw(pp);
        print STDERR ( pp( scalar $json ), "\n" );

        #        my $got
        #            = [ map { $_->{_source}{documentation} }
        #                @{ $json->{hits}{hits} } ];
        #
        #        is_deeply $got, [
        #            qw(
        #                Multiple::Modules
        #                Multiple::Modules::A
        #                Multiple::Modules::B
        #                Multiple::Modules::RDeps
        #                Multiple::Modules::Tester
        #                Multiple::Modules::RDeps::A
        #                Multiple::Modules::RDeps::Deprecated
        #                )
        #            ],
        #            'results are sorted by module name length'
        #            or diag( Test::More::explain($got) );
        #    }
    };
};

done_testing;
