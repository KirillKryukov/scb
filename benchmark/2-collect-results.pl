#!/usr/bin/env perl
#
# 2-collect-results.pl
# by Kirill Kryukov, 2020, public domain
#

use strict;
use File::Basename qw(basename dirname);
use File::Slurp;
use File::Glob qw(:bsd_glob);
use File::Path qw(make_path);
use Sort::Versions;
use List::Util qw(min max sum);
use Storable qw(nstore);

my $all_results_dir = './3-results';
my $all_summary_dir = './4-summary';
my $web_site_data_dir = 'C:/www/sequence-compression-benchmark-v2/data';
my $ctime_rel_error_scatter_data_file   = './4-summary/ctime-rel-error-scatter-data.tsv';
my $dtime_rel_error_scatter_data_file   = './4-summary/dtime-rel-error-scatter-data.tsv';
my $cmem_rel_error_scatter_data_file    = './4-summary/cmem-rel-error-scatter-data.tsv';
my $dmem_rel_error_scatter_data_file    = './4-summary/dmem-rel-error-scatter-data.tsv';
my $ctime_rel_error_histogram_data_file = './4-summary/ctime-rel-error-histogram-data.tsv';
my $dtime_rel_error_histogram_data_file = './4-summary/dtime-rel-error-histogram-data.tsv';
my $cmem_rel_error_histogram_data_file  = './4-summary/cmem-rel-error-histogram-data.tsv';
my $dmem_rel_error_histogram_data_file  = './4-summary/dmem-rel-error-histogram-data.tsv';

my $empty_run_memory_use = 1638;

my %banned_datasets = (
#    '51d Picea abies GCA_900067695.1 2016-11-09',
);

my %banned_ctags = (
    'zstdw30-22w30-1t' => 1, 'zstdw30-22w30-4t' => 1
);
foreach my $a ('', 'r') { foreach my $b ('50', '100', '200', '300', '500') { foreach my $c ('1', '22') { $banned_ctags{"beetl$a-e$b-zst$c"} = 1; } } }
foreach my $a ('', 'r') { foreach my $b ('100', '300') { foreach my $c ('1', '22') { $banned_ctags{"beetl$a-b$b-zst$c"} = 1; } } }
foreach my $k (2 .. 11) { $banned_ctags{"leon-$k"} = 1; $banned_ctags{"leonr-$k"} = 1; }
for (my $i = 1; $i <= 9; $i++) { $banned_ctags{"fqzcomp-${i}p"} = 1; }

