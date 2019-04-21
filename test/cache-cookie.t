use strict;
use warnings;
use Test::More tests => 6;
use Plack::Test;
use File::Path qw(remove_tree);

use Plack::Builder;
use Plack::Middleware::Cache;

my $cache_dir = 'test-plack-cache';
-d $cache_dir
    and die "Directory $cache_dir is in the way";

my $app_ran = 0;

my $app = builder {
    enable 'Cache',
        match_url => [ '^/$' ],
        cache_dir => $cache_dir;
    sub { ++$app_ran; [200, [ 'Content-Type' => 'text/plain', 'Set-Cookie' => 'dancer.session=lalala' ], [ 'Hello' ]] }
};
test_psgi
    app => $app,
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => "http://localhost/");
        my $res = $cb->($req);
        is $res->decoded_content, 'Hello', "Got Hello back";
        is $res->header('Set-Cookie'), 'dancer.session=lalala', "Cookie from uncached run";
    };
is $app_ran, 1;
test_psgi
    app => $app,
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => "http://localhost/");
        my $res = $cb->($req);
        is $res->decoded_content, 'Hello', "Got Hello back";
        is $res->header('Set-Cookie'), undef, "Cookie from cached run";
    };
is $app_ran, 1;

-d $cache_dir
    and remove_tree $cache_dir;

