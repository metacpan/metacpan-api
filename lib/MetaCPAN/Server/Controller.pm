package MetaCPAN::Server::Controller;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

has type => ( is => 'ro', lazy => 1, default => sub { shift->action_namespace } );

sub mapping : Path('_mapping') {
    my ( $self, $c ) = @_;
    $c->stash( $c->model('CPAN')
            ->es->mapping( index => 'cpan', type => $self->action_namespace )
    );
}

sub all : Chained('index') : PathPart('') : Args(0) {
    my ( $self, $c ) = @_;
    $c->req->query_parameters->{p} ||= '*';
    $c->forward('search');
}

sub search : Path('_search') {
    my ( $self, $c ) = @_;
    my $req = $c->req;
    eval {
        $c->stash(
            $c->model('CPAN')->es->request(
                {   method => $req->method,
                    qs     => $req->parameters,
                    cmd    => join( '/',
                        '', 'cpan', $self->type, '_search' ),
                    data => $req->data
                }
            )
        );
    } or do { $self->internal_error( $c, $@ ) };
}

sub not_found : Private {
    my ( $self, $c ) = @_;
    $c->res->code(404);
    $c->stash( { message => 'Not found' } );
}

sub internal_error {
    my ( $self, $c, $message ) = @_;
    $c->res->code(500);
    $c->stash( { message => "$message" } );
    $c->detach( $c->view('JSON') );
}

__PACKAGE__->meta->make_immutable;
