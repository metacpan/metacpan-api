package MetaCPAN::Document::Module;
use Moose;
use ElasticSearchX::Model::Document;

use MetaCPAN::Util;
use URI::Escape ();

has id => ( id => [qw(author release name)] );
has version_numified => ( isa => 'Num', lazy_build => 1 );
has [qw(author distribution)] => ();
has [qw(path file_id)] => ( lazy_build => 1 );
has release => ( parent => 1 );
has name => ( index => 'analyzed' );
has [qw(version)] => ( required => 0 );
has date     => ( isa   => 'DateTime' );
has abstract => ( index => 'analyzed', lazy_build => 1 );
has status => ( default => 'cpan' );
has maturity => ( default => 'released' );

has file => ( property => 0, required => 0 );

sub BUILD {
    my $self = shift;
    $self->file->module($self->name) if($self->file);
    return $self;
}

sub _build_version_numified {
    return MetaCPAN::Util::numify_version( shift->version );
}

sub _build_path {
    shift->file->path;
}

sub _build_file_id {
    shift->file->id;
}

sub _build_abstract {
    shift->file->abstract;
}

__PACKAGE__->meta->make_immutable;
