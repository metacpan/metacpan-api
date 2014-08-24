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
    return $self->filter_files();
}

has module_files => (
    is      => 'ro',
    isa     => 'ArrayRef',
    lazy    => 1,
    builder => '_build_module_files',
);

sub _build_module_files {
    my ($self) = @_;
    return $self->filter_files(
        [ { exists => { field => 'file.module.name' } }, ] );
}

sub filter_files {
    my ( $self, $add_filters ) = @_;

    $add_filters = [$add_filters]
        if $add_filters && ref($add_filters) ne 'ARRAY';

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
        )->size(100)->all
    ];
}

has modules => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { +{} },
);

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
        is $self->data->$attr, $self->$attr, "release $attr";
    }
};

test 'modules in release files' => sub {
    my ($self) = @_;

    plan skip_all => 'No modules specified for testing'
        unless scalar keys %{ $self->modules };

    my %module_files = map { ( $_->path => $_ ) } @{ $self->module_files };

    foreach my $path ( sort keys %{ $self->modules } ) {
        my $desc = "File '$path' has expected modules";
        if ( my $got = delete $module_files{$path} ) {

     # We may need to sort modules by name, I'm not sure if order is reliable.
            is_deeply $got->module, $self->modules->{$path}, $desc
                or diag Test::More::explain( $got->module );
        }
        else {
            ok( 0, $desc );
        }
    }

    is( scalar keys %module_files, 0, 'all module files tested' )
        or diag join ' ', 'Untested files:', keys %module_files;
};

1;
