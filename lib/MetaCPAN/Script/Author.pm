package MetaCPAN::Script::Author;

use Moose;
use feature 'say';
with 'MooseX::Getopt';
use Log::Contextual qw( :log );
with 'MetaCPAN::Role::Common';

use MetaCPAN::Document::Author;

=head1 SYNOPSIS

Loads author info into db. Requires the presence of a local CPAN/minicpan.

=cut

use Data::Dump qw( dump );
use IO::File;
use IO::Uncompress::AnyInflate qw(anyinflate $AnyInflateError);
use JSON::DWIW;
use MooseX::Getopt;
use Scalar::Util qw( reftype );

has 'author_fh' => ( is => 'rw', lazy_build => 1, );

sub run {
    my $self = shift;
    $self->index_authors;
    $self->es->refresh_index( index => 'cpan' );
}

sub index_authors {

    my $self      = shift;
    my @authors   = ();
    my $author_fh = $self->author_fh;
    my @results   = ();
    my $lines = 0;
    log_debug { "Counting author" };
    $lines++ while($author_fh->getline());
    $author_fh = $self->_build_author_fh;
    log_info { "Indexing $lines authors" };
    
    while ( my $line = $author_fh->getline() ) {
        if ( $line =~ m{alias\s([\w\-]*)\s{1,}"(.*)<(.*)>"}gxms ) {
            my ( $pauseid, $name, $email ) = ( $1, $2, $3 );
            log_debug { "Indexing $pauseid: $name <$email>" };
            my $author =
              MetaCPAN::Document::Author->new( pauseid => $pauseid,
                                               name    => $name,
                                               email   => $email );
            my $conf = $self->author_config( $pauseid, $author->dir );
            $author = MetaCPAN::Document::Author->new( pauseid => $pauseid,
                                               name    => $name,
                                               email   => $email, %$conf );

            push @results, $author->index( $self->es );
        }
    }
    log_info { "done" };
}

sub author_config {

    my $self    = shift;
    my $pauseid = shift;
    my $dir     = shift;
    $dir =~ s/^id\///;
    my $file    = "conf/authors/$dir/author.json";
    return {} if !-e $file;
    
    my $json = JSON::DWIW->new;
    my ( $authors, $error_msg ) = $json->from_json_file( $file, {} );

    if ($error_msg) {
        warn "problem with $file: $error_msg";
        return {};
    }

    my $conf = $authors->{$pauseid};

    # uncomment this when search.metacpan can deal with lists in values
    my @lists = qw( website email books blog_url blog_feed cats dogs );
    foreach my $key (@lists) {
        if ( exists $conf->{$key}
             && (   !reftype( $conf->{$key} )
                  || reftype( $conf->{$key} ) ne 'ARRAY' ) )
        {
            $conf->{$key} = [ $conf->{$key} ];
        }
    }

    return $conf;

}

sub _build_author_fh {

    my $self = shift;
    my $file = $self->cpan . "/authors/01mailrc.txt.gz";

    return new IO::Uncompress::AnyInflate $file
      or die "anyinflate failed: $AnyInflateError\n";

}

1;

=pod

=head1 SYNOPSIS

Parse out CPAN author info, add custom per-author metadata and add it to the
ElasticSearch index

    my $author = MetaCPAN::Script::Author->new;
    my $result = $author->index_authors;

=head2 author_config( $pauseid, $dir )

Returns custom author metadata if any exists.

    my $conf = $author->author_config( 'OALDERS', 'O/OA/OALDERS' )

=head2 index_authors

Adds/updates all authors in the CPAN index to ElasticSearch.

=cut
