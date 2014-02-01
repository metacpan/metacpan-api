package MetaCPAN::Script::First;

=head1 NAME

MetaCPAN::Script::First - Set the C<first> bit after a full reindex

=head1 SYNOPSIS

 $ bin/metacpan first --level debug
 $ bin/metacpan first --distribution Moose

=head1 DESCRIPTION

Setting the L<MetaCPAN::Document::Release/first> bit cannot be
set when indexing tarballs in parallel, e.g. when doing a full reindex.
This script sets the C<first> bit once all tarballs have been indexed.

See L<MetaCPAN::Document::Distribution/set_first_release> for more
information.

=cut

use Moose;
with 'MooseX::Getopt';
use Log::Contextual qw( :log );
with 'MetaCPAN::Role::Common';

=head1 OPTIONS

=head2 distribution

Only set the L<MetaCPAN::Document::Release/first> property for releases of this distribution.

=cut

has distribution => (
    is            => "rw",
    isa           => "Str",
    documentation => "set the 'first' for only this distribution",
);

sub run {
    my $self          = shift;
    my $distributions = $self->index->type("distribution");
    $distributions
        = $distributions->filter(
        { term => { name => $self->distribution } } )
        if $self->distribution;
    $distributions = $distributions->size(500)->scroll;
    log_info { "processing " . $distributions->total . " distributions" };
    while ( my $distribution = $distributions->next ) {
        my $release = $distribution->set_first_release;
        $release
            ? log_debug {
            "@{[ $release->name ]} by @{[ $release->author ]} was first";
        }
            : log_warn {
            "no release found for distribution @{[$distribution->name]}";
            };
    }
}

1;
