#!/usr/bin/env perl
#
# 1-benchmark.pl
# by Kirill Kryukov, 2020, public domain
#
# run as:
# sudo nice -n -20 ionice -c1 su -c ./1-benchmark.pl USERNAME

use strict;
use File::Basename qw(basename dirname);
use File::Glob qw(:bsd_glob);
use File::Path qw(make_path);
use Time::HiRes qw(gettimeofday tv_interval);

my $short_time_threshold = 10;

$ENV{'PATH'} = '/data/kirill/tools/bin:' . $ENV{'PATH'};

my $test_data_source_dir = './1-test-data';
my $all_compressed_dir = './2-compressed';
my $all_results_dir = './3-results';
my $temp_dir = '/data/kirill/compressor-benchmark/temp';

my $compressor_file_pattern = 'compressors-*.txt';
my $decompressors_file = 'decompressors.txt';

if (!-e $temp_dir or !-d $temp_dir) { die "Can't find temporary directory \"$temp_dir\"\n"; }
$ENV{'TMP'} = $temp_dir;
$ENV{'TEMP'} = $temp_dir;
$ENV{'TMPDIR'} = $temp_dir;

if (!-e $test_data_source_dir or !-d $test_data_source_dir) { die "Can't find \"$test_data_source_dir\"\n"; }
if (!-e $all_compressed_dir) { make_path($all_compressed_dir); }
if (!-e $all_results_dir) { make_path($all_results_dir); }
if (!-e $all_compressed_dir or !-d $all_compressed_dir) { die "Can't create \"$all_compressed_dir\"\n"; }
if (!-e $all_results_dir or !-d $all_results_dir) { die "Can't create \"$all_results_dir\"\n"; }

my (@compressors, %decompressors, @datasets);
load_configuration();
print scalar(@compressors), " compressors, ", scalar(@datasets), " datasets\n";

my %alphabet_tag_to_extension = ('d' => 'fna', 'r' => 'fra', 'p' => 'faa', 'a' => 'fa');
my %alphabet_tag_to_comp_category = ('d' => 'fasta-dna', 'r' => 'fasta-rna', 'p' => 'fasta-protein', 'a' => 'fasta-synthetic');

