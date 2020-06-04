#!/usr/bin/env perl

use strict;
use CGI qw/:standard/;
use File::Slurp;
use Sort::Versions;
use Storable qw(retrieve);

binmode STDOUT;

my $benchmark_path = '/sequence-compression-benchmark/';

my @default_table_columns = (1, 2, 4, 5, 7, 9, 13, 0);
my $max_table_columns = scalar(@default_table_columns);

my %alphabet_tag_to_name = ('d' => 'dna', 'r' => 'rna', 'p' => 'protein');

my @measure_tags = ('empty', 'name', 'size', 'psize', 'ratio',
                    'ctime', 'cspeed', 'dtime', 'dspeed', 'cdtime',
                    'cdspeed', 'ttime', 'tspeed', 'tdtime', 'tdspeed',
                    'ctdtime', 'ctdspeed', 'cmem', 'dmem', 'datasize',
                    'dataname');

my $n_measures = scalar(@measure_tags) - 2;

my @measure_names = ('', 'Name', 'Compressed size', 'Compressed size relative to original', 'Compression ratio',
                     'Compression time', 'Compression speed', 'Decompression time', 'Decompression speed', 'Compression + decompression time',
                     'Compression + decompression speed', 'Transfer time', 'Transfer speed', 'Transfer + decompression time', 'Transfer + decompression speed',
                     'Compression + transfer + decompression time', 'Compression + transfer + decompression speed', 'Compression memory', 'Decompression memory', 'Test data size',
                     'Test dataset name');

my @measure_titles = ('', 'Compressor', 'Size', 'SizePerc', 'Ratio',
                      'C-Time', 'C-Speed', 'D-Time', 'D-Speed', 'CD-Time',
                      'CD-Speed', 'T-Time', 'T-Speed', 'TD-Time', 'TD-Speed',
                      'CTD-Time', 'CTD-Speed', 'C-Mem', 'D-Mem', 'DataSize',
                      'DatasetName');

my @measure_units = ('', '', 'B', '%', 'times',
                     's', 'MB/s', 's', 'MB/s', 's',
                     'MB/s', 's', 'MB/s', 's', 'MB/s',
                     's', 'MB/s', 'MB', 'MB', 'MB',
                     '');

my @measure_data_indexes          = ( 0,  0,  0,  5,  6,  1, 11,  2, 12,  7, 13,  8, 14,  9, 15, 10, 16,  3,  4, 17,  0);
my @measure_large_is_good         = ( 0,  0,  0,  0,  1,  0,  1,  0,  1,  0,  1,  0,  1,  0,  1,  0,  1,  0,  0,  0,  0);
my @use_measure_for_choosing_best = ( 0,  0,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  0,  0);
my @use_measure_for_sorting       = ( 0,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  0,  0);
my @show_measure_in_column_chart  = ( 0,  0,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  0,  0);
my @compound_measure              = ( 0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  1,  0,  1,  0,  0,  0,  0,  0);

my @sub_measures                  = ( [0], [1], [2], [3], [4],
                                      [5], [6], [7], [8], [5,7],
                                      [10], [11], [12], [11,7], [14],
                                      [5,11,7], [16], [17], [18], [19], [20] );

my @measure_colors = ('#707070', '#707070', '#E5CC99', '#E5CC99', '#E5CC99',
                      '#DC3912', '#DC3912', '#FF9900', '#FF9900', '#7799DD',
                      '#7799DD', '#3366CC', '#3366CC', '#3366CC', '#3366CC',
                      '#3366CC', '#3366CC', '#33BACC', '#33BACC' );

my %measure_tag_to_index;
for (my $i = 0; $i <= $n_measures + 1; $i++) { $measure_tag_to_index{$measure_tags[$i]} = $i; }

my %compressor_line_width = (
    #'2bit' => 0, 'blast' => 0
);
my %default_shape_sizes = ('circle' => 7, 'polygon' => 9, 'square' => 10, 'diamond' => 10, 'triangle' => 11, 'star' => 15);

my %compressor_point_shape = (
    '2bit' => 'star',
    'ac' => 'triangle',
    'alapy' => 'triangle',
    'bcm' => 'polygon',
    'beetl' => 'diamond',
    'blast' => 'star',
    'brieflz' => 'star',
    'brotli' => 'polygon',
    'bsc' => 'polygon',
    'bzip2' => 'square',
    'cmix' => 'star',
    'copy' => 'diamond',
    'dcom' => 'square',
    'dlim' => 'diamond',
    'dnax' => 'star',
    'dsrc' => 'square',
    'fastqz' => 'star',
    'fqs' => 'star',
    'fqzcomp' => 'star',
    'geco' => 'triangle',
    'gtz' => 'star',
    'gzip' => 'square',
    'harc' => 'square',
    'jarvis' => 'star',
    'kic' => 'triangle',
    'leon' => 'triangle',
    'lfastqc' => 'star',
    'lfqc' => 'triangle',
    'lizard' => 'star',
    'lz4' => 'circle',
    'lzop' => 'star',
    'lzturbo' => 'circle',
    'mfc' => 'diamond',
    'minicom' => 'triangle',
    'naf' => 'circle',
    'nakamichi' => 'diamond',
    'nuht' => 'star',
    'pbzip2' => 'star',
    'pfish' => 'diamond',
    'pigz' => 'circle',
    'quip' => 'star',
    'snzip' => 'star',
    'spring' => 'star',
    'uht' => 'star',
    'wrap' => 'star',
    'xm' => 'diamond',
    'xz' => 'diamond',
    'zpaq' => 'star',
    'zpipe' => 'star',
    'zstd' => 'diamond',
);
my %compressor_point_sides = (
    'brieflz' => 4,
    'cmix' => 4,
    'dnax' => 4,
    'fastqz' => 4,
    'fqs' => 4,
    'fqzcomp' => 4,
    'gtz' => 4,
    'jarvis' => 4,
    'lizard' => 4,
    'lzop' => 4,
    'pbzip2' => 4,
    'spring' => 8,
    'wrap' => 4,
    'zpaq' => 4,
    'zpipe' => 4,
);
my %compressor_point_dent = (
    'brieflz' => 0.3,
    'dnax' => 0.3,
    'lizard' => 0.3,
    'pbzip2' => 0.2,
    'spring' => 0.35,
    'wrap' => 0.3,
);
my %compressor_point_rotation = (
    'ac' => 180,
    'cmix' => 45,
    'fastqz' => 45,
    'gtz' => 45,
    'jarvis' => 45,
    'lfqc' => 180,
    'minicom' => 180,
    'zpaq' => 45,
    'zpipe' => 45,
);
my %compressor_point_color = (
    'ac' => '#53AECF',
    '2bit' => '#C55A11',
    'alapy' => '#D60A00',
    'bcm' => '#B3E5E4',
    'beetl' => '#BB8835',
    'blast' => '#5B9BD5',
    'brieflz' => '#FFC700',
    'brotli' => '#92D050',
    'bsc' => '#F3A286',
    'bzip2' => '#70AD47',
    'cmix' => '#4C86EA',
    'copy' => '#727272',
    'dcom' => '#990099',
    'dlim' => '#4472C4',
    'dnax' => '#69B2F7',
    'dsrc' => '#B3E5B4',
    'fastqz' => '#0BCB1E',
    'fqs' => '#E74646',
    'fqzcomp' => '#B87DE0',
    'geco' => '#8FDEE5',
    'gtz' => '#AA98E2',
    'gzip' => '#A6A6A6',
    'harc' => '#D70000',
    'jarvis' => '#FF5B00',
    'kic' => '#506FCE',
    'leon' => '#AAAA11',
    'lfastqc' => '#BE9855',
    'lfqc' => '#CC342D',
    'lizard' => '#98BE0E',
    'lz4' => '#ED7D31',
    'lzop' => '#51EFF5',
    'lzturbo' => '#7084D1',
    'mfc' => '#FF0000',
    'minicom' => '#81D984',
    'naf' => '#FFC000',
    'nakamichi' => '#F06601',
    'nuht' => '#F4A8E0',
    'pbzip2' => '#E46B62',
    'pfish' => '#6B8F7E',
    'pigz' => '#F4A8E0',
    'quip' => '#10751C',
    'snzip' => '#6DC586',
    'spring' => '#B12C12',
    'uht' => '#FF5555',
    'wrap' => '#A2AA98',
    'xm' => '#00B050',
    'xz' => '#D15BC3',
    'zpaq' => '#997300',
    'zpipe' => '#C90B1E',
    'zstd' => '#00B0F0',
);

my %compressor_is_free = (
    '2bit' => 0,
    'ac' => 1,
    'alapy' => 0,
    'bcm' => 1,
    'beetl' => 1,
    'blast' => 1,
    'brieflz' => 1,
    'brotli' => 1,
    'bsc' => 1,
    'bzip2' => 1,
    'cmix' => 1,
    'copy' => 1,
    'dcom' => 1,
    'dlim' => 0,
    'dnax' => 1,
    'dsrc' => 1,
    'fastqz' => 1,
    'fqs' => 1,
    'fqzcomp' => 1,
    'geco' => 1,
    'gtz' => 0,
    'gzip' => 1,
    'harc' => 1,
    'jarvis' => 1,
    'kic' => 1,
    'leon' => 1,
    'lfastqc' => 0,
    'lfqc' => 1,
    'lizard' => 1,
    'lz4' => 1,
    'lzop' => 1,
    'lzturbo' => 1,
    'mfc' => 0,
    'naf' => 1,
    'nuht' => 1,
    'pbzip2' => 1,
    'pfish' => 1,
    'pigz' => 1,
    'quip' => 1,
    'snzip' => 1,
    'spring' => 1,
    'uht' => 1,
    'wrap' => 1,
    'xm' => 1,
    'xz' => 1,
    'zpaq' => 1,
    'zpipe' => 1,
    'zstd' => 1,
);

my %compressor_is_open_source = (
    '2bit' => 1,
    'ac' => 1,
    'alapy' => 0,
    'bcm' => 1,
    'beetl' => 1,
    'blast' => 1,
    'brieflz' => 1,
    'brotli' => 1,
    'bsc' => 1,
    'bzip2' => 1,
    'cmix' => 1,
    'copy' => 1,
    'dcom' => 1,
    'dlim' => 0,
    'dnax' => 1,
    'dsrc' => 1,
    'fastqz' => 1,
    'fqs' => 1,
    'fqzcomp' => 1,
    'geco' => 1,
    'gtz' => 0,
    'gzip' => 1,
    'harc' => 1,
    'jarvis' => 1,
    'kic' => 0,
    'leon' => 1,
    'lfastqc' => 1,
    'lfqc' => 1,
    'lizard' => 1,
    'lz4' => 1,
    'lzop' => 1,
    'lzturbo' => 0,
    'mfc' => 1,
    'naf' => 1,
    'nuht' => 0,
    'pbzip2' => 1,
    'pfish' => 1,
    'pigz' => 1,
    'quip' => 1,
    'snzip' => 1,
    'spring' => 1,
    'uht' => 0,
    'wrap' => 1,
    'xm' => 1,
    'xz' => 1,
    'zpaq' => 1,
    'zpipe' => 1,
    'zstd' => 1,
);

my %size_word_to_min_size = ('tiny' =>        0, 'small' =>  10000000, 'medium' =>  100000000, 'large' =>   1000000000);
my %size_word_to_max_size = ('tiny' => 10000000, 'small' => 100000000, 'medium' => 1000000000, 'large' => 100000000000);



my $header_printed = 0;



#
# Reading data
#
my %dataset_tag_to_index     = %{retrieve('data/dataset-tag-to-index.hash')};
my %dataset_name_to_index    = %{retrieve('data/dataset-name-to-index.hash')};
my @dataset_tags             = @{retrieve('data/dataset-tags.array')};
my @dataset_names            = @{retrieve('data/dataset-names.array')};
my @dataset_dates            = @{retrieve('data/dataset-dates.array')};
my @dataset_sizes            = @{retrieve('data/dataset-sizes.array')};
my %compressor_name_to_index = %{retrieve('data/compressor-name-to-index.hash')};
my @compressor_names         = @{retrieve('data/compressor-names.array')};
my @compressor_is_special    = @{retrieve('data/compressor-is-special.array')};
my %setting_name_to_index    = %{retrieve('data/setting-name-to-index.hash')};
my @setting_names            = @{retrieve('data/setting-names.array')};
my @setting_cis              = @{retrieve('data/setting-cis.array')};
my @data_by_dataset          = @{retrieve('data/data-by-dataset.array')};

my $n_datasets = scalar(@dataset_names);
my $n_compressors = scalar(@compressor_names);
my $n_settings = scalar(@setting_names);

my @dataset_is_alignment = (0) x $n_datasets;
for (my $i = 0; $i < $n_datasets; $i++)
{
    if ($dataset_names[$i] =~ /(\d+way|align)/) { $dataset_is_alignment[$i] = 1; }
}

my @compressor_is_copy = (0) x $n_compressors;
for (my $i = 0; $i < $n_compressors; $i++)
{
    if ($compressor_names[$i] =~ /^copy/) { $compressor_is_copy[$i] = 1; }
}

my @compressor_is_wrapper = (0) x $n_compressors;
for (my $i = 0; $i < $n_compressors; $i++)
{
    if ($compressor_names[$i] =~ /^wrap/) { $compressor_is_wrapper[$i] = 1; }
}



#
# Parsing parameters
#

