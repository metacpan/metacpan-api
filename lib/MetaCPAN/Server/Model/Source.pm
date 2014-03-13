package MetaCPAN::Server::Model::Source;

use strict;
use warnings;

use Archive::Any     ();
use File::Find::Rule ();
use MetaCPAN::Util   ();
use Moose;
use MooseX::Types::Path::Class qw(:all);
use Path::Class qw(file dir);

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

sub COMPONENT {
    my $self = shift;
    my ( $app, $config ) = @_;
    $config = $self->merge_config_hashes(
        {   cpan     => $app->config->{cpan},
            base_dir => $app->config->{source_base}
                || $self->_default_base_dir,
        },
        $config
    );
    return $self->SUPER::COMPONENT( $app, $config );
}

sub _default_base_dir {
    return dir(qw(var tmp source));
}

sub path {
    my ( $self, $pauseid, $distvname, $file ) = @_;
    $file ||= "";
    my $base       = $self->base_dir;
    my $source_dir = dir( $base, $pauseid, $distvname );
    my $source     = $self->find_file( $source_dir, $file );
    return $source if ($source);
    return if -e $source_dir;  # previously extracted, but file does not exist

    my $author = MetaCPAN::Util::author_dir($pauseid);
    my $http = dir( qw(var tmp http authors), $author );
    $author = $self->cpan . "/authors/$author";

    my ($tarball)
        = File::Find::Rule->new->file->name(
        qr/^\Q$distvname\E\.(tgz|tbz|tar[\._-]gz|tar\.bz2|tar\.Z|zip|7z)$/)
        ->in( $author, $http );
    return unless ( $tarball && -e $tarball );

    my $archive = Archive::Any->new($tarball);
    return
        if ( $archive->is_naughty );   # unpacks outside the current directory
    $source_dir->mkpath;
    $archive->extract($source_dir);

    return $self->find_file( $source_dir, $file );
}

sub find_file {
    my ( $self, $dir, $file ) = @_;
    my ($source) = glob "$dir/*/$file";    # file can be in any subdirectory
    ($source) ||= glob "$dir/$file";       # file can be in any subdirectory
    return undef unless ( $source && -e $source );
    return -d $source ? dir($source) : file($source);
}

1;
