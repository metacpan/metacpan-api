use 5.010;
package MetaCPAN::Tests::API::Pod;
use Test::Routine;
with qw(
    MetaCPAN::Tests::API
);
use Test::More;
use namespace::autoclean;

has pod_format => (
    is         => 'ro',
    isa        => 'Str',
);

has pod_re     => (
    is         => 'ro',
    isa        => 'Regexp',
);

has pod_uri    => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

# requires package... either combine with Module or pass in pod_uri
sub _build_pod_uri {
    my ($self) = @_;
    return '/pod/' . $self->package;
}

test pod_content => sub {
    my ($self) = @_;
    my $format = do {
        given($self->pod_format){
            when(/pod/)      { 'text/x-pod' }
            when(/markdown/) { 'text/x-markdown' }
            when(/plain/)    { 'text/plain' }
            default { '' }
        }
    };
    my $pod = $self->request_content(
        GET => $self->pod_uri,
        ($format ? (Accept => $format) : ()),
    );
    like $pod, $self->pod_re, 'pod matches';
};

1;
