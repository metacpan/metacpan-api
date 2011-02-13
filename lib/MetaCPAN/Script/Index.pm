package MetaCPAN::Script::Index;

use Moose;
with 'MooseX::Getopt';
use MetaCPAN;

has [qw(create delete recreate)] => ( isa => 'Bool', is => 'rw' );

sub run {
    my $self = shift;
    my ( undef, $index ) = @{ $self->extra_argv };
    $index ||= 'cpan';
    my $es = MetaCPAN->new->es;
    if ( $self->create ) {
        $es->create_index(index => $index);
    } elsif ( $self->delete ) {
        $es->create_index(index => $index);
    } elsif ( $self->recreate ) {
        $es->delete_index(index => $index);
        $es->create_index(index => $index);
    }
}

__PACKAGE__->meta->make_immutable;
