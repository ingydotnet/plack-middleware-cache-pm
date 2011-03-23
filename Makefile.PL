use inc::Module::Install;

all_from    'lib/Plack/Middleware/Cache.pm';
readme_from;
manifest_skip;
ack_xxx;
version_check;

requires 'Plack::Middleware';
requires 'Plack::Util';
requires 'Plack::Util::Accessor';
requires 'Plack::Middleware';
requires 'Digest::MD5';
requires 'Storable';
requires 'File::Path';

WriteAll;
