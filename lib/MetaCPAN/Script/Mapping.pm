package MetaCPAN::Script::Mapping;

use Moose;

use Cpanel::JSON::XS          qw( decode_json );
use DateTime                  ();
use Log::Contextual           qw( :log );
use MetaCPAN::ESConfig        qw( es_config );
use MetaCPAN::Types::TypeTiny qw( Bool HashRef Int Str );
use Time::HiRes               qw( sleep time );

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

has arg_verify_mapping => (
    init_arg      => 'verify',
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'verify deployed index structure against definition',
);

has arg_list_types => (
    init_arg      => 'list_types',
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'list available document type names',
);

has arg_cluster_info => (
    init_arg      => 'show_cluster_info',
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'show basic info about cluster and indices',
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

has copy_from_index => (
    is            => 'ro',
    isa           => Str,
    documentation => 'index to copy type from',
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

has arg_await_timeout => (
    init_arg      => 'await',
    is            => 'ro',
    isa           => Int,
    default       => 15,
    documentation =>
        'seconds before connection is considered failed with timeout',
);

has delete_from_type => (
    is            => 'ro',
    isa           => Str,
    default       => "",
    documentation => 'delete data from an existing type',
);

has cluster_info => (
    isa     => HashRef,
    traits  => ['Hash'],
    is      => 'rw',
    lazy    => 1,
    default => sub { {} },
);

has indices_info => (
    isa     => HashRef,
    traits  => ['Hash'],
    is      => 'rw',
    lazy    => 1,
    default => sub { {} },
);

sub run {
    my $self = shift;

    # Wait for the ElasticSearch Engine to become ready
    if ( $self->await ) {
        if ( $self->arg_delete_index ) {
            $self->delete_index;
        }
        elsif ( $self->arg_create_index ) {
            $self->create_index;
        }
        elsif ( $self->arg_update_index ) {
            $self->update_index;
        }
        elsif ( $self->copy_to_index ) {
            $self->copy_type;
        }
        elsif ( $self->delete_from_type ) {
            $self->empty_type;
        }
        elsif ( $self->arg_deploy_mapping ) {
            if ( $self->arg_delete_all ) {
                $self->check_health;
                $self->delete_all;
            }
            unless ( $self->deploy_mapping ) {
                $self->print_error("Indices Re-creation has failed!");
                $self->exit_code(1);
            }
        }

        if ( $self->arg_verify_mapping ) {
            $self->check_health;
            unless ( $self->indices_valid( $self->_build_index_config ) ) {
                $self->print_error("Indices Verification has failed!");
                $self->exit_code(1);
            }
        }

        if ( $self->arg_list_types ) {
            $self->list_types;
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

sub delete_all {
    my $self                = $_[0];
    my $runtime_environment = 'production';

    $runtime_environment = $ENV{'PLACK_ENV'}
        if ( defined $ENV{'PLACK_ENV'} );
    $runtime_environment = $ENV{'MOJO_MODE'}
        if ( defined $ENV{'MOJO_MODE'} );

    my $is_development
        = $ENV{HARNESS_ACTIVE}
        || $runtime_environment eq 'development'
        || $runtime_environment eq 'testing';

    if ($is_development) {
        foreach my $name ( grep !/\A\./, keys %{ $self->indices_info } ) {
            $self->_delete_index($name);
        }
    }
    else {
        #Set System Error: 1 - EPERM - Operation not permitted
        $self->exit_code(1);
        $self->print_error("Operation not permitted!");
        $self->handle_error(
            "Operation not permitted in environment: $runtime_environment",
            1 );
    }
}

sub _delete_index {
    my ( $self, $name ) = @_;

    log_info {"Deleting index: $name"};
    my $idx = $self->es->indices;
    $idx->delete( index => $name );

    my $exists;
    my $end = time + 2;
    while ( time < $end ) {
        $exists = $idx->exists( index => $name ) or last;
        sleep 0.1;
    }
    if ($exists) {
        log_error {"Failed to delete index: $name"};
    }
    return $exists;
}

sub update_index {
    my $self = shift;
    my $name = $self->arg_update_index;

    $self->_check_index_exists( $name, EXPECTED );
    $self->are_you_sure("Index $name will be updated !!!");

    die "update_index requires patch_mapping\n"
        unless $self->patch_mapping;

    my $patch_mapping = decode_json $self->patch_mapping;
    my @patch_types   = sort keys %{$patch_mapping};
    my $mapping       = +{ map { $_ => $patch_mapping->{$_} } @patch_types };

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

    my $patch_mapping  = decode_json $self->patch_mapping;
    my @patch_types    = sort keys %{$patch_mapping};
    my $index_settings = es_config->index_settings($dst_idx);
    my $mapping        = +{};

    # create the new index with the copied settings
    log_info {"Creating index: $dst_idx"};
    $self->es->indices->create( index => $dst_idx, body => $index_settings );

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
    my $from_index = $self->copy_from_index
        or die "can't copy without a source index";
    $index //= $self->copy_to_index
        or die "can't copy without a destination index";

    $self->_check_index_exists( $from_index, EXPECTED );
    $self->_check_index_exists( $index,      EXPECTED );
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

    return $self->_copy_slice( $query, $from_index, $index, $type ) if $query;

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
            $self->_copy_slice( $q, $from_index, $index, $type );
            1;
        } or do {
            my $err = $@ || 'zombie error';
            warn $err;
        };
    }
}

sub _copy_slice {
    my ( $self, $query, $from_index, $index, $type ) = @_;

    my $scroll = $self->es->scroll_helper(
        size   => 250,
        scroll => '10m',
        index  => $from_index,
        type   => $type,
        body   => {
            query => $query,
            sort  => '_doc',
        },
    );

    my $bulk = $self->es->bulk_helper(
        index     => $index,
        type      => $type,
        max_count => 500,
    );

    while ( my $search = $scroll->next ) {
        $bulk->create( {
            id     => $search->{_id},
            source => $search->{_source}
        } );
    }

    $bulk->flush;
}

sub empty_type {
    my $self = shift;
    my $type = $self->delete_from_type;
    log_info {"Emptying type: $type"};

    my $bulk
        = $self->es->bulk_helper( es_doc_path($type), max_count => 500, );

    my $scroll = $self->es->scroll_helper(
        size   => 250,
        scroll => '10m',
        es_doc_path($type),
        body => {
            query => { match_all => {} },
            sort  => '_doc',
        },
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
    print "$_\n" for sort keys %{ es_config->documents };
}

sub show_info {
    my $self    = $_[0];
    my $info_rs = {
        'cluster_info' => \%{ $self->cluster_info },
        'indices_info' => \%{ $self->indices_info },
    };
    log_info { JSON->new->utf8->pretty->encode($info_rs) };
}

sub _build_index_config {
    my $self    = $_[0];
    my $docs    = es_config->documents;
    my $indices = {};
    for my $name ( sort keys %$docs ) {
        my $doc   = $docs->{$name};
        my $index = $doc->{index}
            or die "no index defined for $name documents";
        my $type = $doc->{type}
            or die "no type defined for $name documents";
        die "$index specified for multiple documents"
            if $indices->{$index};
        my $mapping  = es_config->mapping($name);
        my $settings = es_config->index_settings($name);
        $indices->{$index} = {
            settings => $settings,
            mappings => {
                $type => $mapping,
            },
        };
    }

    return $mappings;
}

sub deploy_mapping {
    my $self = shift;

    $self->are_you_sure(
        'this will delete EVERYTHING and re-create the (empty) indexes');

    # Deserialize the Index Mapping Structure
    my $rindices = $self->_build_index_config;

    my $es = $self->es;

    # recreate the indices and apply the mapping

    for my $idx ( sort keys %$rindices ) {
        $self->_delete_index($idx)
            if $es->indices->exists( index => $idx );

        log_info {"Creating index: $idx"};

        $es->indices->create( index => $idx, body => $rindices->{$idx} );
    }

    $self->check_health(1);

    # done
    log_info {"Done."};

    return $self->indices_valid($rindices);
}

sub _compare_mapping {
    my ( $self, $sname, $rdeploy, $rmodel ) = @_;
    my $imatch = 0;

    if ( defined $rdeploy && defined $rmodel ) {
        my $json_parser = Cpanel::JSON::XS->new->allow_nonref;
        my ( $deploy_type, $deploy_value );
        my ( $model_type,  $model_value );

        $imatch = 1;

        if ( ref $rdeploy eq 'HASH' ) {
            foreach my $sfield ( sort keys %$rdeploy ) {
                if (   defined $rdeploy->{$sfield}
                    && defined $rmodel->{$sfield} )
                {
                    $deploy_type  = ref( $rdeploy->{$sfield} );
                    $model_type   = ref( $rmodel->{$sfield} );
                    $deploy_value = $rdeploy->{$sfield};
                    $model_value  = $rmodel->{$sfield};

                    if ( $deploy_type eq 'JSON::PP::Boolean' ) {
                        $deploy_type = '';
                        $deploy_value
                            = $json_parser->encode( $rdeploy->{$sfield} );
                    }

                    if ( $model_type eq 'JSON::PP::Boolean' ) {
                        $model_type = '';
                        $model_value
                            = $json_parser->encode( $rmodel->{$sfield} );
                    }

                    if ( $deploy_type ne '' ) {
                        if (   $deploy_type eq 'HASH'
                            || $deploy_type eq 'ARRAY' )
                        {
                            $imatch = (
                                $imatch && $self->_compare_mapping(
                                    $sname . '.' . $sfield, $deploy_value,
                                    $model_value
                                )
                            );
                        }
                        else {    # No Hash nor Array
                            if ( ${$deploy_value} ne ${$model_value} ) {
                                log_error {
                                    'Mismatch field: '
                                        . $sname . '.'
                                        . $sfield . ' ('
                                        . ${$deploy_value} . ' <> '
                                        . ${$model_value} . ')'
                                };
                                $imatch = 0;
                            }
                        }
                    }
                    else {    # Scalar Value
                        if (
                               $sfield eq 'type'
                            && $model_value eq 'string'
                            && (   $deploy_value eq 'text'
                                || $deploy_value eq 'keyword' )
                            )
                        {
                            # ES5 automatically converts string types to text
                            # or keyword. once we upgrade to ES5 and update
                            # our mappings, this special case can be removed.
                        }
                        elsif ($sfield eq 'index'
                            && $model_value eq 'no'
                            && $deploy_value eq 'false' )
                        {
                            # another ES5 string automatic conversion
                        }
                        elsif ( $deploy_value ne $model_value ) {
                            log_error {
                                'Mismatch field: '
                                    . $sname . '.'
                                    . $sfield . ' ('
                                    . $deploy_value . ' <> '
                                    . $model_value . ')'
                            };
                            $imatch = 0;
                        }
                    }
                }
                else {
                    unless ( defined $rdeploy->{$sfield} ) {
                        log_error {
                            'Missing field: ' . $sname . '.' . $sfield
                        };
                        $imatch = 0;

                    }

                    unless ( defined $rmodel->{$sfield} ) {
                        if (   $sfield eq 'payloads'
                            && $rmodel->{type}
                            && $rmodel->{type} eq 'completion'
                            && !$rdeploy->{$sfield} )
                        {
                            # ES5 doesn't allow payloads option. we've removed
                            # it from our mapping. but it gets a default
                            # value. ignore the default.
                        }
                        else {
                            log_error {
                                'Missing definition: ' . $sname . '.'
                                    . $sfield
                            };
                            $imatch = 0;
                        }
                    }
                }
            }
        }
        elsif ( ref $rdeploy eq 'ARRAY' ) {
            foreach my $iindex (@$rdeploy) {
                if (   defined $rdeploy->[$iindex]
                    && defined $rmodel->[$iindex] )
                {
                    $deploy_type  = ref( $rdeploy->[$iindex] );
                    $model_type   = ref( $rmodel->[$iindex] );
                    $deploy_value = $rdeploy->[$iindex];
                    $model_value  = $rmodel->[$iindex];

                    if ( $deploy_type eq 'JSON::PP::Boolean' ) {
                        $deploy_type = '';
                        $deploy_value
                            = $json_parser->encode( $rdeploy->[$iindex] );
                    }

                    if ( $model_type eq 'JSON::PP::Boolean' ) {
                        $model_type = '';
                        $model_value
                            = $json_parser->encode( $rmodel->[$iindex] );
                    }

                    if ( $deploy_type eq '' ) {    # Reference Value
                        if (   $deploy_type eq 'HASH'
                            || $deploy_type eq 'ARRAY' )
                        {
                            $imatch = (
                                $imatch && $self->_compare_mapping(
                                    $sname . '[' . $iindex . ']',
                                    $deploy_value,
                                    $model_value
                                )
                            );
                        }
                        else {    # No Hash nor Array
                            if ( ${$deploy_value} ne ${$model_value} ) {
                                log_error {
                                    'Mismatch field: '
                                        . $sname . '['
                                        . $iindex . '] ('
                                        . ${$deploy_value} . ' <> '
                                        . ${$model_value} . ')'
                                };
                                $imatch = 0;
                            }
                        }
                    }
                    else {    # Scalar Value
                        if ( $deploy_value ne $model_value ) {
                            log_error {
                                'Mismatch field: '
                                    . $sname . '['
                                    . $iindex . '] ('
                                    . $deploy_value . ' <> '
                                    . $model_value . ')'
                            };
                            $imatch = 0;
                        }
                    }
                }
                else {    # Missing Field
                    unless ( defined $rdeploy->[$iindex] ) {
                        log_error {
                            'Missing field: ' . $sname . '[' . $iindex . ']'
                        };
                        $imatch = 0;

                    }
                    unless ( defined $rmodel->[$iindex] ) {
                        log_error {
                            'Missing definition: ' . $sname . '[' . $iindex
                                . ']'
                        };
                        $imatch = 0;
                    }
                }
            }
        }
    }
    else {    # Missing Field
        unless ( defined $rdeploy ) {
            log_error { 'Missing field: ' . $sname };
            $imatch = 0;
        }
        unless ( defined $rmodel ) {
            log_error { 'Missing definition: ' . $sname };
            $imatch = 0;
        }
    }

    if ( $self->{'logger'}->is_debug ) {
        if ($imatch) {
            log_debug {"field '$sname': ok"};
        }
        else {
            log_debug {"field '$sname': failed!"};
        }
    }

    return $imatch;
}

sub indices_valid {
    my ( $self, $config_indices ) = @_;
    my $valid = 0;

    if ( defined $config_indices && ref $config_indices eq 'HASH' ) {
        my $deploy_indices = $self->es->indices->get_mapping;
        $valid = 1;

        for my $idx ( sort keys %$config_indices ) {
            my $config_mappings = $config_indices->{$idx}
                && $config_indices->{$idx}->{'mappings'};
            my $deploy_mappings = $deploy_indices->{$idx}
                && $deploy_indices->{$idx}->{'mappings'};
            if ( !$deploy ) {
                log_error {"Missing index: $idx"};
                $valid = 0;
                next;
            }

            log_info {
                "Verifying index: $idx"
            };

            if ( $self->_compare_mapping(
                $idx, $deploy_mappings, $config_mappings
            ) )
            {
                log_info {
                    "Correct index: $idx (mapping deployed)"
                };
            }
            else {
                log_error {
                    "Broken index: $idx (mapping does not match definition)"
                };
                $valid = 0;
            }
        }
    }

    if ($valid) {
        log_info {"Verification indices: ok"};
    }
    else {
        log_info {"Verification indices: failed"};
    }

    return $valid;
}

sub _get_indices_info {
    my ( $self, $irefresh ) = @_;

    if ( $irefresh || scalar( keys %{ $self->indices_info } ) == 0 ) {
        my $sinfo_rs = $self->es->cat->indices( h => [ 'index', 'health' ] );
        my $sindices_parsing = qr/^([^[:space:]]+) +([^[:space:]]+)/m;

        $self->indices_info( {} );

        while ( $sinfo_rs =~ /$sindices_parsing/g ) {
            $self->indices_info->{$1}
                = { 'index_name' => $1, 'health' => $2 };
        }
    }
}

sub check_health {
    my ( $self, $irefresh ) = @_;
    my $ihealth = 0;

    $irefresh = 0 unless ( defined $irefresh );

    $ihealth = $self->await;

    if ($ihealth) {
        $self->_get_indices_info($irefresh);

        foreach ( keys %{ $self->indices_info } ) {
            $ihealth = 0
                if ( $self->indices_info->{$_}->{'health'} eq 'red' );
        }
    }

    return $ihealth;
}

sub await {
    my $self   = $_[0];
    my $iready = 0;

    if ( scalar( keys %{ $self->cluster_info } ) == 0 ) {
        my $es       = $self->es;
        my $iseconds = 0;

        log_info {"Awaiting Elasticsearch ..."};

        do {
            eval {
                $iready = $es->ping;

                if ($iready) {
                    log_info {
                        "Awaiting $iseconds / "
                            . $self->arg_await_timeout
                            . " : ready"
                    };

                    $self->cluster_info( \%{ $es->info } );
                }
            };

            if ($@) {
                if ( $iseconds < $self->arg_await_timeout ) {
                    log_info {
                        "Awaiting $iseconds / "
                            . $self->arg_await_timeout
                            . " : unavailable - sleeping ..."
                    };

                    sleep(1);

                    $iseconds++;
                }
                else {
                    log_error {
                        "Awaiting $iseconds / "
                            . $self->arg_await_timeout
                            . " : unavailable - timeout!"
                    };

                    #Set System Error: 112 - EHOSTDOWN - Host is down
                    $self->exit_code(112);
                    $self->handle_error( $@, 1 );
                }
            }
        } while ( !$iready && $iseconds <= $self->arg_await_timeout );
    }
    else {
        #ElasticSearch Service is available
        $iready = 1;
    }

    return $iready;
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=pod

=head1 NAME

MetaCPAN::Script::Mapping - Script to set the index and mapping the types

=head1 SYNOPSIS

 # bin/metacpan mapping --show_cluster_info   # show basic info about the cluster and indices
 # bin/metacpan mapping --delete
 # bin/metacpan mapping --delete --all        # deletes ALL indices in the cluster
 # bin/metacpan mapping --verify              # compare deployed indices with project definitions
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
and its indices.
This information has to be collected with the C<MetaCPAN::Role::Script::check_health()> Method.
On Script start-up it is empty.

    bin/metacpan mapping --show_cluster_info

See L<Method C<MetaCPAN::Role::Script::check_health()>>

=item Option C<--delete>

This option makes the Script delete all indices configured in the project and re-create them emtpy.
It verifies the index integrity of the indices calling the methods
C<MetaCPAN::Role::Script::check_health()> and C<mappings_valid()>.
If the C<mappings_valid()> Method fails it will report an error.

    bin/metacpan mapping --delete

B<Exit Code:> If the mapping deployment fails it exits the Script with B<Exit Code> C< 1 >.

See L<Method C<deploy_mapping()>>

See L<Method C<mappings_valid()>>

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

=item Option C<--verify>

This option will request the index mappings from the I<ElasticSearch> Cluster and
compare them indepth with the Project Definitions.

    bin/metacpan mapping --verify

B<Exit Code:> If the deployed mappings do not match the defined mappings
it exits the Script with B<Exit Code> C< 1 >.

=back

=head1 METHODS

This Package provides the following methods

=over 4

=item C<deploy_mapping()>

Deletes and re-creates the indices defined in the Project.
The user will be requested for manual confirmation on the command line before the elemination.
The integrity of the indices will be checked with the C<mappings_valid()> Method.
On successful creation it returns C< 1 >, otherwise it returns C< 0 >.

B<Returns:> It returns C< 1 > when the indices are created and verified as correct.
Otherwise it returns C< 0 >.

B<Exceptions:> It can throw exceptions when the connection to I<ElasticSearch> fails
or there is any issue in any I<ElasticSearch> Request run by the Script.

See L<Option C<--delete>>

See L<Method C<mappings_valid()>>

See L<Method C<MetaCPAN::Role::Script::check_health()>>

=item C<mappings_valid( \%indices )>

This method uses the
L<C<Search::Elasticsearch::Client::2_0::Direct::get_mapping()>|https://metacpan.org/pod/Search::Elasticsearch::Client::2_0::Direct#get_mapping()>
method to request the complete index mappings structure from the I<ElasticSearch> Cluster.
Then it performs an in-depth structure match against the Project Definitions.
Missing indices or any structure mismatch will be count as error.
Errors will be reported in the activity log.

B<Parameters:>

C<\%indices> - Reference to a hash that defines the indices required for the Project.

B<Returns:> It returns C< 1 > when the indices are created and match the defined structure.
Otherwise it returns C< 0 >.

See L<Option C<--delete>>

See L<Method C<mappings_valid()>>

See L<Method C<MetaCPAN::Role::Script::check_health()>>

=item C<await()>

This method uses the
L<C<Search::Elasticsearch::Client::2_0::Direct::ping()>|https://metacpan.org/pod/Search::Elasticsearch::Client::2_0::Direct#ping()>
method to verify the service availabilty and wait for C<arg_await_timeout> seconds.
When the service does not become available within C<arg_await_timeout> seconds it re-throws the
Exception from the C<Search::Elasticsearch::Client> and sets B<Exit Code> to C< 112 >.
The C<Search::Elasticsearch::Client> generates a C<"Search::Elasticsearch::Error::NoNodes"> Exception.
When the service is available it will populate the C<cluster_info> C<HASH> structure with the basic information
about the cluster.

B<Exceptions:> It will throw an exceptions when the I<ElasticSearch> service does not become available
within C<arg_await_timeout> seconds (as described above).

See L<Option C<--await 15>>

See L<Method C<check_health()>>

=item C<check_health( [ refresh ] )>

This method uses the
L<C<Search::Elasticsearch::Client::2_0::Direct::cat()>|https://metacpan.org/pod/Search::Elasticsearch::Client::2_0::Direct#cat()>
method to collect basic data about the cluster structure as the general information,
the health state of the indices.
This information is stored in C<cluster_info>, C<indices_info> as C<HASH> structures.
If the parameter C<refresh> is set to C< 1 > the structure C<indices_info> will always
be updated.
If the C<cluster_info> structure is empty it calls first the C<await()> method.
If the service is unavailable the C<await()> method will produce an exception and the structures will be empty
The method returns C< 1 > when the C<cluster_info> is populated, none of the indices in C<indices_info> has
the Health State I<red> otherwise the method returns C< 0 >

B<Parameters:>

C<refresh> - Integer evaluated as boolean when set to C< 1 > the cluster info structures
will always be updated.

See L<Method C<await()>>

=back

=cut
