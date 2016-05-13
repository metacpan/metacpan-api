package MetaCPAN::Document::Mirror;

use strict;
use warnings;

use Moose;
use ElasticSearchX::Model::Document::Types qw( Location );
use ElasticSearchX::Model::Document;

use MetaCPAN::Types qw( ArrayRef Dict Str );
use MooseX::Types::Structured qw(Dict );    # not sure why I have to do this

has name => (
    is       => 'ro',
    required => 1,
    id       => 1,
);

has [qw(org city region country continent)] => (
    is    => 'ro',
    index => 'analyzed',
);

has [qw(tz src http rsync ftp freq note dnsrr ccode aka_name A_or_CNAME)] =>
    ( is => 'ro' );

has location => (
    is     => 'ro',
    isa    => Location,
    coerce => 1,
);

has contact => (
    is       => 'ro',
    required => 1,
    isa      => Dict [ contact_site => Str, contact_user => Str ],
);

has [qw(inceptdate reitredate)] => (
    is     => 'ro',
    isa    => 'DateTime',
    coerce => 1,
);

__PACKAGE__->meta->make_immutable;
1;
