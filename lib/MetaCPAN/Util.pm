package MetaCPAN::Util;
# ABSTRACT: Helper functions for MetaCPAN
use strict;
use warnings;
use Digest::SHA1;
use version;
use Try::Tiny;

sub digest {
    my $digest = Digest::SHA1::sha1_base64(join("\0", grep { defined } @_));
    $digest =~ tr/[+\/]/-_/;
    return $digest;
}

sub numify_version {
    my $version = shift;
    no warnings;
    try {
        $version = eval version->parse( $version )->numify;
    } catch {
        $version = fix_version($version);
        $version = eval version->parse( $version || 0 )->numify;
    };
    return $version;
}

sub fix_version {
    my $version = shift;
    return undef unless(defined $version);
    $version =~ s/[^\d\._]//g;
    $version =~ s/\._/./g;
    return $version;
}

sub author_dir {
    my $pauseid = shift;
    my $dir = 'id/'
      . sprintf( "%s/%s/%s",
                 substr( $pauseid, 0, 1 ),
                 substr( $pauseid, 0, 2 ), $pauseid );
    return $dir;
}


# TODO: E<escape>
sub strip_pod {
    my $pod = shift;
    $pod =~ s/L<([^\/]*?)\/([^\/]*?)>/$2 in $1/g;
    $pod =~ s/\w<(.*?)(\|.*?)?>/$1/g;
    return $pod;
}

1;

__END__

=head1 FUNCTIONS

=head2 digest

This function will digest the passed parameters to a 32 byte string and makes it url safe.
It consists of the characters A-Z, a-z, 0-9, - and _.

The digest is built using L<Digest::SHA1>.