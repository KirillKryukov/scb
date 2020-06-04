/*
 * fasta-soft-mask-add
 * By Kirill Kryukov, 2019, public domain
 *
 * Usage: fasta-soft-mask-add --mask MASK <IN >OUT
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>


static char *mask_path = NULL;
static FILE *MASK = NULL;

#define in_buffer_size 16384
static unsigned char *in_buffer = NULL;
static size_t in_begin = 0;
static size_t in_end = 0;

static unsigned int masked = 0ull;
unsigned long long length;


static void done(void)
{
    if (MASK != NULL) { fclose(MASK); MASK = NULL; }
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
    for (;;)
    {
        for (size_t i = in_begin; i < in_end; i++)
        {
            if (in_buffer[i] == '>')
            {
                fwrite(in_buffer + in_begin, 1, i - in_begin + 1, stdout);
                in_begin = i + 1;
                return '>';
            }
            else if (in_buffer[i] <= 32) {}
            else
            {
                if (masked)
                {
                    in_buffer[i] = (unsigned char)(in_buffer[i] | 0x20);
                }

                length--;
                if (length == 0)
                {
                    masked = !masked;
                    if (fread(&length, sizeof(length), 1, MASK) != 1) { length = ULLONG_MAX; }
                }
            }
        }

        fwrite(in_buffer + in_begin, 1, in_end - in_begin, stdout);
        refill_in_buffer();
        if (in_end == 0) { return -1; }
    }
}


static void process(void)
{
    int c = in_get_char();
    if (c != '>') { fputs("Input is not in FASTA format\n", stderr); exit(1); }
    fputc(c, stdout);

    if (fread(&length, sizeof(length), 1, MASK) != 1) { return; }

    do
    {
        c = print_name();
        if (c >= 0) { c = process_sequence(); }
    }
    while (c >= 0);
}


int main(int argc, char **argv)
{
    atexit(done);

    for (int i = 1; i < argc; i++)
    {
        if (i < argc - 1)
        {
            if (!strcmp(argv[i], "--mask")) { i++; mask_path = argv[i]; continue; }
        }
        fprintf(stderr, "Unknown or incomplete argument \"%s\"\n", argv[i]);
    }
    if (mask_path == NULL) { fputs("Mask file name is not specified\n", stderr); exit(1); }
    if (mask_path[0] == '\0') { fputs("Empty mask path specified\n", stderr); exit(1); }

    if (!freopen(NULL, "rb", stdin)) { fputs("Can't read input in binary mode\n", stderr); exit(1); }
    if (!freopen(NULL, "wb", stdout)) { fputs("Can't set output stream to binary mode\n", stderr); exit(1); }

    MASK = fopen(mask_path, "rb");
    if (MASK == NULL) { fputs("Can't open mask file\n", stderr); exit(1); }

    in_buffer = (unsigned char *) malloc(in_buffer_size);
    if (in_buffer == NULL) { fputs("Can't allocate memory\n", stderr); exit(1); }

    process();

    return 0;
}
