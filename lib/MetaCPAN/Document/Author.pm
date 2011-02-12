package MetaCPAN::Document::Author;
use Moose;
use ElasticSearch::Document;
use Gravatar::URL ();

# TODO: replace censored emailadresse with cpan emailadress

has [qw(name email)] => ( required => 0, required => 1 );
has 'pauseid' => ( required => 0, required => 1, id         => 1 );
has 'author'  => ( required => 0, required => 1, lazy_build => 1 );
has 'dir'     => ( required => 0, required => 1, lazy_build => 1 );
has 'gravatar_url' => ( required => 0, lazy_build => 1 );

sub _build_dir {
    my $pauseid = ref $_[0] ? shift->pauseid : shift;
    my $dir = 'id/'
      . sprintf( "%s/%s/%s",
                 substr( $pauseid, 0, 1 ),
                 substr( $pauseid, 0, 2 ), $pauseid );
    return $dir;
}

sub _build_gravatar_url {
    Gravatar::URL::gravatar_url( email => shift->email );
}

sub _build_author { shift->name }

has accepts_donations            => ( required => 0 );
has amazon_author_profile        => ( required => 0 );
has blog_feed                    => ( required => 0 );
has blog_url                     => ( required => 0 );
has books                        => ( required => 0 );
has cats                         => ( required => 0 );
has city                         => ( required => 0 );
has country                      => ( required => 0 );
has delicious_username           => ( required => 0 );
has dogs                         => ( required => 0 );
has facebook_public_profile      => ( required => 0 );
has github_username              => ( required => 0 );
has irc_nick                     => ( required => 0 );
has linkedin_public_profile      => ( required => 0 );
has openid                       => ( required => 0 );
has oreilly_author_profile       => ( required => 0 );
has paypal_address               => ( required => 0 );
has perlmongers                  => ( required => 0 );
has perlmongers_url              => ( required => 0 );
has perlmonks_username           => ( required => 0 );
has region                       => ( required => 0 );
has slideshare_url               => ( required => 0 );
has slideshare_username          => ( required => 0 );
has stackoverflow_public_profile => ( required => 0 );
has twitter_username             => ( required => 0 );
has website                      => ( required => 0 );
has youtube_channel_url          => ( required => 0 );

__PACKAGE__->meta->make_immutable;
