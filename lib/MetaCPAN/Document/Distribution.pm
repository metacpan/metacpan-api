package MetaCPAN::Document::Distribution;

use Moose;
use ElasticSearchX::Model::Document;
use MetaCPAN::Types qw(BugSummary);
use MooseX::Types::Moose qw(ArrayRef);
use namespace::autoclean;

has name => ( is => 'ro', required => 1, id => 1 );
has bugs => (
    is      => 'rw',
    isa     => ArrayRef[BugSummary],
    lazy    => 1,
    default => sub { [] },
    dynamic => 1,
);

sub add_bugs {
    my ( $self, $add ) = @_;
    BugSummary->assert_valid($add);
    my $bugs = {
        ( map { $_->{source} => $_ } @{ $self->bugs } ),
        $add->{source} => $add,
    };
    $self->bugs( [ values %$bugs ] );
}

__PACKAGE__->meta->make_immutable;

1;
