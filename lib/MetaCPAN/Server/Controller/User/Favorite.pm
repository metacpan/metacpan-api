package MetaCPAN::Server::Controller::User::Favorite;

use strict;
use warnings;

use List::Util         qw( uniq );
use MetaCPAN::ESConfig qw( es_doc_path );
use MetaCPAN::Util     qw( true false hit_total );
use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

sub index : Path : ActionClass('REST') {
}

sub index_POST {
    my ( $self, $c ) = @_;
    my $pause    = $c->stash->{pause};
    my $data     = $c->req->data;
    my $favorite = $c->model('ESModel')->doc('favorite')->put(
        {
            user         => $c->user->id,
            author       => $data->{author},
            release      => $data->{release},
            distribution => $data->{distribution},
        },
        { refresh => true }
    );
    $c->purge_author_key( $data->{author} )     if $data->{author};
    $c->purge_dist_key( $data->{distribution} ) if $data->{distribution};
    $self->status_created(
        $c,
        location => $c->uri_for( join( '/',
            '/favorite', $favorite->user, $favorite->distribution ) ),
        entity => $favorite->meta->get_data($favorite)
    );
}

sub index_DELETE {
    my ( $self, $c, $distribution ) = @_;
    my $user_id = $c->user->id;

    my $query = {
        bool => {
            must => [
                { term => { user         => $user_id } },
                { term => { distribution => $distribution } },
            ],
        },
    };

    my $res = $c->model('ES')->search(
        es_doc_path('favorite'),
        body => {
            query => $query,
            size  => 100,
        },
    );

    if ( hit_total($res) ) {
        my @authors = uniq grep {defined}
            map { $_->{_source}{author} } @{ $res->{hits}{hits} };

        $c->model('ES')->delete_by_query(
            es_doc_path('favorite'),
            body    => { query => $query },
            refresh => true,
        );

        for my $author (@authors) {
            $c->purge_author_key($author);
        }
        $c->purge_dist_key($distribution);

        $self->status_ok( $c, entity => $res->{hits}{hits}[0]{_source}, );
    }
    else {
        $self->status_not_found( $c, message => 'Entity could not be found' );
    }
}

1;
