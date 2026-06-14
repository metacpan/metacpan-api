package MetaCPAN::Script::Tickets;

use Moose;
use namespace::autoclean;

use HTTP::Request::Common qw( GET );
use Log::Contextual       qw( :log :dlog );
use MetaCPAN::ESConfig    qw( es_doc_path );
use MetaCPAN::Util        qw( true false );
use MetaCPAN::Types       qw( Uri );
use Net::GitHub::V4       ();
use Ref::Util             qw( is_hashref is_ref );
use Text::CSV_XS          ();
use URI::Escape           qw( uri_escape );

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has rt_summary_url => (
    is       => 'ro',
    isa      => Uri,
    coerce   => 1,
    required => 1,
    default  => 'https://rt.cpan.org/Public/bugs-per-dist.tsv',
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
    $self->es->bulk_helper( es_doc_path('distribution') );
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
        scroll => '5m',
        es_doc_path('release'),
        body => {
            query => {
                bool =>
                    { must_not => [ { term => { status => 'backpan' } } ] }
            },
            size    => 500,
            _source => ['distribution'],
        },
    );

    my $dists = {};

    while ( my $release = $scroll->next ) {
        my $distribution = $release->{_source}{'distribution'};
        $distribution or next;
        $dists->{$distribution} = { name => $distribution };
    }

    $self->_bulk_update($dists);
}

# GitHub data is fetched for any dist that points at GitHub in its bugtracker
# or repository resources. Issue counts are only recorded when GitHub issues
# are the bug tracker, but star/watcher counts are recorded for any dist with a
# GitHub repository (see _github_dist_summary).
sub index_github_bugs {
    my $self = shift;

    log_debug {'Fetching GitHub issues'};

    my $scroll = $self->es->scroll_helper(
        scroll => '5m',
        es_doc_path('release'),
        body => {
            query => {
                bool => {
                    must => [
                        { term => { status => 'latest' } },
                        {
                            bool => {
                                should => $self->_github_release_query_filter,
                            },
                        },
                    ],
                },
            },
            sort => ['_doc'],
        },
    );

    log_debug { sprintf( "Found %s repos", $scroll->total ) };

    my %summary;

RELEASE: while ( my $release = $scroll->next ) {
        my $resources = $release->{resources};
        my ( $user, $repo )
            = $self->github_user_repo_from_resources($resources);
        next unless $user;
        log_debug {"Retrieving issues from $user/$repo"};

        my $dist_summary = $summary{ $release->{'distribution'} } ||= {};

        my $vars = {
            user => $user,
            repo => $repo,
        };
        my $data = $self->github_graphql->query( <<'END_QUERY', $vars );
            query($user:String!, $repo:String!) {
                repository(owner: $user, name: $repo) {
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
                    watchers: watchers {
                        totalCount
                    }
                    stargazerCount: stargazerCount
                }
            }
END_QUERY

        if ( my $error = $data->{errors} ) {
            for my $error (@$error) {
                my $log_message
                    = "[$release->{distribution}] $error->{message}";
                if ( $error->{type} eq 'NOT_FOUND' ) {
                    delete $dist_summary->{'bugs'}{'github'};
                    delete $dist_summary->{'repo'}{'github'};
                    log_info {$log_message};
                }
                else {
                    log_error {$log_message};
                }
            }
            if (@$error) {
                next RELEASE;
            }
        }

        my $repo_data = $data->{data}{repository};
        my $github    = $self->_github_dist_summary( $resources, $repo_data );

        $dist_summary->{'repo'}{'github'} = $github->{repo}{github};
        $dist_summary->{'bugs'}{'github'} = $github->{bugs}{github}
            if $github->{bugs};
    }

    log_info {"writing github data"};
    $self->_bulk_update( \%summary );
}

# Resource fields that may contain a GitHub URL. A dist that points at GitHub
# in any of these is eligible for star/watcher counts.
sub _github_resource_fields {
    return qw(
        resources.bugtracker.web
        resources.repository.url
        resources.repository.web
    );
}

sub _github_url_prefixes {
    return qw(
        http://github.com/
        https://github.com/
        git://github.com/
    );
}

# Build the `should` clauses matching any release with a GitHub URL in one of
# the relevant resource fields.
sub _github_release_query_filter {
    my $self = shift;
    return [
        map {
            my $field = $_;
            map +{ prefix => { $field => $_ } }, $self->_github_url_prefixes;
        } $self->_github_resource_fields
    ];
}

sub _is_github_url {
    my ( $self, $url ) = @_;
    return !is_ref($url) && $url && $url =~ m{^(?:https?|git)://github\.com/};
}

# Given a release's resources and the GraphQL repository data, build the
# distribution summary fragment. Star/watcher counts are recorded for any dist
# with a GitHub repository; issue counts are only recorded when GitHub issues
# are the dist's bug tracker.
sub _github_dist_summary {
    my ( $self, $resources, $repo_data ) = @_;

    my %summary = (
        repo => {
            github => {
                stars    => $repo_data->{stargazerCount},
                watchers => $repo_data->{watchers}{totalCount},
            },
        },
    );

    my $bugtracker
        = is_hashref( $resources->{bugtracker} )
        ? $resources->{bugtracker}{web}
        : undef;

    if ( $bugtracker && $self->_is_github_url($bugtracker) ) {
        my $open
            = $repo_data->{openIssues}{totalCount}
            + $repo_data->{openPullRequests}{totalCount};
        my $closed
            = $repo_data->{closedIssues}{totalCount}
            + $repo_data->{closedPullRequests}{totalCount};

        $summary{bugs}{github} = {
            active => $open,
            open   => $open,
            closed => $closed,
            source => $bugtracker,
        };
    }

    return \%summary;
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
        next
            if !$row->{dist};
        $summary{ $row->{dist} }{'bugs'}{'rt'} = {
            source => $self->rt_dist_url( $row->{dist} ),
            active => $row->{active} + 0,
            closed => $row->{inactive} + 0,
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
            doc_as_upsert => true,
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
