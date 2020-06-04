/*
 * sequence-n-add
 * By Kirill Kryukov, 2019, public domain
 *
 * Usage: sequence-n-add --n NFILE <IN >OUT
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

static unsigned char *N_buffer = NULL;


static void done(void)
{
    if (NFILE != NULL) { fclose(NFILE); NFILE = NULL; }
    if (in_buffer != NULL) { free(in_buffer); in_buffer = NULL; }
    if (N_buffer != NULL) { free(N_buffer); N_buffer = NULL; }
}


static int process_non_masked(void)
{
    unsigned long long length;
    if (fread(&length, sizeof(length), 1, NFILE) != 1) { return -1; }

    while (length > 0)
    {
        if (in_begin >= in_end)
        {
            in_begin = 0;
            in_end = fread(in_buffer, 1, in_buffer_size, stdin);
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
    if (fread(&length, sizeof(length), 1, NFILE) != 1) { return -1; }

    while (length > in_buffer_size)
    {
        fwrite(N_buffer, 1, in_buffer_size, stdout);
        length -= in_buffer_size;
    }

    fwrite(N_buffer, 1, length, stdout);

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
            if (!strcmp(argv[i], "--n")) { i++; nfile_path = argv[i]; continue; }
        }
        fprintf(stderr, "Unknown or incomplete argument \"%s\"\n", argv[i]);
    }
    if (nfile_path == NULL) { fputs("N file name is not specified\n", stderr); exit(1); }
    if (nfile_path[0] == '\0') { fputs("Empty N path specified\n", stderr); exit(1); }

    if (!freopen(NULL, "rb", stdin)) { fputs("Can't read input in binary mode\n", stderr); exit(1); }
    if (!freopen(NULL, "wb", stdout)) { fputs("Can't set output stream to binary mode\n", stderr); exit(1); }

    NFILE = fopen(nfile_path, "rb");
    if (NFILE == NULL) { fputs("Can't open N file\n", stderr); exit(1); }

    in_buffer = (unsigned char *) malloc(in_buffer_size);
    if (in_buffer == NULL) { fputs("Can't allocate memory\n", stderr); exit(1); }

    N_buffer = (unsigned char *) malloc(in_buffer_size);
    if (N_buffer == NULL) { fputs("Can't allocate memory\n", stderr); exit(1); }
    memset(N_buffer, 'N', in_buffer_size);

    process();

    return 0;
}
