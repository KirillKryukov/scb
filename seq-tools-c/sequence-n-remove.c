/*
 * sequence-n-remove
 * By Kirill Kryukov, 2019, public domain
 *
 * Usage: sequence-n-remove --n NFILE <IN >OUT
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>


static char *nfile_path = NULL;
static FILE *NFILE = NULL;

#define in_buffer_size 16384
static unsigned char *in_buffer = NULL;
static size_t in_begin = 0;
static size_t in_end = 0;

static unsigned int masked = 0u;
static unsigned long long length = 0ull;


static void done(void)
{
    if (NFILE != NULL) { fclose(NFILE); NFILE = NULL; }
    if (in_buffer != NULL) { free(in_buffer); in_buffer = NULL; }
}


static void process(void)
{
    do
    {
        in_begin = 0;
        in_end = fread(in_buffer, 1, in_buffer_size, stdin);

        for (size_t i = 0; i < in_end; i++)
        {
            if ((in_buffer[i] == 'N') != masked)
            {
                length += i - in_begin;
                fwrite(&length, sizeof(length), 1, NFILE);
                if (!masked) { fwrite(in_buffer + in_begin, 1, i - in_begin, stdout); }
                masked = !masked;
                length = 0ull;
                in_begin = i;
            }
        }

        length += in_end - in_begin;
        if (!masked) { fwrite(in_buffer + in_begin, 1, in_end - in_begin, stdout); }
    }
    while (in_end > 0);

    if (length > 0) { fwrite(&length, sizeof(length), 1, NFILE); }
}


int main(int argc, char **argv)
{
    atexit(done);

    for (int i = 1; i < argc; i++)
    {
        if (i < argc - 1)
        {
            if (!strcmp(argv[i], "--n")) { i++; nfile_path = argv[i]; continue; }
        }
        fprintf(stderr, "Unknown or incomplete argument \"%s\"\n", argv[i]);
    }
    if (nfile_path == NULL) { fputs("Mask file name is not specified\n", stderr); exit(1); }
    if (nfile_path[0] == '\0') { fputs("Empty mask path specified\n", stderr); exit(1); }

    if (!freopen(NULL, "rb", stdin)) { fputs("Can't read input in binary mode\n", stderr); exit(1); }
    if (!freopen(NULL, "wb", stdout)) { fputs("Can't set output stream to binary mode\n", stderr); exit(1); }

    NFILE = fopen(nfile_path, "wb");
    if (NFILE == NULL) { fputs("Can't create N file\n", stderr); exit(1); }

    in_buffer = (unsigned char *) malloc(in_buffer_size);
    if (in_buffer == NULL) { fputs("Can't allocate memory\n", stderr); exit(1); }

    process();

    return 0;
}