my $page_name = 'index';
my $button_pressed = 0;
my (%dataset_is_selected, %compressor_is_selected, %setting_is_selected, %use_compressor, %use_setting);
my ($only_best_settings, $n_best_settings, $best_measure, $best_link_speed_mbit_s, $best_link_speed_bytes_s) = (0, 1, 14, 100, 12500000);
my $max_n_threads = 4;
my $include_closed_source_compressors = 0;
my $include_non_free_compressors = 0;
my ($include_special, $include_general, $include_copy, $include_wrappers) = (0, 0, 0, 0);
my ($do_aggregate, $aggregate_method) = (0, 'average');
my ($selected_sort_measure, $sort_measure, $reverse_sort_order) = (0, $best_measure, 0);
my @table_column_measures = (0) x $max_table_columns;
my ($selected_column_chart_measure, $column_chart_measure) = (0, $best_measure);
my ($show_only_top, $show_top_n) = (0, 0);
my ($relative_to_reference, $reference_setting_name, $reference_setting_index) = (0, '', -1);
my $column_chart_y_log_scale = 0;
my $column_chart_color_by_compressor_specialization = 0;
my ($column_chart_width, $column_chart_height) = (1500, 500);
my %selected_scatterplot_measure = ( 'x' => 14, 'y' => 16);
my %scatterplot_measure = ( 'x' => 14, 'y' => 16);
my %scatterplot_log_scale = ( 'x' => 0, 'y' => 0 );
my %scatterplot_fixed_range = ( 'x' => 0, 'y' => 0 );
my %scatterplot_range_min = ( 'x' => 0, 'y' => 0 );
my %scatterplot_range_max = ( 'x' => 0, 'y' => 0 );
my $scatterplot_use_lines = 0;
my ($show_table, $save_csv, $show_bar_graph, $show_column_chart, $show_scatterplot) = (0, 0, 0, 0, 0);

if (param('page'))
{
    my $p = param('page');
    if ($p !~ /^[a-zA-Z\-]+$/) { error("Invalid page requested"); }
    my $path = "pages/$p.html";
    if (!-e $path) { error("Unknown page requested"); }
    $page_name = $p;
    print_header();
    print read_file($path);
    print_footer();
    exit;
}

if (param('quick-column-chart') or param('quick-scatterplot'))
{
    $button_pressed = 1;
    $include_closed_source_compressors = 1;
    $include_non_free_compressors = 1;
    $show_top_n = 10;
    $reference_setting_name = 'gzip-9';
    $max_n_threads = 4;
    $include_special = 1;
    $include_general = 1;
    $include_copy = 1;
    $do_aggregate = 1;
    $aggregate_method = 'average';
    @table_column_measures = @default_table_columns;

    foreach my $size_word (keys %size_word_to_min_size)
    {
        if (param("$size_word genomes"))
        {
            my $min_size = $size_word_to_min_size{$size_word};
            my $max_size = $size_word_to_max_size{$size_word};
            for (my $di = 0; $di < $n_datasets; $di++)
            {
                my $name = $dataset_names[$di];
                my $size = $dataset_sizes[$di];
                if ($size >= $min_size and $size < $max_size and $name =~ /GC(A|F)_/) { $dataset_is_selected{$di} = 1; }
            }
        }
    }

    if (param('dna'))
    {
        for (my $di = 0; $di < $n_datasets; $di++)
        {
            my $tag = $dataset_tags[$di];
            if (substr($tag, 2, 1) eq 'd' and !$dataset_is_alignment[$di] and $tag !~ /GC(A|F)_/) { $dataset_is_selected{$di} = 1; }
        }
    }

    if (param('aligned dna'))
    {
        for (my $di = 0; $di < $n_datasets; $di++)
        {
            my $tag = $dataset_tags[$di];
            if (substr($tag, 2, 1) eq 'd' and $dataset_is_alignment[$di] and $tag !~ /GC(A|F)_/) { $dataset_is_selected{$di} = 1; }
        }
    }

    if (param('rna'))
    {
        for (my $di = 0; $di < $n_datasets; $di++)
        {
            my $tag = $dataset_tags[$di];
            if (substr($tag, 2, 1) eq 'r' and !$dataset_is_alignment[$di]) { $dataset_is_selected{$di} = 1; }
        }
    }

    if (param('protein'))
    {
        for (my $di = 0; $di < $n_datasets; $di++)
        {
            my $tag = $dataset_tags[$di];
            if (substr($tag, 2, 1) eq 'p' and !$dataset_is_alignment[$di]) { $dataset_is_selected{$di} = 1; }
        }
    }


    if (param('quick-column-chart'))
    {
        $show_column_chart = 1;
        $only_best_settings = 1;
        my $button_label = param('quick-column-chart');
        if ($button_label eq 'Compression Ratio') { $best_measure = $measure_tag_to_index{'ratio'}; $include_copy = 0; }
        elsif ($button_label eq 'Decompression Speed') { $best_measure = $measure_tag_to_index{'dspeed'}; $include_copy = 0; }
        elsif ($button_label eq 'Compression / Decompression Speed') { $best_measure = $measure_tag_to_index{'cdspeed'}; $include_copy = 0; }
        elsif ($button_label eq 'Transfer / Decompression Speed') { $best_measure = $measure_tag_to_index{'tdspeed'}; $include_copy = 1; }
        elsif ($button_label eq 'Compression / Transfer / Decompression Speed') { $best_measure = $measure_tag_to_index{'ctdspeed'}; $include_copy = 1; }
        else { error('Unknown comparison requested'); }
        $selected_sort_measure = 0;
        $sort_measure = $best_measure;
        $selected_column_chart_measure = 0;
        $column_chart_measure = $best_measure;
    }
    elsif (param('quick-scatterplot'))
    {
        $show_scatterplot = 1;
        $only_best_settings = 0;
        my $button_label = param('quick-scatterplot');
        if ($button_label eq 'Compression Ratio -vs- Decompression Speed')
        {
            $selected_scatterplot_measure{'x'} = $measure_tag_to_index{'ratio'};
            $selected_scatterplot_measure{'y'} = $measure_tag_to_index{'dspeed'};
            $include_copy = 0;
            $include_wrappers = 0;
        }
        elsif ($button_label eq 'Compression Ratio -vs- Compression / Decompression Speed')
        {
            $selected_scatterplot_measure{'x'} = $measure_tag_to_index{'ratio'};
            $selected_scatterplot_measure{'y'} = $measure_tag_to_index{'cdspeed'};
            $include_copy = 0;
            $include_wrappers = 0;
        }
        elsif ($button_label eq 'Transfer / Decompression Speed -vs- Compression / Transfer / Decompression Speed')
        {
            $selected_scatterplot_measure{'x'} = $measure_tag_to_index{'tdspeed'};
            $selected_scatterplot_measure{'y'} = $measure_tag_to_index{'ctdspeed'};
            $include_copy = 1;
            $include_wrappers = 0;
        }
        else { error('Unknown comparison requested'); }
        $scatterplot_measure{'x'} = $selected_scatterplot_measure{'x'};
        $scatterplot_measure{'y'} = $selected_scatterplot_measure{'y'};
    }
}

if (param('button'))
{
    $button_pressed = 1;
    my $button_label = param('button');
    if ($button_label eq 'Show table') { $show_table = 1; }
    elsif ($button_label eq 'Save CSV') { $save_csv = 1; }
    elsif ($button_label eq 'Show bar graph') { $show_bar_graph = 1; }
    elsif ($button_label eq 'Show column chart') { $show_column_chart = 1; }
    elsif ($button_label eq 'Show scatterplot') { $show_scatterplot = 1; }
    else { error('Unknown output requested'); }
}

if (!$button_pressed)
{
    $include_special = 1;
    $include_general = 1;
    $include_copy = 1;
    $include_closed_source_compressors = 1;
    $include_non_free_compressors = 1;
    $only_best_settings = 1;
    $show_top_n = 10;
    @table_column_measures = @default_table_columns;
    $reference_setting_name = 'gzip-9';
    $do_aggregate = 1;
}

if (param('cs')) { $include_special = 1; }
if (param('cg')) { $include_general = 1; }
if (param('cc')) { $include_copy = 1; }
if (param('cw')) { $include_wrappers = 1; }

if (param('com'))
{
    my $com = param('com');
    if ($com eq 'no') { $include_non_free_compressors = 0; }
    elsif ($com eq 'yes') { $include_non_free_compressors = 1; }
    else { error('Unknown value of "com" parameter'); }
}

if (param('src'))
{
    my $src = param('src');
    if ($src eq 'open') { $include_closed_source_compressors = 0; }
    elsif ($src eq 'all') { $include_closed_source_compressors = 1; }
    else { error('Unknown value of "src" parameter'); }
}

if (param('nt'))
{
    my $nt = param('nt');
    if ($nt eq '1' or $nt eq '4') { $max_n_threads = $nt; }
    else { error('Unknown number of threads requested'); }
}

if (param('only-best')) { $only_best_settings = 1; }
if (param('bn'))
{
    $n_best_settings = int(param('bn')); 
    if ($n_best_settings ne param('bn') or $n_best_settings < 1 or $n_best_settings > 99) { error('Invalid number of best settings'); }
}
if (param('bm'))
{
    my $mtag = param('bm');
    if ( !exists $measure_tag_to_index{$mtag} or
         $measure_tag_to_index{$mtag} < 2 or
         $measure_tag_to_index{$mtag} > 18 ) { error('Unknown criterion for ranking compresors'); }
    $best_measure = $measure_tag_to_index{$mtag};
}
if (param('bs'))
{
    my $bs = int(param('bs'));
    if ($bs ne param('bs') or $bs < 1 or $bs > 100000) { error('Invalid link speed'); }
    $best_link_speed_mbit_s = $bs;
    $best_link_speed_bytes_s = $best_link_speed_mbit_s * 1000000 / 8;
}


if (param('d'))
{
    foreach my $d (multi_param('d'))
    {
        $d =~ s/\s+\([^\(\)]+?\)$//;
        if (exists $dataset_name_to_index{$d}) { $dataset_is_selected{$dataset_name_to_index{$d}} = 1; }
        elsif ($d eq 'genomes')
        {
            for (my $di = 0; $di < $n_datasets; $di++)
            {
                if ($dataset_names[$di] =~ /GC(A|F)_/) { $dataset_is_selected{$di} = 1; }
            }
        }
        elsif ($d eq 'non-genomes')
        {
            for (my $di = 0; $di < $n_datasets; $di++)
            {
                if ($dataset_names[$di] !~ /GC(A|F)_/) { $dataset_is_selected{$di} = 1; }
            }
        }
        elsif ($d eq 'all')
        {
            for (my $di = 0; $di < $n_datasets; $di++) { $dataset_is_selected{$di} = 1; }
        }

        elsif ($d =~ /^(tiny|small|medium|large) genomes$/)
        {
            my $size_word = $1;
            my $min_size = $size_word_to_min_size{$size_word};
            my $max_size = $size_word_to_max_size{$size_word};
            for (my $di = 0; $di < $n_datasets; $di++)
            {
                my $name = $dataset_names[$di];
                my $size = $dataset_sizes[$di];
                if ($size >= $min_size and $size < $max_size and $name =~ /GC(A|F)_/) { $dataset_is_selected{$di} = 1; }
            }
        }
        elsif ($d eq 'dna')
        {
            for (my $di = 0; $di < $n_datasets; $di++)
            {
                my $tag = $dataset_tags[$di];
                if (substr($tag, 2, 1) eq 'd' and !$dataset_is_alignment[$di] and $tag !~ /GC(A|F)_/) { $dataset_is_selected{$di} = 1; }
            }
        }
        elsif ($d eq 'aligned dna')
        {
            for (my $di = 0; $di < $n_datasets; $di++)
            {
                my $tag = $dataset_tags[$di];
                if (substr($tag, 2, 1) eq 'd' and $dataset_is_alignment[$di] and $tag !~ /GC(A|F)_/) { $dataset_is_selected{$di} = 1; }
            }
        }
        elsif ($d eq 'rna')
        {
            for (my $di = 0; $di < $n_datasets; $di++)
            {
                my $tag = $dataset_tags[$di];
                if (substr($tag, 2, 1) eq 'r') { $dataset_is_selected{$di} = 1; }
            }
        }
        elsif ($d eq 'protein')
        {
            for (my $di = 0; $di < $n_datasets; $di++)
            {
                my $tag = $dataset_tags[$di];
                if (substr($tag, 2, 1) eq 'p') { $dataset_is_selected{$di} = 1; }
            }
        }
        else { error('Unknown dataset: "'. html_escape($d) . '"'); }
    }
}
my $n_datasets_selected = scalar(keys %dataset_is_selected);

if (param('c'))
{
    foreach my $c (multi_param('c'))
    {
        if (!exists $compressor_name_to_index{$c}) { error('Unknown compressor: "' . html_escape($c) . '"'); }
        my $ci = $compressor_name_to_index{$c};
        $compressor_is_selected{$ci} = 1;
        $use_compressor{$ci} = 1;
    }
}

#my $setting_input_log = '';
if (param('s'))
{
    foreach my $s (multi_param('s'))
    {
        #$setting_input_log .= "Requested setting \"$s\"<br />\n";
        if (!exists $setting_name_to_index{$s}) { error('Unknown setting: "' . html_escape($s) . '"'); }
        my $si = $setting_name_to_index{$s};
        #$setting_input_log .= "&emsp;-&emsp;index = $si<br />\n";
        $setting_is_selected{$si} = 1;
        #$setting_input_log .= "&emsp;-&emsp;now " . scalar(keys %setting_is_selected) . " settings in %setting_is_selected<br />\n";
        $use_setting{$si} = 1;
        #$setting_input_log .= "&emsp;-&emsp;now " . scalar(keys %use_setting) . " settings in %use_setting<br />\n";
    }
}

