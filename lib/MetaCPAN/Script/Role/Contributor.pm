package MetaCPAN::Script::Role::Contributor;

use Moose::Role;

use Log::Contextual    qw( :log );
use MetaCPAN::ESConfig qw( es_doc_path );
use MetaCPAN::Util     qw( true false );
use Ref::Util          qw( is_arrayref );

sub update_contributors {
    my ( $self, $query ) = @_;

    my $scroll = $self->es->scroll_helper(
        es_doc_path('release'),
        body => {
            query   => $query,
            sort    => ['_doc'],
            _source => [ qw<
                name
                author
                distribution
                metadata.author
                metadata.x_contributors
            > ],
        },
    );

    my $report = sub {
        my ( $action, $result, $i ) = @_;
        if ( $i == 0 ) {
            log_info {'flushing contributor updates'};
        }
    };

    my $bulk = $self->es->bulk_helper(
        es_doc_path('contributor'),
        on_success => $report,
        on_error   => $report,
    );

    log_info { 'updating contributors for ' . $scroll->total . ' releases' };

    while ( my $release = $scroll->next ) {
        my $source = $release->{_source};
        my $name   = $source->{name};
        if ( !( $name && $source->{author} && $source->{distribution} ) ) {
            Dlog_warn {"found broken release: $_"} $release;
            next;
        }
        log_debug { 'updating contributors for ' . $release->{_source}{name} };
        my $actions = $self->release_contributor_update_actions(
            $release->{_source} );
        for my $action (@$actions) {
            $bulk->add_action(%$action);
        }
    }

    $bulk->flush;
}

sub release_contributor_update_actions {
    my ( $self, $release ) = @_;
    my @actions;

    my $res = $self->es->search(
        es_doc_path('contributor'),
        body => {
            query => {
                bool => {
                    must => [
                        { term => { release_name   => $release->{name} } },
                        { term => { release_author => $release->{author} } },
                    ],
                }
            },
            sort    => ['_doc'],
            size    => 500,
            _source => false,
        },
    );
    my @ids = map $_->{_id}, @{ $res->{hits}{hits} };
    push @actions, map +{ delete => { id => $_ } }, @ids;

    my $contribs = $self->get_contributors($release);
    my @docs     = map {
        ;
        my $contrib = $_;
        {
            release_name   => $release->{name},
            release_author => $release->{author},
            distribution   => $release->{distribution},
            map +( defined $contrib->{$_} ? ( $_ => $contrib->{$_} ) : () ),
            qw(pauseid name email)
        };
    } @$contribs;
    push @actions, map +{ create => { _source => $_ } }, @docs;
    return \@actions;
}

has email_mapping => (
    is      => 'ro',
    default => sub { {} },
);

sub get_contributors {
    my ( $self, $release ) = @_;

    my $author_name = $release->{author};
    my $contribs    = $release->{metadata}{x_contributors} || [];
    my $authors     = $release->{metadata}{author}         || [];

    for ( \( $contribs, $authors ) ) {

        # If a sole contributor is a string upgrade it to an array...
        $$_ = [$$_]
            if !ref $$_;

        # but if it's any other kind of value don't die trying to parse it.
        $$_ = []
            unless Ref::Util::is_arrayref($$_);
    }
    $authors = [ grep { $_ ne 'unknown' } @$authors ];

    my $author = eval {
        $self->es->get_source( es_doc_path('author'), id => $author_name );
    }
        or return [];

    my $author_email = $author->{email};

    my $author_info = {
        email => [
            lc "$author_name\@cpan.org",
            (
                Ref::Util::is_arrayref($author_email)
                ? @{$author_email}
                : $author_email
            ),
        ],
        name => $author_name,
    };
    my %seen = map { $_ => $author_info }
        ( @{ $author_info->{email} }, $author_info->{name}, );

    my @contribs = map {
        my $name = $_;
        my $email;
        if ( $name =~ s/\s*<([^<>]+@[^<>]+)>// ) {
            $email = $1;
        }
        my $info;
        my $dupe;
        if ( $email and $info = $seen{$email} ) {
            $dupe = 1;
        }
        elsif ( $info = $seen{$name} ) {
            $dupe = 1;
        }
        else {
            $info = {
                name  => $name,
                email => [],
            };
        }
        $seen{$name} ||= $info;
        if ($email) {
            push @{ $info->{email} }, $email
                unless grep { $_ eq $email } @{ $info->{email} };
            $seen{$email} ||= $info;
        }
        $dupe ? () : $info;
    } ( @$authors, @$contribs );

    my %want_email;
    for my $contrib (@contribs) {

        # heuristic to autofill pause accounts
        if ( !$contrib->{pauseid} ) {
            my ($pauseid)
                = map { /^(.*)\@cpan\.org$/ ? $1 : () }
                @{ $contrib->{email} };
            $contrib->{pauseid} = uc $pauseid
                if $pauseid;

        }

        push @{ $want_email{$_} }, $contrib for @{ $contrib->{email} };
    }

    if (%want_email) {
        my $email_mapping = $self->email_mapping;

        my @fetch_email = grep !exists $email_mapping->{$_},
            sort keys %want_email;

        if (@fetch_email) {
            my $check_author = $self->es->search(
                es_doc_path('author'),
                body => {
                    query   => { terms => { email => \@fetch_email } },
                    _source => [ 'email', 'pauseid' ],
                    size    => 100,
                },
            );

            for my $author ( @{ $check_author->{hits}{hits} } ) {
                my $pauseid = uc $author->{_source}{pauseid};
                my $emails  = $author->{_source}{email};
                $email_mapping->{$_} //= $pauseid
                    for ref $emails ? @$emails : $emails;
            }
        }

        for my $email ( keys %want_email ) {
            my $pauseid = $email_mapping->{$email}
                or next;
            for my $contrib ( @{ $want_email{$email} } ) {
                $contrib->{pauseid} = $pauseid;
            }
        }
    }

    return \@contribs;
}

no Moose::Role;
1;
