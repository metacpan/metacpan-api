package MetaCPAN::Script::ReindexDist;

# ABSTRACT: Reindex all releases of a distribution

use strict;
use warnings;

use Moose;
use MetaCPAN::Types qw( ArrayRef Bool Str );

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has distribution => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_distribution',
);

sub _build_distribution {
    my ($self) = @_;

    # First arg (after script name) is distribution name.
    # Is there a better way to do this?
    return $self->extra_argv->[1];
}

has releases => (
    is      => 'ro',
    isa     => ArrayRef,
    lazy    => 1,
    builder => '_build_releases',
);

sub _build_releases {
    my ($self) = @_;
    return [ $self->index->type('release')
            ->filter( { term => { distribution => $self->distribution } } )
            ->fields( [qw( download_url )] )->sort( ['date'] )->size(5000)
            ->all
    ];
}

has sources => (
    is      => 'ro',
    isa     => ArrayRef,
    lazy    => 1,
    builder => '_build_sources',
);

has prompt => (
    is            => 'ro',
    isa           => Bool,
    default       => 1,
    documentation => q{Prompt for confirmation (default true)},
);

sub _build_sources {
    my ($self) = @_;
    return [ map { $_->download_url } @{ $self->releases } ];
}

sub script {
    my $self = shift;
    local @ARGV = @_;
    MetaCPAN::Script::Runner->run;
}

sub run {
    my ($self) = @_;
    $self->confirm;
    $self->script(
        release => qw(--level debug --detect_backpan),
        @{ $self->sources }
    );
    $self->script( latest => '--distribution', $self->distribution );
}

sub confirm {
    my ($self) = @_;

    die "No releases found for ${\ $self->distribution }\n"
        if !@{ $self->releases };

    print "Reindexing ${\ $self->distribution }\n",
        ( map {"  $_\n"} @{ $self->sources } );

    if ( !$self->prompt ) {
        return;
    }

    print 'Continue? (y/n): ';

    my $confirmation = <STDIN>;

    die "Aborted\n"
        unless $confirmation =~ /^y/i;
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 SYNOPSIS

 # bin/metacpan reindexdist Foo-Bar

=head1 DESCRIPTION

Reindex all the releases of a named distribution.

=cut
