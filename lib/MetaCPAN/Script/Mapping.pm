package MetaCPAN::Script::Mapping;

use Moose;

use Cpanel::JSON::XS   ();
use Log::Contextual    qw( :log );
use MetaCPAN::ESConfig qw( es_config );
use MetaCPAN::Types    qw( Bool HashRef Int );
use Time::HiRes        qw( sleep time );

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

has arg_cluster_info => (
    init_arg      => 'show_cluster_info',
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'show basic info about cluster and indices',
);

has arg_await_timeout => (
    init_arg      => 'await',
    is            => 'ro',
    isa           => Int,
    default       => 15,
    documentation =>
        'seconds before connection is considered failed with timeout',
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

        if ( $self->arg_verify_mapping ) {
            $self->check_health;
            unless ( $self->indices_valid( $self->_build_index_config ) ) {
                $self->print_error("Indices Verification has failed!");
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

sub show_info {
    my $self    = $_[0];
    my $info_rs = {
        'cluster_info' => \%{ $self->cluster_info },
        'indices_info' => \%{ $self->indices_info },
    };
    log_info { Cpanel::JSON::XS->new->utf8->pretty->encode($info_rs) };
}

sub _build_index_config {
    my $self        = $_[0];
    my $docs        = es_config->documents;
    my $indices     = {};
    my $api_version = $self->es->api_version;
    for my $name ( sort keys %$docs ) {
        my $doc   = $docs->{$name};
        my $index = $doc->{index}
            or die "no index defined for $name documents";
        die "$index specified for multiple documents"
            if $indices->{$index};
        my $mapping  = es_config->mapping( $name, $api_version );
        my $settings = es_config->index_settings( $name, $api_version );
        $indices->{$index} = {
            settings => $settings,
            mappings => $mapping,
        };
    }

    return $indices;
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
            if ( !$deploy_mappings ) {
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
