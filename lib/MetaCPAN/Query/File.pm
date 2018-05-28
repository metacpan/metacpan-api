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
                    { not  => { prefix    => { 'path' => 'corpus/' } } },
                    { not  => { prefix    => { 'path' => 'fatlib/' } } },
                    { not  => { prefix    => { 'path' => 'inc/' } } },
                    { not  => { prefix    => { 'path' => 'local/' } } },
                    { not  => { prefix    => { 'path' => 'perl5/' } } },
                    { not  => { prefix    => { 'path' => 'share/' } } },
                    { not  => { prefix    => { 'path' => 't/' } } },
                    { not  => { prefix    => { 'path' => 'xt/' } } },
                    {
                        bool => {
                            should => [
                                {
                                    bool => {
                                        must => [
                                            { term => { level => 0 } },
                                            {
                                                terms => {
                                                    name => [
                                                        qw(
                                                            alienfile
                                                            AUTHORS
                                                            Build.PL
                                                            CHANGELOG
                                                            CHANGELOG.md
                                                            ChangeLog
                                                            ChangeLog.md
                                                            Changelog
                                                            Changelog.md
                                                            CHANGES
                                                            CHANGES.md
                                                            Changes
                                                            Changes.md
                                                            CONTRIBUTING
                                                            CONTRIBUTING.md
                                                            Contributing
                                                            COPYING
                                                            Copying
                                                            COPYRIGHT
                                                            cpanfile
                                                            CREDITS
                                                            DEVELOPMENT
                                                            DEVELOPMENT.md
                                                            Development
                                                            Development.md
                                                            dist.ini
                                                            FAQ
                                                            FAQ.md
                                                            HACKING
                                                            HACKING.md
                                                            Hacking
                                                            Hacking.md
                                                            INSTALL
                                                            INSTALL.md
                                                            LICENCE
                                                            LICENSE
                                                            MANIFEST
                                                            Makefile.PL
                                                            META.json
                                                            META.yml
                                                            minil.toml
                                                            NEWS
                                                            NEWS.md
                                                            README
                                                            README.markdown
                                                            README.md
                                                            README.mdown
                                                            README.mkdn
                                                            THANKS
                                                            TODO
                                                            TODO.md
                                                            ToDo
                                                            ToDo.md
                                                            Todo
                                                            Todo.md
                                                            )
                                                    ]
                                                }
                                            }
                                        ]
                                    }
                                },
                                {
                                    bool => {
                                        must => [
                                            {
                                                terms => {
                                                    name => [
                                                        qw(
                                                            CONTRIBUTING.pm
                                                            CONTRIBUTING.pod
                                                            Contributing.pm
                                                            Contributing.pod
                                                            ChangeLog.pm
                                                            ChangeLog.pod
                                                            Changelog.pm
                                                            Changelog.pod
                                                            CHANGES.pm
                                                            CHANGES.pod
                                                            Changes.pm
                                                            Changes.pod
                                                            HACKING.pm
                                                            HACKING.pod
                                                            Hacking.pm
                                                            Hacking.pod
                                                            TODO.pm
                                                            TODO.pod
                                                            ToDo.pm
                                                            ToDo.pod
                                                            Todo.pm
                                                            Todo.pod
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
