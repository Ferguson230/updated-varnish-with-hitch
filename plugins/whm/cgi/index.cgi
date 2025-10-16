#!/usr/local/cpanel/3rdparty/bin/perl
use strict;
use warnings;
use FindBin;
use File::Spec;

my $static = File::Spec->catfile($FindBin::Bin, 'index.html');
print "Content-Type: text/html; charset=utf-8\n\n";
if (open my $fh, '<', $static) {
    local $/ = undef;
    my $html = <$fh>;
    close $fh;
    print $html;
} else {
    print "<h1>Varnish Manager</h1><p>Unable to load interface.</p>";
}
