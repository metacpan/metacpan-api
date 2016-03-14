package MetaCPAN::Queue::Helper;

use Moose;

use File::Temp;
use MetaCPAN::Types qw( HashRef );
use Minion::Backend::Pg;
use Minion::Backend::SQLite;

has backend => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_backend',
);

# We could also use an in-memory SQLite db, but this gives us the option of not
# unlinking in order to debug the contents of the db, if we need to.

sub _build_backend {
    my $self = shift;

    return $ENV{HARNESS_ACTIVE}
        ? { SQLite => 'sqlite:'
            . File::Temp->new( UNLINK => 1, SUFFIX => '.db' ) }
        : { Pg => 'postgresql://vagrant@localhost/minion_queue' };
}

__PACKAGE__->meta->make_immutable;
1;
