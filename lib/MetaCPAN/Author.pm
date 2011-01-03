package MetaCPAN::Author;

use Moose;
use Modern::Perl;

with 'MetaCPAN::Role::Common';

=head1 SYNOPSIS

Loads author info into db. Requires the presence of a local CPAN/minicpan.

=cut

use Data::Dump qw( dump );
use Find::Lib '../lib';
use Gravatar::URL;
use Hash::Merge qw( merge );
use IO::File;
use IO::Uncompress::AnyInflate qw(anyinflate $AnyInflateError);
use JSON::DWIW;
use MooseX::Getopt;
use Scalar::Util qw( reftype );

use MetaCPAN;
my $metacpan = MetaCPAN->new;

has 'author_fh' => ( is => 'rw', lazy_build => 1, );

sub index_authors {

    my $self      = shift;
    my @authors   = ();
    my $author_fh = $self->author_fh;
    my @results   = ();

    while ( my $line = $author_fh->getline() ) {

        if ( $line =~ m{alias\s([\w\-]*)\s{1,}"(.*)<(.*)>"}gxms ) {

            my ( $pauseid, $name, $email ) = ( $1, $2, $3 );
            my $dir = sprintf( "%s/%s/%s",
                substr( $pauseid, 0, 1 ),
                substr( $pauseid, 0, 2 ), $pauseid );

            my $author = {
                author       => $pauseid,
                pauseid      => $pauseid,
                author_dir   => "id/$dir",
                name         => $name,
                email        => $email,
                gravatar_url => gravatar_url( email => $email ),
            };

            my $conf = $self->author_config( $pauseid, $dir );
            if ( $conf ) {
                $author = merge( $author, $conf );
            }

            my %update = ( 
                index => 'cpan',
                type  => 'author',
                id    => $pauseid,
                data  => $author,
            );

            push @results, $metacpan->es->index( %update );
            #say dump( $result );
            #say dump( \%update );
            #my %es_insert = (
            #    index => $insert 
            #);

        }
    }

    #return $metacpan->es->bulk( \@authors );
    return \@results;

}

sub author_config {

    my $self    = shift;
    my $pauseid = shift;
    my $dir     = shift;
    my $file    = Find::Lib::base . "/../conf/authors/$dir/author.json";

    return if !-e $file;

    my $json = JSON::DWIW->new;
    my ( $authors, $error_msg ) = $json->from_json_file( $file, {} );

    if ( $error_msg ) {
        warn "problem with $file: $error_msg";
        return {};
    }

    my $conf = $authors->{$pauseid};

    # uncomment this when search.metacpan can deal with lists in values
    my @lists = qw( website email books blog_url blog_feed cats dogs );
    foreach my $key ( @lists ) {
        if ( exists $conf->{$key} && reftype( $conf->{$key} ) ne 'ARRAY' ) {
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

    my $author = MetaCPAN::Author->new;
    my $result = $author->index_authors;

=head2 author_config( $pauseid, $dir )

Returns custom author metadata if any exists.

    my $conf = $author->author_config( 'OALDERS', 'O/OA/OALDERS' )

=head2 index_authors

Adds/updates all authors in the CPAN index to ElasticSearch.

=cut
