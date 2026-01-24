package Pod::With::Data::Token;
our $VERSION = '0.01';
1


=head1 NAME

Pod::With::Data::Token - yo

=head1 SYNOPSIS

  use warnings;
  print <DATA>;
  __DATA__
  More text

=head1 DESCRIPTION

data handle inside pod is pod but not data

__DATA__

see?

=cut

print "hi\n";

print map { " | $_" } <DATA>;

=head2 EVEN MOAR

not much, though

=cut

__DATA__

data is here

__END__

THE END IS NEAR


=pod

this is pod to a pod reader but DATA to perl
