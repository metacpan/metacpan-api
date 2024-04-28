package MetaCPAN::Server::Config;

use warnings;
use strict;

use Config::ZOMG    ();
use FindBin         ();
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

    return $config;
}

sub _zomg {
    my $path = shift;

    my $config = Config::ZOMG->new(
        local_suffix => $ENV{HARNESS_ACTIVE} ? 'testing' : 'local',
        name         => 'metacpan_server',
        path         => $path,
    );

    my $c = $config->open;
    if ( defined $c->{logger} && ref $c->{logger} ne 'ARRAY' ) {
        $c->{logger} = [ $c->{logger} ];
    }
    return keys %{$c} ? $c : undef;
}

1;
