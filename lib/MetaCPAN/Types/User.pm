package MetaCPAN::Types::User;
use strict;
use warnings;

use Type::Library -base, -declare => ( qw(
    AccessToken
    AccessTokens
    Identity
    Identities
) );

use Types::Standard qw(
    ArrayRef
    Dict
    HashRef
    Optional
    Str
);
use Type::Utils               qw( as declare );
use MetaCPAN::Types::Internal qw( ArrayRefFromItem );

declare Identity,
    as Dict [
    name  => Str,
    key   => Optional [Str],
    extra => Optional [HashRef],
    ];

declare Identities,
    as( ( ArrayRef [Identity] )->plus_coercions(ArrayRefFromItem) ),
    coercion => 1;

declare AccessToken,
    as Dict [
    token  => Str,
    client => Str,
    ];

declare AccessTokens,
    as( ( ArrayRef [AccessToken] )->plus_coercions(ArrayRefFromItem) ),
    coercion => 1;

1;
