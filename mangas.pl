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
my $help;           # Should I comment? :)

Getopt::Long::Configure ("bundling");
GetOptions(
    's' => \$short_format,
    'conky' => \$conky,
    'debug' => \$debug,
    'c|cached' => \$cached,
    'u|updater' => \$updater,
    'h|help' => \$help,
);

if ($help) {
    say "Manga prober.";
    say "-h --help";
    say "  show this message";
    say "-u --updater";
    say "  start background updater";
    say "-c --cached";
    say "  only list cached manga info";
    say "-s";
    say "  short format listing";
    say "--debug";
    say "supersecret option :O";
    exit;
}

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
    "Fairy Tail",
);

Manga::init();

if ($updater) {
    say "updater daemonized";
    Manga::daemonize_updater();
}
else {

    my @manga_info;
    if ($cached) {
        for (@manga) {
            my $f = Manga::get_cached_info ($_);
            push (@manga_info, $f) if $f;
        }
    }
    else {
        Manga::check_manga (@manga);
        for (@manga) {
            my $f = Manga::get_info ($_);
            push (@manga_info, $f) if $f;
        }
    }

    my @sorted_manga = sort { $b->{"date"} <=> $a->{"date"} } @manga_info;

    if ($short_format) {
        map { say Manga::short_format_manga ($_) } @sorted_manga;
    }
    else {
        map { say Manga::format_manga ($_) } @sorted_manga;
    }

    if ($debug) { Manga::print_manga }

    Manga::close();
}

