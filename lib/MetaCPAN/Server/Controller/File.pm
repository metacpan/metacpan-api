package MetaCPAN::Server::Controller::File;
use Moose;
use ElasticSearchX::Model::Util;
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

sub index : Chained('/') : PathPart('file') : CaptureArgs(0) {
}

sub find : Chained('index') : PathPart('') : Args {
    my ( $self, $c, $author, $release, @path ) = @_;
    eval {
        $c->stash(
            $c->model('CPAN::File')->inflate(0)->get(
                {   author  => $author,
                    release => $release,
                    path    => join( '/', @path )
                }
                )->{_source}
        );
    } or $c->detach('/not_found');
}

sub get : Chained('index') : PathPart('') : Args(1) {
    my ( $self, $c, $id ) = @_;
    eval {
        $c->stash( $c->model('CPAN::File')->inflate(0)->get($id)->{_source} );
    } or $c->detach('/not_found');
}

1;
