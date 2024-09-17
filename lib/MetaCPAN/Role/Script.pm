package MetaCPAN::Role::Script;

use Moose::Role;

use Carp                                   ();
use ElasticSearchX::Model::Document::Types qw( ES );
use File::Path                             ();
use IO::Prompt::Tiny                       qw( prompt );
use Log::Contextual                        qw( :log :dlog );
use MetaCPAN::Model                        ();
use MetaCPAN::Types::TypeTiny              qw( Bool HashRef Int Path Str );
use MetaCPAN::Util                         qw( checkout_root );
use Mojo::Server                           ();
use Term::ANSIColor                        qw( colored );

with( 'MetaCPAN::Role::HasConfig', 'MetaCPAN::Role::Fastly',
    'MetaCPAN::Role::Logger' );

has cpan => (
    is            => 'ro',
    isa           => Path,
    lazy          => 1,
    builder       => '_build_cpan',
    coerce        => 1,
    documentation =>
        'Location of a local CPAN mirror, looks for $ENV{MINICPAN} and ~/CPAN',
);

has cpan_file_map => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_cpan_file_map',
    traits  => ['NoGetopt'],
);

has die_on_error => (
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'Die on errors instead of simply logging',
);

has exit_code => (
    isa           => Int,
    is            => 'rw',
    default       => 0,
    documentation => 'Exit Code to be returned on termination',
);

has arg_await_timeout => (
    init_arg      => 'await',
    is            => 'ro',
    isa           => Int,
    default       => 15,
    documentation =>
        'seconds before connection is considered failed with timeout',
);

has ua => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_ua',
);

has proxy => (
    is      => 'ro',
    isa     => Str,
    default => '',
);

has es => (
    is            => 'ro',
    isa           => ES,
    required      => 1,
    init_arg      => 'elasticsearch_servers',
    coerce        => 1,
    documentation => 'Elasticsearch http connection string',
);

has model => (
    is       => 'ro',
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_model',
    traits   => ['NoGetopt'],
);

has index => (
    reader        => '_index',
    is            => 'ro',
    isa           => Str,
    lazy          => 1,
    default       => 'cpan',
    documentation =>
        'Index to use, defaults to "cpan" (when used: also export ES_SCRIPT_INDEX)',
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

has aliases_info => (
    isa     => HashRef,
    traits  => ['Hash'],
    is      => 'rw',
    default => sub { {} },
);

has port => (
    isa           => Int,
    is            => 'ro',
    required      => 0,
    lazy          => 1,
    default       => sub {5000},
    documentation => 'Port for the proxy, defaults to 5000',
);

has home => (
    is      => 'ro',
    isa     => Path,
    lazy    => 1,
    coerce  => 1,
    default => sub { checkout_root() },
);

has quarantine => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_quarantine',
);

has _minion => (
    is      => 'ro',
    isa     => 'Minion',
    lazy    => 1,
    handles => { _add_to_queue => 'enqueue', stats => 'stats', },
    default => sub { Mojo::Server->new->build_app('MetaCPAN::API')->minion },
);

has queue => (
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'add indexing jobs to the minion queue',
);

sub BUILDARGS {
    my ( $self, @args ) = @_;
    my %args = @args == 1 ? %{ $args[0] } : @args;

    if ( exists $args{index} ) {
        die
            "when setting --index, please export ES_SCRIPT_INDEX to the same value\n"
            unless $ENV{ES_SCRIPT_INDEX}
            and $args{index} eq $ENV{ES_SCRIPT_INDEX};
    }

    return \%args;
}

sub handle_error {
    my ( $self, $error, $die_always ) = @_;

    # Die if configured (for the test suite).
    $die_always = $self->die_on_error unless defined $die_always;

    # Always log.
    log_fatal {$error};

    $! = $self->exit_code if ( $self->exit_code != 0 );

    Carp::croak $error if $die_always;
}

sub print_error {
    my ( $self, $error ) = @_;

    log_error {$error};
}

sub index {
    my $self = shift;
    return $self->model->index( $self->_index );
}

sub _build_model {
    my $self = shift;

    # es provided by ElasticSearchX::Model::Role
    return MetaCPAN::Model->new( es => $self->es );
}

sub _build_ua {
    my $self  = shift;
    my $ua    = LWP::UserAgent->new;
    my $proxy = $self->proxy;

    if ($proxy) {
        $proxy eq 'env'
            ? $ua->env_proxy
            : $ua->proxy( [qw<http https>], $proxy );
    }

    $ua->agent('MetaCPAN');

    return $ua;
}

sub _build_cpan {
    my $self = shift;
    my @dirs = (
        $ENV{MINICPAN},    '/home/metacpan/CPAN',
        "$ENV{HOME}/CPAN", "$ENV{HOME}/minicpan",
    );
    foreach my $dir ( grep {defined} @dirs ) {
        return $dir if -d $dir;
    }
    die
        "Couldn't find a local cpan mirror. Please specify --cpan or set MINICPAN";

}

