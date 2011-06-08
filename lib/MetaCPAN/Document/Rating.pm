package MetaCPAN::Document::Rating;
use Moose;
use ElasticSearchX::Model::Document;
use ElasticSearchX::Model::Document::Types qw(:all);
use MooseX::Types::Structured qw(Dict Tuple Optional);
use MooseX::Types::Moose qw(Int Num Bool Str ArrayRef HashRef Undef);

has user => ( required => 1, is => 'ro', isa => Str );
has details =>
  ( required => 0, is => 'ro', isa => Dict [ documentation => Str ] );
has rating =>
  ( required => 1, is => 'ro', isa => Num, builder => '_build_rating' );
has distribution => ( required => 1, is => 'ro', isa => Str );
has release      => ( required => 1, is => 'ro', isa => Str );
has author       => ( required => 1, is => 'ro', isa => Str );
has date =>
  ( required => 1, isa => 'DateTime', default => sub { DateTime->now } );
has helpful => (
    required => 1,
    isa      => ArrayRef [ Dict [ user => Str, value => Bool ] ],
    default => sub { [] } );

sub _build_rating {
    my $self = shift;
    die "Provide details to calculate a rating";
    my %details = %{ $self->details };
    my $rating  = 0;
    $rating += $_ for ( values %details );
    return $rating / scalar keys %details;
}

__PACKAGE__->meta->make_immutable;
