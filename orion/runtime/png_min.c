/* png_min.c — minimal PNG loader for the atlas sprite path.
 *
 * #included from orion_rt.c (so it links into both the CLI runtime and the
 * native GPU build). Decodes an 8-bit PNG (grayscale / RGB / RGBA / gray+alpha
 * / palette) into a flat RGBA blob and returns it as a length-headered orion
 * Text: 8-byte header (width LE32, height LE32) followed by width*height*4
 * RGBA bytes. On any failure returns the empty text (len 0) so callers just
 * check the length. Self-contained DEFLATE (RFC 1951) — no zlib dependency.
 *
 * The engine has no GPU sampler; sprites are blitted as og_rects (one per
 * run of same-colour pixels). This loader is the CPU half of that, and being
 * pure computation it is fully testable headless.
 */

/* ---- DEFLATE (RFC 1951) inflate ------------------------------------ */
typedef struct {
    const unsigned char *src;
    size_t len, pos;
    unsigned int bitbuf;
    int bitcnt;
} PngBitR;

static int png_bit(PngBitR *b) {
    if (b->bitcnt == 0) {
        if (b->pos >= b->len) return -1;
        b->bitbuf = b->src[b->pos++];
        b->bitcnt = 8;
    }
    int r = b->bitbuf & 1;
    b->bitbuf >>= 1;
    b->bitcnt--;
    return r;
}

static int png_bits(PngBitR *b, int n) {
    int v = 0;
    for (int i = 0; i < n; i++) {
        int bit = png_bit(b);
        if (bit < 0) return -1;
        v |= bit << i;
    }
    return v;
}

typedef struct {
    unsigned short count[16];
    unsigned short sym[320];
} PngHuff;

static void png_huff_build(PngHuff *h, const unsigned char *lens, int n) {
    unsigned short offs[16];
    int i, sum = 0;
    for (i = 0; i < 16; i++) h->count[i] = 0;
    for (i = 0; i < n; i++) h->count[lens[i]]++;
    h->count[0] = 0;
    for (i = 0; i < 16; i++) { offs[i] = (unsigned short)sum; sum += h->count[i]; }
    for (i = 0; i < n; i++) if (lens[i]) h->sym[offs[lens[i]]++] = (unsigned short)i;
}

/* Canonical Huffman decode (puff-style: walk bit-by-bit). */
static int png_huff_decode(PngBitR *b, PngHuff *h) {
    int code = 0, first = 0, index = 0;
    for (int len = 1; len < 16; len++) {
        int bit = png_bit(b);
        if (bit < 0) return -1;
        code |= bit;
        int count = h->count[len];
        if (code - first < count) return h->sym[index + (code - first)];
        index += count;
        first += count;
        first <<= 1;
        code <<= 1;
    }
    return -1;
}

static const unsigned short PNG_LBASE[29] = {3,4,5,6,7,8,9,10,11,13,15,17,19,23,
    27,31,35,43,51,59,67,83,99,115,131,163,195,227,258};
static const unsigned char PNG_LEXT[29] = {0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,
    3,3,4,4,4,4,5,5,5,5,0};
static const unsigned short PNG_DBASE[30] = {1,2,3,4,5,7,9,13,17,25,33,49,65,97,
    129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577};
static const unsigned char PNG_DEXT[30] = {0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,
    8,8,9,9,10,10,11,11,12,12,13,13};

static int png_grow(unsigned char **o, size_t *cap, size_t need) {
    if (need <= *cap) return 1;
    size_t nc = *cap * 2;
    if (nc < need) nc = need + 256;
    unsigned char *t = (unsigned char *)realloc(*o, nc);
    if (!t) return 0;
    *o = t;
    *cap = nc;
    return 1;
}

