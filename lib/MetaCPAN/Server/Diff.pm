package MetaCPAN::Server::Diff;

use Moose;
use IPC::Run3;
use Encoding::FixLatin ();

has git => ( is => 'ro', required => 1 );
has [qw(source target)] => ( is => 'ro', required => 1 );
has raw => ( is => 'ro', lazy_build => 1 );
has structured => ( is => 'ro', isa => 'ArrayRef', lazy_build => 1 );
has numstat => ( is => 'rw' );
has relative => ( is => 'ro', required => 1 );

# NOTE: Found this in the git(1) change log (cd676a513672eeb9663c6d4de276a1c860a4b879):
#  > [--relative] is inherently incompatible with --no-index, which is a
#  > bolted-on hack that does not have much to do with git
#  > itself.  I didn't bother checking and erroring out on the
#  > combined use of the options, but probably I should.
# So if that ever stops working we'll have to strip the prefix from the paths ourselves.

sub _build_raw {
    my $self = shift;
    my $raw = "";
    run3([$self->git, qw(diff --no-renames -z --no-index -u --no-color --numstat), "--relative=" . $self->relative, $self->source, $self->target], undef, \$raw);
    (my $stats = $raw ) =~ s/^([^\n]*\0).*$/$1/s;
    $self->numstat($stats);
    $raw = substr($raw, length($stats));
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
    my $raw = $self->raw; # run the builder

    my @raw = split(/\n/, $raw);
    my @lines = split(/\0/, $self->numstat);

    while( my $line = shift @lines ) {
        my ($insertions, $deletions) = split(/\t/, $line);
        my $segment = "";
        while(my $diff = shift @raw) {
            $segment .= Encoding::FixLatin::fix_latin($diff) . "\n";
            last if($raw[0] && $raw[0] =~ /^diff --git a\//m);
        }
        push(@structured, {
            source => shift @lines,
            target => shift @lines,
            insertions => $insertions,
            deletions => $deletions,
            diff => $segment,
        });
    }
    return \@structured;
}

1;
