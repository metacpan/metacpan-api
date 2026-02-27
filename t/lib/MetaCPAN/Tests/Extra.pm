package MetaCPAN::Tests::Extra;
use Test::More;
use Test::Routine;
use MetaCPAN::Types qw( CodeRef );

around BUILDARGS => sub {
    my ( $orig, $class, @args ) = @_;
    my $attr = $class->$orig(@args);

    delete $attr->{_expect}{extra_tests};

    return $attr;
};

has _extra_tests => (
    is        => 'ro',
    isa       => CodeRef,
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
