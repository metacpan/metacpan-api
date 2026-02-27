package MetaCPAN::Script::Backup;

use strict;
use warnings;
use feature qw( state );

use Cpanel::JSON::XS   qw( decode_json encode_json );
use DateTime           ();
use IO::Zlib           ();
use Log::Contextual    qw( :log :dlog );
use MetaCPAN::Types    qw( Bool CommaSepOption Int Path Str );
use MetaCPAN::Util     qw( true false );
use MetaCPAN::ESConfig qw( es_config );
use Moose;
use Try::Tiny qw( catch try );

with 'MetaCPAN::Role::Script', 'MooseX::Getopt::Dashes';

has batch_size => (
    is            => 'ro',
    isa           => Int,
    default       => 100,
    documentation =>
        'Number of documents to restore in one batch, defaults to 100',
);

has index => (
    reader        => '_index',
    is            => 'ro',
    isa           => CommaSepOption,
    coerce        => 1,
    default       => sub { es_config->all_indexes },
    documentation => 'ES indexes to backup, defaults to "'
        . join( ', ', @{ es_config->all_indexes } ) . '"',
);

has type => (
    is            => 'ro',
    isa           => Str,
    documentation => 'ES type do backup, optional',
);

has size => (
    is            => 'ro',
    isa           => Int,
    default       => 1000,
    documentation => 'Size of documents to fetch at once, defaults to 1000',
);

has purge => (
    is            => 'ro',
    isa           => Bool,
    documentation => 'Purge old backups',
);

has dry_run => (
    is            => 'ro',
    isa           => Bool,
    documentation => q{Don't actually purge old backups},
);

has restore => (
    is            => 'ro',
    isa           => Path,
    coerce        => 1,
    documentation => 'Restore a backup',
);

sub run {
    my $self = shift;

    return $self->run_purge   if $self->purge;
    return $self->run_restore if $self->restore;

    my $es = $self->es;

    for my $index ( @{ $self->_index } ) {

        $self->es->indices->refresh( index => $index );

        my $filename = join( '-',
            DateTime->now->strftime('%F'),
            grep {defined} $index,
            $self->type );

        my $file = $self->home->child( qw(var backup), "$filename.json.gz" );
        $file->parent->mkpath unless ( -e $file->parent );
        my $fh = IO::Zlib->new( "$file", 'wb4' );

        my $scroll = $es->scroll_helper(
            index => $index,
            $self->type ? ( type => $self->type ) : (),
            scroll => '1m',
            body   => {
                _source => true,
                size    => $self->size,
                sort    => '_doc',
            },
        );

        log_info { 'Backing up ', $scroll->total, ' documents' };

        while ( my $result = $scroll->next ) {
            print $fh encode_json($result), $/;
        }
        close $fh;
    }
    log_info {'done'};
}

sub run_restore {
    my $self = shift;

    return log_fatal { $self->restore, q{ doesn't exist} }
        unless ( -e $self->restore );
    log_info { 'Restoring from ', $self->restore };

    my @bulk;
    my $es = $self->es;
    my $fh = IO::Zlib->new( $self->restore->stringify, 'rb' );

    my %bulk_store;

    while ( my $line = $fh->readline ) {

        state $line_count = 0;
        ++$line_count;
        my $raw;

        try { $raw = decode_json($line) }
        catch {
            log_warn {"cannot decode JSON: $line --- $&"};
        };

        # Create our bulk_helper if we need,
        # incase a backup has mixed _index or _type
        # create a new bulk helper for each
        my $bulk_key = $raw->{_index} . $raw->{_type};

        $bulk_store{$bulk_key} ||= $es->bulk_helper(
            index     => $raw->{_index},
            type      => $raw->{_type},
            max_count => $self->batch_size
        );

        # Fetch relevant bulk helper
        my $bulk = $bulk_store{$bulk_key};

        my $parent = $raw->{_parent};

        if ( $raw->{_type} eq 'author' ) {

            # Hack for dodgy lat / lon's
            if ( my $loc = $raw->{_source}->{location} ) {

                my $lat = $loc->[1];
                my $lon = $loc->[0];

                if ( $lat > 90 or $lat < -90 ) {

                    # Invalid latitude
                    delete $raw->{_source}->{location};
                }
                elsif ( $lon > 180 or $lon < -180 ) {

                    # Invalid longitude
                    delete $raw->{_source}->{location};
                }
            }
        }

        my $exists = $es->exists(
            index => $raw->{_index},
            type  => $raw->{_type},
            id    => $raw->{_id},
        );

        if ($exists) {
            $bulk->update( {
                id            => $raw->{_id},
                doc           => $raw->{_source},
                doc_as_upsert => true,
            } );

        }
        else {
            $bulk->create( {
                id => $raw->{_id},
                $parent ? ( parent => $parent ) : (),
                source => $raw->{_source},
            } );
        }
    }

    # Flush anything left over just incase
    for my $bulk ( values %bulk_store ) {
        $bulk->flush;
    }

    log_info {'done'};
}

sub run_purge {
    my $self = shift;

    my $now = DateTime->now;
    $self->home->child(qw(var backup))->visit(
        sub {
            my $file = shift;
            return if ( $file->is_dir );

            my $mtime = DateTime->from_epoch( epoch => $file->stat->mtime );

            # keep a daily backup for one week
            return
                if ( $mtime > $now->clone->subtract( days => 7 ) );

            # after that keep weekly backups
            if ( $mtime->clone->truncate( to => 'week' )
                != $mtime->clone->truncate( to => 'day' ) )
            {
                log_info {"Removing old backup $file"};
                return log_info {'Not (dry run)'}
                if ( $self->dry_run );
                $file->remove;
            }
        },
        { recurse => 1 }
    );
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

MetaCPAN::Script::Backup - Backup indices and types

=head1 SYNOPSIS

 $ bin/metacpan backup --index user --type account

 $ bin/metacpan backup --purge

=head1 DESCRIPTION

Creates C<.json.gz> files in C<var/backup>. These files contain
one record per line.

=head2 purge

Purges old backups. Backups from the current week are kept.
