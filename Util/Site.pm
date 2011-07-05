#!/usr/bin/perl -w

use Modern::Perl;
use LWP::Simple;

use threads;
use threads::shared;
use Thread::Queue;
use Thread::Semaphore;

package Site;

my %sites :shared;
my %sites_gotten :shared;
my %sites_waiting :shared;
my $site_lock = Thread::Semaphore->new();

# Default cache time
my $store_site = 60;

sub get
{
    my ($url, $cache_time) = @_;

    $cache_time = $store_site if !defined($cache_time);

    download_site ($url, $cache_time);

    while (1) {
        $site_lock->down();
            my $site = $sites{$url};
        $site_lock->up();

        if (defined ($site)) {
            return $site;
        }
        else {
            threads::yield();
            sleep 1;
        }
    }
}

# Will not block the semaphore while waiting for site to download
# Will return immediately if someone else is fetching or we have a valid site
sub download_site
{
    my ($url, $cache_time) = @_;

    $site_lock->down();
        my $has_site = $sites{$url};
        my $gotten = $sites_gotten{$url};
    $site_lock->up();

    # We have a valid site
    if (defined ($has_site) && time - $gotten <= $cache_time) {
        return;
    }

    $site_lock->down();
        my $is_blocking = $sites_waiting{$url};
        $sites_waiting{$url} = 1;
    $site_lock->up();

    # Already someone downloading the site
    return if $is_blocking;

    #say "Nobody is blocking!";
    my $t = time;

    #say "Downloading: $url";
    my $site = LWP::Simple::get $url;
    my $time = time;

    $site_lock->down();
        delete $sites_waiting{$url};
        $sites{$url} = $site;
        $sites_gotten{$url} = $time;
    $site_lock->up();

    my $passed = time - $t;

    my @parts = gmtime($passed);
    my ($d, $h, $m, $s) = @parts[7, 2, 1, 0];

    #say "$url downloaded at $s";
}

# Download sites in parallell, requires cache_time. Set to 0 for force download
# Will block until done
sub download_sites
{
    my $cache_time = shift;
    my @threads;

    for my $site (@_) {
        push (@threads, (threads->create(\&Site::download_site, $site, $cache_time)));
    }

    while (scalar @threads) {
        my @not_done;
        for my $thr (@threads) {
            if ($thr->is_joinable) {
                $thr->join();
            }
            else {
                push (@not_done, $thr);
            }
        }
        @threads = @not_done;
    }
}

