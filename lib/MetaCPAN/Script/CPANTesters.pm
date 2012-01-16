package MetaCPAN::Script::CPANTesters;

use Moose;
with 'MooseX::Getopt';
use Log::Contextual qw( :log :dlog );
with 'MetaCPAN::Role::Common';
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);
use File::stat qw(stat);
use LWP::UserAgent ();
use IO::Uncompress::Bunzip2 qw(bunzip2);
use DBI ();

has db => (
    is      => 'ro',
    default => 'http://devel.cpantesters.org/release/release.db.bz2'
);

sub run {
    my $self = shift;
    $self->index_reports;
    $self->index->refresh;
}

sub index_reports {
    my $self  = shift;
    my $es    = $self->model->es;
    my $index = $self->index->name;
    my $ua    = LWP::UserAgent->new;
    my $db    = $self->home->file(qw(var tmp cpantesters.db));
    log_info { "Mirroring " . $self->db };
    $ua->mirror( $self->db, "$db.bz2" );
    if ( -e $db && stat($db)->mtime >= stat("$db.bz2")->mtime ) {
        log_info {"DB hasn't been modified"};
        return;
    }

    bunzip2 "$db.bz2" => "$db", AutoClose => 1;

    my $scroll = $es->scrolled_search(
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
        $releases{ join( "-", $data->{distribution}, $data->{version} ) }
            = $data;
    }

    log_info { "Opening database file at " . $db };
    my $dbh = DBI->connect( "dbi:SQLite:dbname=" . $db );
    my $sth;
    $sth = $dbh->prepare("SELECT * FROM release");

    $sth->execute;
    my @bulk;

    while ( my $data = $sth->fetchrow_hashref ) {
        my $release = join( "-", $data->{dist}, $data->{version} );
        next unless ( $release = $releases{$release} );
        my $bulk = 0;
        for (qw(fail pass na unknown)) {
            $bulk = 1 if ( $data->{$_} != ( $release->{tests}->{$_} || 0 ) );
        }
        next unless ($bulk);
        $release->{tests}
            = { map { $_ => $data->{$_} } qw(fail pass na unknown) };
        push( @bulk, $release );
        $self->bulk( \@bulk ) if ( @bulk > 100 );
    }
    $self->bulk( \@bulk );
    log_info {"done"};
}

sub bulk {
    my ( $self, $bulk ) = @_;
    my @bulk;
    my $index = $self->index->name;
    while ( my $data = shift @$bulk ) {
        push(
            @bulk,
            {   index => {
                    index => $index,
                    id    => $data->{id},
                    type  => 'release',
                    data  => $data
                }
            }
        );
    }
    $self->es->bulk( \@bulk );
}

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
