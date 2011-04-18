package MetaCPAN::Model::User::Account;
use Moose;
use ElasticSearchX::Model::Document;
use Gravatar::URL ();
use MetaCPAN::Util;

has session => ();

__PACKAGE__->meta->make_immutable;
