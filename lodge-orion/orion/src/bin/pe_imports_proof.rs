//! pe_imports_proof — emit a Windows x64 PE that imports kernel32.ExitProcess
//! and calls it with exit code 7. No external linker. Validates the byte
//! layout of the import table before porting to Orion.
//!
//! Layout (file offsets):
//!   0x000  DOS header
//!   0x040  PE\0\0 + COFF header + optional header (240 B)
//!   0x148  2 section headers (.text, .rdata) — 80 B
//!   0x200  .text content (code, RVA 0x1000)
//!   0x400  .rdata content (import table, RVA 0x2000)
//!
//! Import structure within .rdata (offsets from RVA 0x2000):
//!   +0x00  Import Directory Table (1 entry + null terminator = 40 B)
//!   +0x28  Import Lookup Table for kernel32 (1 entry + null terminator = 16 B)
//!   +0x38  Import Address Table for kernel32 (1 entry + null terminator = 16 B)
//!   +0x48  Hint/Name for "ExitProcess" (2 B hint + 12 B name = 14 B, pad to 16)
//!   +0x58  DLL name "kernel32.dll\0" (13 B, pad to 16)

use std::fs;
use std::io::Write;

const FILE_SIZE: usize = 0x600;
const TEXT_FILE_OFF: usize = 0x200;
const RDATA_FILE_OFF: usize = 0x400;

const TEXT_RVA: u32 = 0x1000;
const RDATA_RVA: u32 = 0x2000;

const RDATA_ILT_OFF: u32 = 0x28;
const RDATA_IAT_OFF: u32 = 0x38;
const RDATA_HINTNAME_OFF: u32 = 0x48;
const RDATA_DLLNAME_OFF: u32 = 0x58;
const RDATA_END_OFF: u32 = 0x68;

fn main() {
    let buf = build_pe();
    let path = std::env::args().nth(1).unwrap_or_else(|| "pe_imports.exe".into());
    let mut f = fs::File::create(&path).expect("create");
    f.write_all(&buf).expect("write");
    eprintln!("wrote {} ({} bytes)", path, buf.len());
}

