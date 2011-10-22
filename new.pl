#!/usr/bin/perl -w

use Modern::Perl;
use Mojo::DOM;
use Mojo::UserAgent;

my $ua = Mojo::UserAgent->new;

my @manga = (
    "Naruto",
    "One Piece",
    "Historys Strongest Disciple Kenichi",
    "Beelzebub",
    "Bleach",
    "Hajime no Ippo",
    "Gamaran",
    "Fairy Tail",

    "Berserk",
    "Kekkaishi",
    "The Breaker",
    "Detective Conan",
    "Vinland Saga",
    "Futari Ecchi",
);

for my $m (@manga) {
    say "Searching mangastream for $m";
    my $info = mangastream_info ($m);
    print_manga ($info);

    say "";

    say "Searching mangable for $m";
    my $info = mangable_info ($m);
    print_manga ($info);
}

sub url_name
{
    my ($url, $replace) = @_;

    if (!$replace) {
        $replace = "_";
    }

    $url = lc ($url);
    $url =~ s/\s/$replace/g;
    return $url;
}

sub mangable_info
{
    my ($manga) = @_;

    my $manga_url = url_name ($manga, '_');

    my $info = {};

    my $dom = $ua->get("http://mangable.com/$manga_url")->res->dom;

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

sub mangastream_info
{
    my ($manga) = @_;

    my $manga_url = url_name ($manga, '_');

    my $info = {};

    my $dom = $ua->get('http://mangastream.com/manga')->res->dom;

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

sub print_manga
{
    my ($info) = @_;

    if (is_useful ($info)) {

        say "----------------------------------------------------------------";
        say $$info{"manga"}, " ", $$info{"chapter"}, " - ", $$info{"title"};
        say $$info{"link"}, " ", $$info{"date"};
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

