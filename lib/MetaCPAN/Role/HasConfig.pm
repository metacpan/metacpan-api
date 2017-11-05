package MetaCPAN::Role::HasConfig;

use Moose::Role;

use FindBin;
use Config::ZOMG ();
use MetaCPAN::Types qw(HashRef);

# Done like this so can be required by a roles
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
    my $self = shift;
    return Config::ZOMG->new(
        name => 'metacpan_server',
        path => "$FindBin::RealBin/..",
    )->load;
}

1;
