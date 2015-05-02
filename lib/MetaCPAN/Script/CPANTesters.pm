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

has force_refresh => (
    is  => 'ro',
    isa => Bool,
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

    $ua->mirror( $self->db, "$db.bz2" );

    if ( -e $db && stat($db)->mtime >= stat("$db.bz2")->mtime ) {
        log_info {"DB hasn't been modified"};
        return unless $self->force_refresh;
    }

    bunzip2 "$db.bz2" => "$db", AutoClose => 1;

    my $scroll = $self->index->type('release')->size(500)->raw->scroll;

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

    while ( my $data = $sth->fetchrow_hashref ) {
        my $release = join( '-', $data->{dist}, $data->{version} );
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
    log_info {'done'};
}

sub bulk {
    my ( $self, $bulk ) = @_;
    my $index = $self->index->name;
    while ( my $data = shift @$bulk ) {
        $bulk->add(
            {
                index => {
                    index => $index,
                    id    => $data->{id},
                    type  => 'release',
                    body  => $data
                }
            }
        );
    }

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
