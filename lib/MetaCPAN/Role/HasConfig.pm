package MetaCPAN::Role::HasConfig;

use Moose::Role;

use FindBin;
use Config::ZOMG ();
use MetaCPAN::Types::TypeTiny qw(HashRef);
use Module::Runtime qw( require_module );

# Done like this so can be required by a role
sub config {
    return $_[0]->_config;
}

has _config => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_config',
);

sub _build_config {
    my $self   = shift;
    my $config = $self->_zomg("$FindBin::RealBin/..");
    return $config if $config;

    require_module('Git::Helpers');
    $config = $self->_zomg( Git::Helpers::checkout_root() );

    return $config if $config;

    die "Couldn't find config file in $FindBin::RealBin/.. or "
        . Git::Helpers::checkout_root();
}

sub _zomg {
    my $self = shift;
    my $path = shift;

    my $config = Config::ZOMG->new(
        local_suffix => $ENV{HARNESS_ACTIVE} ? 'testing' : 'local',
        name         => 'metacpan_server',
        path         => $path,
    );

    return $config->open;
}

1;
