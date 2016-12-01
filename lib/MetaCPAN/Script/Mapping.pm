package MetaCPAN::Script::Mapping;

use strict;
use warnings;

use Log::Contextual qw( :log );
use Moose;
use MetaCPAN::Types qw( Bool Str );
use Cpanel::JSON::XS qw( decode_json );
use DateTime;

use MetaCPAN::Script::Mapping::DeployStatement;
use MetaCPAN::Script::Mapping::Cpan::Author;
use MetaCPAN::Script::Mapping::Cpan::Distribution;
use MetaCPAN::Script::Mapping::Cpan::Favorite;
use MetaCPAN::Script::Mapping::Cpan::File;
use MetaCPAN::Script::Mapping::Cpan::Mirror;
use MetaCPAN::Script::Mapping::Cpan::Rating;
use MetaCPAN::Script::Mapping::Cpan::Release;
use MetaCPAN::Script::Mapping::User::Account;
use MetaCPAN::Script::Mapping::User::Identity;
use MetaCPAN::Script::Mapping::User::Session;

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

has update_index => (
    is            => 'ro',
    isa           => Str,
    default       => "",
    documentation => 'update existing index (add mappings)',
);

has patch_mapping => (
    is            => 'ro',
    isa           => Str,
    default       => "{}",
    documentation => 'type mapping patches',
);

has skip_existing_mapping => (
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'do NOT copy mappings other than patch_mapping',
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
    documentation => 'match query (default: monthly time slices, '
        . ' if provided must be a valid json query OR "match_all")',
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

has delete_from_type => (
    is            => 'ro',
    isa           => Str,
    default       => "",
    documentation => 'delete data from an existing type',
);

sub run {
    my $self = shift;
    $self->index_create   if $self->create_index;
    $self->index_delete   if $self->delete_index;
    $self->index_update   if $self->update_index;
    $self->type_copy      if $self->copy_to_index;
    $self->type_empty     if $self->delete_from_type;
    $self->types_list     if $self->list_types;
    $self->deploy_mapping if $self->delete;
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
    $self->are_you_sure("Index $name will be deleted !!!");

    $self->_index_delete($name);
}

sub _index_delete {
    my ( $self, $name ) = @_;
    log_info {"Deleting index: $name"};
    $self->es->indices->delete( index => $name );
}

sub index_update {
    my $self = shift;
    my $name = $self->update_index;

    $self->_check_index_exists( $name, EXPECTED );
    $self->are_you_sure("Index $name will be updated !!!");

    die "update_index requires patch_mapping\n"
        unless $self->patch_mapping;

    my $patch_mapping    = decode_json $self->patch_mapping;
    my @patch_types      = sort keys %{$patch_mapping};
    my $dep              = $self->index->deployment_statement;
    my $existing_mapping = delete $dep->{mappings};
    my $mapping = +{ map { $_ => $patch_mapping->{$_} } @patch_types };

    log_info {"Updating mapping for index: $name"};

    for my $type ( sort keys %{$mapping} ) {
        log_info {"Adding mapping to index: $type"};
        $self->es->indices->put_mapping(
            index => $self->index->name,
            type  => $type,
            body  => { $type => $mapping->{$type} },
        );
    }

    log_info {"Done."};
}

sub index_create {
    my $self = shift;

    my $dst_idx = $self->create_index;
    $self->_check_index_exists( $dst_idx, NOT_EXPECTED );

    my $patch_mapping    = decode_json $self->patch_mapping;
    my @patch_types      = sort keys %{$patch_mapping};
    my $dep              = $self->index->deployment_statement;
    my $existing_mapping = delete $dep->{mappings};
    my $mapping = $self->skip_existing_mapping ? +{} : $existing_mapping;

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
            $self->type_copy( $dst_idx, $type );
        }
    }

    log_info {
        "Done. you can now fill the data for the altered types: ("
            . join( ',', @patch_types ) . ")"
    }
    if @patch_types;
}

sub type_copy {
    my ( $self, $index, $type ) = @_;
    $index //= $self->copy_to_index;

    $self->_check_index_exists( $index, EXPECTED );
    $type //= $self->copy_type;
    $type or die "can't copy without a type\n";

    my $arg_query = $self->copy_query;
    my $query
        = $arg_query eq 'match_all'
        ? +{ match_all => {} }
        : undef;

    if ( $arg_query and !$query ) {
        eval {
            $query = decode_json $arg_query;
            1;
        } or do {
            my $err = $@ || 'zombie error';
            die $err;
        };
    }

    return $self->_copy_slice( $query, $index, $type ) if $query;

    # else ... do copy by monthly slices

    my $dt = DateTime->new( year => 1994, month => 1 );
    my $end_time = DateTime->now()->add( months => 1 );

    while ( $dt < $end_time ) {
        my $gte = $dt->strftime("%Y-%m");
        $dt->add( months => 1 );
        my $lt = $dt->strftime("%Y-%m");

        my $q = +{ range => { date => { gte => $gte, lt => $lt } } };

        log_info {"copying data for month: $gte"};
        eval {
            $self->_copy_slice( $q, $index, $type );
            1;
        } or do {
            my $err = $@ || 'zombie error';
            warn $err;
        };
    }
}

