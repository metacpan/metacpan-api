package MetaCPAN::Script::Purge;

use Moose;

use Log::Contextual qw( :log );
use MetaCPAN::Types qw( Bool Str HashRef );

with 'MooseX::Getopt', 'MetaCPAN::Role::Script';

has author => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has release => (
    is       => 'ro',
    isa      => Str,
    required => 0,
);

has force => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has bulk => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_bulk',
);

sub _build_bulk {
    my $self  = shift;
    my $index = $self->index->name;
    return +{
        author => $self->es->bulk_helper( index => $index, type => 'author' ),
        contributor => $self->es->bulk_helper(
            index => 'contributor',
            type  => 'contributor'
        ),
        favorite =>
            $self->es->bulk_helper( index => $index, type => 'favorite' ),
        file => $self->es->bulk_helper( index => $index, type => 'file' ),
        permission =>
            $self->es->bulk_helper( index => $index, type => 'permission' ),
        rating => $self->es->bulk_helper( index => $index, type => 'rating' ),
        release =>
            $self->es->bulk_helper( index => $index, type => 'release' ),
    };
}

sub _get_scroller_release {
    my ( $self, $query ) = @_;
    return $self->es->scroll_helper(
        size   => 500,
        scroll => '10m',
        index  => $self->index->name,
        type   => 'release',
        body   => { query => $query },
        fields => [qw( name )],
    );
}

sub _get_scroller_rating {
    my ( $self, $query ) = @_;
    return $self->es->scroll_helper(
        size   => 500,
        scroll => '10m',
        index  => $self->index->name,
        type   => 'rating',
        body   => { query => $query },
        fields => [],
    );
}

sub _get_scroller_file {
    my ( $self, $query ) = @_;
    return $self->es->scroll_helper(
        size   => 500,
        scroll => '10m',
        index  => $self->index->name,
        type   => 'file',
        body   => { query => $query },
        fields => [qw( name )],
    );
}

sub _get_scroller_favorite {
    my ( $self, $query ) = @_;
    return $self->es->scroll_helper(
        size   => 500,
        scroll => '10m',
        index  => $self->index->name,
        type   => 'favorite',
        body   => { query => $query },
        fields => [],
    );
}

sub _get_scroller_contributor {
    my ( $self, $query ) = @_;
    return $self->es->scroll_helper(
        size   => 500,
        scroll => '10m',
        index  => 'contributor',
        type   => 'contributor',
        body   => { query => $query },
        fields => [qw( release_name )],
    );
}

sub run {
    my $self = shift;

    if ( $self->author ) {
        if ( !$self->force ) {
            if ( $self->release ) {
                $self->are_you_sure( 'Release '
                        . $self->release
                        . ' by author '
                        . $self->author
                        . ' will be removed from the index !!!' );
            }
            else {
                $self->are_you_sure( 'Author '
                        . $self->author
                        . ' + all their releases will be removed from the index !!!'
                );
            }
        }
        $self->purge_author_releases;
        $self->purge_favorite;
        $self->purge_author;
        $self->purge_contributor;
        $self->purge_rating;
    }

    $self->index->refresh;
}

sub purge_author_releases {
    my $self = shift;

    if ( $self->release ) {
        $self->purge_single_release;
        $self->purge_files( $self->release );
    }
    else {
        $self->purge_multiple_releases;
    }
}

sub purge_single_release {
    my $self = shift;
    log_info {
        'Looking for release '
            . $self->release
            . ' by author '
            . $self->author
    };

    my $query = {
        bool => {
            must => [
                { term => { author => $self->author } },
                { term => { name   => $self->release } }
            ]
        }
    };

    my $scroll = $self->_get_scroller_release($query);
    my @remove;

    while ( my $r = $scroll->next ) {
        log_debug { 'Removing release ' . $r->{fields}{name}[0] };
        push @remove, $r->{_id};
    }

    if (@remove) {
        $self->bulk->{release}->delete_ids(@remove);
        $self->bulk->{release}->flush;
    }

    log_info { 'Finished purging release ' . $self->release };
}

sub purge_multiple_releases {
    my $self = shift;
    log_info { 'Looking all up author ' . $self->author . ' releases' };

    my $query = { term => { author => $self->author } };

    my $scroll = $self->_get_scroller_release($query);
    my @remove_ids;
    my @remove_release_files;

    while ( my $r = $scroll->next ) {
        log_debug { 'Removing release ' . $r->{fields}{name}[0] };
        push @remove_ids,           $r->{_id};
        push @remove_release_files, $r->{fields}{name}[0];
    }

    if (@remove_ids) {
        $self->bulk->{release}->delete_ids(@remove_ids);
        $self->bulk->{release}->flush;
    }

    for my $release (@remove_release_files) {
        $self->purge_files($release);
    }

    log_info { 'Finished purging releases for author ' . $self->author };
}

