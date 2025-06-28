package MetaCPAN::Types::Internal;

use strict;
use warnings;

use ElasticSearchX::Model::Document::Mapping ();
use ElasticSearchX::Model::Document::Types   qw( Type );
use MetaCPAN::Util                           qw( is_bool true false );
use MooseX::Getopt::OptionTypeMap            ();
use MooseX::Types::Moose                     qw( ArrayRef Bool HashRef Item );

use MooseX::Types -declare => [ qw(
    ESBool
    Module
    Identity
    Dependency
    Profile
) ];

subtype Module, as ArrayRef [ Type ['MetaCPAN::Document::Module'] ];
coerce Module, from ArrayRef, via {
    require MetaCPAN::Document::Module;
    [ map { ref $_ eq 'HASH' ? MetaCPAN::Document::Module->new($_) : $_ }
            @$_ ];
};
coerce Module, from HashRef, via {
    require MetaCPAN::Document::Module;    ## no perlimports
    [ MetaCPAN::Document::Module->new($_) ];
};

subtype Identity, as ArrayRef [ Type ['MetaCPAN::Model::User::Identity'] ];
coerce Identity, from ArrayRef, via {
    require MetaCPAN::Model::User::Identity;
    [
        map {
            ref $_ eq 'HASH'
                ? MetaCPAN::Model::User::Identity->new($_)
                : $_
        } @$_
    ];
};
coerce Identity, from HashRef, via {
    require MetaCPAN::Model::User::Identity;    ## no perlimports
    [ MetaCPAN::Model::User::Identity->new($_) ];
};

subtype Dependency, as ArrayRef [ Type ['MetaCPAN::Document::Dependency'] ];
coerce Dependency, from ArrayRef, via {
    require MetaCPAN::Document::Dependency;
    [
        map {
            ref $_ eq 'HASH'
                ? MetaCPAN::Document::Dependency->new($_)
                : $_
        } @$_
    ];
};
coerce Dependency, from HashRef, via {
    require MetaCPAN::Document::Dependency;    ## no perlimports
    [ MetaCPAN::Document::Dependency->new($_) ];
};

subtype Profile, as ArrayRef [ Type ['MetaCPAN::Document::Author::Profile'] ];
coerce Profile, from ArrayRef, via {
    require MetaCPAN::Document::Author::Profile;
    [
        map {
            ref $_ eq 'HASH'
                ? MetaCPAN::Document::Author::Profile->new($_)
                : $_
        } @$_
    ];
};
coerce Profile, from HashRef, via {
    ## no perlimports
    require MetaCPAN::Document::Author::Profile;
    ## use perlimports
    [ MetaCPAN::Document::Author::Profile->new($_) ];
};

MooseX::Getopt::OptionTypeMap->add_option_type_to_map(
    'MooseX::Types::ElasticSearch::ES' => '=s' );

subtype ESBool, as Item, where { is_bool($_) };
coerce ESBool, from Bool, via {
    $_ ? true : false
};

$ElasticSearchX::Model::Document::Mapping::MAPPING{ESBool}
    = $ElasticSearchX::Model::Document::Mapping::MAPPING{Bool};

use MooseX::Attribute::Deflator;
deflate 'ScalarRef', via {$$_};
inflate 'ScalarRef', via { \$_ };

no MooseX::Attribute::Deflator;

1;
