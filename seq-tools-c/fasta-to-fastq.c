/*
 * fasta-to-fastq
 * by Kirill Kryukov, 2019, public domain
 *
 * Usage: fasta-to-fastq --quality Q <INPUT >OUTPUT
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

static unsigned char quality_char = '?';
unsigned long long seq_length = 0ull;

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


__attribute__((always_inline))
static inline void refill_in_buffer(void)
{
    in_begin = 0;
    in_end = fread(in_buffer, 1, in_buffer_size, stdin);
}


__attribute__((always_inline))
static inline int in_get_char(void)
{
    if (in_begin >= in_end)
    {
        refill_in_buffer();
        if (in_end == 0) { return -1; }
    }
    return in_buffer[in_begin++];
}


__attribute__((always_inline))
static inline int print_name(void)
{
    for (;;)
    {
        for (size_t i = in_begin; i < in_end; i++)
        {
            if (in_buffer[i] == 10)
            {
                fwrite(in_buffer + in_begin, 1, i - in_begin + 1, stdout);
                in_begin = i;
                return 10;
            }
        }

        fwrite(in_buffer + in_begin, 1, in_end - in_begin, stdout);
        refill_in_buffer();
        if (in_end == 0) { return -1; }
    }
}


__attribute__((always_inline))
static inline int process_sequence(void)
{
    for (;;)
    {
        if (in_begin >= in_end)
        {
            refill_in_buffer();
            if (in_end == 0) { return -1; }
        }

        size_t i;
        for (i = in_begin; i < in_end; i++)
        {
            if (in_buffer[i] == 10)
            {
                fwrite(in_buffer + in_begin, 1, i - in_begin, stdout);
                seq_length += i - in_begin;
                i++;
                in_begin = i;

                if (i >= in_end)
                {
                    refill_in_buffer();
                    if (in_end == 0) { return -1; }
                    i = in_begin;
                }

                if (in_buffer[i] == '>') { in_begin = i + 1; return '>'; }
            }
        }

        if (i > in_begin)
        {
            fwrite(in_buffer + in_begin, 1, i - in_begin, stdout);
            seq_length += i - in_begin;
        }
        in_begin = i;
    }
}


static void process(void)
{
    int c = in_get_char();
    if (c != '>') { fputs("Input is not in FASTA format\n", stderr); exit(1); }

    while (c >= 0)
    {
        fputc('@', stdout);
        c = print_name();
        if (c != -1) { c = process_sequence(); }
        fputs("\n+\n", stdout);
        unsigned long long rem = seq_length;
        while (rem >= in_buffer_size) { fwrite(qual_buffer, 1, in_buffer_size, stdout); rem -= in_buffer_size; }
        if (rem > 0) { fwrite(qual_buffer, 1, rem, stdout); }
        fputc(10, stdout);
        seq_length = 0;
    }
}


int main(int argc, char **argv)
{
    atexit(done);

    for (int i = 1; i < argc; i++)
    {
        if (i < argc - 1)
        {
            if (!strcmp(argv[i], "--quality")) { i++; quality_char = (unsigned char)argv[i][0]; continue; }
        }
        fprintf(stderr, "Unknown or incomplete argument \"%s\"\n", argv[i]);
        exit(1);
    }

    if (!freopen(NULL, "rb", stdin)) { fputs("Can't read input in binary mode\n", stderr); exit(1); }
    if (!freopen(NULL, "wb", stdout)) { fputs("Can't set output stream to binary mode\n", stderr); exit(1); }

    in_buffer = (unsigned char *) malloc(in_buffer_size);
    if (in_buffer == NULL) { fputs("Can't allocate memory\n", stderr); exit(1); }

    qual_buffer = (unsigned char *) malloc(in_buffer_size);
    if (qual_buffer == NULL) { fputs("Can't allocate memory\n", stderr); exit(1); }
    memset(qual_buffer, quality_char, in_buffer_size);

    process();

    return 0;
}
