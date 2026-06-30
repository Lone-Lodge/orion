//! `gpu` — pure-Orion WebGPU-shaped graphics. Rust-side broker to
//! the native backend. No wgpu/Dawn dep — we own the WebGPU→native
//! translation.
//!
//! v1 backend: Direct3D 12 on Windows. The user-facing API in
//! `orbs/gpu/lib.or` stays WebGPU-shaped (Device, Buffer, Pipeline,
//! CommandBuffer); this file handles device/swap-chain/queue plumbing
//! and exposes simple int handles up to Orion.
//!
//! Shaders for the MVP arrive as HLSL strings (compiled with D3DCompile).
//! WGSL → HLSL translator is a separate orb that drops in later
//! without touching the public API.

use std::cell::RefCell;

use crate::interp::Interp;
use crate::value::Value;

pub const SOURCE: &str = include_str!("../../../orbs/gpu/lib.or");

pub fn register(interp: &Interp) {
    #[cfg(windows)]
    d3d12::register(interp);

    #[cfg(not(windows))]
    stub::register(interp);
}

// ---------- non-Windows stub ----------
#[cfg(not(windows))]
mod stub {
    use super::*;
    pub fn register(interp: &Interp) {
        interp.register_extern("__os_gpu_ready", |_| Ok(Value::Bool(false)));
        interp.register_extern("__os_gpu_backend", |_| Ok(Value::Text("stub".into())));
        for name in [
            "__os_gpu_init", "__os_gpu_create_buffer", "__os_gpu_create_shader",
            "__os_gpu_create_pipeline", "__os_gpu_begin_frame",
        ] {
            interp.register_extern(name, |_| Ok(Value::Int(0)));
        }
        for name in [
            "__os_gpu_write_buffer", "__os_gpu_set_pipeline",
            "__os_gpu_set_vertex_buffer", "__os_gpu_draw",
            "__os_gpu_submit", "__os_gpu_present", "__os_gpu_destroy",
        ] {
            interp.register_extern(name, |_| Ok(Value::Unit));
        }
    }
}

// ---------- Windows / Direct3D 12 backend ----------
#[cfg(windows)]
mod d3d12 {
    use super::*;
    use std::ffi::c_void;
    use windows::core::{Interface, PCSTR};
    use windows::Win32::Foundation::{HWND};
    use windows::Win32::Graphics::Direct3D::{
        Fxc::D3DCompile,
        ID3DBlob, D3D_FEATURE_LEVEL_11_0, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST,
    };
    use windows::Win32::Graphics::Direct3D12::*;
    use windows::Win32::Graphics::Dxgi::{
        Common::*, CreateDXGIFactory1, IDXGIAdapter1, IDXGIFactory4, IDXGISwapChain3,
        DXGI_ADAPTER_FLAG, DXGI_ADAPTER_FLAG_SOFTWARE, DXGI_PRESENT, DXGI_SCALING,
        DXGI_SWAP_CHAIN_DESC1, DXGI_SWAP_EFFECT_FLIP_DISCARD,
        DXGI_USAGE_RENDER_TARGET_OUTPUT,
    };

    const FRAME_COUNT: u32 = 2;

    /// Per-device state. The COM interfaces are held as owned handles
    /// — Drop releases them via the `windows` crate's IUnknown impl.
    struct Device {
        d3d_device: ID3D12Device,
        cmd_queue: ID3D12CommandQueue,
        swap_chain: IDXGISwapChain3,
        rtv_heap: ID3D12DescriptorHeap,
        rtv_descriptor_size: u32,
        render_targets: Vec<ID3D12Resource>,
        cmd_allocator: ID3D12CommandAllocator,
        cmd_list: ID3D12GraphicsCommandList,
        root_sig: Option<ID3D12RootSignature>,
        pipeline_state: Option<ID3D12PipelineState>,
        vertex_buffer: Option<ID3D12Resource>,
        vertex_view: D3D12_VERTEX_BUFFER_VIEW,
        index_buffer: Option<ID3D12Resource>,
        index_view: D3D12_INDEX_BUFFER_VIEW,
        /// Constant-buffer slot 0 — for the MVP matrix or any uniform
        /// block the user pushes via `set_uniform`. 64 floats max,
        /// enough for a 4×4 matrix plus a few extras.
        uniform_buffer: Option<ID3D12Resource>,
        uniform_mapped: *mut f32,
        /// Cached vertex stride from the most recent layout, used so
        /// repeated `write_buffer` calls don't need to re-derive it.
        vertex_stride: u32,
        /// Parsed vertex layout — kept so `build_pipeline` can run
        /// after the user calls `create_pipeline`, in any order with
        /// `write_buffer`.
        layout_spec: String,
        fence: ID3D12Fence,
        fence_value: u64,
        frame_index: u32,
        width: u32,
        height: u32,
    }

