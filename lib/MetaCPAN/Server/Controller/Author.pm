package MetaCPAN::Server::Controller::Author;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller' }
with 'MetaCPAN::Server::Role::JSONP';

__PACKAGE__->config(
    relationships => {
        release => {
            type    => ['Release'],
            self    => 'pauseid',
            foreign => 'author',
        },
        favorite => {
            type    => ['Favorite'],
            self    => 'user',
            foreign => 'user',
        }
    }
);

sub index : Chained('/') : PathPart('author') : CaptureArgs(0) {
}

sub get : Chained('index') : PathPart('') : Args(1) {
    my ( $self, $c, $pauseid ) = @_;
    eval {
        $c->stash(
            $c->model('CPAN::Author')->inflate(0)->get($pauseid)->{_source} );
    } or $c->detach('/not_found');

}

1;
