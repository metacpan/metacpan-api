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

has list_types => (
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'list available index type names',
);

sub run {
    my $self = shift;

    if ( $self->delete ) {
        $self->delete_mapping;
    }
    elsif ( $self->list_types ) {
        $self->list_available_types;
    }
}

sub list_available_types {
    my $self = shift;
    print "$_\n" for sort keys %{ $self->index->types };
}

sub delete_mapping {
    my $self = shift;

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

__PACKAGE__->meta->make_immutable;
1;
