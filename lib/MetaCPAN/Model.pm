package MetaCPAN::Model;
use Moose;
use ElasticSearchX::Model;

analyzer lowercase => ( tokenizer => 'keyword', filter => 'lowercase' );
analyzer fulltext => ( type => 'snowball', language => 'English' );
analyzer camelcase => (
    type => 'pattern',
    pattern => "([^\\p{L}\\d]+)|(?<=\\D)(?=\\d)|(?<=\\d)(?=\\D)|(?<=[\\p{L}&&[^\\p{Lu}]])(?=\\p{Lu})|(?<=\\p{Lu})(?=\\p{Lu}[\\p{L}&&[^\\p{Lu}]])"
);

index cpan => ( namespace => 'MetaCPAN::Document', alias_for => 'cpan_v3' );

index user => ( namespace => 'MetaCPAN::Model::User' );

__PACKAGE__->meta->make_immutable;

__END__