my %replace_cname = ('geco2' => 'geco');
my %replace_ctag = (
    '2bit0' => 'wrap-2bit', '2bitr0' => 'wrap-2bit',
    'acfa0' => 'wrap-ac-fa', 'acseq0' => 'wrap-ac-seq',
    'alapy0' => 'wrap-alapy', 'alapyr0' => 'wrap-alapy',
    'blast0' => 'wrap-blast', 'blastr0' => 'wrap-blast',
    'beetl0' => 'wrap-beetl', 'beetlr0' => 'wrap-beetl',
    'dcom0' => 'wrap-dcom',
    'dnax0' => 'wrap-dnax', 'dnaxr0' => 'wrap-dnax',
    'dsrc0' => 'wrap-dsrc', 'dsrcr0' => 'wrap-dsrc',
    'fastqz0' => 'wrap-fastqz', 'fastqzr0' => 'wrap-fastqz',
    'fqs0' => 'wrap-fqs',
    'fqzcomp0' => 'wrap-fqzcomp', 'fqzcompr0' => 'wrap-fqzcomp',
    'geco0' => 'wrap-geco', 'geco20' => 'wrap-geco2',
    'gtz0' => 'wrap-gtz',
    'harc0' => 'wrap-harc', 'harcr0' => 'wrap-harc',
    'jarvis0' => 'wrap-jarvis',
    'kic0' => 'wrap-kic', 'kicr0' => 'wrap-kic',
    'leon0' => 'wrap-leon', 'leonr0' => 'wrap-leon',
    'minicom0' => 'wrap-minicom', 'minicomr0' => 'wrap-minicom',
    'lfastqc0' => 'wrap-lfastqc', 'lfastqcr0' => 'wrap-lfastqc',
    'lfqc0' => 'wrap-lfqc',
    'nuht0' => 'wrap-nuht', 'nuhtr0' => 'wrap-nuht',
    'pfish0' => 'wrap-pfish', 'pfishr0' => 'wrap-pfish',
    'quip0' => 'wrap-quip', 'quipr0' => 'wrap-quip',
    'spring0' => 'wrap-spring-l',
    'springshort0' => 'wrap-spring-s', 'springshortr0' => 'wrap-spring-s',
    'uht0' => 'wrap-uht', 'xm0' => 'wrap-xm',

    '2bitr' => '2bit',
    'alapyr-f' => 'alapy-f', 'alapyr-m' => 'alapy-m', 'alapyr-b' => 'alapy-b',
    'blastr' => 'blast',
    'dlimr' => 'dlim',
    'dnaxr-0' => 'dnax-0', 'dnaxr-1' => 'dnax-1', 'dnaxr-2' => 'dnax-2', 'dnaxr-3' => 'dnax-3',
    'fastqzf'  => 'fastqz-fast', 'fastqzs'  => 'fastqz-slow',
    'fastqzfr' => 'fastqz-fast', 'fastqzsr' => 'fastqz-slow',
    'gtz1t-1' => 'gtz-1-1t', 'gtz1t-9' => 'gtz-9-1t', 'gtz4t-1' => 'gtz-1-4t', 'gtz4t-9' => 'gtz-9-4t',
    'harc1t'  => 'harc-1t', 'harc4t'  => 'harc-4t',
    'harcr1t' => 'harc-1t', 'harcr4t' => 'harc-4t',
    'kic-0'  => 'kic-0-4t', 'kic-1'  => 'kic-1-4t', 'kic-2-8'  => 'kic-2-8-4t',
    'kicr-0' => 'kic-0-4t', 'kicr-1' => 'kic-1-4t', 'kicr-2-8' => 'kic-2-8-4t',
    'lfastqcr' => 'lfastqc',
    'lfqc' => 'lfqc-4t',
    'mfcr-1' => 'mfc-1', 'mfcr-2' => 'mfc-2', 'mfcr-3' => 'mfc-3',
    'nuhtr' => 'nuht',
    'pfishr' => 'pfish',
    'quipr' => 'quip',
    'spring1t' => 'spring-l-1t', 'spring4t' => 'spring-l-4t',
    'springshort1t-500'  => 'spring-s-1t', 'springshort4t-500'  => 'spring-s-4t',
    'springshortr1t-500' => 'spring-s-1t', 'springshortr4t-500' => 'spring-s-4t',

    'bcm-16m' => 'bcm-b16', 'bcm-128m' => 'bcm-b128', 'bcm-1024m' => 'bcm-b1024', 'bcm-2047m' => 'bcm-b2047',
    'nakamichi-28-81000-i' => 'nakamichi',
    'pigz-0-1t' => 'copy-pigz-0-1t', 'pigz-0-4t' => 'copy-pigz-0-4t', 'copy' => 'copy-cat',
    'zstdw30-22w30-1t' => 'zstd-22w30-1t', 'zstdw30-22w30-4t' => 'zstd-22w30-4t',
    'zstdw31c30h30s26-22w31c30h30s26-1t' => 'zstd-22w31-1t',
    'zstdw31c30h30s26-22w31c30h30s26-4t' => 'zstd-22w31-4t'
);
for (my $i = 1; $i <= 7; $i++) { $replace_ctag{"acfa-$i"} = "ac-fa-$i"; }
for (my $i = 1; $i <= 7; $i++) { $replace_ctag{"acseq-$i"} = "ac-seq-$i"; }
for (my $i = 1; $i <= 9; $i++) { $replace_ctag{"brieflz3600m-$i"} = "brieflz-$i-3600m"; }
for (my $i = 1; $i <= 9; $i++) { $replace_ctag{"fqzcompr-$i"} = "fqzcomp-$i"; }
for (my $i = 1; $i <= 9; $i++) { $replace_ctag{"fqzcompr-${i}p"} = "fqzcomp-${i}p"; }
for (my $i = 2; $i <= 31; $i++) { $replace_ctag{"leonr-$i"} = "leon-$i"; }
for ('b50-zst1', 'b100-zst1', 'b200-zst1', 'b300-zst1', 'b500-zst1', 'b50-zst22', 'b100-zst22', 'b200-zst22', 'b300-zst22', 'b500-zst22') { $replace_ctag{"beetlr-$_"} = "beetl-$_"; }
foreach my $m (0, 1, 2) { foreach my $t (1, 4) { $replace_ctag{"dsrc${t}t-m$m"} = "dsrc-m$m-${t}t"; } }
foreach my $m (0, 1, 2) { foreach my $t (1, 4) { $replace_ctag{"dsrcr${t}t-m$m"} = "dsrc-m$m-${t}t"; } }
foreach my $t (1, 4) { $replace_ctag{"fqs-4000-${t}t"} = "fqs-${t}t"; }
foreach my $t (1, 4) { $replace_ctag{"minicom${t}t"} = "minicom-${t}t"; }
foreach my $t (1, 4) { $replace_ctag{"minicomr${t}t"} = "minicom-${t}t"; }

