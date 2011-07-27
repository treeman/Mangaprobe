#!/usr/bin/perl -w

use utf8;
use locale;

package Util;

use Modern::Perl;
use Test::More;

sub remove_matches
{
    my ($origin, $remove) = @_;

    for (@{$remove}) {
        delete $origin->{$_};
    }

    return %{$origin};
}

sub get_month_num {
    my ($m) = @_;
    my %months = (
        Jan => "01",
        Feb => "02",
        Mar => "03",
        Apr => "04",
        May => "05",
        Jun => "06",
        Jul => "07",
        Aug => "08",
        Sep => "09",
        Okt => "10",
        Nov => "11",
        Dec => "12",
    );

    return $months{$m};
}

sub get_month_name {
    my ($m) = @_;
    my @months = (
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Okt",
        "Nov",
        "Dec",
    );

    return $months[$m - 1];
}

sub date_help
{
    return "Insert a common date id please. Example: today, 19140104 or 3/12";
}

# Return as YYYYMMDD
# If it fails return undef
sub parse_as_date
{
    my ($s) = @_;

    return undef if !$s;

    if ($s =~ /^today$/i) {
        return make_date (time);
    }
    elsif ($s =~ /^tomorrow$/i) {
        return make_date (time + 60 * 60 * 24);
    }
    elsif ($s =~ /^yesterday$/i) {
        return make_date (time - 60 * 60 * 24);
    }
    elsif ($s =~ /^\d{8}$/) {
        return $s;
    }
    elsif ($s =~ /^\d{6}$/) {
        return "20$s";
    }
    elsif ($s =~ /(\d)\/(\d)\s+(\d+)/) {
        my ($d, $m, $y) = ($1, $2, $3);

        if ($y < 1000) { $y = "20$y"; }
        if ($m < 10) { $m = "0$m"; }
        if ($d < 10) { $d = "0$d"; }

        return "$y$m$d";
    }
    elsif ($s =~ /(\d)\/(\d)/) {
        my ($d, $m) = ($1, $2);
        my ($y) = (localtime(time))[5];
        $y += 1900;

        if ($m < 10) { $m = "0$m"; }
        if ($d < 10) { $d = "0$d"; }

        return "$y$m$d";
    }
    else {
        return undef;
    }
}

# Need a better name
# Transform time to the format YYYYMMDD
sub make_date
{
    my ($t) = @_;

    my ($y, $m, $d) = (localtime($t))[5, 4, 3];
    $y += 1900;
    $m += 1;
    if ($m < 10) { $m = "0$m"; }
    if ($d < 10) { $d = "0$d"; }

    return "$y$m$d";
}

# Make a pretty date from time
sub format_date
{
    my ($time) = @_;

    my @parts = localtime($time);
    my ($y, $m, $d) = @parts[5, 4, 3];
    $y += 1900;
    $m += 1;

    return "$d " . get_month_name ($m) . " $y";
}

# Need a better name?
sub format_time
{
    my ($time) = @_;

    my @parts = localtime($time);
    my ($d, $h, $m, $s) = @parts[7, 2, 1, 0];

    my $msg;
    if ($d) {
        $msg .= "${d}d ";
    }
    if ($h) {
        $msg .= "${h}h ";
    }
    if ($m) {
        $msg .= "${m}m ";
    }
    $msg .= "${s}s ";

    return $msg;
}

# Add in spaces if the string isn't at least this long
sub pre_space_str
{
    my ($str, $min) = @_;

    # For some reason it doesn't count these chars as it should. Simple workaround.
    my $botch = $str;
    $botch =~ s/(ä|ö|å)/x/g;
    #$botch =~ s/[^[:ascii:]]/x/g;
    my $spaces = $min - length ($botch);

    return " " x $spaces . $str;
}

sub post_space_str
{
    my ($str, $min) = @_;

    # For some reason it doesn't count these chars as it should. Simple workaround.
    my $botch = $str;
    $botch =~ s/(ä|ö|å)/x/g;
    #$botch =~ s/[^[:ascii:]]/x/g;
    my $spaces = $min - length ($botch);
    return $str . " " x $spaces;
}

# Swedish lower case
sub lc_se
{
    my ($txt) = @_;
    $txt = lc($txt);

    my %map = ('Å' => 'å', 'Ä' => 'ä', 'Ö' => 'ö');
    $txt =~ s/(Å|Ä|Ö)/$map{$1}/g;
    #$txt =~ s/[^[:ascii:]]//g;
    return $txt;
}

sub crude_remove_html
{
    my ($arg) = @_;
    $arg =~ s/<[^>]+>//g;
    return $arg;
}

sub date_test
{
    is (parse_as_date ("20100102"), "20100102", "simple parse_as_date");
    is (parse_as_date ("890104"), "20890104", "shorter date");
    is (parse_as_date ("89"), undef, "undef");

    like (parse_as_date ("today"), qr/\d{8}/, "today");
    like (parse_as_date ("tomorrow"), qr/\d{8}/, "tomorrow");
    like (parse_as_date ("yesterday"), qr/\d{8}/, "yesterday");

    my $today = parse_as_date ("today");
    my $tomorrow = parse_as_date ("tomorrow");
    my $yesterday = parse_as_date ("yesterday");

    is ($today - $tomorrow, -1, "today - tomorrow");
    is ($today - $yesterday, 1, "today - yesterday");
    is ($tomorrow - $yesterday, 2, "tomorrow - yesterday");

    is (parse_as_date ("3/4"), "20110403", "day month");
    is (parse_as_date ("3/4 03"), "20030403", "day month short year");
    is (parse_as_date ("3/4 1903"), "19030403", "day month long year");
}

1;