    #[derive(Default)]
    struct State {
        devices: Vec<(i64, Device)>,
        next_id: i64,
    }
    impl State {
        fn fresh(&mut self) -> i64 { self.next_id += 1; self.next_id }
        fn dev_mut(&mut self, id: i64) -> Option<&mut Device> {
            self.devices.iter_mut().find(|(d, _)| *d == id).map(|(_, d)| d)
        }
    }

    thread_local! { static STATE: RefCell<State> = RefCell::new(State::default()); }
    thread_local! { static BUF_USAGE: RefCell<std::collections::HashMap<i64, String>> = RefCell::new(std::collections::HashMap::new()); }

    /// Returns the most recently created device id, or 0 if none.
    /// Used by the cmd extern handlers since the Orion side passes the
    /// CommandBuffer handle (not the device) to draw/present.
    fn current_device() -> i64 {
        STATE.with(|s| s.borrow().devices.last().map(|(id, _)| *id).unwrap_or(0))
    }

    pub fn register(interp: &Interp) {
        interp.register_extern("__os_gpu_ready", |_| Ok(Value::Bool(true)));
        interp.register_extern("__os_gpu_backend", |_| Ok(Value::Text("d3d12".into())));

        interp.register_extern("__os_gpu_init", |args| {
            let hwnd = args.first().and_then(|v| v.as_int()).unwrap_or(0);
            // Query the window's actual client area so the backbuffer matches.
            // Avoids the previous 800×600 hardcode that caused stretched / off-screen
            // rendering when the window wasn't that exact size.
            let (mut w, mut h) = (800u32, 600u32);
            #[cfg(windows)]
            unsafe {
                // Use windows_sys (already feature-enabled for WindowsAndMessaging
                // in Cargo.toml) — the `windows` crate is D3D12-only here.
                use windows_sys::Win32::Foundation::{HWND as HwndSys, RECT as RectSys};
                use windows_sys::Win32::UI::WindowsAndMessaging::GetClientRect;
                let mut rect = RectSys { left: 0, top: 0, right: 0, bottom: 0 };
                let hwnd_t = hwnd as HwndSys;
                if GetClientRect(hwnd_t, &mut rect) != 0 {
                    let cw = (rect.right - rect.left) as u32;
                    let ch = (rect.bottom - rect.top) as u32;
                    if cw > 0 && ch > 0 {
                        w = cw;
                        h = ch;
                    }
                }
            }
            match init_device(hwnd as isize, w, h) {
                Ok(id) => Ok(Value::Int(id)),
                Err(e) => Err(crate::interp::run_err(format!("d3d12 init failed: {e:?}"))),
            }
        });

        // The buffer/usage routing happens at write-time: 'vertex' and
        // 'index' set up different views. We track the usage in the
        // upload calls. `create_buffer` is just a fresh handle the
        // user passes back to write_buffer.
        interp.register_extern("__os_gpu_create_buffer", |args| {
            // Hand out a fresh id per buffer and record its usage hint
            // ('vertex' / 'index' / 'uniform') so write_buffer knows
            // where to upload without guessing from data shape.
            let usage = match args.get(2) {
                Some(Value::Text(s)) => s.clone(),
                _ => String::from("vertex"),
            };
            BUF_USAGE.with(|m| {
                let mut m = m.borrow_mut();
                let id = (m.len() as i64) + 1;     // 1-indexed, monotonic
                m.insert(id, usage);
                Ok(Value::Int(id))
            })
        });
        interp.register_extern("__os_gpu_write_buffer", |args| {
            let dev_id = args.first().and_then(|v| v.as_int()).unwrap_or(0);
            let buf_id = args.get(1).and_then(|v| v.as_int()).unwrap_or(1);
            let floats: Vec<f32> = match args.get(2) {
                Some(Value::List(items)) => items.iter().filter_map(|v| match v {
                    Value::Int(n) => Some(*n as f32),
                    Value::Float(x) => Some(*x as f32),
                    Value::Packed(p) => Some(p.widen() as f32),
                    _ => None,
                }).collect(),
                _ => Vec::new(),
            };
            // Dispatch by recorded usage. Falls back to vertex when no
            // usage was recorded (handles tests that bypass create_buffer).
            let usage = BUF_USAGE.with(|m| m.borrow().get(&buf_id).cloned())
                .unwrap_or_else(|| String::from("vertex"));
            match usage.as_str() {
                "index" => {
                    let indices: Vec<u32> = floats.iter().map(|f| *f as u32).collect();
                    let _ = upload_indices(dev_id, &indices);
                }
                _ => {
                    let _ = upload_vertices(dev_id, &floats);
                }
            }
            Ok(Value::Unit)
        });
        interp.register_extern("__os_gpu_create_shader", |_| Ok(Value::Int(1)));
        interp.register_extern("__os_gpu_create_pipeline", |args| {
            let dev_id = args.first().and_then(|v| v.as_int()).unwrap_or(0);
            let layout = match args.get(2) {
                Some(Value::Text(s)) => s.clone(),
                _ => String::from("f32x3"),
            };
            let _ = build_pipeline(dev_id, &layout);
            Ok(Value::Int(1))
        });

        interp.register_extern("__os_gpu_begin_frame", |_| Ok(Value::Int(1)));
        interp.register_extern("__os_gpu_set_pipeline", |_| Ok(Value::Unit));
        interp.register_extern("__os_gpu_set_vertex_buffer", |_| Ok(Value::Unit));
        interp.register_extern("__os_gpu_set_index_buffer", |_| Ok(Value::Unit));
        interp.register_extern("__os_gpu_set_uniform", |args| {
            let dev_id = args.first().and_then(|v| v.as_int()).unwrap_or(0);
            let floats: Vec<f32> = match args.get(2) {
                Some(Value::List(items)) => items.iter().filter_map(|v| match v {
                    Value::Int(n) => Some(*n as f32),
                    Value::Float(x) => Some(*x as f32),
                    Value::Packed(p) => Some(p.widen() as f32),
                    _ => None,
                }).collect(),
                _ => Vec::new(),
            };
            let _ = set_uniform_data(dev_id, &floats);
            Ok(Value::Unit)
        });

        interp.register_extern("__os_gpu_draw", |args| {
            let _cmd = args.first().and_then(|v| v.as_int()).unwrap_or(0);
            let tri_count = args.get(1).and_then(|v| v.as_int()).unwrap_or(1);
            let dev_id = current_device();
            if let Err(e) = record_and_submit(dev_id, tri_count as u32 * 3, false, 0) {
                eprintln!("gpu draw error: {e:?}");
            }
            Ok(Value::Unit)
        });
        interp.register_extern("__os_gpu_draw_indexed", |args| {
            let _cmd = args.first().and_then(|v| v.as_int()).unwrap_or(0);
            let index_count = args.get(1).and_then(|v| v.as_int()).unwrap_or(0);
            let dev_id = current_device();
            if let Err(e) = record_and_submit(dev_id, 0, true, index_count as u32) {
                eprintln!("gpu draw_indexed error: {e:?}");
            }
            Ok(Value::Unit)
        });

        interp.register_extern("__os_gpu_submit", |_| Ok(Value::Unit));
        interp.register_extern("__os_gpu_present", |_args| {
            let dev_id = current_device();
            eprintln!("[present] start dev={dev_id}");
            if let Err(e) = present(dev_id) {
                eprintln!("[present] error: {e:?}");
            }
            eprintln!("[present] done");
            Ok(Value::Unit)
        });
        interp.register_extern("__os_gpu_destroy", |args| {
            let dev_id = args.first().and_then(|v| v.as_int()).unwrap_or(0);
            destroy(dev_id);
            Ok(Value::Unit)
        });

        // Texture upload + sampler binding. The MVP keeps each texture
        // independent: an SRV in the device's shader-resource heap,
        // sampled via a static linear sampler in the root sig.
        interp.register_extern("__os_gpu_create_texture", |args| {
            let dev_id = current_device();
            let width = args.get(1).and_then(|v| v.as_int()).unwrap_or(1) as u32;
            let height = args.get(2).and_then(|v| v.as_int()).unwrap_or(1) as u32;
            let pixels: Vec<f32> = match args.get(3) {
                Some(Value::List(items)) => items.iter().filter_map(|v| match v {
                    Value::Int(n) => Some(*n as f32),
                    Value::Float(x) => Some(*x as f32),
                    Value::Packed(p) => Some(p.widen() as f32),
                    _ => None,
                }).collect(),
                _ => Vec::new(),
            };
            // Convert RGBA float [0..1] → R8G8B8A8 bytes the GPU
            // expects. Real binding lands once the SRV descriptor heap
            // wiring goes in.
            let rgba: Vec<u8> = pixels.iter()
                .map(|f| (f.clamp(0.0, 1.0) * 255.0) as u8)
                .collect();
            let id = upload_texture(dev_id, width, height, &rgba).unwrap_or(0);
            Ok(Value::Int(id))
        });

        interp.register_extern("__os_gpu_set_texture", |_args| {
            // No-op until the SRV descriptor table goes in. The handle
            // is tracked so the binding can wire up later without
            // changing the Orion-side call sites.
            Ok(Value::Unit)
        });
    }

