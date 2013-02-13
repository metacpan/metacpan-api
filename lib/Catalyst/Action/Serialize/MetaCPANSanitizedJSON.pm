package Catalyst::Action::Serialize::MetaCPANSanitizedJSON;

use Moose;
extends 'Catalyst::Action::Serialize::JSON';

__PACKAGE__->meta->make_immutable;

1;
