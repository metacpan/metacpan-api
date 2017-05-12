package MetaCPAN::Script::Debian;

use Moose;
use namespace::autoclean;

use CPAN::DistnameInfo;
use DBI                   ();
use Email::Sender::Simple ();
use Email::Simple         ();
use List::MoreUtils qw( uniq );

use MetaCPAN::Types qw( HashRef Str );

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has email_to => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

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

sub run {
    my $self = shift;

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

    my %dist;
    my @failures;

    for my $sql (@sql) {
        my $sth = $dbh->prepare($sql);
        $sth->execute();

        # map Debian source package to CPAN distro
        while ( my ( $source, $url ) = $sth->fetchrow ) {
            next if $skip{$source};
            $self->dist_for( $source, $url );
            if ( my $dist = $self->dist_for( $source, $url ) ) {
                $dist{$dist} = $source;
            }
            else {
                push @failures => [ $source, $url ];
            }
        }
    }

    if (@failures) {
        my $email_body = join "\n" =>
            map { sprintf "%s %s", $_->[0], $_->[1] // '<undef>' } @failures;

        my $email = Email::Simple->create(
            header => [
                'Content-Type' => 'text/plain; charset=utf-8',
                To             => $self->email_to,
                From           => 'noreply@metacpan.org',
                Subject        => 'Debian package mapping failures report',
                'MIME-Version' => '1.0',
            ],
            body => $email_body,
        );
        Email::Sender::Simple->send($email);
    }

    my $bulk = $self->es->bulk_helper(
        index => $self->index->name,
        type  => 'distribution',
    );

    for my $d ( keys %dist ) {
        my $exists = $self->es->exists(
            index => $self->index->name,
            type  => 'distribution',
            id    => $d,
        );
        next unless $exists;

        $bulk->update(
            {
                id  => $d,
                doc => +{
                    'external_package' => {
                        debian => $dist{$d}
                    }
                }
            }
        );
    }

    $bulk->flush;
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

        my $res = $self->index->type('release')->filter($query)->raw->all;
        return $res->{hits}{hits}[0]{_source}{distribution}
            if exists $res->{hits}{hits} and @{ $res->{hits}{hits} } == 1;
    }

    return;
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

http://api.metacpan.org/distribution/Moose
http://api.metacpan.org/distribution/HTTP-BrowserDetect

=cut

