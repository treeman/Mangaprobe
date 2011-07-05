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
my $site_lock = Thread::Semaphore->new();

my $store_site = 60;

sub get
{
    my ($url) = @_;

    $site_lock->down();

    if (defined($sites{$url})) {
        my $passed = time() - $sites_gotten{$url};

        if ($passed > $store_site) {
            $sites{$url} = LWP::Simple::get $url;
            $sites_gotten{$url} = time();
        }
    }
    else {
            $sites{$url} = LWP::Simple::get $url;
            $sites_gotten{$url} = time();
    }
    my $ret = $sites{$url};

    $site_lock->up();

    return $ret;
}

