package MetaCPAN::Tests::API::Module;
use Test::Routine;
with qw(
    MetaCPAN::Tests::API::File
);
use Test::More;
use namespace::autoclean;

has package => (
    is         => 'ro',
    isa        => 'Str',
    lazy       => 1,
    default    => sub { shift->documentation }
);

has module_uri => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

sub _build_module_uri {
    my ($self) = @_;
    return "/module/" . $self->package;
}

# /file and /module should return the same data
test module_structure => sub {
    my ($self) = @_;
    my $mod = $self->request_content(GET => $self->module_uri);
    $self->_test_file_structure($mod);
};

1;
