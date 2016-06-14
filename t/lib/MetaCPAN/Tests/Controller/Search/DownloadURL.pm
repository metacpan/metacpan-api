package MetaCPAN::Tests::Controller::Search::DownloadURL;

use strict;
use warnings;

use MetaCPAN::Server::Test;
use MetaCPAN::TestHelpers;
use Moose;
use Test::More;

sub run {
    test_psgi app, sub {
        my $cb = shift;

        my $module = 'CPAN::Test::Dummy::Perl5::VersionBump::Decrease';

        # test ES script using doc['blah'] value
        ok( my $res = $cb->( GET '/download_url/' . $module ),
            "GET $module" );
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
}

__PACKAGE__->meta->make_immutable;
1;
