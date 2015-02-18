package MetaCPAN::Model::Release;

use CPAN::DistnameInfo ();
use DateTime           ();
use DDP;
use File::stat ();
use Log::Contextual qw( :log :dlog );
use MetaCPAN::Model::Archive;
use MetaCPAN::Types qw(ArrayRef Dir File HashRef Str);
use Moose;
use MooseX::StrictConstructor;
use Path::Class ();

with 'MetaCPAN::Role::Logger';

has archive => (
    is      => 'ro',
    isa     => 'MetaCPAN::Model::Archive',
    lazy    => 1,
    builder => '_build_archive',
);

has file => (
    is       => 'rw',
    isa      => File,
    required => 1,
    coerce   => 1,
);

has _files => (
    is       => 'ro',
    isa      => ArrayRef,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_files',
);

has date => (
    is  => 'rw',
    isa => 'DateTime',
);

has index => ( is => 'rw', );

has author => (
    is  => 'rw',
    isa => Str,
);

has name => (
    is  => 'rw',
    isa => Str,
);

has metadata => ( is => 'rw', );

has distribution => (
    is  => 'rw',
    isa => Str,
);

has version => (
    is  => 'rw',
    isa => Str,
);

has maturity => (
    is  => 'rw',
    isa => Str,
);

has status => (
    is  => 'rw',
    isa => Str,
);

has bulk => ( is => 'rw', );

sub _build_archive {
    my $self = shift;

    log_info { 'Processing ', $self->file };

    my $archive = MetaCPAN::Model::Archive->new( file => $self->file );

    log_error {"$self->file is being impolite"} if $archive->is_impolite;

    log_error {"$self->file is being naughty"} if $archive->is_naughty;

    return $archive;
}

sub _build_files {
    my $self = shift;

    my @files;
    log_debug { 'Indexing ', scalar @{ $self->archive->files }, ' files' };
    my $file_set = $self->index->type('file');

    my $extract_dir = $self->extract;
    File::Find::find(
        sub {
            my $child
                = -d $File::Find::name
                ? Path::Class::Dir->new($File::Find::name)
                : Path::Class::File->new($File::Find::name);
            return if $self->_is_broken_file($File::Find::name);
            my $relative = $child->relative($extract_dir);
            my $stat     = do {
                my $s = $child->stat;
                +{ map { $_ => $s->$_ } qw(mode uid gid size mtime) };
            };
            return if ( $relative eq q{.} );
            ( my $fpath = "$relative" ) =~ s/^.*?\///;
            my $filename = $fpath;
            $child->is_dir
                ? $filename =~ s/^(.*\/)?(.+?)\/?$/$2/
                : $filename =~ s/.*\///;
            $fpath = q{} if $relative !~ /\// && !$self->archive->is_impolite;

            my $file = $file_set->new_document(
                Dlog_trace {"adding file $_"} +{
                    author       => $self->author,
                    binary       => -B $child,
                    content_cb   => sub { \( scalar $child->slurp ) },
                    date         => $self->date,
                    directory    => $child->is_dir,
                    distribution => $self->distribution,
                    indexed      => $self->metadata->should_index_file($fpath)
                    ? 1
                    : 0,
                    local_path => $child,
                    maturity   => $self->maturity,
                    metadata   => $self->metadata,
                    name       => $filename,
                    path       => $fpath,
                    release    => $self->name,
                    stat       => $stat,
                    status     => $self->status,
                    version    => $self->version,
                }
            );

            $self->bulk->put($file);
            push( @files, $file );
        },
        $extract_dir
    );

    $self->bulk->commit;

    return \@files;
}

sub extract {
    my $self = shift;

    log_debug {'Extracting archive to filesystem'};
    return $self->archive->extract;
}

sub _is_broken_file {
    my $self     = shift;
    my $filename = shift;

    return 1 if ( -p $filename || !-e $filename );

    if ( -l $filename ) {
        my $syml = readlink $filename;
        return 1 if ( !-e $filename && !-l $filename );
    }
    return 0;
}

sub get_files {
    my $self  = shift;
    my $files = $self->_files;
    return @{$files};
}

__PACKAGE__->meta->make_immutable();
1;
