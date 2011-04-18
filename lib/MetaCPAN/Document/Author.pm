package MetaCPAN::Document::Author;
use Moose;
use ElasticSearchX::Model::Document;
use Gravatar::URL ();
use MetaCPAN::Util;

use MetaCPAN::Types qw(:all);
use MooseX::Types::Structured qw(Dict Tuple Optional);
use MooseX::Types::Moose qw/Int Num Str ArrayRef HashRef Undef/;
use ElasticSearchX::Model::Document::Types qw(:all);

# TODO: replace censored emailadresse with cpan emailadress

has name => ( index => 'analyzed' );
has email => ( isa => ArrayRef, coerce => 1 );
has 'pauseid' => ( id         => 1 );
has 'author'  => ( lazy_build => 1 );
has 'dir'     => ( lazy_build => 1 );
has 'gravatar_url' => ( lazy_build => 1 );
has profile => ( isa => Dict[ name => Str, id => Str ], required => 0 );
has blog => ( isa => Dict[ url => Str, feed => Str ], required => 0 );
has perlmongers => ( isa => Dict[ url => Str, name => Str ], required => 0 );
has donation => ( isa => Dict[ name => Str, id => Str ], required => 0 );
has [qw(email website city region country)] => ( required => 0 );
has location => ( isa => Location, coerce => 1, required => 0 );
has extra => ( isa => Extra, required => 0 );

sub _build_dir {
    my $pauseid = ref $_[0] ? shift->pauseid : shift;
    return MetaCPAN::Util::author_dir($pauseid);
}

sub _build_gravatar_url {
    my $self = shift;
    my $email = ref $self->email ? $self->email->[0] : $self->email;
    Gravatar::URL::gravatar_url( email => $email );
}

sub _build_author { shift->name }

__PACKAGE__->meta->make_immutable;
