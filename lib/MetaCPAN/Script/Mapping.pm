package MetaCPAN::Script::Mapping;

use strict;
use warnings;

use Log::Contextual qw( :log );
use Moose;
use MetaCPAN::Types qw( Bool Str );
use Term::ANSIColor qw( colored );
use IO::Interactive qw( is_interactive );
use IO::Prompt;
use Cpanel::JSON::XS qw( decode_json );

use constant {
    EXPECTED     => 1,
    NOT_EXPECTED => 0,
};

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

has create_index => (
    is            => 'ro',
    isa           => Str,
    default       => "",
    documentation => 'create a new empty index (copy mappings)',
);

has patch_mapping => (
    is            => 'ro',
    isa           => Str,
    default       => "{}",
    documentation => 'type mapping patches',
);

has copy_to_index => (
    is            => 'ro',
    isa           => Str,
    default       => "",
    documentation => 'index to copy type to',
);

has copy_type => (
    is            => 'ro',
    isa           => Str,
    default       => "",
    documentation => 'type to copy',
);

has copy_query => (
    is            => 'ro',
    isa           => Str,
    default       => "",
    documentation => 'match query',
);

has reindex => (
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'reindex data from source index for exact mapping types',
);

has delete_index => (
    is            => 'ro',
    isa           => Str,
    default       => "",
    documentation => 'delete an existing index',
);

sub run {
    my $self = shift;
    $self->index_create   if $self->create_index;
    $self->index_delete   if $self->delete_index;
    $self->copy_index     if $self->copy_to_index;
    $self->types_list     if $self->list_types;
    $self->delete_mapping if $self->delete;
}

sub _check_index_exists {
    my ( $self, $name, $expected ) = @_;
    my $exists = $self->es->indices->exists( index => $name );

    if ( $exists and !$expected ) {
        log_error {"Index already exists: $name"};
        exit 0;
    }

    if ( !$exists and $expected ) {
        log_error {"Index doesn't exists: $name"};
        exit 0;
    }
}

sub index_delete {
    my $self = shift;
    my $name = $self->delete_index;

    $self->_check_index_exists( $name, EXPECTED );
    $self->_prompt("Index $name will be deleted !!!");

    log_info {"Deleting index: $name"};
    $self->es->indices->delete( index => $name );
}

sub index_create {
    my $self = shift;

    my $dst_idx = $self->create_index;
    $self->_check_index_exists( $dst_idx, NOT_EXPECTED );

    my $patch_mapping = decode_json $self->patch_mapping;
    my @patch_types   = sort keys %{$patch_mapping};
    my $dep           = $self->index->deployment_statement;
    my $mapping       = delete $dep->{mappings};

    # create the new index with the copied settings
    log_info {"Creating index: $dst_idx"};
    $self->es->indices->create( index => $dst_idx, body => $dep );

    # override with new type mapping
    if ( $self->patch_mapping ) {
        for my $type (@patch_types) {
            log_info {"Patching mapping for type: $type"};
            $mapping->{$type} = $patch_mapping->{$type};
        }
    }

    # add the mappings to the index
    for my $type ( sort keys %{$mapping} ) {
        log_info {"Adding mapping to index: $type"};
        $self->es->indices->put_mapping(
            index => $dst_idx,
            type  => $type,
            body  => { $type => $mapping->{$type} },
        );
    }

    # copy the data to the non-altered types
    if ( $self->reindex ) {
        for my $type (
            grep { !exists $patch_mapping->{$_} }
            sort keys %{$mapping}
            )
        {
            log_info {"Re-indexing data to index $dst_idx from type: $type"};
            my $bulk = $self->es->bulk_helper(
                index => $dst_idx,
                type  => $type,
            );
            $bulk->reindex( source => { index => $self->index->name }, );
            $bulk->flush;
        }
    }

    log_info {
        "Done. you can now fill the data for the altered types: ("
            . join( ',', @patch_types ) . ")"
    }
    if @patch_types;
}

sub copy_index {
    my $self = shift;
    my $type = $self->copy_type;
    $type or die "can't copy without a type\n";

    my $query = { match_all => {} };
    if ( $self->copy_query ) {
        eval {
            $query = decode_json $self->copy_query;
            1;
        } or do {
            my $err = $@ || 'zombie error';
            die $err;
        };
    }

    my $scroll = $self->es()->scroll_helper(
        search_type => 'scan',
        size        => 250,
        scroll      => '10m',
        index       => $self->index->name,
        type        => $type,
        body        => { query => { filtered => { query => $query } } },
    );

    my $bulk = $self->es->bulk_helper(
        index     => $self->copy_to_index,
        type      => $type,
        max_count => 500,
    );

    while ( my $search = $scroll->next ) {
        $bulk->create(
            {
                id     => $search->{_id},
                source => $search->{_source}
            }
        );
    }

    $bulk->flush;
}

sub types_list {
    my $self = shift;
    print "$_\n" for sort keys %{ $self->index->types };
}

sub delete_mapping {
    my $self = shift;

    $self->_prompt(
        'this will delete EVERYTHING and re-create the (empty) indexes');
    log_info {"Putting mapping to ElasticSearch server"};
    $self->model->deploy( delete => $self->delete );
}

sub _prompt {
    my ( $self, $msg ) = @_;

    if (is_interactive) {
        print colored( ['bold red'], "*** Warning ***: $msg" ), "\n";
        my $answer = prompt
            'Are you sure you want to do this (type "YES" to confirm) ? ';
        if ( $answer ne 'YES' ) {
            print "bye.\n";
            exit 0;
        }
        print "alright then...\n";
    }
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 SYNOPSIS

 # bin/metacpan mapping --delete
 # bin/metacpan mapping --list_types
 # bin/metacpan mapping --delete_index xxx
 # bin/metacpan mapping --create_index xxx --reindex
 # bin/metacpan mapping --create_index xxx --reindex --patch_mapping '{"distribution":{"dynamic":"false","properties":{"name":{"index":"not_analyzed","ignore_above":2048,"type":"string"},"river":{"properties":{"total":{"type":"integer"},"immediate":{"type":"integer"},"bucket":{"type":"integer"}},"dynamic":"true"},"bugs":{"properties":{"rt":{"dynamic":"true","properties":{"rejected":{"type":"integer"},"closed":{"type":"integer"},"open":{"type":"integer"},"active":{"type":"integer"},"patched":{"type":"integer"},"source":{"type":"string","ignore_above":2048,"index":"not_analyzed"},"resolved":{"type":"integer"},"stalled":{"type":"integer"},"new":{"type":"integer"}}},"github":{"dynamic":"true","properties":{"active":{"type":"integer"},"open":{"type":"integer"},"closed":{"type":"integer"},"source":{"type":"string","index":"not_analyzed","ignore_above":2048}}}},"dynamic":"true"}}}}'


=head1 DESCRIPTION

This is the index mapping handling script.
Used rarely, but carries the most important task of setting
the index and mapping the types.

=cut
