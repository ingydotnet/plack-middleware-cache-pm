#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 4;
use Plack::Test;

use HTTP::Request::Common;
use MIME::Base64 qw(decode_base64);
use Compress::Zlib qw(uncompress);
use File::Path qw(remove_tree);

use Plack::Builder;
use Plack::Middleware::Cache;


my $cache_dir = 'test-plack-cache';
-d $cache_dir 
    and die "Directory $cache_dir is in the way";

my $img = uncompress(decode_base64(<<IMG));
eJyVjkFuwjAURGfsGEzshG/qADvUbS+RRSUEvVSO0rsgDgHtpjcx9gKkVkDU+X81ev/PpFP6gXxs
91uQxC4P0jfeoZUqm1XlNdaYqjL1dDqxvvbe1c417UKaNrTOyVLCS+y6zs9X62VcL2IXyxPqfFOZ
mTGz2Lgm/lvpgGBBUDNABerAdETMzm/Z4vKvi/QFrwklWgC+bQol9yibb2nUUIBwH9Bkz2eAugEP
Iya9eg6wfx2upaGzL58jlWSskowlZuB8AV3ZQgo=
IMG
my $app_ran = 0;

my $app = builder {
    enable 'Cache',
        match_url => [ '^/$' ],
        cache_dir => $cache_dir;
    sub { ++$app_ran; [200, [ 'Content-Type' => 'image/jpeg' ], [ $img ]] }
};
test_psgi
    app => $app,
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => "http://localhost/");
        my $res = $cb->($req);
        is $res->decoded_content, $img;
    };
is $app_ran, 1;
test_psgi
    app => $app,
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => "http://localhost/");
        my $res = $cb->($req);
        is $res->decoded_content, $img;
    };
is $app_ran, 1;  # Should have hit the cache and not run $app a second time.

done_testing;

remove_tree $cache_dir;
