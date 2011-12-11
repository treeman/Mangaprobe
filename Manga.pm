#!/usr/bin/perl -w

use Modern::Perl;
use Mojo::DOM;
use Mojo::UserAgent;

use LWP::Simple;

use threads;
use threads::shared;
use Thread::Queue;
use Thread::Semaphore;

package Manga;

use Carp;
use POSIX 'setsid';

use Util::Site;
use Util::StoreHash;

# Info about all manga we're tracking
my $manga_info :shared = &share({});

my $cache_time :shared = 90;
my $last_update :shared;

my $lock = Thread::Semaphore->new();

sub get_manga
{
    my @manga;
    for (@_) {
        my $f = format_manga (get_info ($_));
        push (@manga, $f) if $f;
    }
    return @manga;
}
sub get_short_manga
{
    my @manga;
    for (@_) {
        my $f = short_format_manga (get_info ($_));
        push (@manga, $f) if $f;
    }
    return @manga;
}

sub init
{
    load_from_disk();
}

sub start_updater
{
    my $updater = threads->create(\&manga_updater);
    $updater->detach();
}

sub daemonize_updater
{
    open STDIN, '/dev/null' or croak "Can't read /dev/null: $!";
    open STDOUT, '>/dev/null' or croak "Can't write to /dev/null: $!";
    defined(my $pid = fork) or croak "Can't fork: $!";
    exit if $pid;
    croak "Can't start a new session: $!" if setsid == -1;
    open STDERR, '>&STDOUT' or croak "Can't dup stdout: $!";

    manga_updater();
}

sub close
{
    store_to_disk();
}

sub load_from_disk
{
    my $in_store = StoreHash::retrieve_hash_hash ("manga");
    if (defined ($in_store)) {
        $manga_info = shared_clone($in_store);
    }
}

sub store_to_disk
{
    StoreHash::store_hash_hash ("manga", $manga_info);
}

sub get_info
{
    my ($manga) = @_;

    if (has_manga ($manga)) {
        $lock->down();
        my $info = $manga_info->{$manga};
        $lock->up();
        return $info;
    }
    else {
        my $info = fetch_info ($manga);
        if (is_useful ($info)) {
            add_info ($info);
            return $info;
        }
        else {
            return undef;
        }
    }
}

sub get_cached_info
{
    my ($manga) = @_;

    $lock->down();
    my $info = $manga_info->{$manga};
    $lock->up();
    return $info;
}

sub check_manga
{
    my @manga = @_;
    my @threads;

    Site::preload ("http://mangastream.com/manga");
    Site::preload ("http://mangable.com/manga-list/");
    Site::preload ("http://www.mangareader.net/");

    for my $manga (@manga) {
        my $info = fetch_info ($manga);
        if (is_useful ($info)) {
            add_info ($info);
        }
    }

    $lock->down();
    $last_update = time;
    $lock->up();
}

sub recheck_known_manga
{
    $lock->down();
    my @manga = (keys %$manga_info);
    $lock->up();

    check_manga (@manga);
}

sub fetch_info
{
    my ($manga) = @_;

    my $info = {};

    my @funcs = (\&get_mangastream_info, \&get_mangable_info, \&get_mangareader_info);

    for my $f (@funcs) {
        my $new = &$f($manga);
        $new->{"date"} = time;
        update_info ($info, $new);
    }

    return $info;
}

sub has_manga
{
    my ($manga) = @_;

    $lock->down();
    my $has = exists ($manga_info->{$manga})
        && is_useful ($manga_info->{$manga});
    $lock->up();

    return $has;
}

sub manga_updater
{
    while (1) {
        $lock->down();
        my $shall_update = !defined ($last_update)
            || $cache_time - (time - $last_update) >= 0;
        $lock->up();

        if ($shall_update) {
            recheck_known_manga();
            store_to_disk();
            sleep $cache_time;
        }
        else {
            $lock->down();
            my $time_left = $cache_time - (time - $last_update);
            $lock->up();

            sleep $time_left if $time_left > 0;
        }
    }
}

sub add_info
{
    my ($info) = @_;
    my $manga = $$info{"manga"};

    $lock->down();

    # If we need to update
    if (!exists ($manga_info->{$manga}) ||
        is_better ($manga_info->{$manga}, $info))
    {
        $manga_info->{$manga} = shared_clone($info);
    }
    $lock->up();
}

sub update_info
{
    my ($old, $new) = @_;

    if (is_better ($old, $new)) {
        %$old = %$new;
    }
}