if ($button_pressed)
{
    if ($include_special)
    {
        for (my $i = 0; $i < $n_compressors; $i++)
        {
            if ($compressor_is_special[$i] == 2 and !$compressor_is_copy[$i] and !$compressor_is_wrapper[$i]) { $use_compressor{$i} = 1; }
        }
    }
    if ($include_general)
    {
        for (my $i = 0; $i < $n_compressors; $i++)
        {
            if ($compressor_is_special[$i] == 1 and !$compressor_is_copy[$i] and !$compressor_is_wrapper[$i]) { $use_compressor{$i} = 1; }
        }
    }
    if ($include_copy)
    {
        for (my $i = 0; $i < $n_compressors; $i++)
        {
            if ($compressor_is_copy[$i]) { $use_compressor{$i} = 1; }
        }
    }
    if ($include_wrappers)
    {
        for (my $i = 0; $i < $n_compressors; $i++)
        {
            if ($compressor_is_wrapper[$i]) { $use_compressor{$i} = 1; }
        }
    }

    for (my $si = 0; $si < $n_settings; $si++)
    {
        if (!$use_compressor{$setting_cis[$si]}) { next; }
        my $sname = $setting_names[$si];
        my $n_threads = 1;
        if ($sname =~ /-(\d+)t$/) { $n_threads = $1; }
        if ($n_threads > $max_n_threads) { next; }
        $use_setting{$si} = 1;
    }
}

if (param('doagg'))
{
    my $doagg_str = param('doagg');
    if ($doagg_str ne '0' and $doagg_str ne '1') { error("Unknown aggregation specified\n"); }
    $do_aggregate = int($doagg_str);
}

if (param('agg'))
{
    my $agg = param('agg');
    if ($agg eq 'sum' or $agg eq 'average') { $aggregate_method = $agg; }
    else { error("Unknown aggregation method specified\n"); }
}

if (!$do_aggregate and !$show_scatterplot and !$show_table and !$save_csv)
{
    error("Currently non-aggregated data is only supported with scatterplot and table outputs.");
}

if (param('sm'))
{
    my $mtag = param('sm');
    if ($mtag eq 'same') { $selected_sort_measure = 0; }
    else
    {
        if ( !exists $measure_tag_to_index{$mtag} or
             $measure_tag_to_index{$mtag} < 1 or
             $measure_tag_to_index{$mtag} > 18 ) { error('Unknown criterion for sorting compresors (' . html_escape($mtag) . ')'); }
        $selected_sort_measure = $measure_tag_to_index{$mtag};
    }
    $sort_measure = ($selected_sort_measure == 0) ? $best_measure : $selected_sort_measure;
}

if (param('rs')) { $reverse_sort_order = 1; }

if (param('to')) { $show_only_top = 1; }
if (param('tn'))
{ 
    my $n0 = param('tn');
    my $n = int($n0);
    if ($n eq $n0 and $n >= 1 and $n <= 999) { $show_top_n = $n; }
    else { error("Unknown number of top compressors specified\n"); }
}

if (param('rr'))
{
    $reference_setting_name = param('rr');
    if ($reference_setting_name ne '' and !exists $setting_name_to_index{$reference_setting_name}) { error('Unknown reference compressor specified'); }
}

if ($reference_setting_name ne '')
{
    $reference_setting_index = $setting_name_to_index{$reference_setting_name};
}

if (param('rl'))
{
    $relative_to_reference = 1;
    if ($reference_setting_name eq '' or $reference_setting_index < 0) { error('Reference compressor not specified'); }
}

for (my $i = 0; $i < $max_table_columns; $i++)
{
    if (param("tm$i"))
    {
        my $mtag = param("tm$i");
        if (!exists $measure_tag_to_index{$mtag}) { error('Unknown table column "' . html_escape($mtag) . '"'); }
        $table_column_measures[$i] = $measure_tag_to_index{$mtag};
        if ($do_aggregate and ($show_table or $save_csv) and $table_column_measures[$i] == 20) { error('Dataset name is only supported in tables with non-aggregated data'); }
    }
}

if (param('gm'))
{
    my $mtag = param("gm");
    if ($mtag eq 'same') { $selected_column_chart_measure = 0; }
    else
    {
        if (!exists $measure_tag_to_index{$mtag}) { error('Unknown column chart measure "' . html_escape($mtag) . '"'); }
        $selected_column_chart_measure = $measure_tag_to_index{$mtag};
        if ($selected_column_chart_measure < 2 or $selected_column_chart_measure > 19) { error('Unknown column chart measure "' . html_escape($mtag) . '"'); }
    }

    if ($selected_column_chart_measure == 0)
    {
        #if ($sort_measure < 2) { error("Unsupported column chart measure"); }
        #$column_chart_measure = $sort_measure;
        $column_chart_measure = ($sort_measure >= 2) ? $sort_measure : $best_measure;
    }
    else { $column_chart_measure = $selected_column_chart_measure; }
}

if (param('cyl'))
{
    my $scale = param('cyl');
    if ($scale ne 'lin' and $scale ne 'log') { error('Unknown scale specified'); }
    $column_chart_y_log_scale = ($scale eq 'log') ? 1 : 0;
}

if (param('ccw'))
{
    my $s = param('ccw');
    if ($s !~ /^\d{1,5}$/) { error('Unknown column chart width specified'); }
    $column_chart_width = int($s);
    if ($column_chart_width < 100) { $column_chart_width = 100; }
    if ($column_chart_width > 10000) { $column_chart_width = 10000; }
}

if (param('cch'))
{
    my $s = param('cch');
    if ($s !~ /^\d{1,5}$/) { error('Unknown column chart height specified'); }
    $column_chart_height = int($s);
    if ($column_chart_height < 100) { $column_chart_height = 100; }
    if ($column_chart_height > 10000) { $column_chart_height = 10000; }
}

if (param('cc3c'))
{
    my $s = param('cc3c');
    $column_chart_color_by_compressor_specialization = ($s eq '1') ? 1 : 0;
}

foreach my $axis_name ('x', 'y')
{
    if (param("s${axis_name}m"))
    {
        my $mtag = param("s${axis_name}m");
        if ($mtag eq 'same') { $selected_scatterplot_measure{$axis_name} = 0; }
        else
        {
            if ( !exists $measure_tag_to_index{$mtag} or
                 $measure_tag_to_index{$mtag} < 2 or
                 $measure_tag_to_index{$mtag} >19 ) { error('Unknown column chart measure "' . html_escape($mtag) . '"'); }
            $selected_scatterplot_measure{$axis_name} = $measure_tag_to_index{$mtag};
        }
        $scatterplot_measure{$axis_name} = ($selected_scatterplot_measure{$axis_name} == 0) ? $sort_measure : $selected_scatterplot_measure{$axis_name};
    }

    if (param("s${axis_name}l"))
    {
        my $scale = param("s${axis_name}l");
        if ($scale ne 'lin' and $scale ne 'log') { error('Unknown scatterplot scale specified'); }
        $scatterplot_log_scale{$axis_name} = ($scale eq 'log') ? 1 : 0;
    }

    if (param("s${axis_name}min"))
    {
        my $n = param("s${axis_name}min");
        if (length($n) > 12 or $n !~ /^(\d+|\d+\.\d+)$/) { error('Invalid scatterplot range specified'); }
        $scatterplot_range_min{$axis_name} = $n;
    }

    if (param("s${axis_name}max"))
    {
        my $n = param("s${axis_name}max");
        if (length($n) > 12 or $n !~ /^(\d+|\d+\.\d+)$/) { error('Invalid scatterplot range specified'); }
        if ($n <= $scatterplot_range_min{$axis_name}) { error('Invalid scatterplot range specified'); }
        $scatterplot_range_max{$axis_name} = $n;
    }
}

if (param('sl')) { $scatterplot_use_lines = 1; }
if (param('sxfr')) { $scatterplot_fixed_range{'x'} = 1; }
if (param('syfr')) { $scatterplot_fixed_range{'y'} = 1; }


#
# Checking if "Highlight specialized vs general-purpose compressors" option was selected,
# And at the same time if a stacked multi-parameter column chart is requested (e.g. transfer + decompression time).
# In such case show error message that this combination is not supported.
#
if ( $show_column_chart and
     $column_chart_color_by_compressor_specialization and
     $compound_measure[$column_chart_measure] and
     !$relative_to_reference )
{
    error_with_options("\"Highlight specialized vs general-purpose compressors\" option" .
        " is not supported with a stacked multiple-measure column chart\n");
}


#
# Checking if data was selected.
# Also checking if reference compressor has data for selected datasets.
#
my %dataset_is_unselected;
if ($button_pressed)
{
    # Unselecting datasets that don't have data for reference compressor.
    if ($relative_to_reference)
    {
        my $n_unselected = 0;
        foreach my $di (keys %dataset_is_selected)
        {
            if ( !defined $data_by_dataset[$di]->[$reference_setting_index] or
                 $data_by_dataset[$di]->[$reference_setting_index]->[0] == 0 )
            {
                delete $dataset_is_selected{$di};
                $dataset_is_unselected{$di} = 1;
                $n_unselected++;
            }
        }
        if (scalar(keys %dataset_is_selected) == 0) { error_with_options("Reference compressor doesn't have data for any of the selected datasets"); }
    }

    if (!$n_datasets_selected) { error_with_options('No test dataset selected'); }

    if (scalar(keys %use_setting) == 0) { error_with_options('No compressors selected'); }
}


#$setting_input_log .= "Parsed input<br />\n";
#$setting_input_log .= "&emsp;-&emsp;now " . scalar(keys %setting_is_selected) . " settings in %setting_is_selected<br />\n";
#$setting_input_log .= "&emsp;-&emsp;now " . scalar(keys %use_setting) . " settings in %use_setting<br />\n";



#
# Computing data
#
my %setting_has_not_enough_data;
my @combined_data;
my @sorted_settings;
my %compressor_has_settings_that_are_used;