sub purge_files {
    my ( $self, $release ) = @_;
    log_info {
        'Looking for files of release '
            . $release
            . ' by author '
            . $self->author
    };

    my $query = {
        bool => {
            must => [
                { term => { author  => $self->author } },
                { term => { release => $release } }
            ]
        }
    };

    my $scroll = $self->_get_scroller_file($query);
    my @remove;

    while ( my $f = $scroll->next ) {
        log_debug {
            'Removing file '
                . $f->{fields}{name}[0]
                . ' of release '
                . $release
        };
        push @remove, $f->{_id};
    }

    if (@remove) {
        $self->bulk->{file}->delete_ids(@remove);
        $self->bulk->{file}->flush;
    }

    log_info { 'Finished purging files for release ' . $release };
}

sub purge_favorite {
    my ( $self, $release ) = @_;

    if ( $self->release ) {
        log_info {
            'Looking for favorites of release '
                . $self->release
                . ' by author '
                . $self->author
        };
        $self->_purge_favorite( { term => { release => $self->release } } );
        log_info {
            'Finished purging favorites for release ' . $self->release
        };
    }
    else {
        log_info { 'Looking for favorites author ' . $self->author };
        $self->_purge_favorite( { term => { author => $self->author } } );
        log_info { 'Finished purging favorites for author ' . $self->author };
    }
}

sub _purge_favorite {
    my ( $self, $query ) = @_;

    my $scroll = $self->_get_scroller_favorite($query);
    my @remove;

    while ( my $f = $scroll->next ) {
        push @remove, $f->{_id};
    }

    if (@remove) {
        $self->bulk->{favorite}->delete_ids(@remove);
        $self->bulk->{favorite}->flush;
    }
}

sub purge_author {
    my $self = shift;
    log_info { 'Purging author ' . $self->author };

    $self->bulk->{author}->delete_ids( $self->author );
    $self->bulk->{author}->flush;

    log_info { 'Finished purging author ' . $self->author };
}

sub purge_contributor {
    my $self = shift;
    log_info { 'Looking all up author ' . $self->author . ' contributions' };

    my @remove;

    my $query_release_author
        = { term => { release_author => $self->author } };

    my $scroll_release_author
        = $self->_get_scroller_contributor($query_release_author);

    while ( my $r = $scroll_release_author->next ) {
        log_debug {
            'Removing contributions to releases by author ' . $self->author
        };
        push @remove, $r->{_id};
    }

    my $query_pauseid = { term => { pauseid => $self->author } };

    my $scroll_pauseid = $self->_get_scroller_contributor($query_pauseid);

    while ( my $c = $scroll_pauseid->next ) {
        log_debug { 'Removing contributions of author ' . $self->author };
        push @remove, $c->{_id};
    }

    if (@remove) {
        $self->bulk->{contributor}->delete_ids(@remove);
        $self->bulk->{contributor}->flush;
    }

    log_info {
        'Finished purging contribution entries related to ' . $self->author
    };
}

sub purge_rating {
    my $self = shift;

    if ( $self->release ) {
        $self->purge_rating_release;
    }
    else {
        $self->purge_rating_author;
    }
}

sub purge_rating_release {
    my $self = shift;
    log_info {
        'Looking all up ratings for release '
            . $self->release
            . ' author '
            . $self->author
    };

    my @remove;

    my $query = {
        bool => {
            must => [
                { term => { author  => $self->author } },
                { term => { release => $self->release } }
            ]
        }
    };

    my $scroll_rating = $self->_get_scroller_rating($query);

    while ( my $r = $scroll_rating->next ) {
        log_debug {
            'Removing ratings for release '
                . $self->release
                . ' by author '
                . $self->author
        };
        push @remove, $r->{_id};
    }

    if (@remove) {
        $self->bulk->{rating}->delete_ids(@remove);
        $self->bulk->{rating}->flush;
    }

    log_info {
        'Finished purging rating entries for release '
            . $self->release
            . ' by author '
            . $self->author
    };
}

sub purge_rating_author {
    my $self = shift;
    log_info { 'Looking all up ratings for author ' . $self->author };

    my @remove;

    my $query = { term => { author => $self->author } };

    my $scroll_rating = $self->_get_scroller_rating($query);

    while ( my $r = $scroll_rating->next ) {
        log_debug { 'Removing ratings related to author ' . $self->author };
        push @remove, $r->{_id};
    }

    if (@remove) {
        $self->bulk->{rating}->delete_ids(@remove);
        $self->bulk->{rating}->flush;
    }

    log_info {
        'Finished purging rating entries related to author ' . $self->author
    };
}

__PACKAGE__->meta->make_immutable;
1;

=pod

=head1 SYNOPSIS

Purge releases from the index, by author or name

  $ bin/metacpan purge --author X
  $ bin/metacpan purge --release Y

=cut
