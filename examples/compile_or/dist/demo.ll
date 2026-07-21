; orion_emit_llvm output
target datalayout = "e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc19.44.35209"
declare i32 @printf(ptr, ...)
declare i32 @puts(ptr)
declare ptr @malloc(i64)
declare ptr @orion_f64_literal_hex(ptr)
declare ptr @orion_alloc(i64)
declare i64 @orion_arena_init(i64)
declare i64 @orion_arena_on()
declare i64 @orion_arena_off()
declare i64 @orion_arena_active()
declare i64 @orion_frame_init(i64)
declare i64 @orion_frame_on()
declare i64 @orion_frame_off()
declare i64 @orion_frame_reset()
declare i64 @orion_frame_used()
declare i64 @orion_persist_on()
declare i64 @orion_persist_off()
declare i64 @orion_pool_alloc()
declare i64 @orion_pool_on(i64)
declare i64 @orion_pool_off()
declare i64 @orion_pool_reset(i64)
declare i64 @orion_arena_reset()
declare i64 @orion_arena_used()
declare i64 @orion_arena_rewind(i64)
declare i64 @orion_arena_high()
declare i64 @orion_alloc_total()
declare i64 @orion_arena_cap()
declare i64 @orion_frame_high()
declare i64 @orion_frame_cap()
declare i64 @orion_pool_used(i64)
declare i64 @orion_pool_pressure(i64)
declare i64 @orion_ledger_tag(ptr)
declare i64 @orion_ledger_off()
declare i64 @orion_ledger_dump()
declare i64 @orion_pool_high(i64)
declare i64 @orion_pool_cap(i64)
declare i64 @orion_os_private_kb()
declare i64 @orion_console_color()
declare i64 @orion_alloc_malloc_total()
declare i64 @orion_embedded_has(ptr)
declare ptr @orion_embedded_text(ptr)
declare ptr @orion_embedded_list()
declare ptr @orion_dir_list(ptr)
declare ptr @orion_dir_subdirs(ptr)
declare ptr @orion_console_readline()
declare ptr @orion_key_copy(ptr)
declare i64 @orion_file_stamp(ptr)
declare i64 @orion_audio_init()
declare i64 @orion_audio_load(ptr)
declare i64 @orion_audio_play(i64, i64, i64, i64, i64)
declare i64 @orion_audio_loop(i64, i64, i64, i64, i64, i64)
declare i64 @orion_audio_voice_gain(i64, i64, i64)
declare i64 @orion_audio_stop_voice(i64, i64)
declare i64 @orion_audio_music(i64, i64, i64)
declare i64 @orion_audio_layer(i64, i64, i64)
declare i64 @orion_audio_stop_music(i64)
declare i64 @orion_audio_bus_gain(i64, i64, i64)
declare i64 @orion_audio_playing()
declare i64 @orion_audio_debug_plays()
declare void @orion_audio_shutdown()
declare void @orion_arena_ptr_guard(ptr, ptr)
declare ptr @orion_slot_evac(ptr, ptr, i64)
declare void @orion_crumb(ptr, ptr, i64)
declare void @orion_crumb_rule(ptr)
declare double @sqrt(double)
declare double @sin(double)
declare double @cos(double)
declare double @tan(double)
declare double @exp(double)
declare double @log(double)
declare double @log2(double)
declare double @floor(double)
declare double @ceil(double)
declare double @round(double)
declare double @atan2(double, double)
declare double @pow(double, double)
@orion_err_count = global i64 0
define i64 @orion_err_bump() {
entry:
  %n = load i64, ptr @orion_err_count
  %n1 = add i64 %n, 1
  store i64 %n1, ptr @orion_err_count
  ret i64 %n1
}
define i64 @orion_err_get() {
entry:
  %n = load i64, ptr @orion_err_count
  ret i64 %n
}

define ptr @orion_text_join(ptr %parts) {
entry:
  %n = call i64 @orion_list_len(ptr %parts)
  br label %sum_hdr
sum_hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %sum_bdy ]
  %total = phi i64 [ 0, %entry ], [ %total_next, %sum_bdy ]
  %done = icmp sge i64 %i, %n
  br i1 %done, label %alloc, label %sum_bdy
sum_bdy:
  %p_int = call i64 @orion_list_at(ptr %parts, i64 %i)
  %p = inttoptr i64 %p_int to ptr
  %l = call i64 @orion_tlen(ptr %p)
  %total_next = add i64 %total, %l
  %i_next = add i64 %i, 1
  br label %sum_hdr
alloc:
  %bufsz = add i64 %total, 1
  %buf = call ptr @orion_text_alloc(i64 %total)
  br label %cp_hdr
cp_hdr:
  %j = phi i64 [ 0, %alloc ], [ %j_next, %cp_bdy ]
  %off = phi i64 [ 0, %alloc ], [ %off_next, %cp_bdy ]
  %cp_done = icmp sge i64 %j, %n
  br i1 %cp_done, label %fin, label %cp_bdy
cp_bdy:
  %q_int = call i64 @orion_list_at(ptr %parts, i64 %j)
  %q = inttoptr i64 %q_int to ptr
  %ql = call i64 @orion_tlen(ptr %q)
  %dst = getelementptr i8, ptr %buf, i64 %off
  %_c = call ptr @memcpy(ptr %dst, ptr %q, i64 %ql)
  %off_next = add i64 %off, %ql
  %j_next = add i64 %j, 1
  br label %cp_hdr
fin:
  %term = getelementptr i8, ptr %buf, i64 %total
  store i8 0, ptr %term
  ret ptr %buf
}

declare i64 @strlen(ptr)
declare ptr @orion_text_alloc(i64)
declare ptr @orion_text_seal(ptr)
declare ptr @orion_text_from_c(ptr)
declare i64 @orion_text_hash(ptr)
define i64 @orion_tlen(ptr %p) {
entry:
  %hp = getelementptr i8, ptr %p, i64 -8
  %l = load i64, ptr %hp
  ret i64 %l
}

declare i32 @memcmp(ptr, ptr, i64)
define i64 @orion_text_eq(ptr %a, ptr %b) {
entry:
  %same = icmp eq ptr %a, %b
  br i1 %same, label %yes, label %len_chk
len_chk:
  %la_p = getelementptr i8, ptr %a, i64 -8
  %lb_p = getelementptr i8, ptr %b, i64 -8
  %la = load i64, ptr %la_p
  %lb = load i64, ptr %lb_p
  %len_ne = icmp ne i64 %la, %lb
  br i1 %len_ne, label %no, label %ha_chk
ha_chk:
  %ha_p = getelementptr i8, ptr %a, i64 -16
  %ha0 = load i64, ptr %ha_p
  %ha_miss = icmp eq i64 %ha0, 0
  br i1 %ha_miss, label %ha_fill, label %hb_chk
ha_fill:
  %ha1 = call i64 @orion_text_hash(ptr %a)
  br label %hb_chk
hb_chk:
  %ha = phi i64 [ %ha0, %ha_chk ], [ %ha1, %ha_fill ]
  %hb_p = getelementptr i8, ptr %b, i64 -16
  %hb0 = load i64, ptr %hb_p
  %hb_miss = icmp eq i64 %hb0, 0
  br i1 %hb_miss, label %hb_fill, label %h_cmp
hb_fill:
  %hb1 = call i64 @orion_text_hash(ptr %b)
  br label %h_cmp
h_cmp:
  %hb = phi i64 [ %hb0, %hb_chk ], [ %hb1, %hb_fill ]
  %h_ne = icmp ne i64 %ha, %hb
  br i1 %h_ne, label %no, label %bytes
bytes:
  %mc = call i32 @memcmp(ptr %a, ptr %b, i64 %la)
  %beq = icmp eq i32 %mc, 0
  %r = zext i1 %beq to i64
  ret i64 %r
yes:
  ret i64 1
no:
  ret i64 0
}

declare ptr @strcpy(ptr, ptr)
declare ptr @strcat(ptr, ptr)
declare i32 @strcmp(ptr, ptr)
declare i32 @snprintf(ptr, i64, ptr, ...)
declare i64 @__orion_perform_int(ptr, i64)
declare void @__orion_resume_int(i64)
declare ptr @__orion_perform_text(ptr, ptr)
declare void @__orion_resume_text(ptr)
declare i64 @__orion_time_now_ms()
declare i64 @__orion_monotonic_ms()
declare void @__orion_sleep_ms(i64)
@.fmt_int = private unnamed_addr constant [6 x i8] c"%lld\0A\00"
@.fmt_float = private unnamed_addr constant [4 x i8] c"%g\0A\00"
@.fmt_g = private unnamed_addr constant [3 x i8] c"%g\00"
@.fmt_int_raw = private unnamed_addr constant [5 x i8] c"%lld\00"

define ptr @orion_text_concat(ptr %a, ptr %b) {
entry:
  %la = call i64 @orion_tlen(ptr %a)
  %lb = call i64 @orion_tlen(ptr %b)
  %sum = add i64 %la, %lb
  %buf = call ptr @orion_text_alloc(i64 %sum)
  %_1 = call ptr @strcpy(ptr %buf, ptr %a)
  %_2 = call ptr @strcat(ptr %buf, ptr %b)
  ret ptr %buf
}

define ptr @orion_int_to_text(i64 %n) {
entry:
  %buf = call ptr @orion_text_alloc(i64 31)
  %_ = call i32 (ptr, i64, ptr, ...) @snprintf(ptr %buf, i64 32, ptr @.fmt_int_raw, i64 %n)
  %sealed = call ptr @orion_text_seal(ptr %buf)
  ret ptr %sealed
}

declare ptr @memcpy(ptr, ptr, i64)

define ptr @orion_text_slice(ptr %src, i64 %lo, i64 %hi) {
entry:
  %src_len = call i64 @orion_tlen(ptr %src)
  %lo_neg = icmp slt i64 %lo, 0
  %lo_safe = select i1 %lo_neg, i64 0, i64 %lo
  %hi_big = icmp sgt i64 %hi, %src_len
  %hi_safe = select i1 %hi_big, i64 %src_len, i64 %hi
  %hi_lt_lo = icmp slt i64 %hi_safe, %lo_safe
  %hi_final = select i1 %hi_lt_lo, i64 %lo_safe, i64 %hi_safe
  %slice_len = sub i64 %hi_final, %lo_safe
  %buf = call ptr @orion_text_alloc(i64 %slice_len)
  %src_off = getelementptr i8, ptr %src, i64 %lo_safe
  %_ = call ptr @memcpy(ptr %buf, ptr %src_off, i64 %slice_len)
  %term = getelementptr i8, ptr %buf, i64 %slice_len
  store i8 0, ptr %term
  ret ptr %buf
}

declare ptr @strstr(ptr, ptr)

define i64 @orion_text_contains(ptr %hay, ptr %needle) {
entry:
  %hit = call ptr @strstr(ptr %hay, ptr %needle)
  %is_null = icmp eq ptr %hit, null
  %result = select i1 %is_null, i64 0, i64 1
  ret i64 %result
}

define ptr @orion_bytes_from_text(ptr %src) {
entry:
  %src_len = call i64 @orion_tlen(ptr %src)
  %list = call ptr @orion_list_new(i64 %src_len)
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %bdy ]
  %done = icmp sge i64 %i, %src_len
  br i1 %done, label %after, label %bdy
bdy:
  %byte_ptr = getelementptr i8, ptr %src, i64 %i
  %byte = load i8, ptr %byte_ptr
  %byte64 = zext i8 %byte to i64
  call void @orion_list_set(ptr %list, i64 %i, i64 %byte64)
  %i_next = add i64 %i, 1
  br label %hdr
after:
  ret ptr %list
}

define ptr @orion_bytes_to_text(ptr %list) {
entry:
  %list_len = call i64 @orion_list_len(ptr %list)
  %buf = call ptr @orion_text_alloc(i64 %list_len)
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %bdy ]
  %done = icmp sge i64 %i, %list_len
  br i1 %done, label %after, label %bdy
bdy:
  %v64 = call i64 @orion_list_at(ptr %list, i64 %i)
  %v8 = trunc i64 %v64 to i8
  %dst = getelementptr i8, ptr %buf, i64 %i
  store i8 %v8, ptr %dst
  %i_next = add i64 %i, 1
  br label %hdr
after:
  %term = getelementptr i8, ptr %buf, i64 %list_len
  store i8 0, ptr %term
  ret ptr %buf
}

define ptr @orion_bytes_zeros(i64 %n) {
entry:
  %list = call ptr @orion_list_new(i64 %n)
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %bdy ]
  %done = icmp sge i64 %i, %n
  br i1 %done, label %after, label %bdy
bdy:
  call void @orion_list_set(ptr %list, i64 %i, i64 0)
  %i_next = add i64 %i, 1
  br label %hdr
after:
  ret ptr %list
}

define ptr @orion_bytes_slice(ptr %src, i64 %lo, i64 %hi) {
entry:
  %src_len = call i64 @orion_list_len(ptr %src)
  %lo_neg = icmp slt i64 %lo, 0
  %lo_safe = select i1 %lo_neg, i64 0, i64 %lo
  %hi_big = icmp sgt i64 %hi, %src_len
  %hi_safe = select i1 %hi_big, i64 %src_len, i64 %hi
  %hi_lt = icmp slt i64 %hi_safe, %lo_safe
  %hi_final = select i1 %hi_lt, i64 %lo_safe, i64 %hi_safe
  %new_len = sub i64 %hi_final, %lo_safe
  %dst = call ptr @orion_list_new(i64 %new_len)
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %bdy ]
  %done = icmp sge i64 %i, %new_len
  br i1 %done, label %after, label %bdy
