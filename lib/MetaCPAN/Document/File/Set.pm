package MetaCPAN::Document::File::Set;

use Moose;

use MetaCPAN::ESConfig qw( es_doc_path );
use MetaCPAN::Util     qw( true false );

extends 'ElasticSearchX::Model::Document::Set';

sub find {
    my ( $self, $module ) = @_;

    my $query = {
        bool => {
            must => [
                { term => { indexed    => true } },
                { term => { authorized => true } },
                { term => { status     => 'latest' } },
                {
                    bool => {
                        should => [
                            { term => { documentation => $module } },
                            {
                                nested => {
                                    path  => "module",
                                    query => {
                                        bool => {
                                            must => [
                                                {
                                                    term => { "module.name" =>
                                                            $module }
                                                },
                                                {
                                                    bool => { should =>
                                                            [
                                                            { term =>
                                                                    { "module.authorized"
                                                                        => true
                                                                    } },
                                                            { exists =>
                                                                    { field =>
                                                                        'module.associated_pod'
                                                                    } },
                                                            ],
                                                    }
                                                },
                                            ],
                                        },
                                    },
                                }
                            },
                        ]
                    }
                },
            ],
        },
    };

    my $res = $self->es->search(
        es_doc_path('file'),
        search_type => 'dfs_query_then_fetch',
        body        => {
            query => $query,
            sort  => [
                '_score',
                { 'version_numified' => { order => 'desc' } },
                { 'date'             => { order => 'desc' } },
                { 'mime'             => { order => 'asc' } },
                { 'stat.mtime'       => { order => 'desc' } }
            ],
            _source => [
                qw( documentation module.indexed module.authoried module.name )
            ],
            size => 100,
        },
    );

    my @candidates = @{ $res->{hits}{hits} };

    my ($file) = grep {
        grep { $_->{indexed} && $_->{authorized} && $_->{name} eq $module }
            @{ $_->{module} || [] }
    } grep { !$_->{documentation} || $_->{documentation} eq $module }
        @candidates;

    $file ||= shift @candidates;
    return $file ? $self->get( $file->{_id} ) : undef;
}

sub find_pod {
    my ( $self, $name ) = @_;
    my $file = $self->find($name);
    return $file unless ($file);
    my ($module)
        = grep { $_->indexed && $_->authorized && $_->name eq $name }
        @{ $file->module || [] };
    if ( $module && ( my $pod = $module->associated_pod ) ) {
        my ( $author, $release, @path ) = split( /\//, $pod );
        return $self->get( {
            author  => $author,
            release => $release,
            path    => join( '/', @path ),
        } );
    }
    else {
        return $file;
    }
}

=head2 history

Find the history of a given module/documentation.

=cut

sub history {
    my ( $self, $type, $module, @path ) = @_;
    my $search
        = $type eq "module"
        ? $self->query( {
        nested => {
            path  => 'module',
            query => {
                constant_score => {
                    filter => {
                        bool => {
                            must => [
                                { term => { "module.authorized" => true } },
                                { term => { "module.indexed"    => true } },
                                { term => { "module.name" => $module } },
                            ]
                        }
                    }
                }
            }
        }
        } )
        : $type eq "file" ? $self->query( {
        bool => {
            must => [
                { term => { path         => join( "/", @path ) } },
                { term => { distribution => $module } },
            ]
        }
        } )

        # XXX: to fix: no filtering on 'release' so this query
        # will produce modules matching duplications. -- Mickey
        : $type eq "documentation" ? $self->query( {
        bool => {
            must => [
                { match_phrase => { documentation => $module } },
                { term         => { indexed       => true } },
                { term         => { authorized    => true } },
            ]
        }
        } )

        # clearly, one doesn't know what they want in this case
        : $self->query(
        bool => {
            must => [
                { term => { indexed    => true } },
                { term => { authorized => true } },
            ]
        }
        );
    return $search->sort( [ { date => 'desc' } ] );
}

__PACKAGE__->meta->make_immutable;
1;
