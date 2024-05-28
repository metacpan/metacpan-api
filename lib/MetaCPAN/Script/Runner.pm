package MetaCPAN::Script::Runner;

use strict;
use warnings;

use File::Path        ();
use IO::Interactive   qw(is_interactive);
use MetaCPAN::Config  ();
use Module::Pluggable qw( plugins );
use Module::Runtime   ();
use Term::ANSIColor   qw( colored );
use Try::Tiny         qw( catch try );

our $EXIT_CODE = 0;

sub run {
    my ( $class, @actions ) = @ARGV;
    my %plugins
        = map { ( my $key = $_ ) =~ s/^MetaCPAN::Script:://; lc($key) => $_ }
        plugins;
    die "Usage: metacpan [command] [args]" unless ($class);
    Module::Runtime::require_module( $plugins{$class} );

    my $config = MetaCPAN::Config::config();
    $config->{es} = $config->{elasticsearch_servers};

    foreach my $logger ( @{ $config->{logger} || [] } ) {
        my $path = $logger->{filename} or next;
        $path =~ s{([^/]+)$}{};
        -d $path
            or File::Path::mkpath($path);
    }

    my $obj = undef;
    my $ex  = undef;
    try {
        $obj = $plugins{$class}->new_with_options($config);

        $obj->run;
    }
    catch {
        $ex = $_;

        $ex = { 'message' => $ex } unless ( ref $ex );

        unless ( defined $ex->{'message'} ) {
            $ex->{'message'} = $ex->{'msg'}   if ( defined $ex->{'msg'} );
            $ex->{'message'} = $ex->{'error'} if ( defined $ex->{'error'} );
        }

        if ( defined $obj
            && $obj->exit_code != 0 )
        {
            # Copying the Exit Code to propagate it to the superior level
            $EXIT_CODE = $obj->exit_code;
        }
        elsif ( $! != 0 ) {
            $EXIT_CODE = 0 + $!;
        }
        else {
            $EXIT_CODE = 1;
        }

        # Display Exception Message in red
        print colored( ['bold red'],
            "*** EXCEPTION [ $EXIT_CODE ] ***: " . $ex->{'message'} ),
            "\n";
    };

    unless ( defined $ex ) {

        # Copying the Exit Code to propagate it to the superior level
        $EXIT_CODE = $obj->exit_code;
    }

    return ( $EXIT_CODE == 0 );
}

# AnyEvent::Run calls the main method
*main = \&run;

1;
