package MetaCPAN::Model::User::Session;

use strict;
use warnings;

use Moose;
use ElasticSearchX::Model::Document;

=head2 timestamp

Sets the C<_timestamp> field.

=cut

has timestamp => (
    is        => 'ro',
    timestamp => {}, # { store => 1 },
);

__PACKAGE__->meta->make_immutable;
1;
