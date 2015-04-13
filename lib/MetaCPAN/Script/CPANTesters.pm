package MetaCPAN::Script::CPANTesters;

use strict;
use warnings;

use CPAN::DistnameInfo ();
use DBI                ();
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);
use File::stat qw(stat);
use IO::Uncompress::Bunzip2 qw(bunzip2);
use List::AllUtils qw(any);
use LWP::UserAgent ();
use Log::Contextual qw( :log :dlog );
use Moose;
use Try::Tiny;

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has _bulk_queue => (
    is      => 'ro',
    default => sub { [] },
);

has url => (
    is      => 'ro',
    default => 'http://devel.cpantesters.org/release/release.db.bz2'
);

has db_file => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        $_[0]->home->file(qw(var tmp cpantesters.db));
    },
);

has dbh => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $db = $_[0]->db_file;
        log_info { 'Opening database file at ' . $db };
        return DBI->connect( 'dbi:SQLite:dbname=' . $db );
    },
);

has ua => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        LWP::UserAgent->new;
    }
);

sub run {
    my $self = shift;
    $self->index_reports;
    $self->index->refresh;
}

sub update_database {
    my ($self) = @_;
    my $db = $self->db_file;

    log_info { 'Mirroring ' . $self->url };
    $self->ua->mirror( $self->url, "$db.bz2" );

    if ( -e $db && stat($db)->mtime >= stat("$db.bz2")->mtime ) {
        log_info {"DB hasn't been modified"};
        return;
    }

    bunzip2 "$db.bz2" => "$db", AutoClose => 1;
    return 1;
}

sub fetch_all_releases {
    my ($self) = @_;
    my $index = $self->index->name;

    my $scroll = $self->es->scrolled_search(
        index       => $index,
        type        => 'release',
        query       => { match_all => {} },
        size        => 500,
        search_type => 'scan',
        scroll      => '5m',
    );

    my %releases;
    while ( my $release = $scroll->next ) {
        my $data = $release->{_source};
        $releases{ $self->_dist_key($data) } = $data;
    }

    log_debug { 'Releases: ' . keys %releases };

    return \%releases;
}

sub index_reports {
    my $self = shift;

    $self->update_database
        or return;

    # Fetch all releases up front and put them in a hash for fast lookup.
    my $releases = $self->fetch_all_releases;

    my $sth = $self->dbh->prepare('SELECT * FROM release');
    $sth->execute;

    my $count         = 0;
    my @result_fields = qw(fail pass na unknown);
    while ( my $row = $sth->fetchrow_hashref ) {
        $count++;
        log_trace {"Found in db: $row->{dist}-$row->{version}"};

        next
            unless my $release
            = $releases->{ join( '-', $row->{dist}, $row->{version} ) };

        # Only include this doc in the bulk update if there has been a change.
        next
            unless any { $row->{$_} != ( $release->{tests}->{$_} || 0 ) }
        @result_fields;

        $release->{tests}
            = { map { $_ => $row->{$_} } @result_fields };

        $self->update_release($release);
    }

    $self->dequeue_bulk;
    log_info {"Done.  Checked $count releases."};
}

sub update_release {
    my ( $self, $release ) = @_;
    my $queue = $self->_bulk_queue;
    log_debug { 'Updating ' . $release->{name} };
    push @$queue, $release;
    $self->dequeue_bulk if ( @$queue > 100 );
}

sub dequeue_bulk {
    my ($self) = @_;
    my $queue = $self->_bulk_queue;
    my @bulk;
    my $index = $self->index->name;
    while ( my $data = shift @$queue ) {
        push(
            @bulk,
            {
                index => {
                    index => $index,
                    id    => $data->{id},
                    type  => 'release',
                    data  => $data
                }
            }
        );
    }

    log_debug { 'Bulk updating ' . @bulk . ' releases' };

    $self->es->bulk( \@bulk );
}

sub _dist_key {
    my ( $self, $release ) = @_;

    # The CPAN Testers db uses CPAN::DistnameInfo rather than the META file
    # so we get better matches this way.
    try {
        my $info = CPAN::DistnameInfo->new( $release->{download_url} );

        my $v = $info->version;

# The CPAN Testers release db has no records with a version of '0'
# but it has several with a version of ''.
# There are also plenty of '0.00'.
# I believe the code responsible is
# https://github.com/barbie/cpan-testers-data-generator/blob/master/lib/CPAN/Testers/Data/Generator.pm#L864:
# > $fields{$_} ||= ''  for(@fields);
# Since '0' is false, but '0.0' is true.
# So use the same logic here, since this also DWIMs undef (which we want):
        $v ||= '';

        join '-', $info->dist, $v;
    }
    catch {
        my $error = $_[0];
        log_warn {$error};

        join '-',
            grep { defined($_) ? $_ : '' } $release->{distribution},
            $release->{version};
    };
}

__PACKAGE__->meta->make_immutable;
1;

=pod

=head1 SYNOPSIS

 $ bin/metacpan cpantesters

=head1 DESCRIPTION

Index CPAN Testers test results.

=head1 ARGUMENTS

=head2 db

Defaults to C<http://devel.cpantesters.org/release/release.db.bz2>.

=cut