fn build_pe() -> Vec<u8> {
    let mut buf = vec![0u8; FILE_SIZE];

    // ---- DOS header ----
    buf[0] = b'M';
    buf[1] = b'Z';
    wu32(&mut buf, 0x3c, 0x40);

    // ---- PE\0\0 ----
    buf[0x40] = b'P';
    buf[0x41] = b'E';

    // ---- COFF header @ 0x44 ----
    wu16(&mut buf, 0x44, 0x8664);   // Machine: AMD64
    wu16(&mut buf, 0x46, 2);        // NumberOfSections = 2 (.text + .rdata)
    wu16(&mut buf, 0x54, 240);      // SizeOfOptionalHeader
    wu16(&mut buf, 0x56, 0x22);     // EXECUTABLE | LARGE_ADDR_AWARE

    // ---- Optional header @ 0x58 ----
    wu16(&mut buf, 0x58, 0x20b);    // PE32+ magic
    buf[0x5a] = 14;                 // MajorLinkerVersion
    wu32(&mut buf, 0x5c, 0x200);    // SizeOfCode
    wu32(&mut buf, 0x60, 0x200);    // SizeOfInitializedData
    wu32(&mut buf, 0x68, TEXT_RVA); // AddressOfEntryPoint
    wu32(&mut buf, 0x6c, TEXT_RVA); // BaseOfCode

    wu64(&mut buf, 0x70, 0x140000000);  // ImageBase

    wu32(&mut buf, 0x78, 0x1000);   // SectionAlignment
    wu32(&mut buf, 0x7c, 0x200);    // FileAlignment
    wu16(&mut buf, 0x80, 6);        // MajorOSVersion
    wu16(&mut buf, 0x88, 6);        // MajorSubsystemVersion
    wu32(&mut buf, 0x90, 0x3000);   // SizeOfImage (3 pages: header + .text + .rdata)
    wu32(&mut buf, 0x94, 0x200);    // SizeOfHeaders
    wu16(&mut buf, 0x9c, 3);        // CONSOLE subsystem

    wu64(&mut buf, 0xa0, 0x100000); // SizeOfStackReserve
    wu64(&mut buf, 0xa8, 0x1000);   // SizeOfStackCommit
    wu64(&mut buf, 0xb0, 0x100000); // SizeOfHeapReserve
    wu64(&mut buf, 0xb8, 0x1000);   // SizeOfHeapCommit
    wu32(&mut buf, 0xc4, 16);       // NumberOfRvaAndSizes

    // Data Directory[1] = Import Table → starts at RVA_RDATA
    wu32(&mut buf, 0xd0, RDATA_RVA);    // RVA
    wu32(&mut buf, 0xd4, 40);           // Size (one entry + null terminator)

    // Data Directory[12] = Import Address Table (IAT)
    wu32(&mut buf, 0xc8 + 12 * 8, RDATA_RVA + RDATA_IAT_OFF);
    wu32(&mut buf, 0xc8 + 12 * 8 + 4, 16);

    // ---- Section header for .text @ 0x148 ----
    buf[0x148..0x14e].copy_from_slice(b".text\0");
    wu32(&mut buf, 0x150, 16);                  // VirtualSize (code)
    wu32(&mut buf, 0x154, TEXT_RVA);            // VirtualAddress
    wu32(&mut buf, 0x158, 0x200);               // SizeOfRawData
    wu32(&mut buf, 0x15c, TEXT_FILE_OFF as u32);// PointerToRawData
    wu32(&mut buf, 0x16c, 0x60000020);          // CODE | EXEC | READ

    // ---- Section header for .rdata @ 0x170 ----
    buf[0x170..0x176].copy_from_slice(b".rdata");
    wu32(&mut buf, 0x178, RDATA_END_OFF);                   // VirtualSize
    wu32(&mut buf, 0x17c, RDATA_RVA);                       // VirtualAddress
    wu32(&mut buf, 0x180, 0x200);                           // SizeOfRawData
    wu32(&mut buf, 0x184, RDATA_FILE_OFF as u32);           // PointerToRawData
    wu32(&mut buf, 0x194, 0x40000040);                      // INIT_DATA | READ

    // ---- .text section @ 0x200 (RVA 0x1000) ----
    //   sub rsp, 0x28           48 83 EC 28
    //   mov ecx, 7              B9 07 00 00 00
    //   call [rel ExitProcess]  FF 15 disp32
    //
    // disp32 = IAT_RVA - next_instr_RVA
    // Code layout:
    //   0x1000: 48 83 EC 28
    //   0x1004: B9 07 00 00 00
    //   0x1009: FF 15 disp32
    //   0x100F: (next instruction, never reached)
    //
    // IAT_RVA = 0x2038, next_instr_RVA = 0x100F → disp32 = 0x1029.
    buf[TEXT_FILE_OFF + 0] = 0x48;
    buf[TEXT_FILE_OFF + 1] = 0x83;
    buf[TEXT_FILE_OFF + 2] = 0xEC;
    buf[TEXT_FILE_OFF + 3] = 0x28;
    buf[TEXT_FILE_OFF + 4] = 0xB9;
    buf[TEXT_FILE_OFF + 5] = 0x07;
    buf[TEXT_FILE_OFF + 6] = 0x00;
    buf[TEXT_FILE_OFF + 7] = 0x00;
    buf[TEXT_FILE_OFF + 8] = 0x00;
    buf[TEXT_FILE_OFF + 9] = 0xFF;
    buf[TEXT_FILE_OFF + 10] = 0x15;
    let disp32: u32 = (RDATA_RVA + RDATA_IAT_OFF).wrapping_sub(TEXT_RVA + 15);
    wu32(&mut buf, TEXT_FILE_OFF + 11, disp32);

    // ---- .rdata @ 0x400 (RVA 0x2000) ----
    //
    // Import Directory Table @ +0x00 (one entry + null terminator)
    wu32(&mut buf, RDATA_FILE_OFF + 0,  RDATA_RVA + RDATA_ILT_OFF);      // OriginalFirstThunk
    wu32(&mut buf, RDATA_FILE_OFF + 12, RDATA_RVA + RDATA_DLLNAME_OFF);  // Name
    wu32(&mut buf, RDATA_FILE_OFF + 16, RDATA_RVA + RDATA_IAT_OFF);      // FirstThunk
    // 20..40 = null terminator (already zero)

    // ILT @ +0x28: RVA to hint/name | high bit = 0 → import by name
    wu64(
        &mut buf,
        RDATA_FILE_OFF + RDATA_ILT_OFF as usize,
        (RDATA_RVA + RDATA_HINTNAME_OFF) as u64,
    );
    // null terminator (already zero)

    // IAT @ +0x38: same content as ILT initially; loader rewrites to real addr.
    wu64(
        &mut buf,
        RDATA_FILE_OFF + RDATA_IAT_OFF as usize,
        (RDATA_RVA + RDATA_HINTNAME_OFF) as u64,
    );

    // Hint/Name @ +0x48: hint=0, name "ExitProcess\0"
    let hn_off = RDATA_FILE_OFF + RDATA_HINTNAME_OFF as usize;
    buf[hn_off + 2..hn_off + 2 + 11].copy_from_slice(b"ExitProcess");
    // hn_off + 13 = null terminator (already zero)

    // DLL name @ +0x58: "kernel32.dll\0"
    let dn_off = RDATA_FILE_OFF + RDATA_DLLNAME_OFF as usize;
    buf[dn_off..dn_off + 12].copy_from_slice(b"kernel32.dll");

    buf
}

fn wu16(buf: &mut [u8], off: usize, val: u16) {
    buf[off..off + 2].copy_from_slice(&val.to_le_bytes());
}
fn wu32(buf: &mut [u8], off: usize, val: u32) {
    buf[off..off + 4].copy_from_slice(&val.to_le_bytes());
}
fn wu64(buf: &mut [u8], off: usize, val: u64) {
    buf[off..off + 8].copy_from_slice(&val.to_le_bytes());
}
