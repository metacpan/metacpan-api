package MetaCPAN::Types::Distribution;
use strict;
use warnings;

use Type::Library -base, -declare => ( qw(
    RiverSummary
    Tests
    RTIssueStatus
    GitHubIssueStatus
    BugSummary
) );

use Types::Standard qw(
    Dict
    Int
    Optional
    Str
);
use Type::Utils qw( as declare );

declare RiverSummary,
    as Dict [
    total      => Optional [Int],
    immediate  => Optional [Int],
    bucket     => Optional [Int],
    bus_factor => Optional [Int],
    ];

declare Tests,
    as Dict [
    fail    => Int,
    na      => Int,
    pass    => Int,
    unknown => Int,
    ];

declare RTIssueStatus,
    as Dict [
    source   => Str,
    active   => Optional [Int],
    closed   => Optional [Int],
    new      => Optional [Int],
    open     => Optional [Int],
    patched  => Optional [Int],
    rejected => Optional [Int],
    resolved => Optional [Int],
    stalled  => Optional [Int],
    ];

declare GitHubIssueStatus,
    as Dict [
    source => Str,
    active => Optional [Int],
    closed => Optional [Int],
    open   => Optional [Int],
    ];

declare BugSummary,
    as Dict [
    rt     => Optional [RTIssueStatus],
    github => Optional [GitHubIssueStatus],
    ];

1;
