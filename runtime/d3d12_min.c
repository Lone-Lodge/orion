/* d3d12_min.c - minimal D3D12 renderer for native Orion.
 *
 * Same philosophy as win32_min.c: one C file, raw OS API, no
 * middleware. Colored 2D rects only - exactly what cubsy's
 * DisplayList needs. ~450 lines replaces lodge-orion's gpu.rs + wgpu
 * dependency chain.
 *
 * CORRECT frame model (unlike gpu.rs's per-draw-submit):
 *   og_begin(r,g,b)          reset frame, remember clear color
 *   og_rect(x,y,w,h,r,g,b)   append 6 verts (pixel coords, 0-255 col)
 *   og_present()             record ONE command list: barrier, clear,
 *                             draw all, barrier, execute, present,
 *                             fence-wait (full sync - correct first,
 *                             overlap later)
 *
 * All-i64 extern API (colors 0-255, coords in pixels).
 */

#define WIN32_LEAN_AND_MEAN
#define COBJMACROS
#define INITGUID
#include <windows.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include <dxgi1_5.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define FRAME_COUNT 2
#define MAX_VERTS 65536           /* 10922 rects/frame - plenty for 2D */

typedef struct { float x, y, r, g, b, a; } Vert;

static ID3D12Device        *g_dev;
static ID3D12CommandQueue  *g_queue;
/* Everything that belongs to ONE window.
 *
 * The device, queue, command list, pipelines, textures and vertex rings
 * are shared - they are properties of the adapter, not of a window. The
 * swapchain and what hangs off it are not, which is why this used to be a
 * single global set: opening a second window re-inited over the first and
 * the first went white. */
#define MAX_TARGETS 4
typedef struct {
    IDXGISwapChain3       *swap;
    ID3D12DescriptorHeap  *rtv_heap;
    ID3D12Resource        *backbuf[FRAME_COUNT];
    ID3D12CommandAllocator *alloc[FRAME_COUNT];  /* one per in-flight frame */
    UINT64                 frame_fence[FRAME_COUNT]; /* last submit per slot */
    int                    width, height;
    int                    frame;                /* current backbuffer slot */
    float                  clear[4];
    int                    live;
} Target;

static Target  g_target[MAX_TARGETS];
static int     g_ntargets;
static Target *T;         /* the one between og_begin and og_present */
static int     g_cur;     /* its index, for the per-target ring slot */
static ID3D12GraphicsCommandList *g_list;
static ID3D12RootSignature *g_rootsig;
static ID3D12PipelineState *g_pso;
static ID3D12Resource      *g_vbuf;      /* upload ring: FRAME_COUNT slots */
static Vert                *g_vmap;      /* persistently mapped */
static Vert                 g_stage[MAX_VERTS]; /* cached-RAM build buffer */
static ID3D12Fence         *g_fence;
static HANDLE               g_fence_evt;
static UINT64               g_fence_val;
static UINT                 g_rtv_size;
static int                  g_nverts;
static int                  g_dropped;         /* verts dropped this frame (budget hit) */
static int                  g_calls;           /* draw calls issued this frame */
static int                  g_calls_peak;
static int                  g_overflow_warned; /* one-shot budget-exceeded notice */
static int                  g_vsync = 0; /* uncapped by default; og_vsync opts in */
static int                  g_tearing = 0;

/* ---- textured sprite pipeline (modern 2D: blend, tint, clip, scale) ----
 * Rects can't show an image without a rect-per-pixel; a texture draws the
 * whole image as ONE quad the GPU samples. This adds: texture upload (cached
 * by path), a shader-visible SRV heap, a textured PSO per blend mode (alpha,
 * additive), a POINT static sampler (crisp pixel art), per-sprite tint +
 * source sub-rect (atlas) + scale, and a scissor clip. Shaders are compiled
 * at runtime via a dynamically-loaded d3dcompiler (no build-script change;
 * if it is missing, sprites disable and rects still work). */
#define MAX_TEX     2048  /* images + one per (glyph,size); tiny glyph textures */
#define MAX_SPRITES 8192
/* pos, uv, tint - plus the shape a rounded rect needs. Sprites leave the
 * last four alone; the textured pipeline never declares them. Carrying the
 * shape per-vertex rather than in root constants is what lets quads of
 * DIFFERENT sizes share one draw call, which matters because a particle
 * field is a few hundred rounded rects that are all different. */
typedef struct {
    float x, y, u, v, r, g, b, a;
    float hw, hh, rad, pad;
    /* An arc's own shape: inner radius, the two angles it spans, and a
     * flag that tells the shader to read them at all. A ring drawn as a
     * shape rather than as a fan of triangles gets the same smooth edge
     * the rounded corners have, and rides the same one draw call. */
    float k0, k1, k2, k3;
} TexVert;
/* `at_vert` is how many solid verts had been recorded when this sprite was
 * submitted. It is what lets present replay BOTH streams in the order the
 * caller actually issued them - without it every textured quad (which
 * includes all anti-aliased text) drew after every rect, so no panel could
 * ever cover a label. */
/* One entry in the ordered draw stream. `kind` 0 is a textured sprite;
 * kind 1 is a rounded rect evaluated by a signed distance function in the
 * pixel shader, which is the only way to get a smooth corner - spans on
 * the CPU can only ever step a whole pixel at a time. hw/hh/rad are the
 * half-size and corner radius in pixels, pushed as root constants. */
typedef struct {
    int tex; int blend; int cx, cy, cw, ch; int clip; int crad; int at_vert;
    int kind; float hw, hh, rad, soft;
} SpriteDraw;

static ID3D12DescriptorHeap *g_srv_heap;   /* shader-visible SRV table */
static UINT                  g_srv_size;
static ID3D12Resource       *g_tex[MAX_TEX];
static int                   g_tex_w[MAX_TEX], g_tex_h[MAX_TEX];
static char                 *g_tex_path[MAX_TEX]; /* path-keyed (images) */
static long long             g_tex_key[MAX_TEX];  /* int-keyed (glyphs), -1 = none */
/* Glyphs live in ONE atlas, not one texture each. A texture per (glyph,
 * size) meant thousands of committed resources and descriptors, a hard cap
 * at MAX_TEX, and - because every sprite bound its own descriptor table -
 * one draw call per glyph. Sharing a texture lets a run of glyphs collapse
 * into a single draw, and it is what makes sub-pixel phases affordable at
 * all: three phases per glyph would have blown the old budget outright. */
#define ATLAS_DIM 2048
static ID3D12Resource       *g_atlas;
static int                   g_atlas_slot = -1;  /* its SRV index */
static int                   g_shelf_x, g_shelf_y, g_shelf_h;
static int                   g_in_atlas[MAX_TEX];       /* 1 = packed */
static int                   g_tex_ax[MAX_TEX], g_tex_ay[MAX_TEX];
static int                   g_tex_n;
static ID3D12RootSignature  *g_tex_rootsig;
static ID3D12PipelineState  *g_pso_alpha;   /* SRC_ALPHA / INV_SRC_ALPHA */
static ID3D12PipelineState  *g_pso_add;     /* SRC_ALPHA / ONE (glow) */
static ID3D12RootSignature  *g_quad_rootsig;
static ID3D12PipelineState  *g_pso_quad;    /* rounded rects, SDF-shaded */
static void quad_pipeline_init(void);
static void atlas_init(void);
static ID3D12Resource       *g_tvbuf;       /* upload ring for tex verts */
static TexVert              *g_tvmap;
static TexVert               g_tstage[MAX_SPRITES * 6];
static SpriteDraw            g_sprites[MAX_SPRITES];
static int                   g_nsprites;
static ID3D12CommandAllocator *g_up_alloc;  /* dedicated for synchronous uploads */
static ID3D12GraphicsCommandList *g_up_list;
static int                   g_tex_ok;      /* pipeline built? */
static int                   g_clip_x, g_clip_y, g_clip_w, g_clip_h, g_clip_on;
/* A clip with a CORNER. A scissor is a rectangle and always will be, so a
 * rounded one is finished in the pixel shader: the same distance function
 * the rounded rects are drawn with, applied to the clip instead of to the
 * shape. Without it a list inside a rounded panel squares off at the
 * corners, which is the one place every card and every avatar shows it. */
static int                   g_clip_rad;

/* host-side PNG decoder (orion_rt.c): returns [w LE32][h LE32][RGBA...]. */
extern const char *host_image_load(const char *path);
extern void host_image_free_cached(const char *path);
extern long long orion_tlen_c(const char *p);
static void tex_pipeline_init(void); /* defined below; called from init */
static void draw_in_order(UINT ring);   /* defined below; called from present */

/* Shaders precompiled to DXBC at build time (fxc, see tools/shaders) -
 * no d3dcompiler DLL at runtime: fewer deps, faster cold start. */
#include "vs_dxbc.h"
#include "ps_dxbc.h"

static void fence_sync(void) {
    g_fence_val++;
    ID3D12CommandQueue_Signal(g_queue, g_fence, g_fence_val);
    if (ID3D12Fence_GetCompletedValue(g_fence) < g_fence_val) {
        ID3D12Fence_SetEventOnCompletion(g_fence, g_fence_val, g_fence_evt);
        WaitForSingleObject(g_fence_evt, INFINITE);
    }
}

/* Returns a TARGET HANDLE (1-based; 0 = failed), not a boolean. The first
 * call also builds everything shared - device, queue, command list,
 * pipelines, vertex rings, fence - and later calls only add a swapchain. */
