//! pe_proof — emit a minimal Windows x64 PE that returns exit code 42.
//! No external linker, no C runtime. Validates the byte layout before
//! we re-implement the same emitter in Orion.
//!
//! Layout (file offsets):
//!   0x000  DOS header (64 B). MZ signature + e_lfanew = 0x40.
//!   0x040  "PE\0\0" + COFF header (20 B) + PE32+ optional header (240 B).
//!   0x158  Section header for .text (40 B).
//!   0x200  .text section content (machine code, padded to 0x200).
//!
//! Code: `mov eax, 42; ret`. Windows treats the entry point's RAX value
//! as the process exit code when it returns directly.

use std::fs;
use std::io::Write;

fn main() {
    let pe = build_pe();
    let path = std::env::args().nth(1).unwrap_or_else(|| "pe_proof.exe".into());
    let mut f = fs::File::create(&path).expect("create");
    f.write_all(&pe).expect("write");
    eprintln!("wrote {} ({} bytes)", path, pe.len());
}

fn build_pe() -> Vec<u8> {
    let mut buf = vec![0u8; 0x400]; // 1 KB: headers (0x200) + .text (0x200)

    // ---- DOS header ----
    buf[0] = b'M';
    buf[1] = b'Z';
    write_u32(&mut buf, 0x3c, 0x40); // e_lfanew → PE header at 0x40

    // ---- PE signature ----
    buf[0x40] = b'P';
    buf[0x41] = b'E';
    // 0x42, 0x43 already 0

    // ---- COFF header @ 0x44 (20 bytes) ----
    write_u16(&mut buf, 0x44, 0x8664); // Machine: AMD64
    write_u16(&mut buf, 0x46, 1);      // NumberOfSections
    write_u32(&mut buf, 0x48, 0);      // TimeDateStamp
    write_u32(&mut buf, 0x4c, 0);      // PointerToSymbolTable
    write_u32(&mut buf, 0x50, 0);      // NumberOfSymbols
    write_u16(&mut buf, 0x54, 240);    // SizeOfOptionalHeader (PE32+)
    write_u16(&mut buf, 0x56, 0x22);   // EXECUTABLE_IMAGE | LARGE_ADDRESS_AWARE

    // ---- Optional header @ 0x58 (240 bytes) ----
    write_u16(&mut buf, 0x58, 0x20b);          // Magic: PE32+
    buf[0x5a] = 14;                            // MajorLinkerVersion
    buf[0x5b] = 0;                             // MinorLinkerVersion
    write_u32(&mut buf, 0x5c, 0x200);          // SizeOfCode
    write_u32(&mut buf, 0x60, 0);              // SizeOfInitializedData
    write_u32(&mut buf, 0x64, 0);              // SizeOfUninitializedData
    write_u32(&mut buf, 0x68, 0x1000);         // AddressOfEntryPoint (RVA)
    write_u32(&mut buf, 0x6c, 0x1000);         // BaseOfCode

    // ImageBase (8 bytes for PE32+) @ 0x70
    write_u64(&mut buf, 0x70, 0x140000000);

    write_u32(&mut buf, 0x78, 0x1000);         // SectionAlignment
    write_u32(&mut buf, 0x7c, 0x200);          // FileAlignment
    write_u16(&mut buf, 0x80, 6);              // MajorOSVersion
    write_u16(&mut buf, 0x82, 0);              // MinorOSVersion
    write_u16(&mut buf, 0x84, 0);              // MajorImageVersion
    write_u16(&mut buf, 0x86, 0);              // MinorImageVersion
    write_u16(&mut buf, 0x88, 6);              // MajorSubsystemVersion
    write_u16(&mut buf, 0x8a, 0);              // MinorSubsystemVersion
    write_u32(&mut buf, 0x8c, 0);              // Win32VersionValue
    write_u32(&mut buf, 0x90, 0x2000);         // SizeOfImage
    write_u32(&mut buf, 0x94, 0x200);          // SizeOfHeaders
    write_u32(&mut buf, 0x98, 0);              // CheckSum
    write_u16(&mut buf, 0x9c, 3);              // Subsystem: CONSOLE
    write_u16(&mut buf, 0x9e, 0);              // DllCharacteristics

    write_u64(&mut buf, 0xa0, 0x100000);       // SizeOfStackReserve
    write_u64(&mut buf, 0xa8, 0x1000);         // SizeOfStackCommit
    write_u64(&mut buf, 0xb0, 0x100000);       // SizeOfHeapReserve
    write_u64(&mut buf, 0xb8, 0x1000);         // SizeOfHeapCommit
    write_u32(&mut buf, 0xc0, 0);              // LoaderFlags
    write_u32(&mut buf, 0xc4, 16);             // NumberOfRvaAndSizes
    // 16 data directory entries (8 bytes each) @ 0xc8 — all zero.

    // ---- Section table @ 0x148 ----
    // Name (8 bytes)
    buf[0x148..0x14e].copy_from_slice(b".text\0");
    write_u32(&mut buf, 0x150, 0x200);         // VirtualSize
    write_u32(&mut buf, 0x154, 0x1000);        // VirtualAddress
    write_u32(&mut buf, 0x158, 0x200);         // SizeOfRawData
    write_u32(&mut buf, 0x15c, 0x200);         // PointerToRawData
    write_u32(&mut buf, 0x160, 0);             // PointerToRelocations
    write_u32(&mut buf, 0x164, 0);             // PointerToLinenumbers
    write_u16(&mut buf, 0x168, 0);             // NumberOfRelocations
    write_u16(&mut buf, 0x16a, 0);             // NumberOfLinenumbers
    write_u32(&mut buf, 0x16c, 0x60000020);    // CODE | EXECUTE | READ

    // ---- .text section @ 0x200 ----
    // mov eax, 42      → B8 2A 00 00 00
    // ret              → C3
    buf[0x200] = 0xB8;
    buf[0x201] = 0x2A;
    // 0x202..0x204 already 0
    buf[0x205] = 0xC3;

    buf
}

fn write_u16(buf: &mut [u8], off: usize, val: u16) {
    buf[off..off + 2].copy_from_slice(&val.to_le_bytes());
}

fn write_u32(buf: &mut [u8], off: usize, val: u32) {
    buf[off..off + 4].copy_from_slice(&val.to_le_bytes());
}

fn write_u64(buf: &mut [u8], off: usize, val: u64) {
    buf[off..off + 8].copy_from_slice(&val.to_le_bytes());
}
