use v5.20;
use warnings;
use experimental qw( signatures postderef );

package MetaCPAN::ESConfig;

use Carp                      qw( croak );
use Const::Fast               qw( const );
use Cpanel::JSON::XS          ();
use Exporter                  qw( import );
use Hash::Merge::Simple       qw( merge );
use MetaCPAN::Server::Config  ();
use MetaCPAN::Types::TypeTiny qw( Defined HashRef );
use MetaCPAN::Util            qw( root_dir true false );
use Module::Runtime           qw( $module_name_rx require_module );

const my %config => merge(
    {
        documents => {
            author => {
                index    => 'author',
                mapping  => 'es/author/mapping.json',
                settings => 'es/author/settings.json',
                model    => 'MetaCPAN::Document::Author',
            },
            cve => {
                index    => 'cve',
                mapping  => 'es/cve/mapping.json',
                settings => 'es/cve/settings.json',
                model    => 'MetaCPAN::Document::CVE',
            },
            contributor => {
                index    => 'contributor',
                mapping  => 'es/contributor/mapping.json',
                settings => 'es/contributor/settings.json',
                model    => 'MetaCPAN::Document::Contributor',
            },
            cover => {
                index    => 'cover',
                mapping  => 'es/cover/mapping.json',
                settings => 'es/cover/settings.json',
                model    => 'MetaCPAN::Document::Cover',
            },
            distribution => {
                index    => 'distribution',
                mapping  => 'es/distribution/mapping.json',
                settings => 'es/distribution/settings.json',
                model    => 'MetaCPAN::Document::Distribution',
            },
            favorite => {
                index    => 'favorite',
                mapping  => 'es/favorite/mapping.json',
                settings => 'es/favorite/settings.json',
                model    => 'MetaCPAN::Document::Favorite',
            },
            file => {
                index    => 'file',
                mapping  => 'es/file/mapping.json',
                settings => 'es/file/settings.json',
                model    => 'MetaCPAN::Document::File',
            },
            mirror => {
                index    => 'mirror',
                mapping  => 'es/mirror/mapping.json',
                settings => 'es/mirror/settings.json',
                model    => 'MetaCPAN::Document::Mirror',
            },
            package => {
                index    => 'package',
                mapping  => 'es/package/mapping.json',
                settings => 'es/package/settings.json',
                model    => 'MetaCPAN::Document::Package',
            },
            permission => {
                index    => 'permission',
                mapping  => 'es/permission/mapping.json',
                settings => 'es/permission/settings.json',
                model    => 'MetaCPAN::Document::Permission',
            },
            release => {
                index    => 'release',
                mapping  => 'es/release/mapping.json',
                settings => 'es/release/settings.json',
                model    => 'MetaCPAN::Document::Release',
            },

            account => {
                index    => 'account',
                mapping  => 'es/account/mapping.json',
                settings => 'es/account/settings.json',
                model    => 'MetaCPAN::Model::User::Account',
            },
            session => {
                index    => 'session',
                mapping  => 'es/session/mapping.json',
                settings => 'es/session/settings.json',
                model    => 'MetaCPAN::Model::User::Session',
            },
        },
    },
    MetaCPAN::Server::Config::config()->{elasticsearch} || {},
)->%*;

{
    use Moo;
}

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

has documents => (
    is       => 'ro',
    isa      => HashRef [$DefinedHash],
    coerce   => 1,
    required => 1,
);

sub _load_es_data ( $location, $def_sub ) {
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

sub _walk : prototype(&$);

sub _walk : prototype(&$) {
    my ( $cb, $data ) = @_;
    if ( ref $data eq 'HASH' ) {
        $cb->($data);
        _walk( \&$cb, $data->{$_} ) for keys %$data;
    }
    elsif ( ref $data eq 'ARRAY' ) {
        $cb->($data);
        _walk( \&$cb, $_ ) for @$data;
    }
}

sub mapping ( $self, $doc, $version = undef ) {
    my $doc_data = $self->documents->{$doc}
        or croak "unknown document $doc";
    my $data = _load_es_data( $doc_data->{mapping}, 'mapping' );
    return $data;
}

sub index_settings ( $self, $doc, $version = undef ) {
    my $documents = $self->documents;
    my $doc_data  = exists $documents->{$doc} && $documents->{$doc}
        or return {};
    my $settings = exists $doc_data->{settings} && $doc_data->{settings}
        or return {};
    my $data = _load_es_data( $settings, 'settings' );
    return $data;
}

sub doc_path ( $self, $doc ) {
    my $doc_data = $self->documents->{$doc}
        or croak "unknown document $doc";
    return (
        ( exists $doc_data->{index} ? ( index => $doc_data->{index} ) : () ),
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
