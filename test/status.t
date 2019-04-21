use strict;
use warnings;
use Test::More;
use Plack::Test;
use Plack::Builder;
use Plack::Middleware::Cache;

use HTTP::Request::Common;
use File::Path qw(remove_tree);

my $cache_dir = 'test-plack-cache';
-d $cache_dir
    and die "Directory $cache_dir is in the way";

my $st200_ran;
my $st200_inside = sub { ++$st200_ran; [200, [ 'Content-Type' => 'text/plain' ], [ 'good' ]] };
my $st404_ran;
my $st404_inside = sub { ++$st404_ran; [404, [ 'Content-Type' => 'text/plain' ], [ 'bad' ]] };

# test 200 status
test_psgi
    app => builder {
        enable 'Cache',
            match_url => [ '^/$' ],
            status => 200,
            cache_dir => $cache_dir;
        $st200_inside;
    },
    client => sub {
        my $cb = shift;
        my $res = $cb->( GET "http://localhost/" );
        is $res->decoded_content, 'good';
    };
is $st200_ran, 1;
test_psgi
    app => builder {
        enable 'Cache',
            match_url => [ '^/$' ],
            status => 200,
            cache_dir => $cache_dir;
        $st200_inside;
    },
    client => sub {
        my $cb = shift;
        my $res = $cb->( GET "http://localhost/" );
        is $res->decoded_content, 'good';
    };
is $st200_ran, 1;

# test 404 status
test_psgi
    app => builder {
        enable 'Cache',
            match_url => [ '^/notfound$' ],
            status => 200,
            cache_dir => $cache_dir;
        $st404_inside;
    },
    client => sub {
        my $cb = shift;
        my $res = $cb->( GET "http://localhost/notfound" );
        is $res->decoded_content, 'bad';
    };
is $st404_ran, 1;
test_psgi
    app => builder {
        enable 'Cache',
            match_url => [ '^/notfound$' ],
            status => 200,
            cache_dir => $cache_dir;
        $st404_inside;
    },
    client => sub {
        my $cb = shift;
        my $res = $cb->( GET "http://localhost/notfound" );
        is $res->decoded_content, 'bad';
    };
is $st404_ran, 2; # Ran twice because no caching


done_testing;

-d $cache_dir
    and remove_tree $cache_dir;
