package MetaCPAN::Types::Author;
use strict;
use warnings;

use Type::Library -base, -declare => ( qw(
    Author
    Blog
    Blogs
    PerlMonger
    PerlMongers
    Donation
    Donations
    Profile
    Profiles
) );
use Type::Utils qw( as declare );

use Types::Common::String qw( NonEmptySimpleStr );
use Types::Standard       qw(
    ArrayRef
    Dict
    HashRef
    Optional
    Str
    Value
);
use MetaCPAN::Types::Internal qw( ArrayRefFromItem );

declare PerlMonger,
    as Dict [
    url  => Optional [Str],
    name => NonEmptySimpleStr,
    ];

declare PerlMongers,
    as( ( ArrayRef [PerlMonger] )->plus_coercions(ArrayRefFromItem) ),
    coercion => 1;

declare Profile,
    as Dict [
    name => Str,
    id   => Optional [Str],
    ];

declare Profiles,
    as( ( ArrayRef [Profile] )->plus_coercions(ArrayRefFromItem) ),
    coercion => 1;

declare Donation,
    as Dict [
    name => NonEmptySimpleStr,
    id   => Str,
    ];

declare Donations,
    as( ( ArrayRef [Donation] )->plus_coercions(ArrayRefFromItem) ),
    coercion => 1;

declare Blog,
    as Dict [
    url  => NonEmptySimpleStr,
    feed => Optional [Str],
    ];

declare Blogs, as( ( ArrayRef [Blog] )->plus_coercions(ArrayRefFromItem) ),
    coercion => 1;

1;
