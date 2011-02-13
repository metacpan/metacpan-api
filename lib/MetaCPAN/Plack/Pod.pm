package MetaCPAN::Plack::Pod;

use base 'MetaCPAN::Plack::Base';
use strict;
use warnings;

sub index { 'file' }

sub query {
    shift;
    return { query  => { term => { module    => shift } },
         size   => 1,
         sort   => { date      => { reverse => \1 } } 
         };
}

sub handle {
    my ($self, $env) = @_;
    $self->get_first_result($env);
}


1;
__END__

=head1 METHODS

=head2 index

Returns C<file>, because ther eis no C<pod> index, so we look
the module up in the C<file> index.

=head2 query

Builds a query that looks for the name of the module,
sorts by date descending and fetches only to first 
result.

=head2 handle

Get the first result from the response and return it.

=head1 SEE ALSO

L<MetaCPAN::Plack::Base>