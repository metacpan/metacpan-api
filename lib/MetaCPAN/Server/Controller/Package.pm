package MetaCPAN::Server::Controller::Package;

use Moose;
use namespace::autoclean;

BEGIN { extends 'MetaCPAN::Server::Controller' }

with 'MetaCPAN::Server::Role::JSONP';

# https://fastapi.metacpan.org/v1/package/modules/Moose
sub modules : Path('modules') : Args(1) {
    my ( $self, $c, $dist ) = @_;
    my $last = $c->model('CPAN::Release')->raw->find($dist);
    $c->detach( '/not_found', ["Cannot find last release for $dist"] )
        unless $last;

    my $data
        = $self->model($c)->get_modules( $dist, $last->{version} );

    $data
        ? $c->stash($data)
        : $c->detach( '/not_found',
        ['The requested info could not be found'] );
}

__PACKAGE__->meta->make_immutable;
1;
