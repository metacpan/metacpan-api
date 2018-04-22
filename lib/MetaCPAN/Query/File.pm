package MetaCPAN::Query::File;

use MetaCPAN::Moose;

use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );

with 'MetaCPAN::Query::Role::Common';

sub dir {
    my ( $self, $author, $release, @path ) = @_;

    my $body = {
        query => {
            bool => {
                must => [
                    { term => { 'level'   => scalar @path } },
                    { term => { 'author'  => $author } },
                    { term => { 'release' => $release } },
                    {
                        prefix => {
                            'path' => join( q{/}, @path, q{} )
                        }
                    },
                ]
            },
        },
        size   => 999,
        fields => [
            qw(name stat.mtime path stat.size directory slop documentation mime)
        ],
    };

    my $data = $self->es->search(
        {
            index => $self->index_name,
            type  => 'file',
            body  => $body,
        }
    );
    return unless $data->{hits}{total};

    my $dir = [ map { $_->{fields} } @{ $data->{hits}{hits} } ];
    single_valued_arrayref_to_scalar($dir);

    return { dir => $dir };
}

sub interesting_files {
    my ( $self, $author, $release ) = @_;

    my $body = {
        query => {
            bool => {
                must => [
                    { term => { release   => $release } },
                    { term => { author    => $author } },
                    { term => { directory => \0 } },
                    { not  => { prefix    => { 'path' => 'xt/' } } },
                    { not  => { prefix    => { 'path' => 't/' } } },
                    {
                        bool => {
                            should => [
                                {
                                    bool => {
                                        must => [
                                            {
                                                terms => {
                                                    name => [
                                                        qw(
                                                            AUTHORS
                                                            Build.PL
                                                            CHANGELOG
                                                            CHANGES
                                                            CONTRIBUTING
                                                            CONTRIBUTING.md
                                                            CONTRIBUTING.pod
                                                            Contributing.pm
                                                            Contributing.pod
                                                            COPYING
                                                            COPYRIGHT
                                                            CREDITS
                                                            ChangeLog
                                                            Changelog
                                                            Changes
                                                            Copying
                                                            FAQ
                                                            HACKING
                                                            HACKING.md
                                                            HACKING.pod
                                                            Hacking.pm
                                                            Hacking.pod
                                                            Hacking
                                                            INSTALL
                                                            INSTALL.md
                                                            LICENCE
                                                            LICENSE
                                                            MANIFEST
                                                            META.json
                                                            META.yml
                                                            Makefile.PL
                                                            NEWS
                                                            README
                                                            README.markdown
                                                            README.md
                                                            README.mdown
                                                            README.mkdn
                                                            THANKS
                                                            TODO
                                                            ToDo
                                                            Todo
                                                            cpanfile
                                                            alienfile
                                                            dist.ini
                                                            minil.toml
                                                            )
                                                    ]
                                                }
                                            }
                                        ]
                                    }
                                },
                                map {
                                    { prefix     => { 'name' => $_ } },
                                        { prefix => { 'path' => $_ } },

                                 # With "prefix" we don't need the plural "s".
                                    } qw(
                                    ex eg
                                    example Example
                                    sample
                                    )
                            ]
                        }
                    }
                ]
            }
        },

        # NOTE: We could inject author/release/distribution into each result
        # in the controller if asking ES for less data would be better.
        fields => [
            qw(
                name documentation path pod_lines
                author release distribution status
                )
        ],
        size => 250,
    };

    my $data = $self->es->search(
        {
            index => $self->index_name,
            type  => 'file',
            body  => $body,
        }
    );
    return unless $data->{hits}{total};

    my $files = [ map { $_->{fields} } @{ $data->{hits}{hits} } ];
    single_valued_arrayref_to_scalar($files);

    return {
        files => $files,
        total => $data->{hits}{total},
        took  => $data->{took}
    };
}

__PACKAGE__->meta->make_immutable;
1;
