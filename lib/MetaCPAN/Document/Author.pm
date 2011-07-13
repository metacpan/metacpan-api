package MetaCPAN::Document::Author;
use Moose;
use ElasticSearchX::Model::Document;
use Gravatar::URL ();
use MetaCPAN::Util;

use MetaCPAN::Types qw(:all);
use MooseX::Types::Structured qw(Dict Tuple Optional);
use MooseX::Types::Moose qw/Int Num Str ArrayRef HashRef Undef/;
use ElasticSearchX::Model::Document::Types qw(:all);
use MooseX::Types::Common::String qw(NonEmptySimpleStr);

=head1 PROPERTIES

=head2 email

=head2 website

=head2 city

=head2 region

=head2 country

=head2 name

=head2 name.analyzed

Self explanatory.

=head2 pauseid

PAUSE ID of the author.

=head2 dir

Directory of the author.
Example: C<< id/P/PE/PERLER >>

=head2 gravatar_url

URL to the gravatar user picture. This URL is generated using the first email address supplied to L</email>.

=head2 profile

Object or array of user profiles. Example:

 [  { name => "amazon",        id => "B002MRC39U" },
    { name => "stackoverflow", id => "brian-d-foy" } ]

=head2 blog

Object or array of blogs. Example:

 { feed => "http://blogs.perl.org/users/brian_d_foy/atom.xml",
   url  => "http://blogs.perl.org/users/brian_d_foy/" }

=head2 perlmongers

Object or array of perlmonger groups. Example:

 { url => "http://frankfurt.pm", name => "Frankfurt.pm" }

=head2 donation

Object or array of places where to donate. Example:

 { name => "paypal", id => "brian.d.foy@gmail.com" }

=head2 location

Array of longitude and latitude. Example:

 [12.5436, 7.2358]

=head2 extra

=head2 extra.analyzed

This field can contain anything. It is serialized using JSON
and stored in the index. You can do full-text searches on the
analyzed JSON string.

=cut

has name => ( index => 'analyzed', isa => NonEmptySimpleStr );
has asciiname =>
    ( index => 'analyzed', isa => NonEmptySimpleStr, required => 0 );
has [qw(website email)] => ( isa => ArrayRef, coerce => 1 );
has pauseid      => ( id         => 1 );
has dir          => ( lazy_build => 1 );
has gravatar_url => ( lazy_build => 1, isa => NonEmptySimpleStr );
has profile => (
    isa      => Profile,
    coerce   => 1,
    required => 0,
    dynamic  => 1
);
has blog => (
    isa      => Blog,
    coerce   => 1,
    required => 0,
    dynamic  => 1
);
has perlmongers => (
    isa      => PerlMongers,
    coerce   => 1,
    required => 0,
    dynamic  => 1
);
has donation => (
    isa => ArrayRef [ Dict [ name => NonEmptySimpleStr, id => Str ] ],
    required => 0,
    dynamic  => 1
);
has [qw(city region country)] => ( required => 0, isa => NonEmptySimpleStr );
has location => ( isa => Location, coerce => 1, required => 0 );
has extra =>
    ( isa => 'HashRef', source_only => 1, dynamic => 1, required => 0 );
has updated => ( isa => 'DateTime', required => 0 );

sub _build_dir {
    my $pauseid = ref $_[0] ? shift->pauseid : shift;
    return MetaCPAN::Util::author_dir($pauseid);
}

sub _build_gravatar_url {
    my $self = shift;
    my $email = ref $self->email ? $self->email->[0] : $self->email;
    Gravatar::URL::gravatar_url( email => $email );
}

sub validate {
    my ( $class, $data ) = @_;
    my @result;
    foreach my $attr ( $class->meta->get_all_attributes ) {
        if ( $attr->is_required && !exists $data->{ $attr->name } ) {
            push(
                @result,
                {   field   => $attr->name,
                    message => $attr->name . ' is required'
                }
            );
        }
        elsif ( exists $data->{ $attr->name } && $attr->has_type_constraint )
        {
            my $message
                = $attr->type_constraint->validate( $data->{ $attr->name } );
            push( @result, { field => $attr->name, message => $message } )
                if ( defined $message );
        }
    }
    return @result;
}

__PACKAGE__->meta->make_immutable;