bdy:
  %src_idx = add i64 %lo_safe, %i
  %item = call i64 @orion_list_at(ptr %src, i64 %src_idx)
  call void @orion_list_set(ptr %dst, i64 %i, i64 %item)
  %i_next = add i64 %i, 1
  br label %hdr
after:
  ret ptr %dst
}

define ptr @orion_bytes_concat(ptr %a, ptr %b) {
entry:
  %a_len = call i64 @orion_list_len(ptr %a)
  %b_len = call i64 @orion_list_len(ptr %b)
  %total = add i64 %a_len, %b_len
  %dst = call ptr @orion_list_new(i64 %total)
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %store ]
  %done = icmp sge i64 %i, %total
  br i1 %done, label %after, label %bdy
bdy:
  %from_a = icmp slt i64 %i, %a_len
  br i1 %from_a, label %ba, label %bb
ba:
  %item_a = call i64 @orion_list_at(ptr %a, i64 %i)
  br label %store
bb:
  %b_idx = sub i64 %i, %a_len
  %item_b = call i64 @orion_list_at(ptr %b, i64 %b_idx)
  br label %store
store:
  %item = phi i64 [ %item_a, %ba ], [ %item_b, %bb ]
  call void @orion_list_set(ptr %dst, i64 %i, i64 %item)
  %i_next = add i64 %i, 1
  br label %hdr
after:
  ret ptr %dst
}

@orion_slots = global ptr null

@orion_empty_list = constant [2 x i64] zeroinitializer

define ptr @orion_persist_text(ptr %s) {
entry:
  %is_null = icmp eq ptr %s, null
  br i1 %is_null, label %ret_empty, label %copy_it
ret_empty:
  %eo = getelementptr i8, ptr @.empty_str, i64 16
  ret ptr %eo
copy_it:
  %n = call i64 @orion_tlen(ptr %s)
  %tot = add i64 %n, 17
  %src_base = getelementptr i8, ptr %s, i64 -16
  %copy = call ptr @malloc(i64 %tot)
  %_ = call ptr @memcpy(ptr %copy, ptr %src_base, i64 %tot)
  %out = getelementptr i8, ptr %copy, i64 16
  ret ptr %out
}

define ptr @orion_map_new_persist() {
entry:
  %handle = call ptr @malloc(i64 24)
  %entries = call ptr @malloc(i64 256)
  store ptr %entries, ptr %handle
  %cap_slot = getelementptr i64, ptr %handle, i64 1
  store i64 16, ptr %cap_slot
  %len_slot = getelementptr i64, ptr %handle, i64 2
  store i64 0, ptr %len_slot
  ret ptr %handle
}

define void @orion_map_set_persist(ptr %map, ptr %key, i64 %val) {
entry:
  %entries = load ptr, ptr %map
  %cap_slot = getelementptr i64, ptr %map, i64 1
  %len_slot = getelementptr i64, ptr %map, i64 2
  %cap = load i64, ptr %cap_slot
  %len = load i64, ptr %len_slot
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %step ]
  %done = icmp sge i64 %i, %len
  br i1 %done, label %maybe_grow, label %check
check:
  %idx2 = mul i64 %i, 2
  %k_slot = getelementptr i64, ptr %entries, i64 %idx2
  %k_int = load i64, ptr %k_slot
  %k_ptr = inttoptr i64 %k_int to ptr
  %cmp = call i64 @orion_text_eq(ptr %k_ptr, ptr %key)
  %eq = icmp ne i64 %cmp, 0
  br i1 %eq, label %update, label %step
step:
  %i_next = add i64 %i, 1
  br label %hdr
update:
  %vi = add i64 %idx2, 1
  %v_slot = getelementptr i64, ptr %entries, i64 %vi
  store i64 %val, ptr %v_slot
  ret void
maybe_grow:
  %full = icmp sge i64 %len, %cap
  br i1 %full, label %grow, label %append
grow:
  %new_cap = mul i64 %cap, 2
  %new_bytes = mul i64 %new_cap, 16
  %new_entries = call ptr @malloc(i64 %new_bytes)
  %old_bytes = mul i64 %len, 16
  %_cp = call ptr @memcpy(ptr %new_entries, ptr %entries, i64 %old_bytes)
  store ptr %new_entries, ptr %map
  store i64 %new_cap, ptr %cap_slot
  br label %append
append:
  %entries2 = load ptr, ptr %map
  %key_copy = call ptr @orion_persist_text(ptr %key)
  %app_idx2 = mul i64 %len, 2
  %app_k_slot = getelementptr i64, ptr %entries2, i64 %app_idx2
  %app_vi = add i64 %app_idx2, 1
  %app_v_slot = getelementptr i64, ptr %entries2, i64 %app_vi
  %key_int = ptrtoint ptr %key_copy to i64
  store i64 %key_int, ptr %app_k_slot
  store i64 %val, ptr %app_v_slot
  %new_len = add i64 %len, 1
  store i64 %new_len, ptr %len_slot
  ret void
}

define ptr @orion_slot_get(ptr %key) {
entry:
  %m = load ptr, ptr @orion_slots
  %is_null = icmp eq ptr %m, null
  br i1 %is_null, label %init, label %get
init:
  %new = call ptr @orion_map_new_persist()
  store ptr %new, ptr @orion_slots
  br label %get
get:
  %m2 = load ptr, ptr @orion_slots
  %has = call i64 @orion_map_has(ptr %m2, ptr %key)
  %miss = icmp eq i64 %has, 0
  br i1 %miss, label %empty, label %fetch
empty:
  %eo = getelementptr i8, ptr @.empty_str, i64 16
  ret ptr %eo
fetch:
  %raw = call i64 @orion_map_get(ptr %m2, ptr %key)
  %p = inttoptr i64 %raw to ptr
  ret ptr %p
}

define i64 @orion_slot_set(ptr %key, i64 %val) {
entry:
  %m = load ptr, ptr @orion_slots
  %is_null = icmp eq ptr %m, null
  br i1 %is_null, label %init, label %store
init:
  %new = call ptr @orion_map_new_persist()
  store ptr %new, ptr @orion_slots
  br label %store
store:
  %m2 = load ptr, ptr @orion_slots
  call void @orion_map_set_persist(ptr %m2, ptr %key, i64 %val)
  ret i64 0
}

define i64 @orion_slot_has(ptr %key) {
entry:
  %m = load ptr, ptr @orion_slots
  %is_null = icmp eq ptr %m, null
  br i1 %is_null, label %no, label %chk
no:
  ret i64 0
chk:
  %has = call i64 @orion_map_has(ptr %m, ptr %key)
  ret i64 %has
}

define i64 @orion_slot_get_int(ptr %key) {
entry:
  %m = load ptr, ptr @orion_slots
  %is_null = icmp eq ptr %m, null
  br i1 %is_null, label %zero, label %get
zero:
  ret i64 0
get:
  %v = call i64 @orion_map_get(ptr %m, ptr %key)
  ret i64 %v
}

declare ptr @fopen(ptr, ptr)
declare i32 @fclose(ptr)
declare i64 @fread(ptr, i64, i64, ptr)
declare i64 @fwrite(ptr, i64, i64, ptr)
declare i32 @fseek(ptr, i64, i32)
declare i64 @ftell(ptr)
@.fmode_r = private unnamed_addr constant [3 x i8] c"rb\00"
@.fmode_w = private unnamed_addr constant [3 x i8] c"wb\00"
@.empty_str = private unnamed_addr constant [17 x i8] c"\05\15\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00", align 8

define ptr @orion_file_read(ptr %path) {
entry:
  %fp = call ptr @fopen(ptr %path, ptr @.fmode_r)
  %is_null = icmp eq ptr %fp, null
  br i1 %is_null, label %err, label %ok
err:
  %eo = getelementptr i8, ptr @.empty_str, i64 16
  ret ptr %eo
ok:
  %_seek = call i32 @fseek(ptr %fp, i64 0, i32 2)
  %size = call i64 @ftell(ptr %fp)
  %_rew = call i32 @fseek(ptr %fp, i64 0, i32 0)
  %buf = call ptr @orion_text_alloc(i64 %size)
  %_read = call i64 @fread(ptr %buf, i64 1, i64 %size, ptr %fp)
  %term = getelementptr i8, ptr %buf, i64 %size
  store i8 0, ptr %term
  %_close = call i32 @fclose(ptr %fp)
  ret ptr %buf
}

define i64 @orion_file_write(ptr %path, ptr %content) {
entry:
  %fp = call ptr @fopen(ptr %path, ptr @.fmode_w)
  %is_null = icmp eq ptr %fp, null
  br i1 %is_null, label %err, label %ok
err:
  ret i64 0
ok:
  %len = call i64 @orion_tlen(ptr %content)
  %_wrote = call i64 @fwrite(ptr %content, i64 1, i64 %len, ptr %fp)
  %_close = call i32 @fclose(ptr %fp)
  ret i64 1
}

define ptr @orion_list_new(i64 %cap) {
entry:
  %bytes = mul i64 %cap, 8
  %total = add i64 %bytes, 16
  %buf = call ptr @orion_alloc(i64 %total)
  store i64 %cap, ptr %buf
  %len_slot = getelementptr i64, ptr %buf, i64 1
  store i64 %cap, ptr %len_slot
  ret ptr %buf
}

define i64 @orion_struct_field_int(ptr %s, i64 %i) {
entry:
  %slot = getelementptr i64, ptr %s, i64 %i
  %v = load i64, ptr %slot
  ret i64 %v
}

define ptr @orion_struct_field_text(ptr %s, i64 %i) {
entry:
  %slot = getelementptr i64, ptr %s, i64 %i
  %v = load i64, ptr %slot
  %p = inttoptr i64 %v to ptr
  ret ptr %p
}

define i64 @orion_list_len(ptr %list) {
entry:
  %len_slot = getelementptr i64, ptr %list, i64 1
  %len = load i64, ptr %len_slot
  ret i64 %len
}

define i64 @orion_list_at(ptr %list, i64 %idx) {
entry:
  %offset = add i64 %idx, 2
  %slot = getelementptr i64, ptr %list, i64 %offset
  %val = load i64, ptr %slot
  ret i64 %val
}

define ptr @orion_list_slice(ptr %list, i64 %lo, i64 %hi) {
entry:
  %n = call i64 @orion_list_len(ptr %list)
  %hi_neg = icmp slt i64 %hi, 0
  %hi0 = select i1 %hi_neg, i64 0, i64 %hi
  %hi_big = icmp sgt i64 %hi0, %n
  %hi1 = select i1 %hi_big, i64 %n, i64 %hi0
  %lo_neg = icmp slt i64 %lo, 0
  %lo0 = select i1 %lo_neg, i64 0, i64 %lo
  %lo_big = icmp sgt i64 %lo0, %hi1
  %lo1 = select i1 %lo_big, i64 %hi1, i64 %lo0
  %cnt = sub i64 %hi1, %lo1
  %out = call ptr @orion_list_new(i64 %cnt)
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %inext, %body ]
  %done = icmp sge i64 %i, %cnt
  br i1 %done, label %exit, label %body
body:
  %src_i = add i64 %lo1, %i
  %v = call i64 @orion_list_at(ptr %list, i64 %src_i)
  call void @orion_list_set(ptr %out, i64 %i, i64 %v)
  %inext = add i64 %i, 1
  br label %hdr
exit:
  ret ptr %out
}

define void @orion_list_set(ptr %list, i64 %idx, i64 %val) {
entry:
  %len_slot = getelementptr i64, ptr %list, i64 1
  %len = load i64, ptr %len_slot
  %neg = icmp slt i64 %idx, 0
  %oob = icmp sge i64 %idx, %len
  %bad = or i1 %neg, %oob
  br i1 %bad, label %skip, label %write
write:
  %offset = add i64 %idx, 2
  %slot = getelementptr i64, ptr %list, i64 %offset
  store i64 %val, ptr %slot
  ret void
skip:
  ret void
}

define ptr @orion_list_push(ptr %list, i64 %val) {
entry:
  %len_slot = getelementptr i64, ptr %list, i64 1
  %len = load i64, ptr %len_slot
  %need = add i64 %len, 1
  %cap2 = mul i64 %need, 2
  %too_small = icmp slt i64 %cap2, 4
  %new_cap = select i1 %too_small, i64 4, i64 %cap2
  %bytes = mul i64 %new_cap, 8
  %total = add i64 %bytes, 16
  %new_list = call ptr @orion_alloc(i64 %total)
  store i64 %new_cap, ptr %new_list
  %new_len_slot = getelementptr i64, ptr %new_list, i64 1
  store i64 %need, ptr %new_len_slot
  %dst_items = getelementptr i64, ptr %new_list, i64 2
  %src_items = getelementptr i64, ptr %list, i64 2
  %copy_bytes = mul i64 %len, 8
  %_cp = call ptr @memcpy(ptr %dst_items, ptr %src_items, i64 %copy_bytes)
  %app_idx = add i64 %len, 2
  %app_slot = getelementptr i64, ptr %new_list, i64 %app_idx
  store i64 %val, ptr %app_slot
  ret ptr %new_list
}

