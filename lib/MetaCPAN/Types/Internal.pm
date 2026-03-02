package MetaCPAN::Types::Internal;

use strict;
use warnings;

use MetaCPAN::Util qw( is_bool true false );
use Type::Library -base, -declare => ( qw(
    Location
    Logger
    CommaSepOption
    ES
    ESBool
) );
use Types::Standard qw(
    ArrayRef
    Bool
    ConsumerOf
    HashRef
    InstanceOf
    Item
    Str
    StrMatch
    Value
);
use Type::Utils qw( as coerce declare from message via where );

declare Logger, as InstanceOf ['Log::Log4perl::Logger'];
coerce Logger, from ArrayRef, via {
    require MetaCPAN::Role::Logger;    ## no perlimports
    return MetaCPAN::Role::Logger::_build_logger($_);
};
coerce Logger, from HashRef, via {
    require MetaCPAN::Role::Logger;    ## no perlimports
    return MetaCPAN::Role::Logger::_build_logger( [$_] );
};

declare CommaSepOption, as ArrayRef [ StrMatch [qr{^[^, ]+$}] ];
coerce CommaSepOption, from ArrayRef [Str], via {
    return [ map split(/\s*,\s*/), @$_ ];
};
coerce CommaSepOption, from Str, via {
    return [ map split(/\s*,\s*/), $_ ];
};

declare ES, as ConsumerOf ['Search::Elasticsearch::Role::Client'];
coerce ES, from Str, via {
    require Search::Elasticsearch;
    my $server = $_;
    $server = "127.0.0.1$server" if ( $server =~ /^:/ );
    return Search::Elasticsearch->new(
        cxn   => 'HTTPTiny',
        nodes => $server,
    );
};

coerce ES, from HashRef, via {
    return Search::Elasticsearch->new( {
        cxn => 'HTTPTiny',
        %$_,
    } );
};

coerce ES, from ArrayRef, via {
    my @servers = @$_;
    @servers = map { /^:/ ? "127.0.0.1$_" : $_ } @servers;
    return Search::Elasticsearch->new(
        cxn   => 'HTTPTiny',
        nodes => \@servers,
    );
};

declare ESBool, as Item, where { is_bool($_) };
coerce ESBool, from Bool, via { $_ ? true : false };

declare Location, as ArrayRef,
    where { @$_ == 2 },
    message {"Location is an arrayref of longitude and latitude"};

coerce Location,
    from HashRef,
    via { [ $_->{lon} || $_->{longitude}, $_->{lat} || $_->{latitude} ] };
coerce Location, from Str, via { [ reverse split(/,/) ] };

my $_ArrayRefFromItem = Type::Coercion->new(
    name               => 'ArrayRefFromItem',
    type_constraint    => ArrayRef,
    coercion_generator => sub {
        my ( $coercion, $target_type ) = @_;
        if ( $target_type == ArrayRef ) {
            return ();
        }
        elsif ( !$target_type->is_subtype_of(ArrayRef) ) {
            die "can't apply to non-ArrayRef types";
        }
        my $inner_type = $target_type->parameters->[0];
        if ( !$inner_type || !$inner_type->has_coercion ) {
            return (
                ArrayRef, => sub {$_},
                Item,     => sub { [$_] },
            );
        }
        return (
            ArrayRef,
            => sub {
                my $value = $_;
                my @new   = map {
                    return $value
                        if $inner_type->check($_);
                    $inner_type->coerce($_);
                } @$value;
                return \@new;
            },
            Item,
            => sub {
                return [ $inner_type->coerce($_) ];
            },
        );
    },
);

# this is ugly. we want applying the constraint to a type to trigger
# reparameterization without passing in any parameters. this requires the
# coercion to have been parameterized. but parameterized coercions don't have
# names, and unnamed types can't be added to a library. but we can just inject
# a name directly then everything works.
my $ArrayRefFromItem = $_ArrayRefFromItem->parameterize(Item);
$ArrayRefFromItem->{name} = 'ArrayRefFromItem';

__PACKAGE__->meta->add_coercion($ArrayRefFromItem);

__PACKAGE__->meta->make_immutable;

1;
