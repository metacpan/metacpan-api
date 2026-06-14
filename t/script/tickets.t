use strict;
use warnings;
use lib 't/lib';

use Test::More;

## no perlimports (loaded for its methods, referenced by name below)
use MetaCPAN::Script::Tickets ();
## use perlimports

# These helpers are pure (they don't touch instance state), so we can exercise
# them as class methods without standing up a full Script object / ES. This is
# deliberately fragile: if any of these methods grows a dependency on a Moose
# attribute, these class-method calls will start failing and the test should be
# converted to use a constructed object.
my $class = 'MetaCPAN::Script::Tickets';

subtest '_is_github_url' => sub {
    ok $class->_is_github_url('https://github.com/foo/bar'),   'https';
    ok $class->_is_github_url('http://github.com/foo/bar'),    'http';
    ok $class->_is_github_url('git://github.com/foo/bar.git'), 'git';
    ok $class->_is_github_url('https://GitHub.com/foo/bar'),
        'host is case-insensitive';
    ok !$class->_is_github_url('https://rt.cpan.org/Public/x'),
        'rt is not github';
    ok !$class->_is_github_url('https://gitlab.com/foo/bar'),
        'gitlab is not github';
    ok !$class->_is_github_url('https://github.com.evil.com/x'),
        'look-alike host rejected';
    ok !$class->_is_github_url('https://www.github.com/foo'),
        'subdomain is not github.com';
    ok !$class->_is_github_url(undef),            'undef';
    ok !$class->_is_github_url(''),               'empty string';
    ok !$class->_is_github_url( { web => 'x' } ), 'ref is not a url';
};

subtest 'query filter covers repository as well as bugtracker' => sub {
    my $filter = $class->_github_release_query_filter;

    my %fields;
    my %prefixes;
    for my $clause (@$filter) {
        my ($field) = keys %{ $clause->{prefix} };
        $fields{$field}++;
        $prefixes{ $clause->{prefix}{$field} }++;
    }

    # The fix: star counts must be fetched for dists whose repository is on
    # GitHub even when their bug tracker is not, so the query must match the
    # repository resource fields, not just the bugtracker.
    ok $fields{'resources.bugtracker.web'}, 'matches bugtracker.web';
    ok $fields{'resources.repository.url'}, 'matches repository.url';
    ok $fields{'resources.repository.web'}, 'matches repository.web';

    # Bug trackers are http(s) only; repository URLs may also be git://.
    is $fields{'resources.bugtracker.web'}, 2,
        'bugtracker matched on http(s)';
    is $fields{'resources.repository.url'}, 3,
        'repository also matched on git://';

    ok $prefixes{'https://github.com/'}, 'matches https github prefix';
    ok $prefixes{'git://github.com/'},   'matches git github prefix';
};

my $repo_data = {
    openIssues         => { totalCount => 3 },
    closedIssues       => { totalCount => 5 },
    openPullRequests   => { totalCount => 2 },
    closedPullRequests => { totalCount => 4 },
    watchers           => { totalCount => 10 },
    stargazerCount     => 42,
};

subtest 'github bugtracker: stars and issue counts recorded' => sub {
    my $resources = {
        bugtracker => { web => 'https://github.com/foo/bar/issues' },
        repository => { web => 'https://github.com/foo/bar' },
    };

    my $summary = $class->_github_dist_summary( $resources, $repo_data );

    is_deeply $summary->{repo}{github}, { stars => 42, watchers => 10 },
        'stars and watchers recorded';

    is_deeply $summary->{bugs}{github}, {
        active => 5,    # 3 open issues + 2 open PRs
        open   => 5,
        closed => 9,    # 5 closed issues + 4 closed/merged PRs
        source => 'https://github.com/foo/bar/issues',
        },
        'issue counts recorded with bugtracker as source';
};

subtest 'RT bugtracker + github repo: stars recorded, no github issues' =>
    sub {
    my $resources = {
        bugtracker => {
            web => 'https://rt.cpan.org/Public/Dist/Display.html?Name=Foo-Bar'
        },
        repository => {
            url => 'git://github.com/foo/bar.git',
            web => 'https://github.com/foo/bar',
        },
    };

    my $summary = $class->_github_dist_summary( $resources, $repo_data );

    is_deeply $summary->{repo}{github}, { stars => 42, watchers => 10 },
        'stars and watchers recorded even though bug tracker is RT';

    ok !exists $summary->{bugs},
        'no github issue counts when GitHub is not the bug tracker';
    };

subtest 'no bugtracker: stars recorded, no github issues' => sub {
    my $resources = { repository => { web => 'https://github.com/foo/bar' } };

    my $summary = $class->_github_dist_summary( $resources, $repo_data );

    is_deeply $summary->{repo}{github}, { stars => 42, watchers => 10 },
        'stars and watchers recorded';
    ok !exists $summary->{bugs},
        'no github issue counts without a bug tracker';
};

done_testing();
