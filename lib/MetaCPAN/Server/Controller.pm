package MetaCPAN::Server::Controller;
use Moose;
use namespace::autoclean;
use JSON;

BEGIN { extends 'Catalyst::Controller'; }

__PACKAGE__->config(
    default     => 'application/json',
    map         => { 'application/json' => 'JSON' },
    action_args => {
        'search' =>
            { deserialize_http_methods => [qw(POST PUT OPTIONS DELETE GET)] }
    }
);

has type =>
    ( is => 'ro', lazy => 1, default => sub { shift->action_namespace } );

sub mapping : Path('_mapping') {
    my ( $self, $c ) = @_;
    $c->stash( $c->model('CPAN')
            ->es->mapping( index => $c->model('CPAN')->index, type => $self->type )
    );
}

sub all : Chained('index') : PathPart('') : Args(0) {
    my ( $self, $c ) = @_;
    $c->req->query_parameters->{p} ||= '*';
    $c->forward('search');
}

sub search : Path('_search') : ActionClass('Deserialize') {
    my ( $self, $c ) = @_;
    my $req = $c->req;
    # shallow copy
    my $params = {%{$req->params}};
    delete $params->{callback};
    eval {
        $c->stash(
            $c->model('CPAN')->es->request(
                {   method => $req->method,
                    qs     => $params,
                    cmd    => join( '/', '', $c->model('CPAN')->index, $self->type, '_search' ),
                    data   => $req->data
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
    if ( eval { $message->isa('ElasticSearch::Error') } ) {
        $c->res->content_type('text/plain');
        $c->res->body( $message->{'-text'} );
        $c->detach;
    }
    else {
        $c->stash( { message => "$message" } );
        $c->detach( $c->view('JSON') );
    }
}


__PACKAGE__->meta->make_immutable;
