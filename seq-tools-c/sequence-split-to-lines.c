/*
 * sequence-split-to-lines
 * By Kirill Kryukov, 2019, public domain
 *
 * Usage: sequence-split-to-lines --line-length L <INPUT >OUTPUT
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


static void process(void)
{
    unsigned long long line_rem = line_length;

    for (;;)
    {
        if (in_begin >= in_end)
        {
            in_begin = 0;
            in_end = fread(in_buffer, 1, in_buffer_size, stdin);
            if (in_end == 0) { break; }
        }

        unsigned long long len1 = in_end - in_begin;
        if (len1 > line_rem) { len1 = line_rem; }

        fwrite(in_buffer + in_begin, 1, len1, stdout);

        line_rem -= len1;
        in_begin += len1;

        if (line_rem == 0) { fputc(10, stdout); line_rem = line_length; }
    }

    if (line_rem != line_length) { fputc(10, stdout); }
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
