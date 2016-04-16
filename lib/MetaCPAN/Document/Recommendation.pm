package MetaCPAN::Document::Recommendation;
use Moose;
use ElasticSearchX::Model::Document;
use MetaCPAN::Types qw(:all);
use DateTime;
use MetaCPAN::Util;

has id => (
    is => 'ro',
    id => [qw(user module )],
);

has [qw(user module alternative)] => (
    is       => 'ro',
    required => 1,
);

=head2 date

L<DateTime> when the item was created.

=cut

has date => (
    is       => 'ro',
    required => 1,
    isa      => 'DateTime',
    default  => sub { DateTime->now },
);

=head2 timestamp

Sets the C<_timestamp> field to the value of L</date>.

=cut

has timestamp => (
    is        => 'ro',
    timestamp => { path => 'date', store => 1 },
);

__PACKAGE__->meta->make_immutable;

