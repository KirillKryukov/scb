/*
 * fastq-to-sequence
 * By Kirill Kryukov, 2019, public domain
 *
 * Usage: fastq-to-sequence <FASTQ >SEQUENCE
 */

#include <stdlib.h>
#include <stdio.h>


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
static inline int skip_name(void)
{
    for (;;)
    {
        for (size_t i = in_begin; i < in_end; i++)
        {
            if (in_buffer[i] == 10)
            {
                in_begin = i;
                return 10;
            }
        }

        refill_in_buffer();
        if (in_end == 0) { return -1; }
    }
}


__attribute__((always_inline))
static inline int print_sequence(void)
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
                i++;
                in_begin = i;

                if (i >= in_end)
                {
                    refill_in_buffer();
                    if (in_end == 0) { return -1; }
                    i = in_begin;
                }

                if (in_buffer[i] == '+') { in_begin = i + 1; return '+'; }
            }
        }

        if (i > in_begin)
        {
            fwrite(in_buffer + in_begin, 1, i - in_begin, stdout);
        }
        in_begin = i;
    }
}


__attribute__((always_inline))
static inline int skip_quality(void)
{
    for (;;)
    {
        for (size_t i = in_begin; i < in_end; i++)
        {
            if (in_buffer[i] == '@')
            {
                in_begin = i + 1;
                return '@';
            }
        }

        refill_in_buffer();
        if (in_end == 0) { return -1; }
    }
}


static void process(void)
{
    int c = in_get_char();
    if (c != '@') { fputs("fastq-to-sequence error: input is not in FASTQ format\n", stderr); exit(1); }

    while (c >= 0)
    {
        c = skip_name();
        if (c >= 0) { c = print_sequence(); }
        if (c >= 0) { c = skip_quality(); }
    }
}


int main(void)
{
    atexit(done);

    if (!freopen(NULL, "rb", stdin)) { fputs("Can't read input in binary mode\n", stderr); exit(1); }
    if (!freopen(NULL, "wb", stdout)) { fputs("Can't set output stream to binary mode\n", stderr); exit(1); }

    in_buffer = (unsigned char *) malloc(in_buffer_size);
    if (in_buffer == NULL) { fputs("Can't allocate memory\n", stderr); exit(1); }

    process();

    return 0;
}
