use strict;
use warnings;
use Test::More;
use MetaCPAN::Script::Runner;
use MetaCPAN::Script::Release;
use FindBin;
use File::Temp qw( tempdir );
use File::Spec::Functions qw( catfile );
use Archive::Any;

my $authordir = "t/var/tmp/fakecpan/authors/id/L/LO/LOCAL";

my $config = do {

    # build_config expects test to be t/*.t
    local $FindBin::RealBin = "$FindBin::RealBin/../..";
    MetaCPAN::Script::Runner->build_config;
};

my $script = MetaCPAN::Script::Release->new($config);
my $root = tempdir( CLEANUP => 1, TMPDIR => 1 );

my $ext = 'tar.gz';
foreach my $test (
    [ 'MetaFile-YAML-1.1', 'Module::Faker', ['META.yml'] ],
    [ 'MetaFile-JSON-1.1', 'hand',          ['META.json'] ],
    [ 'MetaFile-Both-1.1', 'hand',          [ 'META.json', 'META.yml' ] ],
    )
{
    my ( $name, $genby, $files ) = @$test;

    my $path = "$authordir/$name.$ext";
    die "You need to build your fakepan (with t/fakepan.t) first"
        unless -e $path;

    my $archive = Archive::Any->new($path);
    my $tmpdir = tempdir( DIR => $root );
    $archive->extract($tmpdir);

    my $meta = $script->load_meta_file($tmpdir);

    # some way to identify which file the meta came from
    like eval { $meta->generated_by }, qr/^$genby/,
        "correct meta spec version for $name";

    foreach my $file (@$files) {
        ok( -e catfile( $tmpdir, $name, $file ),
            "meta file $file exists in $name"
        );
    }
}

done_testing;
