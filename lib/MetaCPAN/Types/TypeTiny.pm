package MetaCPAN::Types::TypeTiny;

use strict;
use warnings;

use Type::Library -base, -declare => ( qw(
    ArrayRefPromote

    PerlMongers
    Blog
    Stat
    Tests
    RTIssueStatus
    GitHubIssueStatus
    BugSummary
    RiverSummary
    Resources

    Logger
    HashRefCPANMeta

    CommaSepOption

    ES
) );
use Type::Utils qw( as coerce declare extends from via );

BEGIN {
    extends qw(
        Types::Standard Types::Path::Tiny Types::URI Types::Common::String
    );
}

declare ArrayRefPromote, as ArrayRef;
coerce ArrayRefPromote, from Value, via { [$_] };

declare PerlMongers,
    as ArrayRef [ Dict [ url => Optional [Str], name => NonEmptySimpleStr ] ];
coerce PerlMongers, from HashRef, via { [$_] };

declare Blog,
    as ArrayRef [ Dict [ url => NonEmptySimpleStr, feed => Optional [Str] ] ];
coerce Blog, from HashRef, via { [$_] };

declare Stat,
    as Dict [
    mode  => Int,
    size  => Int,
    mtime => Int
    ];

declare Tests,
    as Dict [ fail => Int, na => Int, pass => Int, unknown => Int ];

declare RTIssueStatus,
    as Dict [
    (
        map { $_ => Optional [Int] }
            qw( active closed new open patched rejected resolved stalled )
    ),
    source => Str
    ];

declare GitHubIssueStatus,
    as Dict [
    ( map { $_ => Optional [Int] } qw( active closed open ) ),
    source => Str,
    ];

declare BugSummary,
    as Dict [
    rt     => Optional [RTIssueStatus],
    github => Optional [GitHubIssueStatus],
    ];

declare RiverSummary,
    as Dict [ ( map { $_ => Optional [Int] } qw(total immediate bucket) ), ];

declare Resources,
    as Dict [
    license    => Optional [ ArrayRef [Str] ],
    homepage   => Optional [Str],
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

declare Logger, as InstanceOf ['Log::Log4perl::Logger'];
coerce Logger, from ArrayRef, via {
    return MetaCPAN::Role::Logger::_build_logger($_);
};
coerce Logger, from HashRef, via {
    return MetaCPAN::Role::Logger::_build_logger( [$_] );
};

declare HashRefCPANMeta, as HashRef;
coerce HashRefCPANMeta, from InstanceOf ['CPAN::Meta'], via {
    my $struct = eval { $_->as_struct( { version => 2 } ); };
    return $struct ? $struct : $_->as_struct;
};

declare CommaSepOption, as ArrayRef [ StrMatch [qr{^[^, ]+$}] ];
coerce CommaSepOption, from ArrayRef [Str], via {
    return [ map split(/\s*,\s*/), @$_ ];
};
coerce CommaSepOption, from Str, via {
    return [ map split(/\s*,\s*/), $_ ];
};

declare ES, as Object;
coerce ES, from Str, via {
    my $server = $_;
    $server = "127.0.0.1$server" if ( $server =~ /^:/ );
    return Search::Elasticsearch->new(
        nodes => $server,
        cxn   => 'HTTPTiny',
    );
};

coerce ES, from HashRef, via {
    return Search::Elasticsearch->new( {
        cxn => 'HTTPTiny',
        %$_,
    } );
};

coerce ES, from ArrayRef, via {
    my @servers = @$_;
    @servers = map { /^:/ ? "127.0.0.1$_" : $_ } @servers;
    return Search::Elasticsearch->new(
        nodes => \@servers,
        cxn   => 'HTTPTiny',
    );
};

1;
