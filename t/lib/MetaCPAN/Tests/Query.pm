package MetaCPAN::Tests::Query;

use Test::Routine;

use MetaCPAN::ESConfig        qw( es_doc_path );
use MetaCPAN::Server::Test    ();
use MetaCPAN::Types::TypeTiny qw( ES ArrayRef HashRef InstanceOf Str );
use Test::More;
use Try::Tiny qw( try );

around BUILDARGS => sub {
    my ( $orig, $class, @args ) = @_;
    my $attr = $class->$orig(@args);

    my $expect = {%$attr};

    return { _expect => $expect, %$attr };
};

with qw(
    MetaCPAN::Tests::Extra
    MetaCPAN::Tests::PSGI
);

has _type => (
    is      => 'ro',
    isa     => Str,
    builder => '_build_type',
);

has es => (
    is      => 'ro',
    isa     => ES,
    lazy    => 1,
    default => sub { MetaCPAN::Server::Test::es() },
);

has search => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_search',
);

sub _do_search {
    my ($self) = @_;
    my $query  = $self->search;
    my $res    = $self->es->search(
        es_doc_path( $self->_type ),
        body => {
            query => $query,
            size  => 1,
        },
    );
    my $hit = $res->{hits}{hits}[0];
    return $hit ? $hit->{_source} : undef;
}

has data => (
    is        => 'ro',
    predicate => 'has_data',
    lazy      => 1,
    default   => sub { $_[0]->_do_search },
);

has _expectations => (
    is       => 'ro',
    isa      => HashRef,
    init_arg => '_expect',
);

test 'expected attributes' => sub {
    my ($self) = @_;
    my $exp    = $self->_expectations;
    my $data   = $self->data;

    foreach my $key ( sort keys %$exp ) {

      # Skip attributes of the test class that aren't attributes of the model.
      #next unless exists $data->{$key};

        is_deeply $data->{$key}, $exp->{$key}, $key
            or diag Test::More::explain $data->{$key};
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
