package MetaCPAN::Script::Role::External::Cygwin;

use Moose::Role;
use namespace::autoclean;

use List::Util qw( shuffle );
use Log::Contextual qw( :log );

use MetaCPAN::Types qw( ArrayRef Int );

has mirrors => (
    is      => 'ro',
    isa     => ArrayRef,
    lazy    => 1,
    builder => '_build_mirrors',
);

has mirror_timeout => (
    is      => 'ro',
    isa     => Int,
    default => 10,
);

sub _build_mirrors {
    my ($self) = @_;

    log_debug {"Fetching mirror list"};
    my $res = $self->ua->get('https://cygwin.com/mirrors.lst');
    die "Failed to fetch mirror list: " . $res->status_line
        unless $res->is_success;
    my @mirrors = shuffle map +( split /;/ )[0], split /\n/,
        $res->decoded_content;

    log_debug { sprintf "Got %d mirrors", scalar @mirrors };
    return \@mirrors;
}

sub run_cygwin {
    my ($self) = @_;
    my $ret = {};

    my @mirrors = @{ $self->mirrors };
    my $timeout = $self->ua->timeout( $self->mirror_timeout );
MIRROR: {
        my $mirror = shift @mirrors or die "Ran out of mirrors";
        log_debug {"Trying mirror: $mirror"};
        my $res = $self->ua->get( $mirror . 'x86_64/setup.ini' );
        redo MIRROR unless $res->is_success;

        my @packages = split /^\@ /m, $res->decoded_content;
        shift @packages;    # drop headers

        log_debug { sprintf "Got %d cygwin packages", scalar @packages };

        for my $desc (@packages) {
            next if substr( $desc, 0, 5 ) ne 'perl-';
            my ( $pkg, %attr ) = map s/\A"|"\z//gr, map s/ \z//r,
                map s/\n+/ /gr, split /^([a-z]+): /m, $desc;
            $attr{category} = [ split / /, $attr{category} ];
            next if grep /^(Debug|_obsolete)$/, @{ $attr{category} };
            $ret->{ $pkg =~ s/^perl-//r } = $pkg;
        }
    }
    $self->ua->timeout($timeout);

    log_debug { sprintf "Found %d cygwin-CPAN packages", scalar keys %$ret };

    return $ret;
}

1;
