#!/usr/bin/perl -w

use Modern::Perl;

package StoreHash;

use Carp;

sub store_simple
{
    my ($name, %h) = @_;

    my $file = "/home/tree/projects/mangaprobe/info/$name";

    open my $fh, '>', $file or croak "Couldn't open file: $file";

    for my $key (sort keys %h) {
        print $fh "$key: $h{$key}\n";
    }

    close $fh;
}

sub retrieve_simple
{
    my ($name) = @_;

    my $file = "/home/tree/projects/mangaprobe/info/$name";

    my %h;
    if (-e $file) {
        open my $fh, '<', $file or croak "Couldn't open file: $file";

        while (<$fh>) {
            $_ =~ /^([^:]+):\s*(.*)/;

            $h{$1} = $2;
        }

        close $fh;
    }
    else {
        say "Couldn't find file: $file";
    }

    return %h;
}

# Store a hash of hashes in a very easy to read manner
sub store_hash_hash
{
    my ($name, $h) = @_;

    my $file = "/home/tree/projects/mangaprobe/Data/$name";

    open my $fh, '>', $file or croak "Couldn't open file: $file";

    for my $key (keys %$h) {
        my $hashes = "";
        my $a = $h->{$key};

        print $fh "$key:\n";

        my @vals;
        while (my ($key, $val) = (each %$a)) {
            print $fh "  $key: $val\n";
        }
    }

    close $fh;
}

# Retrieve said hash of hashes
sub retrieve_hash_hash
{
    my ($name) = @_;

    my $file = "/home/tree/projects/mangaprobe/Data/$name";

    my $outer;
    if (-e $file) {
        open my $fh, '<', $file or croak "Couldn't open file: $file";

        my $outer_key = "";
        my $inner = {};
        my $indent_lvl = 0;
        while (<$fh>) {
            $_ =~ /^(\s*)([^:]+):\s+(.*)/;
            my $spaces = 0;
            if ($1) { $spaces = length $1; }
            my $name = $2;
            my $val;
            if ($3) {
                $val = $3;
            }
            else {
                $val = "";
            }

            # New big time hash
            if ($spaces == 0) {
                if ($outer_key) {
                    $$outer{$outer_key} = $inner;
                }
                $inner = {};
                $outer_key = $name;
            }
            # Continue setting our inner hash
            else {
                $inner->{$name} = $val;
            }
        }
        if ($outer_key) {
            $$outer{$outer_key} = $inner;
        }

        close $fh;
    }

    return $outer;
}

1;

