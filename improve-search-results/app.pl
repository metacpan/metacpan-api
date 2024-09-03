use Mojolicious::Lite;

use Mojo::Pg;
use List::Util qw( first );

my $user = getpwuid($<);    # for vagrant user on dev box

# carton exec /opt/perl-5.22.2/bin/perl ./app.pl daemon -m production -l http://*:5000

helper pg => sub { state $pg = Mojo::Pg->new("postgresql:///${user}") };

app->pg->auto_migrate(1)->migrations->from_data;

helper insert_search => sub {
    my ( $c, $search, $expect ) = @_;
    return !!$c->pg->db->query( <<'  SQL', $search, $expect )->rows;
    insert into searches (search, expect) values (?, ?)
  SQL
};

helper insert_source => sub {
    my ( $c, $name, $query ) = @_;
    return !!$c->pg->db->query( <<'  SQL', $name, $query )->rows;
    insert into sources (name, query) values (?, ?, ?)
  SQL
};

helper get_results => sub {
    my $c = shift;
    return $c->pg->db->query(<<'  SQL')->expand->hash->{results};
    select json_object_agg(search, results) as results
    from (
      select
        searches.search,
        json_object_agg(sources.name, results.rank) as results
      from results
      inner join searches on searches.id = results.search_id
      inner join sources  on sources.id  = results.source_id
      group by searches.search
    ) x
  SQL
};

helper perform_all_searches => sub {
    my ($c) = @_;
    my $queries = $c->pg->db->query(<<'  SQL');
    select
      searches.id as search_id,
      sources.id as source_id,
      searches.search,
      searches.expect,
      sources.name,
      results.rank
    from searches
    cross join sources
    left join results on searches.id = results.search_id
      and sources.id = results.source_id
  SQL
    my $db = $c->pg->db;
    my $sql
        = 'insert into results (search_id, source_id, rank) values (?, ?, ?)';
    $queries->hashes->each( sub {
        my $query = shift;
        return if $query->{rank};
        my $rank = $c->perform_one_search(
            @{$query}{qw/search expect name query/} );
        $db->query( $sql, @{$query}{qw/search_id source_id/}, $rank );
    } );
};

helper perform_one_search => sub {
    my ( $c, $search, $expect, $name, $query ) = @_;

    my $rank
        = $name eq 'SCO'  ? _perform_sco( $c, $search, $expect )
        : $name eq 'MWEB' ? _perform_mweb( $c, $search, $expect )
        :                   _perform_mquery( $c, $search, $expect, $query );

    return $rank // 100;
};

sub _perform_sco {
    my ( $c, $search, $expect ) = @_;
    my $url = Mojo::URL->new('http://search.cpan.org/search?mode=all&n=100');
    $url->query( [ query => $search ] );
    my $tx  = $c->app->ua->get($url);
    my $res = $tx->res->dom->find('.sr')->map('all_text')->to_array;
    my $idx = first { $res->[$_] eq $expect } @{ $res->to_array };
    return $idx < 0 ? undef : $idx + 1;
}

sub _perform_mweb {
    my ( $c, $search, $expect ) = @_;
    my $url = Mojo::URL->new('https://metacpan.org/search?size=100');
    $url->query( [ q => $search ] );
    my $tx = $c->app->ua->get($url);
    my $res
        = $tx->res->dom->find('.module-result big strong a')->map('all_text')
        ->to_array;
    my $idx = first { $res->[$_] eq $expect } 0 .. $#{$res};
    return $idx < 0 ? undef : $idx + 1;
}

sub _perform_mquery { }

get '/' => 'index';

get '/results' => sub {
    my $c = shift;
    $c->render( json => $c->get_results );
};

app->start;

__DATA__

@@ index.html.ep

<%== perform_all_searches  %>

<!DOCTYPE html>
<html>
  <head lang="en">
    <meta charset="utf-8"/>
    <title>MetaCPAN Search Comparison</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.1.1/jquery.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.4.0/Chart.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/lodash.js/4.17.2/lodash.min.js"></script>
  </head>
  <body>
    <canvas id="chart" height="400" width="800"></canvas>
    <script>
      function djb2(str){
        var hash = 5381;
        for (var i = 0; i < str.length; i++) {
          hash = ((hash << 5) + hash) + str.charCodeAt(i); /* hash * 33 + c */
        }
        return hash;
      }

      function hashStringToColor(str) {
        var hash = djb2(str);
        var r = (hash & 0xFF0000) >> 16;
        var g = (hash & 0x00FF00) >> 8;
        var b = hash & 0x0000FF;
        return "#" + ("0" + r.toString(16)).substr(-2) + ("0" + g.toString(16)).substr(-2) + ("0" + b.toString(16)).substr(-2);
      }

      var ctx = document.getElementById('chart').getContext('2d');
      var chartData;
      $.get('<%= url_for 'results' %>', function(data) {
        chartData = {
          labels: [],
          datasets: [],
        };
        var datasets = {};
        _.each(_.keys(data).sort(), function(name) {
          chartData.labels.push(name);
          var search = data[name];
          _.each(_.keys(search).sort(), function(source) {
            datasets[source] = datasets[source] || {label: source, 'data': [], backgroundColor: hashStringToColor(source)};
            datasets[source].data.push(search[source]);
          });
        });
        _.each(_.keys(datasets).sort(), function(source) { chartData.datasets.push(datasets[source]) });
        var chart = new Chart(ctx, {
          type: 'bar',
          data: chartData,
          options: {
            scales: {
              yAxes: [{
                ticks: {
                  beginAtZero:true
                }
              }]
            }
          }
        });
      });
    </script>
  </body>
</html>

@@ migrations

-- 1 up

create table searches (
  id bigserial primary key,
  search text not null unique,
  expect text not null
);
insert into searches (search, expect) values
('tmpfile', 'File::Temp'),
('path', 'Path::Tiny'),
('dbix', 'DBIx::Class'),
('uri', 'URI');

create table sources (
  id bigserial primary key,
  name text not null unique,
  query text
);
insert into sources (name) values ('SCO'), ('MWEB');

create table results (
  id bigserial primary key,
  search_id bigint references searches on delete cascade,
  source_id bigint references sources  on delete cascade,
  rank integer
);

-- 1 down

drop table if exists searches cascade;
drop table if exists sources  cascade;
drop table if exists results  cascade;
