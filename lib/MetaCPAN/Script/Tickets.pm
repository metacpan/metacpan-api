package MetaCPAN::Script::Tickets;

use Moose;
use Log::Contextual qw( :log :dlog );
use List::MoreUtils qw(uniq);
use List::Util      qw(sum);
use LWP::UserAgent;
use Parse::CSV;
use HTTP::Request::Common;
use IO::String;
use Pithub;
use namespace::autoclean;

with 'MooseX::Getopt', 'MetaCPAN::Role::Common';

has rt_summary_url => (
    is       => 'ro',
    required => 1,
    default  => 'https://rt.cpan.org/Public/bugs-per-dist.tsv',
);

has github_issues => (
    is       => 'ro',
    required => 1,
    default  => 'https://api.github.com/repos/%s/%s/issues?per_page=100',
);

has source => (
    is       => 'ro',
    required => 1,
    isa      => 'ArrayRef[Str]',
    default  => sub { [qw(rt github)] },
);

has ua => (
    is      => 'ro',
    default => sub { LWP::UserAgent->new },
);

has pithub => (
    is => 'ro',
    default => sub { Pithub->new( per_page => 100, auto_pagination => 1 ) },
);

sub run {
    my ($self) = @_;
    my $bugs = {};
    foreach my $source ( @{ $self->source } ) {
        if ( $source eq 'github' ) {
	    log_debug {"Fetching GitHub issues"};
            $bugs = { %$bugs, %{$self->retrieve_github_bugs} };
        }
        elsif ( $source eq 'rt' ) {
	    log_debug {"Fetching RT bugs"};
            $bugs = { %$bugs, %{$self->retrieve_rt_bugs} };
        }
    }
    $self->index_bug_summary($bugs);

    return 1;
}

sub index_bug_summary {
    my ( $self, $bugs ) = @_;
    $self->index->refresh;
    my $dists = $self->index->type('distribution');
    my $bulk = $self->index->bulk( size => 300 );
    for my $dist ( keys %$bugs ) {
        my $doc = $dists->get($dist);
        $doc ||= $dists->new_document( { name => $dist } );
        $doc->bugs( $bugs->{ $doc->name } );
        $bulk->put($doc);
    }
    $bulk->commit;
}


sub retrieve_github_bugs {
    my $self = shift;
    my $scroll
        = $self->index->type('release')->find_github_based->scroll;
    log_debug {sprintf("Found %s repos", $scroll->total)};
    my $summary = {};
    while ( my $release = $scroll->next ) {
        my $resources = $release->resources;
        my ( $user, $repo, $source )
            = $self->github_user_repo_from_resources($resources);
	next unless $user;
        log_debug { "Retrieving issues from $user/$repo" };
        my $open = $self->pithub->issues->list( user => $user, repo => $repo, params => { state => 'open' } );
        next unless($open->success);
        my $closed = $self->pithub->issues->list( user => $user, repo => $repo, params => { state => 'closed' } );
        next unless($closed->success);
        $summary->{$release->{distribution}} = { open => 0, closed => 0, source => $source, type => 'github' };
        $summary->{$release->{distribution}}->{open}++ while($open->next);
        $summary->{$release->{distribution}}->{closed}++ while($closed->next);
    }
    return $summary;
}

sub github_user_repo_from_resources {
    my ( $self, $resources ) = @_;
    my ( $user, $repo, $source );
    while ( my ( $k, $v ) = each %$resources ) {
        if ( !ref $v
            && $v =~ /^(https?|git):\/\/github\.com\/([^\/]+)\/([^\/]+?)(\.git)?\/?$/ )
        {
            return ( $2, $3, $v );
        }
        ( $user, $repo, $source ) = $self->github_user_repo_from_resources($v)
            if ( ref $v eq 'HASH' );
        return ( $user, $repo, $source ) if ($user);
    }
    return ();
}

sub retrieve_rt_bugs {
    my ($self) = @_;

    my $resp = $self->ua->request( GET $self->rt_summary_url );

    log_error { $resp->reason } unless $resp->is_success;

    return $self->parse_tsv( $resp->content );
}

sub parse_tsv {
    my ( $self, $tsv ) = @_;
    $tsv =~ s/^#.*\n//mg;

    my $tsv_parser = Parse::CSV->new(
        handle   => IO::String->new($tsv),
        sep_char => "\t"
    );

    my %summary;
    while ( my $row = $tsv_parser->fetch ) {
        my $i = 1;
        $summary{ $row->[0] } = {
            type   => 'rt',
            source => 'https://rt.cpan.org/Public/Dist/Display.html?Name=' . $row->[0],
            active => ( sum @{$row}[ 1 .. 3 ] ),
            closed => ( sum @{$row}[ 4 .. 5 ] ),
            map { $_ => $row->[ $i++ ] + 0 }
                qw(new open stalled resolved rejected),
        };
    }

    return \%summary;
}

__PACKAGE__->meta->make_immutable;

1;
