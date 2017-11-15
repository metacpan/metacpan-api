package MetaCPAN::Role::Logger;

use v5.10;
use Moose::Role;
use MetaCPAN::Types qw(:all);
use Log::Contextual qw( set_logger );
use Log::Log4perl ':easy';
use Path::Tiny qw( path );

has level => (
    is            => 'ro',
    isa           => Str,
    required      => 1,
    trigger       => \&set_level,
    documentation => 'Log level',
);

has logger => (
    is       => 'ro',
    required => 1,
    isa      => Logger,
    coerce   => 1,
    traits   => ['NoGetopt'],
);

sub set_level {
    my $self = shift;
    $self->logger->level(
        Log::Log4perl::Level::to_priority( uc( $self->level ) ) );
}

# NOTE: This makes the test suite print "mapping" regardless of which
# script class is actually running (the category only gets set once)
# but Log::Contextual gets mad if you call set_logger more than once.
sub set_logger_once {
    state $logger_set = 0;
    return if $logger_set;

    my $self = shift;

    set_logger $self->logger;

    $logger_set = 1;

    return;
}

# XXX NOT A MOOSE BUILDER
# XXX This doesn't belong here.
sub _build_logger {
    my ($config) = @_;
    my $log = Log::Log4perl->get_logger( $ARGV[0]
            || 'this_would_have_been_argv_0_but_there_is_no_such_thing' );
    foreach my $c (@$config) {
        my $layout = Log::Log4perl::Layout::PatternLayout->new( $c->{layout}
                || qq{%d %p{1} %c: %m{chomp}%n} );

        if ( $c->{class} =~ /Appender::File$/ && $c->{filename} ) {

            # Create the log file's parent directory if necessary.
            path( $c->{filename} )->parent->mkpath;
        }

        my $app = Log::Log4perl::Appender->new( $c->{class}, %$c );

        $app->layout($layout);
        $log->add_appender($app);
    }
    return $log;
}

1;
