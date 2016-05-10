package MetaCPAN::Script::CPANTesters;

use strict;
use warnings;

use DBI ();
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);
use File::stat qw(stat);
use IO::Uncompress::Bunzip2 qw(bunzip2);
use LWP::UserAgent ();
use Log::Contextual qw( :log :dlog );
use MetaCPAN::Types qw( Bool File Uri );
use Moose;

with 'MetaCPAN::Role::Script', 'MooseX::Getopt::Dashes';

has db => (
    is      => 'ro',
    isa     => Uri,
    lazy    => 1,
    coerce  => 1,
    builder => '_build_db',
);

has force_refresh => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

# XXX move path to config
has mirror_file => (
    is      => 'ro',
    isa     => File,
    default => sub {
        shift->home->file( 'var', ( $ENV{HARNESS_ACTIVE} ? 't' : () ),
            'tmp', 'cpantesters.db' );
    },
    coerce => 1,
);

has skip_download => (
    is  => 'ro',
    isa => Bool,
);

has _bulk => (
    is      => 'ro',
    isa     => 'Search::Elasticsearch::Bulk',
    lazy    => 1,
    default => sub {
        $_[0]->model->es->bulk_helper(
            index => $_[0]->index->name,
            type  => 'release'
        );
    },
);

# XXX fix hardcoded path
sub _build_db {
    my $self = shift;
    return $ENV{HARNESS_ACTIVE}
        ? $self->home->file('t/var/cpantesters-release-fake.db.bz2')
        : 'http://devel.cpantesters.org/release/release.db.bz2';
}

sub run {
    my $self = shift;
    $self->index_reports;
    $self->index->refresh;
}

sub index_reports {
    my $self = shift;

    my $es = $self->model->es;
    my $ua = LWP::UserAgent->new;

    log_info { 'Mirroring ' . $self->db };
    my $db = $self->mirror_file;

    $ua->mirror( $self->db, "$db.bz2" ) unless $self->skip_download;

    if ( -e $db && stat($db)->mtime >= stat("$db.bz2")->mtime ) {
        log_info {'DB hasn\'t been modified'};
        return unless $self->force_refresh;
    }

    bunzip2 "$db.bz2" => "$db", AutoClose => 1 if -e "$db.bz2";

    my $scroll = $es->scroll_helper(
        index       => $self->index->name,
        search_type => 'scan',
        size        => '500',
        type        => 'release',
    );

    my %releases;
    while ( my $release = $scroll->next ) {
        my $data = $release->{_source};

        # XXX temporary hack.  This may be masking issues with release
        # versions. (Olaf)
        my $version = $data->{version};
        $version =~ s{\Av}{} if $version;

        $releases{
            join( '-', grep {defined} $data->{distribution}, $version )
        } = $data;
    }

    log_info { 'Opening database file at ' . $db };

    my $dbh = DBI->connect( 'dbi:SQLite:dbname=' . $db );
    my $sth;
    $sth = $dbh->prepare('SELECT * FROM release');

    $sth->execute;
    my @bulk;
    while ( my $row_from_db = $sth->fetchrow_hashref ) {

       # The testers db seems to return q{} where we would expect a version of
       # 0.

        my $version = $row_from_db->{version} || 0;
        my $release = join( '-', $row_from_db->{dist}, $version );
        my $release_doc = $releases{$release};

        # there's a cpantesters dist we haven't indexed
        next unless ($release_doc);

        my $insert_ok = 0;

        my $tester_results = $release_doc->{tests};
        if ( !$tester_results ) {
            $tester_results = {};
            $insert_ok      = 1;
        }

        # maybe use Data::Compare instead
        for my $condition (qw(fail pass na unknown)) {
            last if $insert_ok;
            if ( ( $tester_results->{$condition} || 0 )
                != $row_from_db->{$condition} )
            {
                $insert_ok = 1;
            }
        }

        next unless ($insert_ok);
        my %tests = map { $_ => $row_from_db->{$_} } qw(fail pass na unknown);
        $self->_bulk->update(
            {
                doc           => { tests => \%tests },
                doc_as_upsert => 1,
                id            => $release_doc->{id},
            }
        );
    }
    $self->_bulk->flush;
    log_info {'done'};
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
