package MetaCPAN::Script::Mapping;

use Moose;

use Cpanel::JSON::XS qw( decode_json );
use DateTime ();
use Log::Contextual qw( :log );
use MetaCPAN::Script::Mapping::CPAN::Author       ();
use MetaCPAN::Script::Mapping::CPAN::Distribution ();
use MetaCPAN::Script::Mapping::CPAN::Favorite     ();
use MetaCPAN::Script::Mapping::CPAN::File         ();
use MetaCPAN::Script::Mapping::CPAN::Mirror       ();
use MetaCPAN::Script::Mapping::CPAN::Permission   ();
use MetaCPAN::Script::Mapping::CPAN::Package      ();
use MetaCPAN::Script::Mapping::CPAN::Rating       ();
use MetaCPAN::Script::Mapping::CPAN::Release      ();
use MetaCPAN::Script::Mapping::DeployStatement    ();
use MetaCPAN::Script::Mapping::User::Account      ();
use MetaCPAN::Script::Mapping::User::Identity     ();
use MetaCPAN::Script::Mapping::User::Session      ();
use MetaCPAN::Script::Mapping::Contributor        ();
use MetaCPAN::Script::Mapping::Cover              ();
use MetaCPAN::Types::TypeTiny qw( Bool Str );

use constant {
    EXPECTED     => 1,
    NOT_EXPECTED => 0,
};

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has arg_deploy_mapping => (
    init_arg      => 'delete',
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'delete index if it exists already',
);

has arg_delete_all => (
    init_arg      => 'all',
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation =>
        'delete ALL existing indices (only effective in combination with "--delete")',
);

has arg_list_types => (
    init_arg      => 'list_types',
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'list available index type names',
);

has arg_cluster_info => (
    init_arg      => 'show_cluster_info',
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'show basic info about cluster, indices and aliases',
);

has arg_create_index => (
    init_arg      => 'create_index',
    is            => 'ro',
    isa           => Str,
    default       => "",
    documentation => 'create a new empty index (copy mappings)',
);

has arg_update_index => (
    init_arg      => 'update_index',
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

has arg_copy_type => (
    init_arg      => 'copy_type',
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

has arg_delete_index => (
    init_arg      => 'delete_index',
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

    if ( $self->await ) {
        $self->create_index if $self->arg_create_index;
        $self->update_index if $self->arg_update_index;
        $self->delete_index if $self->arg_delete_index;
        $self->copy_type    if $self->copy_to_index;
        $self->empty_type   if $self->delete_from_type;
        $self->list_types   if $self->arg_list_types;

        if ( $self->arg_deploy_mapping ) {
            if ( $self->arg_delete_all ) {
                $self->check_health;
                $self->delete_all;
            }
            unless ( $self->deploy_mapping ) {
                $self->print_error("Indices Re-creation has failed!");
                $self->exit_code(1);
            }
        }

        if ( $self->arg_cluster_info ) {
            $self->check_health;
            $self->show_info;
        }
    }

# The run() method is expected to communicate Success to the superior execution level
    return ( $self->exit_code == 0 ? 1 : 0 );
}

sub _check_index_exists {
    my ( $self, $name, $expected ) = @_;
    my $exists = $self->es->indices->exists( index => $name );

    if ( $exists and !$expected ) {
        log_error {"Index already exists: $name"};

        #Set System Error: 1 - EPERM - Operation not permitted
        $self->exit_code(1);
        $self->handle_error( "Conflicting index: $name", 1 );
    }

    if ( !$exists and $expected ) {
        log_error {"Index doesn't exists: $name"};

        #Set System Error: 1 - EPERM - Operation not permitted
        $self->exit_code(1);
        $self->handle_error( "Missing index: $name", 1 );
    }
}

sub delete_index {
    my $self = shift;
    my $name = $self->arg_delete_index;

    $self->_check_index_exists( $name, EXPECTED );
    $self->are_you_sure("Index $name will be deleted !!!");

    $self->_delete_index($name);
}

sub _delete_index {
    my ( $self, $name ) = @_;

    log_info {"Deleting index: $name"};
    $self->es->indices->delete( index => $name );
}

sub update_index {
    my $self = shift;
    my $name = $self->arg_update_index;

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
            index => $name,
            type  => $type,
            body  => { $type => $mapping->{$type} },
        );
    }

    log_info {"Done."};
}