sub _build_cpan_file_map {
    my $self = shift;
    my $ls   = $self->cpan->child(qw(indices find-ls.gz));
    unless ( -e $ls ) {
        die "File $ls does not exist";
    }
    log_info {"Reading $ls"};
    my $cpan = {};
    open my $fh, "<:gzip", $ls;
    while (<$fh>) {
        my $path = ( split(/\s+/) )[-1];
        next unless ( $path =~ /^authors\/id\/\w+\/\w+\/(\w+)\/(.*)$/ );
        $cpan->{$1}{$2} = 1;
    }
    close $fh;
    return $cpan;
}

sub _build_quarantine {
    my $path = "$ENV{HOME}/QUARANTINE";
    if ( !-d $path ) {
        File::Path::mkpath($path);
    }
    return $path;
}

sub remote {
    shift->es->nodes->info->[0];
}

sub run { }
before run => sub {
    my $self = shift;
    $self->set_logger_once;
};

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

sub _get_aliases_info {
    my ( $self, $irefresh ) = @_;

    if ( $irefresh || scalar( keys %{ $self->aliases_info } ) == 0 ) {
        my $sinfo_rs = $self->es->cat->aliases( h => [ 'alias', 'index' ] );
        my $saliases_parsing = qr/^([^[:space:]]+) +([^[:space:]]+)/m;

        $self->aliases_info( {} );

        while ( $sinfo_rs =~ /$saliases_parsing/g ) {
            $self->aliases_info->{$1} = { 'alias_name' => $1, 'index' => $2 };
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

    if ($ihealth) {
        $self->_get_aliases_info($irefresh);

        $ihealth = 0 if ( scalar( keys %{ $self->aliases_info } ) == 0 );
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

sub are_you_sure {
    my ( $self, $msg ) = @_;
    my $iconfirmed = 0;

    if ( -t *STDOUT ) {
        my $answer
            = prompt colored( ['bold red'], "*** Warning ***: $msg" ) . "\n"
            . 'Are you sure you want to do this (type "YES" to confirm) ? ';
        if ( $answer ne 'YES' ) {
            log_error {"Confirmation incorrect: '$answer'"};
            print "Operation will be interruped!\n";

            #Set System Error: 125 - ECANCELED - Operation canceled
            $self->exit_code(125);
            $self->handle_error( 'Operation canceled on User Request', 1 );
        }
        else {
            log_info {'Operation confirmed.'};
            print "alright then...\n";
            $iconfirmed = 1;
        }
    }
    else {
        log_info {"*** Warning ***: $msg"};
        $iconfirmed = 1;
    }

    return $iconfirmed;
}

before perform_purges => sub {
    my ($self) = @_;
    if ( $self->has_surrogate_keys_to_purge ) {
        log_info {
            "CDN Purge: " . join ', ', $self->surrogate_keys_to_purge;
        };
    }
};

1;

__END__

=pod

=head1 NAME

MetaCPAN::Role::Script - Base Role which is used by many command line applications

=head1 SYNOPSIS

Roles which should be available to all modules.

=head1 OPTIONS

This Role makes the command line application accept the following options

=over 4

=item Option C<--await 15>

This option will set the I<ElasticSearch Availability Check Timeout>.
After C<await> seconds the Application will fail with an Exception and the Exit Code [112]
(C<112 - EHOSTDOWN - Host is down>) will be returned

    bin/metacpan <script_name> --await 15

B<Exit Code:> If the I<ElasticSearch> service does not become available
within C<await> seconds it exits the Script with Exit Code C< 112 >.

See L<Method C<await()>>

=back

=head1 METHODS

This Role provides the following methods

=over 4

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
the health state of the indices and the created aliases.
This information is stored in C<cluster_info>, C<indices_info> and C<aliases_info> as C<HASH> structures.
If the parameter C<refresh> is set to C< 1 > the structures C<indices_info> and C<aliases_info> will always
be updated.
If the C<cluster_info> structure is empty it calls first the C<await()> method.
If the service is unavailable the C<await()> method will produce an exception and the structures will be empty
The method returns C< 1 > when the C<cluster_info> is populated, none of the indices in C<indices_info> has
the Health State I<red> and at least one alias is created in C<aliases_info>
otherwise the method returns C< 0 >

B<Parameters:>

C<refresh> - Integer evaluated as boolean when set to C< 1 > the cluster info structures
will always be updated.

See L<Method C<await()>>

=item C<are_you_sure()>

Requests the user to confirm the operation with "I< YES >"

B<Exceptions:> When the operator input does not match "I< YES >" it will exit the Script
with Exit Code [125] (C<125 - ECANCELED - Operation canceled>).

=item C<handle_error( error_message[, die_always ] )>

Logs the string C<error_message> with the log function as fatal error.
If C<exit_code> is not equel C< 0 > sets its value in C< $! >.
If the option C<--die_on_error> is enabled it throws an Exception with C<error_message>.
If the parameter C<die_always> is set it overrides the option C<--die_on_error>.

=item C<print_error( error_message )>

Logs the string C<error_message> with the log function and displays it in red.
But it does not end the application.

=back

=cut
