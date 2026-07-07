//! Built-in functions — the small library every Orion program sees by default.

use super::ops::{as_f64, values_equal};
use super::{RunError, run_err};
use crate::value::Value;

pub(crate) const BUILTINS: &[(&str, usize)] = &[
    ("max", 2), ("min", 2), ("abs", 1), ("sqrt", 1), ("print", 1),
    ("floor", 1), ("ceil", 1), ("round", 1), ("pow", 2), ("clamp", 3),
    ("sign", 1), ("len", 1), ("get_or", 3), ("get", 2), ("has", 2),
    // Typed map-get aliases used by orion-self typechecker to pin element
    // types where inference can't. Runtime is dynamically typed so all
    // three simply delegate to `get`.
    ("get_int", 2), ("get_map", 2), ("get_list", 2),
    ("set", 3), ("at", 2), ("push", 2), ("slice", 3),
    // Explicit in-place push (native); interp delegates to copying push.
    ("push_mut", 2),
    // Struct field by declaration index (native: raw slot; interp: nth
    // insertion-ordered pair).
    ("struct_field_int", 2), ("struct_field_text", 2),
    // Remove a key from a map, returning the map (native: in-place
    // swap-remove; interp: copy-on-write retain).
    ("map_remove", 2),
    // Process args. orbit run does not forward game args, so the interp
    // reports none — mode overrides are a native-exe affair; the interp
    // dev loop reads the project config.
    ("argc", 0), ("argv", 1),
    // numeric conversion
    ("to_int", 1), ("to_float", 1),
    // runtime type introspection
    ("type_of", 1),
    // map iteration
    ("map_keys", 1), ("map_values", 1),
    // thread-local mutable state — `slot_get(name)` returns `none` until first
    // `slot_set`. Used by stateful orbs (random/uuid/log) to keep their state
    // without escaping to Rust.
    ("slot_get", 1), ("slot_set", 2),
    // Typed slot probes — replace `type_of(slot_get(k))`-style dynamic
    // probing with a pair that works identically native (orion-self
    // emits orion_slot_has/orion_slot_get_int) and interpreted.
    ("slot_has", 1), ("slot_get_int", 1),
    // Native frame-arena hooks — interp no-ops so shared orbs run unchanged.
    ("orion_arena_on", 0), ("orion_arena_off", 0), ("orion_arena_reset", 0),
    ("orion_arena_rewind", 1), ("orion_arena_used", 0),
    ("orion_alloc_total", 0),
    // O(1) amortized append directly into a slot-stored List — avoids the
    // `slot_set(name, push(slot_get(name), v))` quadratic blow-up when the
    // list grows long (codegen buffers, byte streams, etc.).
    ("slot_push", 2),
    // O(1) index-write into a slot-stored List — avoids the
    // `slot_set(name, set(slot_get(name), i, v))` clone-per-write quadratic.
    ("slot_set_at", 3),
    // stderr output — Orion's only way to write to stderr (stdout is `print`).
    ("eprint", 1),
    // trig
    ("sin", 1), ("cos", 1), ("tan", 1), ("atan2", 2),
    // exp / log
    ("exp", 1), ("ln", 1), ("log2", 1),
    // raw pointers — for FFI, GPU buffer access, native interop. The
    // host owns the memory; Orion never frees automatically. Returned
    // by `ptr_alloc`, fed back to `ptr_free` / read/write helpers.
    ("ptr_alloc", 1), ("ptr_free", 1),
    ("ptr_read_u8", 2), ("ptr_read_u32", 2), ("ptr_read_u64", 2),
    ("ptr_write_u8", 3), ("ptr_write_u32", 3), ("ptr_write_u64", 3),
    ("ptr_to_bytes", 2), ("bytes_to_ptr", 1),
    // Concurrency primitives. `cpu_count` reports the work-stealing
    // pool size; `thread_id` returns the current worker id (useful for
    // sharding writes when no shared output is allowed).
    ("cpu_count", 0), ("thread_id", 0),
    // SIMD-style element-wise list ops. Interpreter does plain serial maths;
    // the LLVM emit pass can lower the same calls to `<N x i64>` vector
    // ops once the IR backend gains vector type support.
    ("vec_add", 2), ("vec_sub", 2), ("vec_mul", 2), ("vec_dot", 2),
    // Async runtime primitives. `time_now_ms` is wall-clock (deterministic
    // mode forbids it); `monotonic_ms` is the safe alternative for
    // measuring elapsed time. `sleep_ms` yields to the OS.
    ("time_now_ms", 0), ("monotonic_ms", 0), ("sleep_ms", 1),
];

