use strict;
use warnings;

use MetaCPAN::Types::TypeTiny qw( Resources );
use Test::More;

is_deeply(
    Resources->coerce( {
        license    => ['http://dev.perl.org/licenses/'],
        homepage   => 'http://sourceforge.net/projects/module-build',
        bugtracker => {
            web    => 'http://github.com/dagolden/cpan-meta-spec/issues',
            mailto => 'meta-bugs@example.com',
        },
        repository => {
            url  => 'git://github.com/dagolden/cpan-meta-spec.git',
            web  => 'http://github.com/dagolden/cpan-meta-spec',
            type => 'git',
        },
        x_twitter => 'http://twitter.com/cpan_linked/',
    } ),
    {
        license    => ['http://dev.perl.org/licenses/'],
        homepage   => 'http://sourceforge.net/projects/module-build',
        bugtracker => {
            web    => 'http://github.com/dagolden/cpan-meta-spec/issues',
            mailto => 'meta-bugs@example.com',
        },
        repository => {
            url  => 'git://github.com/dagolden/cpan-meta-spec.git',
            web  => 'http://github.com/dagolden/cpan-meta-spec',
            type => 'git',
        }
    },
    'coerce CPAN::Meta::Spec example'
);

ok(
    Resources->check( Resources->coerce( {
        license    => ['http://dev.perl.org/licenses/'],
        homepage   => 'http://sourceforge.net/projects/module-build',
        bugtracker => {
            web    => 'http://github.com/dagolden/cpan-meta-spec/issues',
            mailto => 'meta-bugs@example.com',
        },
        repository => {
            url  => 'git://github.com/dagolden/cpan-meta-spec.git',
            web  => 'http://github.com/dagolden/cpan-meta-spec',
            type => 'git',
        },
        x_twitter => 'http://twitter.com/cpan_linked/',
    } ) ),
    'check CPAN::Meta::Spec example'
);

is_deeply(
    Resources->coerce( {
        license  => ['http://dev.perl.org/licenses/'],
        homepage => 'http://sourceforge.net/projects/module-build',
    } ),
    {
        homepage => 'http://sourceforge.net/projects/module-build',
        license  => ['http://dev.perl.org/licenses/'],
    },
    'coerce sparse resources'
);

ok(
    Resources->check( {
        license  => ['http://dev.perl.org/licenses/'],
        homepage => 'http://sourceforge.net/projects/module-build',
    } ),
    'check sparse resources'
);

ok(
    Resources->check( {
        bugtracker => {
            web =>
                'https://github.com/AlexBio/Dist-Zilla-Plugin-GitHub/issues'
        },
        homepage   => 'http://search.cpan.org/dist/Dist-Zilla-Plugin-GitHub/',
        repository => {
            type => 'git',
            url  => 'git://github.com/AlexBio/Dist-Zilla-Plugin-GitHub.git',
            web  => 'https://github.com/AlexBio/Dist-Zilla-Plugin-GitHub'
        }
    } ),
    'sparse'
);

done_testing;
