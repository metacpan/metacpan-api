package MetaCPAN::Script::Author;

use Moose;
use feature 'say';
with 'MooseX::Getopt';
use Log::Contextual qw( :log );
with 'MetaCPAN::Role::Common';
use Email::Valid;
use File::Find;
use JSON;

use MetaCPAN::Document::Author;

=head1 SYNOPSIS

Loads author info into db. Requires the presence of a local CPAN/minicpan.

=cut

use Data::Dump qw( dump );
use IO::File;
use IO::Uncompress::AnyInflate qw(anyinflate $AnyInflateError);
use MooseX::Getopt;
use Scalar::Util qw( reftype );

has 'author_fh' => ( is => 'rw', lazy_build => 1, traits => ['NoGetopt'] );

sub run {
    my $self = shift;
    $self->index_authors;
    $self->es->refresh_index( index => 'cpan' );
}

sub index_authors {
    my $self      = shift;
    my $type      = $self->index->type('author');
    my @authors   = ();
    my $author_fh = $self->author_fh;
    my @results   = ();
    my $lines     = 0;
    log_debug { "Counting author" };
    $lines++ while ( $author_fh->getline() );
    $author_fh = $self->_build_author_fh;
    log_info { "Indexing $lines authors" };

    while ( my $line = $author_fh->getline() ) {
        if ( $line =~ m{alias\s([\w\-]*)\s*"(.+?)\s*<(.*)>"}gxms ) {
            my ( $pauseid, $name, $email ) = ( $1, $2, $3 );
            $email = lc($pauseid) . '@cpan.org'
              unless ( Email::Valid->address($email) );
            log_debug { "Indexing $pauseid: $name <$email>" };
            my $author =
              MetaCPAN::Document::Author->new( pauseid => $pauseid,
                                               name    => $name,
                                               email   => $email );
            my $conf = $self->author_config( $pauseid, $author->dir );
            $author = $type->put(
                                  { pauseid => $pauseid,
                                    name    => $name,
                                    email   => $email,
                                    map { $_ => $conf->{$_} }
                                      grep { defined $conf->{$_} } keys %$conf
                                  } );

            push @results, $author;
        }
    }
    log_info { "done" };
}

sub author_config {
    my $self    = shift;
    my $pauseid = shift;
    my $dir     = shift;
    $dir = $self->cpan . "/authors/$dir/";
    my @files;
    opendir( my $dh, $dir ) || return {};
    my ($file) =
      sort { ( stat( $dir . $b ) )[9] <=> ( stat( $dir . $a ) )[9] }
      grep { m/author-.*?\.json/ } readdir($dh);
    $file = $dir . $file;
    return {} if !-e $file;
    my $json;
    {
        local $/ = undef;
        local *FILE;
        open FILE, "<", $file;
        $json = <FILE>;
        close FILE
    }
    my $author = eval { decode_json($json) };
    if (@$) {
        log_warn { "$file is broken: $@" };
        return {};
    } else {
        $author =
          { map { $_ => $author->{$_} }
            qw(name profile blog perlmongers donation email website city region country location extra)
          };
        return $author;
    }
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
