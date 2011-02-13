package MetaCPAN::Script::Server;

use Moose;
with 'MooseX::Getopt';
with 'MetaCPAN::Role::Common';
use MetaCPAN;
use Plack::Runner;
use Plack::Middleware::Conditional;
use Plack::Middleware::ReverseProxy;
use Plack::App::Directory;

use Plack::Builder;
use JSON::XS;
use Plack::App::Proxy;
use MetaCPAN::Plack::Module;
use MetaCPAN::Plack::Distribution;
use MetaCPAN::Plack::Pod;
use MetaCPAN::Plack::Author;
use MetaCPAN::Plack::File;
use MetaCPAN::Plack::Source;

has port => ( is => 'ro', default => '5000' );

sub build_app {
    my $self = shift;
    return builder {
        mount "/module"       => MetaCPAN::Plack::Module->new;
        mount "/distribution" => MetaCPAN::Plack::Distribution->new;
        mount "/author"       => MetaCPAN::Plack::Author->new;
        mount "/file"         => MetaCPAN::Plack::File->new;
        mount "/pod"          => MetaCPAN::Plack::Pod->new;
        mount "/source"       => MetaCPAN::Plack::Source->new( cpan => $self->cpan );
    };
}

sub run {
    my ($self) = @_;
    my $runner = Plack::Runner->new;
    shift @ARGV;
    $runner->parse_options;
    $runner->set_options( port => $self->port );
    $runner->run( $self->build_app->to_app );
}

__PACKAGE__->meta->make_immutable;
