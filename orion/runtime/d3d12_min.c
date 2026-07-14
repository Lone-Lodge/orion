/* d3d12_min.c — minimal D3D12 renderer for native Orion.
 *
 * Same philosophy as win32_min.c: one C file, raw OS API, no
 * middleware. Colored 2D rects only — exactly what cubsy's
 * DisplayList needs. ~450 lines replaces lodge-orion's gpu.rs + wgpu
 * dependency chain.
 *
 * CORRECT frame model (unlike gpu.rs's per-draw-submit):
 *   og_begin(r,g,b)          reset frame, remember clear color
 *   og_rect(x,y,w,h,r,g,b)   append 6 verts (pixel coords, 0-255 col)
 *   og_present()             record ONE command list: barrier, clear,
 *                             draw all, barrier, execute, present,
 *                             fence-wait (full sync — correct first,
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
#define MAX_VERTS 65536           /* 10922 rects/frame — plenty for 2D */

typedef struct { float x, y, r, g, b, a; } Vert;

static ID3D12Device        *g_dev;
static ID3D12CommandQueue  *g_queue;
static IDXGISwapChain3     *g_swap;
static ID3D12DescriptorHeap *g_rtv_heap;
static ID3D12Resource      *g_backbuf[FRAME_COUNT];
static ID3D12CommandAllocator *g_alloc[FRAME_COUNT]; /* one per in-flight frame */
static ID3D12GraphicsCommandList *g_list;
static ID3D12RootSignature *g_rootsig;
static ID3D12PipelineState *g_pso;
static ID3D12Resource      *g_vbuf;      /* upload ring: FRAME_COUNT slots */
static Vert                *g_vmap;      /* persistently mapped */
static Vert                 g_stage[MAX_VERTS]; /* cached-RAM build buffer */
static ID3D12Fence         *g_fence;
static HANDLE               g_fence_evt;
static UINT64               g_fence_val;
static UINT64               g_frame_fence[FRAME_COUNT]; /* last submit per slot */
static UINT                 g_rtv_size;
static int                  g_width, g_height;
static int                  g_nverts;
static int                  g_dropped;         /* verts dropped this frame (budget hit) */
static int                  g_overflow_warned; /* one-shot budget-exceeded notice */
static int                  g_frame;     /* current backbuffer slot */
static int                  g_vsync = 0; /* uncapped by default; og_vsync opts in */
static int                  g_tearing = 0;
static float                g_clear[4];

/* ---- textured sprite pipeline (modern 2D: blend, tint, clip, scale) ----
 * Rects can't show an image without a rect-per-pixel; a texture draws the
 * whole image as ONE quad the GPU samples. This adds: texture upload (cached
 * by path), a shader-visible SRV heap, a textured PSO per blend mode (alpha,
 * additive), a POINT static sampler (crisp pixel art), per-sprite tint +
 * source sub-rect (atlas) + scale, and a scissor clip. Shaders are compiled
 * at runtime via a dynamically-loaded d3dcompiler (no build-script change;
 * if it is missing, sprites disable and rects still work). */
#define MAX_TEX     256
#define MAX_SPRITES 4096
typedef struct { float x, y, u, v, r, g, b, a; } TexVert; /* pos, uv, tint */
typedef struct { int tex; int blend; int cx, cy, cw, ch; int clip; } SpriteDraw;

static ID3D12DescriptorHeap *g_srv_heap;   /* shader-visible SRV table */
static UINT                  g_srv_size;
static ID3D12Resource       *g_tex[MAX_TEX];
static int                   g_tex_w[MAX_TEX], g_tex_h[MAX_TEX];
static char                 *g_tex_path[MAX_TEX];
static int                   g_tex_n;
static ID3D12RootSignature  *g_tex_rootsig;
static ID3D12PipelineState  *g_pso_alpha;   /* SRC_ALPHA / INV_SRC_ALPHA */
static ID3D12PipelineState  *g_pso_add;     /* SRC_ALPHA / ONE (glow) */
static ID3D12Resource       *g_tvbuf;       /* upload ring for tex verts */
static TexVert              *g_tvmap;
static TexVert               g_tstage[MAX_SPRITES * 6];
static SpriteDraw            g_sprites[MAX_SPRITES];
static int                   g_nsprites;
static ID3D12CommandAllocator *g_up_alloc;  /* dedicated for synchronous uploads */
static ID3D12GraphicsCommandList *g_up_list;
static int                   g_tex_ok;      /* pipeline built? */
static int                   g_clip_x, g_clip_y, g_clip_w, g_clip_h, g_clip_on;

