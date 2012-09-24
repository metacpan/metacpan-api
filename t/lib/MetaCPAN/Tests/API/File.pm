package MetaCPAN::Tests::API::File;
use Test::Routine;
with qw(
    MetaCPAN::Tests::API
);
use Test::More;
use namespace::autoclean;

has [qw( author release path )] => (
    is         => 'ro',
    isa        => 'Str',
);

has file_uri => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

sub _build_file_uri {
    my ($self, $mod) = @_;
    return "/file/" . join('/', $self->author, $self->release, $self->path);
}

has file_basename => (
    is          => 'ro',
    isa         => 'Str',
    lazy        => 1,
    default     => sub { (shift->path =~ m{([^/]+)$})[0] },
);

has [qw( associated_pod documentation )] => (
    is          => 'ro',
    isa         => 'Maybe[Str]',
);

has status => (
    is          => 'ro',
    isa         => 'Str',
    default     => 'latest',
);

has description => (
    is          => 'ro',
    isa         => 'Regexp',
    predicate   => 'has_description'
);

sub _test_file_structure {
    my ($self, $data) = @_;

    is($data->{author},  $self->author,  'author');
    is($data->{release}, $self->release, 'release');
    is($data->{path},    $self->path,    'path');
    is($data->{name},    $self->file_basename, 'file basename');
    is($data->{module}->[0]->{associated_pod}, $self->associated_pod, 'associated pod');
    is($data->{documentation}, $self->documentation, 'documentation');
    is($data->{status},  $self->status,  'status');

    if( $self->has_description ){
        like $data->{description}, $self->description, 'description';
    }
    else {
        is $data->{description}, undef, 'description';
    }
}

test file_structure => sub {
    my ($self) = @_;
    my $file = $self->request_content(GET => $self->file_uri);
    $self->_test_file_structure($file);
};

1;
