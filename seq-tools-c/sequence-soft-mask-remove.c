/*
 * sequence-soft-mask-remove
 * By Kirill Kryukov, 2019, public domain
 *
 * Usage: sequence-soft-mask-remove --mask MASK <IN >OUT
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>


static char *mask_path = NULL;
static FILE *MASK = NULL;

#define in_buffer_size 16384
static unsigned char *in_buffer = NULL;
static size_t in_end = 0;

static unsigned int masked = 0ull;
static unsigned long long length = 0ull;


static void done(void)
{
    if (MASK != NULL) { fclose(MASK); MASK = NULL; }
    if (in_buffer != NULL) { free(in_buffer); in_buffer = NULL; }
}


static void process(void)
{
    do
    {
        in_end = fread(in_buffer, 1, in_buffer_size, stdin);

        for (size_t i = 0; i < in_end; i++)
        {
            if ((in_buffer[i] >= 96) != masked)
            {
                //fprintf(MASK, "%llu\n", length);
                fwrite(&length, sizeof(length), 1, MASK);
                masked = !masked;
                length = 0ull;
            }

            in_buffer[i] = (unsigned char)(in_buffer[i] & 0xDF);
            length++;
        }

        fwrite(in_buffer, 1, in_end, stdout);
    }
    while (in_end > 0);

    //if (length > 0) { fprintf(MASK, "%llu\n", length); }
    if (length > 0) { fwrite(&length, sizeof(length), 1, MASK); }
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

    MASK = fopen(mask_path, "wb");
    if (MASK == NULL) { fputs("Can't create mask file\n", stderr); exit(1); }

    in_buffer = (unsigned char *) malloc(in_buffer_size);
    if (in_buffer == NULL) { fputs("Can't allocate memory\n", stderr); exit(1); }

    process();

    return 0;
}