sub is_useful
{
    my ($info) = @_;
    return defined($info) &&
           defined($$info{"manga"}) &&
           defined($$info{"link"}) &&
           defined($$info{"chapter"});
}

sub is_newer
{
    my ($old, $new) = @_;

    return $new->{"chapter"} > $old->{"chapter"};
}

sub is_better
{
    my ($old, $new) = @_;

    if (!is_useful ($old)) {
        return 1;
    }
    elsif (!is_useful ($new)) {
        return 0;
    }
    else {
        return is_newer ($old, $new);
    }
}

sub format_manga
{
    my ($info) = @_;

    if (is_useful ($info)) {
        my $txt;

        my ($site) = $info->{"link"} =~ /^http:\/\/(?:www\.)?([^\/]+)/;
        $txt .= $info->{"manga"}." ".$info->{"chapter"};
        if ($info->{"title"}) {
            $txt .= ": ".$info->{"title"};
        }

        $txt .= " ($site)";

        $txt .= "\n";
        $txt .= Util::format_date ($info->{"date"});

        return $txt;
    }
    else {
        return "";
    }
}

sub short_format_manga
{
    my ($info) = @_;

    if (is_useful ($info)) {
        my $txt = $info->{"manga"}." ".$info->{"chapter"};

        return $txt;
    }
    else {
        return "";
    }
}

sub convert_url
{
    my ($url, $repl) = @_;
    $repl = '_' unless defined $repl;

    $url = lc ($url);
    $url =~ s/\s/$repl/g;
    return $url;
}

# Will only check latest manga updates
sub get_mangareader_info
{
    my ($manga) = @_;

    my $site = Site::get "http://www.mangareader.net/", $cache_time;
    my $dom = Mojo::DOM->new($site);

    my $info = {};

    my $manga_url = convert_url ($manga, '-');

    for my $e ($dom->find('a[href^="/'.$manga_url.'"]')->each)
    {
        my $link = "http://www.mangareader.net" . $e->{href};

        if ($e->{href} =~ /(\d+)$/) {

            my $ch = $1;

            # Find newest if many links
            if (!defined ($$info{"chapter"}) || $ch > $$info{"chapter"}) {

                $$info{"chapter"} = $ch;
                $$info{"title"} = "";
                $$info{"link"} = $link;

                $$info{"manga"} = $manga;
                $$info{"date"} = "";
            }
        }
    }

    return $info;
}

sub get_mangastream_info
{
    my ($manga) = @_;

    my $site = Site::get "http://mangastream.com/manga", $cache_time;
    my $dom = Mojo::DOM->new($site);

    my $info = {};

    my $manga_url = convert_url ($manga);

    for my $e ($dom->find("a[href^=\"\/read\/$manga_url\"]")->each)
    {
        my $link = "http://mangastream.com" . $e->{href};
        my $title = $e->text;

        $title =~ /(\d*)
                \s+-\s+
                (.+)
                /xsi;

        my $ch = $1;
        my $ch_title = $2;

        $$info{"chapter"} = $ch;
        $$info{"title"} = $ch_title;
        $$info{"link"} = $link;

        $$info{"manga"} = $manga;
        $$info{"date"} = "";

        return $info;
    }

    return undef;
}

sub get_mangable_info
{
    my ($manga) = @_;
    my $manga_url = convert_url ($manga);

    my $info = {};

    my $site = Site::get "http://mangable.com/$manga_url", $cache_time;
    my $dom = Mojo::DOM->new($site);

    for my $e ($dom->find("a[href*=\"$manga_url\"]")->each)
    {
        my $link = $e->{href};
        my $ch_info = $e->at('p')->at('b')->text;

        $ch_info =~ /(\d+)/s;
        my $ch = $1;

        my $ch_title = $e->at('p')->at('span');
        if ($ch_title) {
            $ch_title = $ch_title->text;
            $ch_title =~ /\s*:\s*(.*)\s*/;
            $ch_title = $1;
        }
        else {
            $ch_title = "";
        }

        $$info{"chapter"} = $ch;
        $$info{"title"} = $ch_title;
        $$info{"link"} = $link;

        $$info{"manga"} = $manga;
        $$info{"date"} = "";

        return $info;
    }

    return undef;
}

sub get_month_num {
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
    return $months{$_[0]};
}

sub print_manga
{
    my (%info) = @_;

    say "----------------------------------------------------------------";
    say $info{"manga"}, " ", $info{"chapter"}, " - ", $info{"title"};
    say $info{"link"}, " ", $info{"date"};
}

sub print_stored_manga
{
    for my $manga (values %$manga_info) {
        print_manga %$manga;
    }
}

