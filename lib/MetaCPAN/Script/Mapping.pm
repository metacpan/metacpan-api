package MetaCPAN::Script::Mapping;

use strict;
use warnings;

use Log::Contextual qw( :log );
use Moose;
use MetaCPAN::Types qw( Bool );
use Term::ANSIColor qw( colored );
use IO::Interactive qw( is_interactive );
use IO::Prompt;

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has delete => (
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'delete index if it exists already',
);

sub run {
    my $self = shift;
    $self->delete_mapping;
}

sub delete_mapping {
    my $self = shift;
    return unless $self->delete;

    if (is_interactive) {
        print colored(
            ['bold red'],
            '*** Warning ***: this will delete EVERYTHING and re-create the (empty) indexes'
            ),
            "\n";
        my $answer = prompt
            'Are you sure you want to do this (type "YES" to confirm) ? ';
        if ( $answer ne 'YES' ) {
            print "bye.\n";
            exit 0;
        }
        print "alright then...\n";
    }
    log_info {"Putting mapping to ElasticSearch server"};
    $self->model->deploy( delete => $self->delete );
}

sub map_perlmongers {
    my ( $self, $es ) = @_;
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
1;
