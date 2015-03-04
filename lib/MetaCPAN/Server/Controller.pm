package MetaCPAN::Server::Controller;

use strict;
use warnings;
use namespace::autoclean;

use JSON;
use List::MoreUtils ();
use Moose::Util     ();
use Moose;

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

has relationships => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
    traits  => ['Hash'],
    handles => { has_relationships => 'count' },
);

my $MAX_SIZE = 5000;

# apply "filters" like \&model but for fabricated data
sub apply_request_filter {
    my ( $self, $c, $data ) = @_;

    if ( my $fields = $c->req->param("fields") ) {
        my $filtered = {};
        my @fields = split /,/, $fields;
        @$filtered{@fields} = @$data{@fields};
        $data = $filtered;
    }

    return $data;
}

sub model {
    my ( $self, $c ) = @_;
    my $model = $c->model('CPAN')->type( $self->type );
    $model = $model->fields( [ map { split(/,/) } $c->req->param("fields") ] )
        if $c->req->param("fields");
    if ( my ($size) = $c->req->param("size") ) {
        $c->detach( '/bad_request',
            [ "size parameter exceeds maximum of $MAX_SIZE", 416 ] )
            if ( $size && $size > $MAX_SIZE );
        $model = $model->size($size);
    }
    return $model;
}

sub mapping : Path('_mapping') {
    my ( $self, $c ) = @_;
    $c->stash(
        $c->model('CPAN')->es->indices->get_mapping(
            index => $c->model('CPAN')->index,
            type  => $self->type
        )
    );
}

sub get : Path('') : Args(1) {
    my ( $self, $c, $id ) = @_;
    my $file = $self->model($c)->raw->get($id);
    if ( !defined $file ) {
        $c->detach( '/not_found', ['Not found'] );
    }
    $c->stash( $file->{_source} || $file->{fields} )
        || $c->detach( '/not_found',
        ['The requested field(s) could not be found'] );
}

sub all : Path('') : Args(0) : ActionClass('Deserialize') {
    my ( $self, $c ) = @_;
    $c->req->params->{q} ||= '*' unless ( $c->req->data );
    $c->forward('search');
}

sub search : Path('_search') : ActionClass('Deserialize') {
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
        $c->stash(
            $self->model($c)->es->search(
                {
                    index => $c->model("CPAN")->index,
                    type  => $self->type,
                    body  => $c->req->data,
                    %$params,
                }
            )
        );
    } or do { $self->internal_error( $c, $@ ) };
}

sub join : ActionClass('Deserialize') {
    my ( $self, $c ) = @_;
    my $joins     = $self->relationships;
    my @req_joins = $c->req->param('join');
    my $is_get    = ref $c->stash->{hits} ? 0 : 1;
    my $query
        = $c->req->params->{q}
        ? { query => { query_string => { query => $c->req->params->{q} } } }
        : $c->req->data ? $c->req->data
        :                 { query => { match_all => {} } };
    $c->detach(
        "/not_allowed",
        [
            "unknown join type, valid values are "
                . Moose::Util::english_list( keys %$joins )
        ]
    ) if ( scalar grep { !$joins->{$_} } @req_joins );

    while ( my ( $join, $config ) = each %$joins ) {
        my $has_many = ref $config->{type};
        my ($type) = $has_many ? @{ $config->{type} } : $config->{type};
        my $cself = $config->{self} || $join;
        next unless ( grep { $_ eq $join } @req_joins );
        my $data
            = $is_get
            ? [ $c->stash ]
            : [ map { $_->{_source} || $_->{fields} }
                @{ $c->stash->{hits}->{hits} } ];
        my @ids = List::MoreUtils::uniq grep {defined}
            map { ref $cself eq 'CODE' ? $cself->($_) : $_->{$cself} } @$data;
        my $filter = { terms => { $config->{foreign} => [@ids] } };
        my $filtered = {%$query};    # don't work on $query
        $filtered->{filter}
            = $query->{filter}
            ? { and => [ $filter, $query->{filter} ] }
            : $filter;
        my $foreign = eval {
            $c->model("CPAN::$type")->query( $filtered->{query} )
                ->filter( $filtered->{filter} )->size(1000)->raw->all;
        } or do { $self->internal_error( $c, $@ ) };
        $c->detach(
            "/not_allowed",
            [
                "The number of joined documents exceeded the allowed number of 1000 documents by "
                    . ( $foreign->{hits}->{total} - 1000 )
                    . ". Please reduce the number of documents or apply additional filters."
            ]
        ) if ( $foreign->{hits}->{total} > 1000 );
        $c->stash->{took} += $foreign->{took} unless ($is_get);

        if ($has_many) {
            my $many;
            for ( @{ $foreign->{hits}->{hits} } ) {
                my $list = $many->{ $_->{_source}->{ $config->{foreign} } }
                    ||= [];
                push( @$list, $_ );
            }
            $foreign = $many;
        }
        else {
            $foreign = { map { $_->{_source}->{ $config->{foreign} } => $_ }
                    @{ $foreign->{hits}->{hits} } };
        }
        for (@$data) {
            my $key = ref $cself eq 'CODE' ? $cself->($_) : $_->{$cself};
            next unless ($key);
            my $result = $foreign->{$key};
            $_->{$join}
                = $has_many
                ? {
                hits => {
                    hits  => $result,
                    total => scalar @{ $result || [] }
                }
                }
                : $result;
        }
    }
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

sub end : Private {
    my ( $self, $c ) = @_;
    $c->forward("join")
        if ( $self->has_relationships && $c->req->param('join') );
    $c->forward("/end");
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 ATTRIBUTES

=head2 relationships

 MetaCPAN::Server::Controller::Author->config(
     relationships => {
         release => {
             type    => ['Release'],
             self    => 'pauseid',
             foreign => 'author',
         }
     }
 );

Contains a HashRef of relationships with other controllers.
If C<type> is an ArrayRef, the relationship is considered a
I<has many> relationship.

Unless a C<self> exists, the name of the relationship is used
as key to join on. C<self> can also be a CodeRef, if the foreign
key is build from several local keys. In this case, again the name of
the relationship is used as key in the result.

C<foreign> refers to the foreign key on the C<type> controller the data
is joined with.

=head1 ACTIONS

=head2 join

This action is called if the controller has L</relationships> defined
and if one or more C<join> query parameters are defined. It then
does a I<left join> based on the information provided by
L</relationships>.

This works both for GET requests, where only one document is requested
and search requests, where a number of documents is returned.
It also passes through search data (either the C<q> query string or
the request body).

B<The number of documents that can be joined is limited to 1000 per
relationship for now.>

=cut
