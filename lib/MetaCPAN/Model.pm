package MetaCPAN::Model;

# load order important
use Moose;

use ElasticSearchX::Model;
use MetaCPAN::ESConfig qw(es_config);
use Module::Runtime    qw(require_module);

my %indexes;
my $docs = es_config->documents;
for my $name ( sort keys %$docs ) {
    my $doc   = $docs->{$name};
    my $model = $doc->{model}
        or next;
    require_module($model);
    my $index = $doc->{index}
        or die "no index for $name documents!";

    $indexes{$index}{types}{$name} = $model->meta;
}

my $aliases = es_config->aliases;
for my $alias ( sort keys %$aliases ) {
    my $index      = $aliases->{$alias};
    my $index_data = $indexes{$index}
        or die "unknown index $index";
    if ( $index_data->{alias_for} ) {
        die "duplicate alias for $index";
    }
    $index_data->{alias_for} = $index;
    $indexes{$alias} = delete $indexes{$index};
}

for my $index ( sort keys %indexes ) {
    index $index => %{ $indexes{$index} };
}

__PACKAGE__->meta->make_immutable;
1;

__END__