if ($button_pressed)
{
    my %setting_n_successful_datasets;
    foreach my $di (keys %dataset_is_selected)
    {
        foreach my $si (keys %use_setting)
        {
            if (!defined $data_by_dataset[$di]->[$si]) { next; }
            if ($data_by_dataset[$di]->[$si]->[0] == 0) { next; }
            $setting_n_successful_datasets{$si}++;
        }
    }

    if (!$include_non_free_compressors)
    {
        foreach my $si (keys %use_setting)
        {
            my $ci = $setting_cis[$si];
            my $cn = $compressor_names[$ci];
            if (!$compressor_is_free{$cn})
            {
                delete $use_setting{$si};
            }
        }
    }

    if (!$include_closed_source_compressors)
    {
        foreach my $si (keys %use_setting)
        {
            my $ci = $setting_cis[$si];
            my $cn = $compressor_names[$ci];
            if (!$compressor_is_open_source{$cn})
            {
                delete $use_setting{$si};
            }
        }
    }

    if ($do_aggregate)
    {
        foreach my $si (keys %use_setting)
        {
            if (!exists $setting_n_successful_datasets{$si} or $setting_n_successful_datasets{$si} < $n_datasets_selected)
            {
                $setting_has_not_enough_data{$si} = 1;
                delete $use_setting{$si};
            }
        }
    }

    if ($n_datasets_selected > 0 and scalar(keys %use_setting) > 0)
    {
        my %calc_setting = map { ($_ => 1) } keys %use_setting;
        if ($relative_to_reference) { $calc_setting{$reference_setting_index} = 1; }

        if ($do_aggregate)
        {
            if ($aggregate_method eq 'average')
            {
                foreach my $si (keys %calc_setting)
                {
                    foreach my $di (keys %dataset_is_selected)
                    {
                        my $usize_b = $dataset_sizes[$di];
                        my $usize_mb = $usize_b / 1000000;
                        my $size  = $data_by_dataset[$di]->[$si]->[0];
                        my $ctime = $data_by_dataset[$di]->[$si]->[1];
                        my $dtime = $data_by_dataset[$di]->[$si]->[2];
                        my $cmem  = $data_by_dataset[$di]->[$si]->[3];
                        my $dmem  = $data_by_dataset[$di]->[$si]->[4];

                        my $psize = $size / $usize_b * 100;
                        my $ratio = $usize_b / $size;
                        my $cdtime = $ctime + $dtime;
                        my $ttime = $size / $best_link_speed_bytes_s;
                        my $tdtime = $ttime + $dtime;
                        my $ctdtime = $ctime + $ttime + $dtime;
                        my $cspeed = $usize_mb / $ctime;
                        my $dspeed = $usize_mb / $dtime;
                        my $cdspeed = $usize_mb / $cdtime;
                        my $tspeed = $usize_mb / $ttime;
                        my $tdspeed = $usize_mb / $tdtime;
                        my $ctdspeed = $usize_mb / $ctdtime;

                        $data_by_dataset[$di]->[$si]->[5] = $psize;
                        $data_by_dataset[$di]->[$si]->[6] = $ratio;
                        $data_by_dataset[$di]->[$si]->[7] = $cdtime;
                        $data_by_dataset[$di]->[$si]->[8] = $ttime;
                        $data_by_dataset[$di]->[$si]->[9] = $tdtime;
                        $data_by_dataset[$di]->[$si]->[10] = $ctdtime;
                        $data_by_dataset[$di]->[$si]->[11] = $cspeed;
                        $data_by_dataset[$di]->[$si]->[12] = $dspeed;
                        $data_by_dataset[$di]->[$si]->[13] = $cdspeed;
                        $data_by_dataset[$di]->[$si]->[14] = $tspeed;
                        $data_by_dataset[$di]->[$si]->[15] = $tdspeed;
                        $data_by_dataset[$di]->[$si]->[16] = $ctdspeed;
                        $data_by_dataset[$di]->[$si]->[17] = $usize_mb;

                        for (my $i = 0; $i <= 17; $i++)
                        {
                            $combined_data[$si]->[$i] += $data_by_dataset[$di]->[$si]->[$i];
                        }
                    }

                    for (my $i = 0; $i <= 17; $i++)
                    {
                        $combined_data[$si]->[$i] /= $n_datasets_selected;
                    }
                }
            }
            else   # sum
            {
                my ($usize_b, $usize_mb) = (0, 0);
                foreach my $di (keys %dataset_is_selected) { $usize_b += $dataset_sizes[$di]; }
                $usize_mb = $usize_b / 1000000;

                foreach my $si (keys %calc_setting)
                {
                    foreach my $di (keys %dataset_is_selected)
                    {
                        $combined_data[$si]->[0] += $data_by_dataset[$di]->[$si]->[0];
                        $combined_data[$si]->[1] += $data_by_dataset[$di]->[$si]->[1];
                        $combined_data[$si]->[2] += $data_by_dataset[$di]->[$si]->[2];
                        $combined_data[$si]->[3] += $data_by_dataset[$di]->[$si]->[3];
                        $combined_data[$si]->[4] += $data_by_dataset[$di]->[$si]->[4];
                    }

                    my $size = $combined_data[$si]->[0];
                    my $ctime = $combined_data[$si]->[1];
                    my $dtime = $combined_data[$si]->[2];
                    my $cmem  = $combined_data[$si]->[3];
                    my $dmem  = $combined_data[$si]->[4];

                    my $psize = $size / $usize_b * 100;
                    my $ratio = $usize_b / $size;
                    my $cdtime = $ctime + $dtime;
                    my $ttime = $size / $best_link_speed_bytes_s;
                    my $tdtime = $ttime + $dtime;
                    my $ctdtime = $ctime + $ttime + $dtime;
                    my $cspeed = $usize_mb / $ctime;
                    my $dspeed = $usize_mb / $dtime;
                    my $cdspeed = $usize_mb / $cdtime;
                    my $tspeed = $usize_mb / $ttime;
                    my $tdspeed = $usize_mb / $tdtime;
                    my $ctdspeed = $usize_mb / $ctdtime;

                    $combined_data[$si]->[5] = $psize;
                    $combined_data[$si]->[6] = $ratio;
                    $combined_data[$si]->[7] = $cdtime;
                    $combined_data[$si]->[8] = $ttime;
                    $combined_data[$si]->[9] = $tdtime;
                    $combined_data[$si]->[10] = $ctdtime;
                    $combined_data[$si]->[11] = $cspeed;
                    $combined_data[$si]->[12] = $dspeed;
                    $combined_data[$si]->[13] = $cdspeed;
                    $combined_data[$si]->[14] = $tspeed;
                    $combined_data[$si]->[15] = $tdspeed;
                    $combined_data[$si]->[16] = $ctdspeed;
                    $combined_data[$si]->[17] = $usize_mb;
                }
            }
        }
        else  # No aggregation
        {
            foreach my $si (keys %calc_setting)
            {
                foreach my $di (keys %dataset_is_selected)
                {
                    if (!defined $data_by_dataset[$di]->[$si]) { next; }
                    if ($data_by_dataset[$di]->[$si]->[0] == 0) { next; }

                    my $usize_b = $dataset_sizes[$di];
                    my $usize_mb = $usize_b / 1000000;
                    my $size  = $data_by_dataset[$di]->[$si]->[0];
                    my $ctime = $data_by_dataset[$di]->[$si]->[1];
                    my $dtime = $data_by_dataset[$di]->[$si]->[2];
                    my $cmem  = $data_by_dataset[$di]->[$si]->[3];
                    my $dmem  = $data_by_dataset[$di]->[$si]->[4];

                    my $psize = $size / $usize_b * 100;
                    my $ratio = $usize_b / $size;
                    my $cdtime = $ctime + $dtime;
                    my $ttime = $size / $best_link_speed_bytes_s;
                    my $tdtime = $ttime + $dtime;
                    my $ctdtime = $ctime + $ttime + $dtime;
                    my $cspeed = $usize_mb / $ctime;
                    my $dspeed = $usize_mb / $dtime;
                    my $cdspeed = $usize_mb / $cdtime;
                    my $tspeed = $usize_mb / $ttime;
                    my $tdspeed = $usize_mb / $tdtime;
                    my $ctdspeed = $usize_mb / $ctdtime;

                    $data_by_dataset[$di]->[$si]->[5] = $psize;
                    $data_by_dataset[$di]->[$si]->[6] = $ratio;
                    $data_by_dataset[$di]->[$si]->[7] = $cdtime;
                    $data_by_dataset[$di]->[$si]->[8] = $ttime;
                    $data_by_dataset[$di]->[$si]->[9] = $tdtime;
                    $data_by_dataset[$di]->[$si]->[10] = $ctdtime;
                    $data_by_dataset[$di]->[$si]->[11] = $cspeed;
                    $data_by_dataset[$di]->[$si]->[12] = $dspeed;
                    $data_by_dataset[$di]->[$si]->[13] = $cdspeed;
                    $data_by_dataset[$di]->[$si]->[14] = $tspeed;
                    $data_by_dataset[$di]->[$si]->[15] = $tdspeed;
                    $data_by_dataset[$di]->[$si]->[16] = $ctdspeed;
                    $data_by_dataset[$di]->[$si]->[17] = $usize_mb;

                    for (my $i = 0; $i <= 17; $i++)
                    {
                        $combined_data[$si]->[$i] += $data_by_dataset[$di]->[$si]->[$i];
                    }
                }

                for (my $i = 0; $i <= 17; $i++)
                {
                    $combined_data[$si]->[$i] /= $n_datasets_selected;
                }
            }
        }
    }

    if ($relative_to_reference)
    {
        my @adjust_settings;
        foreach my $si (keys %use_setting) { if ($si != $reference_setting_index) { push @adjust_settings, $si; } }
        if ($use_setting{$reference_setting_index}) { push @adjust_settings, $reference_setting_index; }

        foreach my $si (@adjust_settings)
        {
            for (my $ni = 1; $ni < 17; $ni++)
            {
                if ($do_aggregate)
                {
                    $combined_data[$si]->[$ni] /= $combined_data[$reference_setting_index]->[$ni];
                }
                else
                {
                    foreach my $di (keys %dataset_is_selected)
                    {
                        $data_by_dataset[$di]->[$si]->[$ni] /= $data_by_dataset[$di]->[$reference_setting_index]->[$ni];
                    }
                }
            }
        }
    }

    if ($only_best_settings)
    {
        my $di = $measure_data_indexes[$best_measure];
        my @best_order = sort { $combined_data[$a]->[$di] <=> $combined_data[$b]->[$di] || versioncmp($setting_names[$a], $setting_names[$b]) } keys %use_setting;
        if ($measure_large_is_good[$best_measure]) { @best_order = reverse @best_order; }

        my %best_by_compressor;
        for (my $i = 0; $i < scalar(@best_order); $i++)
        {
            push @{$best_by_compressor{$setting_cis[$best_order[$i]]}}, $best_order[$i];
        }

        my %setting_is_among_best;
        foreach my $ci (keys %best_by_compressor)
        {
            my $n_to_use = scalar(@{$best_by_compressor{$ci}});
            if ($n_to_use > $n_best_settings) { $n_to_use = $n_best_settings; }
            for (my $i = 0; $i < $n_to_use; $i++)
            {
                $setting_is_among_best{$best_by_compressor{$ci}->[$i]} = 1;
            }
        }

        foreach my $si (keys %use_setting)
        {
            if (!exists $setting_is_among_best{$si}) { delete $use_setting{$si}; }
        }
    }

    if ($sort_measure == 1)
    {
        @sorted_settings = sort { versioncmp($setting_names[$a], $setting_names[$b]) } keys %use_setting;
    }
    else
    {
        my $di = $measure_data_indexes[$sort_measure];
        @sorted_settings = sort { $combined_data[$a]->[$di] <=> $combined_data[$b]->[$di] || versioncmp($setting_names[$a], $setting_names[$b]) } keys %use_setting;
        if ($measure_large_is_good[$sort_measure] xor $reverse_sort_order) { @sorted_settings = reverse @sorted_settings; }
    }

    if ($show_only_top)
    {
        my $n = scalar(@sorted_settings);
        if ($n > $show_top_n) { $n = $show_top_n; }
        @sorted_settings = @sorted_settings[0 .. $n-1];
        my %is_top = map { ($_ => 1) } @sorted_settings;
        foreach my $si (keys %use_setting) { if (!exists $is_top{$si}) { delete $use_setting{$si}; } }
    }

    foreach my $si (keys %use_setting)
    {
        $compressor_has_settings_that_are_used{$setting_cis[$si]} = 1;
    }
}



#$setting_input_log .= "Computed data<br />\n";
#$setting_input_log .= "&emsp;-&emsp;now " . scalar(keys %setting_is_selected) . " settings in %setting_is_selected<br />\n";
#$setting_input_log .= "&emsp;-&emsp;now " . scalar(keys %use_setting) . " settings in %use_setting<br />\n";


#
# Producing csv output
#
if ($save_csv)
{
    print "Content-Type:application/x-download\n";
    print "Content-Disposition:attachment;filename=sequence-compresison-benchmark.csv\n\n";
    my $one_printed = 0;
    for (my $i = 0; $i < $max_table_columns; $i++)
    {
        if ($table_column_measures[$i] < 1) { next; }
        if ($one_printed) { print ','; }
        my $m = $table_column_measures[$i];
        if ($m == 1) { print 'Compressor'; }
        else
        {
            print $measure_titles[$m];
            if (!$relative_to_reference and $measure_units[$m] ne '') { print ' (', $measure_units[$m], ')'; }
        }
        $one_printed = 1;
    }
    print "\n";
    foreach my $si (@sorted_settings)
    {
        if ($do_aggregate)
        {
            $one_printed = 0;
            for (my $i = 0; $i < $max_table_columns; $i++)
            {
                if ($table_column_measures[$i] < 1) { next; }
                if ($one_printed) { print ','; }
                my $m = $table_column_measures[$i];
                if ($m == 1) { print $setting_names[$si]; }
                else { print format_data_for_table($combined_data[$si]->[$measure_data_indexes[$m]], $m, 0); }
                $one_printed = 1;
            }
            print "\n";
        }
        else
        {
            foreach my $di (sort { $dataset_sizes[$a] <=> $dataset_sizes[$b] } keys %dataset_is_selected)
            {
                if (!defined $data_by_dataset[$di]->[$si]) { next; }
                if ($data_by_dataset[$di]->[$si]->[0] == 0) { next; }
                $one_printed = 0;
                for (my $i = 0; $i < $max_table_columns; $i++)
                {
                    if ($table_column_measures[$i] < 1) { next; }
                    if ($one_printed) { print ','; }
                    my $m = $table_column_measures[$i];
                    if ($m == 1) { print $setting_names[$si]; }
                    elsif ($m == 20) { print $dataset_names[$di]; }
                    #else { print format_data_for_table($combined_data[$si]->[$measure_data_indexes[$m]], $m, 0); }
                    else { print format_data_for_table($data_by_dataset[$di]->[$si]->[$measure_data_indexes[$m]], $m, 0); }
                    $one_printed = 1;
                }
                print "\n";
            }
        }
    }
    exit;
}



#
# Printing header and summary
#
print_header();
if ($button_pressed)
{
    if (scalar(keys %dataset_is_unselected) > 0)
    {
        my $n_unselected_datasets = scalar(keys %dataset_is_unselected);
        print qq(<div class="text">\n);
        print "<details><summary>$reference_setting_name has no data for $n_unselected_datasets of the selected datasets, therefore these datasets are removed from selection</summary>\n";
        print '<p>', join(',<br>', map { $dataset_names[$_] } sort { $dataset_sizes[$a] <=> $dataset_sizes[$b] } keys %dataset_is_unselected), "</p></details>\n";
        print "</div>\n";
    }

    if (scalar(keys %setting_has_not_enough_data) > 0)
    {
        my $n_skipped_settings = scalar(keys %setting_has_not_enough_data);
        print qq(<div class="text">\n);
        print "<details><summary>$n_skipped_settings compressor settings don't have data covering all selected datasets</summary>\n";
        print '<p>', join(', ', map { $setting_names[$_] } sort { versioncmp($setting_names[$a], $setting_names[$b]) } keys %setting_has_not_enough_data), "</p></details>\n";
        print "</div>\n";
    }

    if ($n_datasets_selected > 0 and scalar(keys %use_setting) > 0)
    {
        print qq(<div class="text">\n);
        print 'Comparing ', commify(scalar(keys %use_setting)), ' settings of ', commify(scalar(keys %compressor_has_settings_that_are_used)), ' compressors';
        print "</div>\n";
    }
}
else
{
    print_welcome_message();
}



#print $setting_input_log;
#print 'Selected ', scalar(keys %use_setting), " settings<br />\n";



