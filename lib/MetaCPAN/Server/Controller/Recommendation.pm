package MetaCPAN::Server::Controller::Recommendation;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller' }
with 'MetaCPAN::Server::Role::JSONP';

sub find : Path('') : Args(4) {
    my ( $self, $c, $user, $module, $relation, $other_module ) = @_;
    eval {
        my $recommendation = $self->model($c)->raw->get(
            {
                user        => $user,
                module      => $module,
                alternative => $other_module,
            }
        );
        $c->stash( $recommendation->{_source} || $recommendation->{fields} );
    } or $c->detach( '/not_found', [$@] );
}

__PACKAGE__->meta->make_immutable;
