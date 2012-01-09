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
my $update;         # Single update
my $help;           # Should I comment? :)

Getopt::Long::Configure ("bundling");
GetOptions(
    's' => \$short_format,
    'conky' => \$conky,
    'debug' => \$debug,
    'c|cached' => \$cached,
    'updater' => \$updater,
    'u|update' => \$update,
    'h|help' => \$help,
);

if ($help) {
    say "Manga prober.";
    say "-h --help";
    say "  show this message";
    say "--updater";
    say "  start background updater";
    say "-u --update";
    say "  update manga cache";
    say "-c --cached";
    say "  only list cached manga info";
    say "-s";
    say "  short format listing";
    say "--debug";
    say "supersecret option :O";
    exit;
}

my @manga = (
    "Bakuman",
    "Beelzebub",
    "Bleach",
    "Fairy Tail",
    "Futari Ecchi",
    "Gamaran",
    "Hajime no Ippo",
    "Historys Strongest Disciple Kenichi",
    "Naruto",
    "Noblesse",
    "One Piece",
    "Special Martial Arts Extreme Hell Private High School",
    "Sun-Ken Rock",
    "The Breaker New Waves",
    "Vinland Saga",
);

Manga::init();

if ($updater) {
    say "updater daemonized";
    Manga::daemonize_updater();
}
elsif ($update) {
    Manga::check_manga (@manga);
    Manga::store_to_disk();
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

    Manga::store_to_disk();

    Manga::close();
}

