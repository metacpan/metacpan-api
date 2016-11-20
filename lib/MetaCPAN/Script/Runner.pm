package MetaCPAN::Script::Runner;

use MetaCPAN::Moose;

use Config::JFDI;
use File::Path ();
use Hash::Merge::Simple qw(merge);
use IO::Interactive qw(is_interactive);
use Module::Pluggable search_path => ['MetaCPAN::Script'];
use Module::Runtime ();

with 'MetaCPAN::Role::HasConfig';

sub run {
    my $self = shift;
    my ( $class, @actions ) = @ARGV;
    my %plugins
        = map { ( my $key = $_ ) =~ s/^MetaCPAN::Script:://; lc($key) => $_ }
        plugins;
    die "Usage: metacpan [command] [args]" unless ($class);
    Module::Runtime::require_module( $plugins{$class} );

    my $config = $self->config;

    foreach my $logger ( @{ $config->{logger} || [] } ) {
        my $path = $logger->{filename} or next;
        $path =~ s{([^/]+)$}{};
        -d $path
            or File::Path::mkpath($path);
    }

    my $obj = $plugins{$class}->new_with_options;
    $obj->run;
}

# AnyEvent::Run calls the main method
*main = \&run;

1;