foreach my $di (sort { $datasets[$a]->[0] <=> $datasets[$b]->[0] } keys @datasets)
{
    if (!-e $all_compressed_dir) { last; }

    my ($size_class, $alphabet_tag, $name, $source_ext, $source_path) = @{$datasets[$di]};
    my $abbr = $name;
    $abbr =~ s/[\-\s]//g;
    $abbr = substr($abbr, 0, 6);
    my $dtag = $size_class . $alphabet_tag . '-' . $abbr;
    my $results_dir = "$all_results_dir/$size_class$alphabet_tag $name";
    my $aligned = ($name =~ /(\d+way|align)/) ? 1 : 0;

    my $full_source_path = "$test_data_source_dir/$source_path";
    if (!-e $full_source_path) { die "Can't find dataset \"$name\" ($full_source_path)\n"; }

    my $comp_dir = "$all_compressed_dir/$dtag";
    if (!-e $comp_dir) { make_path($comp_dir); }
    if (!-e $comp_dir or !-d $comp_dir) { die "Can't create directory \"$comp_dir\"\n"; }
    if (!-e $results_dir) { make_path($results_dir); }
    if (!-e $results_dir or !-d $results_dir) { die "Can't create directory \"$results_dir\"\n"; }

    my $uncompressed_ext = $alphabet_tag_to_extension{$alphabet_tag};
    if (!defined $uncompressed_ext) { die "Unknown extension for alphabet tag \"$alphabet_tag\"\n"; }

    my $uncompressed_path = "$comp_dir/$abbr.$uncompressed_ext";
    my $uncompress_cmd = $decompressors{$source_ext};
    $uncompress_cmd =~ s/\{IN\}/$full_source_path/g;
    $uncompress_cmd =~ s/\{NAME\}/$dtag/g;
    $uncompress_cmd =~ s/\{TEMP_DIR\}/$temp_dir/g;
    $uncompress_cmd .= " >'$uncompressed_path.temp'";

    my $uncompressed_size;
    if (-e $results_dir and -e "$results_dir/size")
    {
        my $size_file = "$results_dir/size";
        chomp($uncompressed_size = `head -n 1 '$size_file'`);
        if ($uncompressed_size !~ /^\d+$/) { die "Can't read uncompressed size from \"$size_file\"\n"; }
    }
    else
    {
        decompress($name, $uncompressed_ext, $uncompressed_path, $uncompress_cmd);
        $uncompressed_size = -s $uncompressed_path;
        my $size_file = "$results_dir/size";
        open(my $S, '>', $size_file) or die "Can't create \"$size_file\"\n";
        binmode $S;
        print $S "$uncompressed_size\n";
        close $S;
    }

    my $dataset_min_c_time_tries = 1;
    my $dataset_min_d_time_tries = 1;
    my $dataset_min_c_mem_tries  = 1;
    my $dataset_min_d_mem_tries  = 1;
    my $uncompressed_md5;

    for (my $ci = 0; $ci < scalar(@compressors); $ci++)
    {
        if (!-e $all_compressed_dir) { last; }

        my ($comp_category, $threads, $cname, $ext, $parallel, $opt_id, $uncompressed_size_limit, $comp_cmd) = @{$compressors[$ci]};

        my $compatible = ( ( $comp_category eq 'general' ) or
                           ( $comp_category eq ($alphabet_tag_to_comp_category{$alphabet_tag} . ($aligned ? '-aligned' : '')) ) or
                           ( ($alphabet_tag eq 'a') and ($comp_category eq 'fasta-dna') ) or
                           ( ($alphabet_tag eq 'a') and ($comp_category eq 'fasta-protein') and ($cname =~ /^(acfa|acfa0|acseq|acseq0)$/) )
                         ) ? 1 : 0;
        if (!$compatible) { next; }

        #if ( ($alphabet_tag eq 'a') and ($name =~ /^polyA-/) and ($cname =~ /^(dnax|dnax0)$/) { next; }

        if ($uncompressed_size_limit ne '-' and $uncompressed_size > $uncompressed_size_limit) { next; }

        if (!exists $decompressors{$ext}) { die "Unknown decompressor for extension \"$ext\"\n"; }
        my $ctag = $cname . (($opt_id eq '-') ? '' : "-$opt_id");

        my $min_c_time_tries = $dataset_min_c_time_tries;
        my $min_d_time_tries = $dataset_min_d_time_tries;
        my $min_c_mem_tries = $dataset_min_c_mem_tries;
        my $min_d_mem_tries = $dataset_min_d_mem_tries;

        my ($csize, @ctimes, @dtimes, @cmems, @dmems);

        my $res_file = "$results_dir/$ctag";
        if (-e $res_file and -s $res_file == 0) { next; }
        if (-e $res_file and -s $res_file > 0)
        {
            load_stats($res_file, \$csize, \@ctimes, \@dtimes, \@cmems, \@dmems);
            for (@ctimes) { if ($_ <= $short_time_threshold) { $min_c_time_tries = 10; $min_c_mem_tries = 10; } }
            for (@dtimes) { if ($_ <= $short_time_threshold) { $min_d_time_tries = 10; $min_d_mem_tries = 10; } }
            if ( defined($csize) and
                 scalar(@ctimes) >= $min_c_time_tries and scalar(@cmems) >= $min_c_mem_tries and
                 scalar(@dtimes) >= $min_d_time_tries and scalar(@dmems) >= $min_d_mem_tries) { next; }
        }

        print "\n===== $dtag - $ctag =====\n";

        if (!-e $uncompressed_path)
        {
            decompress($name, $uncompressed_ext, $uncompressed_path, $uncompress_cmd);
            my $s1 = -s $uncompressed_path;
            if ($s1 != $uncompressed_size) { die "Mismatch with previously recorded uncompressed size ($s1 != $uncompressed_size)\n"; }
        }

        if (!defined $uncompressed_md5)
        {
            $uncompressed_md5 = `md5sum -b $uncompressed_path`;
            $uncompressed_md5 =~ s/\s.*$//;
        }

        my $compressed_name = "$abbr-$ext" . (($opt_id eq '-') ? '' : "-$opt_id");
        my $compressed_path = "$comp_dir/$compressed_name.$ext";

        my $ok = 1;
        my $n_c_time_tries = $min_c_time_tries - scalar(@ctimes);
        my $n_d_time_tries = $min_d_time_tries - scalar(@dtimes);
        my $n_c_mem_tries = $min_c_mem_tries - scalar(@cmems);
        my $n_d_mem_tries = $min_d_mem_tries - scalar(@dmems);
        if ($n_c_time_tries < 0) { $n_c_time_tries = 0; }
        if ($n_d_time_tries < 0) { $n_d_time_tries = 0; }
        if ($n_c_mem_tries < 0) { $n_c_mem_tries = 0; }
        if ($n_d_mem_tries < 0) { $n_d_mem_tries = 0; }

        # Compression tests
        if ( $ok and ( $n_c_time_tries > 0 or $n_c_mem_tries > 0 or $n_d_time_tries > 0 or $n_d_mem_tries > 0 ) )
        {
            $comp_cmd =~ s/\{OUT\}/$compressed_path/g;
            $comp_cmd =~ s/\{NAME\}/$compressed_name/g;
            $comp_cmd =~ s/\{TEMP_DIR\}/$temp_dir/g;
            $comp_cmd .= " <$uncompressed_path";

            print $comp_cmd, ' ';

            if ($ok and $n_c_time_tries > 0) { print 'T'; }
            for (my $try = 0; $ok and $try < $n_c_time_tries; $try++)
            {
                foreach my $file (bsd_glob("$compressed_path*")) { unlink $file; }
                print ".";
                my $t0 = [gettimeofday];
                my $error = system($comp_cmd);
                my $ctime = tv_interval($t0);
                if ($error != 0) { print "Compression failed:\n\"$comp_cmd\"\n"; $ok = 0; last; }
                if (!defined $csize) { $csize = 0; foreach my $file (bsd_glob("$compressed_path*")) { $csize += -s $file; } }
                if ($csize == 0) { print "Compressed size is 0:\n\"$comp_cmd\"\n"; $ok = 0; last; }
                push @ctimes, $ctime;
                if ($ctime <= $short_time_threshold)
                {
                    if ($min_c_time_tries < 10) { my $add = 10 - $min_c_time_tries; $min_c_time_tries += $add; $n_c_time_tries += $add; }
                    if ($min_c_mem_tries  < 10) { my $add = 10 - $min_c_mem_tries;  $min_c_mem_tries += $add;  $n_c_mem_tries  += $add; }
                }
            }

            if ($ok and $n_c_mem_tries > 0)
            {
                my $cscript_file = "$comp_dir/$compressed_name.cscript.sh";
                my $cmem_temp_file = "$comp_dir/$compressed_name.cmem-temp";

                open(my $CS, '>', $cscript_file) or die "Can't create file \"$cscript_file\"\n";
                binmode $CS;
                print $CS $comp_cmd, "\n";
                close $CS;
                system("chmod 755 $cscript_file");

                print 'M';
                for (my $try = 0; $ok and $try < $n_c_mem_tries; $try++)
                {
                    unlink $cmem_temp_file;
                    foreach my $file (bsd_glob("$compressed_path*")) { unlink $file; }
                    print ".";
                    my $error = system("/usr/bin/time -v $cscript_file 2>$cmem_temp_file");
                    if ($error != 0) { print "Compression failed: \"$comp_cmd\"\n"; $ok = 0; last; }
                    my $cmem = get_time_from_file($cmem_temp_file);
                    if ($cmem < 0) { print "Can't measure memory usage of command: \"$comp_cmd\"\n"; $ok = 0; last; }
                    if (!defined $csize) { $csize = 0; foreach my $file (bsd_glob("$compressed_path*")) { $csize += -s $file; } }
                    push @cmems, $cmem;
                }

                if (-e $cscript_file) { unlink $cscript_file; }
                if (-e $cmem_temp_file) { unlink $cmem_temp_file; }
            }

            if ($ok and $n_c_time_tries == 0 and $n_c_mem_tries == 0)
            {
                print 'C.';
                foreach my $file (bsd_glob("$compressed_path*")) { unlink $file; }
                my $error = system($comp_cmd);
                if ($error != 0) { print "Compression failed: \"$comp_cmd\"\n"; $ok = 0; }
            }

            print "\n";
        }

        # Decompression tests
        if ( $ok and ( $n_d_time_tries > 0 or $n_d_mem_tries > 0 ) )
        {
            my $dec_cmd = $decompressors{$ext};
            $dec_cmd =~ s/\{IN\}/$compressed_path/g;
            $dec_cmd =~ s/\{NAME\}/$compressed_name/g;
            $dec_cmd =~ s/\{TEMP_DIR\}/$temp_dir/g;

            print "$dec_cmd ";
            if ($ok and scalar(@dtimes) == 0 and scalar(@dmems) == 0)
            {
                print 'D.';
                my $dec_md5 = `$dec_cmd | md5sum -b -`;
                $dec_md5 =~ s/\s.*$//;
                if ($dec_md5 ne $uncompressed_md5) { print "$name - $ctag: Decompressed md5 does not match original md5:\n$dec_cmd\n"; $ok = 0; }
            }

            $dec_cmd .= ' >/dev/null';

            if ($ok and $n_d_time_tries > 0)
            {
                print 'T';
                for (my $try = 0; $try < $n_d_time_tries; $try++)
                {
                    print '.';
                    my $t0 = [gettimeofday];
                    my $error = system($dec_cmd);
                    my $dtime = tv_interval($t0);
                    if ($error != 0) { print "    Decompression command failed: $dec_cmd\n"; $ok = 0; last; }
                    push @dtimes, $dtime;
                    if ($dtime <= $short_time_threshold)
                    {
                        if ($min_d_time_tries < 10) { my $add = 10 - $min_d_time_tries; $min_d_time_tries += $add; $n_d_time_tries += $add; }
                        if ($min_d_mem_tries  < 10) { my $add = 10 - $min_d_mem_tries;  $min_d_mem_tries += $add;  $n_d_mem_tries  += $add; }
                    }
                }
            }

            if ($ok and $n_d_mem_tries > 0)
            {
                my $dscript_file = "$comp_dir/$compressed_name.dscript.sh";
                my $dmem_temp_file = "$comp_dir/$compressed_name.dmem-temp";

                open(my $DS, '>', $dscript_file) or die "Can't create file \"$dscript_file\"\n";
                binmode $DS;
                print $DS $dec_cmd, "\n";
                close $DS;
                system("chmod 755 $dscript_file");

                print 'M';
                for (my $try = 0; $try < $n_d_mem_tries; $try++)
                {
                    print '.';
                    my $error = system("/usr/bin/time -v $dscript_file 2>$dmem_temp_file");
                    if ($error != 0) { print "    Decompression command failed: $dec_cmd\n"; $ok = 0; last; }
                    my $dmem = get_time_from_file($dmem_temp_file);
                    if ($dmem < 0) { print "Can't measure memory usage of command: \"$dec_cmd\"\n"; $ok = 0; last; }
                    push @dmems, $dmem;
                }

                if (-e $dscript_file) { unlink $dscript_file; }
                if (-e $dmem_temp_file) { unlink $dmem_temp_file; }
            }

            print "\n";
        }

        if (-e $all_compressed_dir)
        {
            open(my $R, '>', $res_file) or die "Can't create \"$res_file\"\n";
            binmode $R;

            if ($ok)
            {
                my $size_perc = sprintf('%.2f', $csize / $uncompressed_size * 100);

                my $sum_cmem  = 0; for (my $i = 0; $i < scalar(@cmems);  $i++) { $sum_cmem  += $cmems[$i];  }
                my $sum_dmem  = 0; for (my $i = 0; $i < scalar(@dmems);  $i++) { $sum_dmem  += $dmems[$i];  }
                my $sum_ctime = 0; for (my $i = 0; $i < scalar(@ctimes); $i++) { $sum_ctime += $ctimes[$i]; }
                my $sum_dtime = 0; for (my $i = 0; $i < scalar(@dtimes); $i++) { $sum_dtime += $dtimes[$i]; }
                my $avg_cmem  = $sum_cmem  / scalar(@cmems);
                my $avg_dmem  = $sum_dmem  / scalar(@dmems);
                my $avg_ctime = $sum_ctime / scalar(@ctimes);
                my $avg_dtime = $sum_dtime / scalar(@dtimes);

                print "     Size: $size_perc %",
                      '     Comp: ', commify(sprintf('%.3f', $avg_ctime)), ' s, ', commify($avg_cmem), ' kB',
                      '     Dec: ',  commify(sprintf('%.3f', $avg_dtime)), ' s, ', commify($avg_dmem), " kB\n";

                print $R "$csize\n";
                print $R join(' ', map { sprintf('%.3f', $_) } @ctimes), "\n";
                print $R join(' ', map { sprintf('%.3f', $_) } @dtimes), "\n";
                print $R join(' ', @cmems), "\n";
                print $R join(' ', @dmems), "\n";
            }

            close $R;

            foreach my $file (bsd_glob("$compressed_path*")) { unlink $file; }
        }
    }

    if (-e $uncompressed_path) { unlink $uncompressed_path; }
    if (-e $comp_dir) { rmdir $comp_dir; }
}


