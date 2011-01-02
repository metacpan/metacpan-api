package MetaCPAN::Schema;
use base qw/DBIx::Class::Schema::Loader/;

__PACKAGE__->loader_options(
#    constraint              => '^foo.*',
    debug                   => 0,
);

__PACKAGE__->naming('current');
__PACKAGE__->use_namespaces(1);

1;

=pod

=head1 SYNOPSIS

Autoload schema for SQLite db

=cut
