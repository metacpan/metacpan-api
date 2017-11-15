package MetaCPAN::Script::Backpan;

use strict;
use warnings;

use Moose;

use Log::Contextual qw( :log :dlog );
use BackPAN::Index;
use MetaCPAN::Types qw( Bool HashRef Str );

with 'MetaCPAN::Role::Script', 'MooseX::Getopt::Dashes';

has distribution => (
    is            => 'ro',
    isa           => Str,
    documentation => 'work on given distribution',
);

has undo => (
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'mark releases as status=cpan',
);

has files_only => (
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'only update the "file" index',
);

has _cpan_files_list => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_cpan_files_list',
);

has _release_status => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { +{} },
);

has _bulk => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { +{} },
);

sub _build_cpan_files_list {
    my $self = shift;
    my $ls   = $self->cpan->child(qw(indices find-ls.gz));
    unless ( -e $ls ) {
        log_error {"File $ls does not exist"};
        exit;
    }
    log_info {"Reading $ls"};
    my $cpan = {};
    open my $fh, "<:gzip", $ls;
    while (<$fh>) {
        my $path = ( split(/\s+/) )[-1];
        next unless ( $path =~ /^authors\/id\/\w+\/\w+\/(\w+)\/(.*)$/ );
        $cpan->{$1}{$2} = 1;
    }
    close $fh;
    return $cpan;
}

sub run {
    my $self = shift;

    $self->es->trace_calls(1) if $ENV{DEBUG};

    $self->build_release_status_map();

    $self->update_releases() unless $self->files_only;

    $self->update_files();

    $_->flush for values %{ $self->_bulk };
}

sub build_release_status_map {
    my $self = shift;

    log_info {"find_releases"};

    my $scroll = $self->es->scroll_helper(
        size   => 500,
        scroll => '5m',
        index  => $self->index->name,
        type   => 'release',
        fields => [ 'author', 'archive', 'name' ],
        body   => $self->_get_release_query,
    );

    while ( my $release = $scroll->next ) {
        my $author  = $release->{fields}{author}[0];
        my $archive = $release->{fields}{archive}[0];
        my $name    = $release->{fields}{name}[0];
        next unless $name;    # bypass some broken releases

        $self->_release_status->{$author}{$name} = [
            (
                $self->undo
                    or exists $self->_cpan_files_list->{$author}{$archive}
            )
            ? 'cpan'
            : 'backpan',
            $release->{_id}
        ];
    }
}

sub _get_release_query {
    my $self = shift;

    unless ( $self->undo ) {
        return +{
            query => {
                not => { term => { status => 'backpan' } }
            }
        };
    }

    return +{
        query => {
            bool => {
                must => [
                    { term => { status => 'backpan' } },
                    (
                        $self->distribution
                        ? {
                            term => { distribution => $self->distribution }
                            }
                        : ()
                    )
                ]
            }
        }
    };
}

sub update_releases {
    my $self = shift;

    log_info {"update_releases"};

    $self->_bulk->{release} ||= $self->es->bulk_helper(
        index     => $self->index->name,
        type      => 'release',
        max_count => 250,
        timeout   => '5m',
    );

    for my $author ( keys %{ $self->_release_status } ) {

        # value = [ status, _id ]
        for ( values %{ $self->_release_status->{$author} } ) {
            $self->_bulk->{release}->update(
                {
                    id  => $_->[1],
                    doc => {
                        status => $_->[0],
                    }
                }
            );
        }
    }
}

sub update_files {
    my $self = shift;

    for my $author ( keys %{ $self->_release_status } ) {
        my @releases = keys %{ $self->_release_status->{$author} };
        while ( my @chunk = splice @releases, 0, 1000 ) {
            $self->update_files_author( $author, \@chunk );
        }
    }
}

sub update_files_author {
    my $self            = shift;
    my $author          = shift;
    my $author_releases = shift;

    log_info { "update_files: " . $author };

    my $scroll = $self->es->scroll_helper(
        size   => 500,
        scroll => '5m',
        index  => $self->index->name,
        type   => 'file',
        fields => ['release'],
        body   => {
            query => {
                bool => {
                    must => [
                        { term  => { author  => $author } },
                        { terms => { release => $author_releases } }
                    ]
                }
            }
        },
    );

    $self->_bulk->{file} ||= $self->es->bulk_helper(
        index     => $self->index->name,
        type      => 'file',
        max_count => 250,
        timeout   => '5m',
    );
    my $bulk = $self->_bulk->{file};

    while ( my $file = $scroll->next ) {
        my $release = $file->{fields}{release}[0];
        $bulk->update(
            {
                id  => $file->{_id},
                doc => {
                    status => $self->_release_status->{$author}{$release}[0]
                }
            }
        );
    }
}

__PACKAGE__->meta->make_immutable;
1;

=pod

Sets "backpan" status on all BackPAN releases.

=cut
