#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use File::Copy qw(move);
use Getopt::Long;

my ($out, $rna, $wrapper_only);
GetOptions(
    'out=s'        => \$out,
    'rna'          => \$rna,
    'wrapper-only' => \$wrapper_only,
)
or die "Can't parse command line arguments\n";
if (!defined $out) { die "Output file is not specified\n"; }

my $name = basename($out);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $temp_fasta = "$temp_dir/$name.2bit-c-temp-fasta";
my $buf_size = 1000000;
my $buffer;

binmode STDIN;

my $cmd = "fasta-replace-RYSWKMBDHV-with-A --diff '$out.iupac'" .
            ($rna ? ' | fasta-u2t' : '') . " >'$temp_fasta'";

open(my $FA, '|-', $cmd) or die "Can't create temporary file \"$temp_fasta\"\n";
binmode $FA;
while (read(STDIN, $buffer, $buf_size)) { print $FA $buffer; }
close $FA;

run(qq`grep '>' '$temp_fasta' | sed -r 's/^\\S+//' | zstd -c -1 >'$out.name-ends'`);
run("fasta-guess-line-length.pl '$temp_fasta' >'$out.line-length'");

if ($wrapper_only)
{
    run("grep '>' '$temp_fasta' | sed 's/.*//' | zstd -c -1 >'$out.name-ends-2'");
    move($temp_fasta, $out);
}
else
{
    run("faToTwoBit -long '$temp_fasta' '$out'");
    unlink $temp_fasta;
}

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