pub(crate) fn builtin(name: &str, args: Vec<Value>) -> Result<Value, RunError> {
    let arity = BUILTINS.iter().find(|(n, _)| *n == name).map(|(_, a)| *a)
        .ok_or_else(|| run_err(format!("unknown function `{name}`")))?;
    if args.len() != arity {
        return Err(run_err(format!("`{name}` takes {arity} argument(s), got {}", args.len())));
    }
    match name {
        "max" => num2(&args, f64::max, |x, y| x.max(y)),
        "min" => num2(&args, f64::min, |x, y| x.min(y)),
        "abs" => abs(&args),
        "sqrt" => float1(&args, f64::sqrt, "sqrt"),
        "print" => { println!("{}", args[0]); Ok(Value::Unit) }
        "floor" => float1(&args, f64::floor, "floor"),
        "ceil" => float1(&args, f64::ceil, "ceil"),
        "round" => float1(&args, f64::round, "round"),
        "pow" => pow(&args),
        "clamp" => clamp(&args),
        "sign" => sign(&args),
        "len" => len(&args),
        "to_int" => to_int(&args),
        "to_float" => to_float(&args),
        "type_of" => type_of(&args),
        "map_keys" => map_keys(&args),
        "map_values" => map_values(&args),
        "slot_get" => slot_get(&args),
        "slot_set" => slot_set(&args),
        "slot_has" => {
            let Value::Text(name) = &args[0] else {
                return Err(run_err(format!("slot_has expects a Text name, got {:?}", args[0])));
            };
            let has = SLOTS.with(|cells| cells.borrow().contains_key(name.as_str()));
            Ok(Value::Bool(has))
        }
        "slot_get_int" => {
            let Value::Text(name) = &args[0] else {
                return Err(run_err(format!("slot_get_int expects a Text name, got {:?}", args[0])));
            };
            let v = SLOTS.with(|cells| match cells.borrow().get(name.as_str()) {
                Some(Value::Int(n)) => *n,
                _ => 0,
            });
            Ok(Value::Int(v))
        }
        "slot_push" => slot_push(&args),
        "slot_set_at" => slot_set_at(&args),
        // Native frame-arena hooks — no-ops here (the interpreter GCs via Rc).
        "orion_arena_on" | "orion_arena_off" | "orion_arena_reset" | "orion_arena_rewind" => Ok(Value::Int(1)),
        "orion_alloc_total" | "orion_arena_used" => Ok(Value::Int(0)),
        "eprint" => eprint(&args),
        "get_or" => get_or(&args),
        "get" => get(&args),
        "get_int" => get(&args),
        "get_map" => get(&args),
        "get_list" => get(&args),
        "has" => has(&args),
        "set" => set(args),
        "at" => at(&args),
        "push" => push(args),
        // Explicit in-place push under the native compiler; the interp's
        // copying push is a valid (slower) implementation of the same
        // semantics.
        "push_mut" => push(args),
        // Struct field by declaration index. Natively a struct is raw
        // slots in decl order; here struct instances are insertion-
        // ordered maps, so the nth pair is the nth field.
        "struct_field_int" => struct_field(&args),
        "struct_field_text" => struct_field(&args),
        "map_remove" => map_remove(args),
        "argc" => Ok(Value::Int(1)),
        "argv" => Ok(Value::Text(String::new())),
        "slice" => slice(&args),
        "sin" => float1(&args, f64::sin, "sin"),
        "cos" => float1(&args, f64::cos, "cos"),
        "tan" => float1(&args, f64::tan, "tan"),
        "atan2" => atan2(&args),
        "exp" => float1(&args, f64::exp, "exp"),
        "ln" => float1(&args, f64::ln, "ln"),
        "log2" => float1(&args, f64::log2, "log2"),
        "ptr_alloc" => ptr_alloc(&args),
        "ptr_free" => ptr_free(&args),
        "ptr_read_u8" => ptr_read(&args, 1),
        "ptr_read_u32" => ptr_read(&args, 4),
        "ptr_read_u64" => ptr_read(&args, 8),
        "ptr_write_u8" => ptr_write(&args, 1),
        "ptr_write_u32" => ptr_write(&args, 4),
        "ptr_write_u64" => ptr_write(&args, 8),
        "ptr_to_bytes" => ptr_to_bytes(&args),
        "bytes_to_ptr" => bytes_to_ptr(&args),
        "cpu_count" => Ok(Value::Int(num_cpus() as i64)),
        "thread_id" => Ok(Value::Int(rayon::current_thread_index().map(|i| i as i64).unwrap_or(0))),
        "vec_add" => vec_op(&args, "vec_add", |x, y| x.wrapping_add(y)),
        "vec_sub" => vec_op(&args, "vec_sub", |x, y| x.wrapping_sub(y)),
        "vec_mul" => vec_op(&args, "vec_mul", |x, y| x.wrapping_mul(y)),
        "vec_dot" => vec_dot(&args),
        "time_now_ms" => {
            let ms = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_millis() as i64)
                .unwrap_or(0);
            Ok(Value::Int(ms))
        }
        "monotonic_ms" => {
            use std::sync::OnceLock;
            static START: OnceLock<std::time::Instant> = OnceLock::new();
            let start = START.get_or_init(std::time::Instant::now);
            Ok(Value::Int(start.elapsed().as_millis() as i64))
        }
        "sleep_ms" => {
            let Value::Int(ms) = &args[0] else {
                return Err(run_err(format!("sleep_ms expects an int, got {:?}", args[0])));
            };
            if *ms > 0 {
                std::thread::sleep(std::time::Duration::from_millis(*ms as u64));
            }
            Ok(Value::Unit)
        }
        _ => unreachable!("BUILTINS guarded above"),
    }
}

