package MetaCPAN::Script::Snapshot;

use strict;
use warnings;

use Cpanel::JSON::XS qw(encode_json decode_json);
use DateTime ();
use DDP;
use HTTP::Tiny ();
use Log::Contextual qw( :log );
use MetaCPAN::Types qw( Bool Int Str File ArrayRef );
use Moose;
use Sys::Hostname qw(hostname);

with 'MetaCPAN::Role::Script', 'MooseX::Getopt::Dashes';

my $hostname = hostname;
my $mode = $hostname =~ /dev/ ? 'testing' : 'production';

# So we dont' break production
my $bucket = "mc-${mode}-backups";

my $repository_name = 'our_backups';

## Modes
has setup => (
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'Setup the connection with ES',
);

has snap => (
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'Perform a snapshot',
);

has list => (
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'List saved snapshots',
);

has restore => (
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'Perform a restore',
);

## Options
has snap_stub => (
    is  => 'ro',
    isa => Str,
    documentation =>
        'Stub of snapshot name ( e.g full, user etc ), used with dateformat to create the actual name in S3',
);

has date_format => (
    is            => 'ro',
    isa           => Str,
    documentation => 'strftime format to add to snapshot name (eg %Y-%m-%d)',
);

has snap_name => (
    is            => 'ro',
    isa           => Str,
    documentation => 'Full name of snapshot to restore',
);

has host => (
    is            => 'ro',
    isa           => Str,
    default       => 'http://localhost:9200',
    documentation => 'ES host, defaults to: http://localhost:9200',
);

# Note: can take wild cards https://www.elastic.co/guide/en/elasticsearch/reference/2.4/multi-index.html
has indices => (
    is      => 'ro',
    isa     => ArrayRef,
    default => sub { ['*'] },
    documentation =>
        'Which indices to snapshot, defaults to "*" (all), can take wild cards - "*v100*"',
);

## Internal attributes

has aws_key => (
    is      => 'ro',
    traits  => ['NoGetopt'],
    lazy    => 1,
    default => sub { $_[0]->config->{es_aws_s3_access_key} },
);

has aws_secret => (
    is      => 'ro',
    lazy    => 1,
    traits  => ['NoGetopt'],
    default => sub { $_[0]->config->{es_aws_s3_secret} },
);

has http_client => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_http_client',
    traits  => ['NoGetopt'],
);

sub _build_http_client {
    return HTTP::Tiny->new(
        default_headers => { 'Accept' => 'application/json' }, );
}

## Method selector

sub run {
    my $self = shift;

    die "es_aws_s3_access_key not in config" unless $self->aws_key;
    die "es_aws_s3_secret not in config"     unless $self->aws_secret;

    return $self->run_list_snaps if $self->list;
    return $self->run_setup      if $self->setup;
    return $self->run_snapshot   if $self->snap;
    return $self->run_restore    if $self->restore;

    die "setup, restore or snap argument required";
}

sub run_snapshot {
    my $self = shift;

    $self->snap_stub   || die 'Missing snap-stub';
    $self->date_format || die 'Missing date-format (e.g. %Y-%m-%d)';

    my $date      = DateTime->now->strftime( $self->date_format );
    my $snap_name = $self->snap_stub . '_' . $date;

    my $indices = join ',', @{ $self->indices };
    my $data = {
        "ignore_unavailable"   => 0,
        "include_global_state" => 1,
        "indices"              => $indices,
    };

    log_debug { 'snapping: ' . $snap_name };
    log_debug { 'with indices: ' . $indices };

    my $path = "${repository_name}/${snap_name}";

    my $response = $self->_request( 'put', $path, $data );
    return $response;
}

sub run_list_snaps {
    my $self = shift;

    my $path = "${repository_name}/_all";
    my $response = $self->_request( 'get', $path, {} );

    my $data = eval { decode_json $response->{content} };

    foreach my $snapshot ( @{ $data->{snapshots} || [] } ) {
        log_info { $snapshot->{snapshot} }
        log_debug { np($snapshot) }
    }

    return $response;
}

sub run_restore {
    my $self = shift;

    my $snap_name = $self->snap_name;

    $self->are_you_sure('Restoring... will rename indices to restored_XX');

    # This is a safety feature, we can always
    # create aliases to point to them if required
    # just make sure there is enough disk space
    my $data = {
        "rename_pattern"     => '(.+)',
        "rename_replacement" => 'restored_$1',
    };

    my $path = "${repository_name}/${snap_name}/_restore";

    my $response = $self->_request( 'post', $path, $data );

    log_info { 'restoring: ' . $snap_name } if $response;

    return $response;
}

sub run_setup {
    my $self = shift;

    log_debug { 'setup: ' . $repository_name };

    my $data = {
        "type"     => "s3",
        "settings" => {
            "access_key"                 => $self->aws_key,
            "bucket"                     => $bucket,
            "canned_acl"                 => "private",
            "max_restore_bytes_per_sec"  => '500mb',
            "max_snapshot_bytes_per_sec" => '500mb',
            "protocol"                   => "https",
            "region"                     => "us-east",
            "secret_key"                 => $self->aws_secret,
            "server_side_encryption"     => 1,
            "storage_class"              => "standard",
        }
    };

    my $path = "${repository_name}";

    my $response = $self->_request( 'put', $path, $data );
    return $response;
}

sub _request {
    my ( $self, $method, $path, $data ) = @_;

    my $url = $self->host . '/_snapshot/' . $path;

    my $json = encode_json($data);

    my $response = $self->http_client->$method( $url, { content => $json } );

    if ( !$response->{success} && length $response->{content} ) {

        log_error { 'Problem requesting ' . $url };

        try {
            my $resp_json = decode_json( $response->{content} );
            log_error { 'Error response: ' . np($resp_json) }
        }
        catch {
            log_error { 'Error msg: ' . $response->{content} }
        }
        return 0;
    }
    return $response;
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

MetaCPAN::Script::Snapshot - Snapshot (and restore) Elasticsearch indices

=head1 SYNOPSIS

# Setup
 $ bin/metacpan snapshot --setup (only needed once)

# Snapshot all indexes daily
 $ bin/metacpan snapshot --snap --snap-stub full --date-format %Y-%m-%d

# List what has been snapshotted
 $ bin/metacpan snapshot --list

# restore (indices are renamed from `foo` to `restored_foo`)
 $ bin/metacpan snapshot --restore --snap-name full_2016-12-01

Another example..

# Snapshot just user* indexes hourly and restore
 $ bin/metacpan snapshot --snap --indices 'user*' --snap-stub user --date-format '%Y-%m-%d-%H'
 $ bin/metacpan snapshot --restore --snap-name user_2016-12-01-12

Also useful:

See status of snapshot...

 curl localhost:9200/_snapshot/our_backups/SNAP-NAME/_status

Add an alias to the restored index

 curl -X POST 'localhost:9200/_aliases' -d '
    {
        "actions" : [
            { "add" : { "index" : "restored_user", "alias" : "user" } }
        ]
    }'

=head1 DESCRIPTION

Tell elasticsearch to setup (only needed once), snap or
restore from backups stored in AWS S3.

You will need to run --setup on any box you wish to restore to

You will need es_aws_s3_access_key and es_aws_s3_secret setup
in your local metacpan_server_local.conf

=cut
