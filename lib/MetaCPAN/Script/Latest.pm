package MetaCPAN::Script::Latest;

use feature qw(say);
use Moose;
use MooseX::Aliases;
with 'MooseX::Getopt';
use Log::Contextual qw( :log );
with 'MetaCPAN::Role::Common';

has dry_run => ( is => 'ro', isa => 'Bool', default => 0 );
has distribution => ( is => 'ro', isa => 'Str' );

sub run {
    my $self = shift;
    my $es   = $self->es;
    log_info { "Dry run: updates will not be written to ES" }
    if ( $self->dry_run );
    $es->refresh_index();
    my $query =
      $self->distribution
      ? { term => { distribution => $self->distribution } }
      : { match_all => {} };
    my $scroll = $es->scrolled_search({ index => $self->index->name,
                   type   => 'release',
                   query  => $query,
                   scroll => '1h',
                   size => 1000,
                   sort   => ['distribution',
                             { maturity => { reverse => \1 } },
                             { date     => { reverse => \1 } }
                   ], });

    my $dist = '';
    while ( my $row = $scroll->next(1) ) {
        if ( $dist ne $row->{_source}->{distribution} ) {
            $dist = $row->{_source}->{distribution};
            next if ( $row->{_source}->{status} eq 'latest' );
            log_info { "Upgrading $row->{_source}->{name} to latest" };

            for (qw(file dependency)) {
                log_debug { "Upgrading $_" };
                $self->reindex( $_, $row->{_id}, 'latest' );
            }
            next if ( $self->dry_run );
            $es->index( index => $self->index->name,
                        type  => 'release',
                        id    => $row->{_id},
                        data  => { %{ $row->{_source} }, status => 'latest' } );
        } elsif ( $row->{_source}->{status} eq 'latest' ) {
            log_info { "Downgrading $row->{_source}->{name} to cpan" };

            for (qw(file dependency)) {
                log_debug { "Downgrading $_" };
                $self->reindex( $_, $row->{_id}, 'cpan' );
            }
            next if ( $self->dry_run );
            $es->index( index => $self->index->name,
                        type  => 'release',
                        id    => $row->{_id},
                        data  => { %{ $row->{_source} }, status => 'cpan' } );

        }
    }
}

sub reindex {
    my ( $self, $type, $release, $status ) = @_;
    my $es = $self->es;
    my $scroll = $es->scrolled_search({ 
        index => $self->index->name,
        type  => $type,
        scroll => '1h',
        size => 1000,
        search_type => 'scan',
        query => { term => { release => $release } } });
    while ( my $row = $scroll->next(1) ) {
        log_debug {
            $status eq 'latest' ? "Upgrading " : "Downgrading ",
              $type, " ", $row->{_source}->{name} || '';
        };
        $es->index( index => $self->index->name,
                    type  => $type,
                    id    => $row->{_id},
                    data  => { %{ $row->{_source} }, status => $status }
        ) unless ( $self->dry_run );
    }

}

__PACKAGE__->meta->make_immutable;

__END__

=head1 SYNOPSIS

 # bin/metacpan latest

 # bin/metacpan latest --dry_run
 
=head1 DESCRIPTION

After importing releases from cpan, this script will set the status
to latest on the most recent release, its files and dependencies.
It also makes sure that there is only one latest release per distribution.