static int png_inflate(const unsigned char *src, size_t slen,
                       unsigned char **out, size_t *outlen) {
    PngBitR b = {src, slen, 0, 0, 0};
    size_t cap = slen * 4 + 256, n = 0;
    unsigned char *o = (unsigned char *)malloc(cap);
    if (!o) return 0;
    int final = 0;
    do {
        final = png_bit(&b);
        if (final < 0) goto fail;
        int type = png_bits(&b, 2);
        if (type < 0) goto fail;
        if (type == 0) { /* stored */
            b.bitcnt = 0; /* align to byte boundary */
            if (b.pos + 4 > b.len) goto fail;
            int slen2 = src[b.pos] | (src[b.pos + 1] << 8);
            b.pos += 4;
            if (b.pos + (size_t)slen2 > b.len) goto fail;
            if (!png_grow(&o, &cap, n + slen2)) goto fail;
            memcpy(o + n, src + b.pos, slen2);
            n += slen2;
            b.pos += slen2;
        } else if (type == 1 || type == 2) {
            PngHuff lh, dh;
            if (type == 1) { /* fixed */
                unsigned char ll[288];
                int i;
                for (i = 0; i < 144; i++) ll[i] = 8;
                for (; i < 256; i++) ll[i] = 9;
                for (; i < 280; i++) ll[i] = 7;
                for (; i < 288; i++) ll[i] = 8;
                png_huff_build(&lh, ll, 288);
                unsigned char dl[30];
                for (i = 0; i < 30; i++) dl[i] = 5;
                png_huff_build(&dh, dl, 30);
            } else { /* dynamic */
                int hlit = png_bits(&b, 5) + 257;
                int hdist = png_bits(&b, 5) + 1;
                int hclen = png_bits(&b, 4) + 4;
                static const unsigned char ORD[19] = {16,17,18,0,8,7,9,6,10,5,11,
                    4,12,3,13,2,14,1,15};
                unsigned char cl[19] = {0};
                for (int i = 0; i < hclen; i++) {
                    int v = png_bits(&b, 3);
                    if (v < 0) goto fail;
                    cl[ORD[i]] = (unsigned char)v;
                }
                PngHuff ch;
                png_huff_build(&ch, cl, 19);
                unsigned char lens[288 + 30];
                memset(lens, 0, sizeof(lens));
                int i = 0, total = hlit + hdist;
                if (total > 288 + 30) goto fail;
                while (i < total) {
                    int sym = png_huff_decode(&b, &ch);
                    if (sym < 0) goto fail;
                    if (sym < 16) {
                        lens[i++] = (unsigned char)sym;
                    } else if (sym == 16) {
                        if (i == 0) goto fail;
                        int r = png_bits(&b, 2) + 3;
                        unsigned char prev = lens[i - 1];
                        while (r-- > 0 && i < total) lens[i++] = prev;
                    } else if (sym == 17) {
                        int r = png_bits(&b, 3) + 3;
                        while (r-- > 0 && i < total) lens[i++] = 0;
                    } else {
                        int r = png_bits(&b, 7) + 11;
                        while (r-- > 0 && i < total) lens[i++] = 0;
                    }
                }
                png_huff_build(&lh, lens, hlit);
                png_huff_build(&dh, lens + hlit, hdist);
            }
            for (;;) {
                int sym = png_huff_decode(&b, &lh);
                if (sym < 0) goto fail;
                if (sym == 256) break;
                if (sym < 256) {
                    if (!png_grow(&o, &cap, n + 1)) goto fail;
                    o[n++] = (unsigned char)sym;
                } else {
                    sym -= 257;
                    if (sym >= 29) goto fail;
                    int len = PNG_LBASE[sym] + png_bits(&b, PNG_LEXT[sym]);
                    int ds = png_huff_decode(&b, &dh);
                    if (ds < 0 || ds >= 30) goto fail;
                    int dist = PNG_DBASE[ds] + png_bits(&b, PNG_DEXT[ds]);
                    if ((size_t)dist > n) goto fail;
                    if (!png_grow(&o, &cap, n + len)) goto fail;
                    for (int k = 0; k < len; k++) { o[n] = o[n - dist]; n++; }
                }
            }
        } else {
            goto fail;
        }
    } while (!final);
    *out = o;
    *outlen = n;
    return 1;
fail:
    free(o);
    return 0;
}

/* ---- PNG container -------------------------------------------------- */
static unsigned int png_be32(const unsigned char *p) {
    return ((unsigned int)p[0] << 24) | ((unsigned int)p[1] << 16) |
           ((unsigned int)p[2] << 8) | (unsigned int)p[3];
}

static int png_abs(int v) { return v < 0 ? -v : v; }

