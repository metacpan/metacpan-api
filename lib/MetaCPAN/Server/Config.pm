package MetaCPAN::Server::Config;

use warnings;
use strict;

use Config::ZOMG   ();
use MetaCPAN::Util qw(root_dir);

sub config {
    my $root   = root_dir();
    my $config = _zomg($root);

    if ( !$config ) {
        die "Couldn't find config file in $root";
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
