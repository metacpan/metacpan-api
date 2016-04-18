package MetaCPAN::Tests::Model;
use Test::Routine;
use Test::More;
use Try::Tiny;

use MetaCPAN::Server::Test ();
use MetaCPAN::Types qw( ArrayRef HashRef Str );

with qw(
    MetaCPAN::Tests::Extra
    MetaCPAN::Tests::PSGI
);

around BUILDARGS => sub {
    my ( $orig, $class, @args ) = @_;
    my $attr   = $class->$orig(@args);
    my $expect = {};

    # Get a list of defined attributes.
    my %known = map { ( $_ => 1 ) }
        map { $_->init_arg() } $class->meta->get_all_attributes();

    # We could extract any keys that don't have defined attributes
    # and only test those, but it shouldn't hurt to test the others
    # (the ones that do have attributes defined).  This way we won't *not*
    # test something by accident if we define an attribute for it
    # and really anything we specify shouldn't be different on the result.
    while ( my ( $k, $v ) = each %$attr ) {
        $expect->{$k} = $attr->{$k};
        delete $attr->{$k} if !$known{$k};
    }

    return { _expect => $expect, %$attr };
};

has _type => (
    is      => 'ro',
    isa     => Str,
    builder => '_build_type',
);

has _model => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build__model',
);

sub _build__model {
    return MetaCPAN::Server::Test::model();
}

has index => (
    reader  => '_index',
    isa     => Str,
    default => 'cpan',
);

sub index {
    my ($self) = @_;
    $self->_model->index( $self->_index );
}

has search => (
    is      => 'ro',
    isa     => ArrayRef,
    lazy    => 1,
    builder => '_build_search',
);

sub _do_search {
    my ($self) = @_;
    my ( $method, @params ) = @{ $self->search };
    return $self->index->type( $self->_type )->$method(@params);
}

has data => (
    is        => 'ro',
    predicate => 'has_data',
    lazy      => 1,
    default   => sub { $_[0]->_do_search },
);

has _expectations => (
    is        => 'ro',
    isa       => HashRef,
    predicate => 'has_expectations',
    init_arg  => '_expect',
);

test 'expected model attributes' => sub {
    my ($self) = @_;
    my $exp    = $self->_expectations;
    my $data   = $self->data;

    foreach my $key ( sort keys %$exp ) {

      # Skip attributes of the test class that aren't attributes of the model.
        next unless $data->can($key);

        is_deeply $data->$key, $exp->{$key}, $key
            or diag Test::More::explain $data->$key;
    }
};

around run_test => sub {
    my ( $orig, $self, @args ) = @_;

    # If we haven't performed the search yet, do it now.
    if ( !$self->has_data ) {

        # TODO: An attribute that says to expect to not find (and return ok).

        ok( $self->data, 'Search successful' )
            or diag( Test::More::explain( $self->search ) );
    }

    # If the object wasn't found (either just now or in a previous test),
    # don't proceed with the tests because they will all fail miserably
    # (can't call method on undefined value, etc.).
    if ( !defined( $self->data ) ) {
        my $desc = 'Search failed; cannot proceed';

        # We can make the test output a little nicer
        # (but this API might not be documented.)
        try { $desc .= ' with test: ' . $args[0]->name };

        # Show a failure and short-circuit.
        return ok( 0, $desc );
    }

    # Continue with Test::Routine's subtest.
    return $self->$orig(@args);
};

1;
