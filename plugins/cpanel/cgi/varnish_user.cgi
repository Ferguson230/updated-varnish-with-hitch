#!/usr/local/cpanel/3rdparty/bin/perl

use strict;
use warnings;

use CGI;
use JSON::PP;
use FindBin;
use File::Spec;
use Cpanel::SafeRun::Timed qw(timedsaferun);
use Cpanel::API ();         # For domain listing (fallback if available)
use File::Basename qw(basename);
use POSIX qw(geteuid);

$| = 1;

my $cgi = CGI->new;
my $json = JSON::PP->new->utf8->pretty(0);

print $cgi->header('application/json');

my $action = $cgi->param('action') || '';
my $payload = read_payload();
if ($payload && ref $payload eq 'HASH' && !$action) {
    $action = $payload->{action} // '';
}

my $response;

eval {
    my %routes = (
        status  => \&handle_status,
        purge   => \&handle_purge,
        flush   => \&handle_flush,
        domains => \&handle_domains,
    );
    die "Unknown action" unless $routes{$action};
    $response = $routes{$action}->($payload // {});
    $response->{status} //= 'ok';
};

if ($@) {
    $response = { status => 'error', message => "$@" };
}

print $json->encode($response);
exit;

sub read_payload {
    my $type = $ENV{'CONTENT_TYPE'} // '';
    return if !$ENV{'CONTENT_LENGTH'};
    my $raw;
    read(STDIN, $raw, $ENV{'CONTENT_LENGTH'}) or return;
    if ($type =~ m{application/json}) {
        my $decoded = eval { $json->decode($raw) };
        return $decoded if $decoded;
    }
    return;
}

sub bin_path {
    my ($binary) = @_;
    my @locations = (
        '/opt/varnish-whm-manager/bin',
        '/usr/local/varnish-whm-manager/bin',
        File::Spec->catdir($FindBin::Bin, '../../service/bin'),
        File::Spec->catdir($FindBin::Bin, '../../../service/bin'),
    );
    for my $dir (@locations) {
        my $path = File::Spec->catfile($dir, $binary);
        return $path if -x $path;
    }
    return;
}

sub sudo_prefix {
    my @cmd = ('sudo');
    push @cmd, '-n';
    return @cmd;
}

sub run_cmd {
    my (@cmd) = @_;
    my $output = timedsaferun(120, @cmd);
    my $status = $?;
    return ($status, $output);
}

sub handle_status {
    my $bin = bin_path('varnishctl.sh') or die "varnishctl.sh not found";
    my @cmd = (sudo_prefix(), $bin, 'status', '--format=json');
    my ($status, $out) = run_cmd(@cmd);
    die "Status command failed" if $status != 0;
    my $decoded = eval { $json->decode($out) } || {};
    return { data => $decoded };
}

sub handle_purge {
    my ($payload) = @_;
    my $url = $payload->{url} || $cgi->param('url') || '';
    die "Missing URL" unless $url;
    my $bin = bin_path('varnishctl.sh') or die "varnishctl.sh not found";
    my @cmd = (sudo_prefix(), $bin, 'purge', $url);
    my ($status, $out) = run_cmd(@cmd);
    die "Purge failed" if $status != 0;
    return { message => 'URL purge requested', log => $out };
}

sub handle_flush {
    my $bin = bin_path('varnishctl.sh') or die "varnishctl.sh not found";
    my @cmd = (sudo_prefix(), $bin, 'flush');
    my ($status, $out) = run_cmd(@cmd);
    die "Flush failed" if $status != 0;
    return { message => 'Full cache flush requested', log => $out };
}

sub handle_domains {
    my $uapi = '/usr/local/cpanel/bin/uapi';
    my $user = $ENV{'REMOTE_USER'} // '';
    if (!$user) {
        my $uid = geteuid();
        my @pw = getpwuid($uid);
        $user = $pw[0] // '';
    }

    # Prefer uapi CLI to avoid LIVEAPI context issues
    if (-x $uapi) {
        my ($status, $out) = run_cmd($uapi, '--output', 'json', 'Domains', 'list_domains');
        if ($status == 0) {
            my $decoded = eval { $json->decode($out) } || {};
            if ($decoded->{status} && $decoded->{status} == 1) {
                return { domains => $decoded->{data} };
            }
        }
        # Try explicit --user if available
        if ($user) {
            my ($s2, $o2) = run_cmd($uapi, '--output', 'json', "--user=$user", 'Domains', 'list_domains');
            if ($s2 == 0) {
                my $dec2 = eval { $json->decode($o2) } || {};
                if ($dec2->{status} && $dec2->{status} == 1) {
                    return { domains => $dec2->{data} };
                }
            }
        }
    }

    # Fallback to Cpanel::API if available
    eval {
        my $api = Cpanel::API->new();
        my $result = $api->call('UAPI', 'Domains', 'list_domains');
        if ($result && $result->{status} == 1) {
            die "__OK__" . $json->encode({ domains => $result->{data} });
        }
    };
    if ($@ && $@ =~ /^__OK__(.*)/s) {
        my $payload = $1;
        my $res = eval { $json->decode($payload) } || { domains => {} };
        return $res;
    }

    # Last resort: scan /var/cpanel/userdata/<user>
    if ($user) {
        my $base = "/var/cpanel/userdata/$user";
        if (-d $base) {
            my %seen;
            my @all;
            opendir(my $dh, $base);
            while (defined(my $entry = readdir($dh))) {
                next if $entry =~ /^\./;
                next if $entry =~ /^(main|cache|ssl|apache|nginx|subdomain|addons)($|\.)/;
                next if $entry =~ /\.yaml$/; # we'll handle names without extensions
                if ($entry =~ /[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/) {
                    $seen{$entry} ||= 1;
                }
            }
            closedir($dh);

            @all = sort keys %seen;

            # Try to detect main domain from 'main' file
            my $main_domain = '';
            my $main_file = "$base/main";
            if (-f $main_file) {
                if (open my $mf, '<', $main_file) {
                    while (my $line = <$mf>) {
                        if ($line =~ /main_domain:\s*([^\s]+)/) {
                            $main_domain = $1; last;
                        }
                    }
                    close $mf;
                }
            }
            $main_domain = $all[0] if !$main_domain && @all;
            my @addons = grep { $_ ne $main_domain } @all;
            my $data = {
                main_domain    => $main_domain,
                addon_domains  => \@addons,
                parked_domains => [],
                sub_domains    => [],
            };
            return { domains => $data };
        }
    }
    die "Domain lookup failed";
}
