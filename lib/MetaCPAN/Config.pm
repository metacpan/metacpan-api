package MetaCPAN::Config;

use warnings;
use strict;

use FindBin         ();
use Config::ZOMG    ();
use Module::Runtime qw( require_module );

sub config {
    my $config = _zomg("$FindBin::RealBin/..");
    return $config if $config;

    require_module('Git::Helpers');
    $config = _zomg( Git::Helpers::checkout_root() );

    if ( !$config ) {
        die "Couldn't find config file in $FindBin::RealBin/.. or "
            . Git::Helpers::checkout_root();
    }

    if ( defined $config->{logger} && ref $config->{logger} ne 'ARRAY' ) {
        $config->{logger} = [ $config->{logger} ];
    }

    return $config;
}

sub _zomg {
    my $path = shift;

    my $config = Config::ZOMG->new(
        local_suffix => $ENV{HARNESS_ACTIVE} ? 'testing' : 'local',
        name         => 'metacpan_server',
        path         => $path,
    );

    return $config->open;
}

1;