#
# Printing table
#
if ($show_table and $n_datasets_selected > 0 and scalar(keys %use_setting) > 0)
{
    print qq(<div class="table">\n);
    #my $n_columns = 0;
    #for (my $i = 0; $i < $max_table_columns; $i++) { if ($table_column_measures[$i] >= 1) { $n_columns++; } }
    #print qq(<table style="margin-left: auto; margin-right: auto;"><tr><td>);
    #print qq(</td></tr><tr><td>\n);
    print qq(<table class="d" style="margin-left: auto; margin-right: auto;">\n);
    print qq(<thead><tr>);
    for (my $i = 0; $i < $max_table_columns; $i++)
    {
        if ($table_column_measures[$i] < 1) { next; }
        print '<td class="t">';
        my $m = $table_column_measures[$i];
        if ($m == 1) { print 'Compressor'; }
        else
        {
            print $measure_titles[$m];
            if (!$relative_to_reference and $measure_units[$m] ne '') { print '<br />(', $measure_units[$m], ')'; }
        }
        print '</td>';
    }
    print "</tr></thead><tbody>\n";
    foreach my $si (@sorted_settings)
    {
        if ($do_aggregate)
        {
            print "<tr>";
            for (my $i = 0; $i < $max_table_columns; $i++)
            {
                if ($table_column_measures[$i] < 1) { next; }
                my $m = $table_column_measures[$i];
                if ($m == 1) { print '<td class="n">', $setting_names[$si]; }
                else { print '<td class="d">', format_data_for_table($combined_data[$si]->[$measure_data_indexes[$m]], $m, 1); }
                print '</td>';
            }
            print "</tr>\n";
        }
        else
        {
            foreach my $di (sort { $dataset_sizes[$a] <=> $dataset_sizes[$b] } keys %dataset_is_selected)
            {
                if (!defined $data_by_dataset[$di]->[$si]) { next; }
                if ($data_by_dataset[$di]->[$si]->[0] == 0) { next; }
                print "<tr>";
                for (my $i = 0; $i < $max_table_columns; $i++)
                {
                    if ($table_column_measures[$i] < 1) { next; }
                    my $m = $table_column_measures[$i];
                    if ($m == 1) { print '<td class="n">', $setting_names[$si]; }
                    elsif ($m == 20) { print '<td class="n">', $dataset_names[$di]; }
                    else { print '<td class="d">', format_data_for_table($data_by_dataset[$di]->[$si]->[$measure_data_indexes[$m]], $m, 1); }
                    print '</td>';
                }
                print "</tr>\n";
            }
        }
    }
    print "</tbody></table>\n";
    #print "</td></tr></table>\n";
    print "</div>\n";
}



#
# Printing common chart code.
#
if (($show_column_chart or $show_scatterplot) and $n_datasets_selected > 0 and scalar(keys %use_setting) > 0)
{
    print qq`<script>\n`;
    print qq`function download_svg() {\n`;
    print qq`  var e = document.getElementById('chart_div');\n`;
    print qq`  var t = e.getElementsByTagName('svg')[0].outerHTML;\n`;
    print qq`  var t2 = t.replace(/<svg\\s/, '<svg xmlns="http://www.w3.org/2000/svg" ');\n`;
    print qq`  var tb = new Blob([t2], {type : 'image/svg+xml'});\n`;
    print qq`  saveAs(tb, "benchmark.svg");\n`;
    print qq`}\n`;
    print qq`</script>\n`;
}



#
# Printing column chart
#
if ($show_column_chart and $n_datasets_selected > 0 and scalar(keys %use_setting) > 0)
{
    print qq`<div style="width: 100%;"><div id="chart_div" style="width: ${column_chart_width}px; margin: 0 auto;"></div></div>\n`;
    print qq`<div style="width: 100%; text-align: center;"><button onclick="download_svg()">Download SVG file</button></div>\n`;
    print qq`<script>\n`;
    print qq`google.charts.load('current', {packages: ['corechart', 'bar']});\n`;
    #print qq`google.charts.load('current', {'packages':['bar']});\n`;
    print qq`google.charts.setOnLoadCallback(drawChart);\n`;
    print qq`function drawChart() {\n`;

    my @m_names;
    if ($compound_measure[$column_chart_measure] and !$relative_to_reference)
    {
        @m_names = map { my $a = $measure_names[$_]; $a =~ s/ time$//; $a; } @{$sub_measures[$column_chart_measure]};
    }
    else { @m_names = ( $measure_names[$column_chart_measure] ); }
    for (my $i = 0; $i < scalar(@m_names); $i++) { $m_names[$i] =~ s/ (speed|time)$//; }

    print "  var data = google.visualization.arrayToDataTable([\n",
          "    [ 'Measure'";
    foreach my $m_name (@m_names)
    {
        print qq`, '`, $m_name, qq`'`;
        print qq`, { role: 'annotation' }`;
        print qq`, { type: 'string', role: 'tooltip', 'p': { 'html': true } }`;
        if ($column_chart_color_by_compressor_specialization)
        {
            print qq`, { role: 'style' }`;
        }
    }
    print " ],\n";

    for (my $i = 0; $i < scalar(@sorted_settings); $i++)
    {
        my $si = $sorted_settings[$i];

        my $tooltip_text = qq`<span style="font-size: larger;"><b>` . $setting_names[$si] . q`</b></span>`;
        if ($compound_measure[$column_chart_measure] and !$relative_to_reference)
        {
            foreach my $mi (@{$sub_measures[$column_chart_measure]})
            {
                $tooltip_text .= '<br />' . $measure_names[$mi] . q`:&nbsp;` .
                                 format_number_for_screen($combined_data[$si]->[$measure_data_indexes[$mi]], $mi);
            }
        }
        $tooltip_text .= '<br />' . $measure_names[$column_chart_measure] . q`:&nbsp;` .
                         format_number_for_screen($combined_data[$si]->[$measure_data_indexes[$column_chart_measure]], $column_chart_measure);

        print "    [ '", $setting_names[$si], "'";
        if ($compound_measure[$column_chart_measure] and !$relative_to_reference)
        {
            foreach my $mi (@{$sub_measures[$column_chart_measure]})
            {
                print ', ', $combined_data[$si]->[$measure_data_indexes[$mi]];
                print ", ''";
                print ", '", $tooltip_text, "'";
            }
        }
        else
        {
            print ', ', $combined_data[$si]->[$measure_data_indexes[$column_chart_measure]];
            print ", ''";
            print ", '", $tooltip_text, "'";
        }

        if ($column_chart_color_by_compressor_specialization)
        {
            my $color = ($compressor_is_special[$setting_cis[$si]] == 2) ? '#F49806' :
                        ($compressor_is_special[$setting_cis[$si]] == 1) ? '#3366CC' : '#F9150B';
            print qq`, '$color'`, 
        }

        print " ]";

        if ($i < scalar(@sorted_settings) - 1) { print ','; }
        print "\n";
    }

    print "  ]);\n";

    print "  var options = {
    title: '$measure_names[$column_chart_measure]',
    width: $column_chart_width,
    height: $column_chart_height,
    isStacked: true,\n";

    print "    colors: [", join(', ', map { "'" . $measure_colors[$_] . "'" } @{$sub_measures[$column_chart_measure]}), "],\n";

    print "    tooltip: { isHtml: true },\n";

    if ($compound_measure[$column_chart_measure] and !$relative_to_reference) { print "    legend: { position: 'top' },\n"; }
    else { print "    legend: { position: 'none' },\n"; }

    print "    hAxis: {
      title: 'Compressor',
    },
    vAxis: {
      textPosition: 'out',
";
    if ($column_chart_y_log_scale) { print "      logScale: true,\n"; }
    print "      title: '";

    #if ($compound_measure[$column_chart_measure])
    #{
    #    if ($measure_units[$column_chart_measure] eq 's') { print "Time"; }
    #    elsif ($measure_units[$column_chart_measure] eq 'MB/s') { print "Speed"; }
    #    else { print "$measure_names[$column_chart_measure]"; }
    #}
    #else { 
    print $measure_names[$column_chart_measure];
    #}

    if ($relative_to_reference) { print ', relative to ', $reference_setting_name; }
    else { print ' (', $measure_units[$column_chart_measure], ')'; }

    #if ($measure_units[$column_chart_measure] eq 's') { print "Time (seconds)"; }
    #elsif ($measure_units[$column_chart_measure] eq 'MB/s') { print "Speed (MB/s)"; }
    #else { print "$measure_names[$column_chart_measure] ($measure_units[$column_chart_measure])"; }

    print "'
    }
  };\n";

    print "  var chart = new google.visualization.ColumnChart(document.getElementById('chart_div'));\n";
    print "  chart.draw(data, options);\n";
    #print "  var chart = new google.charts.Bar(document.getElementById('chart_div'));\n";
    #print "  chart.draw(data, google.charts.Bar.convertOptions(options));\n";

    print "}\n";
    print "</script>\n";
}



#
# Printing scatterplot
#
if ($show_scatterplot and $n_datasets_selected > 0 and scalar(keys %use_setting) > 0)
{
    my $mx = $scatterplot_measure{'x'};
    my $my = $scatterplot_measure{'y'};
    my $dix = $measure_data_indexes[$mx];
    my $diy = $measure_data_indexes[$my];

    @sorted_settings = sort { versioncmp($setting_names[$a], $setting_names[$b]) } @sorted_settings;

    my (%compressor_is_in_scatter, %settings_in_scatter_by_compressor);
    foreach my $si (@sorted_settings)
    {
        if ($do_aggregate)
        {
            if ($scatterplot_fixed_range{'x'})
            {
                if ($combined_data[$si]->[$dix] < $scatterplot_range_min{'x'}) { next; }
                if ($combined_data[$si]->[$dix] > $scatterplot_range_max{'x'}) { next; }
            }
            if ($scatterplot_fixed_range{'y'})
            {
                if ($combined_data[$si]->[$diy] < $scatterplot_range_min{'y'}) { next; }
                if ($combined_data[$si]->[$diy] > $scatterplot_range_max{'y'}) { next; }
            }
        }
        else
        {
            my $has_points_in_range = 0;
            foreach my $di (keys %dataset_is_selected)
            {
                if (!defined $data_by_dataset[$di]->[$si]) { next; }
                if ($data_by_dataset[$di]->[$si]->[0] == 0) { next; }
                if ($scatterplot_fixed_range{'x'})
                {
                    if ($data_by_dataset[$di]->[$si]->[$dix] < $scatterplot_range_min{'x'}) { next; }
                    if ($data_by_dataset[$di]->[$si]->[$dix] > $scatterplot_range_max{'x'}) { next; }
                }
                if ($scatterplot_fixed_range{'y'})
                {
                    if ($data_by_dataset[$di]->[$si]->[$diy] < $scatterplot_range_min{'y'}) { next; }
                    if ($data_by_dataset[$di]->[$si]->[$diy] > $scatterplot_range_max{'y'}) { next; }
                }
                $has_points_in_range = 1;
                last;
            }
            if (!$has_points_in_range) { next; }
        }
        my $ci = $setting_cis[$si];
        $compressor_is_in_scatter{$ci} = 1;
        push @{$settings_in_scatter_by_compressor{$ci}}, $si;
    }

    my @compressors_in_scatter = keys %compressor_is_in_scatter;
    my @compressors_in_scatter = sort { versioncmp($compressor_names[$a], $compressor_names[$b]) } keys %compressor_is_in_scatter;
    foreach my $ci (@compressors_in_scatter)
    {
        @{$settings_in_scatter_by_compressor{$ci}} = sort { versioncmp($setting_names[$a], $setting_names[$b]) } @{$settings_in_scatter_by_compressor{$ci}};
    }

    print qq`<div style="width: 100%;"><div id="chart_div" style="width: 1000px; margin: 0 auto;"></div></div>\n`;
    print qq`<div style="width: 100%; text-align: center;"><button onclick="download_svg()">Download SVG file</button></div>\n`;
    print qq`<script>\n`;
    print qq`google.charts.load('current', {'packages':['corechart']});\n`;
    print qq`google.charts.setOnLoadCallback(drawChart);\n`;
    print qq`function drawChart() {\n`;

    print "  var data = google.visualization.arrayToDataTable([\n";
    print  "    [ '", $measure_names[$scatterplot_measure{'x'}], "', ";
          #join(', ', map { "'" . $compressor_names[$_] . "', { 'type': 'string', 'role': 'tooltip', p: { html: true } }, { 'type': 'string', 'role': 'style' }" } @compressors_in_scatter),
    print join( ', ',
                map
                {
                    "'" .
                    ( (scalar(@{$settings_in_scatter_by_compressor{$_}}) > 1) ? $compressor_names[$_] : $setting_names[$settings_in_scatter_by_compressor{$_}->[0]] )
                    . "', { 'type': 'string', 'role': 'tooltip', 'p': { html: true } }"
                }
                @compressors_in_scatter);
    print  qq` ],\n`;
    for (my $cci = 0; $cci < scalar(@compressors_in_scatter); $cci++)
    {
        my $ci = $compressors_in_scatter[$cci];
        #my $cn = $compressor_names[$ci];
        my $n_before = $cci;
        my $n_after = scalar(@compressors_in_scatter) - $cci - 1;
        #my $color = $compressor_point_color{$compressor_names[$ci]};
        #my $shape = $compressor_point_shape{$compressor_names[$ci]};
        #my $size = $default_shape_sizes{'shape'};
        #my $sides = (exists $compressor_point_sides{$cn}) ? ('sides: ' . $compressor_point_sides{$cn}) : '';
        #if (exists $compressor_point_sides{$cn}) { print qq`, pointSides: `; }
        foreach my $si (@{$settings_in_scatter_by_compressor{$ci}})
        {
            if ($do_aggregate)
            {
                print '    [ ', $combined_data[$si]->[$dix];
                #for (my $n = 0; $n < $n_before; $n++) { print q`, null, null, null`; }
                for (my $n = 0; $n < $n_before; $n++) { print q`, null, null`; }
                print q`, `, $combined_data[$si]->[$diy];
                print q`, '<span style="font-size: larger;"><b>`, $setting_names[$si], q`</b></span><br />`,
                      $measure_names[$mx], q`:&nbsp;`, format_number_for_screen($combined_data[$si]->[$dix], $mx), '<br />',
                      $measure_names[$my], q`:&nbsp;`, format_number_for_screen($combined_data[$si]->[$diy], $my), q`'`;
                #print qq`, 'point { shape-type: $shape; size: $size; stroke-width: 2; stroke-color: $color; fill-color: #FCFDFE; }' `;
                #print qq`, 'point { $sides }'`;
                #for (my $n = 0; $n < $n_after; $n++) { print q`, null, null, null`; }
                for (my $n = 0; $n < $n_after; $n++) { print q`, null, null`; }
                print " ],\n";
            }
            else
            {
                foreach my $di (keys %dataset_is_selected)
                {
                    if (!defined $data_by_dataset[$di]->[$si]) { next; }
                    if ($data_by_dataset[$di]->[$si]->[0] == 0) { next; }
                    if ($scatterplot_fixed_range{'x'})
                    {
                        if ($data_by_dataset[$di]->[$si]->[$dix] < $scatterplot_range_min{'x'}) { next; }
                        if ($data_by_dataset[$di]->[$si]->[$dix] > $scatterplot_range_max{'x'}) { next; }
                    }
                    if ($scatterplot_fixed_range{'y'})
                    {
                        if ($data_by_dataset[$di]->[$si]->[$diy] < $scatterplot_range_min{'y'}) { next; }
                        if ($data_by_dataset[$di]->[$si]->[$diy] > $scatterplot_range_max{'y'}) { next; }
                    }
                    print '    [ ', $data_by_dataset[$di]->[$si]->[$dix];
                    for (my $n = 0; $n < $n_before; $n++) { print q`, null, null`; }
                    print q`, `, $data_by_dataset[$di]->[$si]->[$diy];
                    print q`, '<span style="font-size: larger;"><b>`, $setting_names[$si], q`</b></span><br />`,
                          'Test data: ', html_escape($dataset_names[$di]), '<br />',
                          'Test data size: ', format_short_size_bold_num($data_by_dataset[$di]->[$si]->[17] * 1000000);
                    if ($mx != 19)  # Not dataset size, which is already printed.
                    {
                        print '<br />', $measure_names[$mx], q`:&nbsp;`, format_number_for_screen($data_by_dataset[$di]->[$si]->[$dix], $mx);
                    }
                    if ($my != 19)  # Not dataset size, which is already printed.
                    {
                        print '<br />', $measure_names[$my], q`:&nbsp;`, format_number_for_screen($data_by_dataset[$di]->[$si]->[$diy], $my);
                    }
                    print q`'`;
                    for (my $n = 0; $n < $n_after; $n++) { print q`, null, null`; }
                    print " ],\n";
                }
            }
        }
    }
    print "  ]);\n";

    print qq`  var options = {\n`;
    print qq`    tooltip: { isHtml: true },\n`;
    print qq`    width: 1000,\n`;
    print qq`    height: 700,\n`;
    print qq`    chartArea: { left: 200, top: 20, width: 600, height: 600 },\n`;
    print qq`    hAxis: { title: '`, $measure_names[$mx],
          ( ($relative_to_reference and $mx != 19)
               ? (', relative to ' . $reference_setting_name)
               : (qq` (` . $measure_units[$mx] . qq`)`) ),
          qq`'`;
    if ($scatterplot_log_scale{'x'}) { print ', logScale: true'; }
    if ($scatterplot_fixed_range{'x'}) { print ', viewWindow: { min: ', $scatterplot_range_min{'x'}, ', max: ', $scatterplot_range_max{'x'}, ' }'; }
    print qq` },\n`;
    print qq`    vAxis: { title: '`, $measure_names[$my],
          ( ($relative_to_reference and $my != 19)
               ? (', relative to ' . $reference_setting_name)
               : (qq` (` . $measure_units[$my] . qq`)`) ),
          qq`'`;
    if ($scatterplot_log_scale{'y'}) { print ", logScale: true"; }
    if ($scatterplot_fixed_range{'y'}) { print ', viewWindow: { min: ', $scatterplot_range_min{'y'}, ', max: ', $scatterplot_range_max{'y'}, ' }'; }
    print qq` },\n`;

    print qq`    series: {\n`;
    for (my $cci = 0; $cci < scalar(@compressors_in_scatter); $cci++)
    {
        my $ci = $compressors_in_scatter[$cci];
        my $cn = $compressor_names[$ci];
        my $ns = scalar(@{$settings_in_scatter_by_compressor{$ci}});
        my $point_shape = exists($compressor_point_shape{$cn}) ? $compressor_point_shape{$cn} : 'circle';
        my $point_size = $default_shape_sizes{$point_shape};
        my $sides = (exists $compressor_point_sides{$cn}) ? (', sides: ' . $compressor_point_sides{$cn}) : '';
        my $dent = (exists $compressor_point_dent{$cn}) ? (', dent: ' . $compressor_point_dent{$cn}) : '';
        my $rotation = (exists $compressor_point_rotation{$cn}) ? (', rotation: ' . $compressor_point_rotation{$cn}) : '';
        print qq`      $cci: { `;
        print qq` lineWidth: `, (($ns > 1) and $scatterplot_use_lines) ? (exists($compressor_line_width{$cn}) ? $compressor_line_width{$cn} : '1') : '0';
        print qq`, pointSize: '$point_size'`;
        #print qq`, pointShape: '$point_shape'`;
        print qq`, pointShape: { type: '$point_shape'$sides$dent$rotation }`;
        #print qq`, fill-color: '#FFFFFF'`;
        print qq` },\n`;
    }
    print qq`    },\n`;

    print qq`    colors: [`;
    for (my $cci = 0; $cci < scalar(@compressors_in_scatter); $cci++)
    {
        my $ci = $compressors_in_scatter[$cci];
        my $cn = $compressor_names[$ci];
        if ($cci > 0) { print ', '; }
        print exists($compressor_point_color{$cn}) ? ("'" . $compressor_point_color{$cn} . "'") : 'randomColor()';
    }
    print qq` ]\n`;

    print qq`  };\n`;

    print "  var chart = new google.visualization.ScatterChart(document.getElementById('chart_div'));\n";
    print "  chart.draw(data, options);\n";
    print "}\n";
    print qq`</script>\n`;
}



