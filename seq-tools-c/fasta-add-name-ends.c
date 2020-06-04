/*
 * fasta-add-name-ends
 * by Kirill Kryukov, 2019, public domain
 *
 * Usage: fasta-add-name-ends NAMEENDS <INPUT >OUTPUT
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>


static char *name_ends_path = NULL;
static FILE *NAMEENDS = NULL;

#define in_buffer_size 16384
static unsigned char *in_buffer = NULL;
static size_t in_begin = 0;
static size_t in_end = 0;
static unsigned char *in_name_ends_buffer = NULL;
static size_t in_name_ends_begin = 0;
static size_t in_name_ends_end = 0;


static void done(void)
{
    if (NAMEENDS != NULL) { fclose(NAMEENDS); NAMEENDS = NULL; }
    if (in_buffer) { free(in_buffer); in_buffer = NULL; }
    if (in_name_ends_buffer) { free(in_name_ends_buffer); in_name_ends_buffer = NULL; }
}


__attribute__((always_inline))
static inline void refill_in_buffer(void)
{
    in_begin = 0;
    in_end = fread(in_buffer, 1, in_buffer_size, stdin);
}


__attribute__((always_inline))
static inline void refill_in_name_ends_buffer(void)
{
    in_name_ends_begin = 0;
    in_name_ends_end = fread(in_name_ends_buffer, 1, in_buffer_size, NAMEENDS);
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
static inline int print_name_start(void)
{
    for (;;)
    {
        for (size_t i = in_begin; i < in_end; i++)
        {
            if (in_buffer[i] == 10)
            {
                fwrite(in_buffer + in_begin, 1, i - in_begin, stdout);
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
static inline int print_name_end(void)
{
    for (;;)
    {
        for (size_t i = in_name_ends_begin; i < in_name_ends_end; i++)
        {
            if (in_name_ends_buffer[i] == 10)
            {
                fwrite(in_name_ends_buffer + in_name_ends_begin, 1, i - in_name_ends_begin + 1, stdout);
                in_name_ends_begin = i + 1;
                return 10;
            }
        }

        fwrite(in_name_ends_buffer + in_name_ends_begin, 1, in_name_ends_end - in_name_ends_begin, stdout);
        refill_in_name_ends_buffer();
        if (in_name_ends_end == 0) { return -1; }
    }
}


__attribute__((always_inline))
static inline int print_sequence(void)
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
            if (in_buffer[i] == '>') { c = in_buffer[i]; break; }
        }

        if (i == in_end) { i--; }
        fwrite(in_buffer + in_begin, 1, i - in_begin + 1, stdout);
        in_begin = i + 1;
        if (c >= 0) { break; }
    }

    return c;
}


static void process(void)
{
    int c = in_get_char();
    if (c != '>') { fputs("Input is not in FASTA format\n", stderr); exit(1); }
    fputc(c, stdout);

    for (;;)
    {
        if (print_name_start() == -1) { return; }
        print_name_end();
        if (print_sequence() == -1) { return; }
    }
}


int main(int argc, char **argv)
{
    atexit(done);

    for (int i = 1; i < argc; i++)
    {
        if (i < argc - 1)
        {
            if (!strcmp(argv[i], "--name-ends")) { i++; name_ends_path = argv[i]; continue; }
        }
        fprintf(stderr, "Unknown or incomplete argument \"%s\"\n", argv[i]);
    }
    if (name_ends_path == NULL) { fputs("Name ends file name is not specified\n", stderr); exit(1); }
    if (name_ends_path[0] == '\0') { fputs("Empty name ends path specified\n", stderr); exit(1); }

    if (!freopen(NULL, "rb", stdin)) { fputs("Can't read input in binary mode\n", stderr); exit(1); }
    if (!freopen(NULL, "wb", stdout)) { fputs("Can't set output stream to binary mode\n", stderr); exit(1); }

    NAMEENDS = fopen(name_ends_path, "rb");
    if (NAMEENDS == NULL) { fputs("Can't open name ends file\n", stderr); exit(1); }

    in_buffer = (unsigned char *) malloc(in_buffer_size);
    if (in_buffer == NULL) { fputs("Can't allocate memory\n", stderr); exit(1); }
    in_name_ends_buffer = (unsigned char *) malloc(in_buffer_size);
    if (in_name_ends_buffer == NULL) { fputs("Can't allocate memory\n", stderr); exit(1); }

    process();

    return 0;
}
