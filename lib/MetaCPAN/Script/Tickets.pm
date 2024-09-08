package MetaCPAN::Script::Tickets;

use Moose;
use namespace::autoclean;

# Some issue with rt.cpan.org's cert
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

use HTTP::Request::Common qw( GET );
use Log::Contextual       qw( :log :dlog );
use Net::GitHub::V4       ();
use Ref::Util             qw( is_hashref is_ref );
use Text::CSV_XS          ();
use URI::Escape           qw( uri_escape );

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

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

has github_token => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_github_token',
);

has github_graphql => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_github_graphql',
);

has _bulk => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_bulk',
);

sub _build_bulk {
    my $self = shift;
    $self->es->bulk_helper(
        index => $self->index->name,
        type  => 'distribution',
    );
}

sub _build_github_token {
    my $self = shift;
    $self->config->{github_token};
}

sub _build_github_graphql {
    my $self = shift;
    return Net::GitHub::V4->new(
        (
            $self->github_token ? ( access_token => $self->github_token ) : ()
        ),
    );
}

sub run {
    my $self = shift;

    $self->check_all_distributions;
    $self->index_rt_bugs;
    $self->index_github_bugs;

    return 1;
}

sub check_all_distributions {
    my $self = shift;

    # first: make sure all distributions have an entry
    my $scroll = $self->es->scroll_helper(
        size   => 500,
        scroll => '5m',
        index  => $self->index->name,
        type   => 'release',
        fields => ['distribution'],
        body   => {
            query => {
                not => { term => { status => 'backpan' } }
            }
        },
    );

    my $dists = {};

    while ( my $release = $scroll->next ) {
        my $distribution = $release->{'fields'}{'distribution'}[0];
        $distribution or next;
        $dists->{$distribution} = { name => $distribution };
    }

    $self->_bulk_update($dists);
}

# gh issues are counted for any dist with a github url in `resources.bugtracker.web`.
sub index_github_bugs {
    my $self = shift;

    log_debug {'Fetching GitHub issues'};

    my $scroll
        = $self->index->type('release')->find_github_based->scroll('5m');
    log_debug { sprintf( "Found %s repos", $scroll->total ) };

    my %summary;

    my $json = JSON::MaybeXS->new( allow_nonref => 1 );

RELEASE: while ( my $release = $scroll->next ) {
        my $resources = $release->resources;
        my ( $user, $repo, $source )
            = $self->github_user_repo_from_resources($resources);
        next unless $user;
        log_debug {"Retrieving issues from $user/$repo"};

        my $data = $self->github_graphql->query(
            sprintf <<'END_QUERY', map $json->encode($_), $user, $repo );
                query {
                    repository(owner: %s, name: %s) {
                        openIssues: issues(states: OPEN) {
                            totalCount
                        }
                        closedIssues: issues(states: CLOSED) {
                            totalCount
                        }
                        openPullRequests: pullRequests(states: OPEN) {
                            totalCount
                        }
                        closedPullRequests: pullRequests(states: [CLOSED, MERGED]) {
                            totalCount
                        }
                    }
                }
END_QUERY

        if ( my $error = $data->{errors} ) {
            for my $error (@$error) {
                my $log_message
                    = "[$release->{distribution}] $error->{message}";
                if ( $error->{type} eq 'NOT_FOUND' ) {
                    delete $summary{ $release->{'distribution'} }{'bugs'}
                        {'github'};
                    log_info {$log_message};
                }
                else {
                    log_error {$log_message};
                }
                next RELEASE;
            }
        }

        my $open
            = $data->{data}{repository}{openIssues}{totalCount}
            + $data->{data}{repository}{openPullRequests}{totalCount};
        my $closed
            = $data->{data}{repository}{closedIssues}{totalCount}
            + $data->{data}{repository}{closedPullRequests}{totalCount};

        my $rec = {
            active => $open,
            open   => $open,
            closed => $closed,
            source => $source,
        };

        $summary{ $release->{'distribution'} }{'bugs'}{'github'} = $rec;
    }

    log_info {"writing github data"};
    $self->_bulk_update( \%summary );
}

# Try (recursively) to find a github url in the resources hash.
# FIXME: This should check bugtracker web exclusively, or at least first.
sub github_user_repo_from_resources {
    my ( $self, $resources ) = @_;
    my ( $user, $repo, $source );

    for my $k ( keys %{$resources} ) {
        my $v = $resources->{$k};

        if ( !is_ref($v)
            && $v
            =~ /^(https?|git):\/\/github\.com\/([^\/]+)\/([^\/]+?)(\.git)?\/?$/
            )
        {
            return ( $2, $3, $v );
        }

        ( $user, $repo, $source ) = $self->github_user_repo_from_resources($v)
            if is_hashref($v);

        return ( $user, $repo, $source ) if $user;
    }

    return ();
}

# rt issues are counted for all dists (the download tsv contains everything).
sub index_rt_bugs {
    my $self = shift;

    log_debug {'Fetching RT bugs'};

    my $resp = $self->ua->request( GET $self->rt_summary_url );

    log_error { $resp->status_line } unless $resp->is_success;

    # NOTE: This is sending a byte string.
    my $summary = $self->parse_tsv( $resp->content );

    log_info {"writing rt data"};
    $self->_bulk_update($summary);
}

sub parse_tsv {
    my ( $self, $tsv ) = @_;
    $tsv
        =~ s/^#\s*(dist\s.+)/$1/m; # uncomment the field spec for Text::CSV_XS
    $tsv =~ s/^#.*\n//mg;

    open my $fh, '<', \$tsv;

    # NOTE: This is byte-oriented.
    my $tsv_parser = Text::CSV_XS->new( {
        sep_char => "\t",
    } );
    $tsv_parser->header($fh);

    my %summary;
    while ( my $row = $tsv_parser->getline_hr($fh) ) {
        $summary{ $row->{dist} }{'bugs'}{'rt'} = {
            source => $self->rt_dist_url( $row->{dist} ),
            active => $row->{active},
            closed => $row->{inactive},
            map { $_ => $row->{$_} + 0 }
                grep { not /^(dist|active|inactive)$/ }
                keys %$row,
        };
    }

    return \%summary;
}

sub rt_dist_url {
    my ( $self, $dist ) = @_;
    return 'https://rt.cpan.org/Public/Dist/Display.html?Name='
        . uri_escape($dist);
}

sub _bulk_update {
    my ( $self, $summary ) = @_;

    for my $distribution ( keys %$summary ) {
        $self->_bulk->update( {
            id            => $distribution,
            doc           => $summary->{$distribution},
            doc_as_upsert => 1,
        } );
    }

    $self->_bulk->flush;
}

__PACKAGE__->meta->make_immutable;

1;

=pod

=head1 SYNOPSIS

 # bin/metacpan tickets

=head1 DESCRIPTION

Tracks the number of issues and the source, if the issue
tracker is RT or Github it fetches the info and updates
out ES information.

This can then be accessed here:

http://fastapi.metacpan.org/v1/distribution/Moose
http://fastapi.metacpan.org/v1/distribution/HTTP-BrowserDetect

=cut

