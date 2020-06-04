#!/usr/bin/env perl

use strict;
use Cwd qw(abs_path);
use File::Basename qw(basename);
use Getopt::Long;

binmode STDOUT;

my ($in, $wrapper_only);
GetOptions(
    'in=s'         => \$in,
    'wrapper-only' => \$wrapper_only,
)
or die "Can't parse command line arguments\n";
if (!defined $in) { die "Input file is not specified\n"; }
if (!-e $in or !-f $in) { die "Can't find the input file\n"; }

my $name = basename($in);
$name =~ s/\s/_/g;

my $temp_dir = $ENV{'TMPDIR'};
if (!defined $temp_dir) { die "Environment variable 'TMPDIR' is not set\n"; }
if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory\n"; }

my $len = `head -n 1 '$in.line-length'`;

my $temp_prefix = "$temp_dir/$name.ac-d";
my $temp_sequence;
my $temp_names   = "$temp_prefix-names";
my $temp_lengths = "$temp_prefix-lengths";

if ($wrapper_only)
{
    $temp_sequence = $in;
}
else
{
    my $ac_link = "$temp_dir/$name.fa.co";
    system("ln -f -s '" . abs_path($in) . "' '$ac_link'");

    my $cmd = "AD '$ac_link' >/dev/null 2>&1";
    my $error = system($cmd);
    if ($error) { die "Command failed: $cmd\n"; }

    $temp_sequence = "$temp_dir/$name.fa.de";
    if (!-e $temp_sequence) { die "Failed to produce temporary sequence file \"$temp_sequence\""; }
    unlink $ac_link;
}

run("zstd -dc <'$in.lengths' >'$temp_lengths'");
run("zstd -dc <'$in.names' >'$temp_names'");

my $cmd = "fasta-from-names-lengths-sequence --names '$temp_names' --lengths '$temp_lengths' --line-length $len <'$temp_sequence'";
run($cmd);

if (!$wrapper_only) { unlink $temp_sequence; }
unlink $temp_names;
unlink $temp_lengths;

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