my %is_special_purpose_compressor = (
    '2bit' => 1, 'ac' => 1, 'alapy' => 1,
    'beetl' => 1, 'blast' => 1, 'dcom' => 1, 'dlim' => 1, 'dnax' => 1, 'dsrc' => 1,
    'fastqz' => 1, 'fqs' => 1, 'fqzcomp' => 1, 'geco' => 1, 'gtz' => 1,
    'harc' => 1, 'jarvis' => 1, 'kic' => 1, 'leon' => 1, 'lfastqc' => 1, 'lfqc' => 1,
    'mfc' => 1, 'minicom' => 1, 'naf' => 1, 'nuht' => 1,
    'pfish' => 1, 'quip' => 1, 'spring' => 1, 'uht' => 1, 'xm' => 1,
    'wrap' => 1
);
my %is_copy_compressor = ('copy' => 1, 'wrap' => 1);

$Storable::canonical = 1;

if (!-e $all_summary_dir) { make_path($all_summary_dir); }
if (!-e $all_summary_dir or !-d $all_summary_dir) { die "Can't create \"$all_summary_dir\"\n"; }
if (!-e $web_site_data_dir) { make_path($web_site_data_dir); }
if (!-e $web_site_data_dir or !-d $web_site_data_dir) { die "Can't create \"$web_site_data_dir\"\n"; }

my %dataset_sizes;
foreach my $dir (bsd_glob("$all_results_dir/*"))
{
    if (!-d $dir) { next; }
    if ($dir =~ /\.0$/) { next; }
    my $dtag = basename($dir);
    if (exists $banned_datasets{$dtag}) { next; }
    my $summary_path = "$all_summary_dir/$dtag.stat";
    my $size_file = "$dir/size";
    if (!-e $size_file) { print "Size unknown for $dtag: can't find file \"$size_file\"\n"; next; }
    chomp(my $original_size = read_file($size_file));
    $dataset_sizes{$dtag} = $original_size;
}



my (%compressor_name_to_index, @compressor_names, @compressor_is_special);
my (%setting_name_to_index, @setting_names, @setting_cis);

my (%all_cnames, %all_snames, %sname_to_cname);
foreach my $dtag (keys %dataset_sizes)
{
    my $res_dir = "$all_results_dir/$dtag";
    foreach my $res_file (bsd_glob("$res_dir/*"))
    {
        my $ctag = basename($res_file);
        if ($ctag eq 'size') { next; }
        if (exists $banned_ctags{$ctag}) { next; }
        if (-s $res_file == 0) { next; }

        if (exists $replace_ctag{$ctag}) { $ctag = $replace_ctag{$ctag}; }
        if (exists $banned_ctags{$ctag}) { next; }

        my $cname = $ctag;
        $cname =~ s/-.*$//;
        if (exists $replace_cname{$cname}) { $cname = $replace_cname{$cname}; }

        my $sname = $ctag;

        $all_cnames{$cname} = 1;
        $all_snames{$sname} = 1;
        $sname_to_cname{$sname} = $cname;
    }
}