define ptr @orion_list_push_mut(ptr %list, i64 %val) {
entry:
  %cap = load i64, ptr %list
  %len_slot = getelementptr i64, ptr %list, i64 1
  %len = load i64, ptr %len_slot
  %has_room = icmp slt i64 %len, %cap
  br i1 %has_room, label %inplace, label %grow
inplace:
  %slot_idx = add i64 %len, 2
  %slot = getelementptr i64, ptr %list, i64 %slot_idx
  store i64 %val, ptr %slot
  %new_len = add i64 %len, 1
  store i64 %new_len, ptr %len_slot
  ret ptr %list
grow:
  %fallback = call ptr @orion_list_push(ptr %list, i64 %val)
  ret ptr %fallback
}

define ptr @orion_map_new(i64 %cap) {
entry:
  %too_small = icmp slt i64 %cap, 4
  %cap2 = select i1 %too_small, i64 4, i64 %cap
  %handle = call ptr @orion_alloc(i64 24)
  %entry_bytes = mul i64 %cap2, 16
  %entries = call ptr @orion_alloc(i64 %entry_bytes)
  store ptr %entries, ptr %handle
  %cap_slot = getelementptr i64, ptr %handle, i64 1
  store i64 %cap2, ptr %cap_slot
  %len_slot = getelementptr i64, ptr %handle, i64 2
  store i64 0, ptr %len_slot
  ret ptr %handle
}

define void @orion_map_set(ptr %map, ptr %key, i64 %val) {
entry:
  %entries = load ptr, ptr %map
  %cap_slot = getelementptr i64, ptr %map, i64 1
  %len_slot = getelementptr i64, ptr %map, i64 2
  %cap = load i64, ptr %cap_slot
  %len = load i64, ptr %len_slot
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %step ]
  %done = icmp sge i64 %i, %len
  br i1 %done, label %maybe_grow, label %check
check:
  %idx2 = mul i64 %i, 2
  %k_slot = getelementptr i64, ptr %entries, i64 %idx2
  %k_int = load i64, ptr %k_slot
  %k_ptr = inttoptr i64 %k_int to ptr
  %cmp = call i64 @orion_text_eq(ptr %k_ptr, ptr %key)
  %eq = icmp ne i64 %cmp, 0
  br i1 %eq, label %update, label %step
step:
  %i_next = add i64 %i, 1
  br label %hdr
update:
  %vi = add i64 %idx2, 1
  %v_slot = getelementptr i64, ptr %entries, i64 %vi
  store i64 %val, ptr %v_slot
  ret void
maybe_grow:
  %full = icmp sge i64 %len, %cap
  br i1 %full, label %grow, label %append
grow:
  %new_cap = mul i64 %cap, 2
  %new_bytes = mul i64 %new_cap, 16
  %new_entries = call ptr @orion_alloc(i64 %new_bytes)
  %old_bytes = mul i64 %len, 16
  %_cp = call ptr @memcpy(ptr %new_entries, ptr %entries, i64 %old_bytes)
  store ptr %new_entries, ptr %map
  store i64 %new_cap, ptr %cap_slot
  br label %append
append:
  %entries2 = load ptr, ptr %map
  %app_idx2 = mul i64 %len, 2
  %app_k_slot = getelementptr i64, ptr %entries2, i64 %app_idx2
  %app_vi = add i64 %app_idx2, 1
  %app_v_slot = getelementptr i64, ptr %entries2, i64 %app_vi
  %key_owned = call ptr @orion_key_copy(ptr %key)
  %key_int = ptrtoint ptr %key_owned to i64
  store i64 %key_int, ptr %app_k_slot
  store i64 %val, ptr %app_v_slot
  %new_len = add i64 %len, 1
  store i64 %new_len, ptr %len_slot
  ret void
}

define i64 @orion_map_get(ptr %map, ptr %key) {
entry:
  %entries = load ptr, ptr %map
  %len_slot = getelementptr i64, ptr %map, i64 2
  %len = load i64, ptr %len_slot
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %step ]
  %done = icmp sge i64 %i, %len
  br i1 %done, label %miss, label %body
body:
  %ki = mul i64 %i, 2
  %vi = add i64 %ki, 1
  %k_slot = getelementptr i64, ptr %entries, i64 %ki
  %k_int = load i64, ptr %k_slot
  %k_ptr = inttoptr i64 %k_int to ptr
  %cmp = call i64 @orion_text_eq(ptr %k_ptr, ptr %key)
  %eq = icmp ne i64 %cmp, 0
  br i1 %eq, label %hit, label %step
hit:
  %v_slot = getelementptr i64, ptr %entries, i64 %vi
  %v = load i64, ptr %v_slot
  ret i64 %v
step:
  %i_next = add i64 %i, 1
  br label %hdr
miss:
  ret i64 0
}

define i64 @orion_map_has(ptr %map, ptr %key) {
entry:
  %entries = load ptr, ptr %map
  %len_slot = getelementptr i64, ptr %map, i64 2
  %len = load i64, ptr %len_slot
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %step ]
  %done = icmp sge i64 %i, %len
  br i1 %done, label %miss, label %body
body:
  %ki = mul i64 %i, 2
  %k_slot = getelementptr i64, ptr %entries, i64 %ki
  %k_int = load i64, ptr %k_slot
  %k_ptr = inttoptr i64 %k_int to ptr
  %cmp = call i64 @orion_text_eq(ptr %k_ptr, ptr %key)
  %eq = icmp ne i64 %cmp, 0
  br i1 %eq, label %hit, label %step
hit:
  ret i64 1
step:
  %i_next = add i64 %i, 1
  br label %hdr
miss:
  ret i64 0
}

define void @orion_map_set_ik(ptr %map, i64 %key, i64 %val) {
entry:
  %entries = load ptr, ptr %map
  %cap_slot = getelementptr i64, ptr %map, i64 1
  %len_slot = getelementptr i64, ptr %map, i64 2
  %cap = load i64, ptr %cap_slot
  %len = load i64, ptr %len_slot
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %step ]
  %done = icmp sge i64 %i, %len
  br i1 %done, label %maybe_grow, label %check
check:
  %idx2 = mul i64 %i, 2
  %k_slot = getelementptr i64, ptr %entries, i64 %idx2
  %k_int = load i64, ptr %k_slot
  %eq = icmp eq i64 %k_int, %key
  br i1 %eq, label %update, label %step
step:
  %i_next = add i64 %i, 1
  br label %hdr
update:
  %vi = add i64 %idx2, 1
  %v_slot = getelementptr i64, ptr %entries, i64 %vi
  store i64 %val, ptr %v_slot
  ret void
maybe_grow:
  %full = icmp sge i64 %len, %cap
  br i1 %full, label %grow, label %append
grow:
  %new_cap = mul i64 %cap, 2
  %new_bytes = mul i64 %new_cap, 16
  %new_entries = call ptr @orion_alloc(i64 %new_bytes)
  %old_bytes = mul i64 %len, 16
  %_cp = call ptr @memcpy(ptr %new_entries, ptr %entries, i64 %old_bytes)
  store ptr %new_entries, ptr %map
  store i64 %new_cap, ptr %cap_slot
  br label %append
append:
  %entries2 = load ptr, ptr %map
  %app_idx2 = mul i64 %len, 2
  %app_k_slot = getelementptr i64, ptr %entries2, i64 %app_idx2
  %app_vi = add i64 %app_idx2, 1
  %app_v_slot = getelementptr i64, ptr %entries2, i64 %app_vi
  store i64 %key, ptr %app_k_slot
  store i64 %val, ptr %app_v_slot
  %new_len = add i64 %len, 1
  store i64 %new_len, ptr %len_slot
  ret void
}

define void @orion_map_remove(ptr %map, ptr %key) {
entry:
  %entries = load ptr, ptr %map
  %len_slot = getelementptr i64, ptr %map, i64 2
  %len = load i64, ptr %len_slot
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %step ]
  %done = icmp sge i64 %i, %len
  br i1 %done, label %miss, label %check
check:
  %idx2 = mul i64 %i, 2
  %k_slot = getelementptr i64, ptr %entries, i64 %idx2
  %k_int = load i64, ptr %k_slot
  %k_ptr = inttoptr i64 %k_int to ptr
  %cmp = call i64 @orion_text_eq(ptr %k_ptr, ptr %key)
  %eq = icmp ne i64 %cmp, 0
  br i1 %eq, label %found, label %step
step:
  %i_next = add i64 %i, 1
  br label %hdr
found:
  %last = add i64 %len, -1
  %last2 = mul i64 %last, 2
  %lk_slot = getelementptr i64, ptr %entries, i64 %last2
  %lv_i = add i64 %last2, 1
  %lv_slot = getelementptr i64, ptr %entries, i64 %lv_i
  %lk = load i64, ptr %lk_slot
  %lv = load i64, ptr %lv_slot
  %vi = add i64 %idx2, 1
  %v_slot = getelementptr i64, ptr %entries, i64 %vi
  store i64 %lk, ptr %k_slot
  store i64 %lv, ptr %v_slot
  store i64 %last, ptr %len_slot
  ret void
miss:
  ret void
}

define void @orion_map_remove_ik(ptr %map, i64 %key) {
entry:
  %entries = load ptr, ptr %map
  %len_slot = getelementptr i64, ptr %map, i64 2
  %len = load i64, ptr %len_slot
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %step ]
  %done = icmp sge i64 %i, %len
  br i1 %done, label %miss, label %check
check:
  %idx2 = mul i64 %i, 2
  %k_slot = getelementptr i64, ptr %entries, i64 %idx2
  %k_int = load i64, ptr %k_slot
  %eq = icmp eq i64 %k_int, %key
  br i1 %eq, label %found, label %step
step:
  %i_next = add i64 %i, 1
  br label %hdr
found:
  %last = add i64 %len, -1
  %last2 = mul i64 %last, 2
  %lk_slot = getelementptr i64, ptr %entries, i64 %last2
  %lv_i = add i64 %last2, 1
  %lv_slot = getelementptr i64, ptr %entries, i64 %lv_i
  %lk = load i64, ptr %lk_slot
  %lv = load i64, ptr %lv_slot
  %vi = add i64 %idx2, 1
  %v_slot = getelementptr i64, ptr %entries, i64 %vi
  store i64 %lk, ptr %k_slot
  store i64 %lv, ptr %v_slot
  store i64 %last, ptr %len_slot
  ret void
miss:
  ret void
}

define i64 @orion_map_get_ik(ptr %map, i64 %key) {
entry:
  %entries = load ptr, ptr %map
  %len_slot = getelementptr i64, ptr %map, i64 2
  %len = load i64, ptr %len_slot
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %step ]
  %done = icmp sge i64 %i, %len
  br i1 %done, label %miss, label %body
body:
  %ki = mul i64 %i, 2
  %vi = add i64 %ki, 1
  %k_slot = getelementptr i64, ptr %entries, i64 %ki
  %k_int = load i64, ptr %k_slot
  %eq = icmp eq i64 %k_int, %key
  br i1 %eq, label %hit, label %step
hit:
  %v_slot = getelementptr i64, ptr %entries, i64 %vi
  %v = load i64, ptr %v_slot
  ret i64 %v
step:
  %i_next = add i64 %i, 1
  br label %hdr
miss:
  ret i64 0
}

define i64 @orion_map_has_ik(ptr %map, i64 %key) {
entry:
  %entries = load ptr, ptr %map
  %len_slot = getelementptr i64, ptr %map, i64 2
  %len = load i64, ptr %len_slot
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %step ]
  %done = icmp sge i64 %i, %len
  br i1 %done, label %miss, label %body
body:
  %ki = mul i64 %i, 2
  %k_slot = getelementptr i64, ptr %entries, i64 %ki
  %k_int = load i64, ptr %k_slot
  %eq = icmp eq i64 %k_int, %key
  br i1 %eq, label %hit, label %step
hit:
  ret i64 1
step:
  %i_next = add i64 %i, 1
  br label %hdr
miss:
  ret i64 0
}

define i64 @orion_map_get_or_ik(ptr %map, i64 %key, i64 %dflt) {
entry:
  %has = call i64 @orion_map_has_ik(ptr %map, i64 %key)
  %miss = icmp eq i64 %has, 0
  br i1 %miss, label %use_dflt, label %fetch
use_dflt:
  ret i64 %dflt
fetch:
  %v = call i64 @orion_map_get_ik(ptr %map, i64 %key)
  ret i64 %v
}

define i64 @orion_map_len(ptr %map) {
entry:
  %len_slot = getelementptr i64, ptr %map, i64 2
  %len = load i64, ptr %len_slot
  ret i64 %len
}

define ptr @orion_map_keys(ptr %map) {
entry:
  %entries = load ptr, ptr %map
  %len_slot = getelementptr i64, ptr %map, i64 2
  %len = load i64, ptr %len_slot
  %out = call ptr @orion_list_new(i64 %len)
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %bdy ]
  %done = icmp sge i64 %i, %len
  br i1 %done, label %after, label %bdy