sub load_configuration
{
    open (my $D, '<', $decompressors_file) or die "Can't open \"$decompressors_file\"\n";
    binmode $D;
    while (<$D>)
    {
        if (substr($_, 0, 1) eq '#') { next; }
        s/[\x0D\x0A]+$//;
        if ($_ =~ /^\s*$/) { next; }
        my @fields = split(/\t|\s{2,}/, $_);
        if (scalar(@fields) != 2) { die "Can't parse decompressor line: \"$_\"\n"; }
        $decompressors{$fields[0]} = $fields[1];
    }
    close $D;

    foreach my $file (bsd_glob($compressor_file_pattern))
    {
        my $base = basename($file);
        if ($base !~ /^compressors-(\S+?)\.txt$/) { die "Can't parse compressor list file name \"$base\"\n"; }
        my $comp_category = $1;

        my ($name, $ext, $parallel) = ('', '', 0);
        open (my $C, '<', $file) or die "Can't open \"$file\"\n";
        binmode $C;
        while (<$C>)
        {
            if (substr($_, 0, 1) eq '#') { next; }
            s/[\x0D\x0A]+$//;
            if ($_ =~ /^\s*$/) { next; }

            if (/^\s*\[(.+)\]\s*$/)
            {
                my $section = $1;
                if ($section !~ /^(\S+),\s*(\S+),\s*(\S+)$/) { die "Can't parse compressor section name \"$_\"\n"; }
                ($name, $ext, $parallel) = ($1, $2, $3);
                if (!exists $decompressors{$ext}) { die "Unknown decompressor for extension \"$ext\"\n"; }
                next;
            }

            my @fields = split(/\t|\s{2,}/, $_);
            if (scalar(@fields) != 3) { die "Can't parse compressor line: \"$_\"\n"; }
            my ($optname, $max_input_size, $command) = @fields;
            my $threads = ($optname =~ /-(\d+)t$/) ? $1 : 1;
            my $ctag = $name . (($optname eq '-') ? '' : "-$optname");

            @{$compressors[scalar(@compressors)]} = ($comp_category, $threads, $name, $ext, $parallel, $optname, $max_input_size, $command);
        }
        close $C;
    }

    foreach my $dir (bsd_glob("$test_data_source_dir/*"))
    {
        if (!-d $dir) { next; }
        my $dirbase = basename($dir);
        foreach my $file (bsd_glob("$dir/*"))
        {
            my $base = basename($file);
            if ($base !~ /^(\d{2})([drpa])\s(.+?)\.([^\.]+)?$/) { die "Can't parse test data file name \"$base\"\n"; }
            my ($size_class, $alphabet_tag, $name, $source_ext) = ($1, $2, $3, $4);
            if (!exists $decompressors{$source_ext}) { die "File with unknown extension \"$source_ext\": \"$file\"\n"; }

            if ($size_class > 10) { next; }

            #if ($size_class > 24) { next; }
            #if ($size_class > 29) { next; }
            #if ($size_class > 31) { next; }
            #if ($size_class > 34) { next; }
            #if ($size_class > 35) { next; }

            #if ($size_class > 39) { next; }
            #if ($size_class > 40) { next; }
            #if ($size_class > 42) { next; }
            #if ($size_class > 44) { next; }
            #if ($size_class > 45) { next; }
            #if ($size_class != 47) { next; }
            #if ($size_class > 48) { next; }

            #if ($size_class > 51) { next; }
            #if ($alphabet_tag ne 'r') { next; }
            #if ($base !~ /^44r/) { next; }

            @{$datasets[scalar(@datasets)]} = ($size_class, $alphabet_tag, $name, $source_ext, "$dirbase/$base");
        }
    }
}


