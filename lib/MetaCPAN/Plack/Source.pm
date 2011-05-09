package MetaCPAN::Plack::Source;

use base 'MetaCPAN::Plack::Base';
use strict;
use warnings;
use Archive::Any;
use File::Copy;
use feature 'say';
use Path::Class qw(file dir);
use File::Find::Rule;
use MetaCPAN::Util;
use Plack::App::Directory;
use File::Temp ();

__PACKAGE__->mk_accessors(qw(cpan remote));

sub call {
    my ( $self, $env ) = @_;
    if ( $env->{REQUEST_URI} =~ m{\A/source/([A-Z0-9]+)/([^\/\?]+)/([^\?]+)} ) {
        my $new_path = $self->file_path( $1, $2, $3 );
        $env->{PATH_INFO} = $new_path if $new_path;
    } elsif ($env->{REQUEST_URI} =~ m{\A/source/authors/id/[A-Z]/[A-Z0-9][A-Z0-9]/([A-Z0-9]+)/([^\/\?]+)/([^\?]+)} ) {
            my $new_path = $self->file_path( $1, $2, $3 );
            $env->{PATH_INFO} = $new_path if $new_path;
    }

    Plack::Util::response_cb(Plack::App::Directory->new( root => "." )->to_app->($env), sub {
        my $res = shift;
        push(@{$res->[1]}, $self->_headers);
        return $res;
    });
}

sub file_path {
    my ( $self, $pauseid, $distvname, $file ) = @_;
    my $base = dir(qw(var tmp source));
    my $source = file($base, $pauseid, $distvname, $file );
    my $source_dir = file( $base, $pauseid );
    return $source if ( -e $source );
    
    return if -e $source_dir; # previously extracted, but file does not exist
        
    my $darkpan = dir(qw(var darkpan source))->file($source->relative($base));
    return $darkpan if ( -e $darkpan );
    
    my $author = MetaCPAN::Util::author_dir($pauseid);
    my $http = dir(qw(var tmp http authors), $author);
    $author = $self->cpan . "/authors/$author";
    my ($tarball) = File::Find::Rule->new->file->name("$distvname.tar.gz")->in($author, $http);
    return unless ( $tarball && -e $tarball );
        
    my $archive = Archive::Any->new($tarball);
    $archive->extract( "$source_dir" );
    
    return $source if ( -e $source );
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
