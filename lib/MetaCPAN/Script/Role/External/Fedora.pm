package MetaCPAN::Script::Role::External::Fedora;

use v5.010;
use Moose::Role;
use namespace::autoclean;

use URI;
use JSON qw( decode_json );
use Log::Contextual qw( :log );

sub run_fedora {
    my $self = shift;
    my $ret  = {};
    my @packages;

    my $uri = URI->new('https://admin.fedoraproject.org/pkgdb/api/packages/');
    my $options = {
        page  => 1,     # start at the beginning
        limit => 500,   # max, says https://admin.fedoraproject.org/pkgdb/api/
        status => 'Approved',
    };
    my $total = 1;

    # loop over the results to build @packages
    while ( $options->{page} <= $total ) {
        $uri->query_form($options);
        log_debug {"Fetching $uri"};
        my $res = $self->ua->get($uri);
        die "Failed to fetch $uri: " . $res->status_line if !$res->is_success;
        my $pkgdb = decode_json $res->decoded_content;
        push @packages, @{ $pkgdb->{packages} };
        $total = $pkgdb->{page_total};
        $options->{page}++;
    }

    # known special cases
    my %skip = map +( $_ => 1 ), qw(
        perl-ccom
        perl-BSSolv
        perl-Cflow
        perl-Fedora-VSP
        perl-DepGen-Perl-Tests
        perl-Fedora-Rebuild
        perl-generators
        perl-libwhisker2
        perl-mecab
        perl-perlmenu
        perl-PBS
        perl-Razor-Agent
        perl-RPM-VersionCompare
        perl-ServiceNow-API
        perl-Sys-Virt-TCK
        perl-Satcon
        perl-SNMP_Session
        perl-srpm-macros
        perl-qooxdoo-compat
        perl-WWW-OrangeHRM-Client
    );

    my @failures;
    for my $pkg (@packages) {
        my ( $source, $url ) = ( $pkg->{name}, $pkg->{upstream_url} );
        next if $skip{$source};
        if ( my $dist = $self->dist_for_fedora( $source, $url ) ) {
            $ret->{dist}{$dist} = $source;
        }
        else { push @failures => [ $source, $url ]; }
    }

    if (@failures) {
        my $ret->{errors_email_body} = join "\n" =>
            map { sprintf "%s %s", $_->[0], $_->[1] // '<undef>' } @failures;
    }

    log_debug {
        sprintf "Found %d Fedora-CPAN packages",
            scalar keys %{ $ret->{dist} }
    };

    return $ret;
}

sub dist_for_fedora {
    my ( $self, $source, $url ) = @_;
    state $dist_re = qr{https?://
                        (?:(?:www\.)?metacpan\.org/release
                             |search\.cpan\.org/(?:dist|~\w+))
                        /([^/]+)/?}x;

    if ( $url =~ $dist_re ) {
        return $1;
    }
    elsif ( $source =~ /^perl-(.*)/ ) {
        print "ES search for $source / $1\n";
        my $query = { term => { 'distribution.lowercase' => $1 } };

        my $res = $self->index->type('release')->filter($query)
            ->sort( [ { date => { order => "desc" } } ] )->raw->first;

        return $res->{_source}{distribution}
            if $res;
    }

    return;
}

1;
