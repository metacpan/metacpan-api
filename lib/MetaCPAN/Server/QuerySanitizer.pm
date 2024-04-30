package MetaCPAN::Server::QuerySanitizer;

use strict;
use warnings;

use Moose;
use MetaCPAN::Types::TypeTiny qw( HashRef Maybe );

has query => (
    is      => 'ro',
    isa     => Maybe [HashRef],
    trigger => \&_build_clean_query,
);

sub _build_clean_query {
    my ($self) = @_;
    my $search = $self->query
        or return;

    _scan_hash_tree($search);

    return $search;
}

# if we want a regexp we could do { $key = qr/^\Q$key\E$/ if !ref $key; }
my $key = 'script';

sub _scan_hash_tree {
    my ($struct) = @_;

    my $ref = ref($struct);
    if ( $ref eq 'HASH' ) {
        while ( my ( $k, $v ) = each %$struct ) {
            if ( $k eq $key ) {
                MetaCPAN::Server::QuerySanitizer::Error->throw(
                    message => qq[Parameter "$key" not allowed], );
            }
            _scan_hash_tree($v) if ref $v;
        }
    }
    elsif ( $ref eq 'ARRAY' ) {
        foreach my $item (@$struct) {
            _scan_hash_tree($item) if ref($item);
        }
    }

    # Mickey: what about $ref eq 'JSON::PP::Boolean' ?
}

__PACKAGE__->meta->make_immutable;

{

    package MetaCPAN::Server::QuerySanitizer::Error;
    use Moose;
    extends 'Throwable::Error';
    __PACKAGE__->meta->make_immutable;
}

1;
