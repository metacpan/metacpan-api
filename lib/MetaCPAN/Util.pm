package MetaCPAN::Util;

# ABSTRACT: Helper functions for MetaCPAN

use strict;
use warnings;
use version;

use Cwd            ();
use Digest::SHA    qw( sha1_base64 sha1_hex );
use Encode         qw( decode_utf8 );
use File::Basename ();
use File::Spec     ();
use Ref::Util      qw(
    is_arrayref
    is_hashref
    is_plain_arrayref
    is_plain_hashref
    is_ref
);
use Cpanel::JSON::XS ();
use Sub::Exporter -setup => {
    exports => [ qw(
        root_dir
        author_dir
        diff_struct
        digest
        extract_section
        fix_pod
        fix_version
        generate_sid
        hit_total
        numify_version
        pod_lines
        strip_pod
        single_valued_arrayref_to_scalar
        true
        false
        is_bool
        MAX_RESULT_WINDOW
    ) ]
};

use constant MAX_RESULT_WINDOW => 10000;

*true    = \&Cpanel::JSON::XS::true;
*false   = \&Cpanel::JSON::XS::false;
*is_bool = \&Cpanel::JSON::XS::is_bool;

sub root_dir {
    Cwd::abs_path( File::Spec->catdir(
        File::Basename::dirname(__FILE__),
        ( File::Spec->updir ) x 2
    ) );
}

sub digest {
    my $digest = sha1_base64( join( "\0", grep {defined} @_ ) );
    $digest =~ tr{+/}{-_};
    return $digest;
}

sub generate_sid {
    return sha1_hex( rand . $$ . {} . time );
}

sub numify_version {
    my $version = shift || return 0;
    $version = fix_version($version);
    $version =~ s/_//g;
    if ( $version =~ s/^v//i || $version =~ tr/.// > 1 ) {
        my @parts = split /\./, $version;
        my $n     = shift @parts;
        return 0 unless defined $n;
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
    return sprintf( 'id/%1$.1s/%1$.2s/%1$s', $pauseid );
}

sub hit_total {
    my $res   = shift;
    my $total = $res && $res->{hits} && $res->{hits}{total};
    if ( ref $total ) {
        return $total->{value};
    }
    return $total;
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
    eval { $pod = decode_utf8( $pod, Encode::FB_CROAK ) };
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
    my $length = 0;
    my $start  = 0;
    my $slop   = 0;

    # Use c-style for loop to avoid copying all the strings.
    my $num_lines = scalar @lines;
    for ( my $i = 0; $i < $num_lines; ++$i ) {
        my $line = $lines[$i];

        if ( $line =~ /\A=cut/ ) {
            $length++;
            $slop++;
            push( @return, [ $start - 1, $length ] )
                if ( $start && $length );
            $start = $length = 0;
        }

      # Match lines that actually look like valid pod: "=pod\n" or "=pod x\n".
        elsif ( $line =~ /^=[a-zA-Z][a-zA-Z0-9]*(?:\s+|$)/ && !$length ) {

            # Re-use iterator as line number.
            $start = $i + 1;
        }

        if ($start) {
            $length++;
            $slop++ if ( $line =~ /\S/ );
        }
    }

    push @return, [ $start - 1, $length ]
        if ( $start && $length );

    return \@return, $slop;
}

sub single_valued_arrayref_to_scalar {
    my ( $array, $fields ) = @_;
    my $is_arrayref = is_arrayref($array);

    $array = [$array] unless $is_arrayref;

    my $has_fields = defined $fields ? 1 : 0;
    $fields ||= [];
    my %fields_to_extract = map { $_ => 1 } @{$fields};
    foreach my $hash ( @{$array} ) {
        next unless is_hashref($hash);
        foreach my $field ( %{$hash} ) {
            next if ( $has_fields and not $fields_to_extract{$field} );
            my $value = $hash->{$field};

            # We only operate when have an ArrayRef of one value
            next unless is_arrayref($value) && scalar @{$value} == 1;
            $hash->{$field} = $value->[0];
        }
    }
    return $is_arrayref ? $array : @{$array};
}

sub diff_struct {
    my ( $old_root, $new_root, $allow_extra ) = @_;
    my (@queue) = [ $old_root, $new_root, '', $allow_extra ];

    while ( my $check = shift @queue ) {
        my ( $old, $new, $path, $allow_extra ) = @$check;
        if ( !defined $new ) {
            return [ $path, $old, $new ]
                if defined $old;
        }
        elsif ( !is_ref($new) ) {
            return [ $path, $old, $new ]
                if !defined $old
                or is_ref($old)
                or $new ne $old;
        }
        elsif ( is_plain_arrayref($new) ) {
            return [ $path, $old, $new ]
                if !is_plain_arrayref($old) || @$new != @$old;
            push @queue, map [ $old->[$_], $new->[$_], "$path/$_" ],
                0 .. $#$new;
        }
        elsif ( is_plain_hashref($new) ) {
            return [ $path, $old, $new ]
                if !is_plain_hashref($old)
                || !$allow_extra && keys %$new != keys %$old;
            push @queue, map [ $old->{$_}, $new->{$_}, "$path/$_" ],
                keys %$new;
        }
        elsif ( is_bool($new) ) {
            return [ $path, $old, $new ]
                if !is_bool($old) || $old != $new;
        }
        else {
            die "can't compare $new type data at $path";
        }
    }
    return undef;
}

1;

__END__

=head1 FUNCTIONS

=head2 digest

This function will digest the passed parameters to a 32 byte string and makes it url safe.
It consists of the characters A-Z, a-z, 0-9, - and _.

The digest is built using L<Digest::SHA>.

=head2 single_valued_arrayref_to_scalar

Elasticsearch 1.x changed the data structure returned when fields are used.
For example before one could get a ArrayRef[HashRef[Str]] where now
that will come in the form of ArrayRef[HashRef[ArrayRef[Str]]]

This function reverses that behavior
By default it will do that for all fields that are a single valued array,
but one may pass in a list of fields to restrict this behavior only to the
fields given.

So this:

    $self->single_valued_arrayref_to_scalar(
    [
      {
        name     => ['WhizzBang'],
        provides => ['Food', 'Bar'],
      },
       ...
   ]);

yields:

    [
      {
        name     => 'WhizzBang',
        provides => ['Food', 'Bar'],
      },
      ...
    ]

and this estrictive example):

    $self->single_valued_arrayref_to_scalar(
    [
      {
        name     => ['WhizzBang'],
        provides => ['Food'],
      },
       ...
   ], ['name']);

yields:

    [
      {
        name     => 'WhizzBang',
        provides => ['Food'],
      },
      ...
    ]

=head2 diff_struct

    my $changed = diff_struct($old_hashref, $new_hashref);

Accepts two data structures and returns a true value if they are different.

=cut
