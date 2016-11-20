package MetaCPAN::Role::HasConfig;

use Moose::Role;

use FindBin qw( $RealBin );
use Hash::Merge::Simple qw(merge);
use IO::Interactive qw(is_interactive);
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
    my $self   = shift;
    my $config = Config::JFDI->new(
        name => 'metacpan_server',
        path => "$RealBin/..",
    )->get;

    if ( $ENV{HARNESS_ACTIVE} ) {
        my $tconf = Config::JFDI->new(
            name => 'metacpan',
            file => 'etc/metacpan_testing.pl'
        )->get;
        return merge( $config, $tconf );
    }

    if ( is_interactive() ) {
        my $iconf = Config::JFDI->new(
            name => 'metacpan',
            file => 'etc/metacpan_interactive.pl'
        )->get;
        return merge( $config, $iconf );
    }
    return $config;
}

1;
