package MetaCPAN::Document::CVE;

use MetaCPAN::Moose;

use ElasticSearchX::Model::Document;
use MetaCPAN::Types::TypeTiny qw( ArrayRef Str );

has distribution => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has cpansa_id => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has description => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has severity => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has reported => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has affected_versions => (
    is       => 'ro',
    isa      => ArrayRef,
    required => 1,
);

has cves => (
    is       => 'ro',
    isa      => ArrayRef,
    required => 1,
);

has references => (
    is       => 'ro',
    isa      => ArrayRef,
    required => 1,
);

has versions => (
    is       => 'ro',
    isa      => ArrayRef,
    required => 1,
);

__PACKAGE__->meta->make_immutable;
1;
