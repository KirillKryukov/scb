#!/usr/bin/env perl

use strict;
use File::Basename qw(basename);
use File::Glob qw(:bsd_glob);
use File::Path qw(make_path remove_tree);
use Getopt::Long;

binmode STDOUT;

my ($in, $rna, $wrapper_only);
GetOptions(
    'in=s'         => \$in,
    'rna'          => \$rna,
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

my $new_temp_dir = "$temp_dir/$name-beetl-d-dir";
make_path($new_temp_dir);
$ENV{'TMP'} = $new_temp_dir;
$ENV{'TEMP'} = $new_temp_dir;
$ENV{'TMPDIR'} = $new_temp_dir;

my $len = `head -n 1 '$in.line-length'`;

my $temp_prefix = "$new_temp_dir/$name";
my $temp_names     = "$temp_prefix-names";
my $temp_lengths   = "$temp_prefix-lengths";
my $temp_soft_mask = "$temp_prefix-soft-mask";
my $temp_n         = "$temp_prefix-n";
my $temp_iupac     = "$temp_prefix-iupac";
my $temp_seq_head;

if ($wrapper_only)
{
    $temp_seq_head = $in;
}
else
{
    my @archives = bsd_glob("$in.beetl-B*");
    foreach my $archive (@archives)
    {
        my $file = $new_temp_dir . '/' . basename($archive);
        $file =~ s/\.[^.]+$//;
        run("zstd -dc <'$archive' >'$file'");
    }

    my $beetl_name = "$new_temp_dir/$name.beetl"; 
    my $temp_unbeetl = "$temp_prefix-unbeetl";
    my $cmd = "beetl-unbwt -i '$beetl_name' -o '$temp_unbeetl' --output-format fasta --temp-directory '$new_temp_dir' --no-temp-subdir >/dev/null 2>&1";
    run($cmd);
    if (!-e $temp_unbeetl) { die "Can't find \"$temp_unbeetl\" after \"$cmd\"\n"; }

    $temp_seq_head = "$temp_prefix-seq-head";
    run("fasta-to-sequence <'$temp_unbeetl' >'$temp_seq_head'");
}

run("zstd -dc <'$in.lengths' >'$temp_lengths'");
run("zstd -dc <'$in.names' >'$temp_names'");
run("zstd -dc <'$in.soft-mask' >'$temp_soft_mask'");
run("zstd -dc <'$in.n' >'$temp_n'");
run("zstd -dc <'$in.iupac' >'$temp_iupac'");

my $cmd = "cat '$temp_seq_head' '$in.tail'"
          . ($rna ? ' | sequence-t2u' : '')
          . " | sequence-iupac-add --iupac '$temp_iupac'"
          . " | sequence-n-add --n '$temp_n'"
          . " | sequence-soft-mask-add --mask '$temp_soft_mask'"
          . " | fasta-from-names-lengths-sequence --names '$temp_names' --lengths '$temp_lengths' --line-length $len";
run($cmd);

remove_tree($new_temp_dir);

sub run
{
    my ($cmd) = @_;
    my $error = system($cmd);
    if ($error) { die "Command failed:\n$cmd\n"; }
}
