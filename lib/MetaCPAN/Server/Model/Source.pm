package MetaCPAN::Server::Model::Source;

use strict;
use warnings;

use File::Find::Rule ();
use MetaCPAN::Model::Archive;
use MetaCPAN::Types qw( Dir );
use MetaCPAN::Util ();
use Moose;
use Path::Tiny ();

extends 'Catalyst::Model';

has base_dir => (
    is       => 'ro',
    isa      => Dir,
    coerce   => 1,
    required => 1,
);

has cpan => (
    is       => 'ro',
    isa      => Dir,
    coerce   => 1,
    required => 1,
);

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    if ( $_[1]->{base_dir} ) {
        Path::Tiny::path( $_[1]->{base_dir} )->mkpath;
    }
    return $class->$orig(@_);
};

sub COMPONENT {
    my $self = shift;
    my ( $app, $config ) = @_;
    $config = $self->merge_config_hashes(
        {
            cpan     => $app->config->{cpan},
            base_dir => $app->config->{source_base}
                || $self->_default_base_dir,
        },
        $config
    );
    return $self->SUPER::COMPONENT( $app, $config );
}

sub _default_base_dir {
    return Path::Tiny::path(qw(var tmp source));
}

sub path {
    my ( $self, $pauseid, $distvname, $file ) = @_;
    $file ||= q{};
    my $base       = $self->base_dir;
    my $source_dir = Path::Tiny::path( $base, $pauseid, $distvname );
    my $source     = $self->find_file( $source_dir, $file );
    return $source if ($source);
    return if -e $source_dir;  # previously extracted, but file does not exist

    my $author = MetaCPAN::Util::author_dir($pauseid);
    my $http = Path::Tiny::path( qw(var tmp http authors), $author );
    $author = $self->cpan . "/authors/$author";

    my ($archive_file)
        = File::Find::Rule->new->file->name(
        qr/^\Q$distvname\E\.(tgz|tbz|tar[\._-]gz|tar\.bz2|tar\.Z|zip|7z)$/)
        ->in( $author, $http );
    return unless ( $archive_file && -e $archive_file );

    $source_dir->mkpath;
    my $archive = MetaCPAN::Model::Archive->new(
        file        => $archive_file,
        extract_dir => $source_dir
    );

    return if $archive->is_naughty;
    $archive->extract;

    return $self->find_file( $source_dir, $file );
}

sub find_file {
    my ( $self, $dir, $file ) = @_;
    my ($source) = glob "$dir/*/$file";    # file can be in any subdirectory
    ($source) ||= glob "$dir/$file";       # file can be in any subdirectory
    return $source && -e $source ? Path::Tiny::path($source) : undef;
}

__PACKAGE__->meta->make_immutable;
1;
