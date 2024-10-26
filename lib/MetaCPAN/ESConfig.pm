use v5.20;
use warnings;
use experimental qw(signatures postderef);

package MetaCPAN::ESConfig;

use Carp                      qw(croak);
use Const::Fast               qw(const);
use Exporter                  qw(import);
use MetaCPAN::Util            qw(root_dir);
use Module::Runtime           qw(require_module $module_name_rx);
use Cpanel::JSON::XS          ();
use Hash::Merge::Simple       qw(merge);
use MetaCPAN::Server::Config  ();
use MetaCPAN::Types::TypeTiny qw(HashRef Defined);
use Const::Fast               qw(const);

const my %config => merge(
    {
        aliases => {
            'cpan' => 'cpan_v1_01',
        },
        indexes => {
            _default => {
                settings =>
                    'MetaCPAN::Script::Mapping::DeployStatement::mapping()',
            },
        },
        documents => {
            author => {
                index   => 'cpan_v1_01',
                type    => 'author',
                mapping => 'MetaCPAN::Script::Mapping::CPAN::Author',
                model   => 'MetaCPAN::Document::Author',
            },
            cve => {
                index   => 'cve',
                type    => 'cve',
                mapping => 'MetaCPAN::Script::Mapping::CVE',
                model   => 'MetaCPAN::Document::CVE',
            },
            contributor => {
                index   => 'contributor',
                type    => 'contributor',
                mapping => 'MetaCPAN::Script::Mapping::Contributor',
                model   => 'MetaCPAN::Document::Contributor',
            },
            cover => {
                index   => 'cover',
                type    => 'cover',
                mapping => 'MetaCPAN::Script::Mapping::Cover',
                model   => 'MetaCPAN::Document::Cover',
            },
            distribution => {
                index   => 'cpan_v1_01',
                type    => 'distribution',
                mapping => 'MetaCPAN::Script::Mapping::CPAN::Distribution',
                model   => 'MetaCPAN::Document::Distribution',
            },
            favorite => {
                index   => 'cpan_v1_01',
                type    => 'favorite',
                mapping => 'MetaCPAN::Script::Mapping::CPAN::Favorite',
                model   => 'MetaCPAN::Document::Favorite',
            },
            file => {
                index   => 'cpan_v1_01',
                type    => 'file',
                mapping => 'MetaCPAN::Script::Mapping::CPAN::File',
                model   => 'MetaCPAN::Document::File',
            },
            mirror => {
                index   => 'cpan_v1_01',
                type    => 'mirror',
                mapping => 'MetaCPAN::Script::Mapping::CPAN::Mirror',
                model   => 'MetaCPAN::Document::Mirror',
            },
            package => {
                index   => 'cpan_v1_01',
                type    => 'package',
                mapping => 'MetaCPAN::Script::Mapping::CPAN::Package',
                model   => 'MetaCPAN::Document::Package',
            },
            permission => {
                index   => 'cpan_v1_01',
                type    => 'permission',
                mapping => 'MetaCPAN::Script::Mapping::CPAN::Permission',
                model   => 'MetaCPAN::Document::Permission',
            },
            release => {
                index   => 'cpan_v1_01',
                type    => 'release',
                mapping => 'MetaCPAN::Script::Mapping::CPAN::Release',
                model   => 'MetaCPAN::Document::Release',
            },

            account => {
                index   => 'user',
                type    => 'account',
                mapping => 'MetaCPAN::Script::Mapping::User::Account',
                model   => 'MetaCPAN::Model::User::Account',
            },
            identity => {
                index   => 'user',
                type    => 'identity',
                mapping => 'MetaCPAN::Script::Mapping::User::Identity',
                model   => 'MetaCPAN::Model::User::Identity',
            },
            session => {
                index   => 'user',
                type    => 'session',
                mapping => 'MetaCPAN::Script::Mapping::User::Session',
                model   => 'MetaCPAN::Model::User::Session',
            },
        },
    },
    MetaCPAN::Server::Config::config()->{elasticsearch} || {},
)->%*;

{
    use Moo;
}

has indexes => (
    is       => 'ro',
    required => 1,
);

has all_indexes => (
    is      => 'lazy',
    default => sub ($self) {
        my %seen;
        [
            sort
                grep !$seen{$_}++,
            map $_->{index},
            values $self->documents->%*
        ];
    },
);

my $DefinedHash = ( HashRef [Defined] )->plus_coercions(
    HashRef,
    => sub ($hash) {
        return {
            map {
                my $value = $hash->{$_};
                defined $value ? ( $_ => $value ) : ();
            } keys %$hash
        };
    },
);
has aliases => (
    is      => 'ro',
    isa     => $DefinedHash,
    coerce  => 1,
    default => sub { {} },
);

has documents => (
    is       => 'ro',
    isa      => HashRef [$DefinedHash],
    coerce   => 1,
    required => 1,
);

sub _load_es_data ( $location, $def_sub = 'mapping' ) {
    my $data;

    if ( ref $location ) {
        $data = $location;
    }
    elsif ( $location
        =~ /\A($module_name_rx)(?:::([0-9a-zA-Z_]+)\(\)|->($module_name_rx))?\z/
        )
    {
        my ( $module, $sub, $method ) = ( $1, $2, $3 );
        require_module $module;
        if ($method) {
            $data = $module->$method;
        }
        else {
            $sub ||= $def_sub;
            no strict 'refs';
            my $code = \&{"${module}::${sub}"};
            die "can't find $location"
                if !defined &$code;
            $data = $code->();
        }
    }
    else {
        my $abs_path = File::Spec->rel2abs( $location, root_dir() );
        open my $fh, '<', $abs_path
            or die "can't open mapping file $abs_path: $!";
        $data = do { local $/; <$fh> };
    }

    return $data
        if ref $data;

    return Cpanel::JSON::XS::decode_json($data);
}

sub mapping ( $self, $doc ) {
    my $doc_data = $self->documents->{$doc}
        or croak "unknown document $doc";
    return _load_es_data( $doc_data->{mapping}, 'mapping' );
}

sub index_settings ( $self, $index ) {
    my $indexes    = $self->indexes;
    my $index_data = exists $indexes->{$index} && $indexes->{$index};
    my $settings
        = $index_data
        && exists $index_data->{settings}
        && $index_data->{settings};
    if ( !$settings ) {
        my $default_data
            = exists $indexes->{_default} && $indexes->{_default};
        $settings
            = $default_data
            && exists $default_data->{settings}
            && $default_data->{settings};
    }
    return {}
        if !$settings;
    return _load_es_data($settings);
}

sub doc_path ( $self, $doc ) {
    my $doc_data = $self->documents->{$doc}
        or croak "unknown document $doc";
    return (
        ( $doc_data->{index} ? ( index => $doc_data->{index} ) : () ),
        ( $doc_data->{type}  ? ( type  => $doc_data->{type} )  : () ),
    );
}

our @EXPORT_OK = qw(
    es_config
    es_doc_path
);

my $single = __PACKAGE__->new(%config);
sub es_config : prototype() {$single}
sub es_doc_path ($doc)      { $single->doc_path($doc) }

1;