/* host-side PNG decoder (orion_rt.c): returns [w LE32][h LE32][RGBA...]. */
extern const char *host_image_load(const char *path);
extern void host_image_free_cached(const char *path);
extern long long orion_tlen_c(const char *p);
static void tex_pipeline_init(void); /* defined below; called from init */
static void tex_flush(UINT frame);   /* defined below; called from present */

/* Shaders precompiled to DXBC at build time (fxc, see tools/shaders) —
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

long long dx_og_init(long long hwnd_i, long long width, long long height) {
    HWND hwnd = (HWND)(uintptr_t)hwnd_i;
    g_width = (int)width;
    g_height = (int)height;

    /* Pick a REAL adapter: the default can be a BMC/software device
     * (ASPEED on server boards) and everything silently runs at
     * software speed. Enumerate, skip software-flagged adapters,
     * take the first that creates a device. */
    {
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

    D3D12_COMMAND_QUEUE_DESC qd = {0};
    qd.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
    if (FAILED(ID3D12Device_CreateCommandQueue(g_dev, &qd,
               &IID_ID3D12CommandQueue, (void **)&g_queue)))
        return 0;

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
    IDXGISwapChain1_QueryInterface(swap1, &IID_IDXGISwapChain3, (void **)&g_swap);
    IDXGISwapChain1_Release(swap1);
    IDXGIFactory4_Release(factory);

    D3D12_DESCRIPTOR_HEAP_DESC hd = {0};
    hd.NumDescriptors = FRAME_COUNT;
    hd.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
    ID3D12Device_CreateDescriptorHeap(g_dev, &hd,
        &IID_ID3D12DescriptorHeap, (void **)&g_rtv_heap);
    g_rtv_size = ID3D12Device_GetDescriptorHandleIncrementSize(
        g_dev, D3D12_DESCRIPTOR_HEAP_TYPE_RTV);

    D3D12_CPU_DESCRIPTOR_HANDLE rtv;
    ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(g_rtv_heap, &rtv);
    for (int i = 0; i < FRAME_COUNT; i++) {
        IDXGISwapChain3_GetBuffer(g_swap, i, &IID_ID3D12Resource,
                                  (void **)&g_backbuf[i]);
        ID3D12Device_CreateRenderTargetView(g_dev, g_backbuf[i], NULL, rtv);
        rtv.ptr += g_rtv_size;
    }

    for (int i = 0; i < FRAME_COUNT; i++)
        ID3D12Device_CreateCommandAllocator(g_dev,
            D3D12_COMMAND_LIST_TYPE_DIRECT, &IID_ID3D12CommandAllocator,
            (void **)&g_alloc[i]);
    ID3D12Device_CreateCommandList(g_dev, 0, D3D12_COMMAND_LIST_TYPE_DIRECT,
        g_alloc[0], NULL, &IID_ID3D12GraphicsCommandList, (void **)&g_list);
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
    rd.Width = (UINT64)FRAME_COUNT * MAX_VERTS * sizeof(Vert); /* ring */
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
    return 1;
}

/* Wait only for THIS slot's previous submission — with FRAME_COUNT
 * slots the CPU records frame N while the GPU draws frame N-1. This
 * is the overlap the v0.0 "full sync per present" left on the table
 * (it played at half vsync). */
void dx_og_begin(long long r, long long g, long long b) {
    g_frame = (int)IDXGISwapChain3_GetCurrentBackBufferIndex(g_swap);
    if (ID3D12Fence_GetCompletedValue(g_fence) < g_frame_fence[g_frame]) {
        ID3D12Fence_SetEventOnCompletion(g_fence, g_frame_fence[g_frame],
                                         g_fence_evt);
        WaitForSingleObject(g_fence_evt, INFINITE);
    }
    g_nverts = 0;
    g_dropped = 0;
    g_nsprites = 0;
    g_clip_on = 0;
    g_clear[0] = (float)r / 255.0f;
    g_clear[1] = (float)g / 255.0f;
    g_clear[2] = (float)b / 255.0f;
    g_clear[3] = 1.0f;
}

