use strict;
use warnings;
use JSON;
use File::Find;

my @files;
find(
    sub {
        push( @files, $File::Find::name );
    },
    'conf/authors' );

foreach my $file (@files) {
    next unless ( -f $file );
    next if($file =~ /1/);
    my $json;
    {
        local $/ = undef;
        local *FILE;
        open FILE, "<$file";
        $json = <FILE>;
        close FILE
    }
    my $data = decode_json($json);
    my ($author) = keys %$data;
    ($data) = values %$data;
    my $raw = { donation => [],
                profile  => [], };
    my %profiles = ( "delicious_username"           => 'delicious',
                     "facebook_public_profile"      => 'facebook',
                     "github_username"              => 'github',
                     "linkedin_public_profile"      => "linkedin",
                     "stackoverflow_public_profile" => 'stackoverflow',
                     "perlmonks_username"           => 'perlmonks',
                     "twitter_username"             => 'twitter',
                     "slideshare_url"               => 'slideshare',
                     "youtube_channel_url"          => 'youtube',
                     slashdot_username              => 'slashdot',
                     "amazon_author_profile"        => 'amazon',
                     aim                            => 'aim',
                     icq                            => 'icq',
                     jabber                         => 'jabber',
                     msn_messenger                  => 'msn_messenger',
                     "oreilly_author_profile"       => 'oreilly',
                     slideshare_username            => 'slideshare',
                     stumbleupon_profile            => 'stumbleupon',
                     xing_public_profile            => 'xing',
                     ACT_id                         => 'act',
                     irc_nick                       => 'irc',
                     irc_nickname                   => 'irc' );

    while ( my ( $k, $v ) = each %profiles ) {
        next unless ( my $value = delete $data->{$k} );
        $value =~ s/^.*\///;
        push( @{ $raw->{profile} },
              {  name => $v,
                 id   => $value
              } );
    }

    if ( my $pp = delete $data->{paypal_address} ) {
        delete $data->{accepts_donations};
        push( @{ $raw->{donation} },
              {  id   => $pp,
                 name => 'paypal'
              } );
    }

    if ( $data->{blog_url} ) {
        $raw->{blog} = [
                         { url  => delete $data->{blog_url},
                           feed => delete $data->{blog_feed} } ];
    }
    delete $data->{perlmongers} if ( ref $data->{perlmongers} );
    if ( $data->{perlmongers} ) {
        $raw->{perlmongers} = { name => delete $data->{perlmongers},
                                url  => delete $data->{perlmongers_url}, };
    }
    $raw->{$_} = delete $data->{$_}
      for (qw(city country email region website openid));
    unlink $file;
    (my $base = $file) =~ s/^(.*)\/.*?$/$1/;
    open FILE, '>', "$base/author-1.0.json";
    print FILE JSON->new->pretty->encode( $raw );
    close FILE;
}