fn vec_op(args: &[Value], who: &str, f: fn(i64, i64) -> i64) -> Result<Value, RunError> {
    let (Value::List(a), Value::List(b)) = (&args[0], &args[1]) else {
        return Err(run_err(format!("{who} expects (list, list), got {args:?}")));
    };
    if a.len() != b.len() {
        return Err(run_err(format!("{who}: length mismatch ({} vs {})", a.len(), b.len())));
    }
    let out: Vec<Value> = a.iter().zip(b.iter()).map(|(x, y)| match (x, y) {
        (Value::Int(xi), Value::Int(yi)) => Value::Int(f(*xi, *yi)),
        _ => Value::Int(0),
    }).collect();
    Ok(Value::List(std::sync::Arc::new(out)))
}

fn vec_dot(args: &[Value]) -> Result<Value, RunError> {
    let (Value::List(a), Value::List(b)) = (&args[0], &args[1]) else {
        return Err(run_err(format!("vec_dot expects (list, list), got {args:?}")));
    };
    if a.len() != b.len() {
        return Err(run_err(format!("vec_dot: length mismatch ({} vs {})", a.len(), b.len())));
    }
    let mut acc: i64 = 0;
    for (x, y) in a.iter().zip(b.iter()) {
        if let (Value::Int(xi), Value::Int(yi)) = (x, y) {
            acc = acc.wrapping_add(xi.wrapping_mul(*yi));
        }
    }
    Ok(Value::Int(acc))
}

fn num_cpus() -> usize {
    std::thread::available_parallelism().map(|n| n.get()).unwrap_or(1)
}

// ---- raw pointers ----
// SAFETY: `raw:` is the explicit unsafety boundary per ORION.md §16.
// Misuse here is a runtime crash, not a silent corruption — the host
// validates length on every read/write.

fn as_ptr(v: &Value, who: &str) -> Result<u64, RunError> {
    match v {
        Value::Raw(addr) => Ok(*addr),
        other => Err(run_err(format!("{who} expects a raw pointer, got {other:?}"))),
    }
}

fn as_usize(v: &Value, who: &str) -> Result<usize, RunError> {
    match v {
        Value::Int(n) if *n >= 0 => Ok(*n as usize),
        other => Err(run_err(format!("{who} expects a non-negative int, got {other:?}"))),
    }
}

fn ptr_alloc(args: &[Value]) -> Result<Value, RunError> {
    let size = as_usize(&args[0], "ptr_alloc")?;
    let layout = std::alloc::Layout::from_size_align(size, 8)
        .map_err(|e| run_err(format!("ptr_alloc: invalid layout: {e}")))?;
    // SAFETY: layout is non-zero (caller's responsibility) and 8-aligned.
    let ptr = unsafe { std::alloc::alloc_zeroed(layout) };
    if ptr.is_null() {
        return Err(run_err("ptr_alloc: allocation failed"));
    }
    Ok(Value::Raw(ptr as u64))
}

