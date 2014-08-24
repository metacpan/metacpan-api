package MetaCPAN::Tests::Distribution;
use Test::Routine;
use Test::More;
use version;

with qw(
    MetaCPAN::Tests::Model
);

sub _build_type {'distribution'}

sub _build_search {
    return [ get => $_[0]->name ];
}

my @attrs = qw(
    name
);

has [@attrs] => (
    is  => 'ro',
    isa => 'Str',
);

test 'distribution attributes' => sub {
    my ($self) = @_;

    foreach my $attr (@attrs) {
        is $self->data->$attr, $self->$attr, $attr;
    }
};

1;
