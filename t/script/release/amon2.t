use Test::Most;
use warnings;
use strict;
use lib qw(t/lib);
use TestLib;
use MetaCPAN::Script::Release;
use MetaCPAN::Model;

my $script;
my $es = TestLib->connect;
warn $es;
#$test->wait_for_es();
my $model = MetaCPAN::Model->new( es => $es );

ok($model->deploy, "deploy");

lives_ok {
    local @ARGV =
      ( 'release', 'var/tmp/http/authors/id/T/TO/TOKUHIROM/Amon2-2.26.tar.gz' );
    $script =
      MetaCPAN::Script::Release->new_with_options(
                          level  => 'info',
                          port => 5000,
                          logger => [
                              { class => 'Log::Log4perl::Appender::Screen',
                                name  => 'mybuffer',
                              }
                          ],
                          es => $es );
    $script->run;
};

{
    use Devel::Dwarn; DwarnN($model->index('cpan')->type('release')->all);
}



done_testing;
