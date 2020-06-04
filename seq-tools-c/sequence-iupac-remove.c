/*
 * sequence-iupac-remove
 * By Kirill Kryukov, 2019, public domain
 *
 * Usage: sequence-iupac-remove --iupac IUPAC <IN >OUT
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>


static char *iupac_path = NULL;
static FILE *IUPAC = NULL;

#define in_buffer_size 16384
static unsigned char *in_buffer = NULL;
static size_t in_begin = 0;
static size_t in_end = 0;

static bool is_iupac_arr[256];

static unsigned long long shift = 0ull;


static void done(void)
{
    if (IUPAC != NULL) { fclose(IUPAC); IUPAC = NULL; }
    if (in_buffer != NULL) { free(in_buffer); in_buffer = NULL; }
}


static void init_tables(void)
{
    memset(is_iupac_arr, 0, sizeof(is_iupac_arr));

    is_iupac_arr['R'] = true;
    is_iupac_arr['Y'] = true;
    is_iupac_arr['S'] = true;
    is_iupac_arr['W'] = true;
    is_iupac_arr['K'] = true;
    is_iupac_arr['M'] = true;
    is_iupac_arr['B'] = true;
    is_iupac_arr['D'] = true;
    is_iupac_arr['H'] = true;
    is_iupac_arr['V'] = true;
}


static void process(void)
{
    do
    {
        in_begin = 0;
        in_end = fread(in_buffer, 1, in_buffer_size, stdin);

        for (size_t i = 0; i < in_end; i++)
        {
            if (is_iupac_arr[in_buffer[i]])
            {
                fwrite(in_buffer + in_begin, 1, i - in_begin, stdout);

                shift += i - in_begin;
                fwrite(&shift, sizeof(shift), 1, IUPAC);
                fputc(in_buffer[i], IUPAC);

                shift = 0ull;
                in_begin = i + 1;
            }
        }

        shift += in_end - in_begin;
        fwrite(in_buffer + in_begin, 1, in_end - in_begin, stdout);
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

    IUPAC = fopen(iupac_path, "wb");
    if (IUPAC == NULL) { fputs("Can't create iupac file\n", stderr); exit(1); }

    in_buffer = (unsigned char *) malloc(in_buffer_size);
    if (in_buffer == NULL) { fputs("Can't allocate memory\n", stderr); exit(1); }

    init_tables();
    process();

    return 0;
}
