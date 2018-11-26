package    # no_index
    Module::Faker::Dist::WithPerl;

use Moose;
extends 'Module::Faker::Dist';

use Encode;

around append_for => sub {
    my ( $orig, $self, $filename ) = @_;
    return [
        # $orig normally expects utf-8 (yaml, json, etc)
        # but the reason for this subclass is to allow other encodings
        map {
                  utf8::is_utf8( $_->{content} )
                ? encode_utf8( $_->{content} )
                : $_->{content}
            }
            grep { $filename eq $_->{file} } @{ $self->append }
    ];
};

around from_file => sub {
    my ( $orig, $self, $filename ) = @_;

  # I'm not thrilled abot this but found it necessary for mixed encoding dists
    return $self->_from_perl_file($filename)
        if $filename =~ /\.pl$/;

    return $self->$orig($filename);
};

# be consistent with _from_meta_file so that the hash structures can be consistent
sub _from_perl_file {
    my ( $self, $filename ) = @_;

    my $data = do($filename);

    my $extra = ( delete $data->{X_Module_Faker} ) || {};
    my $dist  = $self->new( { %$data, %$extra } );
}

__PACKAGE__->meta->make_immutable;
1;
