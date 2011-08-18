package MetaCPAN::Document::Mirror;
use Moose;
use ElasticSearchX::Model::Document;
use ElasticSearchX::Model::Document::Types qw(:all);

use MetaCPAN::Util;

has name => ( is => 'ro', required => 1, id => 1 );
has [qw(org city region country continent)] =>
    ( is => 'ro', index => 'analyzed' );
has [qw(tz src http rsync ftp freq note dnsrr ccode aka_name A_or_CNAME)] =>
    ( is => 'ro' );
has location => ( is => 'ro', isa => Location, coerce => 1 );
has contact => ( is => 'ro', required => 1, isa => 'ArrayRef' );
has [qw(inceptdate reitredate)] =>
    ( is => 'ro', isa => 'DateTime', coerce => 1 );

__PACKAGE__->meta->make_immutable;
