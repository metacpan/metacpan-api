package MetaCPAN::Util;
# ABSTRACT: Helper functions for MetaCPAN
use strict;
use warnings;
use Digest::SHA1;
use version;
use Try::Tiny;
use Pod::Simple::Text;

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


sub strip_pod {
    my $pod = shift;

    # If encoding not declared, replace "smart-quote" bytes with ASCII
    my $have_encoding = $pod =~ /^=encoding/m;
    if(!$have_encoding) {
        $pod =~ tr/\x91\x92\x93\x94\x96\x97/''""\-\-/;
    }

    # If we have a character string, we need to convert it back to bytes
    # for the POD parser
    if ( Encode::is_utf8($pod) ) {
        $pod = Encode::encode_utf8($pod);
        $pod =~ s{^=encoding.*$}{}m;
        $pod = "=encoding utf8\n\n" . $pod;
    }

    my $parser = Pod::Simple::Text->new();
    my $text   = "";
    $parser->output_string( \$text );
    $parser->no_whining( 1 );
    {
        local($Text::Wrap::columns) = 10_000;
        $parser->parse_string_document("=pod\n\n$pod");
    }
    if($have_encoding  and  $text =~ /POD ERRORS.*unsupported encoding/s) {
        $pod =~ s/^=encoding.*$//mg;
        return strip_pod($pod);
    }

    $text =~ s/\h+/ /g;
    $text =~ s/^\s+//mg;
    $text =~ s/\s+$//mg;

    return $text;
}

sub extract_section {
    my ( $pod, $section ) = @_;
    my $encoding = $pod =~ /^(=encoding.*?\n)/m ? "$1\n" : '';
    return undef
      unless ( $pod =~ /^=head1 $section\b(.*?)(^((\=head1)|(\=cut)))/msi
        || $pod =~ /^=head1 $section\b(.*)/msi );
    my $out = $1;
    $out =~ s/^\s*//g;
    $out =~ s/\s*$//g;
    $out =~ s/^=encoding.*$//m;
    return $encoding . $out;
}


sub pod_lines {
    my $content = shift;
    return [] unless($content);
    my @lines = split( "\n", $content );
    my @return;
    my $count  = 1;
    my $length = 0;
    my $start  = 0;
    my $slop = 0;
    foreach my $line (@lines) {
        if ( $line =~ /\A=cut/ ) {
            $length++;
            $slop++;
            push( @return, [ $start-1, $length ] )
              if ( $start && $length );
            $start = $length = 0;
        } elsif ( $line =~ /\A=[a-zA-Z]/ && !$length ) {
            $start = $count;
        } elsif( $line =~ /\A\s*__DATA__/) {
            last;
        }
        if ($start) {
            $length++;
            $slop++ if( $line =~ /\S/ );
        }
        $count++;
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

=head2 strip_pod

Takes a string of POD source code (bytes) and returns a plain text rendering
(which may include 'wide' characters).  If the source POD declares an encoding,
it will be honoured where possible.

The returned text will use single newlines as paragraph separators and all
whitespace will be collapsed.

=cut