bdy:
  %ki = mul i64 %i, 2
  %k_slot = getelementptr i64, ptr %entries, i64 %ki
  %k_int = load i64, ptr %k_slot
  call void @orion_list_set(ptr %out, i64 %i, i64 %k_int)
  %i_next = add i64 %i, 1
  br label %hdr
after:
  ret ptr %out
}

define ptr @orion_map_values(ptr %map) {
entry:
  %entries = load ptr, ptr %map
  %len_slot = getelementptr i64, ptr %map, i64 2
  %len = load i64, ptr %len_slot
  %out = call ptr @orion_list_new(i64 %len)
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %bdy ]
  %done = icmp sge i64 %i, %len
  br i1 %done, label %after, label %bdy
bdy:
  %ki = mul i64 %i, 2
  %vi = add i64 %ki, 1
  %v_slot = getelementptr i64, ptr %entries, i64 %vi
  %v_int = load i64, ptr %v_slot
  call void @orion_list_set(ptr %out, i64 %i, i64 %v_int)
  %i_next = add i64 %i, 1
  br label %hdr
after:
  ret ptr %out
}

define i64 @orion_map_get_or(ptr %map, ptr %key, i64 %dflt) {
entry:
  %has = call i64 @orion_map_has(ptr %map, ptr %key)
  %miss = icmp eq i64 %has, 0
  br i1 %miss, label %use_dflt, label %fetch
use_dflt:
  ret i64 %dflt
fetch:
  %v = call i64 @orion_map_get(ptr %map, ptr %key)
  ret i64 %v
}

define ptr @orion_f64_to_text(double %v) {
entry:
  %buf = call ptr @orion_text_alloc(i64 31)
  %_n = call i32 (ptr, i64, ptr, ...) @snprintf(ptr %buf, i64 32, ptr @.fmt_g, double %v)
  %sealed = call ptr @orion_text_seal(ptr %buf)
  ret ptr %sealed
}

define ptr @orion_vec_add(ptr %a, ptr %b) {
entry:
  %la = call i64 @orion_list_len(ptr %a)
  %out = call ptr @orion_list_new(i64 %la)
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %bdy ]
  %done = icmp sge i64 %i, %la
  br i1 %done, label %after, label %bdy
bdy:
  %xa = call i64 @orion_list_at(ptr %a, i64 %i)
  %xb = call i64 @orion_list_at(ptr %b, i64 %i)
  %s = add i64 %xa, %xb
  call void @orion_list_set(ptr %out, i64 %i, i64 %s)
  %i_next = add i64 %i, 1
  br label %hdr
after:
  ret ptr %out
}

define ptr @orion_vec_sub(ptr %a, ptr %b) {
entry:
  %la = call i64 @orion_list_len(ptr %a)
  %out = call ptr @orion_list_new(i64 %la)
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %bdy ]
  %done = icmp sge i64 %i, %la
  br i1 %done, label %after, label %bdy
bdy:
  %xa = call i64 @orion_list_at(ptr %a, i64 %i)
  %xb = call i64 @orion_list_at(ptr %b, i64 %i)
  %s = sub i64 %xa, %xb
  call void @orion_list_set(ptr %out, i64 %i, i64 %s)
  %i_next = add i64 %i, 1
  br label %hdr
after:
  ret ptr %out
}

define ptr @orion_vec_mul(ptr %a, ptr %b) {
entry:
  %la = call i64 @orion_list_len(ptr %a)
  %out = call ptr @orion_list_new(i64 %la)
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %bdy ]
  %done = icmp sge i64 %i, %la
  br i1 %done, label %after, label %bdy
bdy:
  %xa = call i64 @orion_list_at(ptr %a, i64 %i)
  %xb = call i64 @orion_list_at(ptr %b, i64 %i)
  %s = mul i64 %xa, %xb
  call void @orion_list_set(ptr %out, i64 %i, i64 %s)
  %i_next = add i64 %i, 1
  br label %hdr
after:
  ret ptr %out
}

define i64 @orion_vec_dot(ptr %a, ptr %b) {
entry:
  %la = call i64 @orion_list_len(ptr %a)
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %bdy ]
  %acc = phi i64 [ 0, %entry ], [ %acc_next, %bdy ]
  %done = icmp sge i64 %i, %la
  br i1 %done, label %after, label %bdy
bdy:
  %xa = call i64 @orion_list_at(ptr %a, i64 %i)
  %xb = call i64 @orion_list_at(ptr %b, i64 %i)
  %m = mul i64 %xa, %xb
  %acc_next = add i64 %acc, %m
  %i_next = add i64 %i, 1
  br label %hdr
after:
  ret i64 %acc
}


