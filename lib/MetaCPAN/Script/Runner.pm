package MetaCPAN::Script::Runner;
use strict;
use warnings;
use Class::MOP;
use Config::JFDI;
use FindBin;
use IO::Interactive qw(is_interactive);
use Hash::Merge::Simple qw(merge);
use Module::Pluggable search_path => ['MetaCPAN::Script'];

sub run {
    my ( $class, @actions ) = @ARGV;
    my %plugins = map { (my $key = $_) =~ s/^MetaCPAN::Script:://; lc($key) => $_ } plugins;
    die "Usage: metacpan [command] [args]" unless ($class);
    Class::MOP::load_class($plugins{$class});

    my $config = build_config();
    my $obj = $plugins{$class}->new_with_options($config);
    $obj->run;
}

sub build_config {
     my $config = Config::JFDI->new( name => "metacpan",
                         path => "$FindBin::RealBin/../etc"
      )->get;
    if($ENV{HARNESS_ACTIVE}) {
        my $tconf = Config::JFDI->new(
                      name => "metacpan",
                      file => "$FindBin::RealBin/../etc/metacpan_testing.pl"
        )->get;
        $config = merge $config, $tconf;
    } elsif ( is_interactive() ) {
        my $iconf = Config::JFDI->new(
                      name => "metacpan",
                      file => "$FindBin::RealBin/../etc/metacpan_interactive.pl"
        )->get;
        $config = merge $config, $iconf;
    }
    return $config;
}

# AnyEvent::Run calls the main method
*main = \&run;

1;
