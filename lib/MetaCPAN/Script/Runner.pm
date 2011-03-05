package MetaCPAN::Script::Runner;
use strict;
use warnings;
use Class::MOP;
use Config::JFDI;
use FindBin;
use IO::Interactive qw(is_interactive);
use Hash::Merge::Simple qw/ merge /;

sub run {
    my ( $class, @actions ) = @ARGV;

    die "Usage: metadbic [command] [args]" unless ($class);

    $class = 'MetaCPAN::Script::' . ucfirst($class);
    Class::MOP::load_class($class);

    my $config =
      Config::JFDI->new( name => "metacpan",
                         path => "$FindBin::RealBin/../etc"
      )->get;
    if ( is_interactive() ) {
        my $iconf = Config::JFDI->new(
                      name => "metacpan",
                      file => "$FindBin::RealBin/../etc/metacpan_interactive.pl"
        )->get;
        $config = merge $config, $iconf;
    }
    my $obj = $class->new_with_options($config);
    $obj->run;
}

# AnyEvent::Run calls the main method
*main = \&run;

1;