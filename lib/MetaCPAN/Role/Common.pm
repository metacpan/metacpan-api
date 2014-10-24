package MetaCPAN::Role::Common;

use strict;
use warnings;

use ElasticSearch;
use ElasticSearchX::Model::Document::Types qw(:all);
use FindBin;
use Log::Contextual qw( set_logger :dlog );
use Log::Log4perl ':easy';
use MetaCPAN::Model;
use MetaCPAN::Types qw(:all);
use Moose::Role;
use MooseX::Types::Path::Class qw(:all);
use Path::Class ();

has 'cpan' => (
    is         => 'rw',
    isa        => Dir,
    lazy_build => 1,
    coerce     => 1,
    documentation =>
        'Location of a local CPAN mirror, looks for $ENV{MINICPAN} and ~/CPAN',
);

has level => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    trigger       => \&set_level,
    documentation => 'Log level',
);

has es => (
    isa           => ES,
    is            => 'ro',
    required      => 1,
    coerce        => 1,
    documentation => 'ElasticSearch http connection string',
);

has model => ( lazy_build => 1, is => 'ro', traits => ['NoGetopt'] );

has index => (
    reader        => '_index',
    is            => 'ro',
    isa           => 'Str',
    default       => 'cpan',
    documentation => 'Index to use, defaults to "cpan"',
);

has port => (
    isa           => 'Int',
    is            => 'ro',
    required      => 1,
    documentation => 'Port for the proxy, defaults to 5000',
);

has logger => (
    is        => 'ro',
    required  => 1,
    isa       => Logger,
    coerce    => 1,
    predicate => 'has_logger',
    traits    => ['NoGetopt'],
);

has home => (
    is      => 'ro',
    isa     => Dir,
    coerce  => 1,
    default => "$FindBin::RealBin/..",
);

has config => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_config',
);

sub _build_config {
    my $self = shift;
    return Config::JFDI->new(
        name => "metacpan_server",
        path => "$FindBin::RealBin/..",
    )->get;
}

sub index {
    my $self = shift;
    return $self->model->index( $self->_index );
}

sub set_level {
    my $self = shift;
    $self->logger->level(
        Log::Log4perl::Level::to_priority( uc( $self->level ) ) );
}

sub _build_model {
    my $self = shift;
    return MetaCPAN::Model->new( es => $self->es );
}

# NOT A MOOSE BUILDER
sub _build_logger {
    my ($config) = @_;
    my $log = Log::Log4perl->get_logger( $ARGV[0] );
    foreach my $c (@$config) {
        my $layout = Log::Log4perl::Layout::PatternLayout->new( $c->{layout}
                || "%d %p{1} %c: %m{chomp}%n" );

        if ( $c->{class} =~ /Appender::File$/ && $c->{filename} ) {

            # Create the log file's parent directory if necessary.
            Path::Class::File->new( $c->{filename} )->parent->mkpath;
        }

        my $app = Log::Log4perl::Appender->new( $c->{class}, %$c );

        $app->layout($layout);
        $log->add_appender($app);
    }
    return $log;
}

sub file2mod {
    my $self = shift;
    my $name = shift;

    $name =~ s{\Alib\/}{};
    $name =~ s{\.(pod|pm)\z}{};
    $name =~ s{\/}{::}gxms;

    return $name;
}

sub _build_cpan {
    my $self = shift;
    my @dirs = (
        $ENV{MINICPAN},    '/home/metacpan/CPAN',
        "$ENV{HOME}/CPAN", "$ENV{HOME}/minicpan"
    );
    foreach my $dir ( grep {defined} @dirs ) {
        return $dir if -d $dir;
    }
    die
        "Couldn't find a local cpan mirror. Please specify --cpan or set MINICPAN";

}

sub remote {
    shift->es->transport->default_servers->[0];
}

sub run { }
before run => sub {
    my $self = shift;
    unless ($MetaCPAN::Role::Common::log) {
        $MetaCPAN::Role::Common::log = $self->logger;
        set_logger $self->logger;
    }
    Dlog_debug {"Connected to $_"} $self->remote;
};

1;

__END__

=pod

=head1 SYNOPSIS

Roles which should be available to all modules

=cut
