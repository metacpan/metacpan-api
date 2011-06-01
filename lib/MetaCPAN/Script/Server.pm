package MetaCPAN::Script::Server;

use Moose;
with 'MooseX::Getopt';
with 'MetaCPAN::Role::Common';
use Plack::Runner;

use Plack::App::URLMap;
use Plack::Middleware::CrossOrigin;
use Plack::Middleware::Session;
use Plack::Session::Store::ElasticSearch;
use Plack::Session::State::Cookie;
use Class::MOP;

sub build_app {
    my $self = shift;
    my $app  = Plack::App::URLMap->new;
    my $index = $self->index;
    for ( qw(Author File Mirror Module
          Pod Release Source Login User) )
    {
        my $class = "MetaCPAN::Plack::" . $_;
        Class::MOP::load_class($class);
        $app->map( "/" . lc($_),
                   $class->new( model  => $self->model,
                                cpan   => $self->cpan,
                                remote => $self->remote,
                                index  => $index,
                   ) );
    }

    Plack::Middleware::Session->wrap(
             $app->to_app,
             store => Plack::Session::Store::ElasticSearch->new( index => 'user', type => 'account', property => 'session', es => $self->model->es ),
             state => Plack::Session::State::Cookie->new( expires => 2**30 ) );
}

sub run {
    my ($self) = @_;
    my $runner = Plack::Runner->new;
    shift @ARGV;

    $runner->parse_options(@{$self->extra_argv});
    $runner->run( $self->build_app );
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 SYNOPSIS

 # bin/metacpan server --cpan ~/cpan

=head1 DESCRIPTION

This script starts a L<Twiggy> server and sets up a couple of
endpoints.

=head1 ENDPOINTS

=head2 /author

See L<MetaCPAN::Plack::Author>.

=head2 /distribution

See L<MetaCPAN::Plack::Distribution>.

=head2 /file

See L<MetaCPAN::Plack::File>.

=head2 /module

See L<MetaCPAN::Plack::Module>.

=head2 /pod

See L<MetaCPAN::Plack::Pod>.

=head2 /release

See L<MetaCPAN::Plack::Release>.

=head2 /source

See L<MetaCPAN::Plack::Source>.
