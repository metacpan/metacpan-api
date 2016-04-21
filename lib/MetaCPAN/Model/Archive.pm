package MetaCPAN::Model::Archive;

use v5.10;
use Moose;
use MooseX::StrictConstructor;
use MetaCPAN::Types qw(AbsFile AbsDir ArrayRef Bool);

use Archive::Any;
use Carp;
use File::Temp  ();
use Path::Class ();

=head1 NAME

MetaCPAN::Model::Archive - Inspect and extract archive files

=head1 SYNOPSIS

    use MetaCPAN::Model::Archive;

    my $archive = MetaCPAN::Model::Archive->new( file => $some_file );
    my $files = $archive->files;
    my $extraction_dir = $archive->extract;

=head1 DESCRIPTION

This class manages getting information about and extraction of archive
files (tarballs, zipfiles, etc...) and their extraction directories.

The object is read-only and will only extract once.  If you alter the
extraction directory and want a fresh one, make a new object.

The Archive will clean up its extraction directory upon destruction.

=head1 ATTRIBUTES

=head3 archive

I<Required>

The file to be extracted.  It will be returned as a Path::Class
object.

=cut

has file => (
    is       => 'ro',
    isa      => AbsFile,
    coerce   => 1,
    required => 1,
);

has _extractor => (
    is      => 'ro',
    isa     => 'Archive::Any',
    handles => [
        qw(
            is_impolite
            is_naughty
            )
    ],
    init_arg => undef,
    lazy     => 1,
    default  => sub {
        my $self = shift;
        croak $self->file . ' does not exist' unless -e $self->file;
        return Archive::Any->new( $self->file );
    },
);

# Holding the File::Temp::Dir object here is necessary to keep it
# alive until the object is destroyed.  Path::Class::Dir will not hold
# onto the ojbect.
has _tempdir => (
    is       => 'ro',
    isa      => 'File::Temp::Dir',
    init_arg => undef,
    lazy     => 1,
    default  => sub {
        return File::Temp->newdir;
    },
);

has extract_dir => (
    is      => 'ro',
    isa     => AbsDir,
    lazy    => 1,
    coerce  => 1,
    default => sub {
        my $self = shift;
        return Path::Class::Dir->new( $self->_tempdir );
    },
);

has _has_extracted => (
    is       => 'ro',
    isa      => Bool,
    init_arg => undef,
    default  => 0,
    writer   => '_set_has_extracted',
);

=head1 METHODS

=head3 files

    my $files = $archive->files;

A list of the files in the archive as an array ref.

=cut

# A cheap way to cache the result.
has files => (
    is       => 'ro',
    isa      => ArrayRef,
    init_arg => undef,
    lazy     => 1,
    default  => sub {
        my $self = shift;
        return [ $self->_extractor->files ];
    },
);

=head3 extract

    my $extract_dir = $archive->extract;

Extract the archive into a temp directory.  The directory will be a
L<Path::Class::Dir>.

Only the first call to extract will perform the extraction.  After
that it will just return the extraction directory.  If you want to
re-extract the archive, create a new object.

The extraction directory will be cleaned up when the object is destroyed.

=cut

sub extract {
    my $self = shift;

    return $self->extract_dir if $self->_has_extracted;

    $self->_extractor->extract( $self->extract_dir );
    $self->_set_has_extracted(1);

    return $self->extract_dir;
}

1;
