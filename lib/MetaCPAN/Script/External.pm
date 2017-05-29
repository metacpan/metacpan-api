package MetaCPAN::Script::External;

use Moose;
use namespace::autoclean;

use Email::Sender::Simple ();
use Email::Simple         ();
use Log::Contextual qw( :log );

use MetaCPAN::Types qw( Str );

with 'MetaCPAN::Role::Script', 'MooseX::Getopt',
    'MetaCPAN::Script::Role::External::Cygwin',
    'MetaCPAN::Script::Role::External::Debian',
    'MetaCPAN::Script::Role::External::Fedora';

has external_source => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has email_to => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

sub run {
    my $self = shift;
    my $ret;

    $ret = $self->run_cygwin if $self->external_source eq 'cygwin';
    $ret = $self->run_debian if $self->external_source eq 'debian';
    $ret = $self->run_fedora if $self->external_source eq 'fedora';

    my $email_body = $ret->{errors_email_body};
    if ($email_body) {
        my $email = Email::Simple->create(
            header => [
                'Content-Type' => 'text/plain; charset=utf-8',
                To             => $self->email_to,
                From           => 'noreply@metacpan.org',
                Subject        => 'Package mapping failures report for '
                    . $self->external_source,
                'MIME-Version' => '1.0',
            ],
            body => $email_body,
        );
        Email::Sender::Simple->send($email);

        log_debug { "Sending email to " . $self->email_to . ":" };
        log_debug {"Email body:"};
        log_debug {$email_body};
    }

    $self->update( $ret->{dist} );
}

sub update {
    my ( $self, $dist ) = @_;
    my $external_source = $self->external_source;

    my $scroll = $self->es->scroll_helper(
        index  => $self->index->name,
        type   => 'distribution',
        scroll => '10m',
        body   => {
            query => {
                exists => { field => "external_package." . $external_source }
            }
        },
    );

    my @to_remove;

    while ( my $s = $scroll->next ) {
        my $name = $s->{_source}{name};

        if ( exists $dist->{$name} ) {
            delete $dist->{$name}
                if $dist->{$name} eq
                $s->{_source}{external_package}{$external_source};
        }
        else {
            push @to_remove => $name;
        }
    }

    my $bulk = $self->es->bulk_helper(
        index => $self->index->name,
        type  => 'distribution',
    );

    for my $d ( keys %{$dist} ) {
        my $exists = $self->es->exists(
            index => $self->index->name,
            type  => 'distribution',
            id    => $d,
        );
        next unless $exists;

        log_debug {"[$external_source] adding $d"};
        $bulk->update(
            {
                id  => $d,
                doc => +{
                    'external_package' => {
                        $external_source => $dist->{$d}
                    }
                }
            }
        );
    }

    for my $d (@to_remove) {
        log_debug {"[$external_source] removing $d"};
        $bulk->update(
            {
                id  => $d,
                doc => +{
                    'external_package' => {
                        $external_source => undef
                    }
                }
            }
        );
    }

    $bulk->flush;
}

__PACKAGE__->meta->make_immutable;

1;

=pod

=head1 SYNOPSIS

 # bin/metacpan external --external_source SOURCE

=cut

