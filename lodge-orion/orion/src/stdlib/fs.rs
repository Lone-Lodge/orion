//! `fs` — directory ops and file metadata. Public API is pure Orion
//! (`orbs/fs/lib.or`); only the OS bridges stay native.

use std::fs;

use crate::interp::Interp;
use crate::value::Value;

pub const SOURCE: &str = include_str!("../../../orbs/fs/lib.or");

pub fn register(interp: &Interp) {
    interp.register_extern("__os_list_dir", |args| {
        let path = as_text(&args[0]);
        let entries: Vec<Value> = fs::read_dir(&path)
            .ok()
            .map(|it| {
                it.filter_map(|e| e.ok())
                    .map(|e| Value::Text(e.file_name().to_string_lossy().into_owned()))
                    .collect()
            })
            .unwrap_or_default();
        Ok(Value::List(std::sync::Arc::new(entries)))
    });
    interp.register_extern("__os_mkdir", |args| {
        Ok(Value::Bool(fs::create_dir(as_text(&args[0])).is_ok()))
    });
    interp.register_extern("__os_mkdir_all", |args| {
        Ok(Value::Bool(fs::create_dir_all(as_text(&args[0])).is_ok()))
    });
    interp.register_extern("__os_rmdir", |args| {
        Ok(Value::Bool(fs::remove_dir(as_text(&args[0])).is_ok()))
    });
    interp.register_extern("__os_remove_file", |args| {
        Ok(Value::Bool(fs::remove_file(as_text(&args[0])).is_ok()))
    });
    interp.register_extern("__os_copy_file", |args| {
        Ok(Value::Bool(
            fs::copy(as_text(&args[0]), as_text(&args[1])).is_ok(),
        ))
    });
    interp.register_extern("__os_rename", |args| {
        Ok(Value::Bool(
            fs::rename(as_text(&args[0]), as_text(&args[1])).is_ok(),
        ))
    });
    interp.register_extern("__os_file_size", |args| {
        let size = fs::metadata(as_text(&args[0]))
            .map(|m| m.len() as i64)
            .unwrap_or(-1);
        Ok(Value::Int(size))
    });
    interp.register_extern("__os_is_dir", |args| {
        Ok(Value::Bool(
            fs::metadata(as_text(&args[0]))
                .map(|m| m.is_dir())
                .unwrap_or(false),
        ))
    });
    interp.register_extern("__os_is_file", |args| {
        Ok(Value::Bool(
            fs::metadata(as_text(&args[0]))
                .map(|m| m.is_file())
                .unwrap_or(false),
        ))
    });
}

fn as_text(v: &Value) -> String {
    match v {
        Value::Text(s) => s.clone(),
        other => other.to_string(),
    }
}
