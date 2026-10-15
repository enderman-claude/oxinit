/* Checks for memeunit_pick. Built and run by `make -C memeunit test`. */
#include <stdio.h>
#include <string.h>
#include "memeunit.c"

static int fails = 0;
#define CHECK(desc, cond) do { \
    if (cond) printf("  PASS  %s\n", desc); \
    else { printf("  FAIL  %s\n", desc); fails++; } \
} while (0)

static int is_species_line(const char *line, const struct species_set *sp, int k) {
    for (int n = 0; n < N_SPECIES_LINES; n++)
        if (strcmp(line, sp->lines[k][n]) == 0) return 1;
    return 0;
}

static int is_generic_line(const char *line, int k) {
    for (int n = 0; n < N_GENERIC; n++)
        if (strcmp(line, table[k].lines[n]) == 0) return 1;
    return 0;
}

int main(void) {
    const char *p1 = memeunit_pick("start", "web|CHILL", "Protogen");
    const char *p2 = memeunit_pick("start", "web|CHILL", "Protogen");
    CHECK("same seed and species gives the same line", strcmp(p1, p2) == 0);

    const struct species_set *proto = find_species("Protogen");
    CHECK("protogen species is recognised", proto != NULL && proto == &species_table[0]);
    CHECK("protogen picks a protogen line", is_species_line(p1, proto, 0));

    CHECK("'protogen-ish' also matches", find_species("protogen-ish") == &species_table[0]);
    CHECK("'PROTO' matches case-insensitively", find_species("PROTO") == &species_table[0]);
    CHECK("'wolf' is recognised", find_species("wolf") == &species_table[1]);
    CHECK("'fox' is recognised", find_species("fox") == &species_table[2]);
    CHECK("'dragon' is recognised", find_species("dragon") == &species_table[3]);
    CHECK("unknown species is not recognised", find_species("sheep") == NULL);
    CHECK("empty species is not recognised", find_species("") == NULL);
    CHECK("NULL species is not recognised", find_species(NULL) == NULL);

    const char *g = memeunit_pick("exit", "web|CHILL", "sheep");
    CHECK("unknown species uses the generic pool", is_generic_line(g, 1));

    const char *ng = memeunit_pick("exit", "web|CHILL", "");
    CHECK("non-furry service uses the generic pool", is_generic_line(ng, 1));

    int all_species = 1;
    for (int k = 0; k < N_KINDS; k++) {
        const char *s = memeunit_pick(table[k].key, "svc|SUS", "wolf");
        if (!is_species_line(s, &species_table[1], k)) all_species = 0;
    }
    CHECK("every kind has a wolf line", all_species);

    CHECK("unknown kind returns empty", strcmp(memeunit_pick("nope", "x", ""), "") == 0);

    printf("%s\n", fails ? "memeunit tests FAILED" : "memeunit tests passed");
    return fails ? 1 : 0;
}
