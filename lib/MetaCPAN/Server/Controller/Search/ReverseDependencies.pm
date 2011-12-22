package MetaCPAN::Server::Controller::Search::ReverseDependencies;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller' }
with 'MetaCPAN::Server::Role::JSONP';

has '+type' => ( default => 'release' );

sub get : Chained('/search/index') : PathPart('reverse_dependencies') : Args(2) {
    my ( $self, $c, $author, $release ) = @_;

    my @modules = eval {
        $c->model('CPAN::File')->find_module_names_provided_by({
            author  => $author,
            name    => $release,
        });
    } or $c->detach('/not_found');

    eval {
        $c->stash(
            $c->model('CPAN::Release')->inflate(0)->find_depending_on(\@modules)
        );
    } or $c->detach('/not_found');
}

sub find : Chained('/search/index') : PathPart('reverse_dependencies') : Args(1) {
    my ( $self, $c, $name ) = @_;
    my $release = eval {
        $c->model('CPAN::Release')->inflate(0)->find($name)->{_source}
    } or $c->detach('/not_found');
    $c->forward('get', [@$release{qw( author name )}]);
}

1;
