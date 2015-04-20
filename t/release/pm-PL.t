use strict;
use warnings;

use MetaCPAN::Server::Test;
use Test::More;

my $model = model();
my $idx   = $model->index('cpan');

# Module::Faker will generate a regular pm for the main module.
is( $idx->type('file')->find('uncommon::sense')->path,
    'lib/uncommon/sense.pm', 'find main module' );

# This should be the .pm.PL file we specified.
ok( my $pm = $idx->type('file')->find('less::sense'),
    'find sense.pm.PL module' );

is( $pm->name, 'sense.pm.PL', 'name is correct' );

is(
    $pm->module->[0]->associated_pod,
    'MO/uncommon-sense-0.01/sense.pod',
    'has associated pod file'
);

# Ensure that $VERSION really came from file and not dist.
is( $pm->module->[0]->version,
    '4.56', 'pm.PL module version is (correctly) different than main dist' )

    # TRAVIS 5.16
    or diag( Test::More::explain( $pm->meta->get_data($pm) ) );

{
    # Verify all the files we expect to be contained in the release.
    my $files
        = $idx->type('file')
        ->filter( { term => { release => 'uncommon-sense-0.01' }, } )
        ->inflate(0)->size(20)->all->{hits}->{hits};
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
