/*
 * sequence-iupac-add
 * By Kirill Kryukov, 2019, public domain
 *
 * Usage: sequence-iupac-add --iupac IUPAC <IN >OUT
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>


static char *iupac_path = NULL;
static FILE *IUPAC = NULL;

#define in_buffer_size 16384
static unsigned char *in_buffer = NULL;
static size_t in_begin = 0;
static size_t in_end = 0;


static void done(void)
{
    if (IUPAC != NULL) { fclose(IUPAC); IUPAC = NULL; }
    if (in_buffer != NULL) { free(in_buffer); in_buffer = NULL; }
}


static void process(void)
{
    unsigned long long shift;
    unsigned char c;
    while (fread(&shift, sizeof(shift), 1, IUPAC) && fread(&c, sizeof(c), 1, IUPAC))
    {
        while (shift > 0)
        {
            if (in_begin >= in_end)
            {
                in_begin = 0;
                in_end = fread(in_buffer, 1, in_buffer_size, stdin);
                if (in_end == 0) { return; }
            }

            unsigned long long len1 = in_end - in_begin;
            if (len1 > shift) { len1 = shift; }

            fwrite(in_buffer + in_begin, 1, len1, stdout);

            shift -= len1;
            in_begin += len1;
        }

        fputc(c, stdout);
    }

    do
    {
        fwrite(in_buffer + in_begin, 1, in_end - in_begin, stdout);
        in_begin = 0;
        in_end = fread(in_buffer, 1, in_buffer_size, stdin);
    }
    while (in_end > 0);
}


int main(int argc, char **argv)
{
    atexit(done);

    for (int i = 1; i < argc; i++)
    {
        if (i < argc - 1)
        {
            if (!strcmp(argv[i], "--iupac")) { i++; iupac_path = argv[i]; continue; }
        }
        fprintf(stderr, "Unknown or incomplete argument \"%s\"\n", argv[i]);
    }
    if (iupac_path == NULL) { fputs("Iupac file name is not specified\n", stderr); exit(1); }
    if (iupac_path[0] == '\0') { fputs("Empty iupac path specified\n", stderr); exit(1); }

    if (!freopen(NULL, "rb", stdin)) { fputs("Can't read input in binary mode\n", stderr); exit(1); }
    if (!freopen(NULL, "wb", stdout)) { fputs("Can't set output stream to binary mode\n", stderr); exit(1); }

    IUPAC = fopen(iupac_path, "rb");
    if (IUPAC == NULL) { fputs("Can't open iupac file\n", stderr); exit(1); }

    in_buffer = (unsigned char *) malloc(in_buffer_size);
    if (in_buffer == NULL) { fputs("Can't allocate memory\n", stderr); exit(1); }

    process();

    return 0;
}
