package Plack::Middleware::Cache;
use 5.008003;
use strict;
use warnings;
use parent 'Plack::Middleware';
use Plack::Util;
use Plack::Util::Accessor qw(match_url cache_dir debug);

use Digest::MD5 qw(md5_hex);
use Storable qw(nstore retrieve);
use File::Path qw(make_path);;

our $VERSION = '0.11';

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
        $response->body($cache->[2]);
        return $response->finalize;
    }
    warn "Plack::Middleware::Cache fetch: $request_uri - $digest"
        if $self->debug;
    return Plack::Util::response_cb(
        $self->app->($env),
        sub {
            my $cache = shift;
            make_path($dir) unless -d $dir;
            return sub {
                if (not defined $_[0]) {
                    nstore $cache, $file;
                    return;
                }
                $cache->[2] ||= '';
                $cache->[2] .= $_[0];
                return $_[0];
            }
        }
    );
}

1;

=encoding utf8

=head1 NAME

Plack::Middleware::Cache - Use Cached Responses of Certain URIs

=head1 SYNOPSIS

    builder {
        enable "Cache",
            match_url => [
                '^/foo/',
                '\\?.*xxx=.*',
            ],
            cache_dir => '/tmp/plack-cache';
        $app;
    };

=head1 DESCRIPTION

This middleware allows you to cache expensive and non-changing responses
from URIs that match a list of regular expression patterns.

=head1 PARAMETERS

The following parameters can be used:

=over

=item match_url (required)

A regexp string or array ref of regexp strings to try to match the
current URL against.

=item cache_dir (optional)

A directory to write the cached responses.

Thanks to Strategic Data for supporting the writing and release of
this module.

=item debug (optional)

Set to 1 to warn cache information.

=back

=head1 AUTHOR

Ingy döt Net <ingy@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011. Ingy döt Net.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
