package MetaCPAN::Server::Controller::Search::ReverseDependencies;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller' }
with 'MetaCPAN::Server::Role::JSONP';

has '+type' => ( default => 'release' );

sub get : Chained('/search/index') : PathPart('reverse_dependencies') :
    Args(2) : ActionClass('Deserialize') {
    my ( $self, $c, $author, $release ) = @_;

    my @modules = eval {
        $c->model('CPAN::File')->find_module_names_provided_by(
            {   author => $author,
                name   => $release,
            }
        );
    } or $c->detach('/not_found');

    my $query = $c->model('CPAN::Release')->inflate(0)
        ->find_depending_on( \@modules )->filter;
    if ( my $data = $c->req->data ) {
        $data->{filter}
            = $data->{filter}
            ? { and => [ $data->{filter}, $query ] }
            : $query;
    }
    else {
        $c->req->data(
            { query => { constant_score => { filter => $query } } } );
    }
    $c->forward('/release/search');
}

sub find : Chained('/search/index') : PathPart('reverse_dependencies') :
    Args(1) {
    my ( $self, $c, $name ) = @_;
    my $release = eval {
        $c->model('CPAN::Release')->inflate(0)->find($name)->{_source};
    } or $c->detach('/not_found');
    $c->forward( 'get', [ @$release{qw( author name )} ] );
}

1;
