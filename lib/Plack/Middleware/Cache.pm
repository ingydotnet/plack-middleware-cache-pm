use strict; use warnings;
package Plack::Middleware::Cache;
our $VERSION = '0.19';

use parent 'Plack::Middleware';

use Plack::Util;
use Plack::Util::Accessor qw(match_url status cache_dir debug);
use Plack::Request;

use Digest::MD5 qw(md5_hex);
use Storable qw(nstore retrieve);
use File::Path qw(make_path);
use List::Util 1.33 qw(none pairgrep);

sub call {
    my ($self, $env) = @_;
    my $match_url = $self->match_url or return;
    $match_url = [ $match_url ] unless ref $match_url;
    my $request_uri = $env->{REQUEST_URI};
    for my $regexp (@$match_url) {
        if ($request_uri =~ /$regexp/) {
            return $self->cache_response($env);
        }
    }
    return $self->app->($env);
}

sub cache_response {
    my ($self, $env) = @_;
    my $dir = $self->cache_dir || 'cache';
    my $status = $self->status;
    $status = [ $status ] if ( $status && !ref $status );
    my $request_uri = $env->{REQUEST_URI};
    my $digest = md5_hex($request_uri);
    my $file = "$dir/$digest";
    if (-e $file) {
        warn "Plack::Middleware::Cache found: $request_uri - $digest"
            if $self->debug;
        my $cache = retrieve($file) or die;
        my $request = Plack::Request->new($env);
        my $response = $request->new_response($cache->[0]);
        $response->headers($cache->[1]);
        $response->headers->remove_header('Set-Cookie');
        $response->body($cache->[2]);
        return $response->finalize;
    }
    warn "Plack::Middleware::Cache fetch: $request_uri - $digest"
        if $self->debug;
    return Plack::Util::response_cb(
        $self->app->($env),
        sub {
            my $res = shift;
            make_path($dir) unless -d $dir;
            return sub {
                if (not defined $_[0]) {
                    if ( $status ) {
                        my $res_status = $res->[0];
                        return if ( none { $res_status == $_ } @$status );
                    }
                    # Remove Set-Cookie header
                    if ( @{ $res->[1] } ) {
                        @{ $res->[1] } = pairgrep { $a =~ /^set[_-]cookie$/i } @{ $res->[1] };
                    }
                    nstore $res, $file;
                    return;
                }
                return $_[0];
            }
        }
    );
}

1;
