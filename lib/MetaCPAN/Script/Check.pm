package MetaCPAN::Script::Check;

use strict;
use warnings;

use File::Spec::Functions qw(catfile);
use Log::Contextual qw( :log );
use Moose;

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has modules => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    documentation => 'check CPAN packages against MetaCPAN',
);

has module => (
    is            => 'ro',
    isa           => 'Str',
    default       => '',
    documentation => 'the name of the module you are checking',
);

has max_errors => (
    is      => 'ro',
    isa     => 'Int',
    default => 0,
    documentation =>
        'the maximum number of errors to encounter before stopping',
);

has errors_only => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    documentation => 'just show errors',
);

has error_count => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
    traits  => ['NoGetopt']
);

sub run {
    my $self = shift;

    $self->check_modules if $self->modules;
}

sub check_modules {
    my $self = shift;
    my ( undef, @args ) = @{ $self->extra_argv };
    my $packages_file
        = catfile( $self->cpan, 'modules', '02packages.details.txt' );
    my $target = $self->module;
    my $es     = $self->es;
    my $packages_fh;

    if ( -e $packages_file ) {
        open( $packages_fh, '<', $packages_file )
            or die "Could not open packages file $packages_file: $!";
    }
    else {
        die q{Can't find 02packages.details.txt};
    }

    my $modules_start = 0;
    while ( my $line = <$packages_fh> ) {
        last if $self->max_errors && $self->error_count >= $self->max_errors;
        chomp($line);
        if ($modules_start) {
            my ( $pkg, $ver, $dist ) = split( /\s+/, $line );
            my @releases;

            # we only care about packages if we aren't searching for a
            # particular module or if it matches
            if ( !$target || $pkg eq $target ) {

             # look up this module in ElasticSearch and see what we have on it
                my $results = $es->search(
                    index => $self->index->name,
                    type  => 'file',
                    size  => 100,               # shouldn't get more than this
                    fields => [
                        qw(name release author distribution version authorized indexed maturity date)
                    ],
                    query  => { match_all => {} },
                    filter => {
                        and => [
                            { term => { 'module.name' => $pkg } },
                            { term => { 'authorized'  => 'true' } },
                            { term => { 'maturity'    => 'released' } },
                        ],
                    },
                );
                my @files = @{ $results->{hits}->{hits} };

                # now find the first latest releases for these files
                foreach my $file (@files) {
                    my $release_results = $es->search(
                        index => $self->index->name,
                        type  => 'release',
                        size  => 1,
                        fields =>
                            [qw(name status authorized version id date)],
                        query  => { match_all => {} },
                        filter => {
                            and => [
                                {
                                    term => {
                                        'name' => $file->{fields}->{release}
                                    }
                                },
                                { term => { 'status' => 'latest' } },
                            ],
                        },
                    );

                    if ( $release_results->{hits}->{hits}->[0] ) {
                        push( @releases,
                            $release_results->{hits}->{hits}->[0] );
                    }
                }

               # if we didn't find the latest release, then look at all of the
               # releases so we can find out what might be wrong
                if ( !@releases ) {
                    foreach my $file (@files) {
                        my $release_results = $es->search(
                            index => $self->index->name,
                            type  => 'release',
                            size  => 1,
                            fields =>
                                [qw(name status authorized version id date)],
                            query  => { match_all => {} },
                            filter => {
                                and => [
                                    {
                                        term => {
                                            'name' =>
                                                $file->{fields}->{release}
                                        }
                                    }
                                ]
                            },
                        );

                        push( @releases,
                            @{ $release_results->{hits}->{hits} } );
                    }
                }

                # if we found the releases tell them about it
                if (@releases) {
                    if (   @releases == 1
                        && $releases[0]->{fields}->{status} eq 'latest' )
                    {
                        log_info {
                            "Found latest release $releases[0]->{fields}->{name} for $pkg";
                        }
                        unless $self->errors_only;
                    }
                    else {
                        log_error {"Could not find latest release for $pkg"};
                        foreach my $rel (@releases) {
                            log_warn {
                                "  Found release $rel->{fields}->{name}";
                            };
                            log_warn {
                                "    STATUS    : $rel->{fields}->{status}";
                            };
                            log_warn {
                                "    AUTORIZED : $rel->{fields}->{authorized}";
                            };
                            log_warn {
                                "    DATE      : $rel->{fields}->{date}";
                            };
                        }
                        $self->error_count( $self->error_count + 1 );
                    }
                }
                elsif (@files) {
                    log_error {
                        "Module $pkg doesn't have any releases in ElasticSearch!";
                    };
                    foreach my $file (@files) {
                        log_warn {"  Found file $file->{fields}->{name}"};
                        log_warn {
                            "    RELEASE    : $file->{fields}->{release}";
                        };
                        log_warn {
                            "    AUTHOR     : $file->{fields}->{author}";
                        };
                        log_warn {
                            "    AUTHORIZED : $file->{fields}->{authorized}";
                        };
                        log_warn {"    DATE       : $file->{fields}->{date}"};
                    }
                    $self->error_count( $self->error_count + 1 );
                }
                else {
                    log_error {
                        "Module $pkg [$dist] doesn't not appear in ElasticSearch!";
                    };
                    $self->error_count( $self->error_count + 1 );
                }
                last if $self->module;
            }

        }
        elsif ( !length $line ) {
            $modules_start = 1;
        }
    }
}

__PACKAGE__->meta->make_immutable;
1;

=pod

=head1 SYNOPSIS

Performs checks on the MetaCPAN data store to make sure an
author/module/distribution has been indexed correctly and has the
appropriate information.

=head2 check_modules

Checks all of the modules in CPAN against the information in ElasticSearch.
If is C<module> attribute exists, it will just look at packages that match
that module name.

=head1 TODO

=over

=item * Add support for checking authors

=item * Add support for checking releases

=back

=cut
