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
use MetaCPAN::Plack::Response;
use File::Temp ();
use JSON::XS ();

__PACKAGE__->mk_accessors(qw(cpan remote));

sub call {
    my ( $self, $env ) = @_;
    my ($source, $file);
    if ( $env->{REQUEST_URI} =~ m{\A/source/([A-Z0-9]+)/([^\/\?]+)(/([^\?]+))?} ) {
        $source = $self->file_path( $1, $2, $4 );
        $file = $3;
    } elsif ($env->{REQUEST_URI} =~ m{\A/source/authors/id/[A-Z]/[A-Z0-9][A-Z0-9]/([A-Z0-9]+)/([^\/\?]+)(/([^\?]+))?} ) {
        $source = $self->file_path( $1, $2, $4 );
        $file = $3;
    } elsif($env->{REQUEST_URI} =~ /^\/source\/([^\/]+)\/?/) {
        my ($pauseid, $distvname, $path ) = $self->module_to_path($env, $1);
        $source = $self->file_path($pauseid, $distvname, $path) if($pauseid);
        $file = $path;
    }
    return $self->error404 unless($source);
    $file ||= "";
    my $root = $file ? substr($source, 0, -length($file)) : $source;
    $env->{PATH_INFO} = $file ? $file : '/';
    ($env->{SCRIPT_NAME} = $env->{REQUEST_URI}) =~ s/\/?\Q$file\E$//;
    Plack::Util::response_cb(Plack::App::Directory->new( root => $root )->to_app->($env), sub {
        my $res = shift;
        my $h = [MetaCPAN::Plack::Response->_headers];
        Plack::Util::header_remove($h, 'content-type');
        my $ct = Plack::Util::header_get($res->[1], 'content-type');
        $ct = 'text/plain' unless($ct =~ /^text\/html/ || $ct =~ /^image\//);
        Plack::Util::header_set($res->[1], 'content-type', $ct);
        Plack::Util::header_push($res->[1], shift @$h, shift @$h) while(@$h);
        return $res;
    });
}

sub file_path {
    my ( $self, $pauseid, $distvname, $file ) = @_;
    $file ||= "";
    my $base = dir(qw(var tmp source));
    my $source_dir = dir( $base, $pauseid, $distvname );
    my $source = $self->find_file($source_dir, $file);
    return $source if($source);
    return if -e $source_dir; # previously extracted, but file does not exist
    
    my $author = MetaCPAN::Util::author_dir($pauseid);
    my $http = dir(qw(var tmp http authors), $author);
    $author = $self->cpan . "/authors/$author";
    my ($tarball) = File::Find::Rule->new->file->name(
            qr/^\Q$distvname\E\.(tgz|tbz|tar[\._-]gz|tar\.bz2|tar\.Z|zip|7z)$/)
      ->in( $author, $http );
    return unless ( $tarball && -e $tarball );
        
    my $archive = Archive::Any->new($tarball);
    return if($archive->is_naughty); # unpacks outside the current directory 
    $source_dir->mkpath;
    $archive->extract($source_dir);
    
    return $self->find_file($source_dir, $file);

}

sub find_file {
    my ( $self, $dir, $file ) = @_;
    my ($source) = glob "$dir/*/$file"; # file can be in any subdirectory
    return $source if ( $source && -e $source );
    return $dir->file($file)
        if( -e $dir->file($file) );     # or even at top level
    return undef;
}

sub module_to_path {
    my ($self, $env, $module) = @_;
    local $env->{REQUEST_URI} = "/module/$module";
    my $res = MetaCPAN::Plack::Module->new(
              { index => $self->index } )->to_app->($env);
    return () unless($res->[0] == 200);
    my $data = JSON::XS::decode_json(join("",@{$res->[2]}));
    return (@$data{qw(author release path)});
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
 # var/tmp/source/IONCACHE/Plack-Middleware-HTMLify-0.1.1/Plack-Middleware-HTMLify-0.1.1/lib/Plack/Middleware/HTMLify.pm

=cut
