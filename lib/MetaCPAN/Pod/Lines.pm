package MetaCPAN::Pod::Lines;
use strict;
use warnings;

sub parse {
    my $content = shift;
    return [] unless($content);
    my @lines = split( "\n", $content );
    my @return;
    my $count  = 1;
    my $length = 0;
    my $start  = 0;
    foreach my $line (@lines) {
        if ( $line =~ /\A=cut/ ) {
            $length++;
            push( @return, [ $start-1, $length ] )
              if ( $start && $length );
            $start = $length = 0;
        } elsif ( $line =~ /\A=[a-zA-Z]/ && !$length ) {
            $start = $count;
        } elsif( $line =~ /\A\s*__DATA__/) {
            last;
        }
        $length++ if ($start);
        $count++;
    }
    push( @return, [ $start-1, $length ] )
      if ( $start && $length );
    return \@return;
}

1;
