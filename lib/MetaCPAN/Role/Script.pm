package MetaCPAN::Role::Script;

use Moose::Role;

use ElasticSearchX::Model::Document::Types qw(:all);
use FindBin;
use Git::Helpers qw( checkout_root );
use Log::Contextual qw( :log :dlog );
use MetaCPAN::Model;
use MetaCPAN::Types qw(:all);
use MetaCPAN::Queue ();
use Term::ANSIColor qw( colored );
use IO::Interactive qw( is_interactive );
use IO::Prompt;

use Carp ();

with( 'MetaCPAN::Role::HasConfig', 'MetaCPAN::Role::Fastly',
    'MetaCPAN::Role::Logger' );

has cpan => (
    is      => 'ro',
    isa     => Dir,
    lazy    => 1,
    builder => '_build_cpan',
    coerce  => 1,
    documentation =>
        'Location of a local CPAN mirror, looks for $ENV{MINICPAN} and ~/CPAN',
);

has die_on_error => (
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'Die on errors instead of simply logging',
);

has ua => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_ua',
);

has proxy => (
    is        => 'ro',
    isa       => Str,
    predicate => '_has_proxy',
);

has es => (
    is            => 'ro',
    isa           => ES,
    lazy          => 1,
    coerce        => 1,
    default       => sub { $_[0]->config->{es} },
    documentation => 'Elasticsearch http connection string',
);

has model => (
    is       => 'ro',
    isa      => 'MetaCPAN::Model',
    init_arg => undef,
    lazy     => 1,
    traits   => ['NoGetopt'],
    default  => sub { MetaCPAN::Model->new( es => $_[0]->es ) },
);

has index => (
    reader  => '_index',
    is      => 'ro',
    isa     => Str,
    default => 'cpan',
    documentation =>
        'Index to use, defaults to "cpan" (when used: also export ES_SCRIPT_INDEX)',
);

has port => (
    isa           => Int,
    is            => 'ro',
    lazy          => 1,
    default       => sub { $_[0]->config->{port} },
    documentation => 'Port for the proxy, defaults to 5000',
);

has home => (
    is      => 'ro',
    isa     => Dir,
    lazy    => 1,
    coerce  => 1,
    default => sub { checkout_root() },
);

has _minion => (
    is      => 'ro',
    isa     => 'Minion',
    lazy    => 1,
    handles => { _add_to_queue => 'enqueue', stats => 'stats', },
    default => sub { MetaCPAN::Queue->new->minion },
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

    if ( exists $args{'index'} ) {
        die
            "when setting --index, please export ES_SCRIPT_INDEX to the same value\n"
            unless $ENV{'ES_SCRIPT_INDEX'}
            and $args{'index'} eq $ENV{'ES_SCRIPT_INDEX'};
    }

    return \%args;
}

sub handle_error {
    my ( $self, $error ) = @_;

    # Always log.
    log_fatal {$error};

    # Die if configured (for the test suite).
    Carp::croak $error if $self->die_on_error;
}

sub index {
    my $self = shift;
    return $self->model->index( $self->_index );
}

sub _build_model {
    my $self = shift;
    return MetaCPAN::Model->new( es => $self->es );
}

sub _build_ua {
    my $self = shift;
    my $ua   = LWP::UserAgent->new;

    if ( $self->_has_proxy ) {
        $self->proxy eq 'env'
            ? $ua->env_proxy
            : $ua->proxy( [qw<http https>], $self->proxy );
    }

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
        q{Couldn't find a local cpan mirror. Please specify --cpan or set MINICPAN.};

}

sub remote {
    shift->es->nodes->info->[0];
}

sub run { }

before run => sub {
    my $self = shift;

    $self->set_logger_once;
};

sub are_you_sure {
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

1;

__END__

=pod

=head1 SYNOPSIS

Roles which should be available to all modules.

=cut