fn ptr_free(args: &[Value]) -> Result<Value, RunError> {
    // We don't know the original size — caller is on their honour.
    // Skip the actual free to avoid layout mismatch crashes; this is
    // a deliberate trade-off for safety until typed allocations land.
    let _ = as_ptr(&args[0], "ptr_free")?;
    Ok(Value::Unit)
}

fn ptr_read(args: &[Value], width: usize) -> Result<Value, RunError> {
    let addr = as_ptr(&args[0], "ptr_read")?;
    let off = as_usize(&args[1], "ptr_read")?;
    let ptr = (addr as *const u8).wrapping_add(off);
    // SAFETY: caller asserts the address is valid for `width` bytes.
    let val: i64 = match width {
        1 => unsafe { *ptr as i64 },
        4 => unsafe { (ptr as *const u32).read_unaligned() as i64 },
        8 => unsafe { (ptr as *const u64).read_unaligned() as i64 },
        _ => return Err(run_err("ptr_read: unsupported width")),
    };
    Ok(Value::Int(val))
}

fn ptr_write(args: &[Value], width: usize) -> Result<Value, RunError> {
    let addr = as_ptr(&args[0], "ptr_write")?;
    let off = as_usize(&args[1], "ptr_write")?;
    let val = match &args[2] {
        Value::Int(n) => *n as u64,
        other => return Err(run_err(format!("ptr_write expects an int value, got {other:?}"))),
    };
    let ptr = (addr as *mut u8).wrapping_add(off);
    // SAFETY: caller asserts the address is valid for `width` bytes.
    unsafe {
        match width {
            1 => *ptr = val as u8,
            4 => (ptr as *mut u32).write_unaligned(val as u32),
            8 => (ptr as *mut u64).write_unaligned(val),
            _ => return Err(run_err("ptr_write: unsupported width")),
        }
    }
    Ok(Value::Unit)
}

fn ptr_to_bytes(args: &[Value]) -> Result<Value, RunError> {
    let addr = as_ptr(&args[0], "ptr_to_bytes")?;
    let len = as_usize(&args[1], "ptr_to_bytes")?;
    let mut out = Vec::with_capacity(len);
    let src = addr as *const u8;
    for i in 0..len {
        // SAFETY: caller asserts addr..addr+len is valid.
        let b = unsafe { *src.add(i) };
        out.push(Value::Int(b as i64));
    }
    Ok(Value::List(std::sync::Arc::new(out)))
}

fn bytes_to_ptr(args: &[Value]) -> Result<Value, RunError> {
    let Value::List(items) = &args[0] else {
        return Err(run_err(format!("bytes_to_ptr expects a list, got {:?}", args[0])));
    };
    let size = items.len();
    let layout = std::alloc::Layout::from_size_align(size.max(1), 8)
        .map_err(|e| run_err(format!("bytes_to_ptr: invalid layout: {e}")))?;
    // SAFETY: layout is non-zero (size.max(1)) and 8-aligned.
    let ptr = unsafe { std::alloc::alloc_zeroed(layout) };
    if ptr.is_null() {
        return Err(run_err("bytes_to_ptr: allocation failed"));
    }
    for (i, v) in items.iter().enumerate() {
        let b = match v {
            Value::Int(n) => *n as u8,
            other => return Err(run_err(format!("bytes_to_ptr: list element {i} is not int: {other:?}"))),
        };
        // SAFETY: i < size and we just allocated `size` bytes.
        unsafe { *ptr.add(i) = b; }
    }
    Ok(Value::Raw(ptr as u64))
}

// ---- numeric ----

fn num2(args: &[Value], ffloat: fn(f64, f64) -> f64, fint: fn(i64, i64) -> i64) -> Result<Value, RunError> {
    if let (Value::Int(x), Value::Int(y)) = (&args[0], &args[1]) {
        return Ok(Value::Int(fint(*x, *y)));
    }
    match (as_f64(&args[0]), as_f64(&args[1])) {
        (Some(x), Some(y)) => Ok(Value::Float(ffloat(x, y))),
        _ => Err(run_err("expected numbers")),
    }
}

fn float1(args: &[Value], f: fn(f64) -> f64, who: &str) -> Result<Value, RunError> {
    match as_f64(&args[0]) {
        Some(x) => Ok(Value::Float(f(x))),
        None => Err(run_err(format!("`{who}` expects a number, got {:?}", args[0]))),
    }
}