print_options();

print_footer();



sub print_options
{
    print qq`<form method="get" style="width: 71rem; margin-left: auto; margin-right: auto;">\n`;



    print qq`<h3 class="optheader">Step 1. Select test data</h3>\n`;

    print qq`<table style="width: 48rem; margin-left: auto; margin-right: auto;">\n`;

    print "<tr>";

    print qq`<td style="vertical-align: top; text-align: center;">`;
    print qq`Genomes (less repetitive)`;
    print qq`<select name="d" size="13" multiple>\n`;
    for (my $i = 0; $i < $n_datasets; $i++)
    {
        if ($dataset_names[$i] !~ /GC[AF]_/) { next; }
        my $sel = $button_pressed ? $dataset_is_selected{$i} : ($dataset_sizes[$i] <= 10000000);
        print '<option', ($sel ? ' selected' : ''), '>', $dataset_names[$i], ' (', format_short_size($dataset_sizes[$i]), ")</option>\n";
    }
    print "</select>\n";
    print "</td>";

    print qq`<td style="vertical-align: top; text-align: center;">`;
    print qq`Other datasets (more repetitive)`;
    print qq`<select name="d" size="13" multiple>\n`;
    print qq`<option disabled style="text-align: center;">DNA datasets</option>\n`;
    for (my $i = 0; $i < $n_datasets; $i++)
    {
        if (substr($dataset_tags[$i], 2, 1) ne 'd' or $dataset_names[$i] =~ /GC[AF]_/) { next; }
        if ($dataset_is_alignment[$i]) { next; }
        print '<option', ($dataset_is_selected{$i} ? ' selected' : ''), '>', $dataset_names[$i], ' (', format_short_size($dataset_sizes[$i]), ")</option>\n";
    }
    print qq`<option disabled label=" "> </option>\n`;
    print qq`<option disabled style="text-align: center;">RNA datasets</option>\n`;
    for (my $i = 0; $i < $n_datasets; $i++)
    {
        if (substr($dataset_tags[$i], 2, 1) ne 'r') { next; }
        if ($dataset_is_alignment[$i]) { next; }
        print '<option', ($dataset_is_selected{$i} ? ' selected' : ''), '>', $dataset_names[$i], ' (', format_short_size($dataset_sizes[$i]), ")</option>\n";
    }
    print qq`<option disabled label=" "> </option>\n`;
    print qq`<option disabled style="text-align: center;">Multiple DNA sequence alignments</option>\n`;
    for (my $i = 0; $i < $n_datasets; $i++)
    {
        if (substr($dataset_tags[$i], 2, 1) ne 'd') { next; }
        if (!$dataset_is_alignment[$i]) { next; }
        print '<option', ($dataset_is_selected{$i} ? ' selected' : ''), '>', $dataset_names[$i], ' (', format_short_size($dataset_sizes[$i]), ")</option>\n";
    }
    #print qq`<option disabled label=" "> </option>\n`;
    #print qq`<option disabled style="text-align: center;">RNA alignments</option>\n`;
    #for (my $i = 0; $i < $n_datasets; $i++)
    #{
    #    if (substr($dataset_tags[$i], 2, 1) ne 'r') { next; }
    #    if (!$dataset_is_alignment[$i]) { next; }
    #    print '<option', ($dataset_is_selected{$i} ? ' selected' : ''), '>', $dataset_names[$i], ' (', format_short_size($dataset_sizes[$i]), ")</option>\n";
    #}
    print qq`<option disabled label=" "> </option>\n`;
    print qq`<option disabled style="text-align: center;">Protein datasets</option>\n`;
    for (my $i = 0; $i < $n_datasets; $i++)
    {
        if (substr($dataset_tags[$i], 2, 1) ne 'p') { next; }
        if ($dataset_is_alignment[$i]) { next; }
        print '<option', ($dataset_is_selected{$i} ? ' selected' : ''), '>', $dataset_names[$i], ' (', format_short_size($dataset_sizes[$i]), ")</option>\n";
    }
    print "</select>\n";
    print "</td>";

    print "</tr>";

    print "<tr>";
    print qq`<td colspan="2" style="text-align: center;">`;
    print '<div class="optfar"><input type="checkbox" name="doagg" value="1"', ($do_aggregate ? ' checked' : ''), '>';
    print qq` Aggregate results from multiple datasets using:</div>\n`;
    print qq`<div class="optnear">\n`;
    print qq`<input type="radio" name="agg" value="sum"`, (($aggregate_method eq 'sum') ? ' checked' : ''), qq` style="margin-left: 8pt; margin-right: 5pt;">sum\n`;
    print qq`<input type="radio" name="agg" value="average"`, (($aggregate_method eq 'average') ? ' checked' : ''), qq` style="margin-left: 8pt; margin-right: 5pt;">average\n`;
    print qq`</div>\n`;
    print "</td>";
    print "</tr>";

    print "</table>\n";



    print qq`<h3 class="optheader">Step 2. Select compressors to compare</h3>`;

    print qq`<table style="width: 42rem; margin-left: auto; margin-right: auto;"><tr>\n`;

    print qq`<td style="vertical-align: top;">`;
    print qq`Compare:<br />\n`;
    print qq`<input type="checkbox" name="cs" value="1"`, ($include_special ? ' checked' : ''), "> Sequence compressors<br />\n";
    print qq`<input type="checkbox" name="cg" value="1"`, ($include_general ? ' checked' : ''), "> General-purpose compressors<br />\n";
    print qq`<input type="checkbox" name="cc" value="1"`, ($include_copy ? ' checked' : ''), "> Copy (no compression)<br />\n";
    print qq`<input type="checkbox" name="cw" value="1"`, ($include_wrappers ? ' checked' : ''), "> Wrappers<br />\n";
    print qq`<div class="optfar">Include <select name="com">`;
    print qq`<option value="no"`, (($include_non_free_compressors == 0) ? ' selected' : ''), '>only free </option>';
    print qq`<option value="yes"`, (($include_non_free_compressors == 1) ? ' selected' : ''), '>free and non-free</option>';
    print qq`</select> compressors</div>\n`;
    print qq`<div class="optnear">Include <select name="src">`;
    print qq`<option value="open"`, (($include_closed_source_compressors == 0) ? ' selected' : ''), '>only open source</option>';
    print qq`<option value="all"`, (($include_closed_source_compressors == 1) ? ' selected' : ''), '>open and closed source</option>';
    print qq`</select> compressors</div>\n`;
    print qq`<div class="optnear">Use results from <select name="nt">`;
    print qq`<option value="1"`, (($max_n_threads == 1) ? ' selected' : ''), '>only 1-thread</option>';
    print qq`<option value="4"`, (($max_n_threads == 4) ? ' selected' : ''), '>1 and 4 thread</option>';
    print qq`</select> tests</div>\n`;
    print qq`<div class="optfar"><input type="checkbox" name="only-best" value="1"`, ($only_best_settings ? ' checked' : ''),
          qq`> Only <input type="text" name="bn" size="2" maxlength="2" value="$n_best_settings" style="width: 1.4rem; text-align: center;">`,
          qq` best setting(s) in terms of</div>\n`;
    print qq`<div class="optnear"><select name="bm">\n`;
    for (my $mi = 0; $mi <= $n_measures; $mi++)
    {
        if (!$use_measure_for_choosing_best[$mi]) { next; }
        print '<option value="', $measure_tags[$mi], '"', (($mi == $best_measure) ? ' selected' : ''), '>', $measure_names[$mi], "</option>\n";
    }
    print "</select></div>\n";
    print qq`<div class="optfar">Sort by <select name="sm">\n`;
    print '<option value="same"', (($selected_sort_measure == 0) ? ' selected' : ''), ">Measure used for selecting best settings</option>\n";
    for (my $mi = 1; $mi <= $n_measures; $mi++)
    {
        if (!$use_measure_for_sorting[$mi]) { next; }
        print '<option value="', $measure_tags[$mi], '"', (($mi == $selected_sort_measure) ? ' selected' : ''), '>', $measure_names[$mi], "</option>\n";
    }
    print '</select></div>', "\n";
    print '<div class="optnear"><input type="checkbox" name="rs" value="1"', ($reverse_sort_order ? ' checked' : ''), '> Reverse sort order</div>', "\n";
    print '<div class="optnear">',
          '<input type="checkbox" name="to" value="1"', ($show_only_top ? ' checked' : ''), '>',
          ' Show only top <input type="text" name="tn" size="3" maxlength="3" value="', $show_top_n, '" style="width: 2.0rem; text-align: center;"> entries</div>', "\n";
    print '<div class="optfar">Link speed: ',
          '<input type="text" name="bs" size="5" maxlength="5" value="', $best_link_speed_mbit_s, '" style="width: 3.0rem; text-align: center;">',
          ' Mbit/s (for estimating transfer time)</div>', "\n";
    print '<div class="optfar">',
          '<input type="checkbox" name="rl" value="1"', ($relative_to_reference ? ' checked' : ''), '>',
          ' Show all values relative to ',
          '<input type="text" name="rr" size="14" maxlength="14" value="', $reference_setting_name, '" style="width: 7.0rem; text-align: center;">',
          '</div>', "\n";
    print "</td>\n";

    print qq`<td style="padding-left: 6pt; text-align: center; vertical-align: top;">`;
    print "<br />Select<br />individual<br />compressors:<br />\n";
    print qq`<select name="c" size="18" multiple style="margin-top: 5pt; padding-left: 5pt; padding-right: 5pt;">\n`;
    print qq`<option disabled style="text-align: center;">Specialized</option>\n`;
    for (my $i = 0; $i < $n_compressors; $i++)
    {
        if ($compressor_is_special[$i] != 2) { next; }
        print '<option', ($compressor_is_selected{$i} ? ' selected' : ''), ' style="text-align: center;">', $compressor_names[$i], "</option>\n";
    }
    print qq`<option disabled label=" "> </option>\n`;
    print qq`<option disabled style="text-align: center;">General-purpose</option>\n`;
    for (my $i = 0; $i < $n_compressors; $i++)
    {
        if ($compressor_is_special[$i] != 1) { next; }
        print '<option', ($compressor_is_selected{$i} ? ' selected' : ''), ' style="text-align: center;">', $compressor_names[$i], "</option>\n";
    }
    print qq`<option disabled label=" "> </option>\n`;
    print qq`<option disabled style="text-align: center;">Control</option>\n`;
    for (my $i = 0; $i < $n_compressors; $i++)
    {
        if ($compressor_is_special[$i] != 0) { next; }
        print '<option', ($compressor_is_selected{$i} ? ' selected' : ''), ' style="text-align: center;">', $compressor_names[$i], "</option>\n";
    }
    print "</select>\n";
    print "</td>\n";

    print qq`<td style="padding-left: 6pt; text-align: center; vertical-align: top;">`;
    print "Select<br />individual<br />compressor<br />settings:<br />\n";
    print qq`<select name="s" size="18" multiple style="margin-top: 5pt; padding-left: 5pt; padding-right: 5pt;">\n`;
    foreach my $i (sort { versioncmp($setting_names[$a], $setting_names[$b]) } keys @setting_names)
    {
        print '<option', ($setting_is_selected{$i} ? ' selected' : ''), ' style="text-align: center;">', $setting_names[$i], "</option>\n";
    }
    print "</select>\n";
    print "</td>\n";

    print "</tr></table>\n";



    print qq`<h3 class="optheader">Step 3. Configure output</h3>`;

    print qq`<table style="width: 71rem; margin-left: auto; margin-right: auto;">\n`;

    print qq`<tr>`;
    print "<td style=\"width: 23rem; padding-right: 0.5rem;\">";
    print "<h3 style=\"text-align: center;\">Table</h3>\n";
    print "</td>\n";
    print qq`<td style="padding-left: 0.5rem; padding-right: 0.5rem;">\n`;
    print qq`<h3 style="text-align: center;">Column chart</h3>\n`;
    print "</td>\n";
    print qq`<td style="width: 23rem; padding-left: 0.5rem;">\n`;
    print qq`<h3 style="text-align: center;">Scatterplot</h3>\n`;
    print "</td>\n";
    print qq`</tr>`;

    # Table options
    print qq`<tr>`;
    print "<td style=\"width: 23rem; padding-right: 0.5rem;\">";
    print "Columns to show:<br />\n";
    for (my $i = 0; $i < $max_table_columns; $i++)
    {
        print "<select name=\"tm$i\">\n";
        for (my $mi = 0; $mi <= $n_measures + 1; $mi++)
        {
            print '<option value="', $measure_tags[$mi], '"', (($mi == $table_column_measures[$i]) ? ' selected' : '');
            if ($mi == 0) { print ' label=" "'; }
            print '>', $measure_names[$mi];
            if ($mi > 1 and $mi < 20) { print ' (', $measure_units[$mi], ')'; }
            print "</option>\n";
        }
        print "</select><br />\n";
    }
    print "</td>\n";

    # Column chart options
    print qq`<td style="padding-left: 0.5rem; padding-right: 0.5rem;">\n`;
    print qq`Value to plot:<br />\n`;
    print qq`<select name="gm">\n`;
    print '<option value="same"', (($selected_column_chart_measure == 0) ? ' selected' : ''), ">Measure used for sorting</option>\n";
    for (my $mi = 2; $mi <= $n_measures; $mi++)
    {
        if (!$show_measure_in_column_chart[$mi]) { next; }
        print '<option value="', $measure_tags[$mi], '"', (($mi == $selected_column_chart_measure) ? ' selected' : ''), '>', $measure_names[$mi];
        if ($mi > 1) { print ' (', $measure_units[$mi], ')'; }
        print "</option>\n";
    }
    print "</select>\n";
    print '<div class="optfar">Scale:';
    print '<input type="radio" name="cyl" value="lin"', ($column_chart_y_log_scale ? '' : ' checked'), qq` style="margin-left: 8pt; margin-right: 5pt;">linear`;
    print '<input type="radio" name="cyl" value="log"', ($column_chart_y_log_scale ? ' checked' : ''), qq` style="margin-left: 12pt; margin-right: 5pt;">logarithmic`;
    print "</div>\n";
    print qq`<div class="optfar">Chart size: `;
    print qq`<input type="text" name="ccw" size="5" maxlength="5" value="`, $column_chart_width, qq`" style="width: 3.5rem; text-align: center;">`;
    print qq` x `; 
    print qq`<input type="text" name="cch" size="5" maxlength="5" value="`, $column_chart_height, qq`" style="width: 3.5rem; text-align: center;">`;
    print qq` pixels</div>\n`;

    print qq`<div class="optfar">`;
    print qq`<input type="checkbox" name="cc3c" value="1"`,
             ($column_chart_color_by_compressor_specialization ? ' checked' : ''), qq`>`;
    print qq`Highlight specialized vs general-purpose compressors`;
    print qq`</div>`;

    print "</td>\n";

    # Scatterplot options
    print qq`<td style="width: 23rem; padding-left: 0.5rem;">\n`;
    foreach my $axis_name ('x', 'y')
    {
        print qq`<div class="optnear">`;
        print uc($axis_name), qq` axis: <select name="s${axis_name}m">\n`;
        print '<option value="same"', (($selected_scatterplot_measure{$axis_name} == 0) ? ' selected' : ''), ">Measure used for selecting best settings</option>\n";
        for (my $mi = 2; $mi <= $n_measures; $mi++)
        {
            print '<option value="', $measure_tags[$mi], '"', (($mi == $selected_scatterplot_measure{$axis_name}) ? ' selected' : ''), '>', $measure_names[$mi];
            if ($mi > 1) { print ' (', $measure_units[$mi], ')'; }
            print "</option>\n";
        }
        print qq`</select></div>\n`;
        #print qq`<div class="optnear">`, uc($axis_name), qq` axis scale:`;
        print qq`<div class="optnear">`;
        print qq`<input type="checkbox" name="s${axis_name}fr" value="1"`, ($scatterplot_fixed_range{$axis_name} ? ' checked' : ''), qq` style="margin-left: 20pt;">`;
        print qq` Fixed range: `;
        print qq`<input type="text" name="s${axis_name}min" size="12" maxlength="12" value="`, $scatterplot_range_min{$axis_name}, qq`" style="width: 5.5rem; text-align: center;">`;
        print qq` .. `;
        print qq`<input type="text" name="s${axis_name}max" size="12" maxlength="12" value="`, $scatterplot_range_max{$axis_name}, qq`" style="width: 5.5rem; text-align: center;">`;
        print qq`</div>\n`;
        print qq`<div class="optnear">`;
        print qq`<input type="radio" name="s${axis_name}l" value="lin"`, ($scatterplot_log_scale{$axis_name} ? '' : ' checked'), qq` style="margin-left: 80pt; margin-right: 5pt;">linear`;
        print qq`<input type="radio" name="s${axis_name}l" value="log"`, ($scatterplot_log_scale{$axis_name} ? ' checked' : ''), qq` style="margin-left: 12pt; margin-right: 5pt;">logarithmic`;
        print qq`</div>\n`;
    }
    #print '<div class="optfar"><input type="checkbox" name="sl" value="1"', ($scatterplot_use_lines ? ' checked' : ''), '> Connect settings of same compressor with lines</div>', "\n";
    print qq`</td>\n`;
    print qq`</tr>\n`;

    print qq`<tr>`;
    print "<td style=\"width: 23rem; padding-right: 0.5rem;\">";
    print qq`<div style="text-align: center">`;
    print qq`<input type="submit" name="button" value="Show table" style="margin-top: 10pt; font-size: 1rem;">`;
    print qq`<input type="submit" name="button" value="Save CSV" style="margin-left: 15pt; margin-top: 5pt; font-size: 1rem;">`;
    print qq`</div>\n`;
    print "</td>\n";
    print qq`<td style="padding-left: 0.5rem; padding-right: 0.5rem;">\n`;
    print qq`<div style="text-align: center">\n`;
    print qq`<input type="submit" name="button" value="Show column chart" style="margin-top: 10pt; font-size: 1rem;">\n`;
    print qq`</div>\n`;
    print "</td>\n";
    print qq`<td style="width: 23rem; padding-left: 0.5rem;">\n`;
    print qq`<div style="text-align: center">\n`;
    print qq`<input type="submit" name="button" value="Show scatterplot" style="margin-top: 10pt; font-size: 1rem;">\n`;
    print qq`</div>\n`;
    print "</td>\n";
    print qq`</tr>`;

    print qq`</table>\n`;

    print "</form>\n";
}


