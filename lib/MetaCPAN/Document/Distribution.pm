package MetaCPAN::Document::Distribution;
use Moose;
use ElasticSearch::Document;

has name    => ( id       => 1 );
has ratings => ( isa      => 'Int', default => 0 );
has rating  => ( required => 0, isa => 'Num' );
has [qw(pass fail na unknown)] => ( isa => 'Int', default => 0 );

__PACKAGE__->meta->make_immutable;
