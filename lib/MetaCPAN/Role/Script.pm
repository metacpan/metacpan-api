package MetaCPAN::Role::Script;

use Moose::Role;

use Carp                       ();
use IO::Prompt::Tiny           qw( prompt );
use Log::Contextual            qw( :log :dlog );
use MetaCPAN::Model            ();
use MetaCPAN::Types::TypeTiny  qw( AbsPath Bool ES HashRef Int Path Str );
use MetaCPAN::Util             qw( root_dir );
use Mojo::Server               ();
use Term::ANSIColor            qw( colored );
use MetaCPAN::Model::ESWrapper ();

use MooseX::Getopt::OptionTypeMap ();
for my $type ( Path, AbsPath, ES ) {
    MooseX::Getopt::OptionTypeMap->add_option_type_to_map( $type, '=s' );
}

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
    default => sub { root_dir() },
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

sub _build_model {
    my $self = shift;

    # es provided by ElasticSearchX::Model::Role

    my $es = MetaCPAN::Model::ESWrapper->new( $self->es );
    return MetaCPAN::Model->new( es => $es );
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

sub run { }
before run => sub {
    my $self = shift;
    $self->set_logger_once;
};

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
