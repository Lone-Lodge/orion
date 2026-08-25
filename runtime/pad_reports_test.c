/* Push known reports through the real decoder - the same file the program
 * uses - and say whether the virtual pad came out right. This is how the
 * mapping stays honest without the hardware on the desk, and the only way a
 * fifth report shape can be added without breaking the four that work.
 *
 *     clang -I runtime -o padtest.exe runtime/pad_reports_test.c -luser32 -lgdi32
 *     ./padtest.exe
 */
/* The stub the file expects from the orion runtime; nothing here calls it. */
const char *orion_text_from_c(const char *s);
const char *orion_text_from_c(const char *s) { return s; }
#include "win32_min.c"
#include <stdio.h>

static int fails;

static void want(const char *what, long long got, long long expect) {
    if (got != expect) { printf("  FEL  %-28s fick %lld, ville ha %lld\n", what, got, expect); fails++; }
    else printf("  ok   %-28s %lld\n", what, got);
}

static void try_report(const char *name, unsigned char *r, int len) {
    Pad p;
    memset(&p, 0, sizeof p);
    p.kind = 2;
    printf("%s\n", name);
    pad_from_sony(&p, r, len);
    want("kryss (south)", (p.down >> PAD_SOUTH) & 1, 1);
    want("cirkel (east)", (p.down >> PAD_EAST) & 1, 0);
    want("hatt: vanster", (p.down >> PAD_LEFT) & 1, 1);
    want("l1", (p.down >> PAD_L1) & 1, 1);
    want("start (options)", (p.down >> PAD_START) & 1, 1);
    want("lx at hoger", p.axis[0] > 800, 1);
    want("ly i mitten", p.axis[1], 0);
    want("r2 i botten", p.axis[5] > 900, 1);
}

int main(void) {
    /* Held: cross, d-pad left, L1, options. Left stick hard right, R2 down. */
    unsigned char b0 = 0x20 | 6;    /* cross + hat 6 = left */
    unsigned char b1 = 0x01 | 0x20; /* L1 + options */

    unsigned char bt[10];           /* DualSense, simple Bluetooth mode */
    memset(bt, 0x80, sizeof bt);
    bt[0] = 0x01; bt[1] = 255; bt[2] = 128; bt[3] = 128; bt[4] = 128;
    bt[5] = b0; bt[6] = b1; bt[7] = 0; bt[8] = 0; bt[9] = 255;
    try_report("DualSense, enkelt Bluetooth-lage (10 byte)", bt, 10);

    unsigned char full[64];         /* DualSense over Bluetooth, report 0x31 */
    memset(full, 0, sizeof full);
    full[0] = 0x31; full[1] = 7;
    full[2] = 255; full[3] = 128; full[4] = 128; full[5] = 128;
    full[6] = 0; full[7] = 255;
    full[9] = b0; full[10] = b1;
    try_report("DualSense over Bluetooth (0x31, 64 byte)", full, 64);

    unsigned char usb[64];          /* DualSense over the cable */
    memset(usb, 0, sizeof usb);
    usb[0] = 0x01;
    usb[1] = 255; usb[2] = 128; usb[3] = 128; usb[4] = 128;
    usb[5] = 0; usb[6] = 255;
    usb[8] = b0; usb[9] = b1;
    try_report("DualSense over sladd (0x01, 64 byte)", usb, 64);

    unsigned char ds4[10];          /* DualShock 4 over the cable */
    memset(ds4, 0, sizeof ds4);
    ds4[0] = 0x01;
    ds4[1] = 255; ds4[2] = 128; ds4[3] = 128; ds4[4] = 128;
    ds4[5] = b0; ds4[6] = b1; ds4[8] = 0; ds4[9] = 255;
    try_report("DualShock 4 over sladd (0x01, 10 byte)", ds4, 10);

    printf(fails ? "\n%d fel\n" : "\nallt stammer\n", fails);
    return fails ? 1 : 0;
}
