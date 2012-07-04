use strict;
use warnings;
package Acme::rafl::Everywhere;
{
  $Acme::rafl::Everywhere::VERSION = '0.002';
}
# ABSTRACT: rafl is so everywhere, he has his own Acme module!

sub new {
    my $class = shift;
    my $self  = bless {@_}, $class;

    exists $self->{'facts'}
        or $self->{'facts'} = $self->load_facts;

    return $self;
}

sub load_facts {
    my $self  = shift;
    my @facts = ();

    while ( my $line = <DATA> ) {
        $line =~ /^__END__/ and last;

        # ignore empty lines
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        chomp $line;
        $line or next;

        push @facts, $line;
    }

    return [@facts];
}

sub fact {
    my $self  = shift;
    my $facts = $self->{'facts'};
    return $facts->[ int rand scalar @{$facts} ];
}

1;



=pod

=head1 NAME

Acme::rafl::Everywhere - rafl is so everywhere, he has his own Acme module!

=head1 VERSION

version 0.002

=head1 AUTHOR

Sawyer X <xsawyerx@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Sawyer X.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


__DATA__
rafl is so everywhere, he's on both the vim and emacs mailing list, arguing for each!
rafl is so everywhere, he's behind you right now!
rafl is so everywhere, even Chuck Norris checks under his bed every night!
rafl is so everywhere, Freddy Krueger is afraid of falling asleep!
rafl is so everywhere, Schrodinger's cat's got nothing on him!
rafl is so everywhere, he sent me postcards from the surface of the sun!
rafl is so everywhere, when you want to abandon a module, rafl gets co-maint automatically!
rafl is so everywhere, you can find Waldo simply by searching for anyone who isn't rafl!
rafl is so everywhere, Jesus owes him a pull request on Github!
rafl is so everywhere, he has the first commit of Javascript on Parrot!
rafl is so everywhere, when you breathe, that's rafl you're breathing!
rafl is so everywhere, he makes a cameo in the video from The Ring!
rafl is so everywhere, he ar in yur Perl debuggr, pointing at yore crappy code!
rafl is so everywhere, he is the default entry in your SSH authorized_keys file!
rafl is so everywhere, he issued the first bug report for Perl, before it existed!
rafl is so everywhere, he participated in the space olympics!
rafl is so everywhere, he can visit all the YAPCs even if they are on the same day!

__END__

=head1 SYNOPSIS

    use Acme::rafl::Everywhere;

    my $rafl = Acme::rafl::Everywhere->new;
    print $rafl->fact;

Or set your own facts

    my $rafl = Acme::rafl::Everywhere->new(
        facts => [@new_facts],
    );

=head1 DESCRIPTION

If you haven't already seen C<rafl> somewhere, you probably haven't been alive
for too long, because he really is everywhere.

L<Moose>, L<MooseX::Declare>, L<Catalyst>, L<Dist::Zilla>, L<signatures>,
L<KiokuDB>, L<Gtk2>, Perl core, MetaCPAN and GSoC are just I<some> of the
projects he's involved in.  

=head1 HELP ADD MORE FACTS

Please add more facts! We accept pull requests, patches, emails, IRC messages,
fortune cookie notes, sky writings, scribbled messages on public bathroom
stalls, inappropriate mid-meeting whispers, and more.

=head1 BUGS

This module cannot contain all the information about C<rafl>, but you're
more than welcome to add any new info.

=head1 THANKS

To C<rafl> for being everywhere. :)