/* Append one rect = 2 triangles = 6 verts. Pixel coords → NDC here so
 * the shader stays a passthrough.
 * Verts build in a CACHED staging array, not the mapped upload heap:
 * the upload heap is write-combined memory where scattered 24-byte
 * stores cost ~330ns each — st53 measured it. One streaming memcpy
 * at present is what WC memory is good at. */
void dx_og_rect(long long x, long long y, long long w, long long h,
              long long r, long long g, long long b) {
    if (g_nverts + 6 > MAX_VERTS) { g_dropped += 6; return; }
    float x0 = (float)x / (float)g_width * 2.0f - 1.0f;
    float y0 = 1.0f - (float)y / (float)g_height * 2.0f;
    float x1 = (float)(x + w) / (float)g_width * 2.0f - 1.0f;
    float y1 = 1.0f - (float)(y + h) / (float)g_height * 2.0f;
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
    UINT frame = (UINT)g_frame;
    if (g_nverts > 0)
        memcpy(g_vmap + (size_t)frame * MAX_VERTS, g_stage,
               (size_t)g_nverts * sizeof(Vert));

    ID3D12CommandAllocator_Reset(g_alloc[frame]);
    ID3D12GraphicsCommandList_Reset(g_list, g_alloc[frame], g_pso);

    D3D12_RESOURCE_BARRIER barrier = {0};
    barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barrier.Transition.pResource = g_backbuf[frame];
    barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT;
    barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET;
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    ID3D12GraphicsCommandList_ResourceBarrier(g_list, 1, &barrier);

    D3D12_CPU_DESCRIPTOR_HANDLE rtv;
    ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(g_rtv_heap, &rtv);
    rtv.ptr += (SIZE_T)frame * g_rtv_size;
    ID3D12GraphicsCommandList_OMSetRenderTargets(g_list, 1, &rtv, FALSE, NULL);
    ID3D12GraphicsCommandList_ClearRenderTargetView(g_list, rtv, g_clear, 0, NULL);

    if (g_nverts > 0) {
        D3D12_VIEWPORT vp = {0, 0, (float)g_width, (float)g_height, 0, 1};
        D3D12_RECT sc = {0, 0, g_width, g_height};
        ID3D12GraphicsCommandList_RSSetViewports(g_list, 1, &vp);
        ID3D12GraphicsCommandList_RSSetScissorRects(g_list, 1, &sc);
        ID3D12GraphicsCommandList_SetGraphicsRootSignature(g_list, g_rootsig);
        ID3D12GraphicsCommandList_IASetPrimitiveTopology(g_list,
            D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        D3D12_VERTEX_BUFFER_VIEW vbv;
        vbv.BufferLocation = ID3D12Resource_GetGPUVirtualAddress(g_vbuf) +
                             (UINT64)frame * MAX_VERTS * sizeof(Vert);
        vbv.StrideInBytes = sizeof(Vert);
        vbv.SizeInBytes = (UINT)(g_nverts * sizeof(Vert));
        ID3D12GraphicsCommandList_IASetVertexBuffers(g_list, 0, 1, &vbv);
        ID3D12GraphicsCommandList_DrawInstanced(g_list, (UINT)g_nverts, 1, 0, 0);
    }

    tex_flush(frame); /* textured sprites, blended over the rects */

    barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
    barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT;
    ID3D12GraphicsCommandList_ResourceBarrier(g_list, 1, &barrier);
    ID3D12GraphicsCommandList_Close(g_list);

    ID3D12CommandList *lists[] = {(ID3D12CommandList *)g_list};
    ID3D12CommandQueue_ExecuteCommandLists(g_queue, 1, lists);
    /* 0x200 = DXGI_PRESENT_ALLOW_TEARING — required for uncapped
     * present on flip-model when vsync is off. */
    IDXGISwapChain3_Present(g_swap, g_vsync ? 1 : 0,
                            (!g_vsync && g_tearing) ? 0x200 : 0);
    g_fence_val++;
    ID3D12CommandQueue_Signal(g_queue, g_fence, g_fence_val);
    g_frame_fence[frame] = g_fence_val;
    return 1;
}

/* ---- textured sprite pipeline implementation ---------------------- */

/* D3DCompile, loaded dynamically so we add no link dependency and degrade
 * gracefully if the compiler DLL is absent. Types (ID3DBlob, D3D_SHADER_MACRO)
 * come from d3dcommon.h via d3d12.h — no d3dcompiler.h needed. */
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
        "struct VOut{float4 p:SV_POSITION;float2 uv:TEXCOORD;float4 c:COLOR;};"
        "float4 main(VOut i):SV_TARGET{return t.Sample(s,i.uv)*i.c;}";
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
    D3D12_ROOT_SIGNATURE_DESC rsd = {0};
    rsd.NumParameters = 1;
    rsd.pParameters = &param;
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
    rd.Width = (UINT64)FRAME_COUNT * MAX_SPRITES * 6 * sizeof(TexVert);
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

    g_tex_ok = 1;
    fprintf(stderr, "[gpu] texture pipeline ready\n");
}