/* host_image_load(path) -> Text: [w LE32][h LE32][RGBA...], or empty on fail. */
const char *host_image_load(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) return orion_text_empty();
    fseek(f, 0, SEEK_END);
    long fsz = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (fsz < 8) { fclose(f); return orion_text_empty(); }
    unsigned char *buf = (unsigned char *)malloc((size_t)fsz);
    if (!buf) { fclose(f); return orion_text_empty(); }
    if (fread(buf, 1, (size_t)fsz, f) != (size_t)fsz) {
        fclose(f); free(buf); return orion_text_empty();
    }
    fclose(f);
    static const unsigned char SIG[8] = {137,80,78,71,13,10,26,10};
    if (memcmp(buf, SIG, 8) != 0) { free(buf); return orion_text_empty(); }

    unsigned int w = 0, h = 0;
    int bitdepth = 0, colortype = 0;
    unsigned char *idat = NULL;
    size_t idatlen = 0, idatcap = 0;
    unsigned char plte[256 * 3];
    int plte_n = 0;
    unsigned char trns[256];
    int trns_n = 0;
    size_t p = 8;
    while (p + 8 <= (size_t)fsz) {
        unsigned int clen = png_be32(buf + p);
        const unsigned char *ctype = buf + p + 4;
        const unsigned char *cdata = buf + p + 8;
        if (p + 12 + (size_t)clen > (size_t)fsz) break;
        if (memcmp(ctype, "IHDR", 4) == 0 && clen >= 10) {
            w = png_be32(cdata);
            h = png_be32(cdata + 4);
            bitdepth = cdata[8];
            colortype = cdata[9];
        } else if (memcmp(ctype, "PLTE", 4) == 0) {
            plte_n = (int)(clen / 3);
            if (plte_n > 256) plte_n = 256;
            memcpy(plte, cdata, (size_t)plte_n * 3);
        } else if (memcmp(ctype, "tRNS", 4) == 0) {
            trns_n = (int)clen;
            if (trns_n > 256) trns_n = 256;
            memcpy(trns, cdata, (size_t)trns_n);
        } else if (memcmp(ctype, "IDAT", 4) == 0) {
            if (idatlen + clen > idatcap) {
                idatcap = (idatlen + clen) * 2 + 64;
                idat = (unsigned char *)realloc(idat, idatcap);
                if (!idat) { free(buf); return orion_text_empty(); }
            }
            memcpy(idat + idatlen, cdata, clen);
            idatlen += clen;
        } else if (memcmp(ctype, "IEND", 4) == 0) {
            break;
        }
        p += 12 + (size_t)clen;
    }
    /* 8-bit depth only for now (covers Aseprite RGBA + most exports). */
    if (!w || !h || !idat || bitdepth != 8) {
        free(buf); free(idat); return orion_text_empty();
    }
    int ch = colortype == 2 ? 3 : colortype == 6 ? 4 : colortype == 0 ? 1 :
             colortype == 4 ? 2 : colortype == 3 ? 1 : 0;
    if (ch == 0) { free(buf); free(idat); return orion_text_empty(); }

    unsigned char *raw = NULL;
    size_t rawlen = 0;
    /* skip the 2-byte zlib header */
    if (idatlen < 2 || !png_inflate(idat + 2, idatlen - 2, &raw, &rawlen)) {
        free(buf); free(idat); return orion_text_empty();
    }
    free(idat);
    size_t stride = (size_t)w * ch;
    if (rawlen < (size_t)h * (1 + stride)) {
        free(buf); free(raw); return orion_text_empty();
    }
    unsigned char *px = (unsigned char *)malloc((size_t)h * stride);
    if (!px) { free(buf); free(raw); return orion_text_empty(); }
    for (unsigned int y = 0; y < h; y++) {
        unsigned char ft = raw[(size_t)y * (1 + stride)];
        unsigned char *row = raw + (size_t)y * (1 + stride) + 1;
        unsigned char *out = px + (size_t)y * stride;
        unsigned char *prev = y ? px + (size_t)(y - 1) * stride : NULL;
        for (size_t x = 0; x < stride; x++) {
            int a = x >= (size_t)ch ? out[x - ch] : 0;
            int bb = prev ? prev[x] : 0;
            int c = (prev && x >= (size_t)ch) ? prev[x - ch] : 0;
            int val = row[x], r;
            if (ft == 1) r = val + a;
            else if (ft == 2) r = val + bb;
            else if (ft == 3) r = val + ((a + bb) >> 1);
            else if (ft == 4) {
                int pp = a + bb - c;
                int pa = png_abs(pp - a), pb = png_abs(pp - bb), pc = png_abs(pp - c);
                int pred = (pa <= pb && pa <= pc) ? a : (pb <= pc ? bb : c);
                r = val + pred;
            } else r = val;
            out[x] = (unsigned char)r;
        }
    }
    free(raw);

    long long total = 8 + (long long)w * h * 4;
    char *blob = orion_text_alloc(total);
    unsigned char *o = (unsigned char *)blob;
    o[0] = w & 255; o[1] = (w >> 8) & 255; o[2] = (w >> 16) & 255; o[3] = (w >> 24) & 255;
    o[4] = h & 255; o[5] = (h >> 8) & 255; o[6] = (h >> 16) & 255; o[7] = (h >> 24) & 255;
    unsigned char *dst = o + 8;
    for (unsigned int y = 0; y < h; y++) {
        for (unsigned int x = 0; x < w; x++) {
            unsigned char *s = px + (size_t)y * stride + (size_t)x * ch;
            unsigned char R, G, B, A;
            if (colortype == 6) { R = s[0]; G = s[1]; B = s[2]; A = s[3]; }
            else if (colortype == 2) { R = s[0]; G = s[1]; B = s[2]; A = 255; }
            else if (colortype == 0) { R = G = B = s[0]; A = 255; }
            else if (colortype == 4) { R = G = B = s[0]; A = s[1]; }
            else { int idx = s[0]; R = plte[idx*3]; G = plte[idx*3+1]; B = plte[idx*3+2];
                   A = idx < trns_n ? trns[idx] : 255; }
            size_t d = ((size_t)y * w + x) * 4;
            dst[d] = R; dst[d+1] = G; dst[d+2] = B; dst[d+3] = A;
        }
    }
    free(px);
    free(buf);
    return blob;
}
