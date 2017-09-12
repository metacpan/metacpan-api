package MetaCPAN::Script::Runner;

use strict;
use warnings;

use Config::ZOMG ();
use File::Path   ();
use Hash::Merge::Simple qw(merge);
use IO::Interactive qw(is_interactive);
use Module::Pluggable search_path => ['MetaCPAN::Script'];
use Module::Runtime ();

sub run {
    my ( $class, @actions ) = @ARGV;
    my %plugins
        = map { ( my $key = $_ ) =~ s/^MetaCPAN::Script:://; lc($key) => $_ }
        plugins;
    die "Usage: metacpan [command] [args]" unless ($class);
    Module::Runtime::require_module( $plugins{$class} );

    my $config = build_config();

    foreach my $logger ( @{ $config->{logger} || [] } ) {
        my $path = $logger->{filename} or next;
        $path =~ s{([^/]+)$}{};
        -d $path
            or File::Path::mkpath($path);
    }

    my $obj = $plugins{$class}->new_with_options($config);
    $obj->run;
}

sub build_config {
    my $config = Config::ZOMG->new(
        name => 'metacpan',
        path => 'etc'
    )->load;
    if ( $ENV{HARNESS_ACTIVE} ) {
        my $tconf = Config::ZOMG->new(
            name => 'metacpan',
            file => 'etc/metacpan_testing.pl'
        )->load;
        $config = merge $config, $tconf;
    }
    elsif ( is_interactive() ) {
        my $iconf = Config::ZOMG->new(
            name => 'metacpan',
            file => 'etc/metacpan_interactive.pl'
        )->load;
        $config = merge $config, $iconf;
    }
    return $config;
}

# AnyEvent::Run calls the main method
*main = \&run;

1;
