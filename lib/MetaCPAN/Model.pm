package MetaCPAN::Model;

# load order important
use Moose;

use ElasticSearchX::Model;

analyzer lowercase => (
    tokenizer => 'keyword',
    filter    => 'lowercase',
);

analyzer fulltext => ( type => 'english' );

tokenizer camelcase => (
    type    => 'pattern',
    pattern =>
        "([^\\p{L}\\d]+)|(?<=\\D)(?=\\d)|(?<=\\d)(?=\\D)|(?<=[\\p{L}&&[^\\p{Lu}]])(?=\\p{Lu})|(?<=\\p{Lu})(?=\\p{Lu}[\\p{L}&&[^\\p{Lu}]])"
);

filter edge => (
    type     => 'edge_ngram',
    min_gram => 1,
    max_gram => 20
);

analyzer camelcase => (
    type      => 'custom',
    tokenizer => 'camelcase',
    filter    => [ 'lowercase', 'unique' ]
);

analyzer edge_camelcase => (
    type      => 'custom',
    tokenizer => 'camelcase',
    filter    => [ 'lowercase', 'edge' ]
);

analyzer edge => (
    type      => 'custom',
    tokenizer => 'standard',
    filter    => [ 'lowercase', 'edge' ]
);

index cpan => (
    namespace => 'MetaCPAN::Document',
    alias_for => 'cpan_v1_01',
    shards    => 3
);

index user => ( namespace => 'MetaCPAN::Model::User' );

__PACKAGE__->meta->make_immutable;
1;

__END__
