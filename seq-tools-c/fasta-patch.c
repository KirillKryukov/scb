/*
 * fasta-patch
 * by Kirill Kryukov, 2019, public domain
 *
 * Usage: fasta-patch --diff DIFF <INPUT >OUTPUT
 */

#define NDEBUG

#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>


static char *diff_path = NULL;
static FILE *DIFF = NULL;

#define buffer_size 16384
static unsigned char *buffer = NULL;
static size_t buffer_fill = 0;

static unsigned long long buffer_start_pos = 0;
static unsigned long long buffer_end_pos = 0;

static unsigned char diff_entry[9];
static unsigned long long rep_pos = 0;


#define FREE(p) \
do { if ((p) != NULL) { free(p); (p) = NULL; } } while (0)


static void done(void)
{
    if (DIFF != NULL) { fclose(DIFF); DIFF = 0; }
    FREE(buffer);
}


__attribute__((always_inline))
static inline size_t refill_buffer(void)
{
    assert(buffer != NULL);

    buffer_fill = fread(buffer, 1, buffer_size, stdin);
    buffer_start_pos = buffer_end_pos;
    buffer_end_pos += buffer_fill;
    return buffer_fill;
}


__attribute__((always_inline))
static inline unsigned long long read_number(void)
{
    unsigned long long a = 0;
    unsigned char c;

    if (!fread(&c, 1, 1, DIFF)) { return 0xFFFFFFFFFFFFFFFFull; }
    if (c == 128) { return 0xFFFFFFFFFFFFFFFFull; }

    while (c & 128)
    {
        if (a & (127ull << 57)) { return 0xFFFFFFFFFFFFFFFFull; }
        a = (a << 7) | (c & 127);
        if (!fread(&c, 1, 1, DIFF)) { return 0xFFFFFFFFFFFFFFFFull; }
    }

    if (a & (127ull << 57)) { return 0xFFFFFFFFFFFFFFFFull; }
    a = (a << 7) | c;

    return a;
}


__attribute__((always_inline))
static inline void read_diff_entry(void)
{
    //if (fread(diff_entry, 9, 1, DIFF) == 1) { rep_pos += *(unsigned long long *)diff_entry; }
    //else { rep_pos = 0xFFFFFFFFFFFFFFFFull; }

    unsigned long long n = read_number();

    if (n == 0xFFFFFFFFFFFFFFFFull)
    {
        rep_pos = 0xFFFFFFFFFFFFFFFFull;
    }
    else
    {
        if (fread(&diff_entry[8], 1, 1, DIFF) == 1) { rep_pos += n; }
        else { rep_pos = 0xFFFFFFFFFFFFFFFFull; }
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
    if (diff_path == NULL) { fputs("Diff file is not specified\n", stderr); exit(1); }
    if (diff_path[0] == '\0') { fputs("Empty diff path specified\n", stderr); exit(1); }

    if (!freopen(NULL, "rb", stdin)) { fputs("Can't read input in binary mode\n", stderr); exit(1); }
    if (!freopen(NULL, "wb", stdout)) { fputs("Can't set output stream to binary mode\n", stderr); exit(1); }
    DIFF = fopen(diff_path, "rb");
    if (DIFF == NULL) { fputs("Can't open diff file\n", stderr); exit(1); }

    buffer = (unsigned char *) malloc(buffer_size);

    read_diff_entry();
    while (refill_buffer() > 0)
    {
        while (rep_pos < buffer_end_pos)
        {
            buffer[rep_pos - buffer_start_pos] = diff_entry[8];
            read_diff_entry();
        }

        fwrite(buffer, 1, buffer_fill, stdout);
    }

    return 0;
}
