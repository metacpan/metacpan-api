package MetaCPAN::Script::First;

use strict;
use warnings;

use Log::Contextual qw( :log );
use Moose;
use MetaCPAN::Types qw( Str );

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has distribution => (
    is            => 'ro',
    isa           => Str,
    documentation => q{set the 'first' for only this distribution},
);

sub run {
    my $self = shift;

    my $body;
    if ( $self->distribution ) {
        $body = {
            query => {
                term => { name => $self->distribution }
            }
        };
    }

    my $scroll = $self->es->scroll_helper(
        {
            size   => 500,
            scroll => '1m',
            index  => 'cpan',
            type   => 'distribution',
            body   => $body,
        }
    );

    log_info { "processing " . $scroll->total . " distributions" };

    while ( my $distribution = $scroll->next ) {
        my $release = $distribution->set_first_release;
        $release
            ? log_debug {
            "@{[ $release->name ]} by @{[ $release->author ]} was first";
        }
            : log_warn {
            "no release found for distribution @{[$distribution->name]}";
            };
    }

    # Everything changed - reboot the world!
    $self->cdn_purge_all;

    1;
}

__PACKAGE__->meta->make_immutable;
1;

=pod

=head1 NAME

MetaCPAN::Script::First - Set the C<first> bit after a full reindex

=head1 SYNOPSIS

 $ bin/metacpan first --level debug
 $ bin/metacpan first --distribution Moose

=head1 DESCRIPTION

Setting the L<MetaCPAN::Document::Release/first> bit cannot be
set when indexing archives in parallel, e.g. when doing a full reindex.
This script sets the C<first> bit once all archives have been indexed.

See L<MetaCPAN::Document::Distribution/set_first_release> for more
information.

=head1 OPTIONS

=head2 distribution

Only set the L<MetaCPAN::Document::Release/first> property for releases of this distribution.

=cut
