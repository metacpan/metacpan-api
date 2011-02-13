package ElasticSearch::Document;

use strict;
use warnings;

use Moose 1.15 ();
use Moose::Exporter;
use ElasticSearch::Document::Trait::Class;
use ElasticSearch::Document::Trait::Attribute;
use JSON::XS;
use Digest::SHA1;
use List::MoreUtils ();
use Carp;

Moose::Exporter->setup_import_methods(
                    as_is           => [qw(_build_es_id index _index)],
                    class_metaroles => {
                        class     => ['ElasticSearch::Document::Trait::Class'],
                        attribute => [
                            'ElasticSearch::Document::Trait::Attribute',
                            'MooseX::Attribute::Deflator::Meta::Role::Attribute'
                        ]
                    }, );


my @stat = qw(dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks);
use MooseX::Attribute::Deflator;
deflate 'Bool',       via { \$_ };
deflate 'File::stat', via { return { List::MoreUtils::mesh(@stat, @$_) } };
deflate 'ScalarRef',  via { $$_ };
deflate 'DateTime',   via { $_->iso8601 };
no MooseX::Attribute::Deflator;

sub index {
    my ( $self, $es ) = @_;
    my $id = $self->meta->get_id_attribute;
    return $es->index( $self->_index );
}

sub _index {
    my ($self) = @_;
    my $id = $self->meta->get_id_attribute;

    return ( index => 'cpan',
             type  => $self->meta->short_name,
             $id ? ( id => $id->get_value($self) ) : (),
             data => $self->meta->get_data($self), );
}

sub _build_es_id {
    my $self = shift;
    my $id   = $self->meta->get_id_attribute;
    carp "Need an arrayref of fields for the id, not " . $id->id
      unless ( ref $id->id eq 'ARRAY' );
    my @fields = map { $self->meta->get_attribute($_) } @{ $id->id };
    my $digest = join( "\0", map { $_->get_value($self) } @fields );
    $digest = Digest::SHA1::sha1_base64($digest);
    $digest =~ tr/[+\/]/-_/;
    return $digest;
}

1;
