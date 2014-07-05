use strict;
use warnings;

use Test::More;
use Perl::Critic;
use Test::Perl::Critic;

# NOTE: New files will be tested automatically.

# FIXME: Things should be removed from (not added to) this list.
# Temporarily skip any files that existed before adding the tests.
# Eventually these should all be removed (once the files are cleaned up).
my %skip = map { ( $_ => 1 ) } qw(
    bin/build_test_CPAN_dir.pl
    bin/check_json.pl
    bin/convert_authors.pl
    bin/get_fields.pl
    bin/mirror_cpan_for_developers.pl
    bin/unlisted_prereqs.pl
    bin/write_config_json
    lib/Catalyst/Action/Deserialize/MetaCPANSanitizedJSON.pm
    lib/Catalyst/Authentication/Store/Proxy.pm
    lib/Catalyst/Plugin/OAuth2/Provider.pm
    lib/Catalyst/Plugin/Session/Store/ElasticSearch.pm
    lib/MetaCPAN/Document/Distribution.pm
    lib/MetaCPAN/Document/File.pm
    lib/MetaCPAN/Document/Rating.pm
    lib/MetaCPAN/Document/Release.pm
    lib/MetaCPAN/Model.pm
    lib/MetaCPAN/Pod/XHTML.pm
    lib/MetaCPAN/Role/Common.pm
    lib/MetaCPAN/Script/Author.pm
    lib/MetaCPAN/Script/Backup.pm
    lib/MetaCPAN/Script/CPANTesters.pm
    lib/MetaCPAN/Script/Check.pm
    lib/MetaCPAN/Script/First.pm
    lib/MetaCPAN/Script/Latest.pm
    lib/MetaCPAN/Script/Mapping.pm
    lib/MetaCPAN/Script/Pagerank.pm
    lib/MetaCPAN/Script/PerlMongers.pm
    lib/MetaCPAN/Script/Query.pm
    lib/MetaCPAN/Script/ReindexDist.pm
    lib/MetaCPAN/Script/Release.pm
    lib/MetaCPAN/Script/Runner.pm
    lib/MetaCPAN/Script/Tickets.pm
    lib/MetaCPAN/Script/Watcher.pm
    lib/MetaCPAN/Server/Controller.pm
    lib/MetaCPAN/Server/Controller/Changes.pm
    lib/MetaCPAN/Server/Controller/Diff.pm
    lib/MetaCPAN/Server/Controller/File.pm
    lib/MetaCPAN/Server/Controller/Login.pm
    lib/MetaCPAN/Server/Controller/Login/PAUSE.pm
    lib/MetaCPAN/Server/Controller/Login/Twitter.pm
    lib/MetaCPAN/Server/Controller/Root.pm
    lib/MetaCPAN/Server/Controller/Search/Autocomplete.pm
    lib/MetaCPAN/Server/Controller/Source.pm
    lib/MetaCPAN/Server/Controller/User/Favorite.pm
    lib/MetaCPAN/Server/Diff.pm
    lib/MetaCPAN/Server/Model/CPAN.pm
    lib/MetaCPAN/Server/Model/Source.pm
    lib/MetaCPAN/Server/QuerySanitizer.pm
    lib/MetaCPAN/Server/Test.pm
    lib/MetaCPAN/Server/View/JSON.pm
    lib/MetaCPAN/Server/View/Pod.pm
    lib/MetaCPAN/Util.pm
    lib/Plack/Session/Store/ElasticSearch.pm
    t/document/module.t
    t/fakecpan.t
    t/lib/MetaCPAN/Tests/Distribution.pm
    t/lib/MetaCPAN/Tests/Extra.pm
    t/lib/MetaCPAN/Tests/Model.pm
    t/lib/MetaCPAN/Tests/Release.pm
    t/release/moose.t
    t/release/multiple-modules.t
    t/release/pm-PL.t
    t/release/prefer-meta-json.t
    t/server/controller/author.t
    t/server/controller/changes.t
    t/server/controller/diff.t
    t/server/controller/file.t
    t/server/controller/login/pause.t
    t/server/controller/module.t
    t/server/controller/pod.t
    t/server/controller/scroll.t
    t/server/controller/search/reverse_dependencies.t
    t/server/controller/user/favorite.t
    t/server/controller/user/turing.t
    t/server/not_found.t
    t/server/sanitize_query.t
    t/types.t
    t/util.t
);

my @files = grep { !$skip{$_} }
    grep { !m{^t/var/} }
    ( 'app.psgi', Perl::Critic::Utils::all_perl_files(qw( bin lib t )) );

foreach my $file (@files) {
    critic_ok( $file, $file );
}

done_testing();