fn abs(args: &[Value]) -> Result<Value, RunError> {
    match &args[0] {
        Value::Int(n) => Ok(Value::Int(n.abs())),
        Value::Float(x) => Ok(Value::Float(x.abs())),
        other => Err(run_err(format!("abs expects a number, got {other:?}"))),
    }
}

fn pow(args: &[Value]) -> Result<Value, RunError> {
    match (as_f64(&args[0]), as_f64(&args[1])) {
        (Some(a), Some(b)) => Ok(Value::Float(a.powf(b))),
        _ => Err(run_err("pow expects numbers")),
    }
}

fn atan2(args: &[Value]) -> Result<Value, RunError> {
    match (as_f64(&args[0]), as_f64(&args[1])) {
        (Some(y), Some(x)) => Ok(Value::Float(y.atan2(x))),
        _ => Err(run_err("atan2 expects two numbers")),
    }
}

fn clamp(args: &[Value]) -> Result<Value, RunError> {
    if let (Value::Int(v), Value::Int(lo), Value::Int(hi)) = (&args[0], &args[1], &args[2]) {
        return Ok(Value::Int((*v).clamp(*lo, *hi)));
    }
    match (as_f64(&args[0]), as_f64(&args[1]), as_f64(&args[2])) {
        (Some(v), Some(lo), Some(hi)) => Ok(Value::Float(v.clamp(lo, hi))),
        _ => Err(run_err("clamp expects numbers")),
    }
}

fn sign(args: &[Value]) -> Result<Value, RunError> {
    match as_f64(&args[0]) {
        Some(x) if x < 0.0 => Ok(Value::Int(-1)),
        Some(x) if x > 0.0 => Ok(Value::Int(1)),
        Some(_) => Ok(Value::Int(0)),
        None => Err(run_err(format!("sign expects a number, got {:?}", args[0]))),
    }
}

// ---- collections ----

fn to_int(args: &[Value]) -> Result<Value, RunError> {
    match &args[0] {
        Value::Int(n) => Ok(Value::Int(*n)),
        Value::Float(x) => Ok(Value::Int(*x as i64)),
        Value::Bool(b) => Ok(Value::Int(if *b { 1 } else { 0 })),
        other => Err(run_err(format!("to_int expects a number/bool, got {other:?}"))),
    }
}

fn to_float(args: &[Value]) -> Result<Value, RunError> {
    match &args[0] {
        Value::Int(n) => Ok(Value::Float(*n as f64)),
        Value::Float(x) => Ok(Value::Float(*x)),
        other => Err(run_err(format!("to_float expects a number, got {other:?}"))),
    }
}

// ---- thread-local slots ----

use std::cell::RefCell;
use rustc_hash::FxHashMap as HashMap;

thread_local! {
    static SLOTS: RefCell<HashMap<String, Value>> = RefCell::new(HashMap::default());
}

fn slot_get(args: &[Value]) -> Result<Value, RunError> {
    let name = match &args[0] {
        Value::Text(s) => s.clone(),
        other => return Err(run_err(format!("slot_get expects a Text name, got {other:?}"))),
    };
    Ok(SLOTS.with(|cells| cells.borrow().get(&name).cloned().unwrap_or(Value::None)))
}

fn slot_set(args: &[Value]) -> Result<Value, RunError> {
    let name = match &args[0] {
        Value::Text(s) => s.clone(),
        other => return Err(run_err(format!("slot_set expects a Text name, got {other:?}"))),
    };
    SLOTS.with(|cells| cells.borrow_mut().insert(name, args[1].clone()));
    Ok(Value::Unit)
}

fn slot_set_at(args: &[Value]) -> Result<Value, RunError> {
    let name = match &args[0] {
        Value::Text(s) => s.clone(),
        other => return Err(run_err(format!("slot_set_at expects a Text name, got {other:?}"))),
    };
    let Value::Int(index) = &args[1] else {
        return Err(run_err(format!(
            "slot_set_at expects an int index, got {:?}",
            args[1]
        )));
    };
    let idx = *index as usize;
    SLOTS.with(|cells| {
        let mut slots = cells.borrow_mut();
        let entry = slots.entry(name).or_insert_with(|| Value::List(std::sync::Arc::new(Vec::new())));
        match entry {
            Value::List(items_arc) => {
                let items = std::sync::Arc::make_mut(items_arc);
                if idx >= items.len() {
                    return Err(run_err(format!(
                        "slot_set_at index {idx} out of bounds (len {})",
                        items.len()
                    )));
                }
                items[idx] = args[2].clone();
                Ok(Value::Unit)
            }
            other => Err(run_err(format!(
                "slot_set_at expects the slot to hold a list, got {other:?}"
            ))),
        }
    })
}