/* Upload one RGBA image to a new texture, create its SRV, return the id. */
static int tex_upload(const char *path, const unsigned char *rgba, int w, int h) {
    if (g_tex_n >= MAX_TEX) return -1;
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
    g_tex_path[id] = _strdup(path);
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
    int id = tex_upload(path, d + 8, w, h);
    /* The pixels live on the GPU now — release the ~w*h*4 CPU copy. */
    host_image_free_cached(path);
    return id;
}

/* Record one textured quad. src rect (sx,sy,sw,sh) in texels — 0 w/h means
 * the whole texture (atlas otherwise). tint is 0xRRGGBBAA modulation.
 * blend: 0 = alpha, 1 = additive. Clipped to the active scissor. */
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
    float u0 = (float)sx / (float)tw, v0 = (float)sy / (float)th;
    float u1 = (float)(sx + sw) / (float)tw, v1 = (float)(sy + sh) / (float)th;
    float x0 = (float)dx / (float)g_width * 2.0f - 1.0f;
    float y0 = 1.0f - (float)dy / (float)g_height * 2.0f;
    float x1 = (float)(dx + dw) / (float)g_width * 2.0f - 1.0f;
    float y1 = 1.0f - (float)(dy + dh) / (float)g_height * 2.0f;
    float cr = (float)((tint >> 24) & 255) / 255.0f;
    float cg = (float)((tint >> 16) & 255) / 255.0f;
    float cb = (float)((tint >> 8) & 255) / 255.0f;
    float ca = (float)(tint & 255) / 255.0f;
    TexVert *v = g_tstage + g_nsprites * 6;
    v[0] = (TexVert){x0, y0, u0, v0, cr, cg, cb, ca};
    v[1] = (TexVert){x1, y0, u1, v0, cr, cg, cb, ca};
    v[2] = (TexVert){x0, y1, u0, v1, cr, cg, cb, ca};
    v[3] = (TexVert){x1, y0, u1, v0, cr, cg, cb, ca};
    v[4] = (TexVert){x1, y1, u1, v1, cr, cg, cb, ca};
    v[5] = (TexVert){x0, y1, u0, v1, cr, cg, cb, ca};
    SpriteDraw *s = &g_sprites[g_nsprites];
    s->tex = (int)id;
    s->blend = (int)blend;
    s->clip = g_clip_on;
    s->cx = g_clip_x; s->cy = g_clip_y; s->cw = g_clip_w; s->ch = g_clip_h;
    g_nsprites++;
}

void dx_og_clip(long long x, long long y, long long w, long long h) {
    g_clip_x = (int)x; g_clip_y = (int)y; g_clip_w = (int)w; g_clip_h = (int)h;
    g_clip_on = 1;
}
void dx_og_clip_none(void) { g_clip_on = 0; }

/* Draw all recorded sprites after the rects, in record order. One draw call
 * per sprite (few sprites; keeps texture/scissor binding trivial). */
