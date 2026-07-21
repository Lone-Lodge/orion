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
@.msg_oob = private unnamed_addr constant [48 x i8] c"orion: list index %lld out of range (len %lld)\0A\00"
@.msg_divz = private unnamed_addr constant [25 x i8] c"orion: division by zero\0A\00"
@.msg_modz = private unnamed_addr constant [23 x i8] c"orion: modulo by zero\0A\00"
@.msg_require = private unnamed_addr constant [27 x i8] c"orion: requirement failed\0A\00"
@.msg_ensure = private unnamed_addr constant [29 x i8] c"orion: postcondition failed\0A\00"
declare void @exit(i32)

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
  %at_len_slot = getelementptr i64, ptr %list, i64 1
  %at_len = load i64, ptr %at_len_slot
  %at_oob = icmp uge i64 %idx, %at_len
  br i1 %at_oob, label %at_fail, label %at_ok
at_fail:
  %_atp = call i32 (ptr, ...) @printf(ptr @.msg_oob, i64 %idx, i64 %at_len)
  call void @exit(i32 70)
  unreachable
at_ok:
  %offset = add i64 %idx, 2
  %slot = getelementptr i64, ptr %list, i64 %offset
  %val = load i64, ptr %slot
  ret i64 %val
}

define i64 @orion_idiv(i64 %a, i64 %b) {
entry:
  %dz = icmp eq i64 %b, 0
  br i1 %dz, label %dfail, label %dok
dfail:
  %_dp = call i32 (ptr, ...) @printf(ptr @.msg_divz)
  call void @exit(i32 70)
  unreachable
dok:
  %dq = sdiv i64 %a, %b
  ret i64 %dq
}

define i64 @orion_imod(i64 %a, i64 %b) {
entry:
  %mz = icmp eq i64 %b, 0
  br i1 %mz, label %mfail, label %mok
mfail:
  %_mp = call i32 (ptr, ...) @printf(ptr @.msg_modz)
  call void @exit(i32 70)
  unreachable
mok:
  %mr = srem i64 %a, %b
  ret i64 %mr
}

define i64 @orion_require(i64 %c) {
entry:
  %rq = icmp eq i64 %c, 0
  br i1 %rq, label %rfail, label %rok
rfail:
  %_rp = call i32 (ptr, ...) @printf(ptr @.msg_require)
  call void @exit(i32 70)
  unreachable
rok:
  ret i64 %c
}