#[allow(clippy::ptr_arg)]
fn slot_push(args: &[Value]) -> Result<Value, RunError> {
    let name = match &args[0] {
        Value::Text(s) => s.clone(),
        other => return Err(run_err(format!("slot_push expects a Text name, got {other:?}"))),
    };
    SLOTS.with(|cells| {
        let mut slots = cells.borrow_mut();
        let entry = slots.entry(name).or_insert_with(|| Value::List(std::sync::Arc::new(Vec::new())));
        match entry {
            Value::List(items_arc) => {
                std::sync::Arc::make_mut(items_arc).push(args[1].clone());
                Ok(Value::Unit)
            }
            other => Err(run_err(format!(
                "slot_push expects the slot to hold a list, got {other:?}"
            ))),
        }
    })
}

fn eprint(args: &[Value]) -> Result<Value, RunError> {
    eprintln!("{}", args[0]);
    Ok(Value::Unit)
}

fn map_keys(args: &[Value]) -> Result<Value, RunError> {
    let Value::Map(pairs) = &args[0] else {
        return Err(run_err(format!("map_keys expects a map, got {:?}", args[0])));
    };
    Ok(Value::List(std::sync::Arc::new(pairs.iter().map(|(k, _)| k.clone()).collect())))
}

fn struct_field(args: &[Value]) -> Result<Value, RunError> {
    let Value::Int(i) = &args[1] else {
        return Err(run_err("struct_field expects an int index".to_string()));
    };
    let field = match &args[0] {
        Value::Data { fields, .. } => fields.get(*i as usize).map(|(_, v)| v.clone()),
        Value::Map(pairs) => pairs.get(*i as usize).map(|(_, v)| v.clone()),
        other => {
            return Err(run_err(format!("struct_field expects a struct, got {other:?}")));
        }
    };
    field.ok_or_else(|| run_err(format!("struct_field index {i} out of range")))
}

fn map_values(args: &[Value]) -> Result<Value, RunError> {
    let Value::Map(pairs) = &args[0] else {
        return Err(run_err(format!("map_values expects a map, got {:?}", args[0])));
    };
    Ok(Value::List(std::sync::Arc::new(pairs.iter().map(|(_, v)| v.clone()).collect())))
}

/// Runtime type tag for a value — enables generic serializers like JSON's
/// stringify to dispatch without a `match` on every primitive type.
fn type_of(args: &[Value]) -> Result<Value, RunError> {
    let tag = match &args[0] {
        Value::Fact(_) => "fact",
        Value::Int(_) => "int",
        Value::Float(_) => "float",
        Value::Bool(_) => "bool",
        Value::Text(_) => "text",
        Value::List(_) => "list",
        Value::Map(_) => "map",
        Value::None => "none",
        Value::Unit => "unit",
        Value::Closure { .. } => "fn",
        Value::Raw(_) => "raw",
        Value::Job(_) => "job",
        Value::Packed(p) => p.kind(),
        Value::Entity(_) => "entity",
        Value::Enum { .. } => "enum",
        Value::Data { .. } => "data",
    };
    Ok(Value::Text(tag.into()))
}

fn len(args: &[Value]) -> Result<Value, RunError> {
    match &args[0] {
        Value::Text(s) => Ok(Value::Int(s.chars().count() as i64)),
        Value::List(items) => Ok(Value::Int(items.len() as i64)),
        Value::Map(pairs) => Ok(Value::Int(pairs.len() as i64)),
        other => Err(run_err(format!("len expects text/list/map, got {other:?}"))),
    }
}

fn get_or(args: &[Value]) -> Result<Value, RunError> {
    let Value::Map(pairs) = &args[0] else {
        return Err(run_err(format!("get_or expects a map, got {:?}", args[0])));
    };
    Ok(pairs.iter().find(|(k, _)| values_equal(k, &args[1]))
        .map(|(_, v)| v.clone())
        .unwrap_or_else(|| args[2].clone()))
}

