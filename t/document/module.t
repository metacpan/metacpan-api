use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::Document::Module ();
use Test::More;

subtest set_associated_pod => sub {
    test_associated_pod( 'Squirrel', [qw( lib/Squirrel.pod )],
        'lib/Squirrel.pod' );
    test_associated_pod( 'Squirrel::Face', [qw( lib/Face.pm )],
        'lib/Face.pm' );
    test_associated_pod( 'Squirrel::Face', [qw( bin/sf.pl )], 'bin/sf.pl' );

    test_associated_pod( 'Squirrel::Face', [qw( bin/sf.pl lib/Face.pm )],
        'lib/Face.pm', 'prefer .pm', );

    test_associated_pod( 'Squirrel::Face',
        [qw( bin/sf.pl lib/Face.pm lib/Squirrel.pod )],
        'lib/Squirrel.pod', 'prefer .pod', );

    test_associated_pod(
        'Squirrel::Face', [qw( bin/sf.pl lib/Face.pm README.pod )],
        'lib/Face.pm',    'prefer .pm to README.pod',
    );

    test_associated_pod(
        'Squirrel::Face', [qw( Zoob.pod README.pod )],
        'Zoob.pod',       'prefer any .pod to README.pod',
    );

    test_associated_pod(
        'Squirrel::Face', [qw( narf.pl README.pod )],
        'narf.pl',        'prefer .pl to README.pod',
    );

    # This goes along with the Pod::With::Generator tests.
    # Since file order is not reliable (there) we can't get a reliable failure
    # so test here so that we can ensure the order.
    test_associated_pod(
        'Foo::Bar',       [qw( a/b.pm x/Foo/Bar.pm lib/Foo/Bar.pm )],
        'lib/Foo/Bar.pm', 'prefer lib/ with matching name to other files',
    );
};

{

    package PodFile;    ## no critic
    sub new       { bless { path => $_[1] }, $_[0]; }
    sub path      { $_[0]->{path} }
    sub name      { $_[0]->{name} ||= ( $_[0]->{path} =~ m{([^\/]+)$} )[0] }
    sub full_path { '.../' . $_[0]->{path} }
}

sub test_associated_pod {
    my ( $name, $files, $exp, $desc ) = @_;
    my $module = MetaCPAN::Document::Module->new( name => $name );
    $module->set_associated_pod(
        { $name => [ map { PodFile->new($_) } @$files ] } );
    is $module->associated_pod, ".../$exp", $desc || 'Best pod file selected';
}

done_testing;