sub print_header
{
    if ($header_printed) { return; }
    print header(-charset=>'utf-8');
    print q`<!DOCTYPE html> 
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="author" content="Kirill Kryukov" />
<meta name="keywords" content="dna,rna,protein,genome,sequence,compression,benchmark" />
<meta name="abstract" content="Sequence Compression Benchmark" />
<meta name="description" content="Benchmark of various compressors on biological sequences" />
<title>Sequence Compression Benchmark</title>
<link rel="shortcut icon" type="image/png" href="images/benchmark.png" />
<style>
  body  { background-color: white; font-family: sans-serif; padding: 0; margin: 0; }
  div.text { width: 55rem; max-width: 90%; margin: 0 auto; text-align: left; }
  div.text2 { width: 50rem; max-width: 90%; margin: 0 auto; text-align: left; }

  h1 { font-family: sans-serif; font-weight: normal; font-size: 32pt; margin: 3pt 0pt 0pt 0pt; text-align: center; letter-spacing: 1pt; }
  h1 a { text-decoration: none; color: #3658a7; }
  h1 a:hover { text-decoration: underline; }
  div.nav { font-size: 14pt; text-align: center; color: #2b4b93; margin-top: 0; margin-bottom: 5pt; padding: 0; }
  div.nav a { text-decoration: none; color: #3658a7; }
  div.nav a:hover { text-decoration: underline; }
  div.nav ul { margin: 0; padding: 0; }
  div.nav ul li { list-style-type: none; display: inline; margin: 0 0.5rem 0 0.5rem; }
  h2 { font-size: 24pt; color: #1d417b; text-align: center; margin-bottom: 5pt; }
  h3 { font-size: 18pt; color: #1d417b; margin-top: 15pt; margin-bottom: 3pt; }
  h3.cc { text-align: center; margin-top: 30pt; }
  form h3 { font-size: 14pt; margin-top: 0pt; color: #73858C; }
  form h3.optheader { color: #4C585D; text-align: center; margin-top: 15pt; }
  h4 { margin-bottom: 0pt; }
  h4.dense { margin-top: 2pt; }

  div.footer { text-align: center; margin-bottom: 10pt; }
  div.footer a { text-decoration: none; }
  div.footer a:hover { text-decoration: underline; }
  div.error { width: 50rem; margin-left: auto; margin-right: auto; margin-top: 1rem; margin-bottom: 1rem; text-align: center; color: red; }
  div.optfar { margin-top: 12pt; }
  div.optnear { margin-top: 3pt; }
  select option { padding-left: 3pt; padding-right: 3pt; }
  p { margin-top: 5pt; margin-bottom: 0pt; }

  table.d td { text-align: center; }
  table.d thead tr td { padding-top: 10pt; }
  thead tr td { font-weight: bold; padding-left: 5pt; padding-right: 5pt; }
  table.d tbody tr td { padding-left: 5pt; padding-right: 5pt; }
  td.n { text-align: left; padding-left: 5pt; padding-right: 5pt; }
  table.d tbody tr:nth-child(odd) { background-color: #E8E8E8; }
  table.d td.dl table { margin-left: auto; margin-right: auto; border-spacing: 0; }
  table.d td.dl table tr { background-color: inherit; }
  table.d td.dl table td.arrow { font-size: 16pt; margin: 0; padding: 0 2pt 0 0; }
  table.d td.dl a { text-decoration: none; }
  span.arrow { font-size: 16pt; }

  table.c { margin: 5pt auto 0 auto; border-spacing: 0px; border-collapse: separate; border: 2px outset #3460a7; border-radius: 10px; -moz-border-radius: 10px;  }
  table.c tr td { border: 1px solid #264e8f; padding: 3pt 8pt; text-align: center; }
  table.c tr td tt { font-size: 13pt; }

  table.cc { margin: 8pt auto 3pt auto; border-spacing: 0px; border-collapse: collapse; border: 1px solid #3460a7; }
  table.cc tr td { background-color: #e7e7e7; padding: 3pt 8pt; text-align: center; }
  table.cc tr:nth-child(1) { font-weight: bold; }
  table.cc tr td.n { font-weight: bold; }
  table.cc tr td.c { font-family: monospace; font-size: 13pt; }

  table.ex tr td { vertical-align: top; padding-top: 5pt; padding-bottom: 0pt; }
  table.ex tr td ul { padding-top: 0pt; padding-bottom: 0pt; margin-top: 0pt; margin-bottom: 0pt; }
  table.ex tr td ul li { padding-top: 0pt; padding-bottom: 0pt; margin-top: 0pt; margin-bottom: 2pt; }

  table.ex2 { margin-left: auto; margin-right: auto; }
  table.ex2 td { text-align: center; padding-top: 0pt; padding-left: 5pt; padding-right: 5pt; }

  p.pros { color: green; }
  p.cons { color: #AA0000; }
  p.sum { color: #14457b; }
  span.code { font-family: monospace; font-size: larger; background-color: #F0F0F0; }

  ul.wide { margin-top: 5pt; margin-bottom: 5pt; }
  ul.wide li { margin-top: 10pt; }
  li { margin-top: 5pt; }
  ul.dense { margin-top: 5pt; margin-bottom: 5pt; }
  ul.dense li { margin-top: 2pt; margin-bottom: 0pt; }

  .tooltip { position: relative; display: inline-block; border-bottom: 1px dotted black; }
  .tooltip .tooltiptext { visibility: hidden; background-color: white; color: #000000; text-align: center;
                          padding: 4px 0 3px 0; border-radius: 3px; border: 1px solid black;
                          position: absolute; z-index: 1;
                          width: 130px; bottom: 100%; left: 50%; margin-left: -60px; }
  .tooltip:hover .tooltiptext { visibility: visible; }
`;

    if (!$button_pressed)
    {
        print q`
  div.welcome a { text-decoration: none; color: #3658a7; }
  div.welcome a:hover { text-decoration: underline; }
  div.quick { margin-left: auto; margin-right: auto; margin-top: 0pt; margin-bottom: 20pt; width: 50rem;
              border: solid #12BF12 1px; border-radius: 15pt; background-color: #F9FFF5; padding: 5pt 10pt 10pt 10pt; }
  div.quick table { margin-left: auto; margin-right: auto; }
  div.quick td { text-align: center; vertical-align: middle; padding-left: 5pt; padding-right: 5pt; }
  div.quick td.title { padding-right: 15pt; font-size: 12pt; font-weight: bold; }
  div.quick td.buttons input { margin-top: 8pt; margin-left: 5pt; margin-right: 5pt; font-size: 1rem; background-color: white; border-radius: 8pt; }
  div.quick td.buttons input.col { background-color: #DBEEFF; }
  div.quick td.buttons input.sca { background-color: #FFEEDB; }
  div.quick tr.checkboxes td input { width: 15pt; height: 15pt; }
  div.quick td.g { color: #006100; }
  div.quick td.d { color: #800000; }
`;
    }

    print "</style>\n";

    if (($show_bar_graph or $show_column_chart or $show_scatterplot) and $n_datasets_selected > 0 and scalar(keys %use_setting) > 0)
    {
        print qq`<script src="https://www.gstatic.com/charts/loader.js"></script>\n`;
        print qq`<script src="/libs/Blob.js"></script>\n`;
        print qq`<script src="/libs/FileSaver.min.js"></script>\n`;
    }

    print qq`</head>\n`;
    print qq`<body>\n`;
    print qq`<h1><a href="$benchmark_path">Sequence Compression Benchmark</a></h1>\n`;
    print qq`<div class="nav"><ul>\n`;
    foreach my $p ('About', 'Examples', 'Method', 'Datasets', 'Compressors', 'Commands', 'Wrappers', 'Links')
    {
        print qq`<li><a href="?page=$p">`;
        if ($p eq $page_name) { print '<b>'; }
        print $p;
        if ($p eq $page_name) { print '</b>'; }
        print qq`</a></li>`;
    }
    print qq`</ul></div>\n`;

    $header_printed = 1;
}


