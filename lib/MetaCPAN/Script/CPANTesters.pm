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
use MetaCPAN::Types qw( Bool );
use Moose;

with 'MetaCPAN::Role::Script', 'MooseX::Getopt::Dashes';

has db => (
    is      => 'ro',
    default => 'http://devel.cpantesters.org/release/release.db.bz2'
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

sub run {
    my $self = shift;
    $self->index_reports;
    $self->index->refresh;
}

sub index_reports {
    my $self = shift;

    my $es    = $self->model->es;
    my $index = $self->index->name;
    my $ua    = LWP::UserAgent->new;
    my $db    = $self->home->file(qw(var tmp cpantesters.db));

    log_info { "Mirroring " . $self->db };

    $ua->mirror( $self->db, "$db.bz2" ) unless $self->skip_download;

    if ( -e $db && stat($db)->mtime >= stat("$db.bz2")->mtime ) {
        log_info {"DB hasn't been modified"};
        return unless $self->skip_download;
    }

    bunzip2 "$db.bz2" => "$db", AutoClose => 1 if -e "$db.bz2";

    my $scroll = $es->scroll_helper(
        index       => $self->index->name,
        search_type => 'scan',
        size        => '500',
    );

    my %releases;
    while ( my $release = $scroll->next ) {
        my $data = $release->{_source};
        $releases{
            join( '-',
                grep {defined} $data->{distribution},
                $data->{version} )
        } = $data;
    }

    log_info { 'Opening database file at ' . $db };

    my $dbh = DBI->connect( 'dbi:SQLite:dbname=' . $db );
    my $sth;
    $sth = $dbh->prepare('SELECT * FROM release');

    $sth->execute;
    my @bulk;
    use DDP;
    while ( my $row_from_db = $sth->fetchrow_hashref ) {
        my $release
            = join( '-', $row_from_db->{dist}, $row_from_db->{version} );
        my $release_doc = $releases{$release};

        # there's a cpantesters dist we haven't indexed
        next unless ($release_doc);

        my $bulk = 0;

        my $tester_results = $release_doc->{tests};
        if ( !$tester_results ) {
            $tester_results = {};
            $bulk           = 1;
        }

        # maybe us Data::Compare instead
        for my $condition (qw(fail pass na unknown)) {
            last if $bulk;
            if ( ( $tester_results->{$condition} || 0 )
                != $row_from_db->{$condition} )
            {
                $bulk = 1;
            }
        }

        next unless ($bulk);
        my %tests = map { $_ => $row_from_db->{$_} } qw(fail pass na unknown);
        p %tests;
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
