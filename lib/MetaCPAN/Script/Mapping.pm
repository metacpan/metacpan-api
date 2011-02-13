package MetaCPAN::Script::Mapping;

use Moose;
with 'MooseX::Getopt';
use MetaCPAN;

use MetaCPAN::Document::Author;
use MetaCPAN::Document::Release;
use MetaCPAN::Document::Distribution;
use MetaCPAN::Document::File;
use MetaCPAN::Document::Module;
use MetaCPAN::Document::Dependency;

sub run {
    shift->put_mappings(MetaCPAN->new->es);
}

sub put_mappings {
    my ($self, $es) = @_;
    # do not delete mappings, this will delete the data as well
    # ElasticSearch merges new mappings
    MetaCPAN::Document::Author->meta->put_mapping( $es );
    MetaCPAN::Document::Release->meta->put_mapping( $es );
    MetaCPAN::Document::Distribution->meta->put_mapping( $es );
    MetaCPAN::Document::File->meta->put_mapping( $es );
    MetaCPAN::Document::Module->meta->put_mapping( $es );
    MetaCPAN::Document::Dependency->meta->put_mapping( $es );
    $self->map_cpanratings( $es );
    $self->map_pod( $es );

    return;

}

sub map_pod {
    my ($self, $es) = @_;
    return $es->put_mapping(
        index      => ['cpan'],
        type       => 'pod',
        properties => {
            html     => { type => "string" },
            pure_pod => { type => "string" },
            text     => { type => "string" },
        },
    );

}

sub map_cpanratings {
    my ($self, $es) = @_;
    return $es->put_mapping(
        index      => ['cpan'],
        type       => 'cpanratings',
        properties => {
            dist         => { type => "string" },
            rating       => { type => "string" },
            review_count => { type => "string" },
        },

    );

}

sub map_perlmongers {
    my ($self, $es) = @_;
    return $es->put_mapping(
        index      => ['cpan'],
        type       => 'perlmongers',
        properties => {
            city      => { type       => "string" },
            continent => { type       => "string" },
            email     => { properties => { type => { type => "string" } } },
            inception_date =>
                { format => "dateOptionalTime", type => "date" },
            latitude => { type => "object" },
            location => {
                properties => {
                    city      => { type => "string" },
                    continent => { type => "string" },
                    country   => { type => "string" },
                    latitude  => { type => "string" },
                    longitude => { type => "string" },
                    region    => { type => "object" },
                    state     => { type => "string" },
                },
            },
            longitude    => { type => "object" },
            mailing_list => {
                properties => {
                    email => {
                        properties => {
                            domain => { type => "string" },
                            type   => { type => "string" },
                            user   => { type => "string" },
                        },
                    },
                    name => { type => "string" },
                },
            },
            name   => { type => "string" },
            pm_id  => { type => "string" },
            region => { type => "string" },
            state  => { type => "object" },
            status => { type => "string" },
            tsar   => {
                properties => {
                    email => {
                        properties => {
                            domain => { type => "string" },
                            type   => { type => "string" },
                            user   => { type => "string" },
                        },
                    },
                    name => { type => "string" },
                },
            },
            web => { type => "string" },
        },

    );

}



__PACKAGE__->meta->make_immutable;