/*
 * fasta-from-names-lengths-sequence
 * By Kirill Kryukov, 2019, public domain
 *
 * Usage: fasta-from-names-lengths-sequence --lengths LENGTHS --names NAMES --line-length L <SEQUENCE >FASTA
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>


static char *names_path = NULL;
static char *lengths_path = NULL;
static FILE *NAMES = NULL;
static FILE *LENGTHS = NULL;

static unsigned long long line_length = 0ull;

#define in_buffer_size 16384
static unsigned char *in_seq_buffer = NULL;
static size_t in_seq_begin = 0;
static size_t in_seq_end = 0;
static unsigned char *in_names_buffer = NULL;
static size_t in_names_begin = 0;
static size_t in_names_end = 0;


static void done(void)
{
    if (NAMES != NULL) { fclose(NAMES); NAMES = NULL; }
    if (LENGTHS != NULL) { fclose(LENGTHS); LENGTHS = NULL; }
    if (in_seq_buffer != NULL) { free(in_seq_buffer); in_seq_buffer = NULL; }
    if (in_names_buffer != NULL) { free(in_names_buffer); in_names_buffer = NULL; }
}


__attribute__((always_inline))
static inline int print_name(void)
{
    if (in_names_begin >= in_names_end)
    {
        in_names_begin = 0;
        in_names_end = fread(in_names_buffer, 1, in_buffer_size, NAMES);
        if (in_names_end == 0) { return -1; }
    }

    fputc('>', stdout);

    for (;;)
    {
        for (size_t i = in_names_begin; i < in_names_end; i++)
        {
            if (in_names_buffer[i] == 10)
            {
                fwrite(in_names_buffer + in_names_begin, 1, i - in_names_begin + 1, stdout);
                in_names_begin = i + 1;
                return 10;
            }
        }

        fwrite(in_names_buffer + in_names_begin, 1, in_names_end - in_names_begin, stdout);

        in_names_begin = 0;
        in_names_end = fread(in_names_buffer, 1, in_buffer_size, NAMES);
        if (in_names_end == 0) { return -1; }
    }
}


__attribute__((always_inline))
static inline int print_sequence(void)
{
    unsigned long long length;
    if (fread(&length, sizeof(length), 1, LENGTHS) != 1) { return -1; }

    unsigned long long line_rem = line_length;

    while (length > 0)
    {
        if (in_seq_begin >= in_seq_end)
        {
            in_seq_begin = 0;
            in_seq_end = fread(in_seq_buffer, 1, in_buffer_size, stdin);
            if (in_seq_end == 0) { return -1; }
        }

        unsigned long long len1 = in_seq_end - in_seq_begin;
        if (len1 > length) { len1 = length; }

        if (len1 > line_rem) { len1 = line_rem; }

        fwrite(in_seq_buffer + in_seq_begin, 1, len1, stdout);

        length -= len1;
        in_seq_begin += len1;

        line_rem -= len1;
        if (line_rem == 0) { fputc(10, stdout); line_rem = line_length; }
    }

    if (line_rem != line_length) { fputc(10, stdout); }

    return 0;
}


static void process(void)
{
    for (;;)
    {
        if (print_name() < 0) { return; }
        if (print_sequence() < 0) { return; }
    }
}


int main(int argc, char **argv)
{
    atexit(done);

    for (int i = 1; i < argc; i++)
    {
        if (i < argc - 1)
        {
            if (!strcmp(argv[i], "--names")) { i++; names_path = argv[i]; continue; }
            if (!strcmp(argv[i], "--lengths")) { i++; lengths_path = argv[i]; continue; }
            if (!strcmp(argv[i], "--line-length")) { i++; line_length = strtoull(argv[i], NULL, 10); continue; }
        }
        fprintf(stderr, "Unknown or incomplete argument \"%s\"\n", argv[i]);
    }
    if (names_path == NULL) { fputs("Names file name is not specified\n", stderr); exit(1); }
    if (lengths_path == NULL) { fputs("Lengths file name is not specified\n", stderr); exit(1); }
    if (names_path[0] == '\0') { fputs("Empty names path specified\n", stderr); exit(1); }
    if (lengths_path[0] == '\0') { fputs("Empty lengths path specified\n", stderr); exit(1); }

    if (!freopen(NULL, "rb", stdin)) { fputs("Can't read input in binary mode\n", stderr); exit(1); }
    if (!freopen(NULL, "wb", stdout)) { fputs("Can't set output stream to binary mode\n", stderr); exit(1); }

    NAMES = fopen(names_path, "rb");
    if (NAMES == NULL) { fputs("Can't open names file\n", stderr); exit(1); }
    LENGTHS = fopen(lengths_path, "rb");
    if (LENGTHS == NULL) { fputs("Can't open lengths file\n", stderr); exit(1); }

    in_seq_buffer = (unsigned char *) malloc(in_buffer_size);
    if (in_seq_buffer == NULL) { fputs("Can't allocate memory\n", stderr); exit(1); }
    in_names_buffer = (unsigned char *) malloc(in_buffer_size);
    if (in_names_buffer == NULL) { fputs("Can't allocate memory\n", stderr); exit(1); }

    process();

    return 0;
}
