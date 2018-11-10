package MetaCPAN::API::Controller::Admin;

use Mojo::Base 'Mojolicious::Controller';

sub identity_search_form { }

sub search_identities {
    my $self = shift;
    my $data = $self->model->user->lookup( $self->param('name'),
        $self->param('key') );
    $self->stash( user_data => $data );
    $self->render('admin/search_identities');
}

1;
