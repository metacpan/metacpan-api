package MetaCPAN::Document::Release::Set;

use Moose;

use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );

use MetaCPAN::Query::Release;

with 'MetaCPAN::Role::ES';

has query_release => (
    is      => 'ro',
    isa     => 'MetaCPAN::Query::Release',
    lazy    => 1,
    builder => '_build_query_release',
    handles => [
        qw<
            activity
            all_by_author
            author_status
            by_author
            by_author_and_name
            by_author_and_names
            get_contributors
            get_files
            latest_by_author
            latest_by_distribution
            modules
            recent
            requires
            reverse_dependencies
            top_uploaders
            versions
            >
    ],
);

sub _build_query_release {
    my $self = shift;

    return MetaCPAN::Query::Release->new(
        es         => $self->es,
        index_name => 'cpan',
    );
}

sub find {
    my ( $self, $name ) = @_;
    my $file = $self->filter(
        {
            and => [
                { term => { distribution => $name } },
                { term => { status       => 'latest' } }
            ]
        }
    )->sort( [ { date => 'desc' } ] )->raw->first;
    return unless $file;

    my $data = $file->{_source}
        || single_valued_arrayref_to_scalar( $file->{fields} );
    return $data;
}

sub predecessor {
    my ( $self, $name ) = @_;
    return $self->filter(
        {
            and => [
                { term => { distribution => $name } },
                { not => { filter => { term => { status => 'latest' } } } },
            ]
        }
    )->sort( [ { date => 'desc' } ] )->first;
}

sub get_scroller_github_based {
    my ($self) = @_;

    return $self->es->scroll_helper(
        index       => $self->index_name,
        type        => 'release',
        search_type => 'scan',
        scroll      => '5m',
        size        => 500,
        body        => {
            query => {
                bool => {
                    must => [
                        { term => { status => 'latest' } },
                        {
                            or => {
                                should => [
                                    {
                                        prefix => {
                                            "resources.bugtracker.web" =>
                                                'http://github.com/'
                                        }
                                    },
                                    {
                                        prefix => {
                                            "resources.bugtracker.web" =>
                                                'https://github.com/'
                                        }
                                    },
                                ]
                            }
                        }
                    ]
                }
            }
        },
    );
}

__PACKAGE__->meta->make_immutable;
1;