    /// Upload an RGBA byte buffer as a 2D texture resource. Today we
    /// store the resource on the device so `set_texture` can route to
    /// it later; the SRV descriptor heap + root signature update land
    /// alongside the first sampling shader.
    fn upload_texture(dev_id: i64, width: u32, height: u32, rgba: &[u8]) -> Option<i64> {
        // Texture storage is non-trivial — needs an UPLOAD-heap
        // staging buffer, a DEFAULT-heap GPU resource, and a
        // CopyTextureRegion command. The MVP scaffolds the handle so
        // user-facing code can write against the API. Full impl
        // arrives in the texture-sampling milestone.
        let _ = (dev_id, width, height, rgba);
        Some(1)
    }

    fn init_device(hwnd_raw: isize, width: u32, height: u32) -> windows::core::Result<i64> {
        unsafe {
            let hwnd = HWND(hwnd_raw as *mut c_void);

            let factory: IDXGIFactory4 = CreateDXGIFactory1()?;
            let adapter = pick_adapter(&factory)?;
            let mut d3d_device: Option<ID3D12Device> = None;
            D3D12CreateDevice(&adapter, D3D_FEATURE_LEVEL_11_0, &mut d3d_device)?;
            let d3d_device = d3d_device.unwrap();

            let queue_desc = D3D12_COMMAND_QUEUE_DESC {
                Type: D3D12_COMMAND_LIST_TYPE_DIRECT,
                Priority: 0,
                Flags: D3D12_COMMAND_QUEUE_FLAG_NONE,
                NodeMask: 0,
            };
            let cmd_queue: ID3D12CommandQueue = d3d_device.CreateCommandQueue(&queue_desc)?;

            let swap_desc = DXGI_SWAP_CHAIN_DESC1 {
                Width: width,
                Height: height,
                Format: DXGI_FORMAT_R8G8B8A8_UNORM,
                Stereo: false.into(),
                SampleDesc: DXGI_SAMPLE_DESC { Count: 1, Quality: 0 },
                BufferUsage: DXGI_USAGE_RENDER_TARGET_OUTPUT,
                BufferCount: FRAME_COUNT,
                Scaling: DXGI_SCALING(0),
                SwapEffect: DXGI_SWAP_EFFECT_FLIP_DISCARD,
                AlphaMode: DXGI_ALPHA_MODE_UNSPECIFIED,
                Flags: 0,
            };
            let sc1 = factory.CreateSwapChainForHwnd(
                &cmd_queue, hwnd, &swap_desc, None, None)?;
            let swap_chain: IDXGISwapChain3 = sc1.cast()?;

            let rtv_heap: ID3D12DescriptorHeap = d3d_device.CreateDescriptorHeap(
                &D3D12_DESCRIPTOR_HEAP_DESC {
                    Type: D3D12_DESCRIPTOR_HEAP_TYPE_RTV,
                    NumDescriptors: FRAME_COUNT,
                    Flags: D3D12_DESCRIPTOR_HEAP_FLAG_NONE,
                    NodeMask: 0,
                })?;
            let rtv_descriptor_size = d3d_device.GetDescriptorHandleIncrementSize(
                D3D12_DESCRIPTOR_HEAP_TYPE_RTV);

            let mut render_targets = Vec::with_capacity(FRAME_COUNT as usize);
            let mut rtv_handle = rtv_heap.GetCPUDescriptorHandleForHeapStart();
            for i in 0..FRAME_COUNT {
                let rt: ID3D12Resource = swap_chain.GetBuffer(i)?;
                d3d_device.CreateRenderTargetView(&rt, None, rtv_handle);
                rtv_handle.ptr += rtv_descriptor_size as usize;
                render_targets.push(rt);
            }

            let cmd_allocator: ID3D12CommandAllocator =
                d3d_device.CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT)?;
            let cmd_list: ID3D12GraphicsCommandList =
                d3d_device.CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT,
                    &cmd_allocator, None)?;
            cmd_list.Close()?;

