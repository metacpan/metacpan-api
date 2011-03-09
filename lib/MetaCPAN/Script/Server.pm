package MetaCPAN::Script::Server;

use Moose;
with 'MooseX::Getopt';
with 'MetaCPAN::Role::Common';
use Plack::Runner;

use Plack::App::URLMap;
use MetaCPAN::Plack::Module;
use MetaCPAN::Plack::Dependency;
use MetaCPAN::Plack::Distribution;
use MetaCPAN::Plack::Pod;
use MetaCPAN::Plack::Author;
use MetaCPAN::Plack::File;
use MetaCPAN::Plack::Source;
use MetaCPAN::Plack::Release;
use MetaCPAN::Plack::Mirror;

sub build_app {
    my $self = shift;
    my $app  = Plack::App::URLMap->new;
    for ( qw(Author Dependency Distribution File Mirror Module
          Pod Release Source) )
    {
        my $class = "MetaCPAN::Plack::" . $_;
        $app->map( "/" . lc($_),
                  $class->new( cpan => $self->cpan, remote => $self->remote ) );
    }
    return $app->to_app;
}

sub run {
    my ($self) = @_;
    my $runner = Plack::Runner->new;
    shift @ARGV;
    $runner->parse_options(qw(-s Starman));
    $runner->set_options( port => $self->port );
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
