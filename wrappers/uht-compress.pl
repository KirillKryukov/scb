#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use File::Copy qw(move);
use Getopt::Long;

my ($out, $wrapper_only);
GetOptions(
    'out=s'        => \$out,
    'wrapper-only' => \$wrapper_only,
)
or die "Can't parse command line arguments\n";
if (!defined $out) { die "Output file is not specified\n"; }

my $name = basename($out);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }


my $temp_prefix = "$temp_dir/$name.uht-c";
my $temp_fasta     = "$temp_prefix-fa";
my $temp_names     = "$temp_prefix-names";
my $temp_lengths   = "$temp_prefix-lengths";
my $temp_soft_mask = "$temp_prefix-soft-mask";
my $temp_sequence  = "$temp_prefix-seq";
my $temp_fasta_2   = "$temp_dir/$name.fasta";

my $buf_size = 1000000;
my $buffer;

binmode STDIN;

open(my $FA, '>', $temp_fasta) or die "Can't create temporary file \"$temp_fasta\"\n";
binmode $FA;
while (read(STDIN, $buffer, $buf_size)) { print $FA $buffer; }
close $FA;

run("fasta-guess-line-length.pl '$temp_fasta' >'$out.line-length'");

my $cmd = "fasta-to-names-lengths-sequence --names '$temp_names' --lengths '$temp_lengths' <'$temp_fasta'"
          . " | sequence-soft-mask-remove --mask '$temp_soft_mask'"
          . ' | sequence-split-to-lines --line-length 80'
          . " >'$temp_sequence'";
run($cmd);

open(my $T, '>', $temp_fasta_2) or die "Can't create \"$temp_fasta_2\"\n";
binmode $T;
print $T ">\n";
close $T;

run("cat '$temp_sequence' >>'$temp_fasta_2'");

run("zstd -c -1 <'$temp_names' >'$out.names'");
run("zstd -c -1 <'$temp_lengths' >'$out.lengths'");
run("zstd -c -1 <'$temp_soft_mask' >'$out.soft-mask'");

if ($wrapper_only)
{
    move($temp_fasta_2, $out);
}
else
{
    my $cmd = "UHT-UHT-compress '$temp_fasta_2' >/dev/null";
    run($cmd);
    my $temp_uht = "$temp_dir/${name}_1.uht";
    if (!-e $temp_uht) { die "Can't find \"$temp_uht\" after $cmd\n"; }
    move($temp_uht, $out);
    unlink $temp_fasta_2;
}

unlink $temp_fasta;
unlink $temp_names;
unlink $temp_lengths;
unlink $temp_soft_mask;
unlink $temp_sequence;

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
