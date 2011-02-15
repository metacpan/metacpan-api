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
    try {
        $version = eval version->parse( $version )->numify;
    } catch {
        $version =~ s/[^0-9\.]//g;
        $version = eval version->parse( $version || 0 )->numify;
    };
    return $version;
}

1;

__END__

=head1 FUNCTIONS

=head2 digest

This function will digest the passed parameters to a 32 byte string and makes it url safe.
It consists of the characters A-Z, a-z, 0-9, - and _.

The digest is built using L<Digest::SHA1>.