sub print_footer
{
    print q~<div class="text">
<hr style="margin: 10pt 0 2pt 0;" />
<div class="footer">By <a href="?page=Contributors">Contributors</a>, 2019-2020, public domain</div>
</div></body></html>
~;
}


sub print_welcome_message
{
    print qq`<div class="text" style="margin-top: 20pt; margin-bottom: 10pt; width: 40rem;">
<div class="welcome" style="border: 1px ridge #95CEEE; padding: 10pt; background-color: #F2F9FD; border-radius: 10pt;">Welcome!
We benchmark compressors on DNA, RNA and protein sequences.
Currently we use $n_datasets test datasets, and $n_settings settings of $n_compressors compressors.
Please use the <a href="#QuickSelector">Quick Selector</a>, <a href="?page=Examples">Examples</a>, or jump to <a href="#CustomComparison">Custom Comparison</a>.</div></div>

<div id="QuickSelector" class="quick"><form method="get">
<div style="text-align: center;"><span style="font-size: 20pt; color: #008F88; ">Quick Selector</span></div>
<table><tr><td class="title g">Test data</td><td>
<table>
<tr><td colspan="4" class="g">Genomes</td><td colspan="3" class="d">Other datasets</td><td class="d">Multiple Sequence</td></tr>
<tr>
<td class="g"><div class="tooltip">Tiny<span class="tooltiptext">under 10 MB</span></div></td>
<td class="g"><div class="tooltip">Small<span class="tooltiptext">10 to 100 MB</span></div></td>
<td class="g"><div class="tooltip">Medium<span class="tooltiptext">100 MB to 1 GB</span></div></td>
<td class="g"><div class="tooltip">Large<span class="tooltiptext">over 1 GB</span></div></td>`,

#qq`<td class="g"><div class="tooltip">Huge<span class="tooltiptext">over 10 GB</span></div></td>`,

qq`<td class="d">DNA</td><td class="d">RNA</td><td class="d">Protein</td><td class="d">Alignments</td></tr>
<tr class="checkboxes">
<td class="g"><input type="checkbox" name="tiny genomes" value="1" checked></td>
<td><input type="checkbox" name="small genomes" value="1"></td>
<td><input type="checkbox" name="medium genomes" value="1"></td>
<td><input type="checkbox" name="large genomes" value="1"></td>`,

#qq`<td><input type="checkbox" name="huge genomes" value="1"></td>`,

qq`<td><input type="checkbox" name="dna" value="1"></td>
<td><input type="checkbox" name="rna" value="1"></td>
<td><input type="checkbox" name="protein" value="1"></td>
<td><input type="checkbox" name="aligned dna" value="1"></td>
</tr></table></td></tr>
<tr><td class="title" style="color: #1366AE;">Column&nbsp;chart</td><td class="buttons">
<input type="submit" name="quick-column-chart" class="col" value="Compression Ratio">
<input type="submit" name="quick-column-chart" class="col" value="Decompression Speed">
<input type="submit" name="quick-column-chart" class="col" value="Compression / Decompression Speed">
<input type="submit" name="quick-column-chart" class="col" value="Transfer / Decompression Speed">
<input type="submit" name="quick-column-chart" class="col" value="Compression / Transfer / Decompression Speed">
</td></tr>
<tr><td class="title" style="color: #995200; padding-top: 10pt;">Scatterplot</td><td class="buttons" style="padding-top: 10pt;">
<input type="submit" name="quick-scatterplot" class="sca" value="Compression Ratio -vs- Decompression Speed">
<input type="submit" name="quick-scatterplot" class="sca" value="Compression Ratio -vs- Compression / Decompression Speed">
<input type="submit" name="quick-scatterplot" class="sca" value="Transfer / Decompression Speed -vs- Compression / Transfer / Decompression Speed">
</td></tr></table>
</form></div>

<div id="CustomComparison" class="text" style="margin-bottom: 5pt; text-align: center;"><span style="font-size: 20pt; color: #008F88;">Custom Comparison</span></div>
`;
}


sub commify
{
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}


sub format_data_for_table
{
    my ($d, $m, $commify) = @_;
    my $unit = $measure_units[$m];
    if ($relative_to_reference and $m != 19)
    {
        $d = format_number_with_at_least_3_digits($d);
    }
    elsif ($m == 2)
    {
        $d = sprintf('%.0f', $d);
    }
    else
    {
        if ($unit eq 's' or $unit eq 'B' or $unit eq 'MB' or $unit eq 'MB/s') { $d = format_number_with_at_least_4_digits($d); }
        elsif ($unit eq 'times' or $unit eq '%') { $d = format_number_with_at_least_3_digits($d); }
    }
    if ($commify) { $d = commify($d); }
    return $d;
}


sub format_number_for_screen
{
    my ($number, $m) = @_;
    my $unit = $measure_units[$m];
    if ($relative_to_reference and $m != 19)
    {
        return '<b>' . format_number_with_at_least_3_digits($number) . '</b> times compared to ' . $reference_setting_name;
    }
    else
    {
        if ($unit eq 'B') { return format_short_size_bold_num($number); }
        elsif ($unit eq 'MB') { return format_short_size_bold_num($number * 1000000); }
        elsif ($unit eq 'MB/s') { return format_short_size_bold_num($number * 1000000) . '/s'; }
        elsif ($unit eq 's') { $number = format_number_with_at_least_4_digits($number); }
        elsif ($unit eq 'times' or $unit eq '%') { $number = format_number_with_at_least_3_digits($number); }
    }
    return '<b>' . commify($number) . '</b>&nbsp;' . $unit;
}


sub format_short_size
{
    my ($size) = @_;
    if ($size >= 100000000000) { return sprintf('%.0f GB', $size / 1000000000); }
    if ($size >= 10000000000) { return sprintf('%.1f GB', $size / 1000000000); }
    if ($size >= 1000000000) { return sprintf('%.2f GB', $size / 1000000000); }
    if ($size >= 100000000) { return sprintf('%.0f MB', $size / 1000000); }
    if ($size >= 10000000) { return sprintf('%.1f MB', $size / 1000000); }
    if ($size >= 1000000) { return sprintf('%.2f MB', $size / 1000000); }
    if ($size >= 100000) { return sprintf('%.0f kB', $size / 1000); }
    if ($size >= 10000) { return sprintf('%.1f kB', $size / 1000); }
    if ($size >= 1000) { return sprintf('%.2f kB', $size / 1000); }
    if ($size >= 100) { return sprintf('%.0f B', $size); }
    if ($size >= 10) { return sprintf('%.1f B', $size); }
    return sprintf('%.2f B', $size);
}


sub format_short_size_bold_num
{
    my ($size) = @_;
    if ($size >= 100000000000) { return sprintf('<b>%.0f</b>&nbsp;GB', $size / 1000000000); }
    if ($size >= 10000000000) { return sprintf('<b>%.1f</b>&nbsp;GB', $size / 1000000000); }
    if ($size >= 1000000000) { return sprintf('<b>%.2f</b>&nbsp;GB', $size / 1000000000); }
    if ($size >= 100000000) { return sprintf('<b>%.0f</b>&nbsp;MB', $size / 1000000); }
    if ($size >= 10000000) { return sprintf('<b>%.1f</b>&nbsp;MB', $size / 1000000); }
    if ($size >= 1000000) { return sprintf('<b>%.2f</b>&nbsp;MB', $size / 1000000); }
    if ($size >= 100000) { return sprintf('<b>%.0f</b>&nbsp;kB', $size / 1000); }
    if ($size >= 10000) { return sprintf('<b>%.1f</b>&nbsp;kB', $size / 1000); }
    if ($size >= 1000) { return sprintf('<b>%.2f</b>&nbsp;kB', $size / 1000); }
    if ($size >= 100) { return sprintf('<b>%.0f</b>&nbsp;B', $size); }
    if ($size >= 10) { return sprintf('<b>%.1f</b>&nbsp;B', $size); }
    return sprintf('<b>%.2f</b>&nbsp;B', $size);
}


sub format_number_with_at_least_3_digits
{
    my ($s) = @_;
    if ($s >= 100) { return sprintf('%.0f', $s); }
    elsif ($s >= 10) { return sprintf('%.1f', $s); }
    else { return sprintf('%.2f', $s); }
}


sub format_number_with_at_least_4_digits
{
    my ($s) = @_;
    if ($s >= 1000) { return sprintf('%.0f', $s); }
    elsif ($s >= 100) { return sprintf('%.1f', $s); }
    elsif ($s >= 10) { return sprintf('%.2f', $s); }
    else { return sprintf('%.3f', $s); }
}


sub error
{
    my ($msg) = @_;
    print_header();
    print "<div class=\"error\">$msg</div>\n";
    print_footer();
    exit;
}


sub error_with_options
{
    my ($msg) = @_;
    print_header();
    print "<div class=\"error\">$msg</div>\n";
    print_options();
    print_footer();
    exit;
}


sub html_escape
{
    my ($s) = @_;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    $s =~ s/'/&#39;/g;
    return $s;
}
