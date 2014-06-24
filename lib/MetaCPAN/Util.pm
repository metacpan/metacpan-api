package MetaCPAN::Util;

# ABSTRACT: Helper functions for MetaCPAN

use strict;
use warnings;
use version;

use Digest::SHA1;
use Encode;

sub digest {
    my $digest = Digest::SHA1::sha1_base64( join( "\0", grep {defined} @_ ) );
    $digest =~ tr/[+\/]/-_/;
    return $digest;
}

sub generate_sid {
    Digest::SHA1::sha1_hex( rand() . $$ . {} . time );
}

sub numify_version {
    my $version = shift;
    $version = fix_version($version);
    $version =~ s/_//g;
    if ( $version =~ s/^v//i || $version =~ tr/.// > 1 ) {
        my @parts = split /\./, $version;
        my $n = shift @parts;
        $version
            = sprintf( join( '.', '%s', ( '%03s' x @parts ) ), $n, @parts );
    }
    $version += 0;
    return $version;
}

sub fix_version {
    my $version = shift;
    return 0 unless defined $version;
    my $v = ( $version =~ s/^v//i );
    $version =~ s/[^\d\._].*//;
    $version =~ s/\.[._]+/./;
    $version =~ s/[._]*_[._]*/_/g;
    $version =~ s/\.{2,}/./g;
    $v ||= $version =~ tr/.// > 1;
    $version ||= 0;
    return ( ( $v ? 'v' : '' ) . $version );
}

sub author_dir {
    my $pauseid = shift;
    my $dir     = 'id/'
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

sub extract_section {
    my ( $pod, $section ) = @_;
    eval { $pod = Encode::decode_utf8( $pod, Encode::FB_CROAK ) };
    return undef
        unless ( $pod =~ /^=head1\s+$section\b(.*?)(^((\=head1)|(\=cut)))/msi
        || $pod =~ /^=head1\s+$section\b(.*)/msi );
    my $out = $1;
    $out =~ s/^\s*//g;
    $out =~ s/\s*$//g;
    return $out;
}

sub pod_lines {
    my $content = shift;
    return [] unless ($content);
    my @lines = split( "\n", $content );
    my @return;
    my $count  = 1;
    my $length = 0;
    my $start  = 0;
    my $slop   = 0;
    foreach my $line (@lines) {

        if ( $line =~ /\A=cut/ ) {
            $length++;
            $slop++;
            push( @return, [ $start - 1, $length ] )
                if ( $start && $length );
            $start = $length = 0;
        }
        elsif ( $line =~ /\A=[a-zA-Z]/ && !$length ) {
            $start = $count;
        }
        elsif ( $line =~ /\A\s*__DATA__/ ) {
            last;
        }
        if ($start) {
            $length++;
            $slop++ if ( $line =~ /\S/ );
        }
        $count++;
    }
    push @return, [ $start - 1, $length ]
        if ( $start && $length );
    return \@return, $slop;
}

1;

__END__

=head1 FUNCTIONS

=head2 digest

This function will digest the passed parameters to a 32 byte string and makes it url safe.
It consists of the characters A-Z, a-z, 0-9, - and _.

The digest is built using L<Digest::SHA1>.
