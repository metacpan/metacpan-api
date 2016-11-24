package MetaCPAN::Server::Controller::File;

use strict;
use warnings;

use ElasticSearchX::Model::Util;
use Moose;

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
            $c->stash( $file->{_source} || $file->{fields} );
        }
    } or $c->detach( '/not_found', [$@] );
}

# endpoint: /file/dir
# params:   dir=<dir>&author=<pauseid>&release=<name>
# optional: [&fields=<field>][&sort=<sort_key>][&size=N][&page=N]
sub dir : Path('dir') : Args(0) {
    my ( $self, $c ) = @_;
    my $data = $self->model($c)->raw->dir( $c->req );
    $c->stash($data);
}

1;
