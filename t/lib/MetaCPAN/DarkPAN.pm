package MetaCPAN::DarkPAN;

use strict;
use warnings;

use CPAN::Repository::Perms;
use MetaCPAN::TestHelpers qw( get_config );
use MetaCPAN::Types qw( Dir );
use MetaCPAN::Util qw( author_dir );
use Moose;
use OrePAN2::Indexer;
use OrePAN2::Injector;
use Path::Class qw( dir );
use URI::FromHash qw( uri_object );

has base_dir => (
    is      => 'ro',
    isa     => Dir,
    lazy    => 1,
    coerce  => 1,
    default => 't/var/darkpan',
);

sub run {
    my $self = shift;

    my $dir = dir( 't', 'var', 'darkpan' );
    $dir->mkpath;

    my $base_uri = 'http://cpan.metacpan.org';

    my $injector = OrePAN2::Injector->new( directory => $dir );

    my %downloads = (
        MIYAGAWA => [
            'CPAN-Test-Dummy-Perl5-VersionBump-0.01.tar.gz',
            'CPAN-Test-Dummy-Perl5-VersionBump-0.02.tar.gz',
        ],
        MLEHMANN => ['AnyEvent-4.232.tar.gz'],
    );

    foreach my $pauseid (%downloads) {

        my $files = $downloads{$pauseid};

        foreach my $archive ( @{$files} ) {
            my $uri = uri_object(
                host => 'cpan.metacpan.org',
                path =>
                    join( q{/}, 'authors', author_dir($pauseid), $archive ),
                scheme => 'http',
            );

            $injector->inject( $uri, { author => $pauseid }, );
        }
    }

    my $orepan = OrePAN2::Indexer->new(
        directory => $dir,
        metacpan  => 1,
    );
    $orepan->make_index( no_compress => 1, );
    $self->_write_06perms;
}

sub _write_06perms {
    my $self = shift;

    my $perms = CPAN::Repository::Perms->new(
        {
            repository_root => $self->base_dir,
            written_by      => 'MetaCPAN',
        }
    );

    my %authors = (
        MIYAGAWA => {
            'CPAN::Test::Dummy::Perl5::VersionBump::Decrease' => 'f',
            'CPAN::Test::Dummy::Perl5::VersionBump::Stay'     => 'f',
            'CPAN::Test::Dummy::Perl5::VersionBump::Undef'    => 'f',
        },
        MLEHMANN => {},
    );

    foreach my $pauseid ( keys %authors ) {
        my $modules = $authors{$pauseid};
        foreach my $module ( keys %{$modules} ) {
            $perms->set_perms( $module, $pauseid, $modules->{$module} );
        }
    }

    my $modules_dir = $self->base_dir->subdir('modules');
    $modules_dir->mkpath;

    my $content = $perms->generate_content;

    # work around bug in generate_content()
    $content =~ s{,f}{,f\n}g;

    $modules_dir->file('06perms.txt')->spew($content);
}

__PACKAGE__->meta->make_immutable;
1;
