use Plack::App::Directory;
use Plack::Builder;

# plackup -I../lib

my $app = Plack::App::Directory->new(root => "/home/olaf/cpan-source")->to_app;

builder {
    enable "Plack::Middleware::CPANSource";
    $app;
};

