#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use File::Copy qw(move);
use Getopt::Long;

my ($out, $level, $wrapper_only);
GetOptions(
    'out=s'        => \$out,
    'level=i'      => \$level,
    'wrapper-only' => \$wrapper_only,
)
or die "Can't parse command line arguments\n";
if (!defined $out) { die "Output file is not specified\n"; }
if (!defined $level) { die "Level is not specified\n"; }

my $name = basename($out);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $temp_fasta  = "$temp_dir/$name.fa";

my $buf_size = 1000000;
my $buffer;

binmode STDIN;

open(my $FA, '>', $temp_fasta) or die "Can't create temporary file \"$temp_fasta\"\n";
binmode $FA;
while (read(STDIN, $buffer, $buf_size)) { print $FA $buffer; }
close $FA;

if ($wrapper_only)
{
    move($temp_fasta, $out);
}
else
{
    run("AC -l $level '$temp_fasta' >/dev/null 2>&1");
    my $temp_compressed = "$temp_fasta.co";
    if (!-e $temp_compressed) { die "Can't find \"$temp_compressed\"\n"; }
    move($temp_compressed, $out);
    unlink $temp_fasta;
}

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
