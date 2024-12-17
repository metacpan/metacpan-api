use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::ESConfig     qw( es_doc_path );
use MetaCPAN::Server::Test qw( app GET query es test_psgi );
use Test::More;

my $query = query();

# Module::Faker will generate a regular pm for the main module.
is( $query->file->find_module('uncommon::sense')->{path},
    'lib/uncommon/sense.pm', 'find main module' );

# This should be the .pm.PL file we specified.
ok( my $pm = $query->file->find_module('less::sense'),
    'find sense.pm.PL module' );

is( $pm->{name}, 'sense.pm.PL', 'name is correct' );

is(
    $pm->{module}->[0]->{associated_pod},
    'MO/uncommon-sense-0.01/sense.pod',
    'has associated pod file'
);

# Ensure that $VERSION really came from file and not dist.
is( $pm->{module}->[0]->{version},
    '4.56', 'pm.PL module version is (correctly) different than main dist' )

    # TRAVIS 5.16
    or diag($pm);

{
    # Verify all the files we expect to be contained in the release.
    my $files = es->search(
        es_doc_path('file'),
        body => {
            query => {
                term => { release => 'uncommon-sense-0.01' },
            },
            size => 20,
        },
    )->{hits}->{hits};
    $files = [ map { $_->{_source} } @$files ];

    is_deeply(
        [ sort grep {/\.(pm|pod|pm\.PL)$/} map { $_->{path} } @$files ],
        [
            sort qw(
                lib/uncommon/sense.pm
                sense.pod
                sense.pm.PL
            )
        ],
        'release contains expected files',
    );

    test_psgi app, sub {
        my $cb  = shift;
        my $res = $cb->( GET '/source/MO/uncommon-sense-0.01/sense.pm.PL' );
        is $res->code, 200, '200 OK';
        chomp( my $content = $res->content );

        is(
            $content,
            "#! perl-000\n\nour \$VERSION = '4.56';\n\n__DATA__\npackage less::sense;",
            '.pm.PL file unmodified',
        );
    };
}

done_testing;