            let fence: ID3D12Fence = d3d_device.CreateFence(0, D3D12_FENCE_FLAG_NONE)?;
            let frame_index = swap_chain.GetCurrentBackBufferIndex();

            let id = STATE.with(|s| {
                let mut s = s.borrow_mut();
                let id = s.fresh();
                s.devices.push((id, Device {
                    d3d_device, cmd_queue, swap_chain, rtv_heap, rtv_descriptor_size,
                    render_targets, cmd_allocator, cmd_list,
                    root_sig: None, pipeline_state: None,
                    vertex_buffer: None,
                    vertex_view: D3D12_VERTEX_BUFFER_VIEW {
                        BufferLocation: 0, SizeInBytes: 0, StrideInBytes: 0,
                    },
                    index_buffer: None,
                    index_view: D3D12_INDEX_BUFFER_VIEW {
                        BufferLocation: 0, SizeInBytes: 0, Format: DXGI_FORMAT_UNKNOWN,
                    },
                    uniform_buffer: None,
                    uniform_mapped: std::ptr::null_mut(),
                    vertex_stride: 12,
                    layout_spec: String::from("f32x3"),
                    fence, fence_value: 1, frame_index, width, height,
                }));
                id
            });
            Ok(id)
        }
    }

    unsafe fn pick_adapter(factory: &IDXGIFactory4) -> windows::core::Result<IDXGIAdapter1> {
        unsafe {
            for i in 0.. {
                let adapter = factory.EnumAdapters1(i)?;
                let desc = adapter.GetDesc1()?;
                if (DXGI_ADAPTER_FLAG(desc.Flags as i32) & DXGI_ADAPTER_FLAG_SOFTWARE).0 != 0 {
                    continue;
                }
                if D3D12CreateDevice(&adapter, D3D_FEATURE_LEVEL_11_0,
                    &mut None::<ID3D12Device>).is_ok()
                {
                    return Ok(adapter);
                }
            }
            unreachable!()
        }
    }

    fn make_upload_buffer(device: &ID3D12Device, bytes: u64) -> windows::core::Result<ID3D12Resource> {
        let heap_props = D3D12_HEAP_PROPERTIES {
            Type: D3D12_HEAP_TYPE_UPLOAD,
            CPUPageProperty: D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
            MemoryPoolPreference: D3D12_MEMORY_POOL_UNKNOWN,
            CreationNodeMask: 1,
            VisibleNodeMask: 1,
        };
        let buf_desc = D3D12_RESOURCE_DESC {
            Dimension: D3D12_RESOURCE_DIMENSION_BUFFER,
            Alignment: 0, Width: bytes, Height: 1,
            DepthOrArraySize: 1, MipLevels: 1,
            Format: DXGI_FORMAT_UNKNOWN,
            SampleDesc: DXGI_SAMPLE_DESC { Count: 1, Quality: 0 },
            Layout: D3D12_TEXTURE_LAYOUT_ROW_MAJOR,
            Flags: D3D12_RESOURCE_FLAG_NONE,
        };
        let mut res: Option<ID3D12Resource> = None;
        unsafe {
            device.CreateCommittedResource(
                &heap_props, D3D12_HEAP_FLAG_NONE,
                &buf_desc, D3D12_RESOURCE_STATE_GENERIC_READ,
                None, &mut res)?;
        }
        Ok(res.unwrap())
    }

    fn upload_vertices(dev_id: i64, floats: &[f32]) -> windows::core::Result<()> {
        let bytes = (floats.len() * std::mem::size_of::<f32>()) as u64;
        STATE.with(|s| -> windows::core::Result<()> {
            let mut s = s.borrow_mut();
            let Some(d) = s.dev_mut(dev_id) else { return Ok(()) };
            let vb = make_upload_buffer(&d.d3d_device, bytes)?;
            unsafe {
                let mut mapped: *mut c_void = std::ptr::null_mut();
                vb.Map(0, None, Some(&mut mapped))?;
                std::ptr::copy_nonoverlapping(floats.as_ptr() as *const u8,
                    mapped as *mut u8, bytes as usize);
                vb.Unmap(0, None);
                let gpu_va = vb.GetGPUVirtualAddress();
                d.vertex_view = D3D12_VERTEX_BUFFER_VIEW {
                    BufferLocation: gpu_va,
                    SizeInBytes: bytes as u32,
                    StrideInBytes: d.vertex_stride,
                };
            }
            d.vertex_buffer = Some(vb);
            Ok(())
        })
    }

    fn upload_indices(dev_id: i64, indices: &[u32]) -> windows::core::Result<()> {
        let bytes = (indices.len() * std::mem::size_of::<u32>()) as u64;
        STATE.with(|s| -> windows::core::Result<()> {
            let mut s = s.borrow_mut();
            let Some(d) = s.dev_mut(dev_id) else { return Ok(()) };
            let ib = make_upload_buffer(&d.d3d_device, bytes)?;
            unsafe {
                let mut mapped: *mut c_void = std::ptr::null_mut();
                ib.Map(0, None, Some(&mut mapped))?;
                std::ptr::copy_nonoverlapping(indices.as_ptr() as *const u8,
                    mapped as *mut u8, bytes as usize);
                ib.Unmap(0, None);
                let gpu_va = ib.GetGPUVirtualAddress();
                d.index_view = D3D12_INDEX_BUFFER_VIEW {
                    BufferLocation: gpu_va,
                    SizeInBytes: bytes as u32,
                    Format: DXGI_FORMAT_R32_UINT,
                };
            }
            d.index_buffer = Some(ib);
            Ok(())
        })
    }

    fn set_uniform_data(dev_id: i64, floats: &[f32]) -> windows::core::Result<()> {
        STATE.with(|s| -> windows::core::Result<()> {
            let mut s = s.borrow_mut();
            let Some(d) = s.dev_mut(dev_id) else { return Ok(()) };
            // D3D12 constant buffers must be 256-byte aligned.
            const CB_SIZE: u64 = 256;
            if d.uniform_buffer.is_none() {
                let cb = make_upload_buffer(&d.d3d_device, CB_SIZE)?;
                unsafe {
                    let mut mapped: *mut c_void = std::ptr::null_mut();
                    cb.Map(0, None, Some(&mut mapped))?;
                    d.uniform_mapped = mapped as *mut f32;
                }
                d.uniform_buffer = Some(cb);
            }
            let n = floats.len().min(64);
            unsafe {
                std::ptr::copy_nonoverlapping(
                    floats.as_ptr(), d.uniform_mapped, n);
            }
            Ok(())
        })
    }

    /// Parse a vertex layout spec like `"f32x3"` or `"f32x3,f32x2"`
    /// into (D3D12 input elements, total stride bytes).
    fn parse_layout(spec: &str) -> (Vec<D3D12_INPUT_ELEMENT_DESC>, u32) {
        // Static semantic names — the strings must outlive the desc
        // structs so we leak them deliberately. There are only a few
        // distinct semantics in any project, so the leak is bounded.
        fn static_semantic(n: usize) -> &'static [u8] {
            match n {
                0 => b"POSITION\0",
                1 => b"TEXCOORD\0",
                2 => b"COLOR\0",
                3 => b"NORMAL\0",
                4 => b"TANGENT\0",
                _ => b"TEXCOORD\0",
            }
        }
        let mut elems = Vec::new();
        let mut offset: u32 = 0;
        for (index, part) in spec.split(',').map(|s| s.trim()).enumerate() {
            let (fmt, bytes) = match part {
                "f32x1" | "f32" => (DXGI_FORMAT_R32_FLOAT, 4),
                "f32x2" => (DXGI_FORMAT_R32G32_FLOAT, 8),
                "f32x3" => (DXGI_FORMAT_R32G32B32_FLOAT, 12),
                "f32x4" => (DXGI_FORMAT_R32G32B32A32_FLOAT, 16),
                _ => (DXGI_FORMAT_R32G32B32_FLOAT, 12),
            };
            elems.push(D3D12_INPUT_ELEMENT_DESC {
                SemanticName: PCSTR(static_semantic(index).as_ptr()),
                SemanticIndex: 0,
                Format: fmt,
                InputSlot: 0,
                AlignedByteOffset: offset,
                InputSlotClass: D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA,
                InstanceDataStepRate: 0,
            });
            offset += bytes;
        }
        (elems, offset)
    }

    fn build_pipeline(dev_id: i64, layout_spec: &str) -> windows::core::Result<()> {
        STATE.with(|s| -> windows::core::Result<()> {
            let mut s = s.borrow_mut();
            let Some(d) = s.dev_mut(dev_id) else { return Ok(()) };
            d.layout_spec = layout_spec.to_string();
            let (input_layout, stride) = parse_layout(layout_spec);
            d.vertex_stride = stride;
            // Refresh the existing vertex view's stride if we already
            // uploaded vertices before the pipeline was built.
            if d.vertex_view.SizeInBytes != 0 {
                d.vertex_view.StrideInBytes = stride;
            }

            // Root signature with one root CBV (slot 0) for the MVP
            // matrix uniform. WGSL @group(0) @binding(0) maps here.
            let root_param = D3D12_ROOT_PARAMETER {
                ParameterType: D3D12_ROOT_PARAMETER_TYPE_CBV,
                ShaderVisibility: D3D12_SHADER_VISIBILITY_VERTEX,
                Anonymous: D3D12_ROOT_PARAMETER_0 {
                    Descriptor: D3D12_ROOT_DESCRIPTOR {
                        ShaderRegister: 0,
                        RegisterSpace: 0,
                    },
                },
            };
            let root_params = [root_param];
            let root_desc = D3D12_ROOT_SIGNATURE_DESC {
                NumParameters: root_params.len() as u32,
                pParameters: root_params.as_ptr(),
                NumStaticSamplers: 0,
                pStaticSamplers: std::ptr::null(),
                Flags: D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT,
            };
            let mut signature: Option<ID3DBlob> = None;
            let mut error: Option<ID3DBlob> = None;
            unsafe {
                D3D12SerializeRootSignature(&root_desc,
                    D3D_ROOT_SIGNATURE_VERSION_1, &mut signature, Some(&mut error))?;
            }
            let signature = signature.unwrap();
            let sig_slice = unsafe { std::slice::from_raw_parts(
                signature.GetBufferPointer() as *const u8,
                signature.GetBufferSize()) };
            let root_sig: ID3D12RootSignature = unsafe {
                d.d3d_device.CreateRootSignature(0, sig_slice)?
            };

            // Tiny built-in HLSL — uses MVP matrix from cbuffer at b0
            // when bound, otherwise falls through with identity-ish
            // behaviour. Honors a second f32x3 attribute as colour if
            // the layout spec includes it.
            let hlsl: &[u8] = if layout_spec.contains(',') {
                b"
                cbuffer Globals : register(b0) {
                    float4x4 mvp;
                };
                struct VSIn  { float3 pos : POSITION; float3 col : TEXCOORD; };
                struct VSOut { float4 pos : SV_POSITION; float3 col : COLOR; };
                VSOut VSMain(VSIn input) {
                    VSOut o;
                    o.pos = mul(mvp, float4(input.pos, 1.0));
                    o.col = input.col;
                    return o;
                }
                float4 PSMain(VSOut input) : SV_TARGET {
                    return float4(input.col, 1.0);
                }\0"
            } else {
                b"
                cbuffer Globals : register(b0) {
                    float4x4 mvp;
                };
                struct VSIn  { float3 pos : POSITION; };
                struct VSOut { float4 pos : SV_POSITION; float3 col : COLOR; };
                VSOut VSMain(VSIn input, uint vid : SV_VertexID) {
                    VSOut o;
                    o.pos = mul(mvp, float4(input.pos, 1.0));
                    float3 colors[3] = {
                        float3(0.95, 0.25, 0.55),
                        float3(0.55, 0.25, 0.95),
                        float3(0.25, 0.95, 0.55)
                    };
                    o.col = colors[vid % 3];
                    return o;
                }
                float4 PSMain(VSOut input) : SV_TARGET {
                    return float4(input.col, 1.0);
                }\0"
            };

            let (vs_blob, ps_blob) = unsafe {
                let mut vs: Option<ID3DBlob> = None;
                let mut ps: Option<ID3DBlob> = None;
                let mut err: Option<ID3DBlob> = None;
                D3DCompile(hlsl.as_ptr() as *const c_void, hlsl.len() - 1,
                    PCSTR::null(), None, None,
                    PCSTR(b"VSMain\0".as_ptr()), PCSTR(b"vs_5_0\0".as_ptr()),
                    0, 0, &mut vs, Some(&mut err))?;
                D3DCompile(hlsl.as_ptr() as *const c_void, hlsl.len() - 1,
                    PCSTR::null(), None, None,
                    PCSTR(b"PSMain\0".as_ptr()), PCSTR(b"ps_5_0\0".as_ptr()),
                    0, 0, &mut ps, Some(&mut err))?;
                (vs.unwrap(), ps.unwrap())
            };

            let mut pso_desc: D3D12_GRAPHICS_PIPELINE_STATE_DESC = unsafe { std::mem::zeroed() };
            pso_desc.pRootSignature = unsafe { std::mem::transmute_copy(&root_sig) };
            pso_desc.VS = D3D12_SHADER_BYTECODE {
                pShaderBytecode: unsafe { vs_blob.GetBufferPointer() },
                BytecodeLength: unsafe { vs_blob.GetBufferSize() },
            };
            pso_desc.PS = D3D12_SHADER_BYTECODE {
                pShaderBytecode: unsafe { ps_blob.GetBufferPointer() },
                BytecodeLength: unsafe { ps_blob.GetBufferSize() },
            };
            pso_desc.RasterizerState.FillMode = D3D12_FILL_MODE_SOLID;
            pso_desc.RasterizerState.CullMode = D3D12_CULL_MODE_NONE;
            pso_desc.RasterizerState.DepthClipEnable = true.into();
            pso_desc.BlendState.RenderTarget[0].RenderTargetWriteMask =
                D3D12_COLOR_WRITE_ENABLE_ALL.0 as u8;
            pso_desc.DepthStencilState.DepthEnable = false.into();
            pso_desc.DepthStencilState.StencilEnable = false.into();
            pso_desc.SampleMask = u32::MAX;
            pso_desc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
            pso_desc.NumRenderTargets = 1;
            pso_desc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
            pso_desc.SampleDesc.Count = 1;
            pso_desc.InputLayout = D3D12_INPUT_LAYOUT_DESC {
                pInputElementDescs: input_layout.as_ptr(),
                NumElements: input_layout.len() as u32,
            };

            let pso: ID3D12PipelineState = unsafe {
                d.d3d_device.CreateGraphicsPipelineState(&pso_desc)?
            };
            d.root_sig = Some(root_sig);
            d.pipeline_state = Some(pso);
            Ok(())
        })
    }

    fn record_and_submit(
        dev_id: i64,
        vertex_count: u32,
        indexed: bool,
        index_count: u32,
    ) -> windows::core::Result<()> {
        STATE.with(|s| -> windows::core::Result<()> {
            let mut s = s.borrow_mut();
            let Some(d) = s.dev_mut(dev_id) else { return Ok(()) };
            let (Some(root), Some(pso)) = (d.root_sig.clone(), d.pipeline_state.clone()) else {
                return Ok(());
            };
            unsafe {
                d.cmd_allocator.Reset()?;
                d.cmd_list.Reset(&d.cmd_allocator, &pso)?;
                d.cmd_list.SetGraphicsRootSignature(&root);

                // Bind the uniform constant buffer if one exists.
                if let Some(cb) = d.uniform_buffer.as_ref() {
                    let gpu_va = cb.GetGPUVirtualAddress();
                    d.cmd_list.SetGraphicsRootConstantBufferView(0, gpu_va);
                }

                let viewport = D3D12_VIEWPORT {
                    TopLeftX: 0.0, TopLeftY: 0.0,
                    Width: d.width as f32, Height: d.height as f32,
                    MinDepth: 0.0, MaxDepth: 1.0,
                };
                let scissor = windows::Win32::Foundation::RECT {
                    left: 0, top: 0, right: d.width as i32, bottom: d.height as i32,
                };
                d.cmd_list.RSSetViewports(&[viewport]);
                d.cmd_list.RSSetScissorRects(&[scissor]);

                let rt = &d.render_targets[d.frame_index as usize];
                let barrier = barrier_transition(rt,
                    D3D12_RESOURCE_STATE_PRESENT, D3D12_RESOURCE_STATE_RENDER_TARGET);
                d.cmd_list.ResourceBarrier(&[barrier]);

                let mut rtv = d.rtv_heap.GetCPUDescriptorHandleForHeapStart();
                rtv.ptr += (d.frame_index * d.rtv_descriptor_size) as usize;
                d.cmd_list.OMSetRenderTargets(1, Some(&rtv), false, None);

                let clear: [f32; 4] = [0.05, 0.06, 0.10, 1.0];   // near-black for visible blocks
                d.cmd_list.ClearRenderTargetView(rtv, &clear, None);

                d.cmd_list.IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
                d.cmd_list.IASetVertexBuffers(0, Some(&[d.vertex_view]));
                if indexed {
                    d.cmd_list.IASetIndexBuffer(Some(&d.index_view));
                    d.cmd_list.DrawIndexedInstanced(index_count, 1, 0, 0, 0);
                } else {
                    d.cmd_list.DrawInstanced(vertex_count, 1, 0, 0);
                }

                let barrier_back = barrier_transition(rt,
                    D3D12_RESOURCE_STATE_RENDER_TARGET, D3D12_RESOURCE_STATE_PRESENT);
                d.cmd_list.ResourceBarrier(&[barrier_back]);
                d.cmd_list.Close()?;

                let list = d.cmd_list.cast::<ID3D12CommandList>()?;
                d.cmd_queue.ExecuteCommandLists(&[Some(list)]);
            }
            Ok(())
        })
    }

    fn present(dev_id: i64) -> windows::core::Result<()> {
        STATE.with(|s| -> windows::core::Result<()> {
            let mut s = s.borrow_mut();
            let Some(d) = s.dev_mut(dev_id) else { return Ok(()) };
            unsafe {
                if let Err(e) = d.swap_chain.Present(1, DXGI_PRESENT(0)).ok() {
                    eprintln!("[present] Present failed: {e:?}");
                    return Err(e);
                }
                let fence_val = d.fence_value;
                if let Err(e) = d.cmd_queue.Signal(&d.fence, fence_val) {
                    eprintln!("[present] Signal failed: {e:?}");
                    return Err(e);
                }
                d.fence_value += 1;
                let mut waited = 0u32;
                while d.fence.GetCompletedValue() < fence_val {
                    std::thread::yield_now();
                    waited += 1;
                    if waited > 100_000 {
                        eprintln!("[present] fence wait stalled at frame, val={fence_val} got={}", d.fence.GetCompletedValue());
                        break;
                    }
                }
                d.frame_index = d.swap_chain.GetCurrentBackBufferIndex();
            }
            Ok(())
        })
    }

    fn destroy(dev_id: i64) {
        STATE.with(|s| {
            let mut s = s.borrow_mut();
            if let Some(pos) = s.devices.iter().position(|(id, _)| *id == dev_id) {
                let _ = s.devices.swap_remove(pos);
            }
        });
    }

    fn barrier_transition(
        resource: &ID3D12Resource,
        before: D3D12_RESOURCE_STATES,
        after: D3D12_RESOURCE_STATES,
    ) -> D3D12_RESOURCE_BARRIER {
        D3D12_RESOURCE_BARRIER {
            Type: D3D12_RESOURCE_BARRIER_TYPE_TRANSITION,
            Flags: D3D12_RESOURCE_BARRIER_FLAG_NONE,
            Anonymous: D3D12_RESOURCE_BARRIER_0 {
                Transition: std::mem::ManuallyDrop::new(D3D12_RESOURCE_TRANSITION_BARRIER {
                    pResource: unsafe { std::mem::transmute_copy(resource) },
                    Subresource: D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,
                    StateBefore: before,
                    StateAfter: after,
                }),
            },
        }
    }
}
