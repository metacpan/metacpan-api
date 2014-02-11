package MetaCPAN::Tests::Release;
use Test::Routine;
use Test::More;
use version;

with qw(
    MetaCPAN::Tests::Model
);

sub _build_type {'release'}

sub _build_search {
    my ($self) = @_;
    return [
        get => {
            author => $self->author,
            name   => $self->name,
        }
    ];
}

around BUILDARGS => sub {
    my ( $orig, $self, @args ) = @_;
    my $attr = $self->$orig(@args);

    if (   !$attr->{distribution}
        && !$attr->{version}
        && $attr->{name}
        && $attr->{name} =~ /(.+?)-([0-9._]+)$/ )
    {
        @$attr{qw( distribution version )} = ( $1, $2 );
    }

    return $attr;
};

my @attrs = qw(
    author distribution version
);

has [@attrs] => (
    is  => 'ro',
    isa => 'Str',
);

has version_numified => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub { 'version'->parse( shift->version )->numify + 0 }
);

has files => (
    is      => 'ro',
    isa     => 'ArrayRef',
    lazy    => 1,
    builder => '_build_files',
);

sub _build_files {
    my ($self) = @_;
    return $self->_filter_files();
}

has modules => (
    is      => 'ro',
    isa     => 'ArrayRef',
    lazy    => 1,
    builder => '_build_modules',
);

sub _build_modules {
    my ($self) = @_;
    return $self->_filter_files(
        [ { exists => { field => 'file.module.name' } }, ] );
}

sub _filter_files {
    my ( $self, $add_filters ) = @_;
    my $release = $self->data;
    return [
        $self->index->type('file')->filter(
            {
                and => [
                    { term => { 'file.author'  => $release->author } },
                    { term => { 'file.release' => $release->name } },
                    @{ $add_filters || [] },
                ],
            }
        )->all
    ];
}

has status => (
    is      => 'ro',
    isa     => 'Str',
    default => 'latest',
);

has archive => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub { shift->name . '.tar.gz' }
);

has name => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        $self->distribution . '-' . $self->version;
    },
);

push @attrs, qw( version_numified status archive name );

test release => sub {
    my ($self) = @_;

    foreach my $attr (@attrs) {
        is $self->$attr, $self->data->$attr, "release $attr";
    }
};

1;
