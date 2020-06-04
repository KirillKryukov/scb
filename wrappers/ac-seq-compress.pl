#!/usr/bin/env perl

use strict;
use Cwd qw(cwd);
use File::Basename qw(basename);
use File::Copy qw(move);
use File::Path qw(make_path remove_tree);
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

my $start_dir = cwd();

my $new_temp_dir = "$temp_dir/$name-ac-c-dir";
make_path($new_temp_dir);
$ENV{'TMP'} = $new_temp_dir;
$ENV{'TEMP'} = $new_temp_dir;
$ENV{'TMPDIR'} = $new_temp_dir;

my $temp_prefix = "$new_temp_dir/$name";
my $temp_fasta    = "$temp_prefix.fa";
my $temp_names    = "$temp_prefix-names";
my $temp_lengths  = "$temp_prefix-lengths";
my $temp_sequence = "$temp_prefix";

my $buf_size = 1000000;
my $buffer;

binmode STDIN;

open(my $FA, '>', $temp_fasta) or die "Can't create temporary file \"$temp_fasta\"\n";
binmode $FA;
while (read(STDIN, $buffer, $buf_size)) { print $FA $buffer; }
close $FA;

run("fasta-guess-line-length.pl '$temp_fasta' >'$out.line-length'");

my $cmd = "fasta-to-names-lengths-sequence --names '$temp_names' --lengths '$temp_lengths' <'$temp_fasta' >'$temp_sequence'";
run($cmd);

run("zstd -c -1 <'$temp_names' >'$out.names'");
run("zstd -c -1 <'$temp_lengths' >'$out.lengths'");

if (!chdir($new_temp_dir)) { die "Can't change directory to \"$new_temp_dir\"\n"; }

if (!$wrapper_only)
{
    run("AC -l $level '$name' >/dev/null 2>&1");
}

if (!chdir($start_dir)) { die "Can't change directory to \"$start_dir\"\n"; }

if ($wrapper_only)
{
    move($temp_sequence, $out);
}
else
{
    my $temp_compressed = "$temp_sequence.co";
    if (!-e $temp_compressed) { die "Can't find \"$temp_compressed\"\n"; }
    move($temp_compressed, $out);
    unlink $temp_sequence;
}

unlink $temp_fasta;
unlink $temp_names;
unlink $temp_lengths;

remove_tree($new_temp_dir);

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
