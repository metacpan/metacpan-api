package MetaCPAN::Script::Author;

use strict;
use warnings;

use Moose;
with 'MooseX::Getopt', 'MetaCPAN::Role::Script';

use Cpanel::JSON::XS           qw( decode_json );
use DateTime                   ();
use Email::Valid               ();
use Encode                     ();
use Log::Contextual            qw( :log :dlog );
use MetaCPAN::Document::Author ();
use MetaCPAN::ESConfig         qw( es_doc_path );
use MetaCPAN::Types::TypeTiny  qw( Str );
use MetaCPAN::Util             qw(diff_struct true false);
use URI                        ();
use XML::XPath                 ();

=head1 SYNOPSIS

Loads author info into db. Requires the presence of a local CPAN/minicpan.

=cut

has author_fh => (
    is      => 'ro',
    traits  => ['NoGetopt'],
    lazy    => 1,
    default => sub { shift->cpan . '/authors/00whois.xml' },
);

has pauseid => (
    is  => 'ro',
    isa => Str,
);

sub run {
    my $self = shift;

  # check we are using a dedicated index, prompts if not
  # my $index = $self->index->name;
  # $self->are_you_sure(
  #     "Author script is run against a non-author specific index: $index !!!"
  # ) unless $index =~ /author/;

    $self->index_authors;
    $self->es->indices->refresh;
}

my @author_config_fields = qw(
    name
    asciiname
    profile
    blog
    perlmongers
    donation
    email
    website
    city
    region
    country
    location
    extra
);

my @cpan_fields = qw(
    pauseid
    name
    email
    website
    asciiname
    is_pause_custodial_account
);

my @compare_fields = do {
    my %seen;
    sort grep !$seen{$_}++, @cpan_fields, @author_config_fields;
};

has whois_data => (
    is      => 'ro',
    traits  => ['NoGetopt'],
    lazy    => 1,
    builder => '_build_whois_data',
);

sub _build_whois_data {
    my $self = shift;

    my $whois_data = {};

    my $xp = XML::XPath->new( filename => $self->author_fh );

    for my $author ( $xp->find('/cpan-whois/cpanid')->get_nodelist ) {
        my $data = {
            map +( $_->getLocalName, $_->string_value ),
            grep $_->isa('XML::XPath::Node::Element'),
            $author->getChildNodes
        };

        my $pauseid  = $data->{id};
        my $existing = $whois_data->{$pauseid};
        if (  !$existing
            || $existing->{type} eq 'author' && $data->{type} eq 'list' )
        {
            $whois_data->{$pauseid} = $data;
        }
    }

    return $whois_data;
}

sub index_authors {
    my $self    = shift;
    my $authors = $self->whois_data;

    if ( $self->pauseid ) {
        log_info {"Indexing 1 author"};
        $authors = { $self->pauseid => $authors->{ $self->pauseid } };
    }
    else {
        my $count = keys %$authors;
        log_debug {"Counting author"};
        log_info {"Indexing $count authors"};
    }

    my @author_ids_to_purge;

    my $bulk = $self->es->bulk_helper(
        es_doc_path('author'),
        max_count => 250,
        timeout   => '25m',
    );

    my $scroll = $self->es->scroll_helper(
        es_doc_path('author'),
        size => 500,
        body => {
            query => {
                $self->pauseid
                ? (
                    term => {
                        pauseid => $self->pauseid,
                    },
                    )
                : ( match_all => {} ),
            },
            _source => [@compare_fields],
            sort    => '_doc',
        },
    );

    # update authors
    while ( my $doc = $scroll->next ) {
        my $pauseid    = $doc->{_id};
        my $whois_data = delete $authors->{$pauseid} || next;
        $self->update_author( $bulk, $pauseid, $whois_data, $doc->{_source} );
    }

    # new authors
    for my $pauseid ( keys %$authors ) {
        my $whois_data = delete $authors->{$pauseid} || next;
        $self->update_author( $bulk, $pauseid, $whois_data );
    }

    $bulk->flush;
    $self->es->indices->refresh;

    $self->perform_purges;

    log_info {"done"};
}