{
    my $ci = 0;
    foreach my $cname (sort { $a cmp $b } keys %all_cnames)
    {
        $compressor_name_to_index{$cname} = $ci;
        $compressor_names[$ci] = $cname;
        $compressor_is_special[$ci] = exists($is_copy_compressor{$cname}) ? 0 : exists($is_special_purpose_compressor{$cname}) ? 2 : 1;
        $ci++;
    }
}

{
    my $si = 0;
    foreach my $sname (sort { $a cmp $b } keys %all_snames)
    {
        $setting_name_to_index{$sname} = $si;
        $setting_names[$si] = $sname;
        $setting_cis[$si] = $compressor_name_to_index{$sname_to_cname{$sname}};
        $si++;
    }
}



my (%dataset_tag_to_index, %dataset_name_to_index, @dataset_tags, @dataset_names, @dataset_dates, @dataset_sizes);

my @data_by_dataset;
my (@ctime_rel_errors, @dtime_rel_errors, @cmem_rel_errors, @dmem_rel_errors);
my (%ctime_rel_err_histogram, %dtime_rel_err_histogram, %cmem_rel_err_histogram, %dmem_rel_err_histogram);



foreach my $dtag (sort { $dataset_sizes{$a} <=> $dataset_sizes{$b} } keys %dataset_sizes)
{
    my $res_dir = "$all_results_dir/$dtag";
    my $summary_path = "$all_summary_dir/$dtag.stat";

    my $original_size = $dataset_sizes{$dtag};
    my $dname = substr($dtag, 4);
    if ($dname !~ /\s(\d{4}-\d{2}-\d{2})$/) { die "Dataset with unknown date: \"$dtag\"\n"; }
    my $date = $1;
    $dname =~ s/\s+(\d{4}-\d{2}-\d{2})$//;

    my $di = scalar(@dataset_tags);
    $dataset_tags[$di] = $dtag;
    $dataset_tag_to_index{$dtag} = $di;
    $dataset_names[$di] = $dname;
    $dataset_name_to_index{$dname} = $di;
    $dataset_dates[$di] = $date;
    $dataset_sizes[$di] = $original_size;

    open(my $S, '>', $summary_path) or die "Can't create \"$summary_path\"\n";
    binmode $S;
    print $S "# Original size: $original_size\n";
    print $S "# Compressor\tSetting\tSize\tCTime\tDTime\tCMem\tDMem\n";

    foreach my $res_file (sort { versioncmp($a, $b) } bsd_glob("$res_dir/*"))
    {
        my $ctag = basename($res_file);
        if ($ctag eq 'size') { next; }
        if (exists $banned_ctags{$ctag}) { next; }
        if (-s $res_file == 0) { next; }

        if (exists $replace_ctag{$ctag}) { $ctag = $replace_ctag{$ctag}; }
        my $sname = $ctag;
        my $cname = $ctag;
        $cname =~ s/-.*$//;
        if (exists $replace_cname{$cname}) { $cname = $replace_cname{$cname}; }

        my $ci = $compressor_name_to_index{$cname};
        my $si = $setting_name_to_index{$sname};

        open(my $R, '<', $res_file) or die "Can't open \"$res_file\"\n";
        binmode $R;
        chomp(my $size_str = <$R>);
        chomp(my $ctime_str = <$R>);
        chomp(my $dtime_str = <$R>);
        chomp(my $cmem_str = <$R>);
        chomp(my $dmem_str = <$R>);
        close $R;
        if ( $size_str !~ /^\d+$/ or
             $ctime_str !~ /^[\d\.\s]+$/ or
             $dtime_str !~ /^[\d\.\s]+$/ or
             $cmem_str !~ /^[\d\s]+$/ or
             $dmem_str !~ /^[\d\s]+$/ ) { print "Can't read \"$res_file\"\n"; next; }

        my $csize = int($size_str);
        my @ctimes = split(' ', $ctime_str);
        my @dtimes = split(' ', $dtime_str);
        my @cmems = split(' ', $cmem_str);
        my @dmems = split(' ', $dmem_str);

        for (my $i = 0; $i < scalar(@cmems); $i++) { $cmems[$i] -= $empty_run_memory_use; } 
        for (my $i = 0; $i < scalar(@dmems); $i++) { $dmems[$i] -= $empty_run_memory_use; } 

        for (my $i = 0; $i < scalar(@cmems); $i++) { $cmems[$i] /= 1000; } 
        for (my $i = 0; $i < scalar(@dmems); $i++) { $dmems[$i] /= 1000; } 

        my $min_ctime = min(@ctimes);
        my $min_dtime = min(@dtimes);
        my $avg_ctime = sprintf('%.5f', sum(@ctimes) / scalar(@ctimes));
        my $avg_dtime = sprintf('%.5f', sum(@dtimes) / scalar(@dtimes));
        my $avg_cmem = sprintf('%.2f', sum(@cmems) / scalar(@cmems));
        my $avg_dmem = sprintf('%.2f', sum(@dmems) / scalar(@dmems));

        @{$data_by_dataset[$di]->[$si]} = ($csize, $avg_ctime, $avg_dtime, $avg_cmem, $avg_dmem);

        my $use_for_c_error_stats = ( (scalar(@ctimes) == 10) and (scalar(@cmems) == 10) and $ctimes[0] <= 10);
        my $use_for_d_error_stats = ( (scalar(@dtimes) == 10) and (scalar(@dmems) == 10) and $dtimes[0] <= 10);

        if ($use_for_c_error_stats)
        {
            my $ctime_avg_abs_error = 0;
            for (my $i = 0; $i < scalar(@ctimes); $i++) { $ctime_avg_abs_error += abs($avg_ctime - $ctimes[$i]); }
            $ctime_avg_abs_error /= scalar(@ctimes);
            my $ctime_avg_rel_error = $ctime_avg_abs_error / $avg_ctime;
            push @ctime_rel_errors, ($avg_ctime, $ctime_avg_rel_error);

            for (my $i = 0; $i < scalar(@ctimes); $i++)
            {
                $ctime_rel_err_histogram{ sprintf( '%.0f', ($ctimes[$i] - $avg_ctime) / $avg_ctime * 100 ) }++;
            }
        }

        if ($use_for_d_error_stats)
        {
            my $dtime_avg_abs_error = 0;
            for (my $i = 0; $i < scalar(@dtimes); $i++) { $dtime_avg_abs_error += abs($avg_dtime - $dtimes[$i]); }
            $dtime_avg_abs_error /= scalar(@dtimes);
            my $dtime_avg_rel_error = $dtime_avg_abs_error / $avg_dtime;
            push @dtime_rel_errors, ($avg_dtime, $dtime_avg_rel_error);

            for (my $i = 0; $i < scalar(@dtimes); $i++)
            {
                $dtime_rel_err_histogram{ sprintf( '%.0f', ($dtimes[$i] - $avg_dtime) / $avg_dtime * 100 ) }++;
            }
        }

        if ($use_for_c_error_stats)
        {
            my $cmem_avg_abs_error = 0;
            for (my $i = 0; $i < scalar(@cmems); $i++) { $cmem_avg_abs_error += abs($avg_cmem - $cmems[$i]); }
            $cmem_avg_abs_error /= scalar(@cmems);
            my $cmem_avg_rel_error = $cmem_avg_abs_error / $avg_cmem;
            push @cmem_rel_errors, ($avg_cmem, $cmem_avg_rel_error);

            for (my $i = 0; $i < scalar(@cmems); $i++)
            {
                $cmem_rel_err_histogram{ sprintf( '%.0f', ($cmems[$i] - $avg_cmem) / $avg_cmem * 100 ) }++;
            }
        }

        if ($use_for_d_error_stats)
        {
            my $dmem_avg_abs_error = 0;
            for (my $i = 0; $i < scalar(@dmems); $i++) { $dmem_avg_abs_error += abs($avg_dmem - $dmems[$i]); }
            $dmem_avg_abs_error /= scalar(@dmems);
            my $dmem_avg_rel_error = $dmem_avg_abs_error / $avg_dmem;
            push @dmem_rel_errors, ($avg_dmem, $dmem_avg_rel_error);

            for (my $i = 0; $i < scalar(@dmems); $i++)
            {
                $dmem_rel_err_histogram{ sprintf( '%.0f', ($dmems[$i] - $avg_dmem) / $avg_dmem * 100 ) }++;
            }
        }

        print $S "$cname\t$ctag\t$csize\t$avg_ctime\t$avg_dtime\t$avg_cmem\t$avg_dmem\n";
    }
    close $S;
}



