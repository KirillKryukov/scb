/*
 * sequence-soft-mask-add
 * By Kirill Kryukov, 2019, public domain
 *
 * Usage: sequence-soft-mask-add --mask MASK <IN >OUT
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>


static char *mask_path = NULL;
static FILE *MASK = NULL;

#define in_buffer_size 16384
static unsigned char *in_buffer = NULL;
static size_t in_begin = 0;
static size_t in_end = 0;


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


static int process_non_masked(void)
{
    unsigned long long length;
    if (fread(&length, sizeof(length), 1, MASK) != 1) { return -1; }

    while (length > 0)
    {
        if (in_begin >= in_end)
        {
            refill_in_buffer();
            if (in_end == 0) { return -1; }
        }

        unsigned long long len1 = in_end - in_begin;
        if (len1 > length) { len1 = length; }

        fwrite(in_buffer + in_begin, 1, len1, stdout);

        length -= len1;
        in_begin += len1;
    }

    return 0;
}


static int process_masked(void)
{
    unsigned long long length;
    if (fread(&length, sizeof(length), 1, MASK) != 1) { return -1; }

    while (length > 0)
    {
        if (in_begin >= in_end)
        {
            refill_in_buffer();
            if (in_end == 0) { return -1; }
        }

        unsigned long long len1 = in_end - in_begin;
        if (len1 > length) { len1 = length; }

        for (size_t i = in_begin; i < in_begin + len1; i++)
        {
            in_buffer[i] = (unsigned char)(in_buffer[i] | 0x20);
        }

        fwrite(in_buffer + in_begin, 1, len1, stdout);

        length -= len1;
        in_begin += len1;
    }

    return 0;
}


static void process(void)
{
    if (process_non_masked() < 0) { return; }

    for (;;)
    {
        if (process_masked() < 0) { return; }
        if (process_non_masked() < 0) { return; }
    }
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
