/*
 * fasta-to-names-lengths-sequence
 * By Kirill Kryukov, 2019, public domain
 *
 * Usage: fasta-to-names-lengths-sequence --lengths LENGTHS --names NAMES <FASTA >SEQUENCE
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>


static char *names_path = NULL;
static char *lengths_path = NULL;
static FILE *NAMES = NULL;
static FILE *LENGTHS = NULL;

#define in_buffer_size 16384
static unsigned char *in_buffer = NULL;
static size_t in_begin = 0;
static size_t in_end = 0;

unsigned long long cur_seq_length = 0ull;


static void done(void)
{
    if (NAMES != NULL) { fclose(NAMES); NAMES = NULL; }
    if (LENGTHS != NULL) { fclose(LENGTHS); LENGTHS = NULL; }
    if (in_buffer != NULL) { free(in_buffer); in_buffer = NULL; }
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
    int c = -1;
    for (;;)
    {
        if (in_begin >= in_end)
        {
            refill_in_buffer();
            if (in_end == 0) { break; }
        }

        size_t i;
        for (i = in_begin; i < in_end; i++)
        {
            if (in_buffer[i] == 10) { c = 10; break; }
        }

        if (i == in_end) { i--; }
        fwrite(in_buffer + in_begin, 1, i - in_begin + 1, NAMES);
        in_begin = i + 1;
        if (c >= 0) { break; }
    }

    return c;
}


__attribute__((always_inline))
static inline int print_seq(void)
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
                cur_seq_length += i - in_begin;
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
            cur_seq_length += i - in_begin;
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
        c = print_name();
        if (c != -1) { c = print_seq(); }
        //fprintf(LENGTHS, "%llu\n", cur_seq_length);
        fwrite(&cur_seq_length, sizeof(cur_seq_length), 1, LENGTHS);
        cur_seq_length = 0;
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
        }
        fprintf(stderr, "Unknown or incomplete argument \"%s\"\n", argv[i]);
    }
    if (names_path == NULL) { fputs("Names file name is not specified\n", stderr); exit(1); }
    if (lengths_path == NULL) { fputs("Lengths file name is not specified\n", stderr); exit(1); }
    if (names_path[0] == '\0') { fputs("Empty names path specified\n", stderr); exit(1); }
    if (lengths_path[0] == '\0') { fputs("Empty lengths path specified\n", stderr); exit(1); }

    if (!freopen(NULL, "rb", stdin)) { fputs("Can't read input in binary mode\n", stderr); exit(1); }
    if (!freopen(NULL, "wb", stdout)) { fputs("Can't set output stream to binary mode\n", stderr); exit(1); }

    NAMES = fopen(names_path, "wb");
    if (NAMES == NULL) { fputs("Can't create names file\n", stderr); exit(1); }
    LENGTHS = fopen(lengths_path, "wb");
    if (LENGTHS == NULL) { fputs("Can't create lengths file\n", stderr); exit(1); }

    in_buffer = (unsigned char *) malloc(in_buffer_size);
    if (in_buffer == NULL) { fputs("Can't allocate memory\n", stderr); exit(1); }

    process();

    return 0;
}
