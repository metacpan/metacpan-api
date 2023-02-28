package MetaCPAN::Script::Role::External::Repology;

use v5.010;
use Moose::Role;
use namespace::autoclean;

use Log::Contextual  qw( :log );
use YAML::PP::LibYAML ();

has repology_rules_repo => (
    is => 'ro',
    lazy => 1,
    build => '_build_repology_rules_repo',
);

sub _build_repology_rules_repo {
    my $self = shift;
    my $dir = $self->home->child( 'var', ( $ENV{HARNESS_ACTIVE} ? 't' : () ),
        'repology-rules' );
    mkdir $dir;
    if (!-e $dir->child('.git')) {
        system 'git', '-C', $dir, 'init';
    }
    return $dir;
}

has rules_repo_url => (
    is => 'ro',
    default => 'https://github.com/repology/repology-rules.git',
);

sub update_rules_repo {
    my ($self, $repo) = @_;

    system 'git', '-C', $repo, 'fetch', $self->rules_repo_url;
    system 'git', '-C', $repo, 'clean', '-fdx';
    system 'git', '-C', $repo, 'checkout', '-f', 'FETCH_HEAD';
}

has repology_renames => (
    is => 'ro',
    lazy => 1,
    build => '_build_repology_renames',
);
sub _build_repology_renames {
    my $self = shift;
    my $rules_repo = $self->repology_rules_repo;

    $self->update_rules_repo($rules_repo);

    my %rename;

    my $yaml = YAML::PP::LibYAML->new;

    FILE: for my $yaml_file (glob("$rules_repo/800.renames-and-merges/*.yaml")) {
        my $data = $yaml->load_file($yaml_file);
        PACKAGE: for my $package (@$data) {
            my $setname = $package->{setname}
                or next;
            my $names = $package->{name}
                or next;

            NAME: for my $name (ref $names ? @$names : $names) {
                if ($name =~ /^perl:/) {
                    $rename{$name} = $setname;
                }
            }
        }
    }

    return \%rename;
}

sub run_repology {
    my $self = shift;

    my $scroll = $self->es->scroll_helper(
        index  => $self->index->name,
        type   => 'distribution',
        scroll => '10m',
        body   => {
            query => { match_all => {} },
        },
        fields => [qw(
            id
            name
            external_package
        )],
    );

    my $ret = { dist => {} };

    while ( my $p = $scroll->next ) {
        my $dist = $p->{name};
        my $current_name = $p->{external_package} && $p->{external_package}{repology};
        my $repology_name = $self->repology_name($dist);
        if (!$current_name || $current_name ne $repology_name) {
            $ret->{dist}{$dist} = $repology_name;
        }
    }

    return $ret;
}

1;
