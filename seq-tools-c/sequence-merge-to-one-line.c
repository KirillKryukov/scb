/*
 * sequence-merge-to-one-line
 * By Kirill Kryukov, 2019, public domain
 *
 * Usage: sequence-merge-to-one-line <INPUT >OUTPUT
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


static void process(void)
{
    in_begin = 0;
    in_end = fread(in_buffer, 1, in_buffer_size, stdin);

    while (in_end > 0)
    {
        for (size_t i = 0; i < in_end; i++)
        {
            if (in_buffer[i] == 10)
            {
                fwrite(in_buffer + in_begin, 1, i - in_begin, stdout);
                in_begin = i + 1;
            }
        }

        fwrite(in_buffer + in_begin, 1, in_end - in_begin, stdout);

        in_begin = 0;
        in_end = fread(in_buffer, 1, in_buffer_size, stdin);
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
