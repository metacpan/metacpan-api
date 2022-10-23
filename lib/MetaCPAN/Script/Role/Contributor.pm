package MetaCPAN::Script::Role::Contributor;

use Moose::Role;

use MetaCPAN::Util qw( digest );
use Ref::Util      qw( is_arrayref );

sub get_cpan_author_contributors {
    my ( $self, $author, $release, $distribution ) = @_;
    my @ret;
    my $es = $self->es;

    my $type = $self->index->type('release');
    my $data;
    eval {
        $data = $type->get_contributors( $author, $release );
        1;
    } or return [];

    for my $d ( @{ $data->{contributors} } ) {
        next unless exists $d->{pauseid};

        # skip existing records
        my $id     = digest( $d->{pauseid}, $release );
        my $exists = $es->exists(
            index => 'contributor',
            type  => 'contributor',
            id    => $id,
        );
        next if $exists;

        $d->{release_author} = $author;
        $d->{release_name}   = $release;
        $d->{distribution}   = $distribution;
        push @ret, $d;
    }

    return \@ret;
}

sub update_release_contirbutors {
    my ( $self, $data, $timeout ) = @_;
    return unless $data and is_arrayref($data);

    my $bulk = $self->es->bulk_helper(
        index   => 'contributor',
        type    => 'contributor',
        timeout => $timeout || '5m',
    );

    for my $d ( @{$data} ) {
        my $id = digest( $d->{pauseid}, $d->{release_name} );
        $bulk->update( {
            id  => $id,
            doc => {
                pauseid        => $d->{pauseid},
                release_name   => $d->{release_name},
                release_author => $d->{release_author},
                distribution   => $d->{distribution},
            },
            doc_as_upsert => 1,
        } );
    }

    $bulk->flush;
}

no Moose::Role;
1;
