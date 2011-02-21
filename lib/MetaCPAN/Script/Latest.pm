package MetaCPAN::Script::Latest;

use feature qw(say);
use Moose;
use MooseX::Aliases;
with 'MooseX::Getopt';
use MetaCPAN;

has 'dry_run' => ( is => 'ro', isa => 'Bool', default => 0 );
has verbose => ( is => 'ro', isa => 'Bool', default => 0 );
has es => ( is => 'ro', default => sub { MetaCPAN->new->es } );

sub run {
    my $self = shift;
    my $es   = $self->es;
    say "Dry run: updates will not be written to ES"
      if ( $self->dry_run );
    my $search = { index  => 'cpan',
                   type   => 'release',
                   query  => { match_all => {} },
                   scroll => '1h',
                   size   => 100,
                   from => 0,
                   sort   => [ 'distribution', { date => { reverse => \1 } } ],
    };

    my $dist = '';
    my $rs   = $es->search(%$search);
    while ( my $row = shift @{ $rs->{hits}->{hits} } ) {
        if ( $dist ne $row->{_source}->{distribution} ) {
            $dist = $row->{_source}->{distribution};
            next if ( $row->{_source}->{status} eq 'latest' );
            say "Upgrading $row->{_source}->{name} to latest";
            say "Upgrading files ..." if($self->verbose);
            $self->reindex( 'file', $row->{_id}, 'latest' );
            say "Upgrading modules ..." if($self->verbose);
            $self->reindex( 'module', $row->{_id}, 'latest' );
            next if ( $self->dry_run );
            $es->index( index => 'cpan',
                        type  => 'release',
                        id    => $row->{_id},
                        data  => { %{ $row->{_source} }, status => 'latest' } );
        } elsif ( $row->{_source}->{status} eq 'latest' ) {
            say "Downgrading $row->{_source}->{name} to cpan";
            say "Downgrading files ..." if($self->verbose);
            $self->reindex( 'file', $row->{_id}, 'cpan' );
            say "Downgrading modules ..." if($self->verbose);
            $self->reindex( 'module', $row->{_id}, 'cpan' );
            next if ( $self->dry_run );
            $es->index( index => 'cpan',
                        type  => 'release',
                        id    => $row->{_id},
                        data  => { %{ $row->{_source} }, status => 'cpan' } );
        }
        unless ( @{ $rs->{hits}->{hits} } ) {
            $search = { %$search, from => $search->{from} + $search->{size} };
            $rs = $es->search($search);
        }
    }
}

sub reindex {
    my ( $self, $type, $release, $status ) = @_;
    my $es = $self->es;
    my $search = { index => 'cpan',
                   type  => $type,
                   query => { term => { release => $release } },
                   sort  => ['_id'],
                   size  => 10,
                   from  => 0, };
    my $rs = $es->search(%$search);
    while ( my $row = shift @{ $rs->{hits}->{hits} } ) {
        say $status eq 'latest' ? "Upgrading " : "Downgrading ",
          $type, " ", $row->{_source}->{name} if($self->verbose);
        $es->index( index => 'cpan',
                    type  => $type,
                    id    => $row->{_id},
                    data  => { %{ $row->{_source} }, status => $status }
        ) unless ( $self->dry_run );
        unless ( @{ $rs->{hits}->{hits} } ) {
            $search = { %$search, from => $search->{from} + $search->{size} };
            $rs = $es->search($search);
        }
    }

}

__PACKAGE__->meta->make_immutable;

__END__

=head1 SYNOPSIS

 # bin/metacpan latest

 # bin/metacpan latest --dry-run
 
=head1 DESCRIPTION

After running an import from cpan, this script will set the status
to latest on the most recent release, its files and modules.
It also makes sure that there is only one latest release per distribution.
