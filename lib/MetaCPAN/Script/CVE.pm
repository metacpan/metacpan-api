package MetaCPAN::Script::CVE;

use Moose;
use namespace::autoclean;

use Cpanel::JSON::XS          qw( decode_json );
use Log::Contextual           qw( :log :dlog );
use MetaCPAN::Types::TypeTiny qw( Bool Str Uri );
use MetaCPAN::Util            qw( hit_total numify_version true false );
use Path::Tiny                qw( path );
use Ref::Util                 qw( is_arrayref );

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has cve_url => (
    is      => 'ro',
    isa     => Uri,
    coerce  => 1,
    default => 'https://cpan-security.github.io/cpansa-feed/cpansa.json',
);

has cve_dev_url => (
    is      => 'ro',
    isa     => Uri,
    coerce  => 1,
    default => 'https://cpan-security.github.io/cpansa-feed/cpansa_dev.json',
);

has test => (
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'Test mode (pulls smaller development data set)',
);

has json_file => (
    is            => 'ro',
    isa           => Str,
    default       => 0,
    documentation =>
        'Path to JSON file to be read instead of URL (for testing)',
);

my %range_ops = qw(< lt <= lte > gt >= gte);

my %valid_keys = map { $_ => 1 } qw<
    affected_versions
    cpansa_id
    cves
    description
    distribution
    references
    releases
    reported
    severity
    versions
>;

sub run {
    my $self = shift;
    my $data = $self->retrieve_cve_data;
    $self->index_cve_data($data);
    return 1;
}

sub index_cve_data {
    my ( $self, $data ) = @_;

    my $bulk = $self->es->bulk_helper(
        index => 'cve',
        type  => 'cve',
    );

    log_info {'Updating the cve index'};

    for my $dist ( sort keys %{$data} ) {
        for my $cpansa ( @{ $data->{$dist} } ) {
            if ( !$cpansa->{cpansa_id} ) {
                log_warn { sprintf( "Dist '%s' missing cpansa_id", $dist ) };
                next;
            }

            my @matches;

            if ( !is_arrayref( $cpansa->{affected_versions} ) ) {
                log_debug {
                    sprintf( "Dist '%s' has non-array affected_versions %s",
                        $dist, $cpansa->{affected_versions} )
                };

                # Temp - remove after fixed upstream
                # (affected_versions will always be an array)
                $cpansa->{affected_versions}
                    = [ $cpansa->{affected_versions} ];

                # next;
            }

            my @filters;
            my @afv_filters;

            for my $afv ( @{ $cpansa->{affected_versions} } ) {

                # Temp - remove after fixed upstream
                # (affected_versions will always be an array)
                next unless $afv;

                my @rules = map {s/\(.*?\)//gr} split /,/, $afv;

                my @rule_filters;

                for my $rule (@rules) {
                    my ( $op, $num ) = $rule =~ /^([=<>]*)(.*)$/;
                    $num = numify_version($num);

                    if ( !$op ) {
                        log_debug {
                            sprintf(
                                "Dist '%s' - affected_versions has no operator",
                                $dist )
                        };

                        # Temp - remove after fixed upstream
                        # (affected_versions will always have an operator)
                        $op ||= '=';
                    }

                    if ( exists $range_ops{$op} ) {
                        push @rule_filters,
                            +{
                            range => {
                                version_numified =>
                                    { $range_ops{$op} => $num }
                            }
                            };
                    }
                    else {
                        push @rule_filters,
                            +{ term => { version_numified => $num } };
                    }
                }

                # multiple rules (csv) in affected_version line -> AND
                if ( @rule_filters == 1 ) {
                    push @afv_filters, @rule_filters;
                }
                elsif ( @rule_filters > 1 ) {
                    push @afv_filters, { bool => { must => \@rule_filters } };
                }
            }

            # multiple elements in affected_version -> OR
            if ( @afv_filters == 1 ) {
                push @filters, @afv_filters;
            }
            elsif ( @afv_filters > 1 ) {
                push @filters, { bool => { should => \@afv_filters } };
            }

            if (@filters) {
                my $query = {};

                my $releases = $self->es->search(
                    index => 'cpan',
                    type  => 'release',
                    body  => {
                        query => {
                            bool => {
                                must => [
                                    { term => { distribution => $dist } },
                                    @filters,
                                ]
                            }
                        },
                        _source => [ "version", "name", "author", ],
                        size    => 2000,
                    },
                );

                if ( hit_total($releases) ) {
                    ## no critic (ControlStructures::ProhibitMutatingListFunctions)
                    @matches = map { $_->[0] }
                        sort { $a->[1] <=> $b->[1] }
                        map {
                        [
                            $_->{_source},
                            numify_version( $_->{_source}{version} )
                        ];
                        } @{ $releases->{hits}{hits} };
                }
                else {
                    log_debug {
                        sprintf( "Dist '%s' doesn't have matches.", $dist )
                    };
                    next;
                }
            }

            my $doc_data = {
                distribution      => $dist,
                cpansa_id         => $cpansa->{cpansa_id},
                affected_versions => $cpansa->{affected_versions},
                cves              => $cpansa->{cves},
                description       => $cpansa->{description},
                references        => $cpansa->{references},
                reported          => $cpansa->{reported},
                severity          => $cpansa->{severity},
                versions          => [ map { $_->{version} } @matches ],
                releases => [ map {"$_->{author}/$_->{name}"} @matches ],
            };

            for my $k ( keys %{$doc_data} ) {
                delete $doc_data->{$k} unless exists $valid_keys{$k};
            }

            $bulk->update( {
                id            => $cpansa->{cpansa_id},
                doc           => $doc_data,
                doc_as_upsert => true,
            } );
        }
    }

    $bulk->flush;
}

sub retrieve_cve_data {
    my $self = shift;

    return decode_json( path( $self->json_file )->slurp ) if $self->json_file;

    my $url = $self->test ? $self->cve_dev_url : $self->cve_url;

    log_info { 'Fetching data from ', $url };
    my $resp = $self->ua->get($url);

    $self->handle_error( $resp->status_line ) unless $resp->is_success;

    # clean up headers if .json.gz is served as gzip type
    # rather than json encoded with gzip
    if ( $resp->header('Content-Type') eq 'application/x-gzip' ) {
        $resp->header( 'Content-Type'     => 'application/json' );
        $resp->header( 'Content-Encoding' => 'gzip' );
    }

    return decode_json( $resp->decoded_content );
}

__PACKAGE__->meta->make_immutable;

1;

=pod

=head1 SYNOPSIS

 # bin/metacpan cve [--test] [json_file]

=head1 DESCRIPTION

Retrieves the CPAN CVE data from its source and
updates our ES information.

=cut
