package MetaCPAN::Server::Controller::ReverseDependencies;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller' }
with 'MetaCPAN::Server::Role::JSONP';

sub index : Chained('/') : PathPart('reverse_dependencies') : CaptureArgs(0) {
}

sub get : Chained('index') : PathPart('') : Args(1) {
    my ( $self, $c, $name ) = @_;

    my $modules = eval {
        my $mods = $c->model('CPAN::File')->inflate(0)->find_provided_by($name);
        [
            map { ref($_) eq 'ARRAY' ? @$_ : $_ } # multiple packages in one file
            map { $_->{fields}->{'module.name'} }
            @{ $mods->{hits}->{hits} }
        ];
    } or $c->detach('/not_found');

    eval {
        $c->stash(
            $c->model('CPAN::Release')->inflate(0)->find_depending_on($modules)
        );
    } or $c->detach('/not_found');
}

1;
