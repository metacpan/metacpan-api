package MetaCPAN::Server::Diff;

use strict;
use warnings;
use Moose;

use Encoding::FixLatin        ();
use IPC::Run3                 qw( run3 );
use MetaCPAN::Types::TypeTiny qw( ArrayRef );
use File::Spec                ();

has git => (
    is       => 'ro',
    required => 1,
);

has [qw(source target)] => (
    is       => 'ro',
    required => 1,
);

has raw => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_raw',
);

has structured => (
    is      => 'ro',
    isa     => ArrayRef,
    lazy    => 1,
    builder => '_build_structured',
);

has numstat => (
    is     => 'ro',
    writer => '_set_numstat',
);

has relative => (
    is       => 'ro',
    required => 1,
);

sub _build_raw {
    my $self = shift;
    my $raw  = q[];
    run3(
        [
            $self->git,
            qw(diff --no-renames -z --no-index -u --no-color --numstat),
            $self->source, $self->target
        ],
        undef,
        \$raw
    );
    ( my $stats = $raw ) =~ s/^([^\n]*\0).*$/$1/s;
    $self->_set_numstat($stats);
    $raw = substr( $raw, length($stats) );
    return $raw;
}

# The strings in this hash need to be character strings
# or the json encoder will mojibake them.
# Since the diff could include portions of files in multiple encodings
# try to guess the encoding and upgrade everything to UTF-8.
# It won't be an accurate (binary) representation of the patch
# but that's not what this is used for.
# If we desire such a thing we'd have to base64 encode it or something.

sub _build_structured {
    my $self = shift;
    my @structured;
    my $raw = $self->raw;    # run the builder

    my @raw   = split( /\n/, $raw );
    my @lines = split( /\0/, $self->numstat );

    while ( my $line = shift @lines ) {
        my $source = shift @lines;
        my $target = shift @lines;
        $source = $target if $source eq '/dev/null';
        $target = $source if $target eq '/dev/null';
        $source = File::Spec->abs2rel( $source, $self->relative );
        $target = File::Spec->abs2rel( $target, $self->relative );
        my ( $insertions, $deletions ) = split( /\t/, $line );
        my $segment = q[];

        while ( my $diff = shift @raw ) {

            # only run it through if non-ascii bytes are found
            $diff = Encoding::FixLatin::fix_latin($diff)
                if $diff =~ /[^\x00-\x7f]/;

            $segment .= $diff . "\n";
            last if ( $raw[0] && $raw[0] =~ /^diff --git .\//m );
        }
        push(
            @structured,
            {
                source     => $source,
                target     => $target,
                insertions => $insertions,
                deletions  => $deletions,
                diff       => $segment,
            }
        );
    }
    return \@structured;
}

1;
