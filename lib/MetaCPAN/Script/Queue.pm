package MetaCPAN::Script::Queue;

use strict;
use warnings;

use MetaCPAN::Queue ();
use MetaCPAN::Types qw( Dir File );
use Moose;

has file => (
    is        => 'ro',
    isa       => File,
    predicate => '_has_file',
    coerce    => 1,
);

has _minion => (
    is      => 'ro',
    isa     => 'Minion',
    lazy    => 1,
    handles => { _add_to_queue => 'enqueue' },
    default => sub { MetaCPAN::Queue->new->minion },
);

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

sub run {
    my $self = shift;
    if ( $self->_has_file ) {
        $self->_add_to_queue( index_release => [ $self->file->stringify ] );
    }
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 SYNOPSIS

    bin/metacpan queue --file https://cpan.metacpan.org/authors/id/O/OA/OALDERS/HTML-Restrict-2.2.2.tar.gz

=cut
