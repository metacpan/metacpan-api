use strict;
use warnings;
use lib 't/lib';

use MetaCPAN::TestHelpers qw( test_release );
use MetaCPAN::ESConfig    qw( es_doc_path );
use MetaCPAN::Util        qw( true false );
use Test::More;

test_release(
    {
        name        => 'Meta-Provides-1.01',
        author      => 'RWSTAUNER',
        abstract    => 'has provides key in meta',
        authorized  => true,
        first       => true,
        provides    => [ 'Meta::Provides', ],
        status      => 'latest',
        main_module => 'Meta::Provides',
        extra_tests => sub {

            my ($self) = @_;
            my $release = $self->data;

            my $res = $self->es->search(
                es_doc_path('file'),
                body => {
                    query => {
                        bool => {
                            must => [
                                {
                                    term => { 'author' => $release->{author} }
                                },
                                { term => { 'release' => $release->{name} } },
                                { term   => { 'directory' => false } },
                                { prefix => { 'path'      => 'lib/' } },
                            ],
                        },
                    },
                },
            );
            my @files = map $_->{_source}, @{ $res->{hits}{hits} };

            is( @files, 2, 'two files found in lib/' );

            @files = sort { $a->{name} cmp $b->{name} } @files;

            {
                my $not_indexed = shift @files;
                is $not_indexed->{name}, 'NotSpecified.pm',
                    'matching file name';
                is @{ $not_indexed->{module} }, 0,
                    'no modules (file not parsed)';
            }

            foreach my $test (
                [
                    'Provides.pm', 'Meta::Provides',
                    [ { name => 'Meta::Provides', indexed => true }, ]
                ],
                )
            {
                my ( $basename, $doc, $expmods ) = @$test;

                my $file = shift @files;
                ok $file, "file present (expecting $basename)"
                    or next;

                is( $file->{name},          $basename, 'file name' );
                is( $file->{documentation}, $doc,      'documentation ok' );

                is(
                    scalar @{ $file->{module} },
                    scalar @$expmods,
                    'correct number of modules'
                );

                foreach my $expmod (@$expmods) {
                    my $mod = shift @{ $file->{module} };
                    ok $mod, "module present (expecting $expmod->{name})"
                        or next;
                    is( $mod->{name}, $expmod->{name}, 'module name ok' );
                    is( $mod->{indexed}, $expmod->{indexed},
                        'module indexed (or not)' );
                }

                is( scalar @{ $file->{module} }, 0, 'all mods tested' );
            }

        },
    },
);

done_testing;
