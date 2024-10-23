package MetaCPAN::Server::Controller;

use Moose;
use namespace::autoclean;

use MetaCPAN::ESConfig qw( es_doc_path );
use MetaCPAN::Util     qw( single_valued_arrayref_to_scalar );

BEGIN { extends 'Catalyst::Controller'; }

__PACKAGE__->config(
    default     => 'application/json',
    map         => { 'application/json' => 'MetaCPANSanitizedJSON' },
    action_args => {
        'search' =>
            { deserialize_http_methods => [qw(POST PUT OPTIONS DELETE GET)] }
    }
);

has type => (
    is      => 'ro',
    lazy    => 1,
    default => sub { shift->action_namespace },
);

my $MAX_SIZE = 5000;

# apply "filters" like \&model but for fabricated data
sub apply_request_filter {
    my ( $self, $c, $data ) = @_;

    if ( my $fields = $c->req->param('fields') ) {
        my $filtered = {};
        my @fields   = split /,/, $fields;
        @$filtered{@fields} = @$data{@fields};
        $data = $filtered;
    }

    return $data;
}

sub model {
    my ( $self, $c ) = @_;
    my $model = $c->model('CPAN')->type( $self->type );
    $model = $model->fields( [ map { split(/,/) } $c->req->param('fields') ] )
        if $c->req->param('fields');
    if ( my ($size) = $c->req->param('size') ) {
        $c->detach( '/bad_request',
            [ "size parameter exceeds maximum of $MAX_SIZE", 416 ] )
            if ( $size && $size > $MAX_SIZE );
        $model = $model->size($size);
    }
    return $model;
}

sub mapping : Path('_mapping') Args(0) {
    my ( $self, $c ) = @_;
    $c->stash( $c->model('CPAN')
            ->es->indices->get_mapping( es_doc_path( $self->type ) ) );
}

sub get : Path('') : Args(1) {
    my ( $self, $c, $id ) = @_;
    my $model;

    # get a model without exploding when the request
    # is for a non-existing type
    eval {
        $model = $self->model($c);
        1;
    } or return;
    my $file = $model->raw->get($id);
    if ( !defined $file ) {
        $c->detach( '/not_found', ['Not found'] );
    }
    $c->stash( $file->{_source}
            || single_valued_arrayref_to_scalar( $file->{fields} ) )
        || $c->detach( '/not_found',
        ['The requested field(s) could not be found'] );
}

sub all : Path('') : Args(0) : ActionClass('~Deserialize') {
    my ( $self, $c ) = @_;
    $c->req->params->{q} ||= '*' unless ( $c->req->data );
    $c->forward('search');
}

sub search : Path('_search') : ActionClass('~Deserialize') {
    my ( $self, $c ) = @_;
    my $req = $c->req;

    # shallow copy
    my $params = { %{ $req->params } };
    delete $params->{$_} for qw(type index body join);
    {
        my $size = $params->{size} || ( $req->data || {} )->{size};
        $c->detach( '/bad_request',
            [ "size parameter exceeds maximum of $MAX_SIZE", 416 ] )
            if ( $size && $size > $MAX_SIZE );
    }
    delete $params->{callback};
    eval {
        my $res = $self->model($c)->es->search( {
            es_doc_path( $self->type ),
            body => $c->req->data || delete $params->{source},
            %$params,
        } );
        single_valued_arrayref_to_scalar( $_->{fields} )
            for @{ $res->{hits}{hits} };
        $c->stash($res);
        1;
    } or do { $self->internal_error( $c, $@ ) };
}

sub not_found : Private {
    my ( $self, $c ) = @_;
    $c->cdn_never_cache(1);

    $c->res->code(404);
    $c->stash( { message => 'Not found' } );
}

sub internal_error {
    my ( $self, $c, $message ) = @_;
    $c->cdn_never_cache(1);

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

sub end : Private {
    my ( $self, $c ) = @_;
    $c->forward('/end');
}

__PACKAGE__->meta->make_immutable;
1;
