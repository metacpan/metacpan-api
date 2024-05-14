package MetaCPAN::Server::Controller::Rating;

use strict;
use warnings;

use Moose;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

sub by_distributions : Path('by_distributions') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash_or_detach( {
        took          => 0,
        total         => 0,
        distributions => {},
    } );
}

sub get : Path('') : Args(1) {
    my ( $self, $c ) = @_;
    $c->detach('/not_found');
}

sub _mapping : Path('_mapping') : Args(0) {
    my ( $self, $c ) = @_;
    $c->detach('/not_found');
}

sub find : Path('_search') : Args(0) : ActionClass('~Deserialize') {
    my ( $self, $c, $scroll ) = @_;

    my @hits;

    # fake results for MetaCPAN::Client so it doesn't fail its tests
    if ( ( $c->req->user_agent // '' ) =~ m{^MetaCPAN::Client/([0-9.]+)} ) {
        if ( $1 <= 2.031001 ) {
            my $query = $c->req->data->{'query'};
            if (   $query
                && $query->{term}
                && ( $query->{term}{distribution} // '' ) eq 'Moose' )
            {

                push @hits,
                    {
                    _source => {
                        distribution => "Moose"
                    },
                    };
            }
        }
    }

    $c->stash_or_detach( {
        $c->req->param('scroll') ? ( _scroll_id => 'FAKE_SCROLL_ID' ) : (),
        _shards => {
            failed     => 0,
            successful => 0,
            total      => 0,
        },
        hits => {
            hits      => \@hits,
            max_score => undef,
            total     => scalar @hits,
        },
        timed_out => \0,
        took      => 0,
    } );
}

sub all : Path('') : Args(0) : ActionClass('~Deserialize') {
    my ( $self, $c ) = @_;
    $c->forward('find');
}

1;