sub _copy_slice {
    my ( $self, $query, $index, $type ) = @_;

    my $scroll = $self->es()->scroll_helper(
        search_type => 'scan',
        size        => 250,
        scroll      => '10m',
        index       => $self->index->name,
        type        => $type,
        body        => {
            query => {
                filtered => {
                    query => $query
                }
            }
        },
    );

    my $bulk = $self->es->bulk_helper(
        index     => $index,
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

sub type_empty {
    my $self = shift;

    my $bulk = $self->es->bulk_helper(
        index     => $self->index->name,
        type      => $self->delete_from_type,
        max_count => 500,
    );

    my $scroll = $self->es()->scroll_helper(
        search_type => 'scan',
        size        => 250,
        scroll      => '10m',
        index       => $self->index->name,
        type        => $self->delete_from_type,
        body        => { query => { match_all => {} } },
    );

    my @ids;
    while ( my $search = $scroll->next ) {
        push @ids => $search->{_id};

        if ( @ids == 500 ) {
            $bulk->delete_ids(@ids);
            @ids = ();
        }
    }
    $bulk->delete_ids(@ids);

    $bulk->flush;
}

sub types_list {
    my $self = shift;
    print "$_\n" for sort keys %{ $self->index->types };
}

sub deploy_mapping {
    my $self     = shift;
    my $es       = $self->es;
    my $idx_cpan = 'cpan_v1_01';
    my $idx_user = 'user';

    $self->are_you_sure(
        'this will delete EVERYTHING and re-create the (empty) indexes');

    # delete cpan (aliased) + user indices

    $self->_index_delete($idx_user)
        if $es->indices->exists( index => $idx_user );
    $self->_index_delete($idx_cpan)
        if $es->indices->exists( index => $idx_cpan );

    # create new indices

    my $dep = decode_json MetaCPAN::Script::Mapping::DeployStatement::mapping;

    log_info {"Creating index: user"};
    $es->indices->create( index => $idx_user, body => $dep );

    log_info {"Creating index: $idx_cpan"};
    $es->indices->create( index => $idx_cpan, body => $dep );

    # create type mappings

    my %mappings = (
        $idx_cpan => {
            author =>
                decode_json(MetaCPAN::Script::Mapping::Cpan::Author::mapping),
            distribution =>
                decode_json( MetaCPAN::Script::Mapping::Cpan::Distribution::mapping
                ),
            favorite =>
                decode_json( MetaCPAN::Script::Mapping::Cpan::Favorite::mapping
                ),
            file =>
                decode_json(MetaCPAN::Script::Mapping::Cpan::File::mapping),
            rating =>
                decode_json(MetaCPAN::Script::Mapping::Cpan::Rating::mapping),
            release =>
                decode_json( MetaCPAN::Script::Mapping::Cpan::Release::mapping
                ),
        },
        $idx_user => {
            account =>
                decode_json( MetaCPAN::Script::Mapping::User::Account::mapping
                ),
            identity =>
                decode_json( MetaCPAN::Script::Mapping::User::Identity::mapping
                ),
            session =>
                decode_json( MetaCPAN::Script::Mapping::User::Session::mapping
                ),
        },
    );

    for my $idx ( sort keys %mappings ) {
        for my $type ( sort keys %{ $mappings{$idx} } ) {
            log_info {"Adding mapping: $idx/$type"};
            $es->indices->put_mapping(
                index => $idx,
                type  => $type,
                body  => { $type => $mappings{$idx}{$type} },
            );
        }
    }

    # create alias
    $es->indices->put_alias(
        index => $idx_cpan,
        name  => 'cpan',
    );

    # done
    log_info {"Done."};
    1;
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
 # bin/metacpan mapping --create_index xxx --patch_mapping '{...mapping...}' --skip_existing_mapping
 # bin/metacpan mapping --update_index xxx --patch_mapping '{...mapping...}'
 # bin/metacpan mapping --copy_to_index xxx --copy_type release
 # bin/metacpan mapping --copy_to_index xxx --copy_type release --copy_query '{"range":{"date":{"gte":"2016-01","lt":"2017-01"}}}'

=head1 DESCRIPTION

This is the index mapping handling script.
Used rarely, but carries the most important task of setting
the index and mapping the types.

=cut
