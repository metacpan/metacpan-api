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
    lib/Catalyst/Plugin/Session/Store/ElasticSearch.pm
    lib/MetaCPAN/Document/File.pm
    lib/MetaCPAN/Script/Author.pm
    lib/MetaCPAN/Script/Release.pm
    lib/MetaCPAN/Script/Watcher.pm
    lib/MetaCPAN/Server/Controller/Login.pm
    lib/MetaCPAN/Server/Model/CPAN.pm
    lib/MetaCPAN/Server/Model/Source.pm
    lib/MetaCPAN/Server/View/JSON.pm
    lib/MetaCPAN/Util.pm
    lib/Plack/Session/Store/ElasticSearch.pm
);

my @files = grep { !$skip{$_} }
    grep { !m{^t/var/} }
    ( 'app.psgi', Perl::Critic::Utils::all_perl_files(qw( bin lib t )) );

foreach my $file (@files) {
    critic_ok( $file, $file );
}

done_testing();
