package MetaCPAN::Extract::MetaIndex;

use Moose;

with 'MetaCPAN::Extract::Role::DB';

use Data::Dump qw( dump );
use MetaCPAN::Extract::Meta::Schema;
use Modern::Perl;

has 'db_path' => (
    is      => 'rw',
    isa     => 'Str',
    default => '../CPAN-meta.sqlite',
);




1;

=pod

=head2 populate

Take the results of pkg_index and bulk insert them into the sqlite db.

=cut
