#!/usr/bin/env perl
#
# fasta-guess-line-length.pl
# by Kirill Kryukov, 2020, public domain
#
# Usage: fasta-guess-line-length.pl INPUT.fa >LENGTH
#

use strict;

binmode STDOUT;

my $file = $ARGV[0];
if (!defined $file) { die "File is not specified\n"; }

my $max_len = 0;
my $n_continuous_seq_lines = 0;

open(my $IN, '<', $file) or die "Can't open \"$file\"\n";
binmode $IN;
while (<$IN>)
{
    if (substr($_, 0, 1) eq '>') { $n_continuous_seq_lines = 0; next; }
    s/[\x0D\x0A]+$//;
    my $len = length($_);
    if ($len > $max_len) { $max_len = $len; }
    $n_continuous_seq_lines++;
    if ($n_continuous_seq_lines >= 2) { last; }
}
close $IN;

print $max_len;
