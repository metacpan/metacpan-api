package MetaCPAN::Types::Internal;

use strict;
use warnings;

use CPAN::Meta;
use ElasticSearchX::Model::Document::Types qw(:all);
use JSON;
use MooseX::Getopt::OptionTypeMap;
use MooseX::Types::Common::String qw(NonEmptySimpleStr);
use MooseX::Types::Moose qw( ArrayRef Bool HashRef Item Int Num Str Undef );
use MooseX::Types::Structured qw(Dict Tuple Optional);

use MooseX::Types -declare => [
    qw(
        Logger
        Resources
        Stat
        Module
        AssociatedPod
        Identity
        Dependency
        Extra

        Profile
        Blog
        PerlMongers
        Tests
        BugSummary
        )
];

subtype PerlMongers,
    as ArrayRef [ Dict [ url => Optional [Str], name => NonEmptySimpleStr ] ];
coerce PerlMongers, from HashRef, via { [$_] };

subtype Blog, as ArrayRef [ Dict [ url => NonEmptySimpleStr, feed => Str ] ];
coerce Blog, from HashRef, via { [$_] };

subtype Stat,
    as Dict [
    mode  => Int,
    uid   => Int,
    gid   => Int,
    size  => Int,
    mtime => Int
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

subtype Tests,
    as Dict [ fail => Int, na => Int, pass => Int, unknown => Int ];

subtype BugSummary,
    as Dict [
    (
        map { $_ => Optional [Int] }
            qw(new open stalled patched resolved rejected active closed)
    ),
    type   => Str,
    source => Str
    ];

subtype Resources,
    as Dict [
    license => Optional [ ArrayRef [Str] ],
    homepage => Optional [Str],
    bugtracker =>
        Optional [ Dict [ web => Optional [Str], mailto => Optional [Str] ] ],
    repository => Optional [
        Dict [
            url  => Optional [Str],
            web  => Optional [Str],
            type => Optional [Str]
        ]
    ]
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

class_type 'CPAN::Meta';
coerce HashRef, from 'CPAN::Meta', via {
    my $struct = eval { $_->as_struct( { version => 2 } ); };
    return $struct ? $struct : $_->as_struct;
};

class_type Logger, { class => 'Log::Log4perl::Logger' };
coerce Logger, from ArrayRef, via {
    return MetaCPAN::Role::Logger::_build_logger($_);
};

MooseX::Getopt::OptionTypeMap->add_option_type_to_map(
    'MooseX::Types::ElasticSearch::ES' => '=s' );

subtype AssociatedPod, as Item;

use MooseX::Attribute::Deflator;
deflate 'ScalarRef', via {$$_};
inflate 'ScalarRef', via { \$_ };

deflate AssociatedPod, via { ref $_ ? $_->full_path : $_ };
no MooseX::Attribute::Deflator;

1;
