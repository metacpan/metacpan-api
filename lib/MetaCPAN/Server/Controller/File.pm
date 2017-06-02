package MetaCPAN::Server::Controller::File;

use strict;
use warnings;

use ElasticSearchX::Model::Util;
use Moose;
use MetaCPAN::Util qw( single_valued_arrayref_to_scalar );

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

__PACKAGE__->config(
    relationships => {
        author => {
            type    => 'Author',
            foreign => 'pauseid',
        },
        release => {
            type => 'Release',
            self => sub {
                ElasticSearchX::Model::Util::digest( $_[0]->{author},
                    $_[0]->{release} );
            },
            foreign => 'id',
        }
    }
);

sub find : Path('') {
    my ( $self, $c, $author, $release, @path ) = @_;

    $c->add_author_key($author);
    $c->cdn_max_age('1y');

    eval {
        my $file = $self->model($c)->raw->get(
            {
                author  => $author,
                release => $release,
                path    => join( '/', @path )
            }
        );
        if ( $file->{_source} || $file->{fields} ) {
            $c->stash( $file->{_source}
                    || single_valued_arrayref_to_scalar( $file->{fields} ) );
        }
    } or $c->detach( '/not_found', [$@] );
}

sub dir : Path('dir') {
    my ( $self, $c, @path ) = @_;
    my $data = $self->model($c)->dir(@path);
    return unless $data;
    $c->stash($data);
}

1;
