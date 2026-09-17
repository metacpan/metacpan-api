use strict;
use warnings;

use Log::Contextual qw( set_logger );
use Log::Log4perl   ();
use Test::More;

# update_author logs via Log::Contextual; give it a quiet logger.
Log::Log4perl->easy_init($Log::Log4perl::FATAL);
set_logger( Log::Log4perl->get_logger );

# When an author manages their profile through metacpan.org, the document
# stores canonical_source => 'ui'. The hourly author import must then leave that
# author alone rather than rebuilding (and reverting) it from whois/author.json.
#
# update_author's only outward dependency is the bulk helper, so we inject a fake
# one and assert on the update calls it receives -- no Elasticsearch needed.
{

    ## no critic (Modules::RequireFilenameMatchesPackage)
    package MetaCPAN::Script::Author::MockConfig;
    use Moose;
    extends 'MetaCPAN::Script::Author';

    has fake_config => ( is => 'ro', default => sub { +{} } );

    sub author_config { $_[0]->fake_config }

    __PACKAGE__->meta->make_immutable;
}
{

    ## no critic (Modules::RequireFilenameMatchesPackage)
    package FakeBulk;
    sub new    { bless { calls => [] }, shift }
    sub update { push @{ $_[0]{calls} }, $_[1] }
    sub calls  { @{ $_[0]{calls} } }
}

my %WHOIS = (
    fullname  => 'Test User',
    asciiname => 'Test User',
    email     => 'test@example.com',
    homepage  => 'https://example.com',
);

sub run_update {
    my ($current_data) = @_;
    my $author = MetaCPAN::Script::Author::MockConfig->new(
        elasticsearch_servers => 'http://localhost:9200',
        level                 => 'fatal',
        logger                => [],
    );
    my $bulk = FakeBulk->new;
    $author->update_author( $bulk, 'TESTUSER', {%WHOIS}, $current_data );
    return ( $author, $bulk );
}

subtest 'canonical_source ui is left untouched' => sub {
    my ( $author, $bulk )
        = run_update( { canonical_source => 'ui', name => 'Hand Edited' } );
    is( scalar( $bulk->calls ),               0, 'no bulk update issued' );
    is( $author->has_surrogate_keys_to_purge, 0, 'nothing queued for purge' );
};

subtest 'new author (no current doc) is rebuilt' => sub {
    my ( $author, $bulk ) = run_update(undef);
    is( scalar( $bulk->calls ), 1, 'one bulk update issued' );
    my ($call) = $bulk->calls;
    is( $call->{id},        'TESTUSER',  'update targets the author' );
    is( $call->{doc}{name}, 'Test User', 'document built from whois' );
};

subtest 'existing author without canonical_source is rebuilt' => sub {
    my ( $author, $bulk ) = run_update( { name => 'Stale' } );
    is( scalar( $bulk->calls ), 1, 'one bulk update issued' );
};

done_testing;
