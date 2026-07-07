//! `window` — pure-Orion API on top of raw OS window primitives.
//!
//! No winit dep — Orion talks straight to user32 (Windows), Cocoa
//! (macOS), Wayland/X11 (Linux). Each platform impl is gated on
//! `cfg` so cross-compilation works. This module owns the Rust-side
//! FFI broker; the Orion-side API lives in `orbs/window/lib.or`.
//!
//! Architecture: one window per process for now. The Win32 message
//! pump runs on whichever thread first called `window_open`, mirroring
//! how a normal Win32 app would structure things. Events are
//! buffered into a thread-local VecDeque so `window_pump` returns
//! the lot in one go.

use crate::interp::Interp;
use crate::value::Value;

pub const SOURCE: &str = include_str!("../../../orbs/window/lib.or");

pub fn register(interp: &Interp) {
    #[cfg(windows)]
    win32::register(interp);

    #[cfg(not(windows))]
    stub::register(interp);
}

// ---------- platform stubs (non-Windows) ----------
#[cfg(not(windows))]
mod stub {
    use super::*;
    use crate::interp::{run_err, RunError};
    pub fn register(interp: &Interp) {
        interp.register_extern("__os_window_ready", |_| Ok(Value::Bool(false)));
        interp.register_extern("__os_window_open", |_| Err(not_yet()));
        interp.register_extern("__os_window_should_close", |_| Err(not_yet()));
        interp.register_extern("__os_window_pump", |_| Err(not_yet()));
        interp.register_extern("__os_window_swap", |_| Err(not_yet()));
        interp.register_extern("__os_window_close", |_| Err(not_yet()));
    }
    fn not_yet() -> RunError {
        run_err("window orb: backend for this platform not implemented yet — Win32 is live, macOS/Linux on the roadmap")
    }
}

// ---------- Win32 backend ----------
#[cfg(windows)]
mod win32 {
    use super::*;
    use std::cell::RefCell;
    use std::collections::VecDeque;
    use std::ffi::OsStr;
    use std::os::windows::ffi::OsStrExt;
    use std::ptr;

    use windows_sys::Win32::Foundation::{HWND, LPARAM, LRESULT, WPARAM, HINSTANCE};
    use windows_sys::Win32::System::LibraryLoader::GetModuleHandleW;
    use windows_sys::Win32::Graphics::Gdi::UpdateWindow;
    use windows_sys::Win32::UI::WindowsAndMessaging::{
        CreateWindowExW, DefWindowProcW, DestroyWindow, DispatchMessageW, LoadCursorW,
        PeekMessageW, PostQuitMessage, RegisterClassW, ShowWindow, TranslateMessage,
        CS_HREDRAW, CS_OWNDC, CS_VREDRAW, CW_USEDEFAULT, IDC_ARROW, MSG,
        PM_REMOVE, SW_SHOW, WM_CLOSE, WM_DESTROY, WM_KEYDOWN, WM_KEYUP, WM_LBUTTONDOWN,
        WM_LBUTTONUP, WM_MOUSEMOVE, WM_QUIT, WM_RBUTTONDOWN, WM_RBUTTONUP, WM_SIZE,
        WNDCLASSW, WS_OVERLAPPEDWINDOW,
    };

    /// One queued event for the Orion side. Mirrors the
    /// `pub data Event` in `orbs/window/lib.or`.
    #[derive(Clone)]
    struct Event {
        kind: &'static str,
        key: i64,
        x: f64,
        y: f64,
    }

    struct State {
        hwnd: HWND,
        should_close: bool,
        events: VecDeque<Event>,
    }

    thread_local! {
        static STATE: RefCell<Option<State>> = const { RefCell::new(None) };
    }

    pub fn register(interp: &Interp) {
        interp.register_extern("__os_window_ready", |_| Ok(Value::Bool(true)));

        interp.register_extern("__os_window_open", |args| {
            let width = as_i64(args.first()).unwrap_or(800) as i32;
            let height = as_i64(args.get(1)).unwrap_or(600) as i32;
            let title = as_text(args.get(2)).unwrap_or_else(|| "Orion".into());
            let id = open_window(width, height, &title);
            Ok(Value::Int(id))
        });

        interp.register_extern("__os_window_should_close", |_| {
            pump_messages();
            Ok(Value::Bool(STATE.with(|s| s.borrow().as_ref().is_none_or(|st| st.should_close))))
        });

        interp.register_extern("__os_window_pump", |_| {
            pump_messages();
            let events = STATE.with(|s| {
                let mut s = s.borrow_mut();
                let Some(st) = s.as_mut() else { return Vec::new() };
                std::mem::take(&mut st.events).into_iter().collect::<Vec<_>>()
            });
            let list: Vec<Value> = events.into_iter().map(|e| {
                Value::Data {
                    type_name: "Event".into(),
                    fields: vec![
                        ("kind".into(), Value::Text(e.kind.into())),
                        ("key".into(), Value::Int(e.key)),
                        ("x".into(), Value::Float(e.x)),
                        ("y".into(), Value::Float(e.y)),
                    ],
                }
            }).collect();
            Ok(Value::List(std::sync::Arc::new(list)))
        });

        interp.register_extern("__os_window_swap", |_| {
            // GDI-only mode for now: nothing to swap. When the gpu orb
            // owns the context it'll trigger SwapBuffers itself.
            Ok(Value::Unit)
        });

        interp.register_extern("__os_window_close", |_| {
            STATE.with(|s| {
                if let Some(st) = s.borrow_mut().as_mut() {
                    unsafe { DestroyWindow(st.hwnd); }
                    st.should_close = true;
                }
            });
            Ok(Value::Unit)
        });
    }

