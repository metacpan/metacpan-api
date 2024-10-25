package MetaCPAN::Document::Release::Set;

use Moose;

use MetaCPAN::Query::Release ();

extends 'ElasticSearchX::Model::Document::Set';

has query_release => (
    is      => 'ro',
    isa     => 'MetaCPAN::Query::Release',
    lazy    => 1,
    builder => '_build_query_release',
    handles => [ qw<
        activity
        all_by_author
        author_status
        by_author
        by_author_and_name
        by_author_and_names
        find
        get_contributors
        get_files
        latest_by_author
        latest_by_distribution
        modules
        predecessor
        recent
        requires
        reverse_dependencies
        top_uploaders
        versions
    > ],
);

sub _build_query_release {
    my $self = shift;
    return MetaCPAN::Query::Release->new(
        es         => $self->es,
        index_name => $self->index->name,
    );
}

sub find_github_based {
    shift->query( {
        bool => {
            must => [
                { term => { status => 'latest' } },
                {
                    bool => {
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
                        ],
                    }
                },
            ],
        },
    } );
}

__PACKAGE__->meta->make_immutable;
1;
