package MetaCPAN::Server::QuerySanitizer;

use Moose;

has query => (
    is         => 'ro',
    isa        => 'Maybe[HashRef]',
    trigger    => \&_build_clean_query,
);

my %metacpan_scripts = (
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
);

sub _build_clean_query {
    my ($self) = @_;
    my $search = $self->query
        or return undef;

    _reject_hash_key($search, 'script');

    # this is a pretty specific hack to allow metacpan-web to use some scripts
    # while we work on providing endpoints to do it.
    # NOTE: use exists to avoid autovivifying hash trees
    if(
        exists $search->{query} &&
        exists $search->{query}->{filtered} &&
        exists $search->{query}->{filtered}->{query}
    ){
        if( my $cs = $search->{query}{filtered}{query}{custom_score} ){
            if( my $mscript = delete $cs->{metacpan_script} ){
                $cs->{script} = $metacpan_scripts{ $mscript };
            }
        }
    }

    return $search;
}

sub _reject_hash_key {
    my ($struct, $key) = @_;
    # if we want a regexp we could do { $key = qr/^\Q$key\E$/ if !ref $key; }

    my $ref = ref($struct);
    if( $ref eq 'HASH' ){
        while( my ($k, $v) = each %$struct ){
            if( $k eq $key ){
                MetaCPAN::Server::QuerySanitizer::Error->throw(
                    message => qq[Parameter "$key" not allowed],
                );
            }
            _reject_hash_key($v, $key) if ref $v;
        }
    }
    elsif( $ref eq 'ARRAY' ){
        foreach my $item ( @$struct ){
            _reject_hash_key($item, $key) if ref($item);
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