sub create_index {
    my $self = shift;

    my $dst_idx = $self->arg_create_index;
    $self->_check_index_exists( $dst_idx, NOT_EXPECTED );

    my $patch_mapping = decode_json $self->patch_mapping;
    my @patch_types   = sort keys %{$patch_mapping};
    my $dep           = $self->index->deployment_statement;
    delete $dep->{mappings};
    my $mapping = +{};

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
            $self->copy_type( $dst_idx, $type );
        }
    }

    log_info {
        "Done. you can now fill the data for the altered types: ("
            . join( ',', @patch_types ) . ")"
    }
    if @patch_types;
}

sub copy_type {
    my ( $self, $index, $type ) = @_;
    $index //= $self->copy_to_index;

    $self->_check_index_exists( $index, EXPECTED );
    $type //= $self->arg_copy_type;
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

    my $dt       = DateTime->new( year => 1994, month => 1 );
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

    my $scroll = $self->es->scroll_helper(
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

sub empty_type {
    my $self = shift;
    my $type = $self->delete_from_type;
    log_info {"Emptying type: $type"};

    my $bulk = $self->es->bulk_helper(
        index     => $self->index->name,
        type      => $type,
        max_count => 500,
    );

    my $scroll = $self->es->scroll_helper(
        search_type => 'scan',
        size        => 250,
        scroll      => '10m',
        index       => $self->index->name,
        type        => $type,
        body        => { query => { match_all => {} } },
    );

    my @ids;
    while ( my $search = $scroll->next ) {
        push @ids => $search->{_id};
        log_debug { "deleting id=" . $search->{_id} };
        if ( @ids == 500 ) {
            $bulk->delete_ids(@ids);
            @ids = ();
        }
    }
    $bulk->delete_ids(@ids);

    $bulk->flush;
}

sub list_types {
    my $self = shift;
    print "$_\n" for sort keys %{ $self->index->types };
}

sub show_info {
    my $self    = $_[0];
    my $info_rs = {
        'cluster_info' => \%{ $self->cluster_info },
        'indices_info' => \%{ $self->indices_info },
        'aliases_info' => \%{ $self->aliases_info }
    };
    print JSON->new->utf8->pretty->encode($info_rs);
}

sub deploy_mapping {
    my $self       = shift;
    my $cpan_index = 'cpan_v1_01';
    my $imappingok = 0;

    $self->are_you_sure(
        'this will delete EVERYTHING and re-create the (empty) indexes');

    my %mappings = (
        $cpan_index => {
            author =>
                decode_json(MetaCPAN::Script::Mapping::CPAN::Author::mapping),
            distribution => decode_json(
                MetaCPAN::Script::Mapping::CPAN::Distribution::mapping),
            favorite => decode_json(
                MetaCPAN::Script::Mapping::CPAN::Favorite::mapping),
            file =>
                decode_json(MetaCPAN::Script::Mapping::CPAN::File::mapping),
            mirror =>
                decode_json(MetaCPAN::Script::Mapping::CPAN::Mirror::mapping),
            permission => decode_json(
                MetaCPAN::Script::Mapping::CPAN::Permission::mapping),
            package => decode_json(
                MetaCPAN::Script::Mapping::CPAN::Package::mapping),
            rating =>
                decode_json(MetaCPAN::Script::Mapping::CPAN::Rating::mapping),
            release => decode_json(
                MetaCPAN::Script::Mapping::CPAN::Release::mapping),
        },

        user => {
            account => decode_json(
                MetaCPAN::Script::Mapping::User::Account::mapping),
            identity => decode_json(
                MetaCPAN::Script::Mapping::User::Identity::mapping),
            session => decode_json(
                MetaCPAN::Script::Mapping::User::Session::mapping),
        },
        contributor => {
            contributor =>
                decode_json(MetaCPAN::Script::Mapping::Contributor::mapping),
        },
        cover => {
            cover => decode_json(MetaCPAN::Script::Mapping::Cover::mapping),
        },
    );

    my $deploy_statement
        = decode_json(MetaCPAN::Script::Mapping::DeployStatement::mapping);

    my $es = $self->es;

    # recreate the indices and apply the mapping

    for my $idx ( sort keys %mappings ) {
        $self->_delete_index($idx) if $es->indices->exists( index => $idx );

        log_info {"Creating index: $idx"};
        $es->indices->create( index => $idx, body => $deploy_statement );

        for my $type ( sort keys %{ $mappings{$idx} } ) {
            log_info {"Adding mapping: $idx/$type"};
            $es->indices->put_mapping(
                index => $idx,
                type  => $type,
                body  => { $type => $mappings{$idx}{$type} },
            );
        }
    }

    # create aliases

    my %aliases = ( 'cpan' => $cpan_index );
    for my $alias ( sort keys %aliases ) {
        log_info {"Creating alias: '$alias' -> '$aliases{$alias}'"};
        $es->indices->put_alias(
            index => $aliases{$alias},
            name  => $alias,
        );
    }

    $self->check_health(1);
    $imappingok = $self->verify_mapping( \%mappings, \%aliases );

    # done
    log_info {"Done."};

    return $imappingok;
}

sub verify_mapping {
    my ( $self, $rmappings, $raliases ) = @_;
    my $ihealth = 0;

    if ( defined $rmappings && ref $rmappings eq 'HASH' ) {
        my $rhealth = undef;

        $ihealth = 1;

        for my $idx ( sort keys %$rmappings ) {
            $rhealth = $self->indices_info->{$idx};
            if ( defined $rhealth ) {
                if ( $rhealth->{'health'} eq 'red' ) {
                    log_error {
                        "Broken index: $idx (state '"
                            . $rhealth->{'health'} . "')"
                    };
                    $ihealth = 0;
                }
                else {
                    log_info {
                        "Healthy index: $idx (state '"
                            . $rhealth->{'health'} . "')"
                    };
                }
            }
            else {
                log_error {"Missing index: $idx"};
                $ihealth = 0;
            }
        }
    }

    if ( defined $raliases && ref $raliases eq 'HASH' ) {
        my $ralias = undef;
        for my $name ( sort keys %$raliases ) {
            $ralias = $self->aliases_info->{$name};
            if ( defined $ralias ) {
                if ( $ralias->{'index'} eq $raliases->{$name} ) {
                    log_info {
                        "Correct alias: $name (index '"
                            . $ralias->{'index'} . "')"
                    };
                }
                else {
                    log_error {
                        "Broken alias: $name (index '"
                            . $ralias->{'index'} . "')"
                    };
                    $ihealth = 0;
                }
            }
            else {
                log_error {"Missing alias: $name"};
                $ihealth = 0;
            }
        }
    }
    else {
        $ihealth = 0 if ( scalar( keys %{ $self->aliases_info } ) == 0 );
    }

    return $ihealth;
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=pod

=head1 NAME

MetaCPAN::Script::Mapping - Script to set the index and mapping the types

=head1 SYNOPSIS

 # bin/metacpan mapping --show_cluster_info   # show basic info about the cluster, indices and aliases
 # bin/metacpan mapping --delete
 # bin/metacpan mapping --delete --all        # deletes ALL indices in the cluster
 # bin/metacpan mapping --list_types
 # bin/metacpan mapping --delete_index xxx
 # bin/metacpan mapping --create_index xxx --reindex
 # bin/metacpan mapping --create_index xxx --reindex --patch_mapping '{"distribution":{"dynamic":"false","properties":{"name":{"index":"not_analyzed","ignore_above":2048,"type":"string"},"river":{"properties":{"total":{"type":"integer"},"immediate":{"type":"integer"},"bucket":{"type":"integer"}},"dynamic":"true"},"bugs":{"properties":{"rt":{"dynamic":"true","properties":{"rejected":{"type":"integer"},"closed":{"type":"integer"},"open":{"type":"integer"},"active":{"type":"integer"},"patched":{"type":"integer"},"source":{"type":"string","ignore_above":2048,"index":"not_analyzed"},"resolved":{"type":"integer"},"stalled":{"type":"integer"},"new":{"type":"integer"}}},"github":{"dynamic":"true","properties":{"active":{"type":"integer"},"open":{"type":"integer"},"closed":{"type":"integer"},"source":{"type":"string","index":"not_analyzed","ignore_above":2048}}}},"dynamic":"true"}}}}'
 # bin/metacpan mapping --create_index xxx --patch_mapping '{...mapping...}' --skip_existing_mapping
 # bin/metacpan mapping --update_index xxx --patch_mapping '{...mapping...}'
 # bin/metacpan mapping --copy_to_index xxx --copy_type release
 # bin/metacpan mapping --copy_to_index xxx --copy_type release --copy_query '{"range":{"date":{"gte":"2016-01","lt":"2017-01"}}}'
 # bin/metacpan mapping --delete_from_type xxx   # empty the type

=head1 DESCRIPTION

This is the index mapping handling script.
Used rarely, but carries the most important task of setting
the index and mapping the types.

=head1 OPTIONS

This Script accepts the following options

=over 4

=item Option C<--show_cluster_info>

This option makes the Script show basic information about the I<ElasticSearch> Cluster
and its indices and aliases.
This information has to be collected with the C<MetaCPAN::Role::Script::check_health()> Method.
On Script start-up it is empty.

    bin/metacpan mapping --show_cluster_info

See L<Method C<MetaCPAN::Role::Script::check_health()>>

=item Option C<--delete>

This option makes the Script delete all indices configured in the project and re-create them emtpy.
It verifies the index integrity of the indices and aliases calling the methods
C<MetaCPAN::Role::Script::check_health()> and C<verify_mapping()>.
If the C<verify_mapping()> Method fails it exits the Script
with B<Exit Code> C< 1 >.

    bin/metacpan mapping --delete

B<Exit Code:> If the mapping deployment fails it exits the Script with B<Exit Code> C< 1 >.

See L<Method C<deploy_mapping()>>

See L<Method C<verify_mapping()>>

See L<Method C<MetaCPAN::Role::Script::check_health()>>

=item Option C<--all>

This option is only effective in combination with Option C<--delete>.
It uses the information gathered by C<MetaCPAN::Role::Script::check_health()> to delete
B<ALL> indices in the I<ElasticSearch> Cluster.
This option is usefull to reconstruct a broken I<ElasticSearch> Cluster

    bin/metacpan mapping --delete --all

B<Exceptions:> It will throw an exceptions when not performed in an development or
testing environment.

See L<Option C<--delete>>

See L<Method C<deploy_mapping()>>

See L<Method C<MetaCPAN::Role::Script::check_health()>>

=back

=head1 METHODS

This Package provides the following methods

=over 4

=item C<deploy_mapping()>

Deletes and re-creates the indices and aliases defined in the Project.
The user will be requested for manual confirmation on the command line before the elemination.
The integrity of the indices and aliases will be checked with the C<verify_mapping()> Method.
On successful creation it returns C< 1 >, otherwise it returns C< 0 >.

B<Returns:> It returns C< 1 > when the indices and aliases are created and verified as correct.
Otherwise it returns C< 0 >.

B<Exceptions:> It can throw exceptions when the connection to I<ElasticSearch> fails
or there is any issue in any I<ElasticSearch> Request run by the Script.

See L<Option C<--delete>>

See L<Method C<verify_mapping()>>

See L<Method C<MetaCPAN::Role::Script::check_health()>>

=item C<verify_mapping( \%indices, \%aliases )>

Checks the defined indices and aliases against the actually in the I<ElasticSearch> Cluster
existing indices and aliases which must have been requested with
the C<MetaCPAN::Role::Script::check_health()> Method.

B<Parameters:>

C<\%indices> - Reference to a hash that defines the indices required for the Project.

C<\%aliases> - Reference to a hash that defines the aliases required for the Project.

B<Returns:> It returns C< 1 > when the indices and aliases are created and verified as correct.
Otherwise it returns C< 0 >.

B<Exceptions:> It can throw exceptions when the connection to I<ElasticSearch> fails
or there is any issue in any I<ElasticSearch> Request run by the Script.

See L<Option C<--delete>>

See L<Method C<verify_mapping()>>

See L<Method C<MetaCPAN::Role::Script::check_health()>>

=back

=cut
