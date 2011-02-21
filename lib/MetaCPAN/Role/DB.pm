package MetaCPAN::Role::DB;

use feature 'say';
use Moose::Role;
use DBI;
use Find::Lib;

has 'db_file' => (
    is         => 'rw',
    isa        => 'Str',
    lazy_build => 1,
);

has 'dsn' => (
    is         => 'rw',
    isa        => 'Str',
    lazy_build => 1,
);

has 'module_rs' => (
    is      => 'rw',
    lazy_build => 1,
);

has 'schema' => (
    is         => 'ro',
    lazy_build => 1,
);

has 'schema_class' => (
    is      => 'rw',
    default => 'MetaCPAN::Schema',
);

sub _build_dsn {

    my $self = shift;
    return "dbi:SQLite:dbname=" . $self->db_file;

}

sub _build_db_file {

    my $self   = shift;
    my @caller = caller();

    my $db_file = Find::Lib::base() . '/' . $self->db_path;

    if ( !-e $db_file ) {
        die "$db_file not found";
    }

    return $db_file;

}

sub _build_module_rs {
    
    my $self = shift;
    return my $rs = $self->schema->resultset( 'Module' );
    
}

sub _build_schema {

    my $self   = shift;
    my $schema = $self->schema_class->connect( $self->dsn, '', '', '',
        { sqlite_use_immediate_transaction => 1, AutoCommit => 1 } );

    #$schema->storage->dbh->sqlite_busy_timeout(0);
    return $schema;
}

1;

=pod

=head1 SYNOPSIS

Roles useful for accessing SQLite db

=cut
