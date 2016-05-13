use Test::More;
use strict;
use warnings;

use MetaCPAN::Server::Test;
use lib 't/lib';
use MetaCPAN::TestHelpers;

test_release(
    'RWSTAUNER/Pod-Examples-99',
    {
        first        => 1,
        extra_tests  => \&test_pod_examples,
        main_module  => 'Pod::Examples',
        changes_file => 'Changes',
    }
);

sub test_pod_examples {
    my ($self) = @_;
    my $pod_files
        = $self->filter_files( { term => { mime => 'text/x-pod' } } );
    is( @$pod_files, 1, 'includes one pod file' );

    my @spacial = grep { $_->{documentation} eq 'Pod::Examples::Spacial' }
        @$pod_files;

    is( @spacial, 1, 'parsed =head1\x20\x20NAME' );

    is(
        ${ $spacial[0]->pod },
        q[NAME Pod::Examples::Spacial DESCRIPTION An extra space between 'head1' and 'NAME'],
        'pod text'
    );

    my $xcodes_path    = 'lib/Pod/Examples/XCodes.pm';
    my $xcodes_content = $self->file_content($xcodes_path);
    my $code_re        = qr!^package Pod::Examples::XCodes;!;
    like( $xcodes_content, $code_re, 'file contains code' );

    my $pod_like = sub {
        my ( $type, $like, $desc ) = @_;
        my $pod = $self->pod( $xcodes_path, $type );
        like $pod,   $like,    $desc;
        unlike $pod, $code_re, "$type without code";
    };

    # NOTE: This may change.
    $pod_like->(
        'text/html&x_codes=0',    # hack
        qr{<h1 id="DESCRIPTION">DESCRIPTION </h1>},
        'X codes are ignored in html'
    );

    $pod_like->(
        'text/html&x_codes=1',    # hack
        qr{<h1 id="DESCRIPTION">DESCRIPTION <a id="desc"></a></h1>},
        'X codes are included when requested'
    );

    $pod_like->(
        'text/x-markdown',
        qr!^# DESCRIPTION\n{2,}A doc with X codes!ms,
        'pod as markdown'
    );

    $pod_like->(
        'text/plain', qr!^DESCRIPTION\n\s*A doc with X codes!ms,
        'pod as text'
    );

    $pod_like->(
        'text/x-pod',
        qr!=head1 DESCRIPTION\nX<desc>\n\nA doc with X codes!ms,
        'pod as pod (retains X code)'
    );
}

done_testing;
