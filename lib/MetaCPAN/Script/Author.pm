package MetaCPAN::Script::Author;

use Moose;
use feature 'say';
with 'MooseX::Getopt';
use Log::Contextual qw( :log );
with 'MetaCPAN::Role::Common';
use Email::Valid;
use File::Find;
use JSON;
use XML::Simple qw(XMLin);
use URI;
use Encode;

use MetaCPAN::Document::Author;

=head1 SYNOPSIS

Loads author info into db. Requires the presence of a local CPAN/minicpan.

=cut

use Data::Dump qw( dump );
use IO::File;
use IO::Uncompress::AnyInflate qw(anyinflate $AnyInflateError);
use MooseX::Getopt;
use Scalar::Util qw( reftype );

has 'author_fh' => (
    is => 'rw',
    traits => ['NoGetopt'],
    default => sub { shift->cpan . "/authors/00whois.xml" }
);

sub run {
    my $self = shift;
    $self->index_authors;
    $self->index->refresh;
}

sub index_authors {
    my $self    = shift;
    my $type    = $self->index->type('author');
    my $authors = XMLin( $self->author_fh )->{cpanid};
    my $count   = keys %$authors;
    log_debug { "Counting author" };
    log_info { "Indexing $count authors" };

    while ( my ( $pauseid, $data ) = each %$authors ) {
        my ( $name, $email, $homepage ) =
          ( @$data{qw(fullname email homepage)} );
        $name = undef if(ref $name);
        $email = lc($pauseid) . '@cpan.org'
          unless ( $email && Email::Valid->address($email) );
        log_debug { encode( 'UTF-8', sprintf("Indexing %s: %s <%s>", $pauseid, $name, $email ) ) };
        my $conf = $self->author_config( $pauseid, MetaCPAN::Util::author_dir($pauseid) );
        my $put = { pauseid  => $pauseid,
            name     => $name,
            email    => $email,
            website  => $homepage,
            map { $_ => $conf->{$_} }
              grep { defined $conf->{$_} } keys %$conf
          };
        $put->{website} = [$put->{website}] unless(ref $put->{website} eq 'ARRAY');
        $put->{website} = [
            # fix www.homepage.com to be http://www.homepage.com
            map { $_->scheme ? $_->as_string : 'http://' . $_->as_string }
            map { URI->new($_)->canonical }
            grep { $_ }
            @{$put->{website}}
        ];
        $type->put( $put );
    }
    $self->index->refresh;
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
    return {} unless($file);
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
    my $author = eval { JSON::XS->new->relaxed->decode($json) };
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
