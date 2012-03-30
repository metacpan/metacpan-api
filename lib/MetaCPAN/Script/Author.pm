package MetaCPAN::Script::Author;

use Moose;
with 'MooseX::Getopt';
use Log::Contextual qw( :log );
with 'MetaCPAN::Role::Common';
use Email::Valid ();
use File::stat   ();
use JSON::XS     ();
use URI          ();
use Encode       ();
use XML::Simple qw(XMLin);
use DateTime::Format::ISO8601 ();

use MetaCPAN::Document::Author;

=head1 SYNOPSIS

Loads author info into db. Requires the presence of a local CPAN/minicpan.

=cut

has 'author_fh' => (
    is      => 'rw',
    traits  => ['NoGetopt'],
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
    log_debug {"Counting author"};
    log_info {"Indexing $count authors"};

    log_debug {"Getting last update dates"};
    my $dates
        = $type->inflate(0)->filter( { exists => { field => 'updated' } } )
        ->size(99999)->all;
    $dates = {
        map {
            $_->{pauseid} =>
                DateTime::Format::ISO8601->parse_datetime( $_->{updated} )
            } map { $_->{_source} } @{ $dates->{hits}->{hits} }
    };

    my $bulk = $self->model->bulk( size => 500 );

    while ( my ( $pauseid, $data ) = each %$authors ) {
        my ( $name, $email, $homepage, $asciiname )
            = ( @$data{qw(fullname email homepage asciiname)} );
        $name = undef if ( ref $name );
        $email = lc($pauseid) . '@cpan.org'
            unless ( $email && Email::Valid->address($email) );
        log_debug {
            Encode::encode_utf8(
                sprintf( "Indexing %s: %s <%s>", $pauseid, $name, $email ) );
        };
        my $conf = $self->author_config( $pauseid, $dates ) || next;
        my $put = {
            pauseid   => $pauseid,
            name      => $name,
            asciiname => ref $asciiname ? undef : $asciiname,
            email     => $email,
            website   => $homepage,
            map { $_ => $conf->{$_} }
                grep { defined $conf->{$_} } keys %$conf
        };
        $put->{website} = [ $put->{website} ]
            unless ( ref $put->{website} eq 'ARRAY' );
        $put->{website} = [

            # normalize www.homepage.com to http://www.homepage.com
            map { $_->scheme ? $_->as_string : 'http://' . $_->as_string }
                map  { URI->new($_)->canonical }
                grep {$_} @{ $put->{website} }
        ];
        my $author = $type->new_document($put);
        $author->gravatar_url;    # build gravatar_url
        $bulk->put($author);
    }
    $self->index->refresh;
    log_info {"done"};
}

sub author_config {
    my ( $self, $pauseid, $dates ) = @_;
    my $fallback = $dates->{$pauseid} ? undef : {};
    my $dir = $self->cpan->subdir( 'authors',
        MetaCPAN::Util::author_dir($pauseid) );
    my @files;
    opendir( my $dh, $dir ) || return {};
    my ($file)
        = sort { $dir->file($b)->stat->mtime <=> $dir->file($a)->stat->mtime }
        grep   {m/author-.*?\.json/} readdir($dh);
    return $fallback unless ($file);
    $file = $dir->file($file);
    return $fallback if !-e $file;
    my $mtime = DateTime->from_epoch( epoch => $file->stat->mtime );

    if ( $dates->{$pauseid} && $dates->{$pauseid} >= $mtime ) {
        log_debug {"Skipping $pauseid (newer version in index)"};
        return undef;
    }
    my $json = $file->slurp;
    my $author = eval { JSON::XS->new->utf8->relaxed->decode($json) };

    if ($@) {
        log_warn {"$file is broken: $@"};
        return $fallback;
    }
    else {
        $author
            = { map { $_ => $author->{$_} }
                qw(name asciiname profile blog perlmongers donation email website city region country location extra)
            };
        $author->{updated} = $mtime;
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
