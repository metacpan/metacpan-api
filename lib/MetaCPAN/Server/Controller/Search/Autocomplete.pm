package MetaCPAN::Server::Controller::Search::Autocomplete;
use Moose;
BEGIN { extends 'MetaCPAN::Server::Controller' }
with 'MetaCPAN::Server::Role::JSONP';

has '+type' => ( default => 'file' );

sub get : Chained('/search/index') : PathPart('autocomplete') : Args(0) :
    ActionClass('Deserialize') {
    my ( $self, $c ) = @_;
    my $frac = join( ' ', $c->req->param('q') );
    my $size = $c->req->params->{size};
    $size = 20 unless(defined $size);
    $c->detach('/not_allowed') unless($size =~ /^\d+$/ && $size >= 0 && $size <= 100);
    my $data = $c->model('CPAN::File')->prefix($frac)->inflate(0)
        ->fields( [qw(documentation release author distribution)] )->size($size);
    $c->stash($data->all);
}

1;
