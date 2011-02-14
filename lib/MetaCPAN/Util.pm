package MetaCPAN::Util;
# ABSTRACT: Helper functions for MetaCPAN
use strict;
use warnings;
use Digest::SHA1;

sub digest {
    my $digest = Digest::SHA1::sha1_base64(join("\0", grep { defined } @_));
    $digest =~ tr/[+\/]/-_/;
    return $digest;
}

1;

__END__

=head1 FUNCTIONS

=head2 digest

This function will digest the passed parameters to a 32 byte string and makes it url safe.
It consists of the characters A-Z, a-z, 0-9, - and _.

The digest is built using L<Digest::SHA1>.