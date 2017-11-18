package MetaCPAN::Query::Permission;

use MetaCPAN::Moose;

use Ref::Util qw( is_arrayref );

with 'MetaCPAN::Query::Role::Common';

sub by_author {
    my ( $self, $pauseid ) = @_;

    my $body = {
        query => {
            bool => {
                should => [
                    { term => { owner          => $pauseid } },
                    { term => { co_maintainers => $pauseid } },
                ],
            },
        },
        size => 5_000,
    };

    my $ret = $self->es->search(
        index => $self->index_name,
        type  => 'permission',
        body  => $body,
    );
    return unless $ret->{hits}{total};

    my $data = [
        sort { $a->{module_name} cmp $b->{module_name} }
        map  { $_->{_source} } @{ $ret->{hits}{hits} }
    ];

    return { permissions => $data };
}

sub by_modules {
    my ( $self, $modules ) = @_;
    $modules = [$modules] unless is_arrayref($modules);

    my @modules = map +{ term => { module_name => $_ } },
        grep defined, @{$modules};
    return unless @modules;

    my $body = {
        query => {
            bool => { should => \@modules }
        },
        size => 1_000,
    };

    my $ret = $self->es->search(
        index => $self->index_name,
        type  => 'permission',
        body  => $body,
    );
    return unless $ret->{hits}{total};

    my $data = [
        sort { $a->{module_name} cmp $b->{module_name} }
        map  { $_->{_source} } @{ $ret->{hits}{hits} }
    ];

    return { permissions => $data };
}

__PACKAGE__->meta->make_immutable;
1;