    fn open_window(width: i32, height: i32, title: &str) -> i64 {
        unsafe {
            let hinstance: HINSTANCE = GetModuleHandleW(ptr::null());
            let class_name = wide("OrionWindow");
            let wnd_class = WNDCLASSW {
                style: CS_HREDRAW | CS_VREDRAW | CS_OWNDC,
                lpfnWndProc: Some(wnd_proc),
                cbClsExtra: 0,
                cbWndExtra: 0,
                hInstance: hinstance,
                hIcon: ptr::null_mut(),
                hCursor: LoadCursorW(ptr::null_mut(), IDC_ARROW),
                hbrBackground: ptr::null_mut(),
                lpszMenuName: ptr::null(),
                lpszClassName: class_name.as_ptr(),
            };
            RegisterClassW(&wnd_class);

            let title_w = wide(title);
            let hwnd = CreateWindowExW(
                0,
                class_name.as_ptr(),
                title_w.as_ptr(),
                WS_OVERLAPPEDWINDOW,
                CW_USEDEFAULT, CW_USEDEFAULT, width, height,
                ptr::null_mut(), ptr::null_mut(), hinstance, ptr::null(),
            );
            ShowWindow(hwnd, SW_SHOW);
            UpdateWindow(hwnd);

            STATE.with(|s| {
                *s.borrow_mut() = Some(State {
                    hwnd,
                    should_close: false,
                    events: VecDeque::new(),
                });
            });
            hwnd as i64
        }
    }

    fn pump_messages() {
        unsafe {
            let mut msg: MSG = std::mem::zeroed();
            let mut count = 0;
            while PeekMessageW(&mut msg, ptr::null_mut(), 0, 0, PM_REMOVE) != 0 {
                count += 1;
                if msg.message == WM_QUIT {
                    STATE.with(|s| { if let Some(st) = s.borrow_mut().as_mut() { st.should_close = true; }});
                    break;
                }
                TranslateMessage(&msg);
                DispatchMessageW(&msg);
            }
            let _ = count;
        }
    }

    unsafe extern "system" fn wnd_proc(hwnd: HWND, msg: u32, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
        match msg {
            WM_CLOSE => {
                push_event(Event { kind: "close", key: 0, x: 0.0, y: 0.0 });
                STATE.with(|s| { if let Some(st) = s.borrow_mut().as_mut() { st.should_close = true; }});
                unsafe { DestroyWindow(hwnd); }
                0
            }
            WM_DESTROY => {
                unsafe { PostQuitMessage(0); }
                0
            }
            WM_KEYDOWN => {
                push_event(Event { kind: "key_down", key: wparam as i64, x: 0.0, y: 0.0 });
                0
            }
            WM_KEYUP => {
                push_event(Event { kind: "key_up", key: wparam as i64, x: 0.0, y: 0.0 });
                0
            }
            WM_MOUSEMOVE => {
                let x = (lparam & 0xFFFF) as i16 as f64;
                let y = ((lparam >> 16) & 0xFFFF) as i16 as f64;
                push_event(Event { kind: "mouse_move", key: 0, x, y });
                0
            }
            WM_LBUTTONDOWN => {
                let x = (lparam & 0xFFFF) as i16 as f64;
                let y = ((lparam >> 16) & 0xFFFF) as i16 as f64;
                push_event(Event { kind: "mouse_down", key: 1, x, y });
                0
            }
            WM_LBUTTONUP => {
                let x = (lparam & 0xFFFF) as i16 as f64;
                let y = ((lparam >> 16) & 0xFFFF) as i16 as f64;
                push_event(Event { kind: "mouse_up", key: 1, x, y });
                0
            }
            WM_RBUTTONDOWN => {
                let x = (lparam & 0xFFFF) as i16 as f64;
                let y = ((lparam >> 16) & 0xFFFF) as i16 as f64;
                push_event(Event { kind: "mouse_down", key: 2, x, y });
                0
            }
            WM_RBUTTONUP => {
                let x = (lparam & 0xFFFF) as i16 as f64;
                let y = ((lparam >> 16) & 0xFFFF) as i16 as f64;
                push_event(Event { kind: "mouse_up", key: 2, x, y });
                0
            }
            WM_SIZE => {
                let w = (lparam & 0xFFFF) as f64;
                let h = ((lparam >> 16) & 0xFFFF) as f64;
                push_event(Event { kind: "resize", key: 0, x: w, y: h });
                0
            }
            _ => unsafe { DefWindowProcW(hwnd, msg, wparam, lparam) },
        }
    }

    fn push_event(e: Event) {
        STATE.with(|s| {
            if let Some(st) = s.borrow_mut().as_mut() { st.events.push_back(e); }
        });
    }

    fn wide(s: &str) -> Vec<u16> {
        OsStr::new(s).encode_wide().chain(std::iter::once(0)).collect()
    }

    fn as_i64(v: Option<&Value>) -> Option<i64> {
        v.and_then(|v| v.as_int())
    }
    fn as_text(v: Option<&Value>) -> Option<String> {
        match v? { Value::Text(s) => Some(s.clone()), other => Some(other.to_string()) }
    }
}
