package MetaCPAN::Model;
use Moose;
use ElasticSearchX::Model;

analyzer lowercase => ( tokenizer => 'keyword', filter => 'lowercase' );
analyzer fulltext => ( type => 'snowball', language => 'English' );

index cpan => ( namespace => 'MetaCPAN::Document' );

__PACKAGE__->meta->make_immutable;

__END__
