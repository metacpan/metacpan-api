package MetaCPAN::Document::Author;
use Moose;
use ElasticSearch::Document;
use Gravatar::URL ();
use MetaCPAN::Util;

# TODO: replace censored emailadresse with cpan emailadress

has name => ( index => 'analyzed' );
has email => ( );
has 'pauseid' => ( id         => 1 );
has 'author'  => ( lazy_build => 1 );
has 'dir'     => ( lazy_build => 1 );
has 'gravatar_url' => ( lazy_build => 1 );

sub _build_dir {
    my $pauseid = ref $_[0] ? shift->pauseid : shift;
    return MetaCPAN::Util::author_dir($pauseid);
}

sub _build_gravatar_url {
    Gravatar::URL::gravatar_url( email => shift->email );
}

sub _build_author { shift->name }
has [qw(accepts_donations amazon_author_profile blog_feed blog_url 
       books cats city country delicious_username dogs 
       facebook_public_profile github_username irc_nick 
       linkedin_public_profile openid oreilly_author_profile 
       paypal_address perlmongers perlmongers_url perlmonks_username 
       region slideshare_url slideshare_username 
       stackoverflow_public_profile twitter_username website 
       youtube_channel_url)]
  => ( required => 0 );
__PACKAGE__->meta->make_immutable;
