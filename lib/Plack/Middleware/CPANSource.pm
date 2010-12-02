package Plack::Middleware::CPANSource;

use parent qw( Plack::Middleware );

use Archive::Tar::Wrapper;
use File::Copy;
use File::Path qw(make_path);
use Modern::Perl;
use Path::Class qw(file);

sub call {
    my ( $self, $env ) = @_;

    if ( $env->{REQUEST_URI} =~ m{\A/source/(\w*)/([^\/\?]*)/(.*)} ) {

        my ( $pauseid, $distvname, $file ) = ( $1, $2, $3 );

        my $new_path
            = $self->file_path( $pauseid, $distvname, $file );
        $env->{PATH_INFO} = $new_path if $new_path;
    }

    return $self->app->( $env );
}

sub file_path {

    my ( $self, $pauseid, $distvname, $file ) = @_;
    
    my $archive = sprintf("%s/%s/%s/%s.tar.gz", substr($pauseid, 0, 1), substr($pauseid, 0,2), $pauseid, $distvname);

    my $base_folder   = '/home/olaf/cpan-source/';
    my $author_folder = $archive;
    $author_folder =~ s{\.tar\.gz\z}{};

    my $rewrite_path = "$author_folder/$file";
    my $dest_file    = $base_folder . $rewrite_path;

    return $rewrite_path if ( -e $dest_file );

    my $cpan_path = "/home/cpan/CPAN/authors/id/$archive";
    return if ( !-e $cpan_path );

    my $arch       = Archive::Tar::Wrapper->new();
    my $logic_path = "$distvname/$file"; # path within unzipped archive
    
    $arch->read( $cpan_path, $logic_path );    # read only one file
    my $phys_path = $arch->locate( $logic_path );

    if ( $phys_path ) {
        make_path( file( $dest_file )->dir, {} );
        copy( $phys_path, $dest_file );
        return $rewrite_path;
    }

    return;

}

1;

=pod

=head2 file_path( $pauseid, $distvname, $file )

    print $self->file_path( 'Plack-Middleware-HTMLify-0.1.1', 'I/IO/IONCACHE/Plack-Middleware-HTMLify-0.1.1.tar.gz', 'lib/Plack/Middleware/HTMLify.pm' );
    # id/I/IO/IONCACHE/Plack-Middleware-HTMLify-0.1.1/lib/Plack/Middleware/HTMLify.pm

=cut
