package MetaCPAN::Types::File;
use strict;
use warnings;

use Type::Library -base, -declare => ( qw(
    Module
    Modules
    Stat
) );

use Types::Standard qw(
    ArrayRef
    Dict
    InstanceOf
    Int
    HashRef
);
use Type::Utils qw( as coerce declare from via );    ## no perlimports
use MetaCPAN::Types::Internal qw( ArrayRefFromItem );

declare Module, as InstanceOf ['MetaCPAN::Document::Module'];

coerce Module, from HashRef, via {
    require MetaCPAN::Document::Module;
    MetaCPAN::Document::Module->new($_);
};

declare Modules,
    as( ( ArrayRef [Module] )->plus_coercions(ArrayRefFromItem) ),
    coercion => 1;

declare Stat,
    as Dict [
    mode  => Int,
    size  => Int,
    mtime => Int,
    ];

{

    package MetaCPAN::Types::File::Deflate;
    use MooseX::Attribute::Deflator;

    deflate MetaCPAN::Types::File::Module,
        via { ref $_ eq 'HASH' ? $_ : $_->meta->get_data($_) }, inline_as {
        'ref $value eq "HASH" ? $value : $value->meta->get_data($value)';
        };

    deflate MetaCPAN::Types::File::Modules,
        via { [ map $_->meta->get_data($_), @$_ ] }, inline_as {
        '[ map $_->meta->get_data($_), @$value ]';
        };

    deflate 'ScalarRef', via {$$_};
    inflate 'ScalarRef', via { \$_ };
}

1;
