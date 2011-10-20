package MetaCPAN::Server::Diff;

use Moose;
use IPC::Run3;

has git => ( is => 'ro', required => 1 );
has [qw(source target)] => ( is => 'ro', required => 1 );
has raw => ( is => 'ro', lazy_build => 1 );
has structured => ( is => 'ro', isa => 'ArrayRef', lazy_build => 1 );
has numstat => ( is => 'rw' );
has relative => ( is => 'ro', required => 1 );

sub _build_raw {
    my $self = shift;
    my $raw = "";
    run3([$self->git, qw(diff --no-renames -z --no-index -u --no-color --numstat), "--relative=" . $self->relative, $self->source, $self->target], undef, \$raw);
    (my $stats = $raw ) =~ s/^([^\n]*\0).*$/$1/s;
    $self->numstat($stats);
    $raw = substr($raw, length($stats));
    return $raw;
}

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
            $segment .= "$diff\n";
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
