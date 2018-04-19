package MetaCPAN::Script::River;

use Moose;
use namespace::autoclean;

use Cpanel::JSON::XS qw( decode_json );
use Log::Contextual qw( :log :dlog );
use MetaCPAN::Types qw( ArrayRef Str Uri);
use Mojo::Pg;
use Term::ProgressBar;
use Parse::CPAN::Packages::Fast;

# copied from lib/MetaCPAN/Document/File/Set.pm
my @ROGUE_DISTRIBUTIONS = qw(
    Bundle-Everything
    kurila
    perl-5.005_02+apache1.3.3+modperl
    perlbench
    perl_debug
    pod2texi
    spodcxx
);

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has river_url => (
    is       => 'ro',
    isa      => Uri,
    coerce   => 1,
    required => 1,
    default  => 'http://neilb.org/river-of-cpan.json.gz',
);

has packages => (
    is      => 'ro',
    isa     => 'Parse::CPAN::Packages::Fast',
    builder => '_build_packages',
);

has pg => (
    is      => 'ro',
    isa     => 'Mojo::Pg',
    builder => '_build_pg',
);

sub _build_pg {
    my $pg = Mojo::Pg->new('postgresql:///river_data');
    $pg->migrations->name('river')->from_data;
    return $pg;
}

sub _build_packages {
    my $file = '/home/vagrant/CPAN/modules/02packages.details.txt.gz';
    die 'No 02packages file' unless -r $file;
    Parse::CPAN::Packages::Fast->new($file);
}

sub run {
    my $self = shift;

    $self->pg->migrations->migrate;

    #my $depends = $self->deep_depends('Catalyst-Runtime-5.90115');
    #print $depends->{depends} . "\n";

    #$self->pg->migrations->migrate(0)->migrate;
    #$self->import_release_data;
    #$self->import_module_data;

    #my $summaries = $self->retrieve_river_summaries;
    #$self->index_river_summaries($summaries);

    return 1;
}

sub deep_depends {
    my $self = shift;
    my $db   = $self->pg->db;
    return $db->query( <<'    SQL', shift )->hash || {};
      select name, json_agg(depends_on) as depends_on
      from release_deep_depends_on_release
      where name = ?
      group by name
    SQL
}

sub import_module_data {
    my $self = shift;
    warn 'Importing 02packages';

    my $res = $self->pg->db->query(
        'select distinct depends_on as module from release_depends');

    my $found    = $res->hashes->map( sub { $_->{module} } );
    my $total    = @$found;
    my $progress = Term::ProgressBar->new($total);
    my $i        = 0;

    my $packages = $self->packages;
    my $db       = $self->pg->db;
    foreach my $module (@$found) {
        my $package = $packages->package($module);
        warn "No info for $module\n" && next unless $package;
        my $dist = $package->distribution;
        $db->query( <<'      SQL', $module, $dist->dist, $dist->cpanid );
        insert into
          release_provides (release, provides)
        select
          id, ?
          from release
          where dist = ? and author = ?
        on conflict (release, provides) do nothing
      SQL
        $progress->update( ++$i );
    }

    $progress->update($total);
}

sub update_views {
    my $self = shift;
    my $db   = $self->pg->db;

    $db->query('refresh materialized view release_depends_on_release');
    $db->query('refresh materialized view release_deep_depends_on_release');
}

sub import_release_data {
    my $self = shift;
    warn 'Importing releases';

    my $scroll = $self->es->scroll_helper(
        index       => $self->index->name,
        type        => 'release',
        search_type => 'scan',
        body        => {
            query => {
                bool => {
                    must => [
                        { term => { authorized => 1 } },
                        { term => { status     => 'latest' } },
                    ],
                    must_not => [
                        {
                            terms => { distribution => \@ROGUE_DISTRIBUTIONS }
                        },
                    ],
                }
            },
        },
    );

    my $total    = $scroll->total;
    my $progress = Term::ProgressBar->new($total);
    my $i        = 0;

    my $db = $self->pg->db;
    while ( my $rec = $scroll->next ) {
        my $release = $rec->{_source};
        my $id      = $db->query(
            'insert into release (author, name, dist) values (?,?,?) returning id',
            @{$release}{qw/author name distribution/}
        )->hash->{id};
        for my $dep ( @{ $release->{dependency} } ) {
            $db->query(
                'insert into release_depends (release, depends_on) values (?, ?)',
                $id, $dep->{module}
            );
        }
        $progress->update( ++$i );
    }

    $scroll->finish;
    $progress->update($total);
}

sub index_river_summaries {
    my ( $self, $summaries ) = @_;

    my $bulk = $self->es->bulk_helper(
        index => $self->index->name,
        type  => 'distribution',
    );

    for my $summary ( @{$summaries} ) {
        my $dist = delete $summary->{dist};

        $bulk->update(
            {
                id  => $dist,
                doc => {
                    name  => $dist,
                    river => $summary,
                },
                doc_as_upsert => 1,
            }
        );
    }
    $bulk->flush;
}

sub retrieve_river_summaries {
    my $self = shift;

    my $resp = $self->ua->get( $self->river_url );

    $self->handle_error( $resp->status_line ) unless $resp->is_success;

    # cleanup headers if .json.gz is served as gzip type
    # rather than json encoded with gzip
    if ( $resp->header('Content-Type') eq 'application/x-gzip' ) {
        $resp->header( 'Content-Type'     => 'application/json' );
        $resp->header( 'Content-Encoding' => 'gzip' );
    }

    return decode_json $resp->decoded_content;
}

__PACKAGE__->meta->make_immutable;

1;

=pod

=head1 SYNOPSIS

 # bin/metacpan river

=head1 DESCRIPTION

Retrieves the CPAN river data from its source and
updates our ES information.

This can then be accessed here:

http://fastapi.metacpan.org/v1/distribution/Moose
http://fastapi.metacpan.org/v1/distribution/HTTP-BrowserDetect

=cut

__DATA__

@@ river

-- 1 up

create table if not exists release (
  id bigserial primary key,
  author text not null,
  name text not null,
  dist text not null,
  unique (author, name)
);

create table if not exists release_depends (
  id bigserial primary key,
  release bigint references release,
  depends_on text not null
);

create table if not exists release_provides (
  id bigserial primary key,
  release bigint references release,
  provides text not null,
  unique (release, provides)
);

create materialized view if not exists
  release_depends_on_release (name, depends_on) as (
    select release.name, provided_by.name
      from release
      join release_depends on release.id=release_depends.release
      join release_provides on release_depends.depends_on=release_provides.provides
      join release provided_by on release_provides.release=provided_by.id
);

create or replace function
deep_dependencies_of (_release text) returns setof text
as $$
  with recursive deep_depends (name, depends_on) as (
    select name, depends_on from release_depends_on_release
      where name = _release
    union
    select deep_depends.name, direct.depends_on
      from deep_depends
      join release_depends_on_release direct on deep_depends.depends_on=direct.name
      where deep_depends.name != direct.depends_on
  )
  select depends_on from deep_depends
$$ language sql;

create materialized view if not exists
  deep_reverse_dependencies (name, depended_on_by) as (
    with recursive deep_depends (name, depended_on_by) as (
      select depends_on, name from release_depends_on_release
      union
      select direct.depends_on, deep_depends.depended_on_by,
        from deep_depends
        join release_depends_on_release direct on deep_depends.depends_on=direct.name
        where deep_depends.depended_on_by != direct.depends_on
    )
    select depends_on from deep_depends
);


-- 1 down

drop table if exists release_provides cascade;
drop table if exists release_depends cascade;
drop table if exists release cascade;

