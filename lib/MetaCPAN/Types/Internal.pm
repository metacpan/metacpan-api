package MetaCPAN::Types::Internal;

use strict;
use warnings;

use CPAN::Meta;
use ElasticSearchX::Model::Document::Types qw(Type);
use MooseX::Getopt::OptionTypeMap;
use MooseX::Types::Moose qw( ArrayRef HashRef );

use MooseX::Types -declare => [
    qw(
        Module
        Identity
        Dependency
        Profile
    )
];

subtype Module, as ArrayRef [ Type ['MetaCPAN::Document::Module'] ];
coerce Module, from ArrayRef, via {
    [ map { ref $_ eq 'HASH' ? MetaCPAN::Document::Module->new($_) : $_ }
            @$_ ];
};
coerce Module, from HashRef, via { [ MetaCPAN::Document::Module->new($_) ] };

subtype Identity, as ArrayRef [ Type ['MetaCPAN::Model::User::Identity'] ];
coerce Identity, from ArrayRef, via {
    [
        map {
            ref $_ eq 'HASH'
                ? MetaCPAN::Model::User::Identity->new($_)
                : $_
        } @$_
    ];
};
coerce Identity, from HashRef,
    via { [ MetaCPAN::Model::User::Identity->new($_) ] };

subtype Dependency, as ArrayRef [ Type ['MetaCPAN::Document::Dependency'] ];
coerce Dependency, from ArrayRef, via {
    [
        map {
            ref $_ eq 'HASH'
                ? MetaCPAN::Document::Dependency->new($_)
                : $_
        } @$_
    ];
};
coerce Dependency, from HashRef,
    via { [ MetaCPAN::Document::Dependency->new($_) ] };

subtype Profile, as ArrayRef [ Type ['MetaCPAN::Document::Author::Profile'] ];
coerce Profile, from ArrayRef, via {
    [
        map {
            ref $_ eq 'HASH'
                ? MetaCPAN::Document::Author::Profile->new($_)
                : $_
        } @$_
    ];
};
coerce Profile, from HashRef,
    via { [ MetaCPAN::Document::Author::Profile->new($_) ] };

MooseX::Getopt::OptionTypeMap->add_option_type_to_map(
    'MooseX::Types::ElasticSearch::ES' => '=s' );

use MooseX::Attribute::Deflator;
deflate 'ScalarRef', via {$$_};
inflate 'ScalarRef', via { \$_ };

no MooseX::Attribute::Deflator;

1;
