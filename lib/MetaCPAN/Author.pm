package MetaCPAN::Author;

use Data::Dump qw( dump );
use Moose;
use MooseX::Getopt;
use Modern::Perl;

#with 'MetaCPAN::Role::Author';
with 'MetaCPAN::Role::Common';
#with 'MetaCPAN::Role::DB';

=head1 SYNOPSIS

Loads author info into db.  Requires the presence of a local CPAN/minicpan.

=cut

use Modern::Perl;

use Data::Dump qw( dump );
use Every;
use Find::Lib '../lib';
use Gravatar::URL;
use Hash::Merge qw( merge );
use JSON::DWIW;
use IO::File;
use IO::Uncompress::AnyInflate qw(anyinflate $AnyInflateError);

use MetaCPAN;
my $metacpan = MetaCPAN->new;

has 'author_config' => ( is => 'rw', lazy_build => 1, isa => 'HashRef', );
has 'author_fh' => ( is => 'rw', lazy_build => 1, );

sub _build_author_config {

    my $self = shift;
    my $json = JSON::DWIW->new;
    my ( $authors, $error_msg )
        = $json->from_json_file( Find::Lib::base . '/../conf/author.json',
        {} );
    return $authors;

}

sub _build_author_fh {

    my $self = shift;
    my $file = $self->cpan . "/authors/01mailrc.txt.gz";

    return new IO::Uncompress::AnyInflate $file
        or die "anyinflate failed: $AnyInflateError\n";

}

sub index_authors {

    my $self    = shift;
    my @authors = ();
    my $author_fh = $self->author_fh;
    my $authors = $self->author_config;
    
    while ( my $line = $author_fh->getline() ) {

        if ( $line =~ m{alias\s([\w\-]*)\s{1,}"(.*)<(.*)>"}gxms ) {

            my $pauseid = $1;
            my $name    = $2;
            my $email   = $3;

            my $author = {
                author     => $pauseid,
                pauseid    => $pauseid,
                author_dir => sprintf( "id/%s/%s/%s/",
                    substr( $pauseid, 0, 1 ),
                    substr( $pauseid, 0, 2 ),
                    $pauseid ),
                name         => $name,
                email        => $email,
                gravatar_url => gravatar_url( email => $email ),
            };

            if ( $authors->{$pauseid} ) {
                $author = merge( $author, $authors->{$pauseid} );
            }

            my %es_insert = (
                index => {
                    index => 'cpan',
                    type  => 'author',
                    id    => $pauseid,
                    data  => $author,
                }
            );

            push @authors, \%es_insert;

        }
    }

    my $result = $metacpan->es->bulk( \@authors );
    return;

}

1;
