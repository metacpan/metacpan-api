package MetaCPAN::Script::Backup;

use strict;
use warnings;
use feature qw( state );

use Data::Printer;
use DateTime;
use IO::Zlib ();
use JSON::XS;
use Log::Contextual qw( :log :dlog );
use MetaCPAN::Types qw( Bool Int Str File );
use Moose;
use Try::Tiny;

with 'MetaCPAN::Role::Script', 'MooseX::Getopt::Dashes';

has batch_size => (
    is      => 'ro',
    isa     => Int,
    default => 100,
    documentation =>
        'Number of documents to restore in one batch, defaults to 100',
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
    isa           => File,
    coerce        => 1,
    documentation => 'Restore a backup',
);

sub run {
    my $self = shift;

    return $self->run_purge   if $self->purge;
    return $self->run_restore if $self->restore;

    my $es = $self->es;
    $self->index->refresh;

    my $filename = join( '-',
        DateTime->now->strftime('%F'),
        grep {defined} $self->index->name,
        $self->type );

    my $file = $self->home->subdir(qw(var backup))->file("$filename.json.gz");
    $file->dir->mkpath unless ( -e $file->dir );
    my $fh = IO::Zlib->new( "$file", 'wb4' );

    my $scroll = $es->scroll_helper(
        index => $self->index->name,
        $self->type ? ( type => $self->type ) : (),
        size        => $self->size,
        search_type => 'scan',
        fields      => [qw(_parent _source)],
        scroll      => '1m',
    );

    log_info { 'Backing up ', $scroll->total, ' documents' };

    while ( my $result = $scroll->next ) {
        print $fh encode_json($result), $/;
    }
    close $fh;
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
            log_warn {"cannot decode JSON: $line --- $_"};
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

        my $parent = $raw->{fields}->{_parent};

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

        $bulk->create(
            {
                id => $raw->{_id},
                $parent ? ( parent => $parent ) : (),
                source => $raw->{_source},
            }
        );

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
    $self->home->subdir(qw(var backup))->recurse(
        callback => sub {
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
                log_info        {"Removing old backup $file"};
                return log_info {'Not (dry run)'}
                if ( $self->dry_run );
                $file->remove;
            }
        }
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
