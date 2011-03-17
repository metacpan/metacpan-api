package MetaCPAN::Document::Mirror;
use Moose;
use ElasticSearchX::Model::Document;
use ElasticSearchX::Model::Document::Types qw(:all);

use MetaCPAN::Util;

has name => ( id => 1 );
has [qw(org city region country continent)] => ( index => 'analyzed', required => 0 );
has [qw(tz src http rsync ftp freq note dnsrr ccode aka_name A_or_CNAME)]
    => ( required => 0 );
has location => ( isa => Location, coerce => 1, required => 0 );
has contact => ( isa => 'ArrayRef' );
has [qw(inceptdate reitredate)] => ( isa => 'DateTime', required => 0, coerce => 1 );

__PACKAGE__->meta->make_immutable;
