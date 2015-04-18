use strict;
use warnings;

use FindBin;
use MetaCPAN::Model::Release;
use MetaCPAN::Script::Runner;
use MetaCPAN::TestHelpers qw( get_config );
use Test::More;

my $authordir = 't/var/tmp/fakecpan/authors/id/L/LO/LOCAL';

my $config = get_config();

my $ext = 'tar.gz';
foreach my $test (
    [ 'MetaFile-YAML-1.1', 'Module::Faker', ['META.yml'] ],
    [ 'MetaFile-JSON-1.1', 'hand',          ['META.json'] ],
    [ 'MetaFile-Both-1.1', 'hand',          [ 'META.json', 'META.yml' ] ],
    )
{
    my ( $name, $genby, $files ) = @$test;

    my $path = "$authordir/$name.$ext";
    die 'You need to build your fakepan (with t/fakepan.t) first'
        unless -e $path;

    my $release = MetaCPAN::Model::Release->new(
        logger => $config->{logger},
        level  => $config->{level},
        file   => $path
    );
    $release->set_logger_once;
    my $meta = $release->metadata;

    # some way to identify which file the meta came from
    like eval { $meta->generated_by }, qr/^$genby/,
        "correct meta spec version for $name";

    # Do this after calling metadata to ensure metadata does the
    # extraction.
    my $extract_dir = $release->extract;
    foreach my $file (@$files) {
        ok(
            -e $extract_dir->file( $name, $file ),
            "meta file $file exists in $name"
        );
    }
}

done_testing;
