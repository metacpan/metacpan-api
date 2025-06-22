package MetaCPAN::Server::Config;

use warnings;
use strict;

use Config::ZOMG            ();
use MetaCPAN::Util          qw(root_dir);
use Data::Visitor::Callback ();

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
        name => 'metacpan_server'
            . ( $ENV{HARNESS_ACTIVE} ? '_testing' : '' ),
        path => $path,
    );

    my $c = $config->open;
    if ( defined $c->{logger} && ref $c->{logger} ne 'ARRAY' ) {
        $c->{logger} = [ $c->{logger} ];
    }

    my $root = root_dir();
    my $v    = Data::Visitor::Callback->new(
        plain_value => sub {
            return unless defined $_;
            s{__HOME__}{$root}ge;
        }
    );
    $v->visit($c);

    return keys %{$c} ? $c : undef;
}

1;
