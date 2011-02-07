package MetaCPAN::PerlMongers;

use Moose;
use Modern::Perl;

use Data::Dump qw( dump );
use XML::Simple;
use WWW::Mechanize;
use WWW::Mechanize::Cached;

with 'MetaCPAN::Role::Common';

=head1 SYNOPSIS

Loads author info into db. Requires the presence of a local CPAN/minicpan.

=cut

use Data::Dump qw( dump );
use Find::Lib '../lib';

sub index_perlmongers {

    my $self    = shift;
    my $groups  = $self->get_pm_groups;
    my @updates = ();
    my @results = ();

    foreach my $group ( @{$groups} ) {

        my %update = (
            index => 'cpan',
            type  => 'perlmongers',
            id    => $group->{name},
            data  => $group,
        );

        #push @updates, \%update;
        my $result = $self->es->index( %update );
        push @results, $result;
        say dump( $result );
    }

    say dump( \@results );
    say dump( \@updates );

    #my $result = $self->es->bulk( \@updates );
    return;

}

sub get_pm_groups {

    my $self = shift;
    my $mech = WWW::Mechanize::Cached->new;
    $mech->get( 'http://www.pm.org/groups/perl_mongers.xml' );

    my $xml    = XMLin( $mech->content );
    my @groups = ();
    my %groups = %{ $xml->{group} };
    
    foreach my $pm_name ( sort keys %groups ) {
        
        my $group = $groups{$pm_name};
        my $date  = delete $group->{date};
        
        if ( $date ) {
            my $date_key   = $date->{type} . '_date';
            my $date_value = $date->{content};
            if ( $date_value =~ m{\A(\d\d\d\d)(\d\d)(\d\d)\z} ) {
                $date_value = join "-", $1, $2, $3;
            }
            $group->{$date_key} = $date_value;
        }
        
        my $id = delete $group->{id};
        $group->{pm_id} = $id;
        
        $pm_name =~ s{[\s\-]}{}gxms;
        $group->{name}  = $pm_name;
        
        push @groups, $group;
    }

    return \@groups;

}

1;

=pod

=head1 SYNOPSIS

Parse out PerlMonger Group info and add it to /cpan/perlmongers

=head2 get_pm_groups

Fetches the authoritative XML file on PerlMongers groups, parses the XML and
returns an ARRAYREF of groups.

=head2 index_perlmongers

Adds/updates all PerlMongers groups to ElasticSearch.

=cut
