package MetaCPAN::Server::Controller::Diff;
use Moose;
use MetaCPAN::Server::Diff;
BEGIN { extends 'MetaCPAN::Server::Controller' }

sub index : Chained('/') : PathPart('diff') : CaptureArgs(0) {
}

sub diff_releases : Chained('index') : PathPart('release') : Args(4) {
    my ( $self, $c, @path ) = @_;
    my $path1 = $c->model('Source')->path( $path[0], $path[1] );
    my $path2 = $c->model('Source')->path( $path[2], $path[3] );

    my $diff = MetaCPAN::Server::Diff->new(
        source   => $path1,
        target   => $path2,
        git      => $c->config->{git},
        relative => $path1->parent,
    );

    $c->stash(
        {   source     => join( '/', $path[0], $path[1] ),
            target     => join( '/', $path[2], $path[3] ),
            statistics => $diff->structured,
            diff       => $diff->raw,
        }
    );
}

sub release : Chained('index') : PathPart('release') : Args(1) {
    my ( $self, $c, $name ) = @_;
    my $release = eval {
        $c->model('CPAN::Release')->inflate(0)->find($name)->{_source};
    }
        or $c->detach('/not_found');
    my $with = eval {
        $c->model('CPAN::Release')->inflate(0)->predecessor($name)->{_source};
    }
        or $c->detach('/not_found');
    $c->forward( 'diff_releases',
        [ @$release{qw(author name)}, @$with{qw(author name)} ] );
}

sub file : Chained('index') : PathPart('file') : Args(2) {
    my ( $self, $c, $source, $target ) = @_;
    $source
        = eval { $c->model('CPAN::File')->inflate(0)->get($source)->{_source}; }
        or $c->detach('/not_found');
    $target
        = eval { $c->model('CPAN::File')->inflate(0)->get($target)->{_source}; }
        or $c->detach('/not_found');

    my $diff = MetaCPAN::Server::Diff->new(
        relative =>
            $c->model('Source')->path( @$source{qw(author release)} )->parent,
        source =>
            $c->model('Source')->path( @$source{qw(author release path)} ),
        target =>
            $c->model('Source')->path( @$target{qw(author release path)} ),
        git => $c->config->{git}
    );

    $c->stash(
        {   source => join( '/', @$source{qw(author release path)} ),
            target => join( '/', @$target{qw(author release path)} ),
            statistics => $diff->structured,
            diff       => $diff->raw,
        }
    );
}

1;