sub author_data_from_cpan {
    my $self = shift;
    my ( $pauseid, $whois_data ) = @_;

    my $author_config = $self->author_config($pauseid) || {};

    my $data = {
        pauseid   => $pauseid,
        name      => $whois_data->{fullname},
        email     => $whois_data->{email},
        website   => $whois_data->{homepage},
        asciiname => $whois_data->{asciiname},
        %$author_config,
        is_pause_custodial_account => (
            ( $whois_data->{fullname} // '' )
            =~ /\(PAUSE Custodial Account\)/ ? true : false
        ),
    };

    undef $data->{name}
        if ref $data->{name};

    if ( !length $data->{name} ) {
        $data->{name} = $pauseid;
    }

    $data->{asciiname} = q{}
        if !defined $data->{asciiname};

    $data->{email} = lc($pauseid) . '@cpan.org'
        unless $data->{email} && Email::Valid->address( $data->{email} );

    $data->{website} = [

        # normalize www.homepage.com to http://www.homepage.com
        map +( $_->scheme ? '' : 'http://' ) . $_->as_string,
        map URI->new($_)->canonical,
        grep $_,
        map +( ref eq 'ARRAY' ? @$_ : $_ ),
        $data->{website}
    ];

    # Do not import lat / lon's in the wrong order, or just invalid
    if ( my $loc = $data->{location} ) {
        if ( ref $loc ne 'ARRAY' || @$loc != 2 ) {
            delete $data->{location};
        }
        else {
            my $lat = $loc->[1];
            my $lon = $loc->[0];

            if ( !defined $lat or $lat > 90 or $lat < -90 ) {

                # Invalid latitude
                delete $data->{location};
            }
            elsif ( !defined $lon or $lon > 180 or $lon < -180 ) {

                # Invalid longitude
                delete $data->{location};
            }
        }
    }

    return $data;
}

sub update_author {
    my $self = shift;
    my ( $bulk, $pauseid, $whois_data, $current_data ) = @_;

    my $data = $self->author_data_from_cpan( $pauseid, $whois_data );

    log_debug {
        Encode::encode_utf8( sprintf(
            "Indexing %s: %s <%s>",
            $pauseid, $data->{name}, $data->{email}
        ) );
    };

    # Now check the format we have is actually correct
    if ( my @errors = MetaCPAN::Document::Author->validate($data) ) {
        Dlog_error {
            "Invalid data for $pauseid: $_"
        }
        \@errors;
        return;
    }

    if ( my $diff = diff_struct( $current_data, $data, 1 ) ) {

        # log a sampling of differences
        if ( $self->has_surrogate_keys_to_purge % 10 == 9 ) {
            Dlog_debug {
                "Found difference in $pauseid: $_"
            }
            $diff;
        }
    }
    else {
        return;
    }

    $data->{updated} = DateTime->now( time_zone => 'UTC' )->iso8601;

    $bulk->update( {
        id            => $pauseid,
        doc           => $data,
        doc_as_upsert => true,
    } );

    $self->purge_author_key($pauseid);
}

sub author_config {
    my ( $self, $pauseid ) = @_;

    my $dir = $self->cpan->child( 'authors',
        MetaCPAN::Util::author_dir($pauseid) );

    return undef
        unless $dir->is_dir;

    my $author_cpan_files = $self->cpan_file_map->{$pauseid}
        or return undef;

    # Get the most recent version
    my ($file) = map $_->[0], sort { $b->[1] <=> $a->[1] }
        map [ $_ => $_->stat->mtime ],
        grep $author_cpan_files->{ $_->basename },
        $dir->children(qr/\Aauthor-.*\.json\z/);

    return undef
        unless $file;

    my $author;
    eval {
        $author = decode_json( $file->slurp_raw );
        1;
    } or do {
        log_warn {"$file is broken: $@"};
        return undef;
    };

    return {
        map {
            my $value = $author->{$_};
            defined $value ? ( $_ => $value ) : ()
        } @author_config_fields
    };
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
