package MetaCPAN::Plack::Source;

use base 'Plack::Component';

use Archive::Tar::Wrapper;
use File::Copy;
use File::Path qw(make_path);
use Modern::Perl;
use Path::Class qw(file);

__PACKAGE__->mk_accessors(qw(cpan));

sub call {
    my ( $self, $env ) = @_;
    if ( $env->{REQUEST_URI} =~ m{\A/source/([A-Z]+)/([^\/\?]+)/([^\?]+)} ) {
        my $new_path = $self->file_path( $1, $2, $3 );
        $env->{PATH_INFO} = $new_path if $new_path;
    } elsif ($env->{REQUEST_URI} =~ m{\A/source/authors/id/[A-Z]/[A-Z][A-Z]/([A-Z]+)/([^\/\?]+)/([^\?]+)} ) {
            my $new_path = $self->file_path( $1, $2, $3 );
            $env->{PATH_INFO} = $new_path if $new_path;
    }
    
    Plack::App::Directory->new( root => "var/tmp/" )->to_app->($env);
}

sub file_path {
    my ( $self, $pauseid, $distvname, $file ) = @_;

    my $author_folder = sprintf( "%s/%s/%s/%s",
        substr( $pauseid, 0, 1 ),
        substr( $pauseid, 0, 2 ),
        $pauseid, $distvname );
    my $base_folder = 'var/tmp/';

    my $rewrite_path = "$author_folder/$file";
    my $dest_file    = $base_folder . $rewrite_path;

    return $rewrite_path if ( -e $dest_file );

    my $cpan_path = $self->cpan . "/authors/id/$author_folder.tar.gz";
    return if ( !-e $cpan_path );

    my $arch = Archive::Tar::Wrapper->new();
    my $logic_path = "$distvname/$file";    # path within unzipped archive

    $arch->read( $cpan_path, $logic_path ); # read only one file
    my $phys_path = $arch->locate( $logic_path );

    if ( $phys_path ) {
        make_path( file( $dest_file )->dir, {} );
        copy( $phys_path, $dest_file );
        return $rewrite_path;
    }

    return;

}

1;

__END__

=head1 SYNOPSIS

 GET /source/authors/id/I/IO/IONCACHE/Plack-Middleware-HTMLify-0.1.1/lib/Plack/Middleware/HTMLify.pm
 GET /source/IONCACHE/Plack-Middleware-HTMLify-0.1.1/lib/Plack/Middleware/HTMLify.pm

=head1 DESCRIPTION

If the document is requested for the first time, it is fetched from the local cpan mirror
and extracted to a temporary folder. Subsequent requests to the file will be served
from the temporary folder. The folder is C<< var/tmp >>.

=head1 METHODS

=head2 handle

Perform some regexes on the URL to extract pauseid, release and filename.

=head2 file_path( $pauseid, $distvname, $file )

 $self->file_path( 'IONCACHE', 'Plack-Middleware-HTMLify-0.1.1', 'lib/Plack/Middleware/HTMLify.pm' );
 # id/I/IO/IONCACHE/Plack-Middleware-HTMLify-0.1.1/lib/Plack/Middleware/HTMLify.pm

=cut
