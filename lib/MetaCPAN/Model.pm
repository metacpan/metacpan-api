package MetaCPAN::Model;
use Moose;
use ElasticSearchX::Model;

analyzer lowercase => ( tokenizer => 'keyword', filter => 'lowercase' );
analyzer fulltext => ( type => 'snowball', language => 'English' );
analyzer camelcase => ( type => 'pattern', pattern => "(\\W+)|(?<=[^\\p{Lu}])(?=\\p{Lu})|(?<=\\p{Lu})(?=\\p{Lu}[^\\p{Lu}])" );

index cpan => ( namespace => 'MetaCPAN::Document', alias_for => 'cpan_v3' );

index user => ( namespace => 'MetaCPAN::Model::User' );

__PACKAGE__->meta->make_immutable;

__END__
