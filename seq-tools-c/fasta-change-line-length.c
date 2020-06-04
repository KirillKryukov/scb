/*
 * fasta-change-line-length
 * by Kirill Kryukov, 2019, public domain
 *
 * Usage: fasta-change-line-length --line-length L <INPUT >OUTPUT
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>


static unsigned long long line_length = 0ull;

#define in_buffer_size 16384
static unsigned char *in_buffer = NULL;
static size_t in_begin = 0;
static size_t in_end = 0;


static void done(void)
{
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
    for (;;)
    {
        for (size_t i = in_begin; i < in_end; i++)
        {
            if (in_buffer[i] == 10)
            {
                fwrite(in_buffer + in_begin, 1, i - in_begin + 1, stdout);
                in_begin = i + 1;
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
    unsigned long long line_rem = line_length;

    do
    {
        for (size_t i = in_begin; i < in_end; i++)
        {
            if (in_buffer[i] == '>')
            {
                fwrite(in_buffer + in_begin, 1, i - in_begin, stdout);
                if (line_rem != line_length) { fputc(10, stdout); }
                in_begin = i + 1;
                return '>';
            }
            else if (in_buffer[i] == 10)
            {
                fwrite(in_buffer + in_begin, 1, i - in_begin, stdout);
                in_begin = i + 1;
            }
            else
            {
                line_rem--;
                if (line_rem == 0)
                {
                    fwrite(in_buffer + in_begin, 1, i - in_begin + 1, stdout);
                    fputc(10, stdout);
                    in_begin = i + 1;
                    line_rem = line_length;
                }
            }
        }

        fwrite(in_buffer + in_begin, 1, in_end - in_begin, stdout);
        refill_in_buffer();
    }
    while (in_end > 0);

    if (line_rem != line_length) { fputc(10, stdout); }
    return -1;
}


static void process(void)
{
    int c = in_get_char();
    if (c != '>') { fputs("Input is not in FASTA format\n", stderr); exit(1); }

    for (;;)
    {
        fputc('>', stdout);
        if (print_name() < 0) { return; }
        if (process_sequence() < 0) { return; }
    }
}


int main(int argc, char **argv)
{
    atexit(done);

    for (int i = 1; i < argc; i++)
    {
        if (i < argc - 1)
        {
            if (!strcmp(argv[i], "--line-length")) { i++; line_length = strtoull(argv[i], NULL, 10); continue; }
        }
        fprintf(stderr, "Unknown or incomplete argument \"%s\"\n", argv[i]);
    }

    if (!freopen(NULL, "rb", stdin)) { fputs("Can't read input in binary mode\n", stderr); exit(1); }
    if (!freopen(NULL, "wb", stdout)) { fputs("Can't set output stream to binary mode\n", stderr); exit(1); }

    in_buffer = (unsigned char *) malloc(in_buffer_size);
    if (in_buffer == NULL) { fputs("Can't allocate memory\n", stderr); exit(1); }

    process();

    return 0;
}
