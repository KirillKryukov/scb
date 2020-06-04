/*
 * fastq-from-sequence
 * By Kirill Kryukov, 2019, public domain
 *
 * Usage: fastq-from-sequence --name-prefix P --seq-length L --quality Q <SEQUENCE >FASTA
 *
 * Note: L must be smaller than 8k
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>


static unsigned char quality_char = '?';

static char *name_prefix = NULL;

static unsigned long long seq_number = 0ull;
static unsigned long long seq_length = 0ull;
static bool seq_length_specified = false;

#define in_buffer_size 16384
static unsigned char *in_buffer = NULL;
static size_t in_begin = 0;
static size_t in_end = 0;

static unsigned char *qual_buffer = NULL;


static void done(void)
{
    if (in_buffer != NULL) { free(in_buffer); in_buffer = NULL; }
    if (qual_buffer != NULL) { free(qual_buffer); qual_buffer = NULL; }
}


static void process(void)
{
    in_end = fread(in_buffer, 1, in_buffer_size, stdin);
    unsigned long long seq_rem = 0ull;
    unsigned long long cur_seq_length = 0ull;

    while (in_end > 0)
    {
        if (seq_rem > 0ull)
        {
            unsigned long long len1 = in_end - in_begin;
            if (len1 > seq_rem) { len1 = seq_rem; }
            fwrite(in_buffer, 1, len1, stdout);
            cur_seq_length += len1;
            fputs("\n+\n", stdout);
            unsigned long long qual_rem = cur_seq_length;
            while (qual_rem >= in_buffer_size) { fwrite(qual_buffer, 1, in_buffer_size, stdout); qual_rem -= in_buffer_size; }
            if (qual_rem > 0) { fwrite(qual_buffer, 1, qual_rem, stdout); }
            fputc(10, stdout);
            cur_seq_length = 0ull;
            seq_rem = 0ull;
            in_begin += len1;
        }

        for (size_t i = in_begin + seq_length; i <= in_end; i += seq_length)
        {
            seq_number++;
            if (name_prefix == NULL) { fprintf(stdout, "@%llu\n", seq_number); }
            else { fprintf(stdout, "@%s%llu\n", name_prefix, seq_number); }
            fwrite(in_buffer + in_begin, 1, seq_length, stdout);
            fputs("\n+\n", stdout);
            unsigned long long qual_rem = seq_length;
            while (qual_rem >= in_buffer_size) { fwrite(qual_buffer, 1, in_buffer_size, stdout); qual_rem -= in_buffer_size; }
            if (qual_rem > 0) { fwrite(qual_buffer, 1, qual_rem, stdout); }
            fputc(10, stdout);
            in_begin = i;
        }

        if (in_begin < in_end)
        {
            seq_number++;
            if (name_prefix == NULL) { fprintf(stdout, "@%llu\n", seq_number); }
            else { fprintf(stdout, "@%s%llu\n", name_prefix, seq_number); }
            unsigned long long len1 = in_end - in_begin;
            fwrite(in_buffer + in_begin, 1, len1, stdout);
            cur_seq_length = len1;
            seq_rem = seq_length - len1;
        }

        in_begin = 0;
        in_end = fread(in_buffer, 1, in_buffer_size, stdin);
    }

    if (seq_rem > 0)
    {
        fputs("\n+\n", stdout);
        unsigned long long qual_rem = cur_seq_length;
        while (qual_rem >= in_buffer_size) { fwrite(qual_buffer, 1, in_buffer_size, stdout); qual_rem -= in_buffer_size; }
        if (qual_rem > 0) { fwrite(qual_buffer, 1, qual_rem, stdout); }
        fputc(10, stdout);
    }
}


int main(int argc, char **argv)
{
    atexit(done);

    for (int i = 1; i < argc; i++)
    {
        if (i < argc - 1)
        {
            if (!strcmp(argv[i], "--seq-length")) { i++; seq_length_specified = true; seq_length = strtoull(argv[i], NULL, 10); continue; }
            if (!strcmp(argv[i], "--name-prefix")) { i++; name_prefix = argv[i]; continue; }
            if (!strcmp(argv[i], "--quality")) { i++; quality_char = (unsigned char)argv[i][0]; continue; }
        }
        fprintf(stderr, "Unknown or incomplete argument \"%s\"\n", argv[i]);
        exit(1);
    }

    if (!freopen(NULL, "rb", stdin)) { fputs("Can't read input in binary mode\n", stderr); exit(1); }
    if (!freopen(NULL, "wb", stdout)) { fputs("Can't set output stream to binary mode\n", stderr); exit(1); }
    if (!seq_length_specified) { fputs("--seq-length is not specified\n", stderr); exit(1); }
    if (seq_length == 0ull) { fputs("--seq-length is 0\n", stderr); exit(1); }

    in_buffer = (unsigned char *) malloc(in_buffer_size);
    if (in_buffer == NULL) { fputs("Can't allocate memory\n", stderr); exit(1); }

    qual_buffer = (unsigned char *) malloc(in_buffer_size);
    if (qual_buffer == NULL) { fputs("Can't allocate memory\n", stderr); exit(1); }
    memset(qual_buffer, quality_char, in_buffer_size);

    process();

    return 0;
}
