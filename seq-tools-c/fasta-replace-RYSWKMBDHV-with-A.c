/*
 * fasta-replace-RYSWKMBDHV-with-A
 * By Kirill Kryukov, 2019, public domain
 *
 * Usage: fasta-replace-RYSWKMBDHV-with-A --diff DIFF <INPUT >OUTPUT
 */

#define NDEBUG

#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>


static char *diff_path = NULL;
static FILE *DIFF = NULL;

#define in_buffer_size 16384
static unsigned char *in_buffer = NULL;
static size_t in_begin = 0;
static size_t in_end = 0;

static bool is_space_arr[256];
static bool is_eol_arr[256];
static bool is_iupac_arr[256];

static unsigned long long prev_pos = 0;
static unsigned long long buffer_start_pos = 0;


#define FREE(p) \
do { if ((p) != NULL) { free(p); (p) = NULL; } } while (0)


static void done(void)
{
    if (DIFF != NULL) { fclose(DIFF); DIFF = 0; }
    FREE(in_buffer);
}


static void init_tables(void)
{
    memset(is_space_arr, 0, sizeof(is_space_arr));
    memset(is_eol_arr, 0, sizeof(is_eol_arr));
    memset(is_iupac_arr, 0, sizeof(is_iupac_arr));

    is_space_arr['\t'] = true;
    is_space_arr['\n'] = true;
    is_space_arr['\v'] = true;
    is_space_arr['\f'] = true;
    is_space_arr['\r'] = true;
    is_space_arr[' '] = true;

    is_eol_arr['\n'] = true;
    is_eol_arr['\f'] = true;
    is_eol_arr['\r'] = true;

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

    is_iupac_arr['r'] = true;
    is_iupac_arr['y'] = true;
    is_iupac_arr['s'] = true;
    is_iupac_arr['w'] = true;
    is_iupac_arr['k'] = true;
    is_iupac_arr['m'] = true;
    is_iupac_arr['b'] = true;
    is_iupac_arr['d'] = true;
    is_iupac_arr['h'] = true;
    is_iupac_arr['v'] = true;
}


static void write_variable_length_encoded_number(FILE *F, unsigned long long a)
{
    assert(F != NULL);

    unsigned char vle_buffer[10];
    unsigned char *b = vle_buffer + 10;
    *--b = (unsigned char)(a & 127ull);
    a >>= 7;
    while (a > 0)
    {
        *--b = (unsigned char)(128ull | (a & 127ull));
        a >>= 7;
    }
    size_t len = (size_t)(vle_buffer + 10 - b);
    fwrite(b, 1, len, F);
}


__attribute__((always_inline))
static inline void refill_in_buffer(void)
{
    assert(in_buffer != NULL);

    buffer_start_pos += in_end;
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
static inline int skip_until(bool *delim_arr)
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
            if (delim_arr[in_buffer[i]]) { c = in_buffer[i]; break; }
        }

        if (i == in_end) { i--; }
        fwrite(in_buffer + in_begin, 1, i - in_begin + 1, stdout);
        in_begin = i + 1;
        if (c >= 0) { break; }
    }

    return c;
}


__attribute__((always_inline))
static inline int process_until_next_seq(void)
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
            if (is_iupac_arr[in_buffer[i]])
            {
                if (DIFF != NULL)
                {
                    unsigned long long pos = buffer_start_pos + i;

                    /*unsigned char t[9];
                    *(unsigned long long *)t = pos - prev_pos;
                    t[8] = in_buffer[i];
                    fwrite(t, 9, 1, DIFF);*/

                    write_variable_length_encoded_number(DIFF, pos - prev_pos);
                    fwrite(in_buffer + i, 1, 1, DIFF);

                    prev_pos = pos;
                }
                in_buffer[i] = (in_buffer[i] >= 96) ? 'a' : 'A';
            }
            else if (in_buffer[i] == '>') { c = in_buffer[i]; break; }
        }

        if (i == in_end) { i--; }
        fwrite(in_buffer + in_begin, 1, i - in_begin + 1, stdout);
        in_begin = i + 1;
        if (c >= 0) { break; }
    }

    return c;
}


__attribute__((always_inline))
static inline int process_one_seq(void)
{
    int c = skip_until(is_eol_arr);
    if (c == -1) { return c; }
    return process_until_next_seq();
}


static void process(void)
{
    int c;
    while ((c = in_get_char()) != -1 && is_space_arr[c]) { fputc(c, stdout); }
    if (c == -1) { return; }
    if (c != '>') { fputs("Input is not in FASTA format\n", stderr); exit(1); }
    fputc(c, stdout);

    for (;;)
    {
        if (process_one_seq() == -1) { break; }
    }
}


int main(int argc, char **argv)
{
    atexit(done);

    for (int i = 1; i < argc; i++)
    {
        if (i < argc - 1)
        {
            if (!strcmp(argv[i], "--diff")) { i++; diff_path = argv[i]; continue; }
        }
        fprintf(stderr, "Unknown or incomplete argument \"%s\"\n", argv[i]);
    }
    if (diff_path != NULL && diff_path[0] == '\0') { fputs("Empty diff path specified\n", stderr); exit(1); }

    if (!freopen(NULL, "rb", stdin)) { fputs("Can't read input in binary mode\n", stderr); exit(1); }
    if (!freopen(NULL, "wb", stdout)) { fputs("Can't set output stream to binary mode\n", stderr); exit(1); }
    if (diff_path != NULL)
    {
        DIFF = fopen(diff_path, "wb");
        if (DIFF == NULL) { fputs("Can't create diff file\n", stderr); exit(1); }
    }
    in_buffer = (unsigned char *) malloc(in_buffer_size);
    init_tables();

    process();

    return 0;
}
