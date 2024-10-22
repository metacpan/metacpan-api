package MetaCPAN::Model;

# load order important
use Moose;

use ElasticSearchX::Model;

index cpan => (
    namespace => 'MetaCPAN::Document',
    alias_for => 'cpan_v1_01',
    shards    => 3
);

index user => ( namespace => 'MetaCPAN::Model::User' );

__PACKAGE__->meta->make_immutable;
1;

__END__
