package MetaCPAN::Tests::Extra;
use Test::Routine;
use Test::More;

has _extra_tests => (
    is        => 'ro',
    isa       => 'CodeRef',
    init_arg  => 'extra_tests',
    predicate => 'has_extra_tests',
);

test 'extra tests' => sub {
    my ($self) = @_;

    plan skip_all => 'No extra tests defined'
        if !$self->has_extra_tests;

    $self->_extra_tests->($self);
};

1;
