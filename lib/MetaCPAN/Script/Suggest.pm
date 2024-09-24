package MetaCPAN::Script::Suggest;

use strict;
use warnings;

use Moose;

use DateTime                  ();
use Log::Contextual           qw( :log );
use MetaCPAN::Types::TypeTiny qw( Bool Int );

with 'MetaCPAN::Role::Script', 'MooseX::Getopt';

has days => (
    is            => 'ro',
    isa           => Int,
    default       => 1,
    documentation => 'number of days interval / back to cover.',
);

has all => (
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'update all records',
);

sub run {
    my $self = shift;

    if ( $self->all ) {
        my $dt       = DateTime->new( year => 1994, month => 1 );
        my $end_time = DateTime->now->add( months => 1 );

        while ( $dt < $end_time ) {
            my $gte = $dt->strftime("%Y-%m-%d");
            if ( my $d = $self->days ) {
                $dt->add( days => $d );
                log_info {"updating suggest data for $d days from: $gte"};
            }
            else {
                $dt->add( months => 1 );
                log_info {"updating suggest data for month: $gte"};
            }

            my $lt    = $dt->strftime("%Y-%m-%d");
            my $range = +{ range => { date => { gte => $gte, lt => $lt } } };
            $self->_update_slice($range);
        }
    }
    else {
        my $gte = DateTime->now()->subtract( days => $self->days )
            ->strftime("%Y-%m-%d");
        my $range = +{ range => { date => { gte => $gte } } };
        log_info {"updating suggest data since: $gte "};
        $self->_update_slice($range);
    }

    log_info {"done."};
}

sub _update_slice {
    my ( $self, $range ) = @_;

    my $files = $self->es->scroll_helper(
        index  => $self->index->name,
        type   => 'file',
        scroll => '5m',
        fields => [qw< id documentation >],
        size   => 500,
        body   => {
            query => {
                bool => {
                    must => [
                        { exists => { field => "documentation" } }, $range
                    ],
                },
            },
            sort => '_doc',
        },
    );

    my $bulk = $self->es->bulk_helper(
        index     => $self->index->name,
        type      => 'file',
        max_count => 250,
        timeout   => '5m',
    );

    while ( my $file = $files->next ) {
        my $documentation = $file->{fields}{documentation}[0];
        my $weight        = 1000 - length($documentation);
        $weight = 0 if $weight < 0;

        $bulk->update( {
            id  => $file->{fields}{id}[0],
            doc => {
                suggest => {
                    input   => [$documentation],
                    payload => { doc_name => $documentation },
                    weight  => $weight,
                }
            },
        } );
    }

    $bulk->flush;
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 SYNOPSIS

 # bin/metacpan suggest

=head1 DESCRIPTION

After importing releases from CPAN, this script will set the suggest
field for autocompletion searches.