long long dx_og_init(long long hwnd_i, long long width, long long height) {
    HWND hwnd = (HWND)(uintptr_t)hwnd_i;
    if (g_ntargets >= MAX_TARGETS) {
        fprintf(stderr, "[d3d12] too many windows (max %d)\n", MAX_TARGETS);
        return 0;
    }
    int first = (g_dev == NULL);
    g_cur = g_ntargets;
    T = &g_target[g_cur];
    memset(T, 0, sizeof *T);
    T->width = (int)width;
    T->height = (int)height;

    /* Pick a REAL adapter: the default can be a BMC/software device
     * (ASPEED on server boards) and everything silently runs at
     * software speed. Enumerate, skip software-flagged adapters,
     * take the first that creates a device. */
    if (first) {
        IDXGIFactory4 *f = NULL;
        if (SUCCEEDED(CreateDXGIFactory1(&IID_IDXGIFactory4, (void **)&f))) {
            IDXGIAdapter1 *ad = NULL;
            for (UINT i = 0;
                 IDXGIFactory4_EnumAdapters1(f, i, &ad) != DXGI_ERROR_NOT_FOUND;
                 i++) {
                DXGI_ADAPTER_DESC1 desc;
                IDXGIAdapter1_GetDesc1(ad, &desc);
                if (!(desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) &&
                    SUCCEEDED(D3D12CreateDevice((IUnknown *)ad,
                              D3D_FEATURE_LEVEL_11_0, &IID_ID3D12Device,
                              (void **)&g_dev))) {
                    fprintf(stderr, "[d3d12] adapter: %ls (%lluMB)\n",
                            desc.Description,
                            (unsigned long long)(desc.DedicatedVideoMemory /
                                                 (1024 * 1024)));
                    IDXGIAdapter1_Release(ad);
                    break;
                }
                IDXGIAdapter1_Release(ad);
                ad = NULL;
            }
            IDXGIFactory4_Release(f);
        }
    }
    if (!g_dev && FAILED(D3D12CreateDevice(NULL, D3D_FEATURE_LEVEL_11_0,
                                           &IID_ID3D12Device, (void **)&g_dev)))
        return 0;

    if (first) {
        D3D12_COMMAND_QUEUE_DESC qd = {0};
        qd.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
        if (FAILED(ID3D12Device_CreateCommandQueue(g_dev, &qd,
                   &IID_ID3D12CommandQueue, (void **)&g_queue)))
            return 0;
    }

    IDXGIFactory4 *factory;
    if (FAILED(CreateDXGIFactory1(&IID_IDXGIFactory4, (void **)&factory)))
        return 0;
    /* Tearing support = uncapped present on flip-model. Queried via
     * IDXGIFactory5; absent (old Win10) we still run, just without
     * the unlocked rate. */
    {
        IDXGIFactory5 *f5 = NULL;
        if (SUCCEEDED(IDXGIFactory4_QueryInterface(factory, &IID_IDXGIFactory5,
                                                   (void **)&f5))) {
            BOOL allow = FALSE;
            if (SUCCEEDED(IDXGIFactory5_CheckFeatureSupport(f5,
                    DXGI_FEATURE_PRESENT_ALLOW_TEARING, &allow, sizeof(allow))))
                g_tearing = allow ? 1 : 0;
            IDXGIFactory5_Release(f5);
        }
    }
    fprintf(stderr, "[d3d12] tearing=%d\n", g_tearing);
    DXGI_SWAP_CHAIN_DESC1 sd = {0};
    sd.BufferCount = FRAME_COUNT;
    sd.Width = (UINT)width;
    sd.Height = (UINT)height;
    sd.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
    sd.SampleDesc.Count = 1;
    sd.Flags = g_tearing ? DXGI_SWAP_CHAIN_FLAG_ALLOW_TEARING : 0;
    IDXGISwapChain1 *swap1;
    if (FAILED(IDXGIFactory4_CreateSwapChainForHwnd(factory,
               (IUnknown *)g_queue, hwnd, &sd, NULL, NULL, &swap1)))
        return 0;
    IDXGISwapChain1_QueryInterface(swap1, &IID_IDXGISwapChain3, (void **)&T->swap);
    IDXGISwapChain1_Release(swap1);
    /* Kill DXGI's built-in Alt+Enter: it flips to a stretched exclusive-
     * fullscreen mode (blurry/pixelated - the backbuffer stays windowed-
     * size and DXGI upscales). We handle Alt+Enter ourselves in the window
     * proc as borderless fullscreen, which goes through the normal resize
     * path (swap chain + layout re-derive at native res). */
    IDXGIFactory4_MakeWindowAssociation(factory, hwnd,
                                        2 /* DXGI_MWA_NO_ALT_ENTER */);
    IDXGIFactory4_Release(factory);

    D3D12_DESCRIPTOR_HEAP_DESC hd = {0};
    hd.NumDescriptors = FRAME_COUNT;
    hd.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
    ID3D12Device_CreateDescriptorHeap(g_dev, &hd,
        &IID_ID3D12DescriptorHeap, (void **)&T->rtv_heap);
    g_rtv_size = ID3D12Device_GetDescriptorHandleIncrementSize(
        g_dev, D3D12_DESCRIPTOR_HEAP_TYPE_RTV);

    D3D12_CPU_DESCRIPTOR_HANDLE rtv;
    ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(T->rtv_heap, &rtv);
    for (int i = 0; i < FRAME_COUNT; i++) {
        IDXGISwapChain3_GetBuffer(T->swap, i, &IID_ID3D12Resource,
                                  (void **)&T->backbuf[i]);
        ID3D12Device_CreateRenderTargetView(g_dev, T->backbuf[i], NULL, rtv);
        rtv.ptr += g_rtv_size;
    }

    for (int i = 0; i < FRAME_COUNT; i++)
        ID3D12Device_CreateCommandAllocator(g_dev,
            D3D12_COMMAND_LIST_TYPE_DIRECT, &IID_ID3D12CommandAllocator,
            (void **)&T->alloc[i]);
    if (!first) {          /* the shared pipeline already exists */
        T->live = 1;
        g_ntargets++;
        return g_cur + 1;
    }

    ID3D12Device_CreateCommandList(g_dev, 0, D3D12_COMMAND_LIST_TYPE_DIRECT,
        T->alloc[0], NULL, &IID_ID3D12GraphicsCommandList, (void **)&g_list);
    ID3D12GraphicsCommandList_Close(g_list);

    /* Root signature: empty, just allow the input layout. */
    D3D12_ROOT_SIGNATURE_DESC rsd = {0};
    rsd.Flags = D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT;
    ID3DBlob *sig, *err;
    if (FAILED(D3D12SerializeRootSignature(&rsd, D3D_ROOT_SIGNATURE_VERSION_1,
                                           &sig, &err)))
        return 0;
    ID3D12Device_CreateRootSignature(g_dev, 0,
        ID3D10Blob_GetBufferPointer(sig), ID3D10Blob_GetBufferSize(sig),
        &IID_ID3D12RootSignature, (void **)&g_rootsig);
    ID3D10Blob_Release(sig);

    D3D12_INPUT_ELEMENT_DESC layout[] = {
        { "POSITION", 0, DXGI_FORMAT_R32G32_FLOAT, 0, 0,
          D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "COLOR", 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 8,
          D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
    };

    D3D12_GRAPHICS_PIPELINE_STATE_DESC pd = {0};
    pd.pRootSignature = g_rootsig;
    pd.VS.pShaderBytecode = g_vs_dxbc;
    pd.VS.BytecodeLength = sizeof(g_vs_dxbc);
    pd.PS.pShaderBytecode = g_ps_dxbc;
    pd.PS.BytecodeLength = sizeof(g_ps_dxbc);
    pd.InputLayout.pInputElementDescs = layout;
    pd.InputLayout.NumElements = 2;
    pd.RasterizerState.FillMode = D3D12_FILL_MODE_SOLID;
    pd.RasterizerState.CullMode = D3D12_CULL_MODE_NONE;
    pd.RasterizerState.DepthClipEnable = TRUE;
    /* Alpha blend (glass): SRC_ALPHA / INV_SRC_ALPHA. Opaque rects carry
     * a=1.0 so they composite to src unchanged; translucent (#rrggbbaa)
     * panels blend over what's behind them. */
    pd.BlendState.RenderTarget[0].BlendEnable = TRUE;
    pd.BlendState.RenderTarget[0].SrcBlend = D3D12_BLEND_SRC_ALPHA;
    pd.BlendState.RenderTarget[0].DestBlend = D3D12_BLEND_INV_SRC_ALPHA;
    pd.BlendState.RenderTarget[0].BlendOp = D3D12_BLEND_OP_ADD;
    pd.BlendState.RenderTarget[0].SrcBlendAlpha = D3D12_BLEND_ONE;
    pd.BlendState.RenderTarget[0].DestBlendAlpha = D3D12_BLEND_INV_SRC_ALPHA;
    pd.BlendState.RenderTarget[0].BlendOpAlpha = D3D12_BLEND_OP_ADD;
    pd.BlendState.RenderTarget[0].RenderTargetWriteMask =
        D3D12_COLOR_WRITE_ENABLE_ALL;
    pd.SampleMask = UINT_MAX;
    pd.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
    pd.NumRenderTargets = 1;
    pd.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
    pd.SampleDesc.Count = 1;
    if (FAILED(ID3D12Device_CreateGraphicsPipelineState(g_dev, &pd,
               &IID_ID3D12PipelineState, (void **)&g_pso)))
        return 0;
    /* Persistent upload-heap vertex buffer, mapped once. */
    D3D12_HEAP_PROPERTIES hp = {0};
    hp.Type = D3D12_HEAP_TYPE_UPLOAD;
    D3D12_RESOURCE_DESC rd = {0};
    rd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    /* One FRAME_COUNT ring per target: two windows in flight must never
     * write the same slot while the GPU still reads it. */
    rd.Width = (UINT64)MAX_TARGETS * FRAME_COUNT * MAX_VERTS * sizeof(Vert);
    rd.Height = 1;
    rd.DepthOrArraySize = 1;
    rd.MipLevels = 1;
    rd.SampleDesc.Count = 1;
    rd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    if (FAILED(ID3D12Device_CreateCommittedResource(g_dev, &hp,
               D3D12_HEAP_FLAG_NONE, &rd, D3D12_RESOURCE_STATE_GENERIC_READ,
               NULL, &IID_ID3D12Resource, (void **)&g_vbuf)))
        return 0;
    D3D12_RANGE none = {0, 0};
    ID3D12Resource_Map(g_vbuf, 0, &none, (void **)&g_vmap);

    ID3D12Device_CreateFence(g_dev, 0, D3D12_FENCE_FLAG_NONE,
        &IID_ID3D12Fence, (void **)&g_fence);
    g_fence_evt = CreateEventW(NULL, FALSE, FALSE, NULL);
    g_fence_val = 0;
    tex_pipeline_init(); /* optional: sprites; rects work without it */
    T->live = 1;
    g_ntargets++;
    return g_cur + 1;
}

/* Wait only for THIS slot's previous submission - with FRAME_COUNT
 * slots the CPU records frame N while the GPU draws frame N-1. This
 * is the overlap the v0.0 "full sync per present" left on the table
 * (it played at half vsync). */
void dx_og_begin(long long target, long long r, long long g, long long b) {
    int slot = (int)target - 1;
    if (slot < 0 || slot >= g_ntargets || !g_target[slot].live) return;
    g_cur = slot;
    T = &g_target[slot];
    T->frame = (int)IDXGISwapChain3_GetCurrentBackBufferIndex(T->swap);
    if (ID3D12Fence_GetCompletedValue(g_fence) < T->frame_fence[T->frame]) {
        ID3D12Fence_SetEventOnCompletion(g_fence, T->frame_fence[T->frame],
                                         g_fence_evt);
        WaitForSingleObject(g_fence_evt, INFINITE);
    }
    g_nverts = 0;
    g_dropped = 0;
    g_calls = 0;
    g_nsprites = 0;
    g_clip_on = 0;
    T->clear[0] = (float)r / 255.0f;
    T->clear[1] = (float)g / 255.0f;
    T->clear[2] = (float)b / 255.0f;
    T->clear[3] = 1.0f;
}

/* Append one rect = 2 triangles = 6 verts. Pixel coords → NDC here so
 * the shader stays a passthrough.
 * Verts build in a CACHED staging array, not the mapped upload heap:
 * the upload heap is write-combined memory where scattered 24-byte
 * stores cost ~330ns each - st53 measured it. One streaming memcpy
 * at present is what WC memory is good at. */
/* The plain-rect and gradient verts all land in ONE untextured buffer that
 * is drawn with one call, so they cannot carry a scissor of their own the
 * way sprites and rounded rects do. They are trimmed here instead: exact
 * for a solid fill, and for a gradient the two stop colours are re-read at
 * the trimmed edges so the band it keeps is the band it would have had.
 * Without this a clipping box held its rounded children in and let every
 * flat one walk straight out of it - which is what a carousel is made of. */
static int clip_box(long long *x, long long *y, long long *w, long long *h) {
    if (!g_clip_on) return 1;
    long long x0 = *x, y0 = *y, x1 = *x + *w, y1 = *y + *h;
    long long cx1 = (long long)g_clip_x + g_clip_w;
    long long cy1 = (long long)g_clip_y + g_clip_h;
    if (x0 < g_clip_x) x0 = g_clip_x;
    if (y0 < g_clip_y) y0 = g_clip_y;
    if (x1 > cx1) x1 = cx1;
    if (y1 > cy1) y1 = cy1;
    if (x1 <= x0 || y1 <= y0) return 0;
    *x = x0; *y = y0; *w = x1 - x0; *h = y1 - y0;
    return 1;
}

void dx_og_rect(long long x, long long y, long long w, long long h,
              long long r, long long g, long long b) {
    if (g_nverts + 6 > MAX_VERTS) { g_dropped += 6; return; }
    if (!clip_box(&x, &y, &w, &h)) return;
    float x0 = (float)x / (float)T->width * 2.0f - 1.0f;
    float y0 = 1.0f - (float)y / (float)T->height * 2.0f;
    float x1 = (float)(x + w) / (float)T->width * 2.0f - 1.0f;
    float y1 = 1.0f - (float)(y + h) / (float)T->height * 2.0f;
    float cr = (float)r / 255.0f, cg = (float)g / 255.0f,
          cb = (float)b / 255.0f;
    Vert *v = g_stage + g_nverts;
    v[0] = (Vert){x0, y0, cr, cg, cb, 1};
    v[1] = (Vert){x1, y0, cr, cg, cb, 1};
    v[2] = (Vert){x0, y1, cr, cg, cb, 1};
    v[3] = (Vert){x1, y0, cr, cg, cb, 1};
    v[4] = (Vert){x1, y1, cr, cg, cb, 1};
    v[5] = (Vert){x0, y1, cr, cg, cb, 1};
    g_nverts += 6;
}

/* Same as dx_og_rect but with an alpha channel (0-255) for glass panels.
 * The rect PSO blends SRC_ALPHA/INV_SRC_ALPHA. */
void dx_og_rect_a(long long x, long long y, long long w, long long h,
              long long r, long long g, long long b, long long a) {
    if (g_nverts + 6 > MAX_VERTS) { g_dropped += 6; return; }
    if (!clip_box(&x, &y, &w, &h)) return;
    float x0 = (float)x / (float)T->width * 2.0f - 1.0f;
    float y0 = 1.0f - (float)y / (float)T->height * 2.0f;
    float x1 = (float)(x + w) / (float)T->width * 2.0f - 1.0f;
    float y1 = 1.0f - (float)(y + h) / (float)T->height * 2.0f;
    float cr = (float)r / 255.0f, cg = (float)g / 255.0f,
          cb = (float)b / 255.0f, ca = (float)a / 255.0f;
    Vert *v = g_stage + g_nverts;
    v[0] = (Vert){x0, y0, cr, cg, cb, ca};
    v[1] = (Vert){x1, y0, cr, cg, cb, ca};
    v[2] = (Vert){x0, y1, cr, cg, cb, ca};
    v[3] = (Vert){x1, y0, cr, cg, cb, ca};
    v[4] = (Vert){x1, y1, cr, cg, cb, ca};
    v[5] = (Vert){x0, y1, cr, cg, cb, ca};
    g_nverts += 6;
}

/* Vertical gradient rect: top verts carry colour0, bottom verts colour1 -
 * the rasterizer interpolates the fill for free. */
void dx_og_vgrad(long long x, long long y, long long w, long long h,
              long long r0, long long g0, long long b0,
              long long r1, long long g1, long long b1) {
    if (g_nverts + 6 > MAX_VERTS) { g_dropped += 6; return; }
    long long fy = y, fh = h;
    if (!clip_box(&x, &y, &w, &h)) return;
    /* The band that survived is a slice out of the original ramp, so the
     * two ends are re-read where the cut fell. */
    float t0 = fh > 0 ? (float)(y - fy) / (float)fh : 0.0f;
    float t1 = fh > 0 ? (float)(y + h - fy) / (float)fh : 1.0f;
    float x0 = (float)x / (float)T->width * 2.0f - 1.0f;
    float y0 = 1.0f - (float)y / (float)T->height * 2.0f;
    float x1 = (float)(x + w) / (float)T->width * 2.0f - 1.0f;
    float y1 = 1.0f - (float)(y + h) / (float)T->height * 2.0f;
    float tr = ((float)r0 + ((float)r1 - (float)r0) * t0) / 255.0f;
    float tg = ((float)g0 + ((float)g1 - (float)g0) * t0) / 255.0f;
    float tb = ((float)b0 + ((float)b1 - (float)b0) * t0) / 255.0f;
    float br = ((float)r0 + ((float)r1 - (float)r0) * t1) / 255.0f;
    float bg = ((float)g0 + ((float)g1 - (float)g0) * t1) / 255.0f;
    float bb = ((float)b0 + ((float)b1 - (float)b0) * t1) / 255.0f;
    Vert *v = g_stage + g_nverts;
    v[0] = (Vert){x0, y0, tr, tg, tb, 1}; /* TL top */
    v[1] = (Vert){x1, y0, tr, tg, tb, 1}; /* TR top */
    v[2] = (Vert){x0, y1, br, bg, bb, 1}; /* BL bottom */
    v[3] = (Vert){x1, y0, tr, tg, tb, 1}; /* TR top */
    v[4] = (Vert){x1, y1, br, bg, bb, 1}; /* BR bottom */
    v[5] = (Vert){x0, y1, br, bg, bb, 1}; /* BL bottom */
    g_nverts += 6;
}

long long dx_og_present(void) {
    /* Silent rect drops read as "half my sprite vanished". Say it once. */
    if (g_dropped > 0 && !g_overflow_warned) {
        fprintf(stderr, "[gpu] rect budget exceeded: dropped ~%d rects this "
                "frame (max %d/frame). A large or detailed sprite? Use a "
                "smaller source PNG (pixel art, transparent background) and "
                "scale it up, or draw fewer rects.\n",
                g_dropped / 6, MAX_VERTS / 6);
        g_overflow_warned = 1;
    }
    /* `frame` indexes this window's backbuffers, allocators and fences.
     * `ring` indexes the shared upload buffers, where every target owns
     * its own FRAME_COUNT band - the two are not interchangeable. */
    UINT frame = (UINT)T->frame;
    UINT ring = (UINT)(g_cur * FRAME_COUNT + T->frame);
    if (g_nverts > 0)
        memcpy(g_vmap + (size_t)ring * MAX_VERTS, g_stage,
               (size_t)g_nverts * sizeof(Vert));

    ID3D12CommandAllocator_Reset(T->alloc[frame]);
    ID3D12GraphicsCommandList_Reset(g_list, T->alloc[frame], g_pso);

    D3D12_RESOURCE_BARRIER barrier = {0};
    barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barrier.Transition.pResource = T->backbuf[frame];
    barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT;
    barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET;
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    ID3D12GraphicsCommandList_ResourceBarrier(g_list, 1, &barrier);

    D3D12_CPU_DESCRIPTOR_HANDLE rtv;
    ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(T->rtv_heap, &rtv);
    rtv.ptr += (SIZE_T)frame * g_rtv_size;
    ID3D12GraphicsCommandList_OMSetRenderTargets(g_list, 1, &rtv, FALSE, NULL);
    ID3D12GraphicsCommandList_ClearRenderTargetView(g_list, rtv, T->clear, 0, NULL);

    draw_in_order(ring);
    /* Say once what the batching achieved. A silent win is a win you
     * cannot tell has regressed. */
    if (++g_calls_peak == 60)
        fprintf(stderr, "[gpu] %d draw calls for %d sprites\n",
                g_calls, g_nsprites); /* rects and textured quads, as they were issued */

    barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
    barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT;
    ID3D12GraphicsCommandList_ResourceBarrier(g_list, 1, &barrier);
    ID3D12GraphicsCommandList_Close(g_list);

    ID3D12CommandList *lists[] = {(ID3D12CommandList *)g_list};
    ID3D12CommandQueue_ExecuteCommandLists(g_queue, 1, lists);
    /* 0x200 = DXGI_PRESENT_ALLOW_TEARING - required for uncapped
     * present on flip-model when vsync is off. */
    IDXGISwapChain3_Present(T->swap, g_vsync ? 1 : 0,
                            (!g_vsync && g_tearing) ? 0x200 : 0);
    g_fence_val++;
    ID3D12CommandQueue_Signal(g_queue, g_fence, g_fence_val);
    T->frame_fence[frame] = g_fence_val;
    return 1;
}

/* ---- textured sprite pipeline implementation ---------------------- */

/* D3DCompile, loaded dynamically so we add no link dependency and degrade
 * gracefully if the compiler DLL is absent. Types (ID3DBlob, D3D_SHADER_MACRO)
 * come from d3dcommon.h via d3d12.h - no d3dcompiler.h needed. */
typedef HRESULT(WINAPI *PFN_D3DCOMPILE)(LPCVOID, SIZE_T, LPCSTR,
    const D3D_SHADER_MACRO *, ID3DInclude *, LPCSTR, LPCSTR, UINT, UINT,
    ID3DBlob **, ID3DBlob **);
static PFN_D3DCOMPILE g_D3DCompile;

static ID3DBlob *tex_compile(const char *src, const char *entry, const char *tgt) {
    ID3DBlob *code = NULL, *err = NULL;
    HRESULT hr = g_D3DCompile(src, strlen(src), NULL, NULL, NULL, entry, tgt,
                              0, 0, &code, &err);
    if (FAILED(hr)) {
        if (err) fprintf(stderr, "[gpu] shader compile failed: %s\n",
                         (char *)ID3D10Blob_GetBufferPointer(err));
        if (err) ID3D10Blob_Release(err);
        return NULL;
    }
    if (err) ID3D10Blob_Release(err);
    return code;
}

static ID3D12PipelineState *tex_make_pso(ID3DBlob *vs, ID3DBlob *ps,
                                         int additive) {
    D3D12_INPUT_ELEMENT_DESC layout[] = {
        { "POSITION", 0, DXGI_FORMAT_R32G32_FLOAT, 0, 0,
          D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "TEXCOORD", 0, DXGI_FORMAT_R32G32_FLOAT, 0, 8,
          D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "COLOR", 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 16,
          D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
    };
    D3D12_GRAPHICS_PIPELINE_STATE_DESC pd = {0};
    pd.pRootSignature = g_tex_rootsig;
    pd.VS.pShaderBytecode = ID3D10Blob_GetBufferPointer(vs);
    pd.VS.BytecodeLength = ID3D10Blob_GetBufferSize(vs);
    pd.PS.pShaderBytecode = ID3D10Blob_GetBufferPointer(ps);
    pd.PS.BytecodeLength = ID3D10Blob_GetBufferSize(ps);
    pd.InputLayout.pInputElementDescs = layout;
    pd.InputLayout.NumElements = 3;
    pd.RasterizerState.FillMode = D3D12_FILL_MODE_SOLID;
    pd.RasterizerState.CullMode = D3D12_CULL_MODE_NONE;
    pd.RasterizerState.DepthClipEnable = TRUE;
    D3D12_RENDER_TARGET_BLEND_DESC *rt = &pd.BlendState.RenderTarget[0];
    rt->BlendEnable = TRUE;
    rt->SrcBlend = D3D12_BLEND_SRC_ALPHA;
    rt->DestBlend = additive ? D3D12_BLEND_ONE : D3D12_BLEND_INV_SRC_ALPHA;
    rt->BlendOp = D3D12_BLEND_OP_ADD;
    rt->SrcBlendAlpha = D3D12_BLEND_ONE;
    rt->DestBlendAlpha = D3D12_BLEND_INV_SRC_ALPHA;
    rt->BlendOpAlpha = D3D12_BLEND_OP_ADD;
    rt->RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL;
    pd.SampleMask = UINT_MAX;
    pd.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
    pd.NumRenderTargets = 1;
    pd.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
    pd.SampleDesc.Count = 1;
    ID3D12PipelineState *pso = NULL;
    if (FAILED(ID3D12Device_CreateGraphicsPipelineState(g_dev, &pd,
               &IID_ID3D12PipelineState, (void **)&pso)))
        return NULL;
    return pso;
}

/* The rounded-rect pipeline. The quad's own vertices carry the pixel
 * offset from its centre (in the UV slot - nothing is sampled here), and
 * the half-size and radius arrive as root constants, so the shape costs no
 * vertex bandwidth. The pixel shader is the standard rounded-box distance:
 * shrink the box by the radius, take the distance to that, subtract the
 * radius back. Coverage is a one-pixel ramp across the zero crossing,
 * which is what makes the corner smooth at any radius and any size.
 *
 * Same idea Zed's GPUI uses. A CPU span fill cannot do this: a span either
 * covers a pixel or it does not, so every corner comes out as a staircase. */
static void quad_pipeline_init(void) {
    static const char *QVS =
        "struct VIn{float2 p:POSITION;float2 l:TEXCOORD;float4 c:COLOR;"
        "float4 s:TEXCOORD1;float4 k:TEXCOORD2;};"
        "struct VOut{float4 p:SV_POSITION;float2 l:TEXCOORD;float4 c:COLOR;"
        "nointerpolation float4 s:TEXCOORD1;nointerpolation float4 k:TEXCOORD2;};"
        "VOut main(VIn i){VOut o;o.p=float4(i.p,0,1);o.l=i.l;o.c=i.c;"
        "o.s=i.s;o.k=i.k;return o;}";
    static const char *QPS =
        "struct VOut{float4 p:SV_POSITION;float2 l:TEXCOORD;float4 c:COLOR;"
        "nointerpolation float4 s:TEXCOORD1;nointerpolation float4 k:TEXCOORD2;};"
        "cbuffer K:register(b0){float4 kc;float4 kd;};""float clipped(float2 p){""if(kd.y<0.5)return 1.0;""float2 q=abs(p-kc.xy)-kc.zw+kd.x;""float d=length(max(q,0.0))+min(max(q.x,q.y),0.0)-kd.x;""return saturate(0.5-d);}"
        "float4 main(VOut i):SV_TARGET{"
        "float d;"
        /* Mode 2: a plain triangle. No distance function to evaluate - the
         * shape IS the geometry - but it rides this pipeline anyway so it
         * gets the clip, the rounded clip and the draw order the flat
         * buffer cannot give it. */
        "if(i.k.w>1.5){d=-1.0;}"
        "else if(i.k.w>0.5){"
        /* An annulus, cut by a wedge. The ring is the distance to a circle
         * of the middle radius, minus half the thickness. The wedge is the
         * angle away from the middle of the span, turned into pixels by the
         * radius so the two straight ends fade over the same one pixel the
         * curved ones do. */
        "float rr=length(i.l);"
        "float mid=(i.s.x+i.k.x)*0.5;float hf=(i.s.x-i.k.x)*0.5;"
        "float dring=abs(rr-mid)-hf;"
        "float span=i.k.z-i.k.y;"
        "float dw=-100000.0;"
        "if(span<6.2831){"
        "float ang=atan2(i.l.x,-i.l.y);"
        "float mida=i.k.y+span*0.5;"
        "float da=ang-mida;"
        "da=da-6.28318531*floor((da+3.14159265)/6.28318531);"
        "dw=(abs(da)-span*0.5)*max(rr,1.0);}"
        "d=max(dring,dw);"
        "}else{"
        /* One radius per corner, chosen by which quarter of the box the
         * pixel is in. A tab is round on top and square on the bottom, and
         * so is every joined button group; one radius for all four could
         * not say it. s.z is the top-left, k.xyz the other three. */
        "float rr=(i.l.x<0.0)?((i.l.y<0.0)?i.s.z:i.k.z):((i.l.y<0.0)?i.k.x:i.k.y);"
        "float2 q=abs(i.l)-i.s.xy+rr;"
        "d=length(max(q,0.0))+min(max(q.x,q.y),0.0)-rr;}"
        "float a=saturate(0.5-d/max(i.s.w,1.0))*clipped(i.p.xy);"
        "return float4(i.c.rgb,i.c.a*a);}";
    ID3DBlob *vs = tex_compile(QVS, "main", "vs_5_0");
    ID3DBlob *ps = tex_compile(QPS, "main", "ps_5_0");
    if (!vs || !ps) { fprintf(stderr, "[gpu] quad shader compile failed\n"); return; }

    D3D12_ROOT_PARAMETER kparam = {0};
    kparam.ParameterType = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
    kparam.Constants.ShaderRegister = 0;
    kparam.Constants.Num32BitValues = 8;
    kparam.ShaderVisibility = D3D12_SHADER_VISIBILITY_PIXEL;
    D3D12_ROOT_SIGNATURE_DESC rsd = {0};
    rsd.NumParameters = 1;
    rsd.pParameters = &kparam;
    rsd.Flags = D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT;
    ID3DBlob *sig = NULL, *err = NULL;
    if (FAILED(D3D12SerializeRootSignature(&rsd, D3D_ROOT_SIGNATURE_VERSION_1,
                                           &sig, &err))) {
        fprintf(stderr, "[gpu] quad rootsig serialize failed: %s\n",
                err ? (char *)ID3D10Blob_GetBufferPointer(err) : "?");
        if (err) ID3D10Blob_Release(err);
        return;
    }
    if (FAILED(ID3D12Device_CreateRootSignature(g_dev, 0,
            ID3D10Blob_GetBufferPointer(sig), ID3D10Blob_GetBufferSize(sig),
            &IID_ID3D12RootSignature, (void **)&g_quad_rootsig))) {
        fprintf(stderr, "[gpu] quad rootsig create failed\n");
        ID3D10Blob_Release(sig);
        return;
    }
    ID3D10Blob_Release(sig);

    D3D12_INPUT_ELEMENT_DESC layout[] = {
        { "POSITION", 0, DXGI_FORMAT_R32G32_FLOAT, 0, 0,
          D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "TEXCOORD", 0, DXGI_FORMAT_R32G32_FLOAT, 0, 8,
          D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "COLOR", 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 16,
          D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "TEXCOORD", 1, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 32,
          D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "TEXCOORD", 2, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 48,
          D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
    };
    D3D12_GRAPHICS_PIPELINE_STATE_DESC pd = {0};
    pd.pRootSignature = g_quad_rootsig;
    pd.VS.pShaderBytecode = ID3D10Blob_GetBufferPointer(vs);
    pd.VS.BytecodeLength = ID3D10Blob_GetBufferSize(vs);
    pd.PS.pShaderBytecode = ID3D10Blob_GetBufferPointer(ps);
    pd.PS.BytecodeLength = ID3D10Blob_GetBufferSize(ps);
    pd.InputLayout.pInputElementDescs = layout;
    /* Counted from the array, not written out again. A hand-kept count
     * goes stale: adding the arc's fifth attribute left this at four,
     * the pipeline would not build, and everything silently fell back
     * to filling spans - stepped corners, and no rings at all. */
    pd.InputLayout.NumElements = (UINT)(sizeof layout / sizeof layout[0]);
    pd.RasterizerState.FillMode = D3D12_FILL_MODE_SOLID;
    pd.RasterizerState.CullMode = D3D12_CULL_MODE_NONE;
    pd.RasterizerState.DepthClipEnable = TRUE;
    pd.BlendState.RenderTarget[0].BlendEnable = TRUE;
    pd.BlendState.RenderTarget[0].SrcBlend = D3D12_BLEND_SRC_ALPHA;
    pd.BlendState.RenderTarget[0].DestBlend = D3D12_BLEND_INV_SRC_ALPHA;
    pd.BlendState.RenderTarget[0].BlendOp = D3D12_BLEND_OP_ADD;
    pd.BlendState.RenderTarget[0].SrcBlendAlpha = D3D12_BLEND_ONE;
    pd.BlendState.RenderTarget[0].DestBlendAlpha = D3D12_BLEND_INV_SRC_ALPHA;
    pd.BlendState.RenderTarget[0].BlendOpAlpha = D3D12_BLEND_OP_ADD;
    pd.BlendState.RenderTarget[0].RenderTargetWriteMask = 15;
    pd.SampleMask = UINT_MAX;
    pd.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
    pd.NumRenderTargets = 1;
    pd.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
    pd.SampleDesc.Count = 1;
    ID3D12Device_CreateGraphicsPipelineState(g_dev, &pd,
        &IID_ID3D12PipelineState, (void **)&g_pso_quad);
    if (g_pso_quad) fprintf(stderr, "[gpu] rounded-rect pipeline ready\n");
}

/* Build the whole textured path. Any failure leaves g_tex_ok=0 and rects
 * keep working; DrawImage just no-ops with a one-time notice. */
static void tex_pipeline_init(void) {
    HMODULE dll = LoadLibraryA("d3dcompiler_47.dll");
    if (!dll) dll = LoadLibraryA("d3dcompiler_43.dll");
    if (!dll) { fprintf(stderr, "[gpu] no d3dcompiler DLL - sprites disabled\n"); return; }
    g_D3DCompile = (PFN_D3DCOMPILE)GetProcAddress(dll, "D3DCompile");
    if (!g_D3DCompile) { fprintf(stderr, "[gpu] D3DCompile missing - sprites disabled\n"); return; }

    static const char *VS =
        "struct VIn{float2 p:POSITION;float2 uv:TEXCOORD;float4 c:COLOR;};"
        "struct VOut{float4 p:SV_POSITION;float2 uv:TEXCOORD;float4 c:COLOR;};"
        "VOut main(VIn i){VOut o;o.p=float4(i.p,0,1);o.uv=i.uv;o.c=i.c;return o;}";
    static const char *PS =
        "Texture2D t:register(t0);SamplerState s:register(s0);"
        "cbuffer K:register(b0){float4 kc;float4 kd;};"
        "struct VOut{float4 p:SV_POSITION;float2 uv:TEXCOORD;float4 c:COLOR;};"
        /* The clip's own corners, finished here. A scissor is a rectangle
         * and always will be; text and pictures inside a rounded panel
         * have to be cut by the panel's actual shape or every card and
         * every avatar squares off at the corner. */
        "float4 main(VOut i):SV_TARGET{"
        "float k=1.0;"
        "if(kd.y>0.5){"
        "float2 q=abs(i.p.xy-kc.xy)-kc.zw+kd.x;"
        "float d=length(max(q,0.0))+min(max(q.x,q.y),0.0)-kd.x;"
        "k=saturate(0.5-d);}"
        "float4 o=t.Sample(s,i.uv)*i.c;"
        "return float4(o.rgb,o.a*k);}";
    ID3DBlob *vs = tex_compile(VS, "main", "vs_5_0");
    ID3DBlob *ps = tex_compile(PS, "main", "ps_5_0");
    if (!vs || !ps) return;

    /* Root sig: one SRV table (t0, pixel-visible) + a static POINT sampler. */
    D3D12_DESCRIPTOR_RANGE range = {0};
    range.RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_SRV;
    range.NumDescriptors = 1;
    range.BaseShaderRegister = 0;
    range.OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND;
    D3D12_ROOT_PARAMETER param = {0};
    param.ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
    param.DescriptorTable.NumDescriptorRanges = 1;
    param.DescriptorTable.pDescriptorRanges = &range;
    param.ShaderVisibility = D3D12_SHADER_VISIBILITY_PIXEL;
    D3D12_STATIC_SAMPLER_DESC samp = {0};
    samp.Filter = D3D12_FILTER_MIN_MAG_MIP_POINT; /* crisp pixel art */
    samp.AddressU = D3D12_TEXTURE_ADDRESS_MODE_CLAMP;
    samp.AddressV = D3D12_TEXTURE_ADDRESS_MODE_CLAMP;
    samp.AddressW = D3D12_TEXTURE_ADDRESS_MODE_CLAMP;
    samp.ShaderRegister = 0;
    samp.ShaderVisibility = D3D12_SHADER_VISIBILITY_PIXEL;
    D3D12_ROOT_PARAMETER kparam = {0};
    kparam.ParameterType = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
    kparam.Constants.ShaderRegister = 0;
    kparam.Constants.Num32BitValues = 8;
    kparam.ShaderVisibility = D3D12_SHADER_VISIBILITY_PIXEL;
    D3D12_ROOT_PARAMETER params[2] = { param, kparam };
    D3D12_ROOT_SIGNATURE_DESC rsd = {0};
    rsd.NumParameters = 2;
    rsd.pParameters = params;
    rsd.NumStaticSamplers = 1;
    rsd.pStaticSamplers = &samp;
    rsd.Flags = D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT;
    ID3DBlob *sig = NULL, *serr = NULL;
    if (FAILED(D3D12SerializeRootSignature(&rsd, D3D_ROOT_SIGNATURE_VERSION_1,
                                           &sig, &serr))) {
        fprintf(stderr, "[gpu] tex root sig failed\n");
        return;
    }
    if (FAILED(ID3D12Device_CreateRootSignature(g_dev, 0,
               ID3D10Blob_GetBufferPointer(sig), ID3D10Blob_GetBufferSize(sig),
               &IID_ID3D12RootSignature, (void **)&g_tex_rootsig)))
        return;
    ID3D10Blob_Release(sig);

    g_pso_alpha = tex_make_pso(vs, ps, 0);
    g_pso_add = tex_make_pso(vs, ps, 1);
    ID3D10Blob_Release(vs);
    ID3D10Blob_Release(ps);
    if (!g_pso_alpha || !g_pso_add) { fprintf(stderr, "[gpu] tex PSO failed\n"); return; }

    /* Shader-visible SRV heap. */
    D3D12_DESCRIPTOR_HEAP_DESC hd = {0};
    hd.NumDescriptors = MAX_TEX;
    hd.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
    hd.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
    if (FAILED(ID3D12Device_CreateDescriptorHeap(g_dev, &hd,
               &IID_ID3D12DescriptorHeap, (void **)&g_srv_heap)))
        return;
    g_srv_size = ID3D12Device_GetDescriptorHandleIncrementSize(
        g_dev, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

    /* Tex-vertex upload ring + a dedicated allocator/list for uploads. */
    D3D12_HEAP_PROPERTIES hp = {0};
    hp.Type = D3D12_HEAP_TYPE_UPLOAD;
    D3D12_RESOURCE_DESC rd = {0};
    rd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    /* Same per-target banding as the rect ring above. */
    rd.Width = (UINT64)MAX_TARGETS * FRAME_COUNT * MAX_SPRITES * 6 *
               sizeof(TexVert);
    rd.Height = 1;
    rd.DepthOrArraySize = 1;
    rd.MipLevels = 1;
    rd.SampleDesc.Count = 1;
    rd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    if (FAILED(ID3D12Device_CreateCommittedResource(g_dev, &hp,
               D3D12_HEAP_FLAG_NONE, &rd, D3D12_RESOURCE_STATE_GENERIC_READ,
               NULL, &IID_ID3D12Resource, (void **)&g_tvbuf)))
        return;
    D3D12_RANGE none = {0, 0};
    ID3D12Resource_Map(g_tvbuf, 0, &none, (void **)&g_tvmap);
    ID3D12Device_CreateCommandAllocator(g_dev, D3D12_COMMAND_LIST_TYPE_DIRECT,
        &IID_ID3D12CommandAllocator, (void **)&g_up_alloc);
    ID3D12Device_CreateCommandList(g_dev, 0, D3D12_COMMAND_LIST_TYPE_DIRECT,
        g_up_alloc, NULL, &IID_ID3D12GraphicsCommandList, (void **)&g_up_list);
    ID3D12GraphicsCommandList_Close(g_up_list);

    for (int i = 0; i < MAX_TEX; i++) g_tex_key[i] = -1;
    g_tex_ok = 1;
    fprintf(stderr, "[gpu] texture pipeline ready\n");

    /* Rounded rects ride the same ordered stream, so they need the sprite
     * staging buffer that was just set up. Failing here is survivable: the
     * span fill still draws them, just with stepped corners. */
    atlas_init();
    quad_pipeline_init();
}

/* Shelf packing: fill a row left to right, start a new row when it is
 * full. Dumb, and exactly right for glyphs, which arrive in similar
 * heights and never come back. Returns 0 when the sheet is full. */
static int atlas_alloc(int w, int h, int *ax, int *ay) {
    if (!g_atlas || w > ATLAS_DIM) return 0;
    if (g_shelf_x + w > ATLAS_DIM) {          /* next shelf */
        g_shelf_x = 0;
        g_shelf_y += g_shelf_h;
        g_shelf_h = 0;
    }
    if (g_shelf_y + h > ATLAS_DIM) return 0;  /* sheet full */
    *ax = g_shelf_x;
    *ay = g_shelf_y;
    g_shelf_x += w;
    if (h > g_shelf_h) g_shelf_h = h;
    return 1;
}

/* Copy one small image into the atlas at (ax, ay). Same staging dance as a
 * standalone texture, minus creating a texture. */
static int atlas_put(const unsigned char *rgba, int ax, int ay, int w, int h) {
    D3D12_RESOURCE_DESC td = {0};
    td.Dimension = D3D12_RESOURCE_DIMENSION_TEXTURE2D;
    td.Width = ATLAS_DIM;
    td.Height = ATLAS_DIM;
    td.DepthOrArraySize = 1;
    td.MipLevels = 1;
    td.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    td.SampleDesc.Count = 1;
    D3D12_PLACED_SUBRESOURCE_FOOTPRINT fp;
    UINT rows; UINT64 rowbytes, total;
    D3D12_RESOURCE_DESC one = td;
    one.Width = (UINT64)w;
    one.Height = (UINT)h;
    ID3D12Device_GetCopyableFootprints(g_dev, &one, 0, 1, 0, &fp, &rows,
                                       &rowbytes, &total);
    D3D12_HEAP_PROPERTIES up = {0};
    up.Type = D3D12_HEAP_TYPE_UPLOAD;
    D3D12_RESOURCE_DESC ub = {0};
    ub.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    ub.Width = total;
    ub.Height = 1;
    ub.DepthOrArraySize = 1;
    ub.MipLevels = 1;
    ub.SampleDesc.Count = 1;
    ub.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    ID3D12Resource *staging = NULL;
    if (FAILED(ID3D12Device_CreateCommittedResource(g_dev, &up,
               D3D12_HEAP_FLAG_NONE, &ub, D3D12_RESOURCE_STATE_GENERIC_READ,
               NULL, &IID_ID3D12Resource, (void **)&staging)))
        return 0;
    unsigned char *map = NULL;
    D3D12_RANGE none = {0, 0};
    ID3D12Resource_Map(staging, 0, &none, (void **)&map);
    for (int y = 0; y < h; y++)
        memcpy(map + fp.Offset + (size_t)y * fp.Footprint.RowPitch,
               rgba + (size_t)y * w * 4, (size_t)w * 4);
    ID3D12Resource_Unmap(staging, 0, NULL);

    ID3D12CommandAllocator_Reset(g_up_alloc);
    ID3D12GraphicsCommandList_Reset(g_up_list, g_up_alloc, NULL);
    D3D12_RESOURCE_BARRIER b = {0};
    b.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    b.Transition.pResource = g_atlas;
    b.Transition.StateBefore = D3D12_RESOURCE_STATE_PIXEL_SHADER_RESOURCE;
    b.Transition.StateAfter = D3D12_RESOURCE_STATE_COPY_DEST;
    b.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    ID3D12GraphicsCommandList_ResourceBarrier(g_up_list, 1, &b);
    D3D12_TEXTURE_COPY_LOCATION dst = {0};
    dst.pResource = g_atlas;
    dst.Type = D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;
    dst.SubresourceIndex = 0;
    D3D12_TEXTURE_COPY_LOCATION srcl = {0};
    srcl.pResource = staging;
    srcl.Type = D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT;
    srcl.PlacedFootprint = fp;
    ID3D12GraphicsCommandList_CopyTextureRegion(g_up_list, &dst, ax, ay, 0,
                                                &srcl, NULL);
    b.Transition.StateBefore = D3D12_RESOURCE_STATE_COPY_DEST;
    b.Transition.StateAfter = D3D12_RESOURCE_STATE_PIXEL_SHADER_RESOURCE;
    ID3D12GraphicsCommandList_ResourceBarrier(g_up_list, 1, &b);
    ID3D12GraphicsCommandList_Close(g_up_list);
    ID3D12CommandList *lists[] = {(ID3D12CommandList *)g_up_list};
    ID3D12CommandQueue_ExecuteCommandLists(g_queue, 1, lists);
    fence_sync();
    ID3D12Resource_Release(staging);
    return 1;
}

/* The sheet itself, plus its one SRV. Everything glyph-shaped shares it. */
static void atlas_init(void) {
    D3D12_HEAP_PROPERTIES dp = {0};
    dp.Type = D3D12_HEAP_TYPE_DEFAULT;
    D3D12_RESOURCE_DESC td = {0};
    td.Dimension = D3D12_RESOURCE_DIMENSION_TEXTURE2D;
    td.Width = ATLAS_DIM;
    td.Height = ATLAS_DIM;
    td.DepthOrArraySize = 1;
    td.MipLevels = 1;
    td.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    td.SampleDesc.Count = 1;
    if (FAILED(ID3D12Device_CreateCommittedResource(g_dev, &dp,
               D3D12_HEAP_FLAG_NONE, &td,
               D3D12_RESOURCE_STATE_PIXEL_SHADER_RESOURCE,
               NULL, &IID_ID3D12Resource, (void **)&g_atlas)))
        return;
    g_atlas_slot = g_tex_n++;
    D3D12_CPU_DESCRIPTOR_HANDLE cpu;
    ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(g_srv_heap, &cpu);
    cpu.ptr += (SIZE_T)g_atlas_slot * g_srv_size;
    D3D12_SHADER_RESOURCE_VIEW_DESC sv = {0};
    sv.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    sv.ViewDimension = D3D12_SRV_DIMENSION_TEXTURE2D;
    sv.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
    sv.Texture2D.MipLevels = 1;
    ID3D12Device_CreateShaderResourceView(g_dev, g_atlas, &sv, cpu);
    fprintf(stderr, "[gpu] glyph atlas %dx%d ready\n", ATLAS_DIM, ATLAS_DIM);
}

/* Upload one RGBA image to a new texture, create its SRV, return the id.
 * Caller tags the slot (path for images, key for glyphs). */
static int tex_upload_raw(const unsigned char *rgba, int w, int h) {
    if (g_tex_n >= MAX_TEX || w <= 0 || h <= 0) return -1;
    int id = g_tex_n;

    D3D12_HEAP_PROPERTIES dp = {0};
    dp.Type = D3D12_HEAP_TYPE_DEFAULT;
    D3D12_RESOURCE_DESC td = {0};
    td.Dimension = D3D12_RESOURCE_DIMENSION_TEXTURE2D;
    td.Width = (UINT64)w;
    td.Height = (UINT)h;
    td.DepthOrArraySize = 1;
    td.MipLevels = 1;
    td.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    td.SampleDesc.Count = 1;
    td.Layout = D3D12_TEXTURE_LAYOUT_UNKNOWN;
    if (FAILED(ID3D12Device_CreateCommittedResource(g_dev, &dp,
               D3D12_HEAP_FLAG_NONE, &td, D3D12_RESOURCE_STATE_COPY_DEST,
               NULL, &IID_ID3D12Resource, (void **)&g_tex[id])))
        return -1;

    D3D12_PLACED_SUBRESOURCE_FOOTPRINT fp;
    UINT rows;
    UINT64 rowbytes, total;
    ID3D12Device_GetCopyableFootprints(g_dev, &td, 0, 1, 0, &fp, &rows,
                                       &rowbytes, &total);
    D3D12_HEAP_PROPERTIES up = {0};
    up.Type = D3D12_HEAP_TYPE_UPLOAD;
    D3D12_RESOURCE_DESC ub = {0};
    ub.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    ub.Width = total;
    ub.Height = 1;
    ub.DepthOrArraySize = 1;
    ub.MipLevels = 1;
    ub.SampleDesc.Count = 1;
    ub.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    ID3D12Resource *staging = NULL;
    if (FAILED(ID3D12Device_CreateCommittedResource(g_dev, &up,
               D3D12_HEAP_FLAG_NONE, &ub, D3D12_RESOURCE_STATE_GENERIC_READ,
               NULL, &IID_ID3D12Resource, (void **)&staging)))
        return -1;
    unsigned char *map = NULL;
    D3D12_RANGE none = {0, 0};
    ID3D12Resource_Map(staging, 0, &none, (void **)&map);
    for (int y = 0; y < h; y++)
        memcpy(map + fp.Offset + (size_t)y * fp.Footprint.RowPitch,
               rgba + (size_t)y * w * 4, (size_t)w * 4);
    ID3D12Resource_Unmap(staging, 0, NULL);

    ID3D12CommandAllocator_Reset(g_up_alloc);
    ID3D12GraphicsCommandList_Reset(g_up_list, g_up_alloc, NULL);
    D3D12_TEXTURE_COPY_LOCATION dst = {0};
    dst.pResource = g_tex[id];
    dst.Type = D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;
    dst.SubresourceIndex = 0;
    D3D12_TEXTURE_COPY_LOCATION srcl = {0};
    srcl.pResource = staging;
    srcl.Type = D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT;
    srcl.PlacedFootprint = fp;
    ID3D12GraphicsCommandList_CopyTextureRegion(g_up_list, &dst, 0, 0, 0, &srcl, NULL);
    D3D12_RESOURCE_BARRIER b = {0};
    b.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    b.Transition.pResource = g_tex[id];
    b.Transition.StateBefore = D3D12_RESOURCE_STATE_COPY_DEST;
    b.Transition.StateAfter = D3D12_RESOURCE_STATE_PIXEL_SHADER_RESOURCE;
    b.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    ID3D12GraphicsCommandList_ResourceBarrier(g_up_list, 1, &b);
    ID3D12GraphicsCommandList_Close(g_up_list);
    ID3D12CommandList *lists[] = {(ID3D12CommandList *)g_up_list};
    ID3D12CommandQueue_ExecuteCommandLists(g_queue, 1, lists);
    fence_sync(); /* wait: the copy must finish before we free staging */
    ID3D12Resource_Release(staging);

    D3D12_CPU_DESCRIPTOR_HANDLE cpu;
    ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(g_srv_heap, &cpu);
    cpu.ptr += (SIZE_T)id * g_srv_size;
    D3D12_SHADER_RESOURCE_VIEW_DESC sv = {0};
    sv.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    sv.ViewDimension = D3D12_SRV_DIMENSION_TEXTURE2D;
    sv.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
    sv.Texture2D.MipLevels = 1;
    ID3D12Device_CreateShaderResourceView(g_dev, g_tex[id], &sv, cpu);

    g_tex_w[id] = w;
    g_tex_h[id] = h;
    g_tex_path[id] = NULL;
    g_tex_key[id] = -1;
    g_tex_n++;
    return id;
}

/* dx_og_texture(path): decode (cached in png_min) + upload (cached here). */
long long dx_og_texture(const char *path) {
    if (!g_tex_ok) return -1;
    for (int i = 0; i < g_tex_n; i++)
        if (g_tex_path[i] && strcmp(g_tex_path[i], path) == 0) return i;
    const char *blob = host_image_load(path);
    if (orion_tlen_c(blob) < 8) return -1;
    const unsigned char *d = (const unsigned char *)blob;
    int w = d[0] | d[1] << 8 | d[2] << 16 | d[3] << 24;
    int h = d[4] | d[5] << 8 | d[6] << 16 | d[7] << 24;
    int id = tex_upload_raw(d + 8, w, h);
    if (id >= 0) g_tex_path[id] = _strdup(path);
    /* The pixels live on the GPU now - release the ~w*h*4 CPU copy. */
    host_image_free_cached(path);
    return id;
}

/* Cached glyph texture by int key (gid*K+size). Returns id or -1 if not yet
 * uploaded - the caller then rasterizes and calls dx_og_texture_mem. */
long long dx_og_glyph_id(long long key) {
    if (!g_tex_ok) return -1;
    for (int i = 0; i < g_tex_n; i++)
        if (g_tex_key[i] == key) return i;
    return -1;
}

/* Upload an in-memory RGBA image (orion [int], one byte per element) under an
 * int key. Used for AA glyph bitmaps. Cached: a repeat key returns its id. */
long long dx_og_texture_mem(long long key, long long w, long long h,
                            const long long *rgba) {
    if (!g_tex_ok) return -1;
    for (int i = 0; i < g_tex_n; i++)
        if (g_tex_key[i] == key) return i;
    long long n = w * h * 4;
    unsigned char *packed = (unsigned char *)malloc((size_t)n);
    if (!packed) return -1;
    /* rgba is an orion list: [cap][len][items...]; items are i64 bytes. */
    for (long long i = 0; i < n; i++) packed[i] = (unsigned char)rgba[2 + i];

    /* Into the shared sheet when it has room. A logical id is still handed
     * back, so callers see no difference - it just no longer costs a
     * texture and a descriptor each. */
    int ax = 0, ay = 0, id = -1;
    if (g_atlas && g_tex_n < MAX_TEX && atlas_alloc((int)w, (int)h, &ax, &ay)
        && atlas_put(packed, ax, ay, (int)w, (int)h)) {
        id = g_tex_n++;
        g_in_atlas[id] = 1;
        g_tex_ax[id] = ax;
        g_tex_ay[id] = ay;
        g_tex_w[id] = (int)w;
        g_tex_h[id] = (int)h;
        g_tex_path[id] = NULL;
    } else {
        id = tex_upload_raw(packed, (int)w, (int)h);
    }
    free(packed);
    if (id >= 0) g_tex_key[id] = key;
    return id;
}

/* Record one textured quad. src rect (sx,sy,sw,sh) in texels - 0 w/h means
 * the whole texture (atlas otherwise). tint is 0xRRGGBBAA modulation.
 * blend: 0 = alpha, 1 = additive. Clipped to the active scissor. */
/* A rounded rect, shaded rather than filled. Rides the same ordered draw
 * stream as sprites so it composites in the order the display list asked
 * for. Returns 0 when the pipeline is not up, so the caller can fall back
 * to the span fill. */

/* A ring, or a slice of one. Centre, the two radii, and the span in
 * degrees measured from the top and going clockwise - which is how every
 * cooldown sweep and every radial meter is described. It rides the same
 * shaded-quad pipeline as the rounded rects, so it is smooth at the edges,
 * obeys the clip, and costs one quad however long the arc is. */
long long dx_og_round_rect4(long long x, long long y, long long w,
                            long long h, long long r, long long g,
                            long long b, long long a, long long tl,
                            long long tr, long long br, long long bl,
                            long long soft);

/* One triangle. Recorded as a quad's worth of vertices with the second
 * triangle collapsed to a point, so the sprite stream keeps its six-per
 * stride and a run of triangles still goes out in one draw. Three points
 * is all a polygon, a chart, a gauge needle or a damage cone is made of,
 * and until now the display list had a DrawPath that drew nothing. */
long long dx_og_tri(long long x0, long long y0, long long x1, long long y1,
                    long long x2, long long y2, long long r, long long g,
                    long long b, long long a) {
    if (!g_tex_ok || !g_pso_quad) return 0;
    if (g_nsprites >= MAX_SPRITES) { g_dropped += 6; return 1; }
    float cr = (float)r / 255.0f, cg = (float)g / 255.0f;
    float cb = (float)b / 255.0f, ca = (float)a / 255.0f;
    float px[3], py[3];
    long long ix[3] = { x0, x1, x2 };
    long long iy[3] = { y0, y1, y2 };
    for (int i = 0; i < 3; i++) {
        px[i] = (float)ix[i] / (float)T->width * 2.0f - 1.0f;
        py[i] = 1.0f - (float)iy[i] / (float)T->height * 2.0f;
    }
    TexVert *v = g_tstage + g_nsprites * 6;
    for (int i = 0; i < 3; i++) {
        v[i] = (TexVert){px[i], py[i], 0, 0, cr, cg, cb, ca, 0, 0, 0, 1, 0, 0, 0, 2};
        v[3 + i] = v[0];
    }
    SpriteDraw *s = &g_sprites[g_nsprites];
    s->kind = 1;
    s->tex = 0;
    s->blend = 0;
    s->hw = 0; s->hh = 0; s->rad = 0; s->soft = 1;
    s->clip = g_clip_on;
    s->cx = g_clip_x; s->cy = g_clip_y;
    s->cw = g_clip_w; s->ch = g_clip_h;
    s->crad = g_clip_rad;
    s->at_vert = g_nverts;
    g_nsprites++;
    return 1;
}

long long dx_og_arc(long long cx, long long cy, long long outer,
                    long long inner, long long from_deg, long long to_deg,
                    long long r, long long g, long long b, long long a,
                    long long soft) {
    if (!g_tex_ok || !g_pso_quad || outer <= 0) return 0;
    if (g_nsprites >= MAX_SPRITES) { g_dropped += 6; return 1; }
    float ro = (float)outer;
    float ri = (float)inner < 0.0f ? 0.0f : (float)inner;
    if (ri > ro) ri = ro;
    float ramp = (float)(soft < 1 ? 1 : soft);
    float l = ro + ramp;
    float fx = (float)cx, fy = (float)cy;
    float x0 = (fx - l) / (float)T->width * 2.0f - 1.0f;
    float x1 = (fx + l) / (float)T->width * 2.0f - 1.0f;
    float y0 = 1.0f - (fy - l) / (float)T->height * 2.0f;
    float y1 = 1.0f - (fy + l) / (float)T->height * 2.0f;
    float cr = (float)r / 255.0f, cg = (float)g / 255.0f;
    float cb = (float)b / 255.0f, ca = (float)a / 255.0f;
    const float TAU = 6.28318531f;
    float a0 = (float)from_deg * TAU / 360.0f;
    float a1 = (float)to_deg * TAU / 360.0f;
    if (a1 < a0) { float t = a0; a0 = a1; a1 = t; }
    TexVert *v = g_tstage + g_nsprites * 6;
    TexVert c0 = {x0, y0, -l, -l, cr, cg, cb, ca, ro, ro, 0, ramp, ri, a0, a1, 1};
    TexVert c1 = {x1, y0,  l, -l, cr, cg, cb, ca, ro, ro, 0, ramp, ri, a0, a1, 1};
    TexVert c2 = {x0, y1, -l,  l, cr, cg, cb, ca, ro, ro, 0, ramp, ri, a0, a1, 1};
    TexVert c3 = {x1, y1,  l,  l, cr, cg, cb, ca, ro, ro, 0, ramp, ri, a0, a1, 1};
    v[0] = c0; v[1] = c1; v[2] = c2; v[3] = c1; v[4] = c3; v[5] = c2;
    SpriteDraw *s = &g_sprites[g_nsprites];
    s->kind = 1;
    s->tex = 0;
    s->blend = 0;
    s->hw = ro; s->hh = ro; s->rad = 0; s->soft = ramp;
    s->clip = g_clip_on;
    s->cx = g_clip_x; s->cy = g_clip_y;
    s->cw = g_clip_w; s->ch = g_clip_h;
    s->crad = g_clip_rad;
    s->at_vert = g_nverts;
    g_nsprites++;
    return 1;
}

long long dx_og_round_rect(long long x, long long y, long long w, long long h,
                           long long r, long long g, long long b, long long a,
                           long long radius, long long soft) {
    return dx_og_round_rect4(x, y, w, h, r, g, b, a, radius, radius, radius,
                             radius, soft);
}

long long dx_og_round_rect4(long long x, long long y, long long w,
                            long long h, long long r, long long g,
                            long long b, long long a, long long tl,
                            long long tr, long long br, long long bl,
                            long long soft) {
    long long radius = tl;
    if (!g_tex_ok || !g_pso_quad || w <= 0 || h <= 0) return 0;
    if (g_nsprites >= MAX_SPRITES) { g_dropped += 6; return 1; }
    float hw = (float)w * 0.5f, hh = (float)h * 0.5f;
    float cap = hw < hh ? hw : hh;
    float rad = (float)radius;
    if (rad > cap) rad = cap;
    if (rad < 0.0f) rad = 0.0f;
    float r_tr = (float)tr, r_br = (float)br, r_bl = (float)bl;
    if (r_tr > cap) r_tr = cap;
    if (r_br > cap) r_br = cap;
    if (r_bl > cap) r_bl = cap;
    if (r_tr < 0.0f) r_tr = 0.0f;
    if (r_br < 0.0f) r_br = 0.0f;
    if (r_bl < 0.0f) r_bl = 0.0f;
    /* Grow the quad by the ramp width so the fade has somewhere to happen;
     * without it the outermost half-covered pixel is clipped away and the
     * corner looks bitten rather than round. A shadow's ramp is its blur,
     * which is why a soft edge needs a bigger quad than a hard one. */
    float ramp = (float)(soft < 1 ? 1 : soft);
    float ex = ramp;
    float lx = hw + ex, ly = hh + ex;
    float cx = (float)x + hw, cy = (float)y + hh;
    float x0 = (cx - lx) / (float)T->width * 2.0f - 1.0f;
    float x1 = (cx + lx) / (float)T->width * 2.0f - 1.0f;
    float y0 = 1.0f - (cy - ly) / (float)T->height * 2.0f;
    float y1 = 1.0f - (cy + ly) / (float)T->height * 2.0f;
    float cr = (float)r / 255.0f, cg = (float)g / 255.0f;
    float cb = (float)b / 255.0f, ca = (float)a / 255.0f;
    TexVert *v = g_tstage + g_nsprites * 6;
    v[0] = (TexVert){x0, y0, -lx, -ly, cr, cg, cb, ca, hw, hh, rad, ramp, r_tr, r_br, r_bl, 0};
    v[1] = (TexVert){x1, y0,  lx, -ly, cr, cg, cb, ca, hw, hh, rad, ramp, r_tr, r_br, r_bl, 0};
    v[2] = (TexVert){x0, y1, -lx,  ly, cr, cg, cb, ca, hw, hh, rad, ramp, r_tr, r_br, r_bl, 0};
    v[3] = (TexVert){x1, y0,  lx, -ly, cr, cg, cb, ca, hw, hh, rad, ramp, r_tr, r_br, r_bl, 0};
    v[4] = (TexVert){x1, y1,  lx,  ly, cr, cg, cb, ca, hw, hh, rad, ramp, r_tr, r_br, r_bl, 0};
    v[5] = (TexVert){x0, y1, -lx,  ly, cr, cg, cb, ca, hw, hh, rad, ramp, r_tr, r_br, r_bl, 0};
    SpriteDraw *s = &g_sprites[g_nsprites];
    s->kind = 1;
    s->tex = 0;
    s->blend = 0;
    s->hw = hw; s->hh = hh; s->rad = rad; s->soft = ramp;
    s->clip = g_clip_on;
    s->cx = g_clip_x; s->cy = g_clip_y;
    s->cw = g_clip_w; s->ch = g_clip_h;
    s->crad = g_clip_rad;
    s->at_vert = g_nverts;
    g_nsprites++;
    return 1;
}

/* How big a loaded texture is. Nine-slice needs it: the corners are cut
 * from the source in ITS pixels, and only the loader knows how many there
 * are. */
long long dx_og_tex_w(long long id) {
    if (id < 0 || id >= g_tex_n) return 0;
    return g_tex_w[id];
}

long long dx_og_tex_h(long long id) {
    if (id < 0 || id >= g_tex_n) return 0;
    return g_tex_h[id];
}

void dx_og_sprite(long long id, long long dx, long long dy, long long dw,
                  long long dh, long long sx, long long sy, long long sw,
                  long long sh, long long tint, long long blend) {
    if (!g_tex_ok || id < 0 || id >= g_tex_n) return;
    if (g_nsprites >= MAX_SPRITES) { g_dropped += 6; return; }
    int tw = g_tex_w[id], th = g_tex_h[id];
    if (sw <= 0) sw = tw;
    if (sh <= 0) sh = th;
    if (dw <= 0) dw = tw; /* dest size omitted -> native pixels */
    if (dh <= 0) dh = th;
    /* An atlas entry samples its own rect out of the shared sheet, and
     * binds the sheet's descriptor - which is what lets a run of glyphs
     * become one draw call instead of one each. */
    int packed_in = g_in_atlas[id];
    int slot = packed_in ? g_atlas_slot : (int)id;
    float sheet = packed_in ? (float)ATLAS_DIM : 0.0f;
    float ox = packed_in ? (float)g_tex_ax[id] : 0.0f;
    float oy = packed_in ? (float)g_tex_ay[id] : 0.0f;
    float uw = packed_in ? sheet : (float)tw;
    float uh = packed_in ? sheet : (float)th;
    float u0 = (ox + (float)sx) / uw, v0 = (oy + (float)sy) / uh;
    float u1 = (ox + (float)(sx + sw)) / uw, v1 = (oy + (float)(sy + sh)) / uh;
    float x0 = (float)dx / (float)T->width * 2.0f - 1.0f;
    float y0 = 1.0f - (float)dy / (float)T->height * 2.0f;
    float x1 = (float)(dx + dw) / (float)T->width * 2.0f - 1.0f;
    float y1 = 1.0f - (float)(dy + dh) / (float)T->height * 2.0f;
    float cr = (float)((tint >> 24) & 255) / 255.0f;
    float cg = (float)((tint >> 16) & 255) / 255.0f;
    float cb = (float)((tint >> 8) & 255) / 255.0f;
    float ca = (float)(tint & 255) / 255.0f;
    TexVert *v = g_tstage + g_nsprites * 6;
    v[0] = (TexVert){x0, y0, u0, v0, cr, cg, cb, ca, 0, 0, 0, 0};
    v[1] = (TexVert){x1, y0, u1, v0, cr, cg, cb, ca, 0, 0, 0, 0};
    v[2] = (TexVert){x0, y1, u0, v1, cr, cg, cb, ca, 0, 0, 0, 0};
    v[3] = (TexVert){x1, y0, u1, v0, cr, cg, cb, ca, 0, 0, 0, 0};
    v[4] = (TexVert){x1, y1, u1, v1, cr, cg, cb, ca, 0, 0, 0, 0};
    v[5] = (TexVert){x0, y1, u0, v1, cr, cg, cb, ca, 0, 0, 0, 0};
    SpriteDraw *s = &g_sprites[g_nsprites];
    s->kind = 0;
    s->tex = slot;
    s->blend = (int)blend;
    s->clip = g_clip_on;
    s->cx = g_clip_x; s->cy = g_clip_y; s->cw = g_clip_w; s->ch = g_clip_h;
    s->crad = g_clip_rad;
    s->at_vert = g_nverts;   /* where this sprite sits in the rect stream */
    g_nsprites++;
}

void dx_og_clip(long long x, long long y, long long w, long long h,
                long long radius) {
    g_clip_x = (int)x; g_clip_y = (int)y; g_clip_w = (int)w; g_clip_h = (int)h;
    g_clip_rad = (int)radius;
    g_clip_on = 1;
}
void dx_og_clip_none(void) { g_clip_on = 0; }

/* One draw call for the solid verts in [from, to). */
static void solid_span(UINT ring, int from, int to) {
    if (to <= from) return;
    D3D12_VIEWPORT vp = {0, 0, (float)T->width, (float)T->height, 0, 1};
    D3D12_RECT sc = {0, 0, T->width, T->height};
    ID3D12GraphicsCommandList_SetPipelineState(g_list, g_pso);
    ID3D12GraphicsCommandList_RSSetViewports(g_list, 1, &vp);
    ID3D12GraphicsCommandList_RSSetScissorRects(g_list, 1, &sc);
    ID3D12GraphicsCommandList_SetGraphicsRootSignature(g_list, g_rootsig);
    ID3D12GraphicsCommandList_IASetPrimitiveTopology(g_list,
        D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    D3D12_VERTEX_BUFFER_VIEW vbv;
    vbv.BufferLocation = ID3D12Resource_GetGPUVirtualAddress(g_vbuf) +
                         (UINT64)ring * MAX_VERTS * sizeof(Vert) +
                         (UINT64)from * sizeof(Vert);
    vbv.StrideInBytes = sizeof(Vert);
    vbv.SizeInBytes = (UINT)((size_t)(to - from) * sizeof(Vert));
    ID3D12GraphicsCommandList_IASetVertexBuffers(g_list, 0, 1, &vbv);
    ID3D12GraphicsCommandList_DrawInstanced(g_list, (UINT)(to - from), 1, 0, 0);
}

/* Replay BOTH streams in submission order.
 *
 * Rects and textured quads live in separate vertex buffers with their own
 * root signature and pipeline state, so the old code drew every rect and
 * then every sprite. That is cheap and it is wrong: anti-aliased text goes
 * through the sprite path, so text always landed on top of everything and
 * no drawer, dropdown or modal could cover a label.
 *
 * Each sprite carries the rect-stream position it was submitted at, so
 * here we walk the sprites and flush the pending rects that belong in
 * front of each one first. When the two streams do not actually interleave
 * - the common case - this issues exactly the same two draw calls as
 * before; state is only rebound where the order really alternates. */
static void draw_in_order(UINT ring) {
    int textured = g_tex_ok && g_nsprites > 0;
    size_t vbase = (size_t)ring * MAX_SPRITES * 6;
    if (textured)
        memcpy(g_tvmap + vbase, g_tstage,
               (size_t)g_nsprites * 6 * sizeof(TexVert));
    if (!textured) {
        solid_span(ring, 0, g_nverts);
        return;
    }

    D3D12_GPU_DESCRIPTOR_HANDLE base;
    ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart(g_srv_heap, &base);
    D3D12_RECT full = {0, 0, T->width, T->height};
    D3D12_VIEWPORT vp = {0, 0, (float)T->width, (float)T->height, 0, 1};
    ID3D12DescriptorHeap *heaps[] = {g_srv_heap};

    int drawn_verts = 0;
    int cur_blend = -1;   /* -1 also means "texture state is not bound" */
    for (int i = 0; i < g_nsprites; i++) {
        SpriteDraw *s = &g_sprites[i];
        if (s->at_vert > drawn_verts) {
            solid_span(ring, drawn_verts, s->at_vert);
            drawn_verts = s->at_vert;
            cur_blend = -1;   /* the solid pass rebound rootsig and PSO */
        }
        /* A rounded rect binds its own root signature and pipeline; the
         * shape rides along as root constants. -2 marks "quad state is
         * bound" so a run of them rebinds nothing. */
        if (s->kind == 1) {
            if (cur_blend != -2) {
                ID3D12GraphicsCommandList_RSSetViewports(g_list, 1, &vp);
                ID3D12GraphicsCommandList_SetGraphicsRootSignature(g_list,
                    g_quad_rootsig);
                ID3D12GraphicsCommandList_SetPipelineState(g_list, g_pso_quad);
                ID3D12GraphicsCommandList_IASetPrimitiveTopology(g_list,
                    D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
                cur_blend = -2;
            }
        } else {
        if (cur_blend < 0) {
            ID3D12GraphicsCommandList_RSSetViewports(g_list, 1, &vp);
            ID3D12GraphicsCommandList_SetDescriptorHeaps(g_list, 1, heaps);
            ID3D12GraphicsCommandList_SetGraphicsRootSignature(g_list,
                g_tex_rootsig);
            ID3D12GraphicsCommandList_IASetPrimitiveTopology(g_list,
                D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        }
        if (s->blend != cur_blend) {
            ID3D12GraphicsCommandList_SetPipelineState(g_list,
                s->blend == 1 ? g_pso_add : g_pso_alpha);
            cur_blend = s->blend;
        }
        D3D12_GPU_DESCRIPTOR_HANDLE h = base;
        h.ptr += (UINT64)s->tex * g_srv_size;
        ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable(g_list, 0, h);
        }
        /* Held inside the target. A scissor that starts above the top of
         * the screen is not a scissor D3D12 will take, and a rejected one
         * leaves the PREVIOUS one in force - so a panel scrolled off the
         * top of a page stopped being clipped at all and drew itself over
         * the header. The shader still gets the true rect, so a rounded
         * clip keeps its corners wherever they are. */
        D3D12_RECT sc = full;
        if (s->clip) {
            LONG l = s->cx, t = s->cy;
            LONG r2 = s->cx + s->cw, b2 = s->cy + s->ch;
            if (l < 0) l = 0;
            if (t < 0) t = 0;
            if (r2 > T->width) r2 = T->width;
            if (b2 > T->height) b2 = T->height;
            if (r2 < l) r2 = l;
            if (b2 < t) b2 = t;
            sc = (D3D12_RECT){l, t, r2, b2};
        }
        ID3D12GraphicsCommandList_RSSetScissorRects(g_list, 1, &sc);
        /* A draw run already breaks whenever the clip changes, so the
         * clip's shape can ride as root constants: no vertex carries it
         * and no memory grows. Centre, half size, corner, and whether it
         * is on at all. */
        {
            float kk[8];
            kk[0] = (float)s->cx + (float)s->cw * 0.5f;
            kk[1] = (float)s->cy + (float)s->ch * 0.5f;
            kk[2] = (float)s->cw * 0.5f;
            kk[3] = (float)s->ch * 0.5f;
            kk[4] = (float)s->crad;
            kk[5] = (s->clip && s->crad > 0) ? 1.0f : 0.0f;
            kk[6] = 0.0f;
            kk[7] = 0.0f;
            ID3D12GraphicsCommandList_SetGraphicsRoot32BitConstants(g_list,
                s->kind == 1 ? 0 : 1, 8, kk, 0);
        }
        /* Everything that follows and needs the exact same state goes out
         * in ONE draw: the vertices are already contiguous. With glyphs
         * sharing an atlas this collapses a few hundred draw calls per
         * frame into a handful, which was the point of packing them. */
        int run = 1;
        while (i + run < g_nsprites) {
            SpriteDraw *nx = &g_sprites[i + run];
            if (nx->at_vert > drawn_verts) break;     /* solid work between */
            if (nx->kind != s->kind || nx->tex != s->tex ||
                nx->blend != s->blend || nx->clip != s->clip ||
                nx->cx != s->cx || nx->cy != s->cy ||
                nx->cw != s->cw || nx->ch != s->ch ||
                nx->crad != s->crad) break;
            run++;
        }
        D3D12_VERTEX_BUFFER_VIEW vbv;
        vbv.BufferLocation = ID3D12Resource_GetGPUVirtualAddress(g_tvbuf) +
                             (vbase + (size_t)i * 6) * sizeof(TexVert);
        vbv.StrideInBytes = sizeof(TexVert);
        vbv.SizeInBytes = (UINT)(run * 6 * sizeof(TexVert));
        ID3D12GraphicsCommandList_IASetVertexBuffers(g_list, 0, 1, &vbv);
        ID3D12GraphicsCommandList_DrawInstanced(g_list, run * 6, 1, 0, 0);
        g_calls++;
        i += run - 1;
    }
    solid_span(ring, drawn_verts, g_nverts);   /* whatever came after */
}

long long dx_og_vsync(long long on) {
    g_vsync = on ? 1 : 0;
    return 1;
}

long long dx_og_caps(void) { return 2; /* 1 = software, 2 = d3d12 */ }

long long dx_og_resize(long long target, long long w, long long h) {
    int slot = (int)target - 1;
    if (slot < 0 || slot >= g_ntargets || !g_target[slot].live) return 0;
    g_cur = slot;
    T = &g_target[slot];
    if (!T->swap || w <= 0 || h <= 0) return 0;
    fence_sync(); /* full drain: backbuffers must be unreferenced */
    for (int i = 0; i < FRAME_COUNT; i++) {
        ID3D12Resource_Release(T->backbuf[i]);
        T->backbuf[i] = NULL;
    }
    if (FAILED(IDXGISwapChain3_ResizeBuffers(T->swap, FRAME_COUNT, (UINT)w,
            (UINT)h, DXGI_FORMAT_R8G8B8A8_UNORM,
            g_tearing ? DXGI_SWAP_CHAIN_FLAG_ALLOW_TEARING : 0)))
        return 0;
    D3D12_CPU_DESCRIPTOR_HANDLE rtv;
    ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(T->rtv_heap, &rtv);
    for (int i = 0; i < FRAME_COUNT; i++) {
        IDXGISwapChain3_GetBuffer(T->swap, i, &IID_ID3D12Resource,
                                  (void **)&T->backbuf[i]);
        ID3D12Device_CreateRenderTargetView(g_dev, T->backbuf[i], NULL, rtv);
        rtv.ptr += g_rtv_size;
    }
    T->width = (int)w;
    T->height = (int)h;
    return 1;
}

void dx_og_shutdown(void) {
    if (g_queue) fence_sync();
    /* Deliberately no Release cascade - process exit reclaims
     * everything; a game calls this once. */
}
