package MetaCPAN::Role::HasConfig;

use Moose::Role;

use MetaCPAN::Types qw(HashRef);

use FindBin;

has config => (
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