define i64 @orion_ensure(i64 %c) {
entry:
  %eq0 = icmp eq i64 %c, 0
  br i1 %eq0, label %efail, label %eok
efail:
  %_ep = call i32 (ptr, ...) @printf(ptr @.msg_ensure)
  call void @exit(i32 70)
  unreachable
eok:
  ret i64 %c
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


@.str_0 = private unnamed_addr constant [19 x i8] c"\B4\44\81\05\00\00\00\00\02\00\00\00\00\00\00\00n=\00", align 8
@.str_1 = private unnamed_addr constant [22 x i8] c"\9E\FC\98\02\00\00\00\00\05\00\00\00\00\00\00\00alpha\00", align 8
@.str_2 = private unnamed_addr constant [19 x i8] c"\CC\48\81\05\00\00\00\00\02\00\00\00\00\00\00\00v=\00", align 8
@.str_3 = private unnamed_addr constant [19 x i8] c"\9C\40\81\05\00\00\00\00\02\00\00\00\00\00\00\00f=\00", align 8
@.str_4 = private unnamed_addr constant [19 x i8] c"\13\3F\81\05\00\00\00\00\02\00\00\00\00\00\00\00c=\00", align 8
@.str_5 = private unnamed_addr constant [20 x i8] c"\9D\E3\E1\05\00\00\00\00\03\00\00\00\00\00\00\00cf=\00", align 8
@.str_6 = private unnamed_addr constant [20 x i8] c"\C7\EA\E1\05\00\00\00\00\03\00\00\00\00\00\00\00ct=\00", align 8
@.str_7 = private unnamed_addr constant [21 x i8] c"\A3\01\D7\39\00\00\00\00\04\00\00\00\00\00\00\00v=21\00", align 8
@.str_8 = private unnamed_addr constant [21 x i8] c"\F3\27\B2\37\00\00\00\00\04\00\00\00\00\00\00\00f=21\00", align 8
@.str_9 = private unnamed_addr constant [21 x i8] c"\29\40\4B\37\00\00\00\00\04\00\00\00\00\00\00\00c=42\00", align 8
@.str_10 = private unnamed_addr constant [22 x i8] c"\08\22\D9\24\00\00\00\00\05\00\00\00\00\00\00\00cf=42\00", align 8
@.str_11 = private unnamed_addr constant [27 x i8] c"\01\E2\42\1E\00\00\00\00\0A\00\00\00\00\00\00\00ct=n=alpha\00", align 8
@.str_12 = private unnamed_addr constant [18 x i8] c"\FF\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00p\00", align 8
@.str_13 = private unnamed_addr constant [20 x i8] c"\54\A5\E1\05\00\00\00\00\03\00\00\00\00\00\00\00bob\00", align 8
@.str_14 = private unnamed_addr constant [22 x i8] c"\49\FA\AA\2D\00\00\00\00\05\00\00\00\00\00\00\00n=bob\00", align 8
@.str_15 = private unnamed_addr constant [19 x i8] c"\CE\41\81\05\00\00\00\00\02\00\00\00\00\00\00\00hi\00", align 8
@.str_16 = private unnamed_addr constant [18 x i8] c"\BC\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00-\00", align 8
@.str_17 = private unnamed_addr constant [22 x i8] c"\A3\F0\CA\05\00\00\00\00\05\00\00\00\00\00\00\00hi-hi\00", align 8
@.str_18 = private unnamed_addr constant [21 x i8] c"\75\D2\6A\3A\00\00\00\00\04\00\00\00\00\00\00\00zero\00", align 8
@.str_19 = private unnamed_addr constant [24 x i8] c"\04\DD\6C\38\00\00\00\00\07\00\00\00\00\00\00\00nonzero\00", align 8

define i64 @double_int(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 %v0, %v0
    ret i64 %v1
}

define ptr @label_for(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr @.str_0, i64 16
    %v2 = call ptr @orion_text_concat(ptr %v1, ptr %v0)
    ret ptr %v2
}

define i64 @orion_main() {
entry:
    %v0 = add i64 0, 21
    %v1 = getelementptr i8, ptr @.str_1, i64 16
    %v2 = call ptr @orion_alloc(i64 16)
    %v2.f0 = getelementptr i64, ptr %v2, i64 0
    store i64 %v0, ptr %v2.f0
    %v2.f1 = getelementptr i64, ptr %v2, i64 1
    %v2.f1.i = ptrtoint ptr %v1 to i64
    store i64 %v2.f1.i, ptr %v2.f1
    %v3 = add i64 0, 21
    %v4 = add i64 0, 0
    %v5 = alloca i64, align 8
    store i64 %v4, ptr %v5
    %v6 = add i64 0, 0
    %v7 = getelementptr i8, ptr @.str_2, i64 16
    %v8 = call ptr @orion_int_to_text(i64 %v3)
    %v9 = call ptr @orion_text_concat(ptr %v7, ptr %v8)
    %v10 = getelementptr i8, ptr @.str_3, i64 16
    %v11.slot = getelementptr i64, ptr %v2, i64 0
    %v11 = load i64, ptr %v11.slot
    %v12 = call ptr @orion_int_to_text(i64 %v11)
    %v13 = call ptr @orion_text_concat(ptr %v10, ptr %v12)
    %v14 = getelementptr i8, ptr @.str_4, i64 16
    %v15 = call i64 @double_int(i64 %v3)
    %v16 = call ptr @orion_int_to_text(i64 %v15)
    %v17 = call ptr @orion_text_concat(ptr %v14, ptr %v16)
    %v18 = getelementptr i8, ptr @.str_5, i64 16
    %v19.slot = getelementptr i64, ptr %v2, i64 0
    %v19 = load i64, ptr %v19.slot
    %v20 = call i64 @double_int(i64 %v19)
    %v21 = call ptr @orion_int_to_text(i64 %v20)
    %v22 = call ptr @orion_text_concat(ptr %v18, ptr %v21)
    %v23 = getelementptr i8, ptr @.str_6, i64 16
    %v24.slot = getelementptr i64, ptr %v2, i64 1
    %v24.i = load i64, ptr %v24.slot
    %v24 = inttoptr i64 %v24.i to ptr
    %v25 = call ptr @label_for(ptr %v24)
    %v26 = call ptr @orion_text_concat(ptr %v23, ptr %v25)
    %v27 = getelementptr i8, ptr @.str_7, i64 16
    %v28 = call i64 @orion_text_contains(ptr %v9, ptr %v27)
    %v29.cb = icmp ne i64 %v28, 0
    br i1 %v29.cb, label %if_29_then, label %if_29_else
if_29_then:
    %v31 = load i64, ptr %v5
    %v32 = add i64 0, 1
    %v33 = add i64 %v31, %v32
    store i64 %v33, ptr %v5
    %v34 = add i64 0, 0
    br label %if_29_merge
if_29_else:
    br label %if_29_merge
if_29_merge:
    %v39 = getelementptr i8, ptr @.str_8, i64 16
    %v40 = call i64 @orion_text_contains(ptr %v13, ptr %v39)
    %v41.cb = icmp ne i64 %v40, 0
    br i1 %v41.cb, label %if_41_then, label %if_41_else
if_41_then:
    %v43 = load i64, ptr %v5
    %v44 = add i64 0, 1
    %v45 = add i64 %v43, %v44
    store i64 %v45, ptr %v5
    %v46 = add i64 0, 0
    br label %if_41_merge
if_41_else:
    br label %if_41_merge
if_41_merge:
    %v51 = getelementptr i8, ptr @.str_9, i64 16
    %v52 = call i64 @orion_text_contains(ptr %v17, ptr %v51)
    %v53.cb = icmp ne i64 %v52, 0
    br i1 %v53.cb, label %if_53_then, label %if_53_else
if_53_then:
    %v55 = load i64, ptr %v5
    %v56 = add i64 0, 1
    %v57 = add i64 %v55, %v56
    store i64 %v57, ptr %v5
    %v58 = add i64 0, 0
    br label %if_53_merge
if_53_else:
    br label %if_53_merge
if_53_merge:
    %v63 = getelementptr i8, ptr @.str_10, i64 16
    %v64 = call i64 @orion_text_contains(ptr %v22, ptr %v63)
    %v65.cb = icmp ne i64 %v64, 0
    br i1 %v65.cb, label %if_65_then, label %if_65_else
if_65_then:
    %v67 = load i64, ptr %v5
    %v68 = add i64 0, 1
    %v69 = add i64 %v67, %v68
    store i64 %v69, ptr %v5
    %v70 = add i64 0, 0
    br label %if_65_merge
if_65_else:
    br label %if_65_merge
if_65_merge:
    %v75 = getelementptr i8, ptr @.str_11, i64 16
    %v76 = call i64 @orion_text_contains(ptr %v26, ptr %v75)
    %v77.cb = icmp ne i64 %v76, 0
    br i1 %v77.cb, label %if_77_then, label %if_77_else
if_77_then:
    %v79 = load i64, ptr %v5
    %v80 = add i64 0, 1
    %v81 = add i64 %v79, %v80
    store i64 %v81, ptr %v5
    %v82 = add i64 0, 0
    br label %if_77_merge
if_77_else:
    br label %if_77_merge
if_77_merge:
    %v87 = add i64 0, 0
    %v88 = alloca i64, align 8
    store i64 %v87, ptr %v88
    %v89 = add i64 0, 0
    %v90 = add i64 0, 0
    %v91 = add i64 0, 5
    %v92 = alloca i64, align 8
    store i64 %v90, ptr %v92
    %v93 = add i64 0, 0
    br label %for_90_header
for_90_header:
    %v96 = load i64, ptr %v92
    %v97.b = icmp slt i64 %v96, %v91
    %v97 = zext i1 %v97.b to i64
    %v98.cb = icmp ne i64 %v97, 0
    br i1 %v98.cb, label %for_90_body, label %for_90_end
for_90_body:
    %v100 = load i64, ptr %v88
    %v101 = add i64 %v100, %v96
    store i64 %v101, ptr %v88
    %v102 = add i64 0, 0
    br label %for_90_step
for_90_step:
    %v105 = add i64 0, 1
    %v106 = add i64 %v96, %v105
    store i64 %v106, ptr %v92
    %v107 = add i64 0, 0
    br label %for_90_header
for_90_end:
    %v110 = load i64, ptr %v88
    %v111 = add i64 0, 10
    %v112.b = icmp eq i64 %v110, %v111
    %v112 = zext i1 %v112.b to i64
    %v113.cb = icmp ne i64 %v112, 0
    br i1 %v113.cb, label %if_113_then, label %if_113_else
if_113_then:
    %v115 = load i64, ptr %v5
    %v116 = add i64 0, 1
    %v117 = add i64 %v115, %v116
    store i64 %v117, ptr %v5
    %v118 = add i64 0, 0
    br label %if_113_merge
if_113_else:
    br label %if_113_merge
if_113_merge:
    %v123 = add i64 0, 1
    %v124 = add i64 0, 2
    %v125 = add i64 0, 3
    %v126 = add i64 0, 4
    %v127 = call ptr @orion_list_new(i64 4)
    call void @orion_list_set(ptr %v127, i64 0, i64 %v123)
    call void @orion_list_set(ptr %v127, i64 1, i64 %v124)
    call void @orion_list_set(ptr %v127, i64 2, i64 %v125)
    call void @orion_list_set(ptr %v127, i64 3, i64 %v126)
    %v128 = add i64 0, 0
    %v129 = alloca i64, align 8
    store i64 %v128, ptr %v129
    %v130 = add i64 0, 0
    %v131 = call i64 @orion_list_len(ptr %v127)
    %v132 = alloca i64, align 8
    %v133 = add i64 0, 0
    store i64 %v133, ptr %v132
    %v134 = add i64 0, 0
    br label %fin_131_header
fin_131_header:
    %v137 = load i64, ptr %v132
    %v138.b = icmp slt i64 %v137, %v131
    %v138 = zext i1 %v138.b to i64
    %v139.cb = icmp ne i64 %v138, 0
    br i1 %v139.cb, label %fin_131_body, label %fin_131_end
fin_131_body:
    %v141 = call i64 @orion_list_at(ptr %v127, i64 %v137)
    %v142 = load i64, ptr %v129
    %v143 = add i64 %v142, %v141
    store i64 %v143, ptr %v129
    %v144 = add i64 0, 0
    br label %fin_131_step
fin_131_step:
    %v147 = add i64 0, 1
    %v148 = add i64 %v137, %v147
    store i64 %v148, ptr %v132
    %v149 = add i64 0, 0
    br label %fin_131_header
fin_131_end:
    %v152 = load i64, ptr %v129
    %v153 = add i64 0, 10
    %v154.b = icmp eq i64 %v152, %v153
    %v154 = zext i1 %v154.b to i64
    %v155.cb = icmp ne i64 %v154, 0
    br i1 %v155.cb, label %if_155_then, label %if_155_else
if_155_then:
    %v157 = load i64, ptr %v5
    %v158 = add i64 0, 1
    %v159 = add i64 %v157, %v158
    store i64 %v159, ptr %v5
    %v160 = add i64 0, 0
    br label %if_155_merge
if_155_else:
    br label %if_155_merge
if_155_merge:
    %v165 = add i64 0, 0
    %v166.b = icmp sgt i64 %v3, %v165
    %v166 = zext i1 %v166.b to i64
    %v167.cb = icmp ne i64 %v166, 0
    br i1 %v167.cb, label %if_167_then, label %if_167_else
if_167_then:
    %v169 = add i64 0, 1
    br label %if_167_merge
if_167_else:
    %v172 = add i64 0, 0
    br label %if_167_merge
if_167_merge:
    %v175 = phi i64 [ %v169, %if_167_then ], [ %v172, %if_167_else ]
    %v176 = add i64 0, 1
    %v177.b = icmp eq i64 %v175, %v176
    %v177 = zext i1 %v177.b to i64
    %v178.cb = icmp ne i64 %v177, 0
    br i1 %v178.cb, label %if_178_then, label %if_178_else
if_178_then:
    %v180 = load i64, ptr %v5
    %v181 = add i64 0, 1
    %v182 = add i64 %v180, %v181
    store i64 %v182, ptr %v5
    %v183 = add i64 0, 0
    br label %if_178_merge
if_178_else:
    br label %if_178_merge
if_178_merge:
    %v188 = add i64 0, 2
    %v189 = alloca i64, align 8
    %v190 = add i64 0, 1
    %v191.b = icmp eq i64 %v188, %v190
    %v191 = zext i1 %v191.b to i64
    %v192.cb = icmp ne i64 %v191, 0
    br i1 %v192.cb, label %match_189_arm_0_body, label %match_189_arm_0_next
match_189_arm_0_body:
    %v194 = add i64 0, 100
    store i64 %v194, ptr %v189
    %v195 = add i64 0, 0
    br label %match_189_end
match_189_arm_0_next:
    %v198 = add i64 0, 2
    %v199.b = icmp eq i64 %v188, %v198
    %v199 = zext i1 %v199.b to i64
    %v200.cb = icmp ne i64 %v199, 0
    br i1 %v200.cb, label %match_189_arm_1_body, label %match_189_arm_1_next
match_189_arm_1_body:
    %v202 = add i64 0, 200
    store i64 %v202, ptr %v189
    %v203 = add i64 0, 0
    br label %match_189_end
match_189_arm_1_next:
    %v206 = add i64 0, 0
    store i64 %v206, ptr %v189
    %v207 = add i64 0, 0
    br label %match_189_end
match_189_end:
    %v210 = load i64, ptr %v189
    %v211 = add i64 0, 200
    %v212.b = icmp eq i64 %v210, %v211
    %v212 = zext i1 %v212.b to i64
    %v213.cb = icmp ne i64 %v212, 0
    br i1 %v213.cb, label %if_213_then, label %if_213_else
if_213_then:
    %v215 = load i64, ptr %v5
    %v216 = add i64 0, 1
    %v217 = add i64 %v215, %v216
    store i64 %v217, ptr %v5
    %v218 = add i64 0, 0
    br label %if_213_merge
if_213_else:
    br label %if_213_merge
if_213_merge:
    %v223 = add i64 0, 0
    %v224 = alloca i64, align 8
    store i64 %v223, ptr %v224
    %v225 = add i64 0, 0
    br label %loop_226_header
loop_226_header:
    %v228 = load i64, ptr %v224
    %v229 = add i64 0, 1
    %v230 = add i64 %v228, %v229
    store i64 %v230, ptr %v224
    %v231 = add i64 0, 0
    %v232 = load i64, ptr %v224
    %v233 = add i64 0, 3
    %v234.b = icmp eq i64 %v232, %v233
    %v234 = zext i1 %v234.b to i64
    %v235.cb = icmp ne i64 %v234, 0
    br i1 %v235.cb, label %if_235_then, label %if_235_else
if_235_then:
    br label %loop_226_end
if_235_else:
    br label %if_235_merge
if_235_merge:
    br label %loop_226_header
loop_226_end:
    %v243 = load i64, ptr %v224
    %v244 = add i64 0, 3
    %v245.b = icmp eq i64 %v243, %v244
    %v245 = zext i1 %v245.b to i64
    %v246.cb = icmp ne i64 %v245, 0
    br i1 %v246.cb, label %if_246_then, label %if_246_else
if_246_then:
    %v248 = load i64, ptr %v5
    %v249 = add i64 0, 1
    %v250 = add i64 %v248, %v249
    store i64 %v250, ptr %v5
    %v251 = add i64 0, 0
    br label %if_246_merge
if_246_else:
    br label %if_246_merge
if_246_merge:
    %v256 = add i64 0, 7
    %v257 = add i64 0, 0
    %v258 = sub i64 %v257, %v256
    %v259 = add i64 0, 0
    %v260.b = icmp slt i64 %v258, %v259
    %v260 = zext i1 %v260.b to i64
    %v261.cb = icmp ne i64 %v260, 0
    br i1 %v261.cb, label %if_261_then, label %if_261_else
if_261_then:
    %v263 = load i64, ptr %v5
    %v264 = add i64 0, 1
    %v265 = add i64 %v263, %v264
    store i64 %v265, ptr %v5
    %v266 = add i64 0, 0
    br label %if_261_merge
if_261_else:
    br label %if_261_merge
if_261_merge:
    %v271 = add i64 0, 5
    %v272 = getelementptr i8, ptr @.str_12, i64 16
    %v273 = call ptr @orion_alloc(i64 16)
    %v273.f0 = getelementptr i64, ptr %v273, i64 0
    store i64 %v271, ptr %v273.f0
    %v273.f1 = getelementptr i64, ptr %v273, i64 1
    %v273.f1.i = ptrtoint ptr %v272 to i64
    store i64 %v273.f1.i, ptr %v273.f1
    %v274 = add i64 0, 7
    %v275 = getelementptr i8, ptr @.str_12, i64 16
    %v276 = call ptr @orion_alloc(i64 16)
    %v276.f0 = getelementptr i64, ptr %v276, i64 0
    store i64 %v274, ptr %v276.f0
    %v276.f1 = getelementptr i64, ptr %v276, i64 1
    %v276.f1.i = ptrtoint ptr %v275 to i64
    store i64 %v276.f1.i, ptr %v276.f1
    %v277.slot = getelementptr i64, ptr %v273, i64 0
    %v277 = load i64, ptr %v277.slot
    %v278.slot = getelementptr i64, ptr %v276, i64 0
    %v278 = load i64, ptr %v278.slot
    %v279 = add i64 %v277, %v278
    %v280 = add i64 0, 12
    %v281.b = icmp eq i64 %v279, %v280
    %v281 = zext i1 %v281.b to i64
    %v282.cb = icmp ne i64 %v281, 0
    br i1 %v282.cb, label %if_282_then, label %if_282_else
if_282_then:
    %v284 = load i64, ptr %v5
    %v285 = add i64 0, 1
    %v286 = add i64 %v284, %v285
    store i64 %v286, ptr %v5
    %v287 = add i64 0, 0
    br label %if_282_merge
if_282_else:
    br label %if_282_merge
if_282_merge:
    %v292 = getelementptr i8, ptr @.str_13, i64 16
    %v293 = call ptr @label_for(ptr %v292)
    %v294 = getelementptr i8, ptr @.str_14, i64 16
    %v295.e = call i64 @orion_text_eq(ptr %v293, ptr %v294)
    %v295 = add i64 %v295.e, 0
    %v296.cb = icmp ne i64 %v295, 0
    br i1 %v296.cb, label %if_296_then, label %if_296_else
if_296_then:
    %v298 = load i64, ptr %v5
    %v299 = add i64 0, 1
    %v300 = add i64 %v298, %v299
    store i64 %v300, ptr %v5
    %v301 = add i64 0, 0
    br label %if_296_merge
if_296_else:
    br label %if_296_merge
if_296_merge:
    %v306 = getelementptr i8, ptr @.str_15, i64 16
    %v307 = getelementptr i8, ptr @.str_16, i64 16
    %v308 = call ptr @orion_text_concat(ptr %v306, ptr %v307)
    %v309 = call ptr @orion_text_concat(ptr %v308, ptr %v306)
    %v310 = getelementptr i8, ptr @.str_17, i64 16
    %v311.e = call i64 @orion_text_eq(ptr %v309, ptr %v310)
    %v311 = add i64 %v311.e, 0
    %v312.cb = icmp ne i64 %v311, 0
    br i1 %v312.cb, label %if_312_then, label %if_312_else
if_312_then:
    %v314 = load i64, ptr %v5
    %v315 = add i64 0, 1
    %v316 = add i64 %v314, %v315
    store i64 %v316, ptr %v5
    %v317 = add i64 0, 0
    br label %if_312_merge
if_312_else:
    br label %if_312_merge
if_312_merge:
    %v322 = add i64 0, 0
    %v323 = alloca i64, align 8
    store i64 %v322, ptr %v323
    %v324 = add i64 0, 0
    %v325 = load i64, ptr %v323
    %v326 = add i64 0, 3
    %v327 = add i64 %v325, %v326
    store i64 %v327, ptr %v323
    %v328 = add i64 0, 0
    %v329 = load i64, ptr %v323
    %v330 = add i64 0, 4
    %v331 = add i64 %v329, %v330
    store i64 %v331, ptr %v323
    %v332 = add i64 0, 0
    %v333 = load i64, ptr %v323
    %v334 = add i64 0, 7
    %v335.b = icmp eq i64 %v333, %v334
    %v335 = zext i1 %v335.b to i64
    %v336.cb = icmp ne i64 %v335, 0
    br i1 %v336.cb, label %if_336_then, label %if_336_else
if_336_then:
    %v338 = load i64, ptr %v5
    %v339 = add i64 0, 1
    %v340 = add i64 %v338, %v339
    store i64 %v340, ptr %v5
    %v341 = add i64 0, 0
    br label %if_336_merge
if_336_else:
    br label %if_336_merge
if_336_merge:
    %v346 = alloca ptr, align 8
    %v347 = add i64 0, 0
    %v348.b = icmp eq i64 %v258, %v347
    %v348 = zext i1 %v348.b to i64
    %v349.cb = icmp ne i64 %v348, 0
    br i1 %v349.cb, label %match_346_arm_0_body, label %match_346_arm_0_next
match_346_arm_0_body:
    %v351 = getelementptr i8, ptr @.str_18, i64 16
    store ptr %v351, ptr %v346
    %v352 = add i64 0, 0
    br label %match_346_end
match_346_arm_0_next:
    %v355 = getelementptr i8, ptr @.str_19, i64 16
    store ptr %v355, ptr %v346
    %v356 = add i64 0, 0
    br label %match_346_end
match_346_end:
    %v359 = load ptr, ptr %v346
    %v360 = getelementptr i8, ptr @.str_19, i64 16
    %v361.e = call i64 @orion_text_eq(ptr %v359, ptr %v360)
    %v361 = add i64 %v361.e, 0
    %v362.cb = icmp ne i64 %v361, 0
    br i1 %v362.cb, label %if_362_then, label %if_362_else
if_362_then:
    %v364 = load i64, ptr %v5
    %v365 = add i64 0, 1
    %v366 = add i64 %v364, %v365
    store i64 %v366, ptr %v5
    %v367 = add i64 0, 0
    br label %if_362_merge
if_362_else:
    br label %if_362_merge
if_362_merge:
    %v372 = add i64 0, 0
    %v373 = add i64 0, 99
    %v374 = add i64 0, 0
    %v375 = call ptr @orion_alloc(i64 24)
    %v375.f0 = getelementptr i64, ptr %v375, i64 0
    store i64 %v372, ptr %v375.f0
    %v375.f1 = getelementptr i64, ptr %v375, i64 1
    store i64 %v373, ptr %v375.f1
    %v375.f2 = getelementptr i64, ptr %v375, i64 2
    store i64 %v374, ptr %v375.f2
    %v376 = alloca i64, align 8
    %v377 = add i64 0, 0
    %v378.slot = getelementptr i64, ptr %v375, i64 0
    %v378 = load i64, ptr %v378.slot
    %v379.b = icmp eq i64 %v378, %v377
    %v379 = zext i1 %v379.b to i64
    %v380.cb = icmp ne i64 %v379, 0
    br i1 %v380.cb, label %match_376_arm_0_body, label %match_376_arm_0_next
match_376_arm_0_body:
    %v382.slot = getelementptr i64, ptr %v375, i64 1
    %v382 = load i64, ptr %v382.slot
    store i64 %v382, ptr %v376
    %v383 = add i64 0, 0
    br label %match_376_end
match_376_arm_0_next:
    %v386 = add i64 0, 1
    %v387.slot = getelementptr i64, ptr %v375, i64 0
    %v387 = load i64, ptr %v387.slot
    %v388.b = icmp eq i64 %v387, %v386
    %v388 = zext i1 %v388.b to i64
    %v389.cb = icmp ne i64 %v388, 0
    br i1 %v389.cb, label %match_376_arm_1_body, label %match_376_arm_1_next
match_376_arm_1_body:
    %v391.slot = getelementptr i64, ptr %v375, i64 1
    %v391 = load i64, ptr %v391.slot
    %v392 = add i64 0, 0
    store i64 %v392, ptr %v376
    %v393 = add i64 0, 0
    br label %match_376_end
match_376_arm_1_next:
    %v396 = add i64 0, 0
    store i64 %v396, ptr %v376
    %v397 = add i64 0, 0
    br label %match_376_end
match_376_end:
    %v400 = load i64, ptr %v376
    %v401 = add i64 0, 99
    %v402.b = icmp eq i64 %v400, %v401
    %v402 = zext i1 %v402.b to i64
    %v403.cb = icmp ne i64 %v402, 0
    br i1 %v403.cb, label %if_403_then, label %if_403_else
if_403_then:
    %v405 = load i64, ptr %v5
    %v406 = add i64 0, 1
    %v407 = add i64 %v405, %v406
    store i64 %v407, ptr %v5
    %v408 = add i64 0, 0
    br label %if_403_merge
if_403_else:
    br label %if_403_merge
if_403_merge:
    %v413 = load i64, ptr %v5
    %v414 = add i64 0, 17
    %v415.b = icmp eq i64 %v413, %v414
    %v415 = zext i1 %v415.b to i64
    %v416.cb = icmp ne i64 %v415, 0
    br i1 %v416.cb, label %if_416_then, label %if_416_else
if_416_then:
    %v418 = add i64 0, 42
    br label %if_416_merge
if_416_else:
    %v421 = add i64 0, 0
    %v422 = load i64, ptr %v5
    %v423 = sub i64 %v421, %v422
    br label %if_416_merge
if_416_merge:
    %v426 = phi i64 [ %v418, %if_416_then ], [ %v423, %if_416_else ]
    ret i64 %v426
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
