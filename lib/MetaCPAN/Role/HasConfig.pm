package MetaCPAN::Role::HasConfig;

use Moose::Role;

use MetaCPAN::Types qw(HashRef);

use FindBin;

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
    return Config::JFDI->new(
        name => 'metacpan_server',
        path => "$FindBin::RealBin/..",
    )->get;
}

1;
