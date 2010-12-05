package MetaCPAN::Extract::Role::Author;

use Moose::Role;

has 'author' => (
    is         => 'ro',
    isa        => 'MetaCPAN::Extract::Schema::Result::Zauthor',
    lazy_build => 1,
);


sub _build_author {

    my $self = shift;

    die "no pauseid" if !$self->metadata->pauseid;
    my $author = $self->schema->resultset( 'MetaCPAN::Extract::Schema::Result::Zauthor' )
        ->find_or_create( { zpauseid => $self->metadata->pauseid } );
    return $author;

}

1;