sub decompress
{
    my ($name, $dest_ext, $dest_path, $cmd) = @_;
    print "\"$name\": Decompressing into " . uc($dest_ext) . " format\n";
    print "$cmd\n";
    my $error = system($cmd);
    if ($error != 0) { die "Can't decompress \"$name\" - decompression command failed:\n$cmd\n"; }
    if (!-e "$dest_path.temp") { die "Decompression failed: Can't find \"$dest_path.temp\"\n"; }
    if (-s "$dest_path.temp" == 0) { die "Decompression produced empty file \"$dest_path.temp\"\n"; }
    rename "$dest_path.temp", $dest_path;
}


sub get_time_from_file
{
    my ($file) = @_;
    open(my $M, '<', $file) or return -1;
    binmode $M;
    my $m = -1;
    while (<$M>)
    {
        if (/Maximum resident set size \(kbytes\): (\d+)/) { $m = $1; last; }
    }
    close $M;
    return $m;
}


sub load_stats
{
    my ($file, $csize_ref, $ctimes_ref, $dtimes_ref, $cmems_ref, $dmems_ref) = @_;
    if (!-e $file) { return; }

    open(my $R, '<', $file) or die "Can't open \"$file\"\n";
    binmode $R;
    my $csize_str = <$R>;
    my $ctime_str = <$R>;
    my $dtime_str = <$R>;
    my $cmem_str = <$R>;
    my $dmem_str = <$R>;
    close $R;

    my @ctimes = split(' ', $ctime_str);
    my @dtimes = split(' ', $dtime_str);
    my @cmems = split(' ', $cmem_str);
    my @dmems = split(' ', $dmem_str);

    if (defined($csize_ref) and $csize_str =~ /^\d+$/) { $$csize_ref = int($csize_str); }
    if (defined($ctimes_ref)) { push @{$ctimes_ref}, @ctimes; } 
    if (defined($dtimes_ref)) { push @{$dtimes_ref}, @dtimes; } 
    if (defined($cmems_ref)) { push @{$cmems_ref}, @cmems; } 
    if (defined($dmems_ref)) { push @{$dmems_ref}, @dmems; } 
}


sub commify
{
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}


sub create_empty_file
{
    my ($file) = @_;
    open(my $F, '>', $file) or die "Can't create file \"$file\"\n";
    close $F;
}
