package MetaCPAN::Queue::Helper;

use Moose;

use File::Temp ();
use MetaCPAN::Types qw( HashRef );
use Module::Load qw( load );

has backend => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_backend',
);

with 'MetaCPAN::Role::HasConfig';

# We could also use an in-memory SQLite db, but this gives us the option of not
# unlinking in order to debug the contents of the db, if we need to.

sub _build_backend {
    my $self = shift;

    if ( $ENV{HARNESS_ACTIVE} ) {
        load(Minion::Backend::SQLite);
        my $file = File::Temp->new( UNLINK => 1, SUFFIX => '.db' );
        return { SQLite => 'sqlite:' . $file };
    }

    load(Minion::Backend::Pg);
    return { Pg => $self->config->{minion_dsn} };
}

__PACKAGE__->meta->make_immutable;
1;