nstore(\%dataset_tag_to_index,     "$web_site_data_dir/dataset-tag-to-index.hash");
nstore(\%dataset_name_to_index,    "$web_site_data_dir/dataset-name-to-index.hash");
nstore(\@dataset_tags,             "$web_site_data_dir/dataset-tags.array");
nstore(\@dataset_names,            "$web_site_data_dir/dataset-names.array");
nstore(\@dataset_dates,            "$web_site_data_dir/dataset-dates.array");
nstore(\@dataset_sizes,            "$web_site_data_dir/dataset-sizes.array");

nstore(\%compressor_name_to_index, "$web_site_data_dir/compressor-name-to-index.hash");
nstore(\@compressor_names,         "$web_site_data_dir/compressor-names.array");
nstore(\@compressor_is_special,    "$web_site_data_dir/compressor-is-special.array");

nstore(\%setting_name_to_index,    "$web_site_data_dir/setting-name-to-index.hash");
nstore(\@setting_names,            "$web_site_data_dir/setting-names.array");
nstore(\@setting_cis,              "$web_site_data_dir/setting-cis.array");

nstore(\@data_by_dataset,          "$web_site_data_dir/data-by-dataset.array");

open(my $CE, '>', $ctime_rel_error_scatter_data_file) or die;
binmode $CE;
for (my $i = 0; $i < scalar(@ctime_rel_errors); $i += 2)
{
    print $CE sprintf( "%.5f\t%.5f\n", $ctime_rel_errors[$i], $ctime_rel_errors[$i + 1] * 100 );
}
close $CE;
open(my $DE, '>', $dtime_rel_error_scatter_data_file) or die;
binmode $DE;
for (my $i = 0; $i < scalar(@dtime_rel_errors); $i += 2)
{
    print $DE sprintf( "%.5f\t%.3f\n", $dtime_rel_errors[$i], $dtime_rel_errors[$i + 1] * 100);
}
close $DE;
open(my $CME, '>', $cmem_rel_error_scatter_data_file) or die;
binmode $CME;
for (my $i = 0; $i < scalar(@cmem_rel_errors); $i += 2)
{
    print $CME sprintf( "%.5f\t%.5f\n", $cmem_rel_errors[$i] / 1000, $cmem_rel_errors[$i + 1] * 100 );
}
close $CME;
open(my $DME, '>', $dmem_rel_error_scatter_data_file) or die;
binmode $DME;
for (my $i = 0; $i < scalar(@dmem_rel_errors); $i += 2)
{
    print $DME sprintf( "%.5f\t%.3f\n", $dmem_rel_errors[$i] / 1000, $dmem_rel_errors[$i + 1] * 100);
}
close $DME;