@.str_0 = private unnamed_addr constant [20 x i8] c"\3A\5D\E3\05\00\00\00\00\03\00\00\00\00\00\00\00i64\00", align 8
@.str_1 = private unnamed_addr constant [20 x i8] c"\71\52\E5\05\00\00\00\00\03\00\00\00\00\00\00\00ptr\00", align 8
@.str_2 = private unnamed_addr constant [21 x i8] c"\BB\28\36\37\00\00\00\00\04\00\00\00\00\00\00\00bool\00", align 8
@.str_3 = private unnamed_addr constant [21 x i8] c"\BD\35\E4\39\00\00\00\00\04\00\00\00\00\00\00\00void\00", align 8
@.str_4 = private unnamed_addr constant [23 x i8] c"\5D\17\44\29\00\00\00\00\06\00\00\00\00\00\00\00iconst\00", align 8
@.str_5 = private unnamed_addr constant [17 x i8] c"\05\15\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00", align 8
@.str_6 = private unnamed_addr constant [21 x i8] c"\D1\97\22\38\00\00\00\00\04\00\00\00\00\00\00\00iadd\00", align 8
@.str_7 = private unnamed_addr constant [21 x i8] c"\24\57\27\38\00\00\00\00\04\00\00\00\00\00\00\00isub\00", align 8
@.str_8 = private unnamed_addr constant [21 x i8] c"\F8\C4\25\38\00\00\00\00\04\00\00\00\00\00\00\00imul\00", align 8
@.str_9 = private unnamed_addr constant [21 x i8] c"\8D\63\23\38\00\00\00\00\04\00\00\00\00\00\00\00idiv\00", align 8
@.str_10 = private unnamed_addr constant [21 x i8] c"\DE\C1\25\38\00\00\00\00\04\00\00\00\00\00\00\00imod\00", align 8
@.str_11 = private unnamed_addr constant [21 x i8] c"\EF\9C\22\38\00\00\00\00\04\00\00\00\00\00\00\00iand\00", align 8
@.str_12 = private unnamed_addr constant [20 x i8] c"\A3\7A\E3\05\00\00\00\00\03\00\00\00\00\00\00\00ior\00", align 8
@.str_13 = private unnamed_addr constant [21 x i8] c"\F7\04\26\38\00\00\00\00\04\00\00\00\00\00\00\00inot\00", align 8
@.str_14 = private unnamed_addr constant [24 x i8] c"\C5\D8\90\06\00\00\00\00\07\00\00\00\00\00\00\00icmp_eq\00", align 8
@.str_15 = private unnamed_addr constant [24 x i8] c"\54\DD\90\06\00\00\00\00\07\00\00\00\00\00\00\00icmp_ne\00", align 8
@.str_16 = private unnamed_addr constant [24 x i8] c"\5D\DC\90\06\00\00\00\00\07\00\00\00\00\00\00\00icmp_lt\00", align 8
@.str_17 = private unnamed_addr constant [24 x i8] c"\4E\DC\90\06\00\00\00\00\07\00\00\00\00\00\00\00icmp_le\00", align 8
@.str_18 = private unnamed_addr constant [24 x i8] c"\CE\D9\90\06\00\00\00\00\07\00\00\00\00\00\00\00icmp_gt\00", align 8
@.str_19 = private unnamed_addr constant [24 x i8] c"\BF\D9\90\06\00\00\00\00\07\00\00\00\00\00\00\00icmp_ge\00", align 8
@.str_20 = private unnamed_addr constant [23 x i8] c"\43\E2\48\1E\00\00\00\00\06\00\00\00\00\00\00\00return\00", align 8
@.str_21 = private unnamed_addr constant [26 x i8] c"\2B\80\49\02\00\00\00\00\09\00\00\00\00\00\00\00print_int\00", align 8
@.str_22 = private unnamed_addr constant [28 x i8] c"\4D\6B\F1\23\00\00\00\00\0B\00\00\00\00\00\00\00print_float\00", align 8
@.str_23 = private unnamed_addr constant [23 x i8] c"\96\C1\21\04\00\00\00\00\06\00\00\00\00\00\00\00select\00", align 8
@.str_24 = private unnamed_addr constant [23 x i8] c"\30\C0\DA\38\00\00\00\00\06\00\00\00\00\00\00\00fconst\00", align 8
@.str_25 = private unnamed_addr constant [20 x i8] c"\1F\94\E2\05\00\00\00\00\03\00\00\00\00\00\00\00f64\00", align 8
@.str_26 = private unnamed_addr constant [21 x i8] c"\B9\39\BC\37\00\00\00\00\04\00\00\00\00\00\00\00fcmp\00", align 8
@.str_27 = private unnamed_addr constant [23 x i8] c"\8A\DD\D2\0F\00\00\00\00\06\00\00\00\00\00\00\00sitofp\00", align 8
@.str_28 = private unnamed_addr constant [23 x i8] c"\36\A1\4D\2F\00\00\00\00\06\00\00\00\00\00\00\00fptosi\00", align 8
@.str_29 = private unnamed_addr constant [21 x i8] c"\4F\CA\54\37\00\00\00\00\04\00\00\00\00\00\00\00call\00", align 8
@.str_30 = private unnamed_addr constant [26 x i8] c"\95\21\4C\02\00\00\00\00\09\00\00\00\00\00\00\00print_str\00", align 8
@.str_31 = private unnamed_addr constant [26 x i8] c"\28\BD\87\1A\00\00\00\00\09\00\00\00\00\00\00\00const_str\00", align 8
@.str_32 = private unnamed_addr constant [21 x i8] c"\EA\03\9D\39\00\00\00\00\04\00\00\00\00\00\00\00text\00", align 8
@.str_33 = private unnamed_addr constant [28 x i8] c"\D3\54\F8\07\00\00\00\00\0B\00\00\00\00\00\00\00text_concat\00", align 8
@.str_34 = private unnamed_addr constant [28 x i8] c"\9D\F5\A0\22\00\00\00\00\0B\00\00\00\00\00\00\00int_to_text\00", align 8
@.str_35 = private unnamed_addr constant [25 x i8] c"\4C\43\B5\23\00\00\00\00\08\00\00\00\00\00\00\00text_len\00", align 8
@.str_36 = private unnamed_addr constant [27 x i8] c"\DB\03\D5\36\00\00\00\00\0A\00\00\00\00\00\00\00text_slice\00", align 8
@.str_37 = private unnamed_addr constant [27 x i8] c"\3C\0F\EB\00\00\00\00\00\0A\00\00\00\00\00\00\00list_slice\00", align 8
@.str_38 = private unnamed_addr constant [23 x i8] c"\1D\CF\B4\33\00\00\00\00\06\00\00\00\00\00\00\00fmath1\00", align 8
@.str_39 = private unnamed_addr constant [23 x i8] c"\1E\CF\B4\33\00\00\00\00\06\00\00\00\00\00\00\00fmath2\00", align 8
@.str_40 = private unnamed_addr constant [30 x i8] c"\49\5A\40\29\00\00\00\00\0D\00\00\00\00\00\00\00text_contains\00", align 8
@.str_41 = private unnamed_addr constant [26 x i8] c"\67\15\AB\0E\00\00\00\00\09\00\00\00\00\00\00\00file_read\00", align 8
@.str_42 = private unnamed_addr constant [27 x i8] c"\1F\8A\1C\2C\00\00\00\00\0A\00\00\00\00\00\00\00file_write\00", align 8
@.str_43 = private unnamed_addr constant [21 x i8] c"\1A\A0\14\37\00\00\00\00\04\00\00\00\00\00\00\00argc\00", align 8
@.str_44 = private unnamed_addr constant [21 x i8] c"\2D\A0\14\37\00\00\00\00\04\00\00\00\00\00\00\00argv\00", align 8
@.str_45 = private unnamed_addr constant [32 x i8] c"\4A\EC\24\37\00\00\00\00\0F\00\00\00\00\00\00\00bytes_from_text\00", align 8
@.str_46 = private unnamed_addr constant [21 x i8] c"\A7\A0\8B\38\00\00\00\00\04\00\00\00\00\00\00\00list\00", align 8
@.str_47 = private unnamed_addr constant [30 x i8] c"\A2\44\F1\17\00\00\00\00\0D\00\00\00\00\00\00\00bytes_to_text\00", align 8
@.str_48 = private unnamed_addr constant [28 x i8] c"\7E\B3\54\07\00\00\00\00\0B\00\00\00\00\00\00\00bytes_slice\00", align 8
@.str_49 = private unnamed_addr constant [29 x i8] c"\1B\12\CC\2B\00\00\00\00\0C\00\00\00\00\00\00\00bytes_concat\00", align 8
@.str_50 = private unnamed_addr constant [28 x i8] c"\ED\5D\11\0A\00\00\00\00\0B\00\00\00\00\00\00\00bytes_zeros\00", align 8
@.str_51 = private unnamed_addr constant [25 x i8] c"\66\39\6C\09\00\00\00\00\08\00\00\00\00\00\00\00slot_get\00", align 8
@.str_52 = private unnamed_addr constant [25 x i8] c"\D2\5D\6F\09\00\00\00\00\08\00\00\00\00\00\00\00slot_set\00", align 8
@.str_53 = private unnamed_addr constant [25 x i8] c"\DD\BD\CA\18\00\00\00\00\08\00\00\00\00\00\00\00list_lit\00", align 8
@.str_54 = private unnamed_addr constant [22 x i8] c"\4B\5A\79\10\00\00\00\00\05\00\00\00\00\00\00\00list:\00", align 8
@.str_55 = private unnamed_addr constant [24 x i8] c"\56\A8\1A\06\00\00\00\00\07\00\00\00\00\00\00\00list_at\00", align 8
@.str_56 = private unnamed_addr constant [25 x i8] c"\CB\BB\CA\18\00\00\00\00\08\00\00\00\00\00\00\00list_len\00", align 8
@.str_57 = private unnamed_addr constant [26 x i8] c"\5A\E5\A4\1D\00\00\00\00\09\00\00\00\00\00\00\00list_push\00", align 8
@.str_58 = private unnamed_addr constant [30 x i8] c"\F9\4B\DF\08\00\00\00\00\0D\00\00\00\00\00\00\00list_push_mut\00", align 8
@.str_59 = private unnamed_addr constant [24 x i8] c"\34\FC\51\09\00\00\00\00\07\00\00\00\00\00\00\00vec_add\00", align 8
@.str_60 = private unnamed_addr constant [24 x i8] c"\87\BB\56\09\00\00\00\00\07\00\00\00\00\00\00\00vec_sub\00", align 8
@.str_61 = private unnamed_addr constant [24 x i8] c"\5B\29\55\09\00\00\00\00\07\00\00\00\00\00\00\00vec_mul\00", align 8
@.str_62 = private unnamed_addr constant [24 x i8] c"\00\CB\52\09\00\00\00\00\07\00\00\00\00\00\00\00vec_dot\00", align 8
@.str_63 = private unnamed_addr constant [28 x i8] c"\AB\B4\1C\19\00\00\00\00\0B\00\00\00\00\00\00\00time_now_ms\00", align 8
@.str_64 = private unnamed_addr constant [29 x i8] c"\23\23\AC\31\00\00\00\00\0C\00\00\00\00\00\00\00monotonic_ms\00", align 8
@.str_65 = private unnamed_addr constant [25 x i8] c"\F4\3B\A3\3A\00\00\00\00\08\00\00\00\00\00\00\00sleep_ms\00", align 8
@.str_66 = private unnamed_addr constant [24 x i8] c"\C2\01\C5\1A\00\00\00\00\07\00\00\00\00\00\00\00map_lit\00", align 8
@.str_67 = private unnamed_addr constant [20 x i8] c"\9B\7F\E4\05\00\00\00\00\03\00\00\00\00\00\00\00map\00", align 8
@.str_68 = private unnamed_addr constant [24 x i8] c"\89\B0\C3\1A\00\00\00\00\07\00\00\00\00\00\00\00map_get\00", align 8
@.str_69 = private unnamed_addr constant [24 x i8] c"\85\F1\C3\1A\00\00\00\00\07\00\00\00\00\00\00\00map_has\00", align 8
@.str_70 = private unnamed_addr constant [28 x i8] c"\DE\92\96\27\00\00\00\00\0B\00\00\00\00\00\00\00map_set_val\00", align 8
@.str_71 = private unnamed_addr constant [27 x i8] c"\2E\1C\1C\35\00\00\00\00\0A\00\00\00\00\00\00\00map_remove\00", align 8
@.str_72 = private unnamed_addr constant [29 x i8] c"\C3\CF\04\20\00\00\00\00\0C\00\00\00\00\00\00\00list_set_val\00", align 8
@.str_73 = private unnamed_addr constant [25 x i8] c"\62\7A\6C\09\00\00\00\00\08\00\00\00\00\00\00\00slot_has\00", align 8
@.str_74 = private unnamed_addr constant [29 x i8] c"\BD\96\22\30\00\00\00\00\0C\00\00\00\00\00\00\00slot_get_int\00", align 8
@.str_75 = private unnamed_addr constant [24 x i8] c"\B0\FF\C4\1A\00\00\00\00\07\00\00\00\00\00\00\00map_len\00", align 8
@.str_76 = private unnamed_addr constant [25 x i8] c"\F3\C9\9A\31\00\00\00\00\08\00\00\00\00\00\00\00map_keys\00", align 8
@.str_77 = private unnamed_addr constant [26 x i8] c"\69\42\55\24\00\00\00\00\09\00\00\00\00\00\00\00list:text\00", align 8
@.str_78 = private unnamed_addr constant [27 x i8] c"\76\24\B8\01\00\00\00\00\0A\00\00\00\00\00\00\00map_values\00", align 8
@.str_79 = private unnamed_addr constant [27 x i8] c"\FA\64\B7\1F\00\00\00\00\0A\00\00\00\00\00\00\00map_get_or\00", align 8
@.str_80 = private unnamed_addr constant [28 x i8] c"\55\0B\72\25\00\00\00\00\0B\00\00\00\00\00\00\00f64_to_text\00", align 8
@.str_81 = private unnamed_addr constant [28 x i8] c"\3A\3D\32\3B\00\00\00\00\0B\00\00\00\00\00\00\00struct_cons\00", align 8
@.str_82 = private unnamed_addr constant [24 x i8] c"\34\C9\5A\22\00\00\00\00\07\00\00\00\00\00\00\00struct:\00", align 8
@.str_83 = private unnamed_addr constant [27 x i8] c"\BF\A9\5F\25\00\00\00\00\0A\00\00\00\00\00\00\00field_load\00", align 8
@.str_84 = private unnamed_addr constant [27 x i8] c"\B6\A0\0D\03\00\00\00\00\0A\00\00\00\00\00\00\00print_text\00", align 8
@.str_85 = private unnamed_addr constant [23 x i8] c"\F1\F2\BB\29\00\00\00\00\06\00\00\00\00\00\00\00alloca\00", align 8
@.str_86 = private unnamed_addr constant [21 x i8] c"\97\29\8D\38\00\00\00\00\04\00\00\00\00\00\00\00load\00", align 8
@.str_87 = private unnamed_addr constant [22 x i8] c"\1E\0B\9C\15\00\00\00\00\05\00\00\00\00\00\00\00store\00", align 8
@.str_88 = private unnamed_addr constant [22 x i8] c"\5F\72\62\0F\00\00\00\00\05\00\00\00\00\00\00\00label\00", align 8
@.str_89 = private unnamed_addr constant [19 x i8] c"\C5\3E\81\05\00\00\00\00\02\00\00\00\00\00\00\00br\00", align 8
@.str_90 = private unnamed_addr constant [22 x i8] c"\80\11\F0\14\00\00\00\00\05\00\00\00\00\00\00\00br_if\00", align 8
@.str_91 = private unnamed_addr constant [18 x i8] c"\0B\C2\0A\00\00\00\00\00\01\00\00\00\00\00\00\00|\00", align 8
@.str_92 = private unnamed_addr constant [20 x i8] c"\44\4C\E5\05\00\00\00\00\03\00\00\00\00\00\00\00phi\00", align 8
@.str_93 = private unnamed_addr constant [22 x i8] c"\21\B0\02\1A\00\00\00\00\05\00\00\00\00\00\00\00param\00", align 8
@.str_94 = private unnamed_addr constant [18 x i8] c"\05\C2\0A\00\00\00\00\00\01\00\00\00\00\00\00\00v\00", align 8
@.str_95 = private unnamed_addr constant [20 x i8] c"\2A\43\D0\05\00\00\00\00\03\00\00\00\00\00\00\00 = \00", align 8
@.str_96 = private unnamed_addr constant [24 x i8] c"\4F\EE\6C\29\00\00\00\00\07\00\00\00\00\00\00\00iconst.\00", align 8
@.str_97 = private unnamed_addr constant [18 x i8] c"\AF\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00 \00", align 8
@.str_98 = private unnamed_addr constant [24 x i8] c"\9B\B2\63\21\00\00\00\00\07\00\00\00\00\00\00\00return \00", align 8
@.str_99 = private unnamed_addr constant [18 x i8] c"\BD\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00.\00", align 8
@.str_100 = private unnamed_addr constant [19 x i8] c"\D1\22\81\05\00\00\00\00\02\00\00\00\00\00\00\00, \00", align 8
@.str_101 = private unnamed_addr constant [28 x i8] c"\79\B4\7B\05\00\00\00\00\0B\00\00\00\00\00\00\00perform_int\00", align 8
@.str_102 = private unnamed_addr constant [29 x i8] c"\6F\DE\82\04\00\00\00\00\0C\00\00\00\00\00\00\00perform_text\00", align 8
@.str_103 = private unnamed_addr constant [23 x i8] c"\CB\98\62\09\00\00\00\00\06\00\00\00\00\00\00\00fn_ref\00", align 8
@.str_104 = private unnamed_addr constant [30 x i8] c"\0C\B2\F3\1C\00\00\00\00\0D\00\00\00\00\00\00\00indirect_call\00", align 8
@.str_105 = private unnamed_addr constant [20 x i8] c"\B3\B0\E2\05\00\00\00\00\03\00\00\00\00\00\00\00fn \00", align 8
@.str_106 = private unnamed_addr constant [21 x i8] c"\14\C5\4C\2E\00\00\00\00\04\00\00\00\00\00\00\00 -> \00", align 8
@.str_107 = private unnamed_addr constant [19 x i8] c"\E5\29\81\05\00\00\00\00\02\00\00\00\00\00\00\00:\0A\00", align 8
@.str_108 = private unnamed_addr constant [21 x i8] c"\45\4E\49\2E\00\00\00\00\04\00\00\00\00\00\00\00    \00", align 8
@.str_109 = private unnamed_addr constant [18 x i8] c"\99\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00\0A\00", align 8
@.str_110 = private unnamed_addr constant [40 x i8] c"\8D\17\2A\08\00\00\00\00\17\00\00\00\00\00\00\00; orion_ir module dump\0A\00", align 8
@.str_111 = private unnamed_addr constant [21 x i8] c"\D6\D0\AB\38\00\00\00\00\04\00\00\00\00\00\00\00main\00", align 8

define ptr @ir_type_i64() {
entry:
    %v0 = getelementptr i8, ptr @.str_0, i64 16
    ret ptr %v0
}

define ptr @ir_type_ptr() {
entry:
    %v0 = getelementptr i8, ptr @.str_1, i64 16
    ret ptr %v0
}

define ptr @ir_type_bool() {
entry:
    %v0 = getelementptr i8, ptr @.str_2, i64 16
    ret ptr %v0
}

define ptr @ir_type_void() {
entry:
    %v0 = getelementptr i8, ptr @.str_3, i64 16
    ret ptr %v0
}

define i64 @compile_error(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    call i32 @puts(ptr %v0)
    %v1 = add i64 0, 0
    %v2 = call i64 @orion_err_bump()
    ret i64 %v2
}

define i64 @compile_errors() {
entry:
    %v0 = call i64 @orion_err_get()
    ret i64 %v0
}

