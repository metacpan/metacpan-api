package MetaCPAN::Script::Author;

use strict;
use warnings;

use Moose;
with 'MooseX::Getopt', 'MetaCPAN::Role::Script';

use DateTime::Format::ISO8601 ();
use Email::Valid              ();
use Encode                    ();
use File::stat                ();
use Cpanel::JSON::XS qw( decode_json );
use Log::Contextual qw( :log );
use MetaCPAN::Document::Author;
use URI ();
use XML::Simple qw(XMLin);

=head1 SYNOPSIS

Loads author info into db. Requires the presence of a local CPAN/minicpan.

=cut

has author_fh => (
    is      => 'ro',
    traits  => ['NoGetopt'],
    lazy    => 1,
    default => sub { shift->cpan . '/authors/00whois.xml' },
);

sub run {
    my $self = shift;

  # check we are using a dedicated index, prompts if not
  # my $index = $self->index->name;
  # $self->are_you_sure(
  #     "Author script is run against a non-author specific index: $index !!!"
  # ) unless $index =~ /author/;

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
        ->size(10000)->all;
    $dates = {
        map {
            $_->{pauseid} =>
                DateTime::Format::ISO8601->parse_datetime( $_->{updated} )
        } map { $_->{_source} } @{ $dates->{hits}->{hits} }
    };

    my $bulk = $self->model->bulk( size => 100 );

    my @author_ids_to_purge;

    while ( my ( $pauseid, $data ) = each %$authors ) {
        my ( $name, $email, $homepage, $asciiname )
            = ( @$data{qw(fullname email homepage asciiname)} );
        $name = undef if ( ref $name );
        $asciiname = q{} unless defined $asciiname;
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

        $put->{is_pause_custodial_account} = 1
            if $name and $name =~ /\(PAUSE Custodial Account\)/;

        # Now check the format we have is actually correct
        my @errors = MetaCPAN::Document::Author->validate($put);
        next if scalar @errors;

        my $author = $type->new_document($put);
        $author->gravatar_url;    # build gravatar_url

        # Do not import lat / lon's in the wrong order, or just invalid
        if ( my $loc = $author->{location} ) {

            my $lat = $loc->[1];
            my $lon = $loc->[0];

            if ( $lat > 90 or $lat < -90 ) {

                # Invalid latitude
                delete $author->{location};
            }
            elsif ( $lon > 180 or $lon < -180 ) {

                # Invalid longitude
                delete $author->{location};
            }
        }

        push @author_ids_to_purge, $put->{pauseid};

        # Only try put if this is a valid format
        $bulk->put($author);
    }
    $self->index->refresh;

    $self->purge_author_key(@author_ids_to_purge);
    $self->perform_purges;

    log_info {"done"};
}

sub author_config {
    my ( $self, $pauseid, $dates ) = @_;

    my $fallback = $dates->{$pauseid} ? undef : {};

    my $dir = $self->cpan->subdir( 'authors',
        MetaCPAN::Util::author_dir($pauseid) );

    my @files;
    opendir( my $dh, $dir ) || return $fallback;

    # Get the most recent version
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

    my $author;
    eval {
        $author = decode_json( $file->slurp );
        1;
    } or do {
        log_warn {"$file is broken: $@"};
        return $fallback;
    };
    $author
        = { map { $_ => $author->{$_} }
            qw(name asciiname profile blog perlmongers donation email website city region country location extra)
        };
    $author->{updated} = $mtime;
    return $author;
}

__PACKAGE__->meta->make_immutable;
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
