#!/usr/bin/perl -w
use utf8;
use locale;

use Modern::Perl;
use Test::More;
use Carp;
use LWP::Simple;
use Getopt::Long;

use lib "/home/tree/projects/mangaprobe";

use Util;
use Util::StoreHash;
use Manga;

my $short_format;   # Short format
my $conky;          # Format for use in conky
my $debug;          # Debug mode
my $cached;         # List cached manga
my $updater;        # Launch manga updater

Getopt::Long::Configure ("bundling");
GetOptions(
    's' => \$short_format,
    'conky' => \$conky,
    'debug' => \$debug,
    'c|cached' => \$cached,
    'u|updater' => \$updater,
);

my @manga = (
    "Naruto",
    "One Piece",
    "Historys Strongest Disciple Kenichi",
    "Beelzebub",
    "Bleach",
    "Hajime no Ippo",
    "Gamaran",
    "Detective Conan",
    "Vinland Saga",
    "Futari Ecchi",

    "Berserk",
    "Kekkaishi",
    "The Breaker",
);

Manga::init();

if ($updater) {
    Manga::daemonize_updater();
}
else {
    if (!$cached) {
        Manga::check_manga (@manga);
    }

    my @manga_info;
    if ($cached) {
        for (@manga) {
            my $f = Manga::get_cached_info ($_);
            push (@manga_info, $f) if $f;
        }
    }
    else {
        for (@manga) {
            my $f = Manga::get_info ($_);
            push (@manga_info, $f) if $f;
        }
    }

    sub date_cmp {
        $a->{"date"} > $b->{"date"}
    }

    @manga_info = sort date_cmp @manga_info;

    if ($short_format) {
        map { say Manga::short_format_manga ($_) } @manga_info;
    }
    else {
        map { say Manga::format_manga ($_) } @manga_info;
    }

    if ($debug) { Manga::print_manga }

    Manga::close();
}

