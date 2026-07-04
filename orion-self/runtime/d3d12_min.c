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
static ID3D12Fence         *g_fence;
static HANDLE               g_fence_evt;
static UINT64               g_fence_val;
static UINT64               g_frame_fence[FRAME_COUNT]; /* last submit per slot */
static UINT                 g_rtv_size;
static int                  g_width, g_height;
static int                  g_nverts;
static int                  g_frame;     /* current backbuffer slot */
static int                  g_vsync = 0; /* uncapped by default; og_vsync opts in */
static int                  g_tearing = 0;
static float                g_clear[4];

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
    g_clear[0] = (float)r / 255.0f;
    g_clear[1] = (float)g / 255.0f;
    g_clear[2] = (float)b / 255.0f;
    g_clear[3] = 1.0f;
}

/* Append one rect = 2 triangles = 6 verts. Pixel coords → NDC here so
 * the shader stays a passthrough. */
void dx_og_rect(long long x, long long y, long long w, long long h,
              long long r, long long g, long long b) {
    if (g_nverts + 6 > MAX_VERTS) return;
    float x0 = (float)x / (float)g_width * 2.0f - 1.0f;
    float y0 = 1.0f - (float)y / (float)g_height * 2.0f;
    float x1 = (float)(x + w) / (float)g_width * 2.0f - 1.0f;
    float y1 = 1.0f - (float)(y + h) / (float)g_height * 2.0f;
    float cr = (float)r / 255.0f, cg = (float)g / 255.0f,
          cb = (float)b / 255.0f;
    Vert *v = g_vmap + (size_t)g_frame * MAX_VERTS + g_nverts;
    v[0] = (Vert){x0, y0, cr, cg, cb, 1};
    v[1] = (Vert){x1, y0, cr, cg, cb, 1};
    v[2] = (Vert){x0, y1, cr, cg, cb, 1};
    v[3] = (Vert){x1, y0, cr, cg, cb, 1};
    v[4] = (Vert){x1, y1, cr, cg, cb, 1};
    v[5] = (Vert){x0, y1, cr, cg, cb, 1};
    g_nverts += 6;
}

long long dx_og_present(void) {
    UINT frame = (UINT)g_frame;

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
