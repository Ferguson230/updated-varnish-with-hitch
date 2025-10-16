#!/usr/local/cpanel/3rdparty/bin/perl

use strict;
use warnings;

use CGI;
use JSON::PP;
use FindBin;
use File::Spec;
use File::Path qw(make_path);
use Fcntl qw(:flock);
use Cpanel::SafeRun::Timed qw(timedsaferun); # Provided by cPanel

$| = 1;

my $cgi = CGI->new;
my $json = JSON::PP->new->utf8->pretty(0);

print $cgi->header('application/json');

my $action = $cgi->param('action') || '';
my $payload = read_payload();

my $response;

eval {
    if ($payload && ref $payload eq 'HASH' && !$action) {
        $action = $payload->{action} // '';
    }

    my %routes = (
        status        => \&handle_status,
        install       => \&handle_install,
        service       => \&handle_service,
        purge         => \&handle_purge,
        metrics       => \&handle_metrics,
        update_certs  => \&handle_update_certs,
        settings_get  => \&handle_settings_get,
        settings_update => \&handle_settings_update,
    );

    die "Unknown action" unless $routes{$action};

    $response = $routes{$action}->($payload // {});
    $response->{status} //= 'ok';
};

if ($@) {
    $response = {
        status  => 'error',
        message => "$@",
    };
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

sub run_cmd {
    my ($desc, @cmd) = @_;
    my $output = timedsaferun( 300, @cmd );
    my $status = $?;
    return ($status, $output);
}

sub config_dir {
    my @dirs = (
        '/opt/varnish-whm-manager/config',
        '/usr/local/varnish-whm-manager/config',
        File::Spec->catdir($FindBin::Bin, '../../service/config'),
        File::Spec->catdir($FindBin::Bin, '../../../service/config'),
    );
    for my $dir (@dirs) {
        return $dir if -d $dir;
    }
    return $dirs[0];
}

sub settings_path {
    my $dir = config_dir();
    make_path($dir, { mode => 0755 });
    return File::Spec->catfile($dir, 'settings.json');
}

sub default_settings {
    return {
        security_headers => {
            enabled            => JSON::PP::false,
            max_age            => 31536000,
            include_subdomains => JSON::PP::true,
            preload            => JSON::PP::false,
            frame_options      => 'SAMEORIGIN',
            referrer_policy    => 'strict-origin-when-cross-origin',
            permissions_policy => 'geolocation=()',
            content_type_options => 'nosniff',
            xss_protection       => '1; mode=block',
        },
    };
}

sub load_settings {
    my $path = settings_path();
    if (-f $path) {
        if (open my $fh, '<', $path) {
            local $/ = undef;
            my $raw = <$fh>;
            close $fh;
            my $data = eval { $json->decode($raw) };
            return $data if $data && ref $data eq 'HASH';
        }
    }
    return default_settings();
}

sub save_settings {
    my ($settings) = @_;
    my $path = settings_path();
    if (open my $fh, '>', $path) {
        flock($fh, LOCK_EX);
        print {$fh} $json->encode($settings);
        close $fh;
        chmod 0644, $path;
    } else {
        die "Unable to write settings";
    }
}

sub render_configuration {
    my $bin = bin_path('provision.sh') or die "provision.sh not found";
    my ($status, $out) = run_cmd('render', $bin, '--render-config');
    if ($status != 0) {
        die "Configuration render failed: $out";
    }
}

sub handle_status {
    my ($payload) = @_;
    my $bin = bin_path('varnishctl.sh') or die "varnishctl.sh not found";
    my ($status, $out) = run_cmd('status', $bin, 'status', '--format=json');
    if ($status != 0) {
        die "Failed to obtain status";
    }
    my $decoded = eval { $json->decode($out) } || {};
    return {
        data => $decoded,
    };
}

sub handle_metrics {
    return handle_status(@_);
}

sub handle_install {
    my $bin = bin_path('provision.sh') or die "provision.sh not found";
    my ($status, $out) = run_cmd('install', $bin);
    if ($status != 0) {
        die "Provisioning failed: $out";
    }
    return {
        message => 'Provisioning completed',
        log     => $out,
    };
}

sub handle_service {
    my ($payload) = @_;
    my $op = $payload->{operation} || $cgi->param('operation') || '';
    die "Missing operation" unless $op;
    my %allowed = map { $_ => 1 } qw(start stop restart reload enable disable);
    die "Unsupported operation" unless $allowed{$op};
    my $bin = bin_path('varnishctl.sh') or die "varnishctl.sh not found";
    my ($status, $out) = run_cmd('service', $bin, $op);
    if ($status != 0) {
        die "Service command failed: $out";
    }
    return { message => "${op} executed", log => $out };
}

sub handle_purge {
    my ($payload) = @_;
    my $scope = $payload->{scope} || $cgi->param('scope') || 'all';
    my $bin = bin_path('varnishctl.sh') or die "varnishctl.sh not found";
    my ($status, $out);
    if ($scope eq 'all') {
        ($status, $out) = run_cmd('purge', $bin, 'flush');
    } elsif ($scope eq 'url') {
        my $url = $payload->{url} || $cgi->param('url') || '';
        die "Missing URL" unless $url;
        ($status, $out) = run_cmd('purge', $bin, 'purge', $url);
    } else {
        die "Unsupported purge scope";
    }
    if ($status != 0) {
        die "Purge failed: $out";
    }
    return { message => 'Purge requested', log => $out };
}

sub handle_update_certs {
    my $bin = bin_path('update_certs.sh') or die "update_certs.sh not found";
    my ($status, $out) = run_cmd('certs', $bin);
    if ($status != 0) {
        die "Certificate sync failed: $out";
    }
    return { message => 'Certificates synced', log => $out };
}

sub handle_settings_get {
    my $settings = load_settings();
    return { settings => $settings };
}

sub handle_settings_update {
    my ($payload) = @_;
    my $incoming = $payload->{security_headers} || {};
    my $settings = load_settings();
    my $sec = $settings->{security_headers} ||= {};

    $sec->{enabled} = $incoming->{enabled} ? JSON::PP::true : JSON::PP::false;
    if (exists $incoming->{max_age} && defined $incoming->{max_age} && $incoming->{max_age} =~ /\A\d+\z/) {
        my $max_age = $incoming->{max_age} + 0;
        $max_age = 0 if $max_age < 0;
        $max_age = 63072000 if $max_age > 63072000; # cap at 2 years
        $sec->{max_age} = $max_age;
    }
    $sec->{include_subdomains} = $incoming->{include_subdomains} ? JSON::PP::true : JSON::PP::false;
    $sec->{preload} = $incoming->{preload} ? JSON::PP::true : JSON::PP::false;
    for my $key (qw(frame_options referrer_policy permissions_policy content_type_options xss_protection)) {
        my $val = $incoming->{$key};
        if (defined $val) {
            $val =~ s/[\r\n]//g;
            $sec->{$key} = $val;
        }
    }

    save_settings($settings);
    render_configuration();

    return {
        message  => 'Settings updated',
        settings => $settings,
    };
}
