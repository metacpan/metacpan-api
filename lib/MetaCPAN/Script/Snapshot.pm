package MetaCPAN::Script::Snapshot;

use strict;
use warnings;

use MetaCPAN::Types qw( Bool Int Str File );
use Moose;
use DateTime;
use Try::Tiny;
use Sys::Hostname;
use HTTP::Tiny;
use Cpanel::JSON::XS;

with 'MetaCPAN::Role::Script', 'MooseX::Getopt::Dashes';

my $hostname = hostname;

my $mode = $hostname =~ /dev/ ? 'testing' : 'production';

# So we dont' break production
my $bucket = "mc-${mode}-backups";

my $repository_name = 'bar';

## Modes
has setup => (
    is            => 'ro',
    isa           => Bool,
    documentation => 'Setup the connection with ES',
);

has snap => (
    is            => 'ro',
    isa           => Bool,
    documentation => 'Perform a snapshot',
);

has restore => (
    is            => 'ro',
    isa           => Bool,
    documentation => 'Perform a restore',
);

## Options
has name => (
    is  => 'ro',
    isa => 'Str',
    documentation =>
        'Name of snapshot ( e.g full, user etc ), used with dateformat to create the actual name in ES',
);

has date_format => (
    is            => 'ro',
    isa           => 'Str',
    documentation => 'strftime format to add to snapshot name',
);

has host => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'http://localhost:9200',
    documentation => 'ES host, defaults to: http://localhost:9200',
);

# Note: can take wild cards https://www.elastic.co/guide/en/elasticsearch/reference/2.4/multi-index.html
has indices => (
    is            => 'ro',
    isa           => 'ArrayRef',
    default       => sub { ['user'] },
    documentation => 'Which indices to snapshot, defaults to "user" only',
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
    builder => '_build__http_client',
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

    return $self->run_setup    if $self->setup;
    return $self->run_restore  if $self->restore;
    return $self->run_snapshot if $self->snap;

    die "setup, restore or snap argument required";
}

sub run_snapshot {
    my $self = shift;

    my $now = DateTime->now;

    #    my $strftime_format = '%Y-%m'; #$self->format;
    my $date = $now->strftime( $self->date_format );
    warn $date;
    my $snap_name = $self->name . '_' . $date;

    my $indices = join ',', @{ $self->indices };

    my $data = {
        "indices"              => $indices,
        "ignore_unavailable"   => 0,
        "include_global_state" => 1
    };

    my $path = "${repository_name}/${snap_name}";

    die $path;

    my $response = $self->_request( 'put', $path, $data );

    log_info {'done'};
}

sub run_restore {
    my $self = shift;

    log_info {'restore'};

    $self->are_you_sure('WARNING stuff will happen!');

    # This is a safetly feature, we can always
    # create aliases to point to them if required
    # just make sure there is enough disk space
    my $data = {
        "rename_pattern"     => '(.+)',
        "rename_replacement" => 'restored_$1'
    };

    # FIXME: snap_name
    my $path = "${repository_name}/nightly_full/_restore";

    my $response = $self->_request( 'post', $path, $data );

    log_info {'done'};
}

sub run_setup {
    my $self = shift;

    log_info {'setup'};

    my $data = {
        "type"     => "s3",
        "settings" => {
            "bucket"                 => $bucket,
            "region"                 => "us-east",
            "protocol"               => "https",
            "access_key"             => $self->aws_key,
            "secret_key"             => $self->aws_secret,
            "server_side_encryption" => 1,
            "storage_class"          => "standard",
            "canned_acl"             => "private",
        }
    };

    my $path = "${repository_name}";

    my $response = $self->_request( 'put', $path, $data );

}

sub _request {
    my ( $self, $method, $path, $data ) = @_;

    my $url = $self->host . '/_snapshot/' . $path;

    my $json = encode_json $data;

    my $response = $self->http_client->$method( $url, { content => $json } );

    if ( !$response->{success} && length $response->{content} ) {
        my $resp_json = decode_json $response->{content};
        use DDP;
        p $resp_json;
    }
    return $response;
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

MetaCPAN::Script::Snapshot - Snapshot (and restore) ElasticSearch indices

=head1 SYNOPSIS

 $ bin/metacpan snapshot --setup (only needed once)

 $ bin/metacpan snapshot --snap --name full --strftime '%Y-%m-%d'

 $ bin/metacpan snapshot --restore --name full_2016-12-01

 $ bin/metacpan snapshot --snap --name user --strftime '%Y-%m-%d_%H-%m'

 $ bin/metacpan snapshot --restore --name user_2016-12-01_12-22


=head1 DESCRIPTION

Tell elasticsearch to setup (only needed once), snap or
restore from backups stored in AWS S3.

=cut
