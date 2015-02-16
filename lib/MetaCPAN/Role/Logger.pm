package MetaCPAN::Role::Logger;

use Moose::Role;
use MetaCPAN::Types qw(:all);
use Log::Log4perl ':easy';
use Path::Class ();

has level => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    trigger       => \&set_level,
    documentation => 'Log level',
);

has logger => (
    is        => 'ro',
    required  => 1,
    isa       => Logger,
    coerce    => 1,
    predicate => 'has_logger',
    traits    => ['NoGetopt'],
);

sub set_level {
    my $self = shift;
    $self->logger->level(
        Log::Log4perl::Level::to_priority( uc( $self->level ) ) );
}

# XXX NOT A MOOSE BUILDER
# XXX This doesn't belong here.
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

1;