define ptr @ir_iconst(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_4, i64 16
    %v2 = getelementptr i8, ptr @.str_0, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_iadd(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_6, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v4, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v0, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v1, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_isub(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_7, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v4, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v0, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v1, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_imul(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_8, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v4, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v0, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v1, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_idiv(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_9, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v4, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v0, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v1, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_imod(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_10, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v4, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v0, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v1, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_iand(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_11, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v4, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v0, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v1, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_ior(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_12, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v4, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v0, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v1, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_inot(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_13, i64 16
    %v2 = getelementptr i8, ptr @.str_0, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_icmp_eq(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_14, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v4, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v0, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v1, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_icmp_ne(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_15, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v4, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v0, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v1, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_icmp_lt(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_16, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v4, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v0, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v1, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_icmp_le(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_17, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v4, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v0, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v1, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_icmp_gt(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_18, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v4, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v0, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v1, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_icmp_ge(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_19, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v4, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v0, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v1, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_return(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_20, i64 16
    %v2 = getelementptr i8, ptr @.str_3, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_return_void() {
entry:
    %v0 = getelementptr i8, ptr @.str_20, i64 16
    %v1 = getelementptr i8, ptr @.str_3, i64 16
    %v2 = add i64 0, 0
    %v3 = add i64 0, 1
    %v4 = sub i64 %v2, %v3
    %v5 = add i64 0, 0
    %v6 = add i64 0, 0
    %v7 = getelementptr i8, ptr @.str_5, i64 16
    %v8 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v9 = call ptr @orion_alloc(i64 56)
    %v9.f0 = getelementptr i64, ptr %v9, i64 0
    %v9.f0.i = ptrtoint ptr %v0 to i64
    store i64 %v9.f0.i, ptr %v9.f0
    %v9.f1 = getelementptr i64, ptr %v9, i64 1
    %v9.f1.i = ptrtoint ptr %v1 to i64
    store i64 %v9.f1.i, ptr %v9.f1
    %v9.f2 = getelementptr i64, ptr %v9, i64 2
    store i64 %v4, ptr %v9.f2
    %v9.f3 = getelementptr i64, ptr %v9, i64 3
    store i64 %v5, ptr %v9.f3
    %v9.f4 = getelementptr i64, ptr %v9, i64 4
    store i64 %v6, ptr %v9.f4
    %v9.f5 = getelementptr i64, ptr %v9, i64 5
    %v9.f5.i = ptrtoint ptr %v7 to i64
    store i64 %v9.f5.i, ptr %v9.f5
    %v9.f6 = getelementptr i64, ptr %v9, i64 6
    %v9.f6.i = ptrtoint ptr %v8 to i64
    store i64 %v9.f6.i, ptr %v9.f6
    ret ptr %v9
}

define ptr @ir_print_int(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_21, i64 16
    %v2 = getelementptr i8, ptr @.str_3, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_print_float(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_22, i64 16
    %v2 = getelementptr i8, ptr @.str_3, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_select(i64 %p0, i64 %p1, i64 %p2) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = getelementptr i8, ptr @.str_23, i64 16
    %v4 = getelementptr i8, ptr @.str_0, i64 16
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v4 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v2, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_fconst(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr @.str_24, i64 16
    %v2 = getelementptr i8, ptr @.str_25, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v3, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v4, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v5, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v0 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_fbin(ptr %p0, i64 %p1, i64 %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = getelementptr i8, ptr @.str_25, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v0 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v4, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v2, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_fcmp(ptr %p0, i64 %p1, i64 %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = getelementptr i8, ptr @.str_26, i64 16
    %v4 = getelementptr i8, ptr @.str_0, i64 16
    %v5 = add i64 0, 0
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v4 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v5, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v2, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v0 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_sitofp(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_27, i64 16
    %v2 = getelementptr i8, ptr @.str_25, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_fptosi(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_28, i64 16
    %v2 = getelementptr i8, ptr @.str_0, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_call(ptr %p0, ptr %p1, ptr %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i8, ptr %p2, i64 0
    %v3 = getelementptr i8, ptr @.str_29, i64 16
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    %v6 = add i64 0, 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v4, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v5, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v6, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v0 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_print_str(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr @.str_30, i64 16
    %v2 = getelementptr i8, ptr @.str_3, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v3, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v4, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v5, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v0 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_const_str(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr @.str_31, i64 16
    %v2 = getelementptr i8, ptr @.str_32, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v3, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v4, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v5, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v0 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_text_concat(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_33, i64 16
    %v3 = getelementptr i8, ptr @.str_32, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v4, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v0, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v1, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_int_to_text(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_34, i64 16
    %v2 = getelementptr i8, ptr @.str_32, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_text_cmp(ptr %p0, i64 %p1, i64 %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v0 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v4, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v2, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_text_len(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_35, i64 16
    %v2 = getelementptr i8, ptr @.str_0, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_text_slice(i64 %p0, i64 %p1, i64 %p2) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = getelementptr i8, ptr @.str_36, i64 16
    %v4 = getelementptr i8, ptr @.str_32, i64 16
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v4 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v2, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_list_slice(i64 %p0, i64 %p1, i64 %p2, ptr %p3) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = getelementptr i8, ptr %p3, i64 0
    %v4 = getelementptr i8, ptr @.str_37, i64 16
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v4 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v2, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_fmath1(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_38, i64 16
    %v3 = getelementptr i8, ptr @.str_25, i64 16
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v1, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v4, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v5, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v0 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_fmath2(ptr %p0, i64 %p1, i64 %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = getelementptr i8, ptr @.str_39, i64 16
    %v4 = getelementptr i8, ptr @.str_25, i64 16
    %v5 = add i64 0, 0
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v4 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v1, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v2, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v5, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v0 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_text_contains(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_40, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_file_read(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_41, i64 16
    %v2 = getelementptr i8, ptr @.str_32, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_file_write(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_42, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_argc() {
entry:
    %v0 = getelementptr i8, ptr @.str_43, i64 16
    %v1 = getelementptr i8, ptr @.str_0, i64 16
    %v2 = add i64 0, 0
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v0 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v2, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_argv(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_44, i64 16
    %v2 = getelementptr i8, ptr @.str_32, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_bytes_from_text(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_45, i64 16
    %v2 = getelementptr i8, ptr @.str_46, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_bytes_to_text(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_47, i64 16
    %v2 = getelementptr i8, ptr @.str_32, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_bytes_slice(i64 %p0, i64 %p1, i64 %p2) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = getelementptr i8, ptr @.str_48, i64 16
    %v4 = getelementptr i8, ptr @.str_46, i64 16
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v4 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v2, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_bytes_concat(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_49, i64 16
    %v3 = getelementptr i8, ptr @.str_46, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_bytes_zeros(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_50, i64 16
    %v2 = getelementptr i8, ptr @.str_46, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_slot_get(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_51, i64 16
    %v2 = getelementptr i8, ptr @.str_32, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_slot_set(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_52, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_list_lit(ptr %p0, ptr %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i8, ptr @.str_53, i64 16
    %v3 = getelementptr i8, ptr @.str_54, i64 16
    %v4 = call ptr @orion_text_concat(ptr %v3, ptr %v1)
    %v5 = add i64 0, 0
    %v6 = add i64 0, 0
    %v7 = add i64 0, 0
    %v8 = getelementptr i8, ptr @.str_5, i64 16
    %v9 = call ptr @orion_alloc(i64 56)
    %v9.f0 = getelementptr i64, ptr %v9, i64 0
    %v9.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v9.f0.i, ptr %v9.f0
    %v9.f1 = getelementptr i64, ptr %v9, i64 1
    %v9.f1.i = ptrtoint ptr %v4 to i64
    store i64 %v9.f1.i, ptr %v9.f1
    %v9.f2 = getelementptr i64, ptr %v9, i64 2
    store i64 %v5, ptr %v9.f2
    %v9.f3 = getelementptr i64, ptr %v9, i64 3
    store i64 %v6, ptr %v9.f3
    %v9.f4 = getelementptr i64, ptr %v9, i64 4
    store i64 %v7, ptr %v9.f4
    %v9.f5 = getelementptr i64, ptr %v9, i64 5
    %v9.f5.i = ptrtoint ptr %v8 to i64
    store i64 %v9.f5.i, ptr %v9.f5
    %v9.f6 = getelementptr i64, ptr %v9, i64 6
    %v9.f6.i = ptrtoint ptr %v0 to i64
    store i64 %v9.f6.i, ptr %v9.f6
    ret ptr %v9
}

define ptr @ir_list_at(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_55, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_list_len(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_56, i64 16
    %v2 = getelementptr i8, ptr @.str_0, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_list_push(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_57, i64 16
    %v3 = getelementptr i8, ptr @.str_46, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_list_push_mut(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_58, i64 16
    %v3 = getelementptr i8, ptr @.str_46, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_vec_add(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_59, i64 16
    %v3 = getelementptr i8, ptr @.str_46, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_vec_sub(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_60, i64 16
    %v3 = getelementptr i8, ptr @.str_46, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_vec_mul(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_61, i64 16
    %v3 = getelementptr i8, ptr @.str_46, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_vec_dot(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_62, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_time_now_ms() {
entry:
    %v0 = getelementptr i8, ptr @.str_63, i64 16
    %v1 = getelementptr i8, ptr @.str_0, i64 16
    %v2 = add i64 0, 0
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v0 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v2, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_monotonic_ms() {
entry:
    %v0 = getelementptr i8, ptr @.str_64, i64 16
    %v1 = getelementptr i8, ptr @.str_0, i64 16
    %v2 = add i64 0, 0
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v0 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v2, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_sleep_ms(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_65, i64 16
    %v2 = getelementptr i8, ptr @.str_3, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_map_lit(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr @.str_66, i64 16
    %v2 = getelementptr i8, ptr @.str_67, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    %v6 = getelementptr i8, ptr @.str_5, i64 16
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v3, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v4, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v5, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v0 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_map_get(i64 %p0, i64 %p1, ptr %p2) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr %p2, i64 0
    %v3 = getelementptr i8, ptr @.str_68, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_map_has(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_69, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_map_set_val(i64 %p0, i64 %p1, i64 %p2) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = getelementptr i8, ptr @.str_70, i64 16
    %v4 = getelementptr i8, ptr @.str_67, i64 16
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v4 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v2, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_map_remove(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_71, i64 16
    %v3 = getelementptr i8, ptr @.str_67, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_list_set_val(i64 %p0, i64 %p1, i64 %p2, ptr %p3) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = getelementptr i8, ptr %p3, i64 0
    %v4 = getelementptr i8, ptr @.str_72, i64 16
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v4 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v2, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_slot_has(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_73, i64 16
    %v2 = getelementptr i8, ptr @.str_0, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_slot_get_int(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_74, i64 16
    %v2 = getelementptr i8, ptr @.str_0, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_map_len(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_75, i64 16
    %v2 = getelementptr i8, ptr @.str_0, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_map_keys(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_76, i64 16
    %v2 = getelementptr i8, ptr @.str_77, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_map_values(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_78, i64 16
    %v2 = getelementptr i8, ptr @.str_46, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_map_get_or(i64 %p0, i64 %p1, i64 %p2, ptr %p3) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = getelementptr i8, ptr %p3, i64 0
    %v4 = getelementptr i8, ptr @.str_79, i64 16
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v4 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v2, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_f64_to_text(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_80, i64 16
    %v2 = getelementptr i8, ptr @.str_32, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_struct_cons(ptr %p0, i64 %p1, ptr %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr %p2, i64 0
    %v3 = getelementptr i8, ptr @.str_81, i64 16
    %v4 = getelementptr i8, ptr @.str_82, i64 16
    %v5 = call ptr @orion_text_concat(ptr %v4, ptr %v0)
    %v6 = add i64 0, 0
    %v7 = add i64 0, 0
    %v8 = call ptr @orion_alloc(i64 56)
    %v8.f0 = getelementptr i64, ptr %v8, i64 0
    %v8.f0.i = ptrtoint ptr %v3 to i64
    store i64 %v8.f0.i, ptr %v8.f0
    %v8.f1 = getelementptr i64, ptr %v8, i64 1
    %v8.f1.i = ptrtoint ptr %v5 to i64
    store i64 %v8.f1.i, ptr %v8.f1
    %v8.f2 = getelementptr i64, ptr %v8, i64 2
    store i64 %v1, ptr %v8.f2
    %v8.f3 = getelementptr i64, ptr %v8, i64 3
    store i64 %v6, ptr %v8.f3
    %v8.f4 = getelementptr i64, ptr %v8, i64 4
    store i64 %v7, ptr %v8.f4
    %v8.f5 = getelementptr i64, ptr %v8, i64 5
    %v8.f5.i = ptrtoint ptr %v0 to i64
    store i64 %v8.f5.i, ptr %v8.f5
    %v8.f6 = getelementptr i64, ptr %v8, i64 6
    %v8.f6.i = ptrtoint ptr %v2 to i64
    store i64 %v8.f6.i, ptr %v8.f6
    ret ptr %v8
}

define ptr @ir_field_load(i64 %p0, i64 %p1, ptr %p2) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr %p2, i64 0
    %v3 = getelementptr i8, ptr @.str_83, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_print_text(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_84, i64 16
    %v2 = getelementptr i8, ptr @.str_3, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_alloca(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr @.str_85, i64 16
    %v2 = add i64 0, 0
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v0 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v2, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_load(i64 %p0, ptr %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i8, ptr @.str_86, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_store(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_87, i64 16
    %v3 = getelementptr i8, ptr @.str_3, i64 16
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_label(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr @.str_88, i64 16
    %v2 = getelementptr i8, ptr @.str_3, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v3, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v4, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v5, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v0 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_br(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr @.str_89, i64 16
    %v2 = getelementptr i8, ptr @.str_3, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v3, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v4, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v5, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v0 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_br_if(i64 %p0, ptr %p1, ptr %p2) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i8, ptr %p2, i64 0
    %v3 = getelementptr i8, ptr @.str_90, i64 16
    %v4 = getelementptr i8, ptr @.str_3, i64 16
    %v5 = add i64 0, 0
    %v6 = add i64 0, 0
    %v7 = getelementptr i8, ptr @.str_91, i64 16
    %v8 = call ptr @orion_text_concat(ptr %v1, ptr %v7)
    %v9 = call ptr @orion_text_concat(ptr %v8, ptr %v2)
    %v10 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v11 = call ptr @orion_alloc(i64 56)
    %v11.f0 = getelementptr i64, ptr %v11, i64 0
    %v11.f0.i = ptrtoint ptr %v3 to i64
    store i64 %v11.f0.i, ptr %v11.f0
    %v11.f1 = getelementptr i64, ptr %v11, i64 1
    %v11.f1.i = ptrtoint ptr %v4 to i64
    store i64 %v11.f1.i, ptr %v11.f1
    %v11.f2 = getelementptr i64, ptr %v11, i64 2
    store i64 %v0, ptr %v11.f2
    %v11.f3 = getelementptr i64, ptr %v11, i64 3
    store i64 %v5, ptr %v11.f3
    %v11.f4 = getelementptr i64, ptr %v11, i64 4
    store i64 %v6, ptr %v11.f4
    %v11.f5 = getelementptr i64, ptr %v11, i64 5
    %v11.f5.i = ptrtoint ptr %v9 to i64
    store i64 %v11.f5.i, ptr %v11.f5
    %v11.f6 = getelementptr i64, ptr %v11, i64 6
    %v11.f6.i = ptrtoint ptr %v10 to i64
    store i64 %v11.f6.i, ptr %v11.f6
    ret ptr %v11
}

define ptr @ir_phi(i64 %p0, ptr %p1, i64 %p2, ptr %p3, ptr %p4) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = add i64 0, %p2
    %v3 = getelementptr i8, ptr %p3, i64 0
    %v4 = getelementptr i8, ptr %p4, i64 0
    %v5 = getelementptr i8, ptr @.str_92, i64 16
    %v6 = add i64 0, 0
    %v7 = getelementptr i8, ptr @.str_91, i64 16
    %v8 = call ptr @orion_text_concat(ptr %v1, ptr %v7)
    %v9 = call ptr @orion_text_concat(ptr %v8, ptr %v3)
    %v10 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v11 = call ptr @orion_alloc(i64 56)
    %v11.f0 = getelementptr i64, ptr %v11, i64 0
    %v11.f0.i = ptrtoint ptr %v5 to i64
    store i64 %v11.f0.i, ptr %v11.f0
    %v11.f1 = getelementptr i64, ptr %v11, i64 1
    %v11.f1.i = ptrtoint ptr %v4 to i64
    store i64 %v11.f1.i, ptr %v11.f1
    %v11.f2 = getelementptr i64, ptr %v11, i64 2
    store i64 %v6, ptr %v11.f2
    %v11.f3 = getelementptr i64, ptr %v11, i64 3
    store i64 %v0, ptr %v11.f3
    %v11.f4 = getelementptr i64, ptr %v11, i64 4
    store i64 %v2, ptr %v11.f4
    %v11.f5 = getelementptr i64, ptr %v11, i64 5
    %v11.f5.i = ptrtoint ptr %v9 to i64
    store i64 %v11.f5.i, ptr %v11.f5
    %v11.f6 = getelementptr i64, ptr %v11, i64 6
    %v11.f6.i = ptrtoint ptr %v10 to i64
    store i64 %v11.f6.i, ptr %v11.f6
    ret ptr %v11
}

define ptr @ir_param(i64 %p0, ptr %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i8, ptr @.str_93, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_5, i64 16
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v3, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v4, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v5 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_fn_new(ptr %p0, ptr %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v3 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v4 = call ptr @orion_alloc(i64 32)
    %v4.f0 = getelementptr i64, ptr %v4, i64 0
    %v4.f0.i = ptrtoint ptr %v0 to i64
    store i64 %v4.f0.i, ptr %v4.f0
    %v4.f1 = getelementptr i64, ptr %v4, i64 1
    %v4.f1.i = ptrtoint ptr %v1 to i64
    store i64 %v4.f1.i, ptr %v4.f1
    %v4.f2 = getelementptr i64, ptr %v4, i64 2
    %v4.f2.i = ptrtoint ptr %v2 to i64
    store i64 %v4.f2.i, ptr %v4.f2
    %v4.f3 = getelementptr i64, ptr %v4, i64 3
    %v4.f3.i = ptrtoint ptr %v3 to i64
    store i64 %v4.f3.i, ptr %v4.f3
    ret ptr %v4
}

define ptr @ir_fn_add_param(ptr %p0, ptr %p1, ptr %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i8, ptr %p2, i64 0
    %v3 = call ptr @orion_alloc(i64 16)
    %v3.f0 = getelementptr i64, ptr %v3, i64 0
    %v3.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v3.f0.i, ptr %v3.f0
    %v3.f1 = getelementptr i64, ptr %v3, i64 1
    %v3.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v3.f1.i, ptr %v3.f1
    %v4.slot = getelementptr i64, ptr %v0, i64 2
    %v4.i = load i64, ptr %v4.slot
    %v4 = inttoptr i64 %v4.i to ptr
    %v5.p = ptrtoint ptr %v3 to i64
    %v5 = call ptr @orion_list_push(ptr %v4, i64 %v5.p)
    %v6.slot = getelementptr i64, ptr %v0, i64 0
    %v6.i = load i64, ptr %v6.slot
    %v6 = inttoptr i64 %v6.i to ptr
    %v7.slot = getelementptr i64, ptr %v0, i64 1
    %v7.i = load i64, ptr %v7.slot
    %v7 = inttoptr i64 %v7.i to ptr
    %v8.slot = getelementptr i64, ptr %v0, i64 3
    %v8.i = load i64, ptr %v8.slot
    %v8 = inttoptr i64 %v8.i to ptr
    %v9 = call ptr @orion_alloc(i64 32)
    %v9.f0 = getelementptr i64, ptr %v9, i64 0
    %v9.f0.i = ptrtoint ptr %v6 to i64
    store i64 %v9.f0.i, ptr %v9.f0
    %v9.f1 = getelementptr i64, ptr %v9, i64 1
    %v9.f1.i = ptrtoint ptr %v7 to i64
    store i64 %v9.f1.i, ptr %v9.f1
    %v9.f2 = getelementptr i64, ptr %v9, i64 2
    %v9.f2.i = ptrtoint ptr %v5 to i64
    store i64 %v9.f2.i, ptr %v9.f2
    %v9.f3 = getelementptr i64, ptr %v9, i64 3
    %v9.f3.i = ptrtoint ptr %v8 to i64
    store i64 %v9.f3.i, ptr %v9.f3
    ret ptr %v9
}

define ptr @ir_fn_push(ptr %p0, ptr %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2.slot = getelementptr i64, ptr %v0, i64 3
    %v2.i = load i64, ptr %v2.slot
    %v2 = inttoptr i64 %v2.i to ptr
    %v3 = alloca ptr, align 8
    store ptr %v2, ptr %v3
    %v4 = add i64 0, 0
    %v5 = load ptr, ptr %v3
    %v6 = call i64 @orion_list_len(ptr %v5)
    %v7 = load ptr, ptr %v3
    %v8.p = ptrtoint ptr %v1 to i64
    %v8 = call ptr @orion_list_push_mut(ptr %v7, i64 %v8.p)
    store ptr %v8, ptr %v3
    %v9 = add i64 0, 0
    %v10.slot = getelementptr i64, ptr %v0, i64 0
    %v10.i = load i64, ptr %v10.slot
    %v10 = inttoptr i64 %v10.i to ptr
    %v11.slot = getelementptr i64, ptr %v0, i64 1
    %v11.i = load i64, ptr %v11.slot
    %v11 = inttoptr i64 %v11.i to ptr
    %v12.slot = getelementptr i64, ptr %v0, i64 2
    %v12.i = load i64, ptr %v12.slot
    %v12 = inttoptr i64 %v12.i to ptr
    %v13 = load ptr, ptr %v3
    %v14 = call ptr @orion_alloc(i64 32)
    %v14.f0 = getelementptr i64, ptr %v14, i64 0
    %v14.f0.i = ptrtoint ptr %v10 to i64
    store i64 %v14.f0.i, ptr %v14.f0
    %v14.f1 = getelementptr i64, ptr %v14, i64 1
    %v14.f1.i = ptrtoint ptr %v11 to i64
    store i64 %v14.f1.i, ptr %v14.f1
    %v14.f2 = getelementptr i64, ptr %v14, i64 2
    %v14.f2.i = ptrtoint ptr %v12 to i64
    store i64 %v14.f2.i, ptr %v14.f2
    %v14.f3 = getelementptr i64, ptr %v14, i64 3
    %v14.f3.i = ptrtoint ptr %v13 to i64
    store i64 %v14.f3.i, ptr %v14.f3
    %v15 = call ptr @orion_alloc(i64 16)
    %v15.f0 = getelementptr i64, ptr %v15, i64 0
    %v15.f0.i = ptrtoint ptr %v14 to i64
    store i64 %v15.f0.i, ptr %v15.f0
    %v15.f1 = getelementptr i64, ptr %v15, i64 1
    store i64 %v6, ptr %v15.f1
    ret ptr %v15
}

define ptr @ir_fn_set_inst(ptr %p0, i64 %p1, ptr %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr %p2, i64 0
    %v3.slot = getelementptr i64, ptr %v0, i64 3
    %v3.i = load i64, ptr %v3.slot
    %v3 = inttoptr i64 %v3.i to ptr
    %v4 = alloca ptr, align 8
    store ptr %v3, ptr %v4
    %v5 = add i64 0, 0
    %v6 = load ptr, ptr %v4
    %v7.p = ptrtoint ptr %v2 to i64
    call void @orion_list_set(ptr %v6, i64 %v1, i64 %v7.p)
    %v7 = getelementptr i8, ptr %v6, i64 0
    store ptr %v7, ptr %v4
    %v8 = add i64 0, 0
    %v9.slot = getelementptr i64, ptr %v0, i64 0
    %v9.i = load i64, ptr %v9.slot
    %v9 = inttoptr i64 %v9.i to ptr
    %v10.slot = getelementptr i64, ptr %v0, i64 1
    %v10.i = load i64, ptr %v10.slot
    %v10 = inttoptr i64 %v10.i to ptr
    %v11.slot = getelementptr i64, ptr %v0, i64 2
    %v11.i = load i64, ptr %v11.slot
    %v11 = inttoptr i64 %v11.i to ptr
    %v12 = load ptr, ptr %v4
    %v13 = call ptr @orion_alloc(i64 32)
    %v13.f0 = getelementptr i64, ptr %v13, i64 0
    %v13.f0.i = ptrtoint ptr %v9 to i64
    store i64 %v13.f0.i, ptr %v13.f0
    %v13.f1 = getelementptr i64, ptr %v13, i64 1
    %v13.f1.i = ptrtoint ptr %v10 to i64
    store i64 %v13.f1.i, ptr %v13.f1
    %v13.f2 = getelementptr i64, ptr %v13, i64 2
    %v13.f2.i = ptrtoint ptr %v11 to i64
    store i64 %v13.f2.i, ptr %v13.f2
    %v13.f3 = getelementptr i64, ptr %v13, i64 3
    %v13.f3.i = ptrtoint ptr %v12 to i64
    store i64 %v13.f3.i, ptr %v13.f3
    ret ptr %v13
}

define ptr @ir_module_new() {
entry:
    %v0 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v1 = call ptr @orion_alloc(i64 8)
    %v1.f0 = getelementptr i64, ptr %v1, i64 0
    %v1.f0.i = ptrtoint ptr %v0 to i64
    store i64 %v1.f0.i, ptr %v1.f0
    ret ptr %v1
}

define ptr @ir_module_add_fn(ptr %p0, ptr %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2.slot = getelementptr i64, ptr %v0, i64 0
    %v2.i = load i64, ptr %v2.slot
    %v2 = inttoptr i64 %v2.i to ptr
    %v3.p = ptrtoint ptr %v1 to i64
    %v3 = call ptr @orion_list_push(ptr %v2, i64 %v3.p)
    %v4 = call ptr @orion_alloc(i64 8)
    %v4.f0 = getelementptr i64, ptr %v4, i64 0
    %v4.f0.i = ptrtoint ptr %v3 to i64
    store i64 %v4.f0.i, ptr %v4.f0
    ret ptr %v4
}

define ptr @ir_dump_value_ref(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, 0
    %v2.b = icmp slt i64 %v0, %v1
    %v2 = zext i1 %v2.b to i64
    %v3.cb = icmp ne i64 %v2, 0
    br i1 %v3.cb, label %if_3_then, label %if_3_else
if_3_then:
    %v5 = getelementptr i8, ptr @.str_3, i64 16
    br label %if_3_merge
if_3_else:
    %v8 = getelementptr i8, ptr @.str_94, i64 16
    %v9 = call ptr @orion_int_to_text(i64 %v0)
    %v10 = call ptr @orion_text_concat(ptr %v8, ptr %v9)
    br label %if_3_merge
if_3_merge:
    %v13 = phi ptr [ %v5, %if_3_then ], [ %v10, %if_3_else ]
    ret ptr %v13
}

define ptr @ir_dump_instruction(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = call ptr @ir_dump_value_ref(i64 %v1)
    %v3 = getelementptr i8, ptr @.str_95, i64 16
    %v4 = call ptr @orion_text_concat(ptr %v2, ptr %v3)
    %v5.slot = getelementptr i64, ptr %v0, i64 0
    %v5.i = load i64, ptr %v5.slot
    %v5 = inttoptr i64 %v5.i to ptr
    %v6 = getelementptr i8, ptr @.str_4, i64 16
    %v7.e = call i64 @orion_text_eq(ptr %v5, ptr %v6)
    %v7 = add i64 %v7.e, 0
    %v8.cb = icmp ne i64 %v7, 0
    br i1 %v8.cb, label %if_8_then, label %if_8_else
if_8_then:
    %v10 = getelementptr i8, ptr @.str_96, i64 16
    %v11 = call ptr @orion_text_concat(ptr %v4, ptr %v10)
    %v12.slot = getelementptr i64, ptr %v0, i64 1
    %v12.i = load i64, ptr %v12.slot
    %v12 = inttoptr i64 %v12.i to ptr
    %v13 = call ptr @orion_text_concat(ptr %v11, ptr %v12)
    %v14 = getelementptr i8, ptr @.str_97, i64 16
    %v15 = call ptr @orion_text_concat(ptr %v13, ptr %v14)
    %v16.slot = getelementptr i64, ptr %v0, i64 2
    %v16 = load i64, ptr %v16.slot
    %v17 = call ptr @orion_int_to_text(i64 %v16)
    %v18 = call ptr @orion_text_concat(ptr %v15, ptr %v17)
    br label %if_8_merge
if_8_else:
    %v21 = getelementptr i8, ptr @.str_20, i64 16
    %v22.e = call i64 @orion_text_eq(ptr %v5, ptr %v21)
    %v22 = add i64 %v22.e, 0
    %v23.cb = icmp ne i64 %v22, 0
    br i1 %v23.cb, label %if_23_then, label %if_23_else
if_23_then:
    %v25 = getelementptr i8, ptr @.str_98, i64 16
    %v26.slot = getelementptr i64, ptr %v0, i64 2
    %v26 = load i64, ptr %v26.slot
    %v27 = call ptr @ir_dump_value_ref(i64 %v26)
    %v28 = call ptr @orion_text_concat(ptr %v25, ptr %v27)
    br label %if_23_merge
if_23_else:
    %v31.slot = getelementptr i64, ptr %v0, i64 3
    %v31 = load i64, ptr %v31.slot
    %v32 = call ptr @ir_dump_value_ref(i64 %v31)
    %v33.slot = getelementptr i64, ptr %v0, i64 4
    %v33 = load i64, ptr %v33.slot
    %v34 = call ptr @ir_dump_value_ref(i64 %v33)
    %v35 = call ptr @orion_text_concat(ptr %v4, ptr %v5)
    %v36 = getelementptr i8, ptr @.str_99, i64 16
    %v37 = call ptr @orion_text_concat(ptr %v35, ptr %v36)
    %v38.slot = getelementptr i64, ptr %v0, i64 1
    %v38.i = load i64, ptr %v38.slot
    %v38 = inttoptr i64 %v38.i to ptr
    %v39 = call ptr @orion_text_concat(ptr %v37, ptr %v38)
    %v40 = getelementptr i8, ptr @.str_97, i64 16
    %v41 = call ptr @orion_text_concat(ptr %v39, ptr %v40)
    %v42 = call ptr @orion_text_concat(ptr %v41, ptr %v32)
    %v43 = getelementptr i8, ptr @.str_100, i64 16
    %v44 = call ptr @orion_text_concat(ptr %v42, ptr %v43)
    %v45 = call ptr @orion_text_concat(ptr %v44, ptr %v34)
    br label %if_23_merge
if_23_merge:
    %v48 = phi ptr [ %v28, %if_23_then ], [ %v45, %if_23_else ]
    br label %if_8_merge
if_8_merge:
    %v51 = phi ptr [ %v18, %if_8_then ], [ %v48, %if_23_merge ]
    ret ptr %v51
}

define ptr @ir_perform_int(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_101, i64 16
    %v3 = getelementptr i8, ptr @.str_0, i64 16
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v4, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v5, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v0 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_perform_text(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_102, i64 16
    %v3 = getelementptr i8, ptr @.str_32, i64 16
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v4, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v1, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v5, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v0 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_fn_ref(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr @.str_103, i64 16
    %v2 = getelementptr i8, ptr @.str_1, i64 16
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v3, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v4, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v5, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v0 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_indirect_call(i64 %p0, ptr %p1, ptr %p2) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i8, ptr %p2, i64 0
    %v3 = getelementptr i8, ptr @.str_104, i64 16
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    %v6 = getelementptr i8, ptr @.str_5, i64 16
    %v7 = call ptr @orion_alloc(i64 56)
    %v7.f0 = getelementptr i64, ptr %v7, i64 0
    %v7.f0.i = ptrtoint ptr %v3 to i64
    store i64 %v7.f0.i, ptr %v7.f0
    %v7.f1 = getelementptr i64, ptr %v7, i64 1
    %v7.f1.i = ptrtoint ptr %v2 to i64
    store i64 %v7.f1.i, ptr %v7.f1
    %v7.f2 = getelementptr i64, ptr %v7, i64 2
    store i64 %v0, ptr %v7.f2
    %v7.f3 = getelementptr i64, ptr %v7, i64 3
    store i64 %v4, ptr %v7.f3
    %v7.f4 = getelementptr i64, ptr %v7, i64 4
    store i64 %v5, ptr %v7.f4
    %v7.f5 = getelementptr i64, ptr %v7, i64 5
    %v7.f5.i = ptrtoint ptr %v6 to i64
    store i64 %v7.f5.i, ptr %v7.f5
    %v7.f6 = getelementptr i64, ptr %v7, i64 6
    %v7.f6.i = ptrtoint ptr %v1 to i64
    store i64 %v7.f6.i, ptr %v7.f6
    ret ptr %v7
}

define ptr @ir_dump_fn(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr @.str_105, i64 16
    %v2.slot = getelementptr i64, ptr %v0, i64 0
    %v2.i = load i64, ptr %v2.slot
    %v2 = inttoptr i64 %v2.i to ptr
    %v3 = call ptr @orion_text_concat(ptr %v1, ptr %v2)
    %v4 = getelementptr i8, ptr @.str_106, i64 16
    %v5 = call ptr @orion_text_concat(ptr %v3, ptr %v4)
    %v6.slot = getelementptr i64, ptr %v0, i64 1
    %v6.i = load i64, ptr %v6.slot
    %v6 = inttoptr i64 %v6.i to ptr
    %v7 = call ptr @orion_text_concat(ptr %v5, ptr %v6)
    %v8 = getelementptr i8, ptr @.str_107, i64 16
    %v9 = call ptr @orion_text_concat(ptr %v7, ptr %v8)
    %v10 = alloca ptr, align 8
    store ptr %v9, ptr %v10
    %v11 = add i64 0, 0
    %v12.slot = getelementptr i64, ptr %v0, i64 3
    %v12.i = load i64, ptr %v12.slot
    %v12 = inttoptr i64 %v12.i to ptr
    %v13 = call i64 @orion_list_len(ptr %v12)
    %v14 = add i64 0, 0
    %v15 = alloca i64, align 8
    store i64 %v14, ptr %v15
    %v16 = add i64 0, 0
    br label %for_14_header
for_14_header:
    %v19 = load i64, ptr %v15
    %v20.b = icmp slt i64 %v19, %v13
    %v20 = zext i1 %v20.b to i64
    %v21.cb = icmp ne i64 %v20, 0
    br i1 %v21.cb, label %for_14_body, label %for_14_end
for_14_body:
    %v23.slot = getelementptr i64, ptr %v0, i64 3
    %v23.i = load i64, ptr %v23.slot
    %v23 = inttoptr i64 %v23.i to ptr
    %v24.i = call i64 @orion_list_at(ptr %v23, i64 %v19)
    %v24 = inttoptr i64 %v24.i to ptr
    %v25 = call ptr @ir_dump_instruction(ptr %v24, i64 %v19)
    %v26 = load ptr, ptr %v10
    %v27 = getelementptr i8, ptr @.str_108, i64 16
    %v28 = call ptr @orion_text_concat(ptr %v26, ptr %v27)
    %v29 = call ptr @orion_text_concat(ptr %v28, ptr %v25)
    %v30 = getelementptr i8, ptr @.str_109, i64 16
    %v31 = call ptr @orion_text_concat(ptr %v29, ptr %v30)
    store ptr %v31, ptr %v10
    %v32 = add i64 0, 0
    br label %for_14_step
for_14_step:
    %v35 = add i64 0, 1
    %v36 = add i64 %v19, %v35
    store i64 %v36, ptr %v15
    %v37 = add i64 0, 0
    br label %for_14_header
for_14_end:
    %v40 = load ptr, ptr %v10
    ret ptr %v40
}

define ptr @ir_dump_module(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr @.str_110, i64 16
    %v2 = alloca ptr, align 8
    store ptr %v1, ptr %v2
    %v3 = add i64 0, 0
    %v4.slot = getelementptr i64, ptr %v0, i64 0
    %v4.i = load i64, ptr %v4.slot
    %v4 = inttoptr i64 %v4.i to ptr
    %v5 = call i64 @orion_list_len(ptr %v4)
    %v6 = add i64 0, 0
    %v7 = alloca i64, align 8
    store i64 %v6, ptr %v7
    %v8 = add i64 0, 0
    br label %for_6_header
for_6_header:
    %v11 = load i64, ptr %v7
    %v12.b = icmp slt i64 %v11, %v5
    %v12 = zext i1 %v12.b to i64
    %v13.cb = icmp ne i64 %v12, 0
    br i1 %v13.cb, label %for_6_body, label %for_6_end
for_6_body:
    %v15.slot = getelementptr i64, ptr %v0, i64 0
    %v15.i = load i64, ptr %v15.slot
    %v15 = inttoptr i64 %v15.i to ptr
    %v16.i = call i64 @orion_list_at(ptr %v15, i64 %v11)
    %v16 = inttoptr i64 %v16.i to ptr
    %v17 = load ptr, ptr %v2
    %v18 = call ptr @ir_dump_fn(ptr %v16)
    %v19 = call ptr @orion_text_concat(ptr %v17, ptr %v18)
    %v20 = getelementptr i8, ptr @.str_109, i64 16
    %v21 = call ptr @orion_text_concat(ptr %v19, ptr %v20)
    store ptr %v21, ptr %v2
    %v22 = add i64 0, 0
    br label %for_6_step
for_6_step:
    %v25 = add i64 0, 1
    %v26 = add i64 %v11, %v25
    store i64 %v26, ptr %v7
    %v27 = add i64 0, 0
    br label %for_6_header
for_6_end:
    %v30 = load ptr, ptr %v2
    ret ptr %v30
}

define i64 @orion_main() {
entry:
    %v0 = add i64 0, 42
    %v1 = call ptr @ir_iconst(i64 %v0)
    %v2 = add i64 0, 0
    %v3 = add i64 0, 1
    %v4 = call ptr @ir_iadd(i64 %v2, i64 %v3)
    %v5.slot = getelementptr i64, ptr %v1, i64 0
    %v5.i = load i64, ptr %v5.slot
    %v5 = inttoptr i64 %v5.i to ptr
    %v6.slot = getelementptr i64, ptr %v1, i64 2
    %v6 = load i64, ptr %v6.slot
    %v7 = getelementptr i8, ptr @.str_111, i64 16
    %v8 = getelementptr i8, ptr @.str_0, i64 16
    %v9 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v10 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v11 = call ptr @orion_alloc(i64 32)
    %v11.f0 = getelementptr i64, ptr %v11, i64 0
    %v11.f0.i = ptrtoint ptr %v7 to i64
    store i64 %v11.f0.i, ptr %v11.f0
    %v11.f1 = getelementptr i64, ptr %v11, i64 1
    %v11.f1.i = ptrtoint ptr %v8 to i64
    store i64 %v11.f1.i, ptr %v11.f1
    %v11.f2 = getelementptr i64, ptr %v11, i64 2
    %v11.f2.i = ptrtoint ptr %v9 to i64
    store i64 %v11.f2.i, ptr %v11.f2
    %v11.f3 = getelementptr i64, ptr %v11, i64 3
    %v11.f3.i = ptrtoint ptr %v10 to i64
    store i64 %v11.f3.i, ptr %v11.f3
    %v12 = call ptr @ir_fn_push(ptr %v11, ptr %v1)
    %v13.slot = getelementptr i64, ptr %v12, i64 0
    %v13.i = load i64, ptr %v13.slot
    %v13 = inttoptr i64 %v13.i to ptr
    %v14.slot = getelementptr i64, ptr %v13, i64 3
    %v14.i = load i64, ptr %v14.slot
    %v14 = inttoptr i64 %v14.i to ptr
    %v15 = call i64 @orion_list_len(ptr %v14)
    %v16 = getelementptr i8, ptr @.str_96, i64 16
    %v17.slot = getelementptr i64, ptr %v1, i64 1
    %v17.i = load i64, ptr %v17.slot
    %v17 = inttoptr i64 %v17.i to ptr
    %v18 = call ptr @orion_text_concat(ptr %v16, ptr %v17)
    %v19 = getelementptr i8, ptr @.str_95, i64 16
    %v20 = call ptr @orion_text_concat(ptr %v18, ptr %v19)
    %v21 = call ptr @orion_int_to_text(i64 %v6)
    %v22 = call ptr @orion_text_concat(ptr %v20, ptr %v21)
    %v23 = add i64 %v6, %v15
    %v24 = add i64 0, 1
    %v25 = sub i64 %v23, %v24
    ret i64 %v25
}

@orion_argc = global i64 0
@orion_argv = global ptr null

define i32 @main(i32 %argc, ptr %argv) {
entry:
  %argc64 = sext i32 %argc to i64
  store i64 %argc64, ptr @orion_argc
  store ptr %argv, ptr @orion_argv
  %ret = call i64 @orion_main()
  %ret32 = trunc i64 %ret to i32
  ret i32 %ret32
}
