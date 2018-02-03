package MetaCPAN::Script::CPANTestersAPI;

use strict;
use warnings;

use Log::Contextual qw( :log :dlog );
use Cpanel::JSON::XS qw( decode_json );
use MetaCPAN::Types qw( Uri );
use Moose;

with 'MetaCPAN::Role::Script', 'MooseX::Getopt::Dashes';

has url => (
    is      => 'ro',
    isa     => Uri,
    coerce  => 1,
    lazy    => 1,
    builder => '_build_url',
);

sub _build_url {
    my ($self) = @_;
    $ENV{HARNESS_ACTIVE}
        ? 'file:'
        . $self->home->file('t/var/cpantesters-release-api-fake.json')
        : 'http://api-3.cpantesters.org/v3/release';
}

has _bulk => (
    is      => 'ro',
    isa     => 'Search::Elasticsearch::Bulk',
    lazy    => 1,
    default => sub {
        $_[0]->es->bulk_helper(
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

    my $es = $self->es;

    log_info { 'Fetching ' . $self->url };
    my $res  = $self->ua->get( $self->url );
    my $json = $res->decoded_content;
    my $data = decode_json $json;

    my $scroll = $es->scroll_helper(
        index       => $self->index->name,
        search_type => 'scan',
        size        => '500',
        type        => 'release',
    );

    # Create a cache of all releases (dist + version combos)
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

    for my $row (@$data) {

        # The testers db seems to return q{} where we would expect
        # a version of 0.
        my $version = $row->{version} || 0;

        # weblint++ gets a name of 'weblint' and a version of '++-1.15'
        # from the testers db.  Special case it for now.  Maybe try and
        # get the db fixed.

        $version =~ s{\+}{}g;
        $version =~ s{\A-}{};

        my $release = join( '-', $row->{dist}, $version );
        my $release_doc = $releases{$release};

        # there's a cpantesters dist we haven't indexed
        next unless $release_doc;

        # Check if we need to update this data
        my $insert_ok      = 0;
        my $tester_results = $release_doc->{tests};
        if ( !$tester_results ) {
            $tester_results = {};
            $insert_ok      = 1;
        }

        # maybe use Data::Compare instead
        for my $condition (qw(fail pass na unknown)) {
            last if $insert_ok;
            if (
                ( $tester_results->{$condition} || 0 ) != $row->{$condition} )
            {
                $insert_ok = 1;
            }
        }

        next unless $insert_ok;

        my %tests = map { $_ => $row->{$_} } qw(fail pass na unknown);
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

1;