static void tex_flush(UINT frame) {
    if (!g_tex_ok || g_nsprites == 0) return;
    size_t vbase = (size_t)frame * MAX_SPRITES * 6;
    memcpy(g_tvmap + vbase, g_tstage, (size_t)g_nsprites * 6 * sizeof(TexVert));
    D3D12_VIEWPORT vp = {0, 0, (float)g_width, (float)g_height, 0, 1};
    ID3D12GraphicsCommandList_RSSetViewports(g_list, 1, &vp);
    ID3D12DescriptorHeap *heaps[] = {g_srv_heap};
    ID3D12GraphicsCommandList_SetDescriptorHeaps(g_list, 1, heaps);
    ID3D12GraphicsCommandList_SetGraphicsRootSignature(g_list, g_tex_rootsig);
    ID3D12GraphicsCommandList_IASetPrimitiveTopology(g_list,
        D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    D3D12_GPU_DESCRIPTOR_HANDLE base;
    ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart(g_srv_heap, &base);
    D3D12_RECT full = {0, 0, g_width, g_height};
    int cur_blend = -1;
    for (int i = 0; i < g_nsprites; i++) {
        SpriteDraw *s = &g_sprites[i];
        if (s->blend != cur_blend) {
            ID3D12GraphicsCommandList_SetPipelineState(g_list,
                s->blend == 1 ? g_pso_add : g_pso_alpha);
            cur_blend = s->blend;
        }
        D3D12_GPU_DESCRIPTOR_HANDLE h = base;
        h.ptr += (UINT64)s->tex * g_srv_size;
        ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable(g_list, 0, h);
        D3D12_RECT sc = s->clip ? (D3D12_RECT){s->cx, s->cy, s->cx + s->cw,
                                               s->cy + s->ch} : full;
        ID3D12GraphicsCommandList_RSSetScissorRects(g_list, 1, &sc);
        D3D12_VERTEX_BUFFER_VIEW vbv;
        vbv.BufferLocation = ID3D12Resource_GetGPUVirtualAddress(g_tvbuf) +
                             (vbase + (size_t)i * 6) * sizeof(TexVert);
        vbv.StrideInBytes = sizeof(TexVert);
        vbv.SizeInBytes = 6 * sizeof(TexVert);
        ID3D12GraphicsCommandList_IASetVertexBuffers(g_list, 0, 1, &vbv);
        ID3D12GraphicsCommandList_DrawInstanced(g_list, 6, 1, 0, 0);
    }
}

long long dx_og_vsync(long long on) {
    g_vsync = on ? 1 : 0;
    return 1;
}

long long dx_og_caps(void) { return 2; /* 1 = software, 2 = d3d12 */ }

long long dx_og_resize(long long w, long long h) {
    if (!g_swap || w <= 0 || h <= 0) return 0;
    fence_sync(); /* full drain: backbuffers must be unreferenced */
    for (int i = 0; i < FRAME_COUNT; i++) {
        ID3D12Resource_Release(g_backbuf[i]);
        g_backbuf[i] = NULL;
    }
    if (FAILED(IDXGISwapChain3_ResizeBuffers(g_swap, FRAME_COUNT, (UINT)w,
            (UINT)h, DXGI_FORMAT_R8G8B8A8_UNORM,
            g_tearing ? DXGI_SWAP_CHAIN_FLAG_ALLOW_TEARING : 0)))
        return 0;
    D3D12_CPU_DESCRIPTOR_HANDLE rtv;
    ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(g_rtv_heap, &rtv);
    for (int i = 0; i < FRAME_COUNT; i++) {
        IDXGISwapChain3_GetBuffer(g_swap, i, &IID_ID3D12Resource,
                                  (void **)&g_backbuf[i]);
        ID3D12Device_CreateRenderTargetView(g_dev, g_backbuf[i], NULL, rtv);
        rtv.ptr += g_rtv_size;
    }
    g_width = (int)w;
    g_height = (int)h;
    return 1;
}

void dx_og_shutdown(void) {
    if (g_queue) fence_sync();
    /* Deliberately no Release cascade — process exit reclaims
     * everything; a game calls this once. */
}
