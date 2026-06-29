//! M7 (honest first slice) — ahead-of-time compilation to a native object file.
//!
//! The JIT (`jit.rs`) compiles in memory. Here we use the *same* code generator
//! (`jit::compile_into`) but with Cranelift's object backend, writing a real
//! `.o`/`.obj` file. That object can be linked into a standalone native binary by
//! the platform's linker — the path to shipping executables without a runtime.
//!
//! This achieves the *spirit* of M7 (fast standalone artifacts). A full LLVM
//! backend (for maximum optimization and mature auto-vectorisation) and explicit
//! SIMD/AoSoA remain their own, larger projects — see ORION.md §19.

use cranelift::prelude::{Configurable, settings};
use cranelift_module::default_libcall_names;
use cranelift_object::{ObjectBuilder, ObjectModule};

use crate::ast::Program;
use crate::jit::compile_into;

/// Compile `root` (and everything it calls) to a native object file at `out`.
/// Returns the number of bytes written.
pub fn compile_object(program: &Program, root: &str, out: &str) -> Result<usize, String> {
    let mut flags = settings::builder();
    // Object code is position-independent so it can be linked anywhere.
    flags.set("is_pic", "true").map_err(|e| e.to_string())?;
    let isa = cranelift_native::builder()
        .map_err(|e| e.to_string())?
        .finish(settings::Flags::new(flags))
        .map_err(|e| e.to_string())?;

    let builder = ObjectBuilder::new(isa, "orion", default_libcall_names()).map_err(|e| e.to_string())?;
    let mut module = ObjectModule::new(builder);

    compile_into(&mut module, program, root)?;

    let product = module.finish();
    let bytes = product.emit().map_err(|e| e.to_string())?;
    std::fs::write(out, &bytes).map_err(|e| e.to_string())?;
    Ok(bytes.len())
}
