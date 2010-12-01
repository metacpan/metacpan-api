package Plack::Middleware::CPANSource;

use parent qw( Plack::Middleware );

use Moose;

use Archive::Tar::Wrapper;
use Data::Dump qw( dump );
use File::Copy;
use File::Path qw(make_path);
use Furl;
use JSON::DWIW;
use Modern::Perl;

has 'archive'       => ( is => 'rw', );
has 'author_folder' => ( is => 'rw' );
has 'base_folder'   => ( is => 'ro', default => '/home/olaf/cpan-source/id' );
has 'pauseid'       => ( is => 'rw' );
has 'rewrite_to'    => ( is => 'rw' );

sub call {
    my ( $self, $env ) = @_;

    if ( $env->{REQUEST_URI} =~ m{\A/source/(\w*)/([^\/\?]*)/(.*)} ) {

        my $author    = $1;
        my $distvname = $2;
        my $file      = $3;

        #say "$author | $distvname | $file";

        $self->get_pkg_name( $distvname );
        if ( $self->archive ) {
            if ( $self->extract_file( $file, $distvname ) ) {
                $env->{REQUEST_URI}              = $self->rewrite_to;
                $env->{PATH_INFO}                = $self->rewrite_to;
                $env->{'psgix.rewrite_modified'} = 1;
                
               # my $headers = $res->[1];
               # Plack::Util::header_set( $headers, 'Content-Type', 'text/html' );
            }
        }
    }

    my $res = $self->app->( $env );
    
    $self->response_cb(
        $res,
        sub {
            my $res     = shift;
            my $headers = $res->[1];
            Plack::Util::header_set( $headers, 'Content-Type', 'text/plain' );
        }
    );
    
    return $res;
}

sub get_pkg_name {

    my $self      = shift;
    my $distvname = shift;

    my $furl = Furl->new( timeout => 10, );

    my $res
        = $furl->get( 'http://localhost:9200/cpan/module/_search?q=distvname:'
            . $distvname );

    my $found  = JSON::DWIW->from_json( $res->content );
    my $module = $found->{hits}->{hits}->[0]->{_source};
    return if !$module;

    $self->archive( $module->{archive} );
    $self->pauseid( $module->{pauseid} || $module->{author} );
    $self->author_folder( $self->pauseid2folder( $self->pauseid ) );

    return $self->archive;

}

sub extract_file {

    my $self      = shift;
    my $file      = shift;
    my $distvname = shift;

    my $base_folder = '/home/olaf/cpan-source/';
    my $dest_file = $base_folder . $self->author_folder . "/$distvname/$file";
    $self->rewrite_to( $self->author_folder . "/$distvname/$file" );

    if ( -e $dest_file ) {
        say "$dest_file already exists";
        return 1;
    }

    my $path = '/home/cpan/CPAN/authors/id/' . $self->archive;
    if ( !-e $path ) {
        say "$path not found!";
        return 0;
    }

    my $arch = Archive::Tar::Wrapper->new();
    $arch->read( $path );
    $arch->list_reset();

    while ( my $entry = $arch->list_next() ) {

        my ( $tar_path, $phys_path ) = @$entry;

        if ( $tar_path =~ m{$file\z} ) {

            my @parts         = split( "/", $dest_file );
            my $filename      = pop @parts;
            my $create_folder = join "/", @parts;

            make_path( $create_folder, { error => \my $err, verbose => 1 } );

            copy( $phys_path, $dest_file );
            return 1;
        }
    }

    return 0;

}

sub pauseid2folder {

    my $self    = shift;
    my $pauseid = $self->pauseid;
    return sprintf( "id/%s/%s/%s/",
        substr( $pauseid, 0, 1 ),
        substr( $pauseid, 0, 2 ), $pauseid );

}
1;
