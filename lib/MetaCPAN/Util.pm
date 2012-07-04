package MetaCPAN::Util;
# ABSTRACT: Helper functions for MetaCPAN
use strict;
use warnings;
use Digest::SHA1;
use version;
use Try::Tiny;
use Encode;

sub digest {
    my $digest = Digest::SHA1::sha1_base64(join("\0", grep { defined } @_));
    $digest =~ tr/[+\/]/-_/;
    return $digest;
}

sub numify_version {
    my $version = shift;
    use warnings FATAL => 'numeric';
    eval {
        $version = version->parse( $version )->numify+0;
    } or do {
        $version = fix_version($version);
        $version = eval { version->parse( $version || 0 )->numify+0 };
    };
    return $version;
}

sub fix_version {
    my $version = shift;
    return undef unless(defined $version);
    $version =~ s/[^\d\._]//g;
    $version =~ s/_/00/g;
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

sub extract_section {
    my ( $pod, $section ) = @_;
    eval { $pod = Encode::decode_utf8($pod, Encode::FB_CROAK) };
    return undef
      unless ( $pod =~ /^=head1 $section\b(.*?)(^((\=head1)|(\=cut)))/msi
        || $pod =~ /^=head1 $section\b(.*)/msi );
    my $out = $1;
    $out =~ s/^\s*//g;
    $out =~ s/\s*$//g;
    return $out;
}

=head2 pod_lines

    my ($lines, $slop) = pod_lines ($content);

Given Perl code in C<$content>, return an array reference C<$lines> of
array references C<[[first1, last1], [first2, last2], ...]>, where the
line numbers refer to the start and end of Pod documentation in
C<$content>. If the file is empty or does not contain Pod, $lines is a
reference to an empty array. C<$slop> contains the number of lines of
pod. If the file contains no pod, it is zero.

=cut


sub pod_lines {
    my $content = shift;
    return ([], 0) unless($content);
    my @lines = split( "\n", $content );
    my @return;
    my $line_number = 0;
    my $length = 0;
    my $start  = 0;
    my $slop = 0;
    my $in_data;
    foreach my $line (@lines) {
        $line_number++;
        if ($in_data) {
            if( $line =~ /\A\s*__END__/) {
                $in_data = undef;
            }
            next;
        }
        if ( $line =~ /\A=cut/ ) {
            $length++;
            $slop++;
            push( @return, [ $start-1, $length ] )
              if ( $start && $length );
            $start = $length = 0;
        } elsif ( $line =~ /\A=[a-zA-Z]/ && !$length ) {
            $start = $line_number;
        } elsif( $line =~ /\A\s*__DATA__/) {
            $in_data = 1;
        }
        if ($start) {
            $length++;
            $slop++ if( $line =~ /\S/ );
        }
    }
    push( @return, [ $start-1, $length ] )
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