open(my $CTEH, '>', $ctime_rel_error_histogram_data_file) or die;
binmode $CTEH;
for (my $e = -100; $e <= 100; $e++)
{
    print $CTEH "$e\t", (exists($ctime_rel_err_histogram{$e}) ? $ctime_rel_err_histogram{$e} : 0), "\n";
}
close $CTEH;

open(my $DTEH, '>', $dtime_rel_error_histogram_data_file) or die;
binmode $DTEH;
for (my $e = -100; $e <= 100; $e++)
{
    print $DTEH "$e\t", (exists($dtime_rel_err_histogram{$e}) ? $dtime_rel_err_histogram{$e} : 0), "\n";
}
close $DTEH;

open(my $CMEH, '>', $cmem_rel_error_histogram_data_file) or die;
binmode $CMEH;
for (my $e = -100; $e <= 100; $e++)
{
    print $CMEH "$e\t", (exists($cmem_rel_err_histogram{$e}) ? $cmem_rel_err_histogram{$e} : 0), "\n";
}
close $CMEH;

open(my $DMEH, '>', $dmem_rel_error_histogram_data_file) or die;
binmode $DMEH;
for (my $e = -100; $e <= 100; $e++)
{
    print $DMEH "$e\t", (exists($dmem_rel_err_histogram{$e}) ? $dmem_rel_err_histogram{$e} : 0), "\n";
}
close $DMEH;



sub commify
{
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}
