package MetaCPAN::Script::Backpan;

use strict;
use warnings;

use BackPAN::Index;
use Moose;

with 'MetaCPAN::Role::Script', 'MooseX::Getopt::Dashes';

sub run {
    my $self = shift;

    my $backpan = BackPAN::Index->new( debug => 0 );
    my $releases = $backpan->releases();

    my @search;
    while ( my $release = $releases->next ) {
        push @search,
            {
            and => [
                { term => { 'author' => $release->cpanid } },
                { term => { 'name'   => $release->distvname } },
                { not  => { term     => { status => 'backpan' } } },
            ]
            };
        if ( scalar @search >= 5000 ) {
            $self->update_status(@search);
            @search = ();
        }
    }
    $self->update_status(@search) if @search;
}

sub update_status {
    my $self   = shift;
    my @search = @_;

    my $es = $self->es;
    $es->trace_calls(1) if $ENV{DEBUG};

    my $scroll = $es->scroll_helper(
        size   => 500,
        scroll => '2m',
        index  => 'cpan_v1',
        type   => 'release',
        fields => [ 'author', 'name' ],
        query  => {
            filtered => {
                query  => { match_all => {} },
                filter => {
                    or => \@search,
                },
            },
        },
    );

    while ( my $release = $scroll->next ) {
        $es->update(
            index => 'cpan_v1',
            type  => 'release',
            id    => $release->{_id},
            doc   => { status => 'backpan' }
        );
    }
}

__PACKAGE__->meta->make_immutable;
1;

=pod

Sets "backpan" status on all BackPAN releases.

=cut