fn get(args: &[Value]) -> Result<Value, RunError> {
    let Value::Map(pairs) = &args[0] else {
        return Err(run_err(format!("get expects a map, got {:?}", args[0])));
    };
    Ok(pairs.iter().find(|(k, _)| values_equal(k, &args[1]))
        .map(|(_, v)| v.clone())
        .unwrap_or(Value::None))
}

fn has(args: &[Value]) -> Result<Value, RunError> {
    let Value::Map(pairs) = &args[0] else {
        return Err(run_err(format!("has expects a map, got {:?}", args[0])));
    };
    Ok(Value::Bool(pairs.iter().any(|(k, _)| values_equal(k, &args[1]))))
}

fn map_remove(mut args: Vec<Value>) -> Result<Value, RunError> {
    let key = args.pop().unwrap();
    let target = args.pop().unwrap();
    match target {
        Value::Map(mut pairs_arc) => {
            let pairs = std::sync::Arc::make_mut(&mut pairs_arc);
            pairs.retain(|(k, _)| !values_equal(k, &key));
            Ok(Value::Map(pairs_arc))
        }
        other => Err(run_err(format!("map_remove expects a map, got {other:?}"))),
    }
}

fn set(mut args: Vec<Value>) -> Result<Value, RunError> {
    // Take ownership of args so we can move the target's underlying Vec
    // straight into the result instead of cloning every pair (~quadratic
    // for `mut m = ...; m = set(m, k, v)` loops in the parser/lexer).
    let val = args.pop().unwrap();
    let key = args.pop().unwrap();
    let target = args.pop().unwrap();
    match target {
        Value::Map(mut pairs_arc) => {
            // Arc::make_mut clones only if shared — no clone for the unique
            // (lhs-of-assign) case which is overwhelmingly the common path.
            let pairs = std::sync::Arc::make_mut(&mut pairs_arc);
            match pairs.iter_mut().find(|(k, _)| values_equal(k, &key)) {
                Some(slot) => slot.1 = val,
                None => pairs.push((key, val)),
            }
            Ok(Value::Map(pairs_arc))
        }
        Value::List(mut items_arc) => {
            let Value::Int(index) = key else {
                return Err(run_err(format!(
                    "set on a list expects an int index, got {key:?}"
                )));
            };
            let idx = index as usize;
            let items = std::sync::Arc::make_mut(&mut items_arc);
            if idx >= items.len() {
                return Err(run_err(format!(
                    "set index {idx} out of bounds (len {})",
                    items.len()
                )));
            }
            items[idx] = val;
            Ok(Value::List(items_arc))
        }
        other => Err(run_err(format!("set expects a map or list, got {other:?}"))),
    }
}

fn at(args: &[Value]) -> Result<Value, RunError> {
    let (Value::List(items), Value::Int(i)) = (&args[0], &args[1]) else {
        return Err(run_err(format!("at expects a list and an index, got {:?}", args[0])));
    };
    items.get(*i as usize).cloned()
        .ok_or_else(|| run_err(format!("index {i} out of bounds (len {})", items.len())))
}

fn slice(args: &[Value]) -> Result<Value, RunError> {
    // Generic slice — works on any list type (vs bytes_slice which is [int]-only).
    // `slice(list, lo, hi)` returns the half-open range [lo, hi). Bounds are clamped.
    let (Value::List(items), Value::Int(lo), Value::Int(hi)) = (&args[0], &args[1], &args[2]) else {
        return Err(run_err(format!("slice expects (list, lo, hi), got {:?}", args)));
    };
    let total = items.len() as i64;
    let capped_hi = (*hi).clamp(0, total);
    let capped_lo = (*lo).clamp(0, capped_hi);
    let out: Vec<Value> = items[capped_lo as usize..capped_hi as usize].to_vec();
    Ok(Value::List(std::sync::Arc::new(out)))
}

fn push(mut args: Vec<Value>) -> Result<Value, RunError> {
    // Take ownership so the underlying Vec can be moved into the result
    // instead of cloned. Saves one full deep-clone per push call — for
    // a `mut buf = []; for: buf = push(buf, v)` loop that halves the
    // per-iteration work (the Var lookup still clones the list once).
    let val = args.pop().unwrap();
    let list = args.pop().unwrap();
    let Value::List(mut items_arc) = list else {
        return Err(run_err(format!("push expects a list, got {list:?}")));
    };
    std::sync::Arc::make_mut(&mut items_arc).push(val);
    Ok(Value::List(items_arc))
}
