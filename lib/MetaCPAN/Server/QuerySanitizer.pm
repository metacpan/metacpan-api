package MetaCPAN::Server::QuerySanitizer;

use Moose;

has query => (
    is         => 'ro',
    isa        => 'Maybe[HashRef]',
    trigger    => \&_build_clean_query,
);

our %metacpan_scripts = (
    prefer_shorter_module_names_100 => q{
        _score - doc['documentation'].stringValue.length()/100
    },
    prefer_shorter_module_names_400 => q{
        documentation = doc['documentation'].stringValue;
        if(documentation == empty) {
            documentation = 'xxxxxxxxxxxxxxxxxxxxxxxxx'
        }
        return _score - documentation.length()/400
    },
    score_version_numified => q{doc['module.version_numified'].value},
    status_is_latest => q{doc['status'].value == 'latest'},
);

sub _build_clean_query {
    my ($self) = @_;
    my $search = $self->query
        or return undef;

    _scan_hash_tree($search);

    return $search;
}

# if we want a regexp we could do { $key = qr/^\Q$key\E$/ if !ref $key; }
my $key = 'script';
sub _scan_hash_tree {
    my ($struct) = @_;

    my $ref = ref($struct);
    if( $ref eq 'HASH' ){
        while( my ($k, $v) = each %$struct ){
            if( $k eq $key ){
                MetaCPAN::Server::QuerySanitizer::Error->throw(
                    message => qq[Parameter "$key" not allowed],
                );
            }
            _scan_hash_tree($v) if ref $v;
        }
        if( my $mscript = delete $struct->{metacpan_script} ){
            $struct->{script} = $metacpan_scripts{ $mscript };
        }
    }
    elsif( $ref eq 'ARRAY' ){
        foreach my $item ( @$struct ){
            _scan_hash_tree($item) if ref($item);
        }
    }
}

__PACKAGE__->meta->make_immutable;

{
    package MetaCPAN::Server::QuerySanitizer::Error;
    use Moose;
    extends 'Throwable::Error';
    __PACKAGE__->meta->make_immutable;
}

1;
