package MetaCPAN::Types::Release;
use strict;
use warnings;

use Type::Library -base, -declare => ( qw(
    Dependency
    Dependencies
    Resources

    HashRefCPANMeta
) );

use Types::Standard qw(
    ArrayRef
    Dict
    HashRef
    InstanceOf
    Optional
    Str
);
use Type::Utils               qw( as coerce declare from via );
use MetaCPAN::Types::Internal qw( ArrayRefFromItem );

declare Dependency,
    as Dict [
    phase        => Str,
    relationship => Str,
    module       => Str,
    version      => Str,
    ];

declare Dependencies,
    as( ( ArrayRef [Dependency] )->plus_coercions(ArrayRefFromItem) ),
    coercion => 1;

declare Resources,
    as Dict [
    license    => Optional [ ArrayRef [Str] ],
    homepage   => Optional [Str],
    bugtracker => Optional [
        Dict [
            web    => Optional [Str],
            mailto => Optional [Str],
        ]
    ],
    repository => Optional [
        Dict [
            url  => Optional [Str],
            web  => Optional [Str],
            type => Optional [Str]
        ]
    ],
    ];

coerce Resources, from HashRef, via {
    my $r         = $_;
    my $resources = {};
    for my $field (qw(license homepage bugtracker repository)) {
        my $val = $r->{$field};
        if ( !defined $val ) {
            next;
        }
        elsif ( !ref $val ) {
        }
        elsif ( ref $val eq 'HASH' ) {
            $val = {%$val};
            delete @{$val}{ grep /^x_/, keys %$val };
        }
        $resources->{$field} = $val;
    }
    return $resources;
};

declare HashRefCPANMeta, as HashRef;
coerce HashRefCPANMeta, from InstanceOf ['CPAN::Meta'], via {
    my $struct = eval { $_->as_struct( { version => 2 } ); };
    return $struct ? $struct : $_->as_struct;
};

1;
