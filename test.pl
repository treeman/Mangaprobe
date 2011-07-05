#!/usr/bin/perl -w
use utf8;
use locale;

use Modern::Perl;
use Test::More;
use Carp;
use LWP::Simple;

use Util;
use Util::StoreHash;
use Manga;

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

#Manga::load_from_disk();


#Manga::print_stored_manga();

#map { say $_ } Manga::get_manga (@manga);

#Manga::manga_updater();

Manga::init();

my $t = time;
Manga::check_manga (@manga);
my $passed = time() - $t;

my @parts = gmtime($passed);
my ($d, $h, $m, $s) = @parts[7, 2, 1, 0];
say "${s}s to retrieve";

#sleep 10;
map { say $_ } Manga::get_manga (@manga);
Manga::close();

done_testing();

