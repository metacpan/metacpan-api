package MetaCPAN::Document::Author;

use MetaCPAN::Moose;

# load order important for next 2 modules
use ElasticSearchX::Model::Document::Types qw(:all);
use ElasticSearchX::Model::Document;

# load order not important
use Gravatar::URL ();
use MetaCPAN::Types qw(:all);
use MooseX::Types::Structured qw(Dict Tuple Optional);
use MetaCPAN::Util;

with 'MetaCPAN::Role::ES::Query';

has name => (
    is       => 'ro',
    required => 1,
    index    => 'analyzed',
    isa      => NonEmptySimpleStr,
);

has asciiname => (
    is       => 'ro',
    required => 1,
    index    => 'analyzed',
    isa      => Str,
    default  => q{},
);

has [qw(website email)] =>
    ( is => 'ro', required => 1, isa => ArrayRef, coerce => 1 );

has pauseid => (
    is       => 'ro',
    required => 1,
    id       => 1,
);

has user => (
    is     => 'ro',
    writer => '_set_user',
);

has gravatar_url => (
    is      => 'ro',
    isa     => NonEmptySimpleStr,
    lazy    => 1,
    builder => '_build_gravatar_url',
);

has profile => (
    is              => 'ro',
    isa             => Profile,
    coerce          => 1,
    type            => 'nested',
    include_in_root => 1,
);

has blog => (
    is      => 'ro',
    isa     => Blog,
    coerce  => 1,
    dynamic => 1,
);

has perlmongers => (
    is      => 'ro',
    isa     => PerlMongers,
    coerce  => 1,
    dynamic => 1,
);

has donation => (
    is      => 'ro',
    isa     => ArrayRef [ Dict [ name => NonEmptySimpleStr, id => Str ] ],
    dynamic => 1,
);

has [qw(city region country)] => ( is => 'ro', isa => NonEmptySimpleStr );

has location => ( is => 'ro', isa => Location, coerce => 1 );

has extra => (
    is          => 'ro',
    isa         => HashRef,
    source_only => 1,
    dynamic     => 1,
);

has updated => (
    is  => 'ro',
    isa => 'DateTime',
);

sub _build_gravatar_url {
    my $self = shift;

    # We do not use the author personal address ($self->email[0])
    # because we want to show the author's CPAN identity.
    # Using another e-mail than the CPAN one removes flexibility for
    # the author and ultimately could be a privacy leak.
    # The author can manage this identity both on his gravatar account
    # (by assigning an image to his author@cpan.org)
    # and now by changing this URL from metacpa.org
    return Gravatar::URL::gravatar_url(
        email => $self->pauseid . '@cpan.org',
        size  => 130,
        https => 1,

        # Fallback to a generated image
        default => 'identicon',
    );
}

sub validate {
    my ( $class, $data ) = @_;
    my @result;
    foreach my $attr ( $class->meta->get_all_attributes ) {
        if ( $attr->is_required && !exists $data->{ $attr->name } ) {
            push(
                @result,
                {
                    field   => $attr->name,
                    message => $attr->name . ' is required'
                }
            );
        }
        elsif ( exists $data->{ $attr->name } && $attr->has_type_constraint )
        {
            my $value = $data->{ $attr->name };
            if ( $attr->should_coerce ) {
                $value = $attr->type_constraint->coerce($value);
            }
            my $message = $attr->type_constraint->validate($value);
            push( @result, { field => $attr->name, message => $message } )
                if ( defined $message );
        }
    }
    return @result;
}

sub by_id {
    my ( $self, $req, $ids ) = @_;
    my @ids = map {uc} ( $ids ? $ids : $req->read_param('id') );
    return $self->es_by_terms_vals(
        req => $req,
        -or => {
            pauseid => \@ids,
        },
    );
}

sub by_id_for_top_uploaders {
    my ( $self, $req, $counts ) = @_;
    my $authors = $self->by_id( $req, [ keys %$counts ] );
    return [
        sort { $b->{releases} <=> $a->{releases} } map {
            {
                %{ $_->{_source} },
                    releases => $counts->{ $_->{_source}->{pauseid} }
            }
        } @{ $authors->{hits}{hits} }
    ];
}

sub by_user {
    my ( $self, $req ) = @_;
    my @users = $req->read_param('user');
    return $self->es_by_terms_vals(
        req => $req,
        -or => {
            user => \@users,
        },
    );
}

sub by_key {
    my ( $self, $req ) = @_;
    my $key = $req->parameters->{key};
    $key or return;

    my $filter = +{
        bool => {
            should => [
                {
                    match => {
                        'name.analyzed' =>
                            { query => $key, operator => 'and' }
                    }
                },
                {
                    match => {
                        'asciiname.analyzed' =>
                            { query => $key, operator => 'and' }
                    }
                },
                { match => { 'pauseid'    => uc($key) } },
                { match => { 'profile.id' => lc($key) } },
            ]
        }
    };
    my $cb = sub {
        my $res = shift;
        return +{
            results => [
                map { +{ %{ $_->{_source} }, id => $_->{_id} } }
                    @{ $res->{hits}{hits} }
            ],
            total => $res->{hits}{total} || 0,
            took => $res->{took}
        };
    };

    $self->es_by_filter( req => $req, filter => $filter, cb => $cb );
}

__PACKAGE__->meta->make_immutable;

1;

=pod

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

URL to the gravatar user picture. This URL is generated using PAUSEID@cpan.org.

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

