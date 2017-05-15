package MetaCPAN::Script::Role::External::Debian;

use Moose::Role;
use namespace::autoclean;

use CPAN::DistnameInfo ();
use DBI                ();

use MetaCPAN::Types qw( Str );

has _host_regex => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_host_regex',
);

sub _build_host_regex {
    my $self = shift;

    my @cpan_hosts = qw<
        backpan.cpan.org
        backpan.perl.org
        cpan.metacpan.org
        cpan.noris.de
        cpan.org
        cpan.perl.org
        search.cpan.org
        www.cpan.org
        www.perl.com
    >;

    return
        '^(https?|ftp)://('
        . join( '|', map {s/\./\\./r} @cpan_hosts ) . ')/';
}

sub run_debian {
    my $self = shift;
    my $ret  = {};

    # connect to the database
    my $dbh
        = DBI->connect(
        "dbi:Pg:host=public-udd-mirror.xvm.mit.edu;dbname=udd",
        'public-udd-mirror', 'public-udd-mirror' );

    # special cases
    my %skip = ( 'libbssolv-perl' => 1 );

    # multiple queries are needed
    my @sql = (

        # packages with upstream identified as CPAN
        q{select u.source, u.upstream_url from upstream_metadata um join upstream u on um.source = u.source where um.key='Archive' and um.value='CPAN'},

        # packages which upstream URL pointing to CPAN
        qq{select source, upstream_url from upstream where upstream_url ~ '${\$self->_host_regex}'},
    );

    my @failures;

    for my $sql (@sql) {
        my $sth = $dbh->prepare($sql);
        $sth->execute();

        # map Debian source package to CPAN distro
        while ( my ( $source, $url ) = $sth->fetchrow ) {
            next if $skip{$source};
            $self->dist_for( $source, $url );
            if ( my $dist = $self->dist_for( $source, $url ) ) {
                $ret->{dist}{$dist} = $source;
            }
            else {
                push @failures => [ $source, $url ];
            }
        }
    }

    if (@failures) {
        my $ret->{errors_email_body} = join "\n" =>
            map { sprintf "%s %s", $_->[0], $_->[1] // '<undef>' } @failures;
    }

    return $ret;
}

sub dist_for {
    my ( $self, $source, $url ) = @_;

    my %alias = (
        'datapager'   => 'data-pager',
        'html-format' => 'html-formatter',
    );

    my $dist = CPAN::DistnameInfo->new($url);
    if ( $dist->dist ) {
        return $dist->dist;
    }
    elsif ( $source =~ /^lib(.*)-perl$/ ) {
        my $query
            = { term => { 'distribution.lowercase' => $alias{$1} // $1 } };

        my $res = $self->index->type('release')->filter($query)
            ->sort( [ { date => { order => "desc" } } ] )->raw->first;

        return $res->{_source}{distribution}
            if $res;
    }

    return;
}

1;
