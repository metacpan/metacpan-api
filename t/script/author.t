use strict;
use warnings;

use Test::More;

# Subclass to inject author.json config without a CPAN mirror. The method under
# test never touches Elasticsearch, so a dummy connection string suffices.
{

    ## no critic (Modules::RequireFilenameMatchesPackage)
    package MetaCPAN::Script::Author::MockConfig;
    use Moose;
    extends 'MetaCPAN::Script::Author';

    has fake_config => ( is => 'ro', default => sub { +{} } );

    sub author_config { $_[0]->fake_config }

    __PACKAGE__->meta->make_immutable;
}

my %WHOIS = (
    fullname  => 'Test User',
    asciiname => 'Test User',
    email     => 'whois@example.com',
    homepage  => 'https://example.com',
);

sub email_for {
    my ( $pauseid, %config ) = @_;
    my $author = MetaCPAN::Script::Author::MockConfig->new(
        elasticsearch_servers => 'http://localhost:9200',
        level                 => 'fatal',
        logger                => [],
        fake_config           => \%config,
    );
    return $author->author_data_from_cpan( $pauseid, {%WHOIS} )->{email};
}

is_deeply(
    email_for( 'TESTUSER', email => ['author@example.com'] ),
    ['author@example.com'],
    'arrayref email with a valid entry resolves to that address, not @cpan.org',
);

is_deeply(
    email_for(
        'TESTUSER', email => [ 'first@example.com', 'second@example.com' ]
    ),
    [ 'first@example.com', 'second@example.com' ],
    'arrayref email keeps every valid address',
);

is_deeply(
    email_for(
        'TESTUSER', email => [ 'not-an-email', 'author@example.com' ]
    ),
    ['author@example.com'],
    'arrayref email drops invalid entries and keeps the valid ones',
);

is_deeply(
    email_for( 'TESTUSER', email => [ 'nope', 'also-bad' ] ),
    ['testuser@cpan.org'],
    'arrayref email with no valid entry falls back to <pauseid>@cpan.org',
);

is_deeply(
    email_for( 'TESTUSER', email => 'author@example.com' ),
    ['author@example.com'], 'scalar valid email is preserved (as a list)',
);

is_deeply(
    email_for( 'TESTUSER', email => 'not-an-email' ),
    ['testuser@cpan.org'],
    'scalar invalid email falls back to <pauseid>@cpan.org',
);

is_deeply( email_for('TESTUSER'), ['whois@example.com'],
    'with no author.json email, the whois email is used',
);

done_testing;
