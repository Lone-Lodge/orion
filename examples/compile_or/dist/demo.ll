; orion_emit_llvm output
target datalayout = "e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc19.44.35209"
declare i32 @printf(ptr, ...)
declare i32 @puts(ptr)
declare ptr @malloc(i64)
declare ptr @orion_f64_literal_hex(ptr)
declare i64 @orion_par_run(ptr, i64)
declare ptr @orion_alloc(i64)
declare ptr @orion_par_madd(ptr, ptr, i64)
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
declare i64 @orion_task_spawn(ptr, i64)
declare i64 @orion_task_await(i64)
declare i64 @orion_task_yield()
declare i64 @orion_task_run_all()
declare i64 @orion_task_state(i64)
declare i64 @orion_task_live_count()
declare i64 @orion_task_sleep(i64)
declare i64 @orion_ms_perform(ptr, i64)
declare i64 @orion_ms_resume(i64)
declare i64 @orion_ms_supported()
declare ptr @orion_stdin_line()
declare ptr @orion_stdin_read(i64)
declare i64 @orion_stdout_write(ptr)
declare i64 @orion_stderr_line(ptr)
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
declare i64 @__orion_perform_int_n(ptr, i64, i64, i64, i64, i64)
declare ptr @__orion_perform_text_n(ptr, i64, i64, i64, i64, i64)
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

@.str_empty_h = constant [3 x i64] [i64 5381, i64 0, i64 0]

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

define i64 @orion_map_idx_find(ptr %map, ptr %key) {
entry:
  %ixs = getelementptr i64, ptr %map, i64 3
  %ixv = load i64, ptr %ixs
  %noix = icmp eq i64 %ixv, 0
  br i1 %noix, label %lin, label %hsh
lin:
  %le = load ptr, ptr %map
  %lls = getelementptr i64, ptr %map, i64 2
  %ll = load i64, ptr %lls
  br label %lh
lh:
  %li = phi i64 [ 0, %lin ], [ %lin2, %ls ]
  %ld = icmp sge i64 %li, %ll
  br i1 %ld, label %lm, label %lb
lb:
  %lki = mul i64 %li, 2
  %lks = getelementptr i64, ptr %le, i64 %lki
  %lkiv = load i64, ptr %lks
  %lkp = inttoptr i64 %lkiv to ptr
  %lc = call i64 @orion_text_eq(ptr %lkp, ptr %key)
  %lce = icmp ne i64 %lc, 0
  br i1 %lce, label %lhit, label %ls
lhit:
  ret i64 %li
ls:
  %lin2 = add i64 %li, 1
  br label %lh
lm:
  ret i64 -1
hsh:
  %ix = inttoptr i64 %ixv to ptr
  %mks = getelementptr i64, ptr %map, i64 4
  %mk = load i64, ptr %mks
  %he = load ptr, ptr %map
  %h0 = call i64 @orion_text_hash(ptr %key)
  %hh = and i64 %h0, %mk
  br label %ph
ph:
  %ps = phi i64 [ %hh, %hsh ], [ %psw, %pst ]
  %pisl = getelementptr i64, ptr %ix, i64 %ps
  %pv = load i64, ptr %pisl
  %pe = icmp eq i64 %pv, 0
  br i1 %pe, label %pm, label %pc
pc:
  %pos = add i64 %pv, -1
  %pki = mul i64 %pos, 2
  %pks = getelementptr i64, ptr %he, i64 %pki
  %pkiv = load i64, ptr %pks
  %pkp = inttoptr i64 %pkiv to ptr
  %pcx = call i64 @orion_text_eq(ptr %pkp, ptr %key)
  %pce = icmp ne i64 %pcx, 0
  br i1 %pce, label %phit, label %pst
phit:
  ret i64 %pos
pst:
  %ps1 = add i64 %ps, 1
  %psw = and i64 %ps1, %mk
  br label %ph
pm:
  ret i64 -1
}

define void @orion_map_idx_build(ptr %map) {
entry:
  %bls = getelementptr i64, ptr %map, i64 2
  %bl = load i64, ptr %bls
  %need = mul i64 %bl, 2
  br label %sz
sz:
  %isz = phi i64 [ 16, %entry ], [ %isz2, %szs ]
  %szok = icmp sge i64 %isz, %need
  br i1 %szok, label %al, label %szs
szs:
  %isz2 = mul i64 %isz, 2
  br label %sz
al:
  %ib = mul i64 %isz, 8
  %ix = call ptr @malloc(i64 %ib)
  br label %zh
zh:
  %zi = phi i64 [ 0, %al ], [ %zi2, %zb ]
  %zd = icmp sge i64 %zi, %isz
  br i1 %zd, label %fl, label %zb
zb:
  %zs = getelementptr i64, ptr %ix, i64 %zi
  store i64 0, ptr %zs
  %zi2 = add i64 %zi, 1
  br label %zh
fl:
  %mk = add i64 %isz, -1
  %fe = load ptr, ptr %map
  br label %fh
fh:
  %fi = phi i64 [ 0, %fl ], [ %fi2, %fd2 ]
  %fdn = icmp sge i64 %fi, %bl
  br i1 %fdn, label %si, label %fb
fb:
  %fki = mul i64 %fi, 2
  %fks = getelementptr i64, ptr %fe, i64 %fki
  %fkiv = load i64, ptr %fks
  %fkp = inttoptr i64 %fkiv to ptr
  %fh0 = call i64 @orion_text_hash(ptr %fkp)
  %fhh = and i64 %fh0, %mk
  br label %pr
pr:
  %prs = phi i64 [ %fhh, %fb ], [ %prw, %prc ]
  %pri = getelementptr i64, ptr %ix, i64 %prs
  %prv = load i64, ptr %pri
  %pre = icmp eq i64 %prv, 0
  br i1 %pre, label %pp, label %prc
prc:
  %prs1 = add i64 %prs, 1
  %prw = and i64 %prs1, %mk
  br label %pr
pp:
  %fp1 = add i64 %fi, 1
  store i64 %fp1, ptr %pri
  br label %fd2
fd2:
  %fi2 = add i64 %fi, 1
  br label %fh
si:
  %ixi = ptrtoint ptr %ix to i64
  %sixs = getelementptr i64, ptr %map, i64 3
  store i64 %ixi, ptr %sixs
  %smks = getelementptr i64, ptr %map, i64 4
  store i64 %mk, ptr %smks
  ret void
}

define void @orion_map_idx_add(ptr %map, ptr %key, i64 %posp1) {
entry:
  %ixs = getelementptr i64, ptr %map, i64 3
  %ixv = load i64, ptr %ixs
  %noix = icmp eq i64 %ixv, 0
  br i1 %noix, label %ret, label %chk
chk:
  %mks = getelementptr i64, ptr %map, i64 4
  %mk = load i64, ptr %mks
  %isz = add i64 %mk, 1
  %need = mul i64 %posp1, 2
  %big = icmp sgt i64 %need, %isz
  br i1 %big, label %rebuild, label %ins
rebuild:
  call void @orion_map_idx_build(ptr %map)
  br label %ret
ins:
  %ix = inttoptr i64 %ixv to ptr
  %h0 = call i64 @orion_text_hash(ptr %key)
  %hh = and i64 %h0, %mk
  br label %ph
ph:
  %ps = phi i64 [ %hh, %ins ], [ %psw, %pst ]
  %pisl = getelementptr i64, ptr %ix, i64 %ps
  %pv = load i64, ptr %pisl
  %pe = icmp eq i64 %pv, 0
  br i1 %pe, label %put, label %pst
pst:
  %ps1 = add i64 %ps, 1
  %psw = and i64 %ps1, %mk
  br label %ph
put:
  store i64 %posp1, ptr %pisl
  br label %ret
ret:
  ret void
}

define ptr @orion_map_new_persist() {
entry:
  %handle = call ptr @malloc(i64 40)
  %entries = call ptr @malloc(i64 256)
  store ptr %entries, ptr %handle
  %cap_slot = getelementptr i64, ptr %handle, i64 1
  store i64 16, ptr %cap_slot
  %len_slot = getelementptr i64, ptr %handle, i64 2
  store i64 0, ptr %len_slot
  %ix_slot = getelementptr i64, ptr %handle, i64 3
  store i64 0, ptr %ix_slot
  %mk_slot = getelementptr i64, ptr %handle, i64 4
  store i64 0, ptr %mk_slot
  ret ptr %handle
}

define void @orion_map_set_persist(ptr %map, ptr %key, i64 %val) {
entry:
  %len_slot = getelementptr i64, ptr %map, i64 2
  %len = load i64, ptr %len_slot
  %big = icmp sge i64 %len, 8
  br i1 %big, label %ens, label %findit
ens:
  %ixs = getelementptr i64, ptr %map, i64 3
  %ixv = load i64, ptr %ixs
  %noix = icmp eq i64 %ixv, 0
  br i1 %noix, label %bld, label %findit
bld:
  call void @orion_map_idx_build(ptr %map)
  br label %findit
findit:
  %pos = call i64 @orion_map_idx_find(ptr %map, ptr %key)
  %found = icmp sge i64 %pos, 0
  br i1 %found, label %update, label %maybe_grow
update:
  %ue = load ptr, ptr %map
  %uki = mul i64 %pos, 2
  %uvi = add i64 %uki, 1
  %uvs = getelementptr i64, ptr %ue, i64 %uvi
  store i64 %val, ptr %uvs
  ret void
maybe_grow:
  %cap_slot = getelementptr i64, ptr %map, i64 1
  %cap = load i64, ptr %cap_slot
  %entries = load ptr, ptr %map
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
  call void @orion_map_idx_add(ptr %map, ptr %key_copy, i64 %new_len)
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
  %handle = call ptr @orion_alloc(i64 40)
  %entry_bytes = mul i64 %cap2, 16
  %entries = call ptr @orion_alloc(i64 %entry_bytes)
  store ptr %entries, ptr %handle
  %cap_slot = getelementptr i64, ptr %handle, i64 1
  store i64 %cap2, ptr %cap_slot
  %len_slot = getelementptr i64, ptr %handle, i64 2
  store i64 0, ptr %len_slot
  %ixn_slot = getelementptr i64, ptr %handle, i64 3
  store i64 0, ptr %ixn_slot
  %mkn_slot = getelementptr i64, ptr %handle, i64 4
  store i64 0, ptr %mkn_slot
  ret ptr %handle
}

define void @orion_map_set(ptr %map, ptr %key, i64 %val) {
entry:
  %len_slot = getelementptr i64, ptr %map, i64 2
  %len = load i64, ptr %len_slot
  %big = icmp sge i64 %len, 8
  br i1 %big, label %ens, label %findit
ens:
  %ixs = getelementptr i64, ptr %map, i64 3
  %ixv = load i64, ptr %ixs
  %noix = icmp eq i64 %ixv, 0
  br i1 %noix, label %bld, label %findit
bld:
  call void @orion_map_idx_build(ptr %map)
  br label %findit
findit:
  %pos = call i64 @orion_map_idx_find(ptr %map, ptr %key)
  %found = icmp sge i64 %pos, 0
  br i1 %found, label %update, label %maybe_grow
update:
  %ue = load ptr, ptr %map
  %uki = mul i64 %pos, 2
  %uvi = add i64 %uki, 1
  %uvs = getelementptr i64, ptr %ue, i64 %uvi
  store i64 %val, ptr %uvs
  ret void
maybe_grow:
  %cap_slot = getelementptr i64, ptr %map, i64 1
  %cap = load i64, ptr %cap_slot
  %entries = load ptr, ptr %map
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
  call void @orion_map_idx_add(ptr %map, ptr %key_owned, i64 %new_len)
  ret void
}

define i64 @orion_map_get(ptr %map, ptr %key) {
entry:
  %pos = call i64 @orion_map_idx_find(ptr %map, ptr %key)
  %ok = icmp sge i64 %pos, 0
  br i1 %ok, label %hit, label %miss
hit:
  %e = load ptr, ptr %map
  %ki = mul i64 %pos, 2
  %vi = add i64 %ki, 1
  %vs = getelementptr i64, ptr %e, i64 %vi
  %v = load i64, ptr %vs
  ret i64 %v
miss:
  ret i64 0
}

define i64 @orion_map_has(ptr %map, ptr %key) {
entry:
  %pos = call i64 @orion_map_idx_find(ptr %map, ptr %key)
  %ok = icmp sge i64 %pos, 0
  %r = zext i1 %ok to i64
  ret i64 %r
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
  %rixs = getelementptr i64, ptr %map, i64 3
  store i64 0, ptr %rixs
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

define ptr @orion_vec_addi(ptr %dst, ptr %src) {
entry:
  %nslot = getelementptr i64, ptr %dst, i64 1
  %n = load i64, ptr %nslot
  %db = getelementptr i64, ptr %dst, i64 2
  %sb = getelementptr i64, ptr %src, i64 2
  %vend = and i64 %n, -4
  br label %vhdr
vhdr:
  %vi = phi i64 [ 0, %entry ], [ %vin, %vbody ]
  %vdone = icmp sge i64 %vi, %vend
  br i1 %vdone, label %shdr, label %vbody
vbody:
  %dp = getelementptr i64, ptr %db, i64 %vi
  %sp = getelementptr i64, ptr %sb, i64 %vi
  %dv = load <4 x i64>, ptr %dp, align 8
  %sv = load <4 x i64>, ptr %sp, align 8
  %vsum = add <4 x i64> %dv, %sv
  store <4 x i64> %vsum, ptr %dp, align 8
  %vin = add i64 %vi, 4
  br label %vhdr
shdr:
  %si = phi i64 [ %vend, %vhdr ], [ %sin, %sbody ]
  %sdone = icmp sge i64 %si, %n
  br i1 %sdone, label %retb, label %sbody
sbody:
  %sdp = getelementptr i64, ptr %db, i64 %si
  %ssp = getelementptr i64, ptr %sb, i64 %si
  %sa = load i64, ptr %sdp, align 8
  %sbv = load i64, ptr %ssp, align 8
  %sr = add i64 %sa, %sbv
  store i64 %sr, ptr %sdp, align 8
  %sin = add i64 %si, 1
  br label %shdr
retb:
  ret ptr %dst
}

define ptr @orion_vec_madd(ptr %dst, ptr %src, i64 %k) {
entry:
  %nslot = getelementptr i64, ptr %dst, i64 1
  %n = load i64, ptr %nslot
  %db = getelementptr i64, ptr %dst, i64 2
  %sb = getelementptr i64, ptr %src, i64 2
  %vend = and i64 %n, -4
  %kv0 = insertelement <4 x i64> undef, i64 %k, i32 0
  %kv = shufflevector <4 x i64> %kv0, <4 x i64> undef, <4 x i32> zeroinitializer
  br label %vhdr
vhdr:
  %vi = phi i64 [ 0, %entry ], [ %vin, %vbody ]
  %vdone = icmp sge i64 %vi, %vend
  br i1 %vdone, label %shdr, label %vbody
vbody:
  %dp = getelementptr i64, ptr %db, i64 %vi
  %sp = getelementptr i64, ptr %sb, i64 %vi
  %dv = load <4 x i64>, ptr %dp, align 8
  %sv = load <4 x i64>, ptr %sp, align 8
  %prod = mul <4 x i64> %sv, %kv
  %msum = add <4 x i64> %dv, %prod
  store <4 x i64> %msum, ptr %dp, align 8
  %vin = add i64 %vi, 4
  br label %vhdr
shdr:
  %si = phi i64 [ %vend, %vhdr ], [ %sin, %sbody ]
  %sdone = icmp sge i64 %si, %n
  br i1 %sdone, label %retb, label %sbody
sbody:
  %sdp = getelementptr i64, ptr %db, i64 %si
  %ssp = getelementptr i64, ptr %sb, i64 %si
  %ma = load i64, ptr %sdp, align 8
  %mb = load i64, ptr %ssp, align 8
  %mm = mul i64 %mb, %k
  %mr = add i64 %ma, %mm
  store i64 %mr, ptr %sdp, align 8
  %sin = add i64 %si, 1
  br label %shdr
retb:
  ret ptr %dst
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
@.str_60 = private unnamed_addr constant [25 x i8] c"\79\46\DC\1C\00\00\00\00\08\00\00\00\00\00\00\00vec_addi\00", align 8
@.str_61 = private unnamed_addr constant [25 x i8] c"\9D\20\77\1E\00\00\00\00\08\00\00\00\00\00\00\00vec_madd\00", align 8
@.str_62 = private unnamed_addr constant [25 x i8] c"\4F\C3\82\32\00\00\00\00\08\00\00\00\00\00\00\00par_madd\00", align 8
@.str_63 = private unnamed_addr constant [24 x i8] c"\87\BB\56\09\00\00\00\00\07\00\00\00\00\00\00\00vec_sub\00", align 8
@.str_64 = private unnamed_addr constant [24 x i8] c"\5B\29\55\09\00\00\00\00\07\00\00\00\00\00\00\00vec_mul\00", align 8
@.str_65 = private unnamed_addr constant [24 x i8] c"\00\CB\52\09\00\00\00\00\07\00\00\00\00\00\00\00vec_dot\00", align 8
@.str_66 = private unnamed_addr constant [28 x i8] c"\AB\B4\1C\19\00\00\00\00\0B\00\00\00\00\00\00\00time_now_ms\00", align 8
@.str_67 = private unnamed_addr constant [29 x i8] c"\23\23\AC\31\00\00\00\00\0C\00\00\00\00\00\00\00monotonic_ms\00", align 8
@.str_68 = private unnamed_addr constant [25 x i8] c"\F4\3B\A3\3A\00\00\00\00\08\00\00\00\00\00\00\00sleep_ms\00", align 8
@.str_69 = private unnamed_addr constant [24 x i8] c"\C2\01\C5\1A\00\00\00\00\07\00\00\00\00\00\00\00map_lit\00", align 8
@.str_70 = private unnamed_addr constant [21 x i8] c"\37\D4\AB\38\00\00\00\00\04\00\00\00\00\00\00\00map:\00", align 8
@.str_71 = private unnamed_addr constant [24 x i8] c"\89\B0\C3\1A\00\00\00\00\07\00\00\00\00\00\00\00map_get\00", align 8
@.str_72 = private unnamed_addr constant [24 x i8] c"\85\F1\C3\1A\00\00\00\00\07\00\00\00\00\00\00\00map_has\00", align 8
@.str_73 = private unnamed_addr constant [28 x i8] c"\DE\92\96\27\00\00\00\00\0B\00\00\00\00\00\00\00map_set_val\00", align 8
@.str_74 = private unnamed_addr constant [27 x i8] c"\2E\1C\1C\35\00\00\00\00\0A\00\00\00\00\00\00\00map_remove\00", align 8
@.str_75 = private unnamed_addr constant [20 x i8] c"\9B\7F\E4\05\00\00\00\00\03\00\00\00\00\00\00\00map\00", align 8
@.str_76 = private unnamed_addr constant [29 x i8] c"\C3\CF\04\20\00\00\00\00\0C\00\00\00\00\00\00\00list_set_val\00", align 8
@.str_77 = private unnamed_addr constant [25 x i8] c"\62\7A\6C\09\00\00\00\00\08\00\00\00\00\00\00\00slot_has\00", align 8
@.str_78 = private unnamed_addr constant [29 x i8] c"\BD\96\22\30\00\00\00\00\0C\00\00\00\00\00\00\00slot_get_int\00", align 8
@.str_79 = private unnamed_addr constant [24 x i8] c"\B0\FF\C4\1A\00\00\00\00\07\00\00\00\00\00\00\00map_len\00", align 8
@.str_80 = private unnamed_addr constant [25 x i8] c"\F3\C9\9A\31\00\00\00\00\08\00\00\00\00\00\00\00map_keys\00", align 8
@.str_81 = private unnamed_addr constant [26 x i8] c"\69\42\55\24\00\00\00\00\09\00\00\00\00\00\00\00list:text\00", align 8
@.str_82 = private unnamed_addr constant [27 x i8] c"\76\24\B8\01\00\00\00\00\0A\00\00\00\00\00\00\00map_values\00", align 8
@.str_83 = private unnamed_addr constant [27 x i8] c"\FA\64\B7\1F\00\00\00\00\0A\00\00\00\00\00\00\00map_get_or\00", align 8
@.str_84 = private unnamed_addr constant [28 x i8] c"\55\0B\72\25\00\00\00\00\0B\00\00\00\00\00\00\00f64_to_text\00", align 8
@.str_85 = private unnamed_addr constant [28 x i8] c"\3A\3D\32\3B\00\00\00\00\0B\00\00\00\00\00\00\00struct_cons\00", align 8
@.str_86 = private unnamed_addr constant [24 x i8] c"\34\C9\5A\22\00\00\00\00\07\00\00\00\00\00\00\00struct:\00", align 8
@.str_87 = private unnamed_addr constant [27 x i8] c"\BF\A9\5F\25\00\00\00\00\0A\00\00\00\00\00\00\00field_load\00", align 8
@.str_88 = private unnamed_addr constant [27 x i8] c"\B6\A0\0D\03\00\00\00\00\0A\00\00\00\00\00\00\00print_text\00", align 8
@.str_89 = private unnamed_addr constant [23 x i8] c"\F1\F2\BB\29\00\00\00\00\06\00\00\00\00\00\00\00alloca\00", align 8
@.str_90 = private unnamed_addr constant [21 x i8] c"\97\29\8D\38\00\00\00\00\04\00\00\00\00\00\00\00load\00", align 8
@.str_91 = private unnamed_addr constant [22 x i8] c"\1E\0B\9C\15\00\00\00\00\05\00\00\00\00\00\00\00store\00", align 8
@.str_92 = private unnamed_addr constant [22 x i8] c"\5F\72\62\0F\00\00\00\00\05\00\00\00\00\00\00\00label\00", align 8
@.str_93 = private unnamed_addr constant [19 x i8] c"\C5\3E\81\05\00\00\00\00\02\00\00\00\00\00\00\00br\00", align 8
@.str_94 = private unnamed_addr constant [22 x i8] c"\80\11\F0\14\00\00\00\00\05\00\00\00\00\00\00\00br_if\00", align 8
@.str_95 = private unnamed_addr constant [18 x i8] c"\0B\C2\0A\00\00\00\00\00\01\00\00\00\00\00\00\00|\00", align 8
@.str_96 = private unnamed_addr constant [20 x i8] c"\44\4C\E5\05\00\00\00\00\03\00\00\00\00\00\00\00phi\00", align 8
@.str_97 = private unnamed_addr constant [22 x i8] c"\21\B0\02\1A\00\00\00\00\05\00\00\00\00\00\00\00param\00", align 8
@.str_98 = private unnamed_addr constant [18 x i8] c"\05\C2\0A\00\00\00\00\00\01\00\00\00\00\00\00\00v\00", align 8
@.str_99 = private unnamed_addr constant [20 x i8] c"\2A\43\D0\05\00\00\00\00\03\00\00\00\00\00\00\00 = \00", align 8
@.str_100 = private unnamed_addr constant [24 x i8] c"\4F\EE\6C\29\00\00\00\00\07\00\00\00\00\00\00\00iconst.\00", align 8
@.str_101 = private unnamed_addr constant [18 x i8] c"\AF\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00 \00", align 8
@.str_102 = private unnamed_addr constant [24 x i8] c"\9B\B2\63\21\00\00\00\00\07\00\00\00\00\00\00\00return \00", align 8
@.str_103 = private unnamed_addr constant [18 x i8] c"\BD\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00.\00", align 8
@.str_104 = private unnamed_addr constant [19 x i8] c"\D1\22\81\05\00\00\00\00\02\00\00\00\00\00\00\00, \00", align 8
@.str_105 = private unnamed_addr constant [28 x i8] c"\79\B4\7B\05\00\00\00\00\0B\00\00\00\00\00\00\00perform_int\00", align 8
@.str_106 = private unnamed_addr constant [29 x i8] c"\6F\DE\82\04\00\00\00\00\0C\00\00\00\00\00\00\00perform_text\00", align 8
@.str_107 = private unnamed_addr constant [23 x i8] c"\CB\98\62\09\00\00\00\00\06\00\00\00\00\00\00\00fn_ref\00", align 8
@.str_108 = private unnamed_addr constant [30 x i8] c"\0C\B2\F3\1C\00\00\00\00\0D\00\00\00\00\00\00\00indirect_call\00", align 8
@.str_109 = private unnamed_addr constant [29 x i8] c"\7A\3B\F1\1F\00\00\00\00\0C\00\00\00\00\00\00\00make_closure\00", align 8
@.str_110 = private unnamed_addr constant [29 x i8] c"\1C\15\10\21\00\00\00\00\0C\00\00\00\00\00\00\00closure_call\00", align 8
@.str_111 = private unnamed_addr constant [27 x i8] c"\66\A7\42\00\00\00\00\00\0A\00\00\00\00\00\00\00int_to_ptr\00", align 8
@.str_112 = private unnamed_addr constant [20 x i8] c"\B3\B0\E2\05\00\00\00\00\03\00\00\00\00\00\00\00fn \00", align 8
@.str_113 = private unnamed_addr constant [21 x i8] c"\14\C5\4C\2E\00\00\00\00\04\00\00\00\00\00\00\00 -> \00", align 8
@.str_114 = private unnamed_addr constant [19 x i8] c"\E5\29\81\05\00\00\00\00\02\00\00\00\00\00\00\00:\0A\00", align 8
@.str_115 = private unnamed_addr constant [21 x i8] c"\45\4E\49\2E\00\00\00\00\04\00\00\00\00\00\00\00    \00", align 8
@.str_116 = private unnamed_addr constant [18 x i8] c"\99\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00\0A\00", align 8
@.str_117 = private unnamed_addr constant [40 x i8] c"\8D\17\2A\08\00\00\00\00\17\00\00\00\00\00\00\00; orion_ir module dump\0A\00", align 8
@.str_118 = private unnamed_addr constant [21 x i8] c"\6D\50\69\38\00\00\00\00\04\00\00\00\00\00\00\00kind\00", align 8
@.str_119 = private unnamed_addr constant [22 x i8] c"\F7\D9\1D\0C\00\00\00\00\05\00\00\00\00\00\00\00value\00", align 8
@.str_120 = private unnamed_addr constant [21 x i8] c"\09\9E\8B\38\00\00\00\00\04\00\00\00\00\00\00\00line\00", align 8
@.str_121 = private unnamed_addr constant [20 x i8] c"\67\E8\E1\05\00\00\00\00\03\00\00\00\00\00\00\00col\00", align 8
@.str_122 = private unnamed_addr constant [22 x i8] c"\A6\2A\7D\26\00\00\00\00\05\00\00\00\00\00\00\00token\00", align 8
@.str_123 = private unnamed_addr constant [22 x i8] c"\02\D0\BB\16\00\00\00\00\05\00\00\00\00\00\00\00ident\00", align 8
@.str_124 = private unnamed_addr constant [21 x i8] c"\48\32\CF\38\00\00\00\00\04\00\00\00\00\00\00\00next\00", align 8
@.str_125 = private unnamed_addr constant [19 x i8] c"\CD\40\81\05\00\00\00\00\02\00\00\00\00\00\00\00fn\00", align 8
@.str_126 = private unnamed_addr constant [22 x i8] c"\CA\9E\C6\00\00\00\00\00\05\00\00\00\00\00\00\00kw_fn\00", align 8
@.str_127 = private unnamed_addr constant [21 x i8] c"\F7\1B\77\37\00\00\00\00\04\00\00\00\00\00\00\00data\00", align 8
@.str_128 = private unnamed_addr constant [24 x i8] c"\13\B0\6C\16\00\00\00\00\07\00\00\00\00\00\00\00kw_data\00", align 8
@.str_129 = private unnamed_addr constant [21 x i8] c"\96\D1\9C\37\00\00\00\00\04\00\00\00\00\00\00\00enum\00", align 8
@.str_130 = private unnamed_addr constant [24 x i8] c"\B2\65\92\16\00\00\00\00\07\00\00\00\00\00\00\00kw_enum\00", align 8
@.str_131 = private unnamed_addr constant [22 x i8] c"\2F\77\E1\26\00\00\00\00\05\00\00\00\00\00\00\00trait\00", align 8
@.str_132 = private unnamed_addr constant [25 x i8] c"\7B\13\15\02\00\00\00\00\08\00\00\00\00\00\00\00kw_trait\00", align 8
@.str_133 = private unnamed_addr constant [21 x i8] c"\69\C2\25\38\00\00\00\00\04\00\00\00\00\00\00\00impl\00", align 8
@.str_134 = private unnamed_addr constant [24 x i8] c"\85\56\1B\17\00\00\00\00\07\00\00\00\00\00\00\00kw_impl\00", align 8
@.str_135 = private unnamed_addr constant [23 x i8] c"\8A\1B\22\3A\00\00\00\00\06\00\00\00\00\00\00\00system\00", align 8
@.str_136 = private unnamed_addr constant [26 x i8] c"\9E\38\EA\05\00\00\00\00\09\00\00\00\00\00\00\00kw_system\00", align 8
@.str_137 = private unnamed_addr constant [20 x i8] c"\0E\A1\E6\05\00\00\00\00\03\00\00\00\00\00\00\00use\00", align 8
@.str_138 = private unnamed_addr constant [23 x i8] c"\D2\67\0C\2A\00\00\00\00\06\00\00\00\00\00\00\00kw_use\00", align 8
@.str_139 = private unnamed_addr constant [20 x i8] c"\E4\52\E5\05\00\00\00\00\03\00\00\00\00\00\00\00pub\00", align 8
@.str_140 = private unnamed_addr constant [23 x i8] c"\A8\19\0B\2A\00\00\00\00\06\00\00\00\00\00\00\00kw_pub\00", align 8
@.str_141 = private unnamed_addr constant [20 x i8] c"\DB\89\E4\05\00\00\00\00\03\00\00\00\00\00\00\00mut\00", align 8
@.str_142 = private unnamed_addr constant [23 x i8] c"\9F\50\0A\2A\00\00\00\00\06\00\00\00\00\00\00\00kw_mut\00", align 8
@.str_143 = private unnamed_addr constant [19 x i8] c"\4E\42\81\05\00\00\00\00\02\00\00\00\00\00\00\00if\00", align 8
@.str_144 = private unnamed_addr constant [22 x i8] c"\4B\A0\C6\00\00\00\00\00\05\00\00\00\00\00\00\00kw_if\00", align 8
@.str_145 = private unnamed_addr constant [21 x i8] c"\76\4A\9C\37\00\00\00\00\04\00\00\00\00\00\00\00else\00", align 8
@.str_146 = private unnamed_addr constant [24 x i8] c"\92\DE\91\16\00\00\00\00\07\00\00\00\00\00\00\00kw_else\00", align 8
@.str_147 = private unnamed_addr constant [20 x i8] c"\88\B1\E2\05\00\00\00\00\03\00\00\00\00\00\00\00for\00", align 8
@.str_148 = private unnamed_addr constant [23 x i8] c"\4C\78\08\2A\00\00\00\00\06\00\00\00\00\00\00\00kw_for\00", align 8
@.str_149 = private unnamed_addr constant [19 x i8] c"\56\42\81\05\00\00\00\00\02\00\00\00\00\00\00\00in\00", align 8
@.str_150 = private unnamed_addr constant [22 x i8] c"\53\A0\C6\00\00\00\00\00\05\00\00\00\00\00\00\00kw_in\00", align 8
@.str_151 = private unnamed_addr constant [21 x i8] c"\C7\F6\04\3A\00\00\00\00\04\00\00\00\00\00\00\00with\00", align 8
@.str_152 = private unnamed_addr constant [24 x i8] c"\E3\8A\FA\18\00\00\00\00\07\00\00\00\00\00\00\00kw_with\00", align 8
@.str_153 = private unnamed_addr constant [22 x i8] c"\BD\D8\99\1E\00\00\00\00\05\00\00\00\00\00\00\00where\00", align 8
@.str_154 = private unnamed_addr constant [25 x i8] c"\10\3F\68\35\00\00\00\00\08\00\00\00\00\00\00\00kw_where\00", align 8
@.str_155 = private unnamed_addr constant [21 x i8] c"\CD\30\8D\38\00\00\00\00\04\00\00\00\00\00\00\00loop\00", align 8
@.str_156 = private unnamed_addr constant [24 x i8] c"\E9\C4\82\17\00\00\00\00\07\00\00\00\00\00\00\00kw_loop\00", align 8
@.str_157 = private unnamed_addr constant [22 x i8] c"\A3\9F\F1\14\00\00\00\00\05\00\00\00\00\00\00\00break\00", align 8
@.str_158 = private unnamed_addr constant [25 x i8] c"\F6\05\C0\2B\00\00\00\00\08\00\00\00\00\00\00\00kw_break\00", align 8
@.str_159 = private unnamed_addr constant [25 x i8] c"\1D\23\AC\1B\00\00\00\00\08\00\00\00\00\00\00\00continue\00", align 8
@.str_160 = private unnamed_addr constant [28 x i8] c"\E7\C3\8D\05\00\00\00\00\0B\00\00\00\00\00\00\00kw_continue\00", align 8
@.str_161 = private unnamed_addr constant [22 x i8] c"\48\DE\F4\20\00\00\00\00\05\00\00\00\00\00\00\00match\00", align 8
@.str_162 = private unnamed_addr constant [25 x i8] c"\9B\44\C3\37\00\00\00\00\08\00\00\00\00\00\00\00kw_match\00", align 8
@.str_163 = private unnamed_addr constant [21 x i8] c"\C7\69\A0\39\00\00\00\00\04\00\00\00\00\00\00\00true\00", align 8
@.str_164 = private unnamed_addr constant [24 x i8] c"\E3\FD\95\18\00\00\00\00\07\00\00\00\00\00\00\00kw_true\00", align 8
@.str_165 = private unnamed_addr constant [22 x i8] c"\04\66\48\1D\00\00\00\00\05\00\00\00\00\00\00\00false\00", align 8
@.str_166 = private unnamed_addr constant [25 x i8] c"\57\CC\16\34\00\00\00\00\08\00\00\00\00\00\00\00kw_false\00", align 8
@.str_167 = private unnamed_addr constant [20 x i8] c"\CA\61\E1\05\00\00\00\00\03\00\00\00\00\00\00\00and\00", align 8
@.str_168 = private unnamed_addr constant [23 x i8] c"\8E\28\07\2A\00\00\00\00\06\00\00\00\00\00\00\00kw_and\00", align 8
@.str_169 = private unnamed_addr constant [19 x i8] c"\6C\45\81\05\00\00\00\00\02\00\00\00\00\00\00\00or\00", align 8
@.str_170 = private unnamed_addr constant [22 x i8] c"\69\A3\C6\00\00\00\00\00\05\00\00\00\00\00\00\00kw_or\00", align 8
@.str_171 = private unnamed_addr constant [20 x i8] c"\D2\C9\E4\05\00\00\00\00\03\00\00\00\00\00\00\00not\00", align 8
@.str_172 = private unnamed_addr constant [23 x i8] c"\96\90\0A\2A\00\00\00\00\06\00\00\00\00\00\00\00kw_not\00", align 8
@.str_173 = private unnamed_addr constant [23 x i8] c"\6F\D2\F8\21\00\00\00\00\06\00\00\00\00\00\00\00extern\00", align 8
@.str_174 = private unnamed_addr constant [26 x i8] c"\8A\B9\5B\29\00\00\00\00\09\00\00\00\00\00\00\00kw_extern\00", align 8
@.str_175 = private unnamed_addr constant [25 x i8] c"\E2\91\98\2B\00\00\00\00\08\00\00\00\00\00\00\00comptime\00", align 8
@.str_176 = private unnamed_addr constant [28 x i8] c"\AC\32\7A\15\00\00\00\00\0B\00\00\00\00\00\00\00kw_comptime\00", align 8
@.str_177 = private unnamed_addr constant [30 x i8] c"\5E\F7\44\04\00\00\00\00\0D\00\00\00\00\00\00\00deterministic\00", align 8
@.str_178 = private unnamed_addr constant [33 x i8] c"\E1\C9\63\30\00\00\00\00\10\00\00\00\00\00\00\00kw_deterministic\00", align 8
@.str_179 = private unnamed_addr constant [25 x i8] c"\3D\FA\E3\19\00\00\00\00\08\00\00\00\00\00\00\00parallel\00", align 8
@.str_180 = private unnamed_addr constant [28 x i8] c"\07\9B\C5\03\00\00\00\00\0B\00\00\00\00\00\00\00kw_parallel\00", align 8
@.str_181 = private unnamed_addr constant [22 x i8] c"\CC\2C\0F\15\00\00\00\00\05\00\00\00\00\00\00\00spawn\00", align 8
@.str_182 = private unnamed_addr constant [25 x i8] c"\1F\93\DD\2B\00\00\00\00\08\00\00\00\00\00\00\00kw_spawn\00", align 8
@.str_183 = private unnamed_addr constant [24 x i8] c"\62\D6\9A\1C\00\00\00\00\07\00\00\00\00\00\00\00destroy\00", align 8
@.str_184 = private unnamed_addr constant [27 x i8] c"\C3\78\8A\2A\00\00\00\00\0A\00\00\00\00\00\00\00kw_destroy\00", align 8
@.str_185 = private unnamed_addr constant [24 x i8] c"\AF\00\53\28\00\00\00\00\07\00\00\00\00\00\00\00require\00", align 8
@.str_186 = private unnamed_addr constant [27 x i8] c"\10\A3\42\36\00\00\00\00\0A\00\00\00\00\00\00\00kw_require\00", align 8
@.str_187 = private unnamed_addr constant [23 x i8] c"\46\F4\21\25\00\00\00\00\06\00\00\00\00\00\00\00ensure\00", align 8
@.str_188 = private unnamed_addr constant [26 x i8] c"\61\DB\84\2C\00\00\00\00\09\00\00\00\00\00\00\00kw_ensure\00", align 8
@.str_189 = private unnamed_addr constant [22 x i8] c"\CD\E2\54\13\00\00\00\00\05\00\00\00\00\00\00\00scope\00", align 8
@.str_190 = private unnamed_addr constant [25 x i8] c"\20\49\23\2A\00\00\00\00\08\00\00\00\00\00\00\00kw_scope\00", align 8
@.str_191 = private unnamed_addr constant [20 x i8] c"\9C\BD\E3\05\00\00\00\00\03\00\00\00\00\00\00\00job\00", align 8
@.str_192 = private unnamed_addr constant [23 x i8] c"\60\84\09\2A\00\00\00\00\06\00\00\00\00\00\00\00kw_job\00", align 8
@.str_193 = private unnamed_addr constant [20 x i8] c"\CF\CE\E5\05\00\00\00\00\03\00\00\00\00\00\00\00raw\00", align 8
@.str_194 = private unnamed_addr constant [23 x i8] c"\93\95\0B\2A\00\00\00\00\06\00\00\00\00\00\00\00kw_raw\00", align 8
@.str_195 = private unnamed_addr constant [22 x i8] c"\DA\A8\8C\1F\00\00\00\00\05\00\00\00\00\00\00\00frame\00", align 8
@.str_196 = private unnamed_addr constant [25 x i8] c"\2D\0F\5B\36\00\00\00\00\08\00\00\00\00\00\00\00kw_frame\00", align 8
@.str_197 = private unnamed_addr constant [23 x i8] c"\39\45\33\0C\00\00\00\00\06\00\00\00\00\00\00\00before\00", align 8
@.str_198 = private unnamed_addr constant [26 x i8] c"\54\2C\96\13\00\00\00\00\09\00\00\00\00\00\00\00kw_before\00", align 8
@.str_199 = private unnamed_addr constant [22 x i8] c"\A8\35\CC\01\00\00\00\00\05\00\00\00\00\00\00\00after\00", align 8
@.str_200 = private unnamed_addr constant [25 x i8] c"\FB\9B\9A\18\00\00\00\00\08\00\00\00\00\00\00\00kw_after\00", align 8
@.str_201 = private unnamed_addr constant [19 x i8] c"\43\3E\81\05\00\00\00\00\02\00\00\00\00\00\00\00as\00", align 8
@.str_202 = private unnamed_addr constant [22 x i8] c"\40\9C\C6\00\00\00\00\00\05\00\00\00\00\00\00\00kw_as\00", align 8
@.str_203 = private unnamed_addr constant [26 x i8] c"\5E\C9\AB\25\00\00\00\00\09\00\00\00\00\00\00\00kw_return\00", align 8
@.str_204 = private unnamed_addr constant [21 x i8] c"\75\CB\D1\38\00\00\00\00\04\00\00\00\00\00\00\00none\00", align 8
@.str_205 = private unnamed_addr constant [24 x i8] c"\91\5F\C7\17\00\00\00\00\07\00\00\00\00\00\00\00kw_none\00", align 8
@.str_206 = private unnamed_addr constant [21 x i8] c"\1D\B0\7A\39\00\00\00\00\04\00\00\00\00\00\00\00self\00", align 8
@.str_207 = private unnamed_addr constant [24 x i8] c"\39\44\70\18\00\00\00\00\07\00\00\00\00\00\00\00kw_self\00", align 8
@.str_208 = private unnamed_addr constant [22 x i8] c"\A1\7B\C2\1E\00\00\00\00\05\00\00\00\00\00\00\00float\00", align 8
@.str_209 = private unnamed_addr constant [20 x i8] c"\22\7A\E3\05\00\00\00\00\03\00\00\00\00\00\00\00int\00", align 8
@.str_210 = private unnamed_addr constant [18 x i8] c"\BF\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\000\00", align 8
@.str_211 = private unnamed_addr constant [24 x i8] c"\6C\5F\F2\2D\00\00\00\00\07\00\00\00\00\00\00\00newline\00", align 8
@.str_212 = private unnamed_addr constant [20 x i8] c"\8C\1B\E6\05\00\00\00\00\03\00\00\00\00\00\00\00str\00", align 8
@.str_213 = private unnamed_addr constant [23 x i8] c"\BA\BB\9D\33\00\00\00\00\06\00\00\00\00\00\00\00closed\00", align 8
@.str_214 = private unnamed_addr constant [20 x i8] c"\17\E6\D3\05\00\00\00\00\03\00\00\00\00\00\00\00..<\00", align 8
@.str_215 = private unnamed_addr constant [20 x i8] c"\18\E6\D3\05\00\00\00\00\03\00\00\00\00\00\00\00..=\00", align 8
@.str_216 = private unnamed_addr constant [19 x i8] c"\A1\2B\81\05\00\00\00\00\02\00\00\00\00\00\00\00==\00", align 8
@.str_217 = private unnamed_addr constant [19 x i8] c"\4D\1D\81\05\00\00\00\00\02\00\00\00\00\00\00\00!=\00", align 8
@.str_218 = private unnamed_addr constant [19 x i8] c"\1E\2B\81\05\00\00\00\00\02\00\00\00\00\00\00\00<=\00", align 8
@.str_219 = private unnamed_addr constant [19 x i8] c"\24\2C\81\05\00\00\00\00\02\00\00\00\00\00\00\00>=\00", align 8
@.str_220 = private unnamed_addr constant [19 x i8] c"\72\23\81\05\00\00\00\00\02\00\00\00\00\00\00\00->\00", align 8
@.str_221 = private unnamed_addr constant [19 x i8] c"\6B\22\81\05\00\00\00\00\02\00\00\00\00\00\00\00+=\00", align 8
@.str_222 = private unnamed_addr constant [19 x i8] c"\71\23\81\05\00\00\00\00\02\00\00\00\00\00\00\00-=\00", align 8
@.str_223 = private unnamed_addr constant [19 x i8] c"\E8\21\81\05\00\00\00\00\02\00\00\00\00\00\00\00*=\00", align 8
@.str_224 = private unnamed_addr constant [19 x i8] c"\77\24\81\05\00\00\00\00\02\00\00\00\00\00\00\00/=\00", align 8
@.str_225 = private unnamed_addr constant [18 x i8] c"\BA\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00+\00", align 8
@.str_226 = private unnamed_addr constant [18 x i8] c"\BC\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00-\00", align 8
@.str_227 = private unnamed_addr constant [18 x i8] c"\B9\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00*\00", align 8
@.str_228 = private unnamed_addr constant [18 x i8] c"\BE\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00/\00", align 8
@.str_229 = private unnamed_addr constant [18 x i8] c"\CC\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00=\00", align 8
@.str_230 = private unnamed_addr constant [18 x i8] c"\CB\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00<\00", align 8
@.str_231 = private unnamed_addr constant [18 x i8] c"\CD\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00>\00", align 8
@.str_232 = private unnamed_addr constant [18 x i8] c"\B0\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00!\00", align 8
@.str_233 = private unnamed_addr constant [18 x i8] c"\B7\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00(\00", align 8
@.str_234 = private unnamed_addr constant [18 x i8] c"\B8\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00)\00", align 8
@.str_235 = private unnamed_addr constant [18 x i8] c"\BB\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00,\00", align 8
@.str_236 = private unnamed_addr constant [18 x i8] c"\C9\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00:\00", align 8
@.str_237 = private unnamed_addr constant [18 x i8] c"\CA\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00;\00", align 8
@.str_238 = private unnamed_addr constant [18 x i8] c"\EA\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00[\00", align 8
@.str_239 = private unnamed_addr constant [18 x i8] c"\EC\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00]\00", align 8
@.str_240 = private unnamed_addr constant [18 x i8] c"\0A\C2\0A\00\00\00\00\00\01\00\00\00\00\00\00\00{\00", align 8
@.str_241 = private unnamed_addr constant [18 x i8] c"\0C\C2\0A\00\00\00\00\00\01\00\00\00\00\00\00\00}\00", align 8
@.str_242 = private unnamed_addr constant [18 x i8] c"\CE\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00?\00", align 8
@.str_243 = private unnamed_addr constant [18 x i8] c"\CF\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00@\00", align 8
@.str_244 = private unnamed_addr constant [18 x i8] c"\B5\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00&\00", align 8
@.str_245 = private unnamed_addr constant [18 x i8] c"\ED\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00^\00", align 8
@.str_246 = private unnamed_addr constant [18 x i8] c"\B4\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00%\00", align 8
@.str_247 = private unnamed_addr constant [30 x i8] c"\18\37\C4\0B\00\00\00\00\0D\00\00\00\00\00\00\00slx:last_kind\00", align 8
@.str_248 = private unnamed_addr constant [23 x i8] c"\63\98\4F\39\00\00\00\00\06\00\00\00\00\00\00\00symbol\00", align 8
@.str_249 = private unnamed_addr constant [20 x i8] c"\73\6E\E2\05\00\00\00\00\03\00\00\00\00\00\00\00eof\00", align 8
@.str_250 = private unnamed_addr constant [20 x i8] c"\02\19\DB\05\00\00\00\00\03\00\00\00\00\00\00\00Int\00", align 8
@.str_251 = private unnamed_addr constant [21 x i8] c"\EF\16\0B\33\00\00\00\00\04\00\00\00\00\00\00\00Call\00", align 8
@.str_252 = private unnamed_addr constant [23 x i8] c"\45\86\EE\24\00\00\00\00\06\00\00\00\00\00\00\00callee\00", align 8
@.str_253 = private unnamed_addr constant [21 x i8] c"\2A\A0\14\37\00\00\00\00\04\00\00\00\00\00\00\00args\00", align 8
@.str_254 = private unnamed_addr constant [22 x i8] c"\26\4A\13\05\00\00\00\00\05\00\00\00\00\00\00\00Field\00", align 8
@.str_255 = private unnamed_addr constant [23 x i8] c"\E5\F1\75\33\00\00\00\00\06\00\00\00\00\00\00\00object\00", align 8
@.str_256 = private unnamed_addr constant [22 x i8] c"\28\EA\10\39\00\00\00\00\05\00\00\00\00\00\00\00Ident\00", align 8
@.str_257 = private unnamed_addr constant [21 x i8] c"\74\20\CE\38\00\00\00\00\04\00\00\00\00\00\00\00name\00", align 8
@.str_258 = private unnamed_addr constant [22 x i8] c"\07\FA\58\1E\00\00\00\00\05\00\00\00\00\00\00\00field\00", align 8
@.str_259 = private unnamed_addr constant [22 x i8] c"\7B\10\3B\19\00\00\00\00\05\00\00\00\00\00\00\00Named\00", align 8
@.str_260 = private unnamed_addr constant [21 x i8] c"\57\C6\D1\38\00\00\00\00\04\00\00\00\00\00\00\00node\00", align 8
@.str_261 = private unnamed_addr constant [26 x i8] c"\7B\FE\A8\20\00\00\00\00\09\00\00\00\00\00\00\00TupleType\00", align 8
@.str_262 = private unnamed_addr constant [22 x i8] c"\19\2D\32\0D\00\00\00\00\05\00\00\00\00\00\00\00elems\00", align 8
@.str_263 = private unnamed_addr constant [21 x i8] c"\47\ED\41\34\00\00\00\00\04\00\00\00\00\00\00\00List\00", align 8
@.str_264 = private unnamed_addr constant [21 x i8] c"\54\43\9C\37\00\00\00\00\04\00\00\00\00\00\00\00elem\00", align 8
@.str_265 = private unnamed_addr constant [22 x i8] c"\5B\81\58\30\00\00\00\00\05\00\00\00\00\00\00\00Error\00", align 8
@.str_266 = private unnamed_addr constant [20 x i8] c"\C8\88\E4\05\00\00\00\00\03\00\00\00\00\00\00\00msg\00", align 8
@.str_267 = private unnamed_addr constant [48 x i8] c"\0D\8E\65\17\00\00\00\00\1F\00\00\00\00\00\00\00expected `]` to close list type\00", align 8
@.str_268 = private unnamed_addr constant [22 x i8] c"\C8\63\D7\23\00\00\00\00\05\00\00\00\00\00\00\00Range\00", align 8
@.str_269 = private unnamed_addr constant [20 x i8] c"\C3\43\E4\05\00\00\00\00\03\00\00\00\00\00\00\00low\00", align 8
@.str_270 = private unnamed_addr constant [21 x i8] c"\0B\64\02\38\00\00\00\00\04\00\00\00\00\00\00\00high\00", align 8
@.str_271 = private unnamed_addr constant [26 x i8] c"\53\A6\2D\0E\00\00\00\00\09\00\00\00\00\00\00\00inclusive\00", align 8
@.str_272 = private unnamed_addr constant [21 x i8] c"\C9\F1\77\35\00\00\00\00\04\00\00\00\00\00\00\00Unit\00", align 8
@.str_273 = private unnamed_addr constant [23 x i8] c"\66\4F\1E\23\00\00\00\00\06\00\00\00\00\00\00\00FnType\00", align 8
@.str_274 = private unnamed_addr constant [23 x i8] c"\C7\25\E9\09\00\00\00\00\06\00\00\00\00\00\00\00params\00", align 8
@.str_275 = private unnamed_addr constant [20 x i8] c"\D8\D0\E5\05\00\00\00\00\03\00\00\00\00\00\00\00ret\00", align 8
@.str_276 = private unnamed_addr constant [20 x i8] c"\ED\6D\E2\05\00\00\00\00\03\00\00\00\00\00\00\00enc\00", align 8
@.str_277 = private unnamed_addr constant [22 x i8] c"\01\4F\4C\27\00\00\00\00\05\00\00\00\00\00\00\00tuple\00", align 8
@.str_278 = private unnamed_addr constant [18 x i8] c"\C0\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\001\00", align 8
@.str_279 = private unnamed_addr constant [24 x i8] c"\01\0F\A6\18\00\00\00\00\07\00\00\00\00\00\00\00pattern\00", align 8
@.str_280 = private unnamed_addr constant [25 x i8] c"\43\4E\1F\00\00\00\00\00\08\00\00\00\00\00\00\00pat_kind\00", align 8
@.str_281 = private unnamed_addr constant [25 x i8] c"\61\0A\1F\27\00\00\00\00\08\00\00\00\00\00\00\00bindings\00", align 8
@.str_282 = private unnamed_addr constant [21 x i8] c"\27\23\36\37\00\00\00\00\04\00\00\00\00\00\00\00body\00", align 8
@.str_283 = private unnamed_addr constant [22 x i8] c"\8A\4A\81\31\00\00\00\00\05\00\00\00\00\00\00\00guard\00", align 8
@.str_284 = private unnamed_addr constant [22 x i8] c"\67\2E\AF\07\00\00\00\00\05\00\00\00\00\00\00\00Match\00", align 8
@.str_285 = private unnamed_addr constant [26 x i8] c"\D0\CC\75\27\00\00\00\00\09\00\00\00\00\00\00\00scrutinee\00", align 8
@.str_286 = private unnamed_addr constant [21 x i8] c"\3C\A3\14\37\00\00\00\00\04\00\00\00\00\00\00\00arms\00", align 8
@.str_287 = private unnamed_addr constant [19 x i8] c"\EE\31\81\05\00\00\00\00\02\00\00\00\00\00\00\00If\00", align 8
@.str_288 = private unnamed_addr constant [21 x i8] c"\CB\75\58\37\00\00\00\00\04\00\00\00\00\00\00\00cond\00", align 8
@.str_289 = private unnamed_addr constant [21 x i8] c"\46\C3\9D\39\00\00\00\00\04\00\00\00\00\00\00\00then\00", align 8
@.str_290 = private unnamed_addr constant [21 x i8] c"\73\FB\17\39\00\00\00\00\04\00\00\00\00\00\00\00push\00", align 8
@.str_291 = private unnamed_addr constant [21 x i8] c"\B6\0A\CB\36\00\00\00\00\04\00\00\00\00\00\00\00__fc\00", align 8
@.str_292 = private unnamed_addr constant [28 x i8] c"\8C\13\E4\23\00\00\00\00\0B\00\00\00\00\00\00\00LetOrAssign\00", align 8
@.str_293 = private unnamed_addr constant [24 x i8] c"\DC\82\09\39\00\00\00\00\07\00\00\00\00\00\00\00IfBlock\00", align 8
@.str_294 = private unnamed_addr constant [22 x i8] c"\87\87\7B\36\00\00\00\00\05\00\00\00\00\00\00\00Block\00", align 8
@.str_295 = private unnamed_addr constant [22 x i8] c"\20\86\9B\15\00\00\00\00\05\00\00\00\00\00\00\00stmts\00", align 8
@.str_296 = private unnamed_addr constant [22 x i8] c"\5E\71\E4\05\00\00\00\00\05\00\00\00\00\00\00\00ForIn\00", align 8
@.str_297 = private unnamed_addr constant [20 x i8] c"\EE\DA\E6\05\00\00\00\00\03\00\00\00\00\00\00\00var\00", align 8
@.str_298 = private unnamed_addr constant [26 x i8] c"\D1\3E\A1\37\00\00\00\00\09\00\00\00\00\00\00\00index_var\00", align 8
@.str_299 = private unnamed_addr constant [21 x i8] c"\0D\92\27\38\00\00\00\00\04\00\00\00\00\00\00\00iter\00", align 8
@.str_300 = private unnamed_addr constant [23 x i8] c"\8B\99\63\2E\00\00\00\00\06\00\00\00\00\00\00\00MutLet\00", align 8
@.str_301 = private unnamed_addr constant [24 x i8] c"\D5\69\9B\34\00\00\00\00\07\00\00\00\00\00\00\00ListLit\00", align 8
@.str_302 = private unnamed_addr constant [22 x i8] c"\2E\A9\E0\18\00\00\00\00\05\00\00\00\00\00\00\00items\00", align 8
@.str_303 = private unnamed_addr constant [25 x i8] c"\FE\67\D2\28\00\00\00\00\08\00\00\00\00\00\00\00ExprStmt\00", align 8
@.str_304 = private unnamed_addr constant [21 x i8] c"\66\6D\9F\37\00\00\00\00\04\00\00\00\00\00\00\00expr\00", align 8
@.str_305 = private unnamed_addr constant [22 x i8] c"\A0\65\5A\19\00\00\00\00\05\00\00\00\00\00\00\00__par\00", align 8
@.str_306 = private unnamed_addr constant [23 x i8] c"\EB\6B\7D\11\00\00\00\00\06\00\00\00\00\00\00\00Lambda\00", align 8
@.str_307 = private unnamed_addr constant [21 x i8] c"\DA\0F\CB\36\00\00\00\00\04\00\00\00\00\00\00\00__pi\00", align 8
@.str_308 = private unnamed_addr constant [28 x i8] c"\B7\C4\1E\27\00\00\00\00\0B\00\00\00\00\00\00\00param_types\00", align 8
@.str_309 = private unnamed_addr constant [25 x i8] c"\EE\D3\B1\32\00\00\00\00\08\00\00\00\00\00\00\00ForRange\00", align 8
@.str_310 = private unnamed_addr constant [24 x i8] c"\AD\77\58\2E\00\00\00\00\07\00\00\00\00\00\00\00par_run\00", align 8
@.str_311 = private unnamed_addr constant [22 x i8] c"\D3\4B\A0\1E\00\00\00\00\05\00\00\00\00\00\00\00Unary\00", align 8
@.str_312 = private unnamed_addr constant [19 x i8] c"\6A\45\81\05\00\00\00\00\02\00\00\00\00\00\00\00op\00", align 8
@.str_313 = private unnamed_addr constant [24 x i8] c"\36\01\F0\2D\00\00\00\00\07\00\00\00\00\00\00\00operand\00", align 8
@.str_314 = private unnamed_addr constant [20 x i8] c"\A7\C4\E4\05\00\00\00\00\03\00\00\00\00\00\00\00neg\00", align 8
@.str_315 = private unnamed_addr constant [24 x i8] c"\D4\A7\A0\06\00\00\00\00\07\00\00\00\00\00\00\00perform\00", align 8
@.str_316 = private unnamed_addr constant [39 x i8] c"\05\13\16\36\00\00\00\00\16\00\00\00\00\00\00\00expected an expression\00", align 8
@.str_317 = private unnamed_addr constant [24 x i8] c"\E6\5E\26\35\00\00\00\00\07\00\00\00\00\00\00\00Perform\00", align 8
@.str_318 = private unnamed_addr constant [23 x i8] c"\BF\AC\27\0E\00\00\00\00\06\00\00\00\00\00\00\00effect\00", align 8
@.str_319 = private unnamed_addr constant [22 x i8] c"\C0\CB\7C\05\00\00\00\00\05\00\00\00\00\00\00\00Float\00", align 8
@.str_320 = private unnamed_addr constant [22 x i8] c"\20\9F\06\0E\00\00\00\00\05\00\00\00\00\00\00\00Tuple\00", align 8
@.str_321 = private unnamed_addr constant [27 x i8] c"\C5\32\2D\24\00\00\00\00\0A\00\00\00\00\00\00\00StructCons\00", align 8
@.str_322 = private unnamed_addr constant [23 x i8] c"\3A\DC\9F\29\00\00\00\00\06\00\00\00\00\00\00\00fields\00", align 8
@.str_323 = private unnamed_addr constant [23 x i8] c"\88\09\36\13\00\00\00\00\06\00\00\00\00\00\00\00spread\00", align 8
@.str_324 = private unnamed_addr constant [20 x i8] c"\6C\BA\DD\05\00\00\00\00\03\00\00\00\00\00\00\00Str\00", align 8
@.str_325 = private unnamed_addr constant [23 x i8] c"\49\48\11\33\00\00\00\00\06\00\00\00\00\00\00\00Binary\00", align 8
@.str_326 = private unnamed_addr constant [21 x i8] c"\DC\8D\8A\38\00\00\00\00\04\00\00\00\00\00\00\00left\00", align 8
@.str_327 = private unnamed_addr constant [22 x i8] c"\CD\E1\92\02\00\00\00\00\05\00\00\00\00\00\00\00right\00", align 8
@.str_328 = private unnamed_addr constant [24 x i8] c"\C7\33\44\3B\00\00\00\00\07\00\00\00\00\00\00\00to_text\00", align 8
@.str_329 = private unnamed_addr constant [20 x i8] c"\9E\FB\E3\05\00\00\00\00\03\00\00\00\00\00\00\00key\00", align 8
@.str_330 = private unnamed_addr constant [23 x i8] c"\01\E3\68\34\00\00\00\00\06\00\00\00\00\00\00\00MapLit\00", align 8
@.str_331 = private unnamed_addr constant [22 x i8] c"\89\5D\00\1A\00\00\00\00\05\00\00\00\00\00\00\00pairs\00", align 8
@.str_332 = private unnamed_addr constant [25 x i8] c"\AA\B6\44\2A\00\00\00\00\08\00\00\00\00\00\00\00NamedArg\00", align 8
@.str_333 = private unnamed_addr constant [27 x i8] c"\E4\2E\C4\31\00\00\00\00\0A\00\00\00\00\00\00\00MethodCall\00", align 8
@.str_334 = private unnamed_addr constant [25 x i8] c"\48\87\B5\2F\00\00\00\00\08\00\00\00\00\00\00\00receiver\00", align 8
@.str_335 = private unnamed_addr constant [23 x i8] c"\43\4F\62\24\00\00\00\00\06\00\00\00\00\00\00\00method\00", align 8
@.str_336 = private unnamed_addr constant [22 x i8] c"\96\AA\67\3A\00\00\00\00\05\00\00\00\00\00\00\00Index\00", align 8
@.str_337 = private unnamed_addr constant [22 x i8] c"\70\90\12\18\00\00\00\00\05\00\00\00\00\00\00\00index\00", align 8
@.str_338 = private unnamed_addr constant [25 x i8] c"\CD\B4\AC\14\00\00\00\00\08\00\00\00\00\00\00\00Question\00", align 8
@.str_339 = private unnamed_addr constant [22 x i8] c"\C4\2E\15\18\00\00\00\00\05\00\00\00\00\00\00\00inner\00", align 8
@.str_340 = private unnamed_addr constant [21 x i8] c"\77\3C\A2\39\00\00\00\00\04\00\00\00\00\00\00\00type\00", align 8
@.str_341 = private unnamed_addr constant [24 x i8] c"\F6\F1\7F\25\00\00\00\00\07\00\00\00\00\00\00\00Unknown\00", align 8

define ptr @prog__ir_type_i64() {
entry:
    %v0 = getelementptr i8, ptr @.str_0, i64 16
    ret ptr %v0
}

define ptr @prog__ir_type_ptr() {
entry:
    %v0 = getelementptr i8, ptr @.str_1, i64 16
    ret ptr %v0
}

define ptr @prog__ir_type_bool() {
entry:
    %v0 = getelementptr i8, ptr @.str_2, i64 16
    ret ptr %v0
}

define ptr @prog__ir_type_void() {
entry:
    %v0 = getelementptr i8, ptr @.str_3, i64 16
    ret ptr %v0
}

define i64 @prog__compile_error(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    call i32 @puts(ptr %v0)
    %v1 = add i64 0, 0
    %v2 = call i64 @orion_err_bump()
    ret i64 %v2
}

define i64 @prog__compile_errors() {
entry:
    %v0 = call i64 @orion_err_get()
    ret i64 %v0
}

define ptr @prog__ir_iconst(i64 %p0) {
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

define ptr @prog__ir_iadd(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_isub(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_imul(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_idiv(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_imod(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_iand(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_ior(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_inot(i64 %p0) {
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

define ptr @prog__ir_icmp_eq(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_icmp_ne(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_icmp_lt(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_icmp_le(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_icmp_gt(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_icmp_ge(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_return(i64 %p0) {
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

define ptr @prog__ir_return_void() {
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

define ptr @prog__ir_print_int(i64 %p0) {
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

define ptr @prog__ir_print_float(i64 %p0) {
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

define ptr @prog__ir_select(i64 %p0, i64 %p1, i64 %p2) {
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

define ptr @prog__ir_fconst(ptr %p0) {
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

define ptr @prog__ir_fbin(ptr %p0, i64 %p1, i64 %p2) {
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

define ptr @prog__ir_fcmp(ptr %p0, i64 %p1, i64 %p2) {
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

define ptr @prog__ir_sitofp(i64 %p0) {
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

define ptr @prog__ir_fptosi(i64 %p0) {
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

define ptr @prog__ir_call(ptr %p0, ptr %p1, ptr %p2) {
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

define ptr @prog__ir_print_str(ptr %p0) {
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

define ptr @prog__ir_const_str(ptr %p0) {
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

define ptr @prog__ir_text_concat(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_int_to_text(i64 %p0) {
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

define ptr @prog__ir_text_cmp(ptr %p0, i64 %p1, i64 %p2) {
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

define ptr @prog__ir_text_len(i64 %p0) {
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

define ptr @prog__ir_text_slice(i64 %p0, i64 %p1, i64 %p2) {
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

define ptr @prog__ir_list_slice(i64 %p0, i64 %p1, i64 %p2, ptr %p3) {
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

define ptr @prog__ir_fmath1(ptr %p0, i64 %p1) {
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

define ptr @prog__ir_fmath2(ptr %p0, i64 %p1, i64 %p2) {
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

define ptr @prog__ir_text_contains(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_file_read(i64 %p0) {
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

define ptr @prog__ir_file_write(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_argc() {
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

define ptr @prog__ir_argv(i64 %p0) {
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

define ptr @prog__ir_bytes_from_text(i64 %p0) {
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

define ptr @prog__ir_bytes_to_text(i64 %p0) {
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

define ptr @prog__ir_bytes_slice(i64 %p0, i64 %p1, i64 %p2) {
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

define ptr @prog__ir_bytes_concat(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_bytes_zeros(i64 %p0) {
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

define ptr @prog__ir_slot_get(i64 %p0) {
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

define ptr @prog__ir_slot_set(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_list_lit(ptr %p0, ptr %p1) {
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

define ptr @prog__ir_list_at(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_list_len(i64 %p0) {
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

define ptr @prog__ir_list_push(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_list_push_mut(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_vec_add(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_vec_addi(i64 %p0, i64 %p1) {
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

define ptr @prog__ir_vec_madd(i64 %p0, i64 %p1, i64 %p2) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = getelementptr i8, ptr @.str_61, i64 16
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

define ptr @prog__ir_par_madd(i64 %p0, i64 %p1, i64 %p2) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = getelementptr i8, ptr @.str_62, i64 16
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

define ptr @prog__ir_vec_sub(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_63, i64 16
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

define ptr @prog__ir_vec_mul(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_64, i64 16
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

define ptr @prog__ir_vec_dot(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_65, i64 16
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

define ptr @prog__ir_time_now_ms() {
entry:
    %v0 = getelementptr i8, ptr @.str_66, i64 16
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

define ptr @prog__ir_monotonic_ms() {
entry:
    %v0 = getelementptr i8, ptr @.str_67, i64 16
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

define ptr @prog__ir_sleep_ms(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_68, i64 16
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

define ptr @prog__ir_map_lit(ptr %p0, ptr %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i8, ptr @.str_69, i64 16
    %v3 = getelementptr i8, ptr @.str_70, i64 16
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

define ptr @prog__ir_map_get(i64 %p0, i64 %p1, ptr %p2) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr %p2, i64 0
    %v3 = getelementptr i8, ptr @.str_71, i64 16
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

define ptr @prog__ir_map_has(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_72, i64 16
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

define ptr @prog__ir_map_set_val(i64 %p0, i64 %p1, i64 %p2, ptr %p3) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = getelementptr i8, ptr %p3, i64 0
    %v4 = getelementptr i8, ptr @.str_73, i64 16
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

define ptr @prog__ir_map_remove(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_74, i64 16
    %v3 = getelementptr i8, ptr @.str_75, i64 16
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

define ptr @prog__ir_list_set_val(i64 %p0, i64 %p1, i64 %p2, ptr %p3) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = getelementptr i8, ptr %p3, i64 0
    %v4 = getelementptr i8, ptr @.str_76, i64 16
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

define ptr @prog__ir_slot_has(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_77, i64 16
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

define ptr @prog__ir_slot_get_int(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_78, i64 16
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

define ptr @prog__ir_map_len(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_79, i64 16
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

define ptr @prog__ir_map_keys(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_80, i64 16
    %v2 = getelementptr i8, ptr @.str_81, i64 16
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

define ptr @prog__ir_map_values(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_82, i64 16
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

define ptr @prog__ir_map_get_or(i64 %p0, i64 %p1, i64 %p2, ptr %p3) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = getelementptr i8, ptr %p3, i64 0
    %v4 = getelementptr i8, ptr @.str_83, i64 16
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

define ptr @prog__ir_f64_to_text(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_84, i64 16
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

define ptr @prog__ir_struct_cons(ptr %p0, i64 %p1, ptr %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr %p2, i64 0
    %v3 = getelementptr i8, ptr @.str_85, i64 16
    %v4 = getelementptr i8, ptr @.str_86, i64 16
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

define ptr @prog__ir_field_load(i64 %p0, i64 %p1, ptr %p2) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr %p2, i64 0
    %v3 = getelementptr i8, ptr @.str_87, i64 16
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

define ptr @prog__ir_print_text(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_88, i64 16
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

define ptr @prog__ir_alloca(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr @.str_89, i64 16
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

define ptr @prog__ir_load(i64 %p0, ptr %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i8, ptr @.str_90, i64 16
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

define ptr @prog__ir_store(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_91, i64 16
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

define ptr @prog__ir_label(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr @.str_92, i64 16
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

define ptr @prog__ir_br(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr @.str_93, i64 16
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

define ptr @prog__ir_br_if(i64 %p0, ptr %p1, ptr %p2) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i8, ptr %p2, i64 0
    %v3 = getelementptr i8, ptr @.str_94, i64 16
    %v4 = getelementptr i8, ptr @.str_3, i64 16
    %v5 = add i64 0, 0
    %v6 = add i64 0, 0
    %v7 = getelementptr i8, ptr @.str_95, i64 16
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

define ptr @prog__ir_phi(i64 %p0, ptr %p1, i64 %p2, ptr %p3, ptr %p4) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = add i64 0, %p2
    %v3 = getelementptr i8, ptr %p3, i64 0
    %v4 = getelementptr i8, ptr %p4, i64 0
    %v5 = getelementptr i8, ptr @.str_96, i64 16
    %v6 = add i64 0, 0
    %v7 = getelementptr i8, ptr @.str_95, i64 16
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

define ptr @prog__ir_param(i64 %p0, ptr %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i8, ptr @.str_97, i64 16
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

define ptr @prog__ir_fn_new(ptr %p0, ptr %p1) {
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

define ptr @prog__ir_fn_add_param(ptr %p0, ptr %p1, ptr %p2) {
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

define ptr @prog__ir_fn_push(ptr %p0, ptr %p1) {
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

define ptr @prog__ir_fn_set_inst(ptr %p0, i64 %p1, ptr %p2) {
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

define ptr @prog__ir_module_new() {
entry:
    %v0 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v1 = call ptr @orion_alloc(i64 8)
    %v1.f0 = getelementptr i64, ptr %v1, i64 0
    %v1.f0.i = ptrtoint ptr %v0 to i64
    store i64 %v1.f0.i, ptr %v1.f0
    ret ptr %v1
}

define ptr @prog__ir_module_add_fn(ptr %p0, ptr %p1) {
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

define ptr @prog__ir_dump_value_ref(i64 %p0) {
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
    %v8 = getelementptr i8, ptr @.str_98, i64 16
    %v9 = call ptr @orion_int_to_text(i64 %v0)
    %v10 = call ptr @orion_text_concat(ptr %v8, ptr %v9)
    br label %if_3_merge
if_3_merge:
    %v13 = phi ptr [ %v5, %if_3_then ], [ %v10, %if_3_else ]
    ret ptr %v13
}

define ptr @prog__ir_dump_instruction(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = call ptr @prog__ir_dump_value_ref(i64 %v1)
    %v3 = getelementptr i8, ptr @.str_99, i64 16
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
    %v10 = getelementptr i8, ptr @.str_100, i64 16
    %v11 = call ptr @orion_text_concat(ptr %v4, ptr %v10)
    %v12.slot = getelementptr i64, ptr %v0, i64 1
    %v12.i = load i64, ptr %v12.slot
    %v12 = inttoptr i64 %v12.i to ptr
    %v13 = call ptr @orion_text_concat(ptr %v11, ptr %v12)
    %v14 = getelementptr i8, ptr @.str_101, i64 16
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
    %v25 = getelementptr i8, ptr @.str_102, i64 16
    %v26.slot = getelementptr i64, ptr %v0, i64 2
    %v26 = load i64, ptr %v26.slot
    %v27 = call ptr @prog__ir_dump_value_ref(i64 %v26)
    %v28 = call ptr @orion_text_concat(ptr %v25, ptr %v27)
    br label %if_23_merge
if_23_else:
    %v31.slot = getelementptr i64, ptr %v0, i64 3
    %v31 = load i64, ptr %v31.slot
    %v32 = call ptr @prog__ir_dump_value_ref(i64 %v31)
    %v33.slot = getelementptr i64, ptr %v0, i64 4
    %v33 = load i64, ptr %v33.slot
    %v34 = call ptr @prog__ir_dump_value_ref(i64 %v33)
    %v35 = call ptr @orion_text_concat(ptr %v4, ptr %v5)
    %v36 = getelementptr i8, ptr @.str_103, i64 16
    %v37 = call ptr @orion_text_concat(ptr %v35, ptr %v36)
    %v38.slot = getelementptr i64, ptr %v0, i64 1
    %v38.i = load i64, ptr %v38.slot
    %v38 = inttoptr i64 %v38.i to ptr
    %v39 = call ptr @orion_text_concat(ptr %v37, ptr %v38)
    %v40 = getelementptr i8, ptr @.str_101, i64 16
    %v41 = call ptr @orion_text_concat(ptr %v39, ptr %v40)
    %v42 = call ptr @orion_text_concat(ptr %v41, ptr %v32)
    %v43 = getelementptr i8, ptr @.str_104, i64 16
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

define ptr @prog__ir_perform_int(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_105, i64 16
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

define ptr @prog__ir_perform_text(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_106, i64 16
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

define ptr @prog__ir_fn_ref(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr @.str_107, i64 16
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

define ptr @prog__ir_indirect_call(i64 %p0, ptr %p1, ptr %p2) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i8, ptr %p2, i64 0
    %v3 = getelementptr i8, ptr @.str_108, i64 16
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

define ptr @prog__ir_make_closure(ptr %p0, ptr %p1, i64 %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = add i64 0, %p2
    %v3 = getelementptr i8, ptr @.str_109, i64 16
    %v4 = getelementptr i8, ptr @.str_1, i64 16
    %v5 = add i64 0, 0
    %v6 = add i64 0, 0
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
    store i64 %v2, ptr %v7.f3
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

define ptr @prog__ir_closure_call(i64 %p0, ptr %p1, ptr %p2) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i8, ptr %p2, i64 0
    %v3 = getelementptr i8, ptr @.str_110, i64 16
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

define ptr @prog__ir_int_to_ptr(i64 %p0, ptr %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i8, ptr @.str_111, i64 16
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

define ptr @prog__ir_dump_fn(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr @.str_112, i64 16
    %v2.slot = getelementptr i64, ptr %v0, i64 0
    %v2.i = load i64, ptr %v2.slot
    %v2 = inttoptr i64 %v2.i to ptr
    %v3 = call ptr @orion_text_concat(ptr %v1, ptr %v2)
    %v4 = getelementptr i8, ptr @.str_113, i64 16
    %v5 = call ptr @orion_text_concat(ptr %v3, ptr %v4)
    %v6.slot = getelementptr i64, ptr %v0, i64 1
    %v6.i = load i64, ptr %v6.slot
    %v6 = inttoptr i64 %v6.i to ptr
    %v7 = call ptr @orion_text_concat(ptr %v5, ptr %v6)
    %v8 = getelementptr i8, ptr @.str_114, i64 16
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
    %v25 = call ptr @prog__ir_dump_instruction(ptr %v24, i64 %v19)
    %v26 = load ptr, ptr %v10
    %v27 = getelementptr i8, ptr @.str_115, i64 16
    %v28 = call ptr @orion_text_concat(ptr %v26, ptr %v27)
    %v29 = call ptr @orion_text_concat(ptr %v28, ptr %v25)
    %v30 = getelementptr i8, ptr @.str_116, i64 16
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

define ptr @prog__ir_dump_module(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr @.str_117, i64 16
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
    %v18 = call ptr @prog__ir_dump_fn(ptr %v16)
    %v19 = call ptr @orion_text_concat(ptr %v17, ptr %v18)
    %v20 = getelementptr i8, ptr @.str_116, i64 16
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

define i64 @prog__slx_is_space(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, 32
    %v2.b = icmp eq i64 %v0, %v1
    %v2 = zext i1 %v2.b to i64
    %v3.cb = icmp ne i64 %v2, 0
    br i1 %v3.cb, label %if_3_then, label %if_3_else
if_3_then:
    br label %if_3_merge
if_3_else:
    %v7 = add i64 0, 9
    %v8.b = icmp eq i64 %v0, %v7
    %v8 = zext i1 %v8.b to i64
    br label %if_3_merge
if_3_merge:
    %v11 = phi i64 [ %v2, %if_3_then ], [ %v8, %if_3_else ]
    %v12.cb = icmp ne i64 %v11, 0
    br i1 %v12.cb, label %if_12_then, label %if_12_else
if_12_then:
    br label %if_12_merge
if_12_else:
    %v16 = add i64 0, 13
    %v17.b = icmp eq i64 %v0, %v16
    %v17 = zext i1 %v17.b to i64
    br label %if_12_merge
if_12_merge:
    %v20 = phi i64 [ %v11, %if_12_then ], [ %v17, %if_12_else ]
    ret i64 %v20
}

define i64 @prog__slx_is_newline(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, 10
    %v2.b = icmp eq i64 %v0, %v1
    %v2 = zext i1 %v2.b to i64
    ret i64 %v2
}

define i64 @prog__slx_is_digit(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, 48
    %v2.b = icmp sge i64 %v0, %v1
    %v2 = zext i1 %v2.b to i64
    %v3.cb = icmp ne i64 %v2, 0
    br i1 %v3.cb, label %if_3_then, label %if_3_else
if_3_then:
    %v5 = add i64 0, 57
    %v6.b = icmp sle i64 %v0, %v5
    %v6 = zext i1 %v6.b to i64
    br label %if_3_merge
if_3_else:
    %v9 = add i64 0, 0
    br label %if_3_merge
if_3_merge:
    %v12 = phi i64 [ %v6, %if_3_then ], [ %v9, %if_3_else ]
    ret i64 %v12
}

define i64 @prog__slx_is_lower(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, 97
    %v2.b = icmp sge i64 %v0, %v1
    %v2 = zext i1 %v2.b to i64
    %v3.cb = icmp ne i64 %v2, 0
    br i1 %v3.cb, label %if_3_then, label %if_3_else
if_3_then:
    %v5 = add i64 0, 122
    %v6.b = icmp sle i64 %v0, %v5
    %v6 = zext i1 %v6.b to i64
    br label %if_3_merge
if_3_else:
    %v9 = add i64 0, 0
    br label %if_3_merge
if_3_merge:
    %v12 = phi i64 [ %v6, %if_3_then ], [ %v9, %if_3_else ]
    ret i64 %v12
}

define i64 @prog__slx_is_upper(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, 65
    %v2.b = icmp sge i64 %v0, %v1
    %v2 = zext i1 %v2.b to i64
    %v3.cb = icmp ne i64 %v2, 0
    br i1 %v3.cb, label %if_3_then, label %if_3_else
if_3_then:
    %v5 = add i64 0, 90
    %v6.b = icmp sle i64 %v0, %v5
    %v6 = zext i1 %v6.b to i64
    br label %if_3_merge
if_3_else:
    %v9 = add i64 0, 0
    br label %if_3_merge
if_3_merge:
    %v12 = phi i64 [ %v6, %if_3_then ], [ %v9, %if_3_else ]
    ret i64 %v12
}

define i64 @prog__slx_is_ident_start(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = call i64 @prog__slx_is_lower(i64 %v0)
    %v2.cb = icmp ne i64 %v1, 0
    br i1 %v2.cb, label %if_2_then, label %if_2_else
if_2_then:
    br label %if_2_merge
if_2_else:
    %v6 = call i64 @prog__slx_is_upper(i64 %v0)
    br label %if_2_merge
if_2_merge:
    %v9 = phi i64 [ %v1, %if_2_then ], [ %v6, %if_2_else ]
    %v10.cb = icmp ne i64 %v9, 0
    br i1 %v10.cb, label %if_10_then, label %if_10_else
if_10_then:
    br label %if_10_merge
if_10_else:
    %v14 = add i64 0, 95
    %v15.b = icmp eq i64 %v0, %v14
    %v15 = zext i1 %v15.b to i64
    br label %if_10_merge
if_10_merge:
    %v18 = phi i64 [ %v9, %if_10_then ], [ %v15, %if_10_else ]
    ret i64 %v18
}

define i64 @prog__slx_is_ident_continue(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = call i64 @prog__slx_is_ident_start(i64 %v0)
    %v2.cb = icmp ne i64 %v1, 0
    br i1 %v2.cb, label %if_2_then, label %if_2_else
if_2_then:
    br label %if_2_merge
if_2_else:
    %v6 = call i64 @prog__slx_is_digit(i64 %v0)
    br label %if_2_merge
if_2_merge:
    %v9 = phi i64 [ %v1, %if_2_then ], [ %v6, %if_2_else ]
    ret i64 %v9
}

define ptr @prog__slx_make_token(ptr %p0, ptr %p1, i64 %p2, i64 %p3) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = add i64 0, %p2
    %v3 = add i64 0, %p3
    %v4 = getelementptr i8, ptr @.str_118, i64 16
    %v5 = getelementptr i8, ptr @.str_119, i64 16
    %v6 = getelementptr i8, ptr @.str_120, i64 16
    %v7 = getelementptr i8, ptr @.str_121, i64 16
    %v8 = call ptr @orion_map_new(i64 4)
    %v8.p0 = ptrtoint ptr %v0 to i64
    call void @orion_map_set(ptr %v8, ptr %v4, i64 %v8.p0)
    %v8.p1 = ptrtoint ptr %v1 to i64
    call void @orion_map_set(ptr %v8, ptr %v5, i64 %v8.p1)
    call void @orion_map_set(ptr %v8, ptr %v6, i64 %v2)
    call void @orion_map_set(ptr %v8, ptr %v7, i64 %v3)
    ret ptr %v8
}

define ptr @prog__slx_scan_ident(ptr %p0, i64 %p1, i64 %p2, i64 %p3, i64 %p4) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = add i64 0, %p3
    %v4 = add i64 0, %p4
    %v5 = alloca i64, align 8
    store i64 %v1, ptr %v5
    %v6 = add i64 0, 0
    br label %loop_7_header
loop_7_header:
    %v9 = load i64, ptr %v5
    %v10.b = icmp sge i64 %v9, %v2
    %v10 = zext i1 %v10.b to i64
    %v11.cb = icmp ne i64 %v10, 0
    br i1 %v11.cb, label %if_11_then, label %if_11_else
if_11_then:
    br label %loop_7_end
if_11_else:
    br label %if_11_merge
if_11_merge:
    %v17 = load i64, ptr %v5
    %v18 = call i64 @orion_list_at(ptr %v0, i64 %v17)
    %v19 = call i64 @prog__slx_is_ident_continue(i64 %v18)
    %v20.n = icmp eq i64 %v19, 0
    %v20 = zext i1 %v20.n to i64
    %v21.cb = icmp ne i64 %v20, 0
    br i1 %v21.cb, label %if_21_then, label %if_21_else
if_21_then:
    br label %loop_7_end
if_21_else:
    br label %if_21_merge
if_21_merge:
    %v27 = load i64, ptr %v5
    %v28 = add i64 0, 1
    %v29 = add i64 %v27, %v28
    store i64 %v29, ptr %v5
    %v30 = add i64 0, 0
    br label %loop_7_header
loop_7_end:
    %v33 = load i64, ptr %v5
    %v34 = call ptr @orion_bytes_slice(ptr %v0, i64 %v1, i64 %v33)
    %v35 = call ptr @orion_bytes_to_text(ptr %v34)
    %v36 = getelementptr i8, ptr @.str_122, i64 16
    %v37 = getelementptr i8, ptr @.str_123, i64 16
    %v38 = call ptr @prog__slx_make_token(ptr %v37, ptr %v35, i64 %v3, i64 %v4)
    %v39 = getelementptr i8, ptr @.str_124, i64 16
    %v40 = load i64, ptr %v5
    %v41 = call ptr @orion_map_new(i64 2)
    %v41.p0 = ptrtoint ptr %v38 to i64
    call void @orion_map_set(ptr %v41, ptr %v36, i64 %v41.p0)
    call void @orion_map_set(ptr %v41, ptr %v39, i64 %v40)
    ret ptr %v41
}

define ptr @prog__slx_keyword_table() {
entry:
    %v0 = getelementptr i8, ptr @.str_125, i64 16
    %v1 = getelementptr i8, ptr @.str_126, i64 16
    %v2 = getelementptr i8, ptr @.str_127, i64 16
    %v3 = getelementptr i8, ptr @.str_128, i64 16
    %v4 = getelementptr i8, ptr @.str_129, i64 16
    %v5 = getelementptr i8, ptr @.str_130, i64 16
    %v6 = getelementptr i8, ptr @.str_131, i64 16
    %v7 = getelementptr i8, ptr @.str_132, i64 16
    %v8 = getelementptr i8, ptr @.str_133, i64 16
    %v9 = getelementptr i8, ptr @.str_134, i64 16
    %v10 = getelementptr i8, ptr @.str_135, i64 16
    %v11 = getelementptr i8, ptr @.str_136, i64 16
    %v12 = getelementptr i8, ptr @.str_137, i64 16
    %v13 = getelementptr i8, ptr @.str_138, i64 16
    %v14 = getelementptr i8, ptr @.str_139, i64 16
    %v15 = getelementptr i8, ptr @.str_140, i64 16
    %v16 = getelementptr i8, ptr @.str_141, i64 16
    %v17 = getelementptr i8, ptr @.str_142, i64 16
    %v18 = getelementptr i8, ptr @.str_143, i64 16
    %v19 = getelementptr i8, ptr @.str_144, i64 16
    %v20 = getelementptr i8, ptr @.str_145, i64 16
    %v21 = getelementptr i8, ptr @.str_146, i64 16
    %v22 = getelementptr i8, ptr @.str_147, i64 16
    %v23 = getelementptr i8, ptr @.str_148, i64 16
    %v24 = getelementptr i8, ptr @.str_149, i64 16
    %v25 = getelementptr i8, ptr @.str_150, i64 16
    %v26 = getelementptr i8, ptr @.str_151, i64 16
    %v27 = getelementptr i8, ptr @.str_152, i64 16
    %v28 = getelementptr i8, ptr @.str_153, i64 16
    %v29 = getelementptr i8, ptr @.str_154, i64 16
    %v30 = getelementptr i8, ptr @.str_155, i64 16
    %v31 = getelementptr i8, ptr @.str_156, i64 16
    %v32 = getelementptr i8, ptr @.str_157, i64 16
    %v33 = getelementptr i8, ptr @.str_158, i64 16
    %v34 = getelementptr i8, ptr @.str_159, i64 16
    %v35 = getelementptr i8, ptr @.str_160, i64 16
    %v36 = getelementptr i8, ptr @.str_161, i64 16
    %v37 = getelementptr i8, ptr @.str_162, i64 16
    %v38 = getelementptr i8, ptr @.str_163, i64 16
    %v39 = getelementptr i8, ptr @.str_164, i64 16
    %v40 = getelementptr i8, ptr @.str_165, i64 16
    %v41 = getelementptr i8, ptr @.str_166, i64 16
    %v42 = getelementptr i8, ptr @.str_167, i64 16
    %v43 = getelementptr i8, ptr @.str_168, i64 16
    %v44 = getelementptr i8, ptr @.str_169, i64 16
    %v45 = getelementptr i8, ptr @.str_170, i64 16
    %v46 = getelementptr i8, ptr @.str_171, i64 16
    %v47 = getelementptr i8, ptr @.str_172, i64 16
    %v48 = getelementptr i8, ptr @.str_173, i64 16
    %v49 = getelementptr i8, ptr @.str_174, i64 16
    %v50 = getelementptr i8, ptr @.str_175, i64 16
    %v51 = getelementptr i8, ptr @.str_176, i64 16
    %v52 = getelementptr i8, ptr @.str_177, i64 16
    %v53 = getelementptr i8, ptr @.str_178, i64 16
    %v54 = getelementptr i8, ptr @.str_179, i64 16
    %v55 = getelementptr i8, ptr @.str_180, i64 16
    %v56 = getelementptr i8, ptr @.str_181, i64 16
    %v57 = getelementptr i8, ptr @.str_182, i64 16
    %v58 = getelementptr i8, ptr @.str_183, i64 16
    %v59 = getelementptr i8, ptr @.str_184, i64 16
    %v60 = getelementptr i8, ptr @.str_185, i64 16
    %v61 = getelementptr i8, ptr @.str_186, i64 16
    %v62 = getelementptr i8, ptr @.str_187, i64 16
    %v63 = getelementptr i8, ptr @.str_188, i64 16
    %v64 = getelementptr i8, ptr @.str_189, i64 16
    %v65 = getelementptr i8, ptr @.str_190, i64 16
    %v66 = getelementptr i8, ptr @.str_191, i64 16
    %v67 = getelementptr i8, ptr @.str_192, i64 16
    %v68 = getelementptr i8, ptr @.str_193, i64 16
    %v69 = getelementptr i8, ptr @.str_194, i64 16
    %v70 = getelementptr i8, ptr @.str_195, i64 16
    %v71 = getelementptr i8, ptr @.str_196, i64 16
    %v72 = getelementptr i8, ptr @.str_197, i64 16
    %v73 = getelementptr i8, ptr @.str_198, i64 16
    %v74 = getelementptr i8, ptr @.str_199, i64 16
    %v75 = getelementptr i8, ptr @.str_200, i64 16
    %v76 = getelementptr i8, ptr @.str_201, i64 16
    %v77 = getelementptr i8, ptr @.str_202, i64 16
    %v78 = getelementptr i8, ptr @.str_20, i64 16
    %v79 = getelementptr i8, ptr @.str_203, i64 16
    %v80 = getelementptr i8, ptr @.str_204, i64 16
    %v81 = getelementptr i8, ptr @.str_205, i64 16
    %v82 = getelementptr i8, ptr @.str_206, i64 16
    %v83 = getelementptr i8, ptr @.str_207, i64 16
    %v84 = call ptr @orion_list_new(i64 84)
    %v84.lp0 = ptrtoint ptr %v0 to i64
    call void @orion_list_set(ptr %v84, i64 0, i64 %v84.lp0)
    %v84.lp1 = ptrtoint ptr %v1 to i64
    call void @orion_list_set(ptr %v84, i64 1, i64 %v84.lp1)
    %v84.lp2 = ptrtoint ptr %v2 to i64
    call void @orion_list_set(ptr %v84, i64 2, i64 %v84.lp2)
    %v84.lp3 = ptrtoint ptr %v3 to i64
    call void @orion_list_set(ptr %v84, i64 3, i64 %v84.lp3)
    %v84.lp4 = ptrtoint ptr %v4 to i64
    call void @orion_list_set(ptr %v84, i64 4, i64 %v84.lp4)
    %v84.lp5 = ptrtoint ptr %v5 to i64
    call void @orion_list_set(ptr %v84, i64 5, i64 %v84.lp5)
    %v84.lp6 = ptrtoint ptr %v6 to i64
    call void @orion_list_set(ptr %v84, i64 6, i64 %v84.lp6)
    %v84.lp7 = ptrtoint ptr %v7 to i64
    call void @orion_list_set(ptr %v84, i64 7, i64 %v84.lp7)
    %v84.lp8 = ptrtoint ptr %v8 to i64
    call void @orion_list_set(ptr %v84, i64 8, i64 %v84.lp8)
    %v84.lp9 = ptrtoint ptr %v9 to i64
    call void @orion_list_set(ptr %v84, i64 9, i64 %v84.lp9)
    %v84.lp10 = ptrtoint ptr %v10 to i64
    call void @orion_list_set(ptr %v84, i64 10, i64 %v84.lp10)
    %v84.lp11 = ptrtoint ptr %v11 to i64
    call void @orion_list_set(ptr %v84, i64 11, i64 %v84.lp11)
    %v84.lp12 = ptrtoint ptr %v12 to i64
    call void @orion_list_set(ptr %v84, i64 12, i64 %v84.lp12)
    %v84.lp13 = ptrtoint ptr %v13 to i64
    call void @orion_list_set(ptr %v84, i64 13, i64 %v84.lp13)
    %v84.lp14 = ptrtoint ptr %v14 to i64
    call void @orion_list_set(ptr %v84, i64 14, i64 %v84.lp14)
    %v84.lp15 = ptrtoint ptr %v15 to i64
    call void @orion_list_set(ptr %v84, i64 15, i64 %v84.lp15)
    %v84.lp16 = ptrtoint ptr %v16 to i64
    call void @orion_list_set(ptr %v84, i64 16, i64 %v84.lp16)
    %v84.lp17 = ptrtoint ptr %v17 to i64
    call void @orion_list_set(ptr %v84, i64 17, i64 %v84.lp17)
    %v84.lp18 = ptrtoint ptr %v18 to i64
    call void @orion_list_set(ptr %v84, i64 18, i64 %v84.lp18)
    %v84.lp19 = ptrtoint ptr %v19 to i64
    call void @orion_list_set(ptr %v84, i64 19, i64 %v84.lp19)
    %v84.lp20 = ptrtoint ptr %v20 to i64
    call void @orion_list_set(ptr %v84, i64 20, i64 %v84.lp20)
    %v84.lp21 = ptrtoint ptr %v21 to i64
    call void @orion_list_set(ptr %v84, i64 21, i64 %v84.lp21)
    %v84.lp22 = ptrtoint ptr %v22 to i64
    call void @orion_list_set(ptr %v84, i64 22, i64 %v84.lp22)
    %v84.lp23 = ptrtoint ptr %v23 to i64
    call void @orion_list_set(ptr %v84, i64 23, i64 %v84.lp23)
    %v84.lp24 = ptrtoint ptr %v24 to i64
    call void @orion_list_set(ptr %v84, i64 24, i64 %v84.lp24)
    %v84.lp25 = ptrtoint ptr %v25 to i64
    call void @orion_list_set(ptr %v84, i64 25, i64 %v84.lp25)
    %v84.lp26 = ptrtoint ptr %v26 to i64
    call void @orion_list_set(ptr %v84, i64 26, i64 %v84.lp26)
    %v84.lp27 = ptrtoint ptr %v27 to i64
    call void @orion_list_set(ptr %v84, i64 27, i64 %v84.lp27)
    %v84.lp28 = ptrtoint ptr %v28 to i64
    call void @orion_list_set(ptr %v84, i64 28, i64 %v84.lp28)
    %v84.lp29 = ptrtoint ptr %v29 to i64
    call void @orion_list_set(ptr %v84, i64 29, i64 %v84.lp29)
    %v84.lp30 = ptrtoint ptr %v30 to i64
    call void @orion_list_set(ptr %v84, i64 30, i64 %v84.lp30)
    %v84.lp31 = ptrtoint ptr %v31 to i64
    call void @orion_list_set(ptr %v84, i64 31, i64 %v84.lp31)
    %v84.lp32 = ptrtoint ptr %v32 to i64
    call void @orion_list_set(ptr %v84, i64 32, i64 %v84.lp32)
    %v84.lp33 = ptrtoint ptr %v33 to i64
    call void @orion_list_set(ptr %v84, i64 33, i64 %v84.lp33)
    %v84.lp34 = ptrtoint ptr %v34 to i64
    call void @orion_list_set(ptr %v84, i64 34, i64 %v84.lp34)
    %v84.lp35 = ptrtoint ptr %v35 to i64
    call void @orion_list_set(ptr %v84, i64 35, i64 %v84.lp35)
    %v84.lp36 = ptrtoint ptr %v36 to i64
    call void @orion_list_set(ptr %v84, i64 36, i64 %v84.lp36)
    %v84.lp37 = ptrtoint ptr %v37 to i64
    call void @orion_list_set(ptr %v84, i64 37, i64 %v84.lp37)
    %v84.lp38 = ptrtoint ptr %v38 to i64
    call void @orion_list_set(ptr %v84, i64 38, i64 %v84.lp38)
    %v84.lp39 = ptrtoint ptr %v39 to i64
    call void @orion_list_set(ptr %v84, i64 39, i64 %v84.lp39)
    %v84.lp40 = ptrtoint ptr %v40 to i64
    call void @orion_list_set(ptr %v84, i64 40, i64 %v84.lp40)
    %v84.lp41 = ptrtoint ptr %v41 to i64
    call void @orion_list_set(ptr %v84, i64 41, i64 %v84.lp41)
    %v84.lp42 = ptrtoint ptr %v42 to i64
    call void @orion_list_set(ptr %v84, i64 42, i64 %v84.lp42)
    %v84.lp43 = ptrtoint ptr %v43 to i64
    call void @orion_list_set(ptr %v84, i64 43, i64 %v84.lp43)
    %v84.lp44 = ptrtoint ptr %v44 to i64
    call void @orion_list_set(ptr %v84, i64 44, i64 %v84.lp44)
    %v84.lp45 = ptrtoint ptr %v45 to i64
    call void @orion_list_set(ptr %v84, i64 45, i64 %v84.lp45)
    %v84.lp46 = ptrtoint ptr %v46 to i64
    call void @orion_list_set(ptr %v84, i64 46, i64 %v84.lp46)
    %v84.lp47 = ptrtoint ptr %v47 to i64
    call void @orion_list_set(ptr %v84, i64 47, i64 %v84.lp47)
    %v84.lp48 = ptrtoint ptr %v48 to i64
    call void @orion_list_set(ptr %v84, i64 48, i64 %v84.lp48)
    %v84.lp49 = ptrtoint ptr %v49 to i64
    call void @orion_list_set(ptr %v84, i64 49, i64 %v84.lp49)
    %v84.lp50 = ptrtoint ptr %v50 to i64
    call void @orion_list_set(ptr %v84, i64 50, i64 %v84.lp50)
    %v84.lp51 = ptrtoint ptr %v51 to i64
    call void @orion_list_set(ptr %v84, i64 51, i64 %v84.lp51)
    %v84.lp52 = ptrtoint ptr %v52 to i64
    call void @orion_list_set(ptr %v84, i64 52, i64 %v84.lp52)
    %v84.lp53 = ptrtoint ptr %v53 to i64
    call void @orion_list_set(ptr %v84, i64 53, i64 %v84.lp53)
    %v84.lp54 = ptrtoint ptr %v54 to i64
    call void @orion_list_set(ptr %v84, i64 54, i64 %v84.lp54)
    %v84.lp55 = ptrtoint ptr %v55 to i64
    call void @orion_list_set(ptr %v84, i64 55, i64 %v84.lp55)
    %v84.lp56 = ptrtoint ptr %v56 to i64
    call void @orion_list_set(ptr %v84, i64 56, i64 %v84.lp56)
    %v84.lp57 = ptrtoint ptr %v57 to i64
    call void @orion_list_set(ptr %v84, i64 57, i64 %v84.lp57)
    %v84.lp58 = ptrtoint ptr %v58 to i64
    call void @orion_list_set(ptr %v84, i64 58, i64 %v84.lp58)
    %v84.lp59 = ptrtoint ptr %v59 to i64
    call void @orion_list_set(ptr %v84, i64 59, i64 %v84.lp59)
    %v84.lp60 = ptrtoint ptr %v60 to i64
    call void @orion_list_set(ptr %v84, i64 60, i64 %v84.lp60)
    %v84.lp61 = ptrtoint ptr %v61 to i64
    call void @orion_list_set(ptr %v84, i64 61, i64 %v84.lp61)
    %v84.lp62 = ptrtoint ptr %v62 to i64
    call void @orion_list_set(ptr %v84, i64 62, i64 %v84.lp62)
    %v84.lp63 = ptrtoint ptr %v63 to i64
    call void @orion_list_set(ptr %v84, i64 63, i64 %v84.lp63)
    %v84.lp64 = ptrtoint ptr %v64 to i64
    call void @orion_list_set(ptr %v84, i64 64, i64 %v84.lp64)
    %v84.lp65 = ptrtoint ptr %v65 to i64
    call void @orion_list_set(ptr %v84, i64 65, i64 %v84.lp65)
    %v84.lp66 = ptrtoint ptr %v66 to i64
    call void @orion_list_set(ptr %v84, i64 66, i64 %v84.lp66)
    %v84.lp67 = ptrtoint ptr %v67 to i64
    call void @orion_list_set(ptr %v84, i64 67, i64 %v84.lp67)
    %v84.lp68 = ptrtoint ptr %v68 to i64
    call void @orion_list_set(ptr %v84, i64 68, i64 %v84.lp68)
    %v84.lp69 = ptrtoint ptr %v69 to i64
    call void @orion_list_set(ptr %v84, i64 69, i64 %v84.lp69)
    %v84.lp70 = ptrtoint ptr %v70 to i64
    call void @orion_list_set(ptr %v84, i64 70, i64 %v84.lp70)
    %v84.lp71 = ptrtoint ptr %v71 to i64
    call void @orion_list_set(ptr %v84, i64 71, i64 %v84.lp71)
    %v84.lp72 = ptrtoint ptr %v72 to i64
    call void @orion_list_set(ptr %v84, i64 72, i64 %v84.lp72)
    %v84.lp73 = ptrtoint ptr %v73 to i64
    call void @orion_list_set(ptr %v84, i64 73, i64 %v84.lp73)
    %v84.lp74 = ptrtoint ptr %v74 to i64
    call void @orion_list_set(ptr %v84, i64 74, i64 %v84.lp74)
    %v84.lp75 = ptrtoint ptr %v75 to i64
    call void @orion_list_set(ptr %v84, i64 75, i64 %v84.lp75)
    %v84.lp76 = ptrtoint ptr %v76 to i64
    call void @orion_list_set(ptr %v84, i64 76, i64 %v84.lp76)
    %v84.lp77 = ptrtoint ptr %v77 to i64
    call void @orion_list_set(ptr %v84, i64 77, i64 %v84.lp77)
    %v84.lp78 = ptrtoint ptr %v78 to i64
    call void @orion_list_set(ptr %v84, i64 78, i64 %v84.lp78)
    %v84.lp79 = ptrtoint ptr %v79 to i64
    call void @orion_list_set(ptr %v84, i64 79, i64 %v84.lp79)
    %v84.lp80 = ptrtoint ptr %v80 to i64
    call void @orion_list_set(ptr %v84, i64 80, i64 %v84.lp80)
    %v84.lp81 = ptrtoint ptr %v81 to i64
    call void @orion_list_set(ptr %v84, i64 81, i64 %v84.lp81)
    %v84.lp82 = ptrtoint ptr %v82 to i64
    call void @orion_list_set(ptr %v84, i64 82, i64 %v84.lp82)
    %v84.lp83 = ptrtoint ptr %v83 to i64
    call void @orion_list_set(ptr %v84, i64 83, i64 %v84.lp83)
    ret ptr %v84
}

define ptr @prog__slx_keyword_kind(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = call ptr @prog__slx_keyword_table()
    %v2 = call i64 @orion_list_len(ptr %v1)
    %v3 = getelementptr i8, ptr @.str_123, i64 16
    %v4 = alloca ptr, align 8
    store ptr %v3, ptr %v4
    %v5 = add i64 0, 0
    %v6 = add i64 0, 0
    %v7 = alloca i64, align 8
    store i64 %v6, ptr %v7
    %v8 = add i64 0, 0
    br label %loop_9_header
loop_9_header:
    %v11 = load i64, ptr %v7
    %v12.b = icmp sge i64 %v11, %v2
    %v12 = zext i1 %v12.b to i64
    %v13.cb = icmp ne i64 %v12, 0
    br i1 %v13.cb, label %if_13_then, label %if_13_else
if_13_then:
    br label %loop_9_end
if_13_else:
    br label %if_13_merge
if_13_merge:
    %v19 = load i64, ptr %v7
    %v20.i = call i64 @orion_list_at(ptr %v1, i64 %v19)
    %v20 = inttoptr i64 %v20.i to ptr
    %v21.e = call i64 @orion_text_eq(ptr %v20, ptr %v0)
    %v21 = add i64 %v21.e, 0
    %v22.cb = icmp ne i64 %v21, 0
    br i1 %v22.cb, label %if_22_then, label %if_22_else
if_22_then:
    %v24 = load i64, ptr %v7
    %v25 = add i64 0, 1
    %v26 = add i64 %v24, %v25
    %v27.i = call i64 @orion_list_at(ptr %v1, i64 %v26)
    %v27 = inttoptr i64 %v27.i to ptr
    store ptr %v27, ptr %v4
    %v28 = add i64 0, 0
    br label %if_22_merge
if_22_else:
    br label %if_22_merge
if_22_merge:
    %v33 = load i64, ptr %v7
    %v34 = add i64 0, 2
    %v35 = add i64 %v33, %v34
    store i64 %v35, ptr %v7
    %v36 = add i64 0, 0
    br label %loop_9_header
loop_9_end:
    %v39 = load ptr, ptr %v4
    ret ptr %v39
}

define ptr @prog__slx_scan_number(ptr %p0, i64 %p1, i64 %p2, i64 %p3, i64 %p4) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = add i64 0, %p3
    %v4 = add i64 0, %p4
    %v5 = alloca i64, align 8
    store i64 %v1, ptr %v5
    %v6 = add i64 0, 0
    %v7 = add i64 0, 0
    %v8 = alloca i64, align 8
    store i64 %v7, ptr %v8
    %v9 = add i64 0, 0
    br label %loop_10_header
loop_10_header:
    %v12 = load i64, ptr %v5
    %v13.b = icmp sge i64 %v12, %v2
    %v13 = zext i1 %v13.b to i64
    %v14.cb = icmp ne i64 %v13, 0
    br i1 %v14.cb, label %if_14_then, label %if_14_else
if_14_then:
    br label %loop_10_end
if_14_else:
    br label %if_14_merge
if_14_merge:
    %v20 = load i64, ptr %v5
    %v21 = call i64 @orion_list_at(ptr %v0, i64 %v20)
    %v22 = call i64 @prog__slx_is_digit(i64 %v21)
    %v23.cb = icmp ne i64 %v22, 0
    br i1 %v23.cb, label %if_23_then, label %if_23_else
if_23_then:
    %v25 = load i64, ptr %v5
    %v26 = add i64 0, 1
    %v27 = add i64 %v25, %v26
    store i64 %v27, ptr %v5
    %v28 = add i64 0, 0
    br label %if_23_merge
if_23_else:
    %v31 = add i64 0, 46
    %v32.b = icmp eq i64 %v21, %v31
    %v32 = zext i1 %v32.b to i64
    %v33.cb = icmp ne i64 %v32, 0
    br i1 %v33.cb, label %if_33_then, label %if_33_else
if_33_then:
    %v35 = load i64, ptr %v8
    %v36.n = icmp eq i64 %v35, 0
    %v36 = zext i1 %v36.n to i64
    br label %if_33_merge
if_33_else:
    %v39 = add i64 0, 0
    br label %if_33_merge
if_33_merge:
    %v42 = phi i64 [ %v36, %if_33_then ], [ %v39, %if_33_else ]
    %v43.cb = icmp ne i64 %v42, 0
    br i1 %v43.cb, label %if_43_then, label %if_43_else
if_43_then:
    %v45 = load i64, ptr %v5
    %v46 = add i64 0, 1
    %v47 = add i64 %v45, %v46
    %v48.b = icmp slt i64 %v47, %v2
    %v48 = zext i1 %v48.b to i64
    br label %if_43_merge
if_43_else:
    %v51 = add i64 0, 0
    br label %if_43_merge
if_43_merge:
    %v54 = phi i64 [ %v48, %if_43_then ], [ %v51, %if_43_else ]
    %v55.cb = icmp ne i64 %v54, 0
    br i1 %v55.cb, label %if_55_then, label %if_55_else
if_55_then:
    %v57 = load i64, ptr %v5
    %v58 = add i64 0, 1
    %v59 = add i64 %v57, %v58
    %v60 = call i64 @orion_list_at(ptr %v0, i64 %v59)
    %v61 = call i64 @prog__slx_is_digit(i64 %v60)
    br label %if_55_merge
if_55_else:
    %v64 = add i64 0, 0
    br label %if_55_merge
if_55_merge:
    %v67 = phi i64 [ %v61, %if_55_then ], [ %v64, %if_55_else ]
    %v68.cb = icmp ne i64 %v67, 0
    br i1 %v68.cb, label %if_68_then, label %if_68_else
if_68_then:
    %v70 = add i64 0, 1
    store i64 %v70, ptr %v8
    %v71 = add i64 0, 0
    %v72 = load i64, ptr %v5
    %v73 = add i64 0, 1
    %v74 = add i64 %v72, %v73
    store i64 %v74, ptr %v5
    %v75 = add i64 0, 0
    br label %if_68_merge
if_68_else:
    br label %loop_10_end
if_68_merge:
    br label %if_23_merge
if_23_merge:
    %v82 = phi i64 [ %v28, %if_23_then ], [ %v75, %if_68_merge ]
    br label %loop_10_header
loop_10_end:
    %v85 = load i64, ptr %v5
    %v86 = call ptr @orion_bytes_slice(ptr %v0, i64 %v1, i64 %v85)
    %v87 = call ptr @orion_bytes_to_text(ptr %v86)
    %v88 = load i64, ptr %v8
    %v89.cb = icmp ne i64 %v88, 0
    br i1 %v89.cb, label %if_89_then, label %if_89_else
if_89_then:
    %v91 = getelementptr i8, ptr @.str_208, i64 16
    br label %if_89_merge
if_89_else:
    %v94 = getelementptr i8, ptr @.str_209, i64 16
    br label %if_89_merge
if_89_merge:
    %v97 = phi ptr [ %v91, %if_89_then ], [ %v94, %if_89_else ]
    %v98 = getelementptr i8, ptr @.str_122, i64 16
    %v99 = call ptr @prog__slx_make_token(ptr %v97, ptr %v87, i64 %v3, i64 %v4)
    %v100 = getelementptr i8, ptr @.str_124, i64 16
    %v101 = load i64, ptr %v5
    %v102 = call ptr @orion_map_new(i64 2)
    %v102.p0 = ptrtoint ptr %v99 to i64
    call void @orion_map_set(ptr %v102, ptr %v98, i64 %v102.p0)
    call void @orion_map_set(ptr %v102, ptr %v100, i64 %v101)
    ret ptr %v102
}

define i64 @prog__slx_resolve_escape(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, 0
    %v2 = add i64 0, 1
    %v3 = sub i64 %v1, %v2
    %v4 = alloca i64, align 8
    store i64 %v3, ptr %v4
    %v5 = add i64 0, 0
    %v6 = add i64 0, 34
    %v7.b = icmp eq i64 %v0, %v6
    %v7 = zext i1 %v7.b to i64
    %v8.cb = icmp ne i64 %v7, 0
    br i1 %v8.cb, label %if_8_then, label %if_8_else
if_8_then:
    %v10 = add i64 0, 34
    store i64 %v10, ptr %v4
    %v11 = add i64 0, 0
    br label %if_8_merge
if_8_else:
    br label %if_8_merge
if_8_merge:
    %v16 = add i64 0, 92
    %v17.b = icmp eq i64 %v0, %v16
    %v17 = zext i1 %v17.b to i64
    %v18.cb = icmp ne i64 %v17, 0
    br i1 %v18.cb, label %if_18_then, label %if_18_else
if_18_then:
    %v20 = add i64 0, 92
    store i64 %v20, ptr %v4
    %v21 = add i64 0, 0
    br label %if_18_merge
if_18_else:
    br label %if_18_merge
if_18_merge:
    %v26 = add i64 0, 110
    %v27.b = icmp eq i64 %v0, %v26
    %v27 = zext i1 %v27.b to i64
    %v28.cb = icmp ne i64 %v27, 0
    br i1 %v28.cb, label %if_28_then, label %if_28_else
if_28_then:
    %v30 = add i64 0, 10
    store i64 %v30, ptr %v4
    %v31 = add i64 0, 0
    br label %if_28_merge
if_28_else:
    br label %if_28_merge
if_28_merge:
    %v36 = add i64 0, 114
    %v37.b = icmp eq i64 %v0, %v36
    %v37 = zext i1 %v37.b to i64
    %v38.cb = icmp ne i64 %v37, 0
    br i1 %v38.cb, label %if_38_then, label %if_38_else
if_38_then:
    %v40 = add i64 0, 13
    store i64 %v40, ptr %v4
    %v41 = add i64 0, 0
    br label %if_38_merge
if_38_else:
    br label %if_38_merge
if_38_merge:
    %v46 = add i64 0, 116
    %v47.b = icmp eq i64 %v0, %v46
    %v47 = zext i1 %v47.b to i64
    %v48.cb = icmp ne i64 %v47, 0
    br i1 %v48.cb, label %if_48_then, label %if_48_else
if_48_then:
    %v50 = add i64 0, 9
    store i64 %v50, ptr %v4
    %v51 = add i64 0, 0
    br label %if_48_merge
if_48_else:
    br label %if_48_merge
if_48_merge:
    %v56 = add i64 0, 48
    %v57.b = icmp eq i64 %v0, %v56
    %v57 = zext i1 %v57.b to i64
    %v58.cb = icmp ne i64 %v57, 0
    br i1 %v58.cb, label %if_58_then, label %if_58_else
if_58_then:
    %v60 = add i64 0, 0
    store i64 %v60, ptr %v4
    %v61 = add i64 0, 0
    br label %if_58_merge
if_58_else:
    br label %if_58_merge
if_58_merge:
    %v66 = add i64 0, 39
    %v67.b = icmp eq i64 %v0, %v66
    %v67 = zext i1 %v67.b to i64
    %v68.cb = icmp ne i64 %v67, 0
    br i1 %v68.cb, label %if_68_then, label %if_68_else
if_68_then:
    %v70 = add i64 0, 39
    store i64 %v70, ptr %v4
    %v71 = add i64 0, 0
    br label %if_68_merge
if_68_else:
    br label %if_68_merge
if_68_merge:
    %v76 = load i64, ptr %v4
    ret i64 %v76
}

define ptr @prog__slx_int_to_text(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, 0
    %v2.b = icmp eq i64 %v0, %v1
    %v2 = zext i1 %v2.b to i64
    %v3.cb = icmp ne i64 %v2, 0
    br i1 %v3.cb, label %if_3_then, label %if_3_else
if_3_then:
    %v5 = getelementptr i8, ptr @.str_210, i64 16
    ret ptr %v5
if_3_else:
    br label %if_3_merge
if_3_merge:
    %v10 = add i64 0, 0
    %v11 = call ptr @orion_bytes_zeros(i64 %v10)
    %v12 = alloca ptr, align 8
    store ptr %v11, ptr %v12
    %v13 = add i64 0, 0
    %v14 = alloca i64, align 8
    store i64 %v0, ptr %v14
    %v15 = add i64 0, 0
    br label %loop_16_header
loop_16_header:
    %v18 = load i64, ptr %v14
    %v19 = add i64 0, 0
    %v20.b = icmp sle i64 %v18, %v19
    %v20 = zext i1 %v20.b to i64
    %v21.cb = icmp ne i64 %v20, 0
    br i1 %v21.cb, label %if_21_then, label %if_21_else
if_21_then:
    br label %loop_16_end
if_21_else:
    br label %if_21_merge
if_21_merge:
    %v27 = load ptr, ptr %v12
    %v28 = add i64 0, 48
    %v29 = load i64, ptr %v14
    %v30 = add i64 0, 10
    %v31 = call i64 @orion_imod(i64 %v29, i64 %v30)
    %v32 = add i64 %v28, %v31
    %v33 = call ptr @orion_list_push(ptr %v27, i64 %v32)
    store ptr %v33, ptr %v12
    %v34 = add i64 0, 0
    %v35 = load i64, ptr %v14
    %v36 = add i64 0, 10
    %v37 = call i64 @orion_idiv(i64 %v35, i64 %v36)
    store i64 %v37, ptr %v14
    %v38 = add i64 0, 0
    br label %loop_16_header
loop_16_end:
    %v41 = add i64 0, 0
    %v42 = call ptr @orion_bytes_zeros(i64 %v41)
    %v43 = alloca ptr, align 8
    store ptr %v42, ptr %v43
    %v44 = add i64 0, 0
    %v45 = load ptr, ptr %v12
    %v46 = call i64 @orion_list_len(ptr %v45)
    %v47 = add i64 0, 1
    %v48 = sub i64 %v46, %v47
    %v49 = alloca i64, align 8
    store i64 %v48, ptr %v49
    %v50 = add i64 0, 0
    br label %loop_51_header
loop_51_header:
    %v53 = load i64, ptr %v49
    %v54 = add i64 0, 0
    %v55.b = icmp slt i64 %v53, %v54
    %v55 = zext i1 %v55.b to i64
    %v56.cb = icmp ne i64 %v55, 0
    br i1 %v56.cb, label %if_56_then, label %if_56_else
if_56_then:
    br label %loop_51_end
if_56_else:
    br label %if_56_merge
if_56_merge:
    %v62 = load ptr, ptr %v43
    %v63 = load ptr, ptr %v12
    %v64 = load i64, ptr %v49
    %v65 = call i64 @orion_list_at(ptr %v63, i64 %v64)
    %v66 = call ptr @orion_list_push(ptr %v62, i64 %v65)
    store ptr %v66, ptr %v43
    %v67 = add i64 0, 0
    %v68 = load i64, ptr %v49
    %v69 = add i64 0, 1
    %v70 = sub i64 %v68, %v69
    store i64 %v70, ptr %v49
    %v71 = add i64 0, 0
    br label %loop_51_header
loop_51_end:
    %v74 = load ptr, ptr %v43
    %v75 = call ptr @orion_bytes_to_text(ptr %v74)
    ret ptr %v75
}

define ptr @prog__slx_scan_char(ptr %p0, i64 %p1, i64 %p2, i64 %p3, i64 %p4) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = add i64 0, %p3
    %v4 = add i64 0, %p4
    %v5 = add i64 0, 1
    %v6 = add i64 %v1, %v5
    %v7 = alloca i64, align 8
    store i64 %v6, ptr %v7
    %v8 = add i64 0, 0
    %v9 = add i64 0, 0
    %v10 = alloca i64, align 8
    store i64 %v9, ptr %v10
    %v11 = add i64 0, 0
    %v12 = add i64 0, 0
    %v13 = alloca i64, align 8
    store i64 %v12, ptr %v13
    %v14 = add i64 0, 0
    %v15 = load i64, ptr %v7
    %v16.b = icmp slt i64 %v15, %v2
    %v16 = zext i1 %v16.b to i64
    %v17.cb = icmp ne i64 %v16, 0
    br i1 %v17.cb, label %if_17_then, label %if_17_else
if_17_then:
    %v19 = load i64, ptr %v7
    %v20 = call i64 @orion_list_at(ptr %v0, i64 %v19)
    %v21 = add i64 0, 92
    %v22.b = icmp eq i64 %v20, %v21
    %v22 = zext i1 %v22.b to i64
    %v23.cb = icmp ne i64 %v22, 0
    br i1 %v23.cb, label %if_23_then, label %if_23_else
if_23_then:
    %v25 = load i64, ptr %v7
    %v26 = add i64 0, 1
    %v27 = add i64 %v25, %v26
    %v28.b = icmp slt i64 %v27, %v2
    %v28 = zext i1 %v28.b to i64
    br label %if_23_merge
if_23_else:
    %v31 = add i64 0, 0
    br label %if_23_merge
if_23_merge:
    %v34 = phi i64 [ %v28, %if_23_then ], [ %v31, %if_23_else ]
    %v35.cb = icmp ne i64 %v34, 0
    br i1 %v35.cb, label %if_35_then, label %if_35_else
if_35_then:
    %v37 = load i64, ptr %v7
    %v38 = add i64 0, 1
    %v39 = add i64 %v37, %v38
    %v40 = call i64 @orion_list_at(ptr %v0, i64 %v39)
    %v41 = call i64 @prog__slx_resolve_escape(i64 %v40)
    %v42 = add i64 0, 0
    %v43.b = icmp sge i64 %v41, %v42
    %v43 = zext i1 %v43.b to i64
    %v44.cb = icmp ne i64 %v43, 0
    br i1 %v44.cb, label %if_44_then, label %if_44_else
if_44_then:
    store i64 %v41, ptr %v10
    %v46 = add i64 0, 0
    %v47 = load i64, ptr %v7
    %v48 = add i64 0, 2
    %v49 = add i64 %v47, %v48
    store i64 %v49, ptr %v7
    %v50 = add i64 0, 0
    %v51 = add i64 0, 1
    store i64 %v51, ptr %v13
    %v52 = add i64 0, 0
    br label %if_44_merge
if_44_else:
    br label %if_44_merge
if_44_merge:
    br label %if_35_merge
if_35_else:
    %v59 = add i64 0, 39
    %v60.b = icmp ne i64 %v20, %v59
    %v60 = zext i1 %v60.b to i64
    %v61.cb = icmp ne i64 %v60, 0
    br i1 %v61.cb, label %if_61_then, label %if_61_else
if_61_then:
    store i64 %v20, ptr %v10
    %v63 = add i64 0, 0
    %v64 = load i64, ptr %v7
    %v65 = add i64 0, 1
    %v66 = add i64 %v64, %v65
    store i64 %v66, ptr %v7
    %v67 = add i64 0, 0
    %v68 = add i64 0, 1
    store i64 %v68, ptr %v13
    %v69 = add i64 0, 0
    br label %if_61_merge
if_61_else:
    br label %if_61_merge
if_61_merge:
    br label %if_35_merge
if_35_merge:
    br label %if_17_merge
if_17_else:
    br label %if_17_merge
if_17_merge:
    %v80 = load i64, ptr %v13
    %v81.cb = icmp ne i64 %v80, 0
    br i1 %v81.cb, label %if_81_then, label %if_81_else
if_81_then:
    %v83 = load i64, ptr %v7
    %v84.b = icmp slt i64 %v83, %v2
    %v84 = zext i1 %v84.b to i64
    br label %if_81_merge
if_81_else:
    %v87 = add i64 0, 0
    br label %if_81_merge
if_81_merge:
    %v90 = phi i64 [ %v84, %if_81_then ], [ %v87, %if_81_else ]
    %v91.cb = icmp ne i64 %v90, 0
    br i1 %v91.cb, label %if_91_then, label %if_91_else
if_91_then:
    %v93 = load i64, ptr %v7
    %v94 = call i64 @orion_list_at(ptr %v0, i64 %v93)
    %v95 = add i64 0, 39
    %v96.b = icmp eq i64 %v94, %v95
    %v96 = zext i1 %v96.b to i64
    br label %if_91_merge
if_91_else:
    %v99 = add i64 0, 0
    br label %if_91_merge
if_91_merge:
    %v102 = phi i64 [ %v96, %if_91_then ], [ %v99, %if_91_else ]
    %v103.cb = icmp ne i64 %v102, 0
    br i1 %v103.cb, label %if_103_then, label %if_103_else
if_103_then:
    %v105 = load i64, ptr %v7
    %v106 = add i64 0, 1
    %v107 = add i64 %v105, %v106
    store i64 %v107, ptr %v7
    %v108 = add i64 0, 0
    %v109 = getelementptr i8, ptr @.str_122, i64 16
    %v110 = getelementptr i8, ptr @.str_209, i64 16
    %v111 = load i64, ptr %v10
    %v112 = call ptr @prog__slx_int_to_text(i64 %v111)
    %v113 = call ptr @prog__slx_make_token(ptr %v110, ptr %v112, i64 %v3, i64 %v4)
    %v114 = getelementptr i8, ptr @.str_124, i64 16
    %v115 = load i64, ptr %v7
    %v116 = call ptr @orion_map_new(i64 2)
    %v116.p0 = ptrtoint ptr %v113 to i64
    call void @orion_map_set(ptr %v116, ptr %v109, i64 %v116.p0)
    call void @orion_map_set(ptr %v116, ptr %v114, i64 %v115)
    br label %if_103_merge
if_103_else:
    %v119 = getelementptr i8, ptr @.str_122, i64 16
    %v120 = getelementptr i8, ptr @.str_211, i64 16
    %v121 = getelementptr i8, ptr @.str_116, i64 16
    %v122 = call ptr @prog__slx_make_token(ptr %v120, ptr %v121, i64 %v3, i64 %v4)
    %v123 = getelementptr i8, ptr @.str_124, i64 16
    %v124 = add i64 0, 1
    %v125 = add i64 %v1, %v124
    %v126 = call ptr @orion_map_new(i64 2)
    %v126.p0 = ptrtoint ptr %v122 to i64
    call void @orion_map_set(ptr %v126, ptr %v119, i64 %v126.p0)
    call void @orion_map_set(ptr %v126, ptr %v123, i64 %v125)
    br label %if_103_merge
if_103_merge:
    %v129 = phi ptr [ %v116, %if_103_then ], [ %v126, %if_103_else ]
    ret ptr %v129
}

define ptr @prog__slx_scan_string(ptr %p0, i64 %p1, i64 %p2, i64 %p3, i64 %p4) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = add i64 0, %p3
    %v4 = add i64 0, %p4
    %v5 = add i64 0, 1
    %v6 = add i64 %v1, %v5
    %v7 = alloca i64, align 8
    store i64 %v6, ptr %v7
    %v8 = add i64 0, 0
    %v9 = add i64 0, 0
    %v10 = call ptr @orion_bytes_zeros(i64 %v9)
    %v11 = alloca ptr, align 8
    store ptr %v10, ptr %v11
    %v12 = add i64 0, 0
    %v13 = add i64 0, 0
    %v14 = alloca i64, align 8
    store i64 %v13, ptr %v14
    %v15 = add i64 0, 0
    %v16 = add i64 0, 0
    %v17 = alloca i64, align 8
    store i64 %v16, ptr %v17
    %v18 = add i64 0, 0
    br label %loop_19_header
loop_19_header:
    %v21 = load i64, ptr %v7
    %v22.b = icmp sge i64 %v21, %v2
    %v22 = zext i1 %v22.b to i64
    %v23.cb = icmp ne i64 %v22, 0
    br i1 %v23.cb, label %if_23_then, label %if_23_else
if_23_then:
    br label %loop_19_end
if_23_else:
    br label %if_23_merge
if_23_merge:
    %v29 = load i64, ptr %v7
    %v30 = call i64 @orion_list_at(ptr %v0, i64 %v29)
    %v31 = add i64 0, 34
    %v32.b = icmp eq i64 %v30, %v31
    %v32 = zext i1 %v32.b to i64
    %v33.cb = icmp ne i64 %v32, 0
    br i1 %v33.cb, label %if_33_then, label %if_33_else
if_33_then:
    %v35 = load i64, ptr %v17
    %v36 = add i64 0, 0
    %v37.b = icmp eq i64 %v35, %v36
    %v37 = zext i1 %v37.b to i64
    br label %if_33_merge
if_33_else:
    %v40 = add i64 0, 0
    br label %if_33_merge
if_33_merge:
    %v43 = phi i64 [ %v37, %if_33_then ], [ %v40, %if_33_else ]
    %v44.cb = icmp ne i64 %v43, 0
    br i1 %v44.cb, label %if_44_then, label %if_44_else
if_44_then:
    %v46 = add i64 0, 1
    store i64 %v46, ptr %v14
    %v47 = add i64 0, 0
    %v48 = load i64, ptr %v7
    %v49 = add i64 0, 1
    %v50 = add i64 %v48, %v49
    store i64 %v50, ptr %v7
    %v51 = add i64 0, 0
    br label %loop_19_end
if_44_else:
    br label %if_44_merge
if_44_merge:
    %v56 = add i64 0, 10
    %v57.b = icmp eq i64 %v30, %v56
    %v57 = zext i1 %v57.b to i64
    %v58.cb = icmp ne i64 %v57, 0
    br i1 %v58.cb, label %if_58_then, label %if_58_else
if_58_then:
    br label %loop_19_end
if_58_else:
    br label %if_58_merge
if_58_merge:
    %v64 = add i64 0, 92
    %v65.b = icmp eq i64 %v30, %v64
    %v65 = zext i1 %v65.b to i64
    %v66.cb = icmp ne i64 %v65, 0
    br i1 %v66.cb, label %if_66_then, label %if_66_else
if_66_then:
    %v68 = load i64, ptr %v7
    %v69 = add i64 0, 1
    %v70 = add i64 %v68, %v69
    %v71.b = icmp slt i64 %v70, %v2
    %v71 = zext i1 %v71.b to i64
    br label %if_66_merge
if_66_else:
    %v74 = add i64 0, 0
    br label %if_66_merge
if_66_merge:
    %v77 = phi i64 [ %v71, %if_66_then ], [ %v74, %if_66_else ]
    %v78.cb = icmp ne i64 %v77, 0
    br i1 %v78.cb, label %if_78_then, label %if_78_else
if_78_then:
    %v80 = load i64, ptr %v7
    %v81 = add i64 0, 1
    %v82 = add i64 %v80, %v81
    %v83 = call i64 @orion_list_at(ptr %v0, i64 %v82)
    %v84 = call i64 @prog__slx_resolve_escape(i64 %v83)
    %v85 = add i64 0, 0
    %v86.b = icmp sge i64 %v84, %v85
    %v86 = zext i1 %v86.b to i64
    %v87.cb = icmp ne i64 %v86, 0
    br i1 %v87.cb, label %if_87_then, label %if_87_else
if_87_then:
    %v89 = load ptr, ptr %v11
    %v90 = call ptr @orion_list_push(ptr %v89, i64 %v84)
    store ptr %v90, ptr %v11
    %v91 = add i64 0, 0
    %v92 = load i64, ptr %v7
    %v93 = add i64 0, 2
    %v94 = add i64 %v92, %v93
    store i64 %v94, ptr %v7
    %v95 = add i64 0, 0
    br label %if_87_merge
if_87_else:
    %v98 = load ptr, ptr %v11
    %v99 = add i64 0, 92
    %v100 = call ptr @orion_list_push(ptr %v98, i64 %v99)
    store ptr %v100, ptr %v11
    %v101 = add i64 0, 0
    %v102 = load ptr, ptr %v11
    %v103 = call ptr @orion_list_push(ptr %v102, i64 %v83)
    store ptr %v103, ptr %v11
    %v104 = add i64 0, 0
    %v105 = load i64, ptr %v7
    %v106 = add i64 0, 2
    %v107 = add i64 %v105, %v106
    store i64 %v107, ptr %v7
    %v108 = add i64 0, 0
    br label %if_87_merge
if_87_merge:
    %v111 = phi i64 [ %v95, %if_87_then ], [ %v108, %if_87_else ]
    br label %if_78_merge
if_78_else:
    %v114 = add i64 0, 123
    %v115.b = icmp eq i64 %v30, %v114
    %v115 = zext i1 %v115.b to i64
    %v116.cb = icmp ne i64 %v115, 0
    br i1 %v116.cb, label %if_116_then, label %if_116_else
if_116_then:
    %v118 = load i64, ptr %v17
    %v119 = add i64 0, 1
    %v120 = add i64 %v118, %v119
    store i64 %v120, ptr %v17
    %v121 = add i64 0, 0
    br label %if_116_merge
if_116_else:
    br label %if_116_merge
if_116_merge:
    %v126 = add i64 0, 125
    %v127.b = icmp eq i64 %v30, %v126
    %v127 = zext i1 %v127.b to i64
    %v128.cb = icmp ne i64 %v127, 0
    br i1 %v128.cb, label %if_128_then, label %if_128_else
if_128_then:
    %v130 = load i64, ptr %v17
    %v131 = add i64 0, 0
    %v132.b = icmp sgt i64 %v130, %v131
    %v132 = zext i1 %v132.b to i64
    br label %if_128_merge
if_128_else:
    %v135 = add i64 0, 0
    br label %if_128_merge
if_128_merge:
    %v138 = phi i64 [ %v132, %if_128_then ], [ %v135, %if_128_else ]
    %v139.cb = icmp ne i64 %v138, 0
    br i1 %v139.cb, label %if_139_then, label %if_139_else
if_139_then:
    %v141 = load i64, ptr %v17
    %v142 = add i64 0, 1
    %v143 = sub i64 %v141, %v142
    store i64 %v143, ptr %v17
    %v144 = add i64 0, 0
    br label %if_139_merge
if_139_else:
    br label %if_139_merge
if_139_merge:
    %v149 = load ptr, ptr %v11
    %v150 = call ptr @orion_list_push(ptr %v149, i64 %v30)
    store ptr %v150, ptr %v11
    %v151 = add i64 0, 0
    %v152 = load i64, ptr %v7
    %v153 = add i64 0, 1
    %v154 = add i64 %v152, %v153
    store i64 %v154, ptr %v7
    %v155 = add i64 0, 0
    br label %if_78_merge
if_78_merge:
    %v158 = phi i64 [ %v111, %if_87_merge ], [ %v155, %if_139_merge ]
    br label %loop_19_header
loop_19_end:
    %v161 = load ptr, ptr %v11
    %v162 = call ptr @orion_bytes_to_text(ptr %v161)
    %v163 = getelementptr i8, ptr @.str_122, i64 16
    %v164 = getelementptr i8, ptr @.str_212, i64 16
    %v165 = call ptr @prog__slx_make_token(ptr %v164, ptr %v162, i64 %v3, i64 %v4)
    %v166 = getelementptr i8, ptr @.str_124, i64 16
    %v167 = load i64, ptr %v7
    %v168 = getelementptr i8, ptr @.str_213, i64 16
    %v169 = load i64, ptr %v14
    %v170 = call ptr @orion_map_new(i64 3)
    %v170.p0 = ptrtoint ptr %v165 to i64
    call void @orion_map_set(ptr %v170, ptr %v163, i64 %v170.p0)
    call void @orion_map_set(ptr %v170, ptr %v166, i64 %v167)
    call void @orion_map_set(ptr %v170, ptr %v168, i64 %v169)
    ret ptr %v170
}

define ptr @prog__slx_scan_op(ptr %p0, i64 %p1, i64 %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = call i64 @orion_list_at(ptr %v0, i64 %v1)
    %v4 = add i64 0, 0
    %v5 = alloca i64, align 8
    store i64 %v4, ptr %v5
    %v6 = add i64 0, 0
    %v7 = add i64 0, 1
    %v8 = add i64 %v1, %v7
    %v9.b = icmp slt i64 %v8, %v2
    %v9 = zext i1 %v9.b to i64
    %v10.cb = icmp ne i64 %v9, 0
    br i1 %v10.cb, label %if_10_then, label %if_10_else
if_10_then:
    %v12 = add i64 0, 1
    %v13 = add i64 %v1, %v12
    %v14 = call i64 @orion_list_at(ptr %v0, i64 %v13)
    store i64 %v14, ptr %v5
    %v15 = add i64 0, 0
    br label %if_10_merge
if_10_else:
    br label %if_10_merge
if_10_merge:
    %v20 = add i64 0, 0
    %v21 = alloca i64, align 8
    store i64 %v20, ptr %v21
    %v22 = add i64 0, 0
    %v23 = add i64 0, 2
    %v24 = add i64 %v1, %v23
    %v25.b = icmp slt i64 %v24, %v2
    %v25 = zext i1 %v25.b to i64
    %v26.cb = icmp ne i64 %v25, 0
    br i1 %v26.cb, label %if_26_then, label %if_26_else
if_26_then:
    %v28 = add i64 0, 2
    %v29 = add i64 %v1, %v28
    %v30 = call i64 @orion_list_at(ptr %v0, i64 %v29)
    store i64 %v30, ptr %v21
    %v31 = add i64 0, 0
    br label %if_26_merge
if_26_else:
    br label %if_26_merge
if_26_merge:
    %v36 = getelementptr i8, ptr @.str_5, i64 16
    %v37 = alloca ptr, align 8
    store ptr %v36, ptr %v37
    %v38 = add i64 0, 0
    %v39 = add i64 0, 46
    %v40.b = icmp eq i64 %v3, %v39
    %v40 = zext i1 %v40.b to i64
    %v41.cb = icmp ne i64 %v40, 0
    br i1 %v41.cb, label %if_41_then, label %if_41_else
if_41_then:
    %v43 = load i64, ptr %v5
    %v44 = add i64 0, 46
    %v45.b = icmp eq i64 %v43, %v44
    %v45 = zext i1 %v45.b to i64
    br label %if_41_merge
if_41_else:
    %v48 = add i64 0, 0
    br label %if_41_merge
if_41_merge:
    %v51 = phi i64 [ %v45, %if_41_then ], [ %v48, %if_41_else ]
    %v52.cb = icmp ne i64 %v51, 0
    br i1 %v52.cb, label %if_52_then, label %if_52_else
if_52_then:
    %v54 = load i64, ptr %v21
    %v55 = add i64 0, 60
    %v56.b = icmp eq i64 %v54, %v55
    %v56 = zext i1 %v56.b to i64
    br label %if_52_merge
if_52_else:
    %v59 = add i64 0, 0
    br label %if_52_merge
if_52_merge:
    %v62 = phi i64 [ %v56, %if_52_then ], [ %v59, %if_52_else ]
    %v63.cb = icmp ne i64 %v62, 0
    br i1 %v63.cb, label %if_63_then, label %if_63_else
if_63_then:
    %v65 = getelementptr i8, ptr @.str_214, i64 16
    store ptr %v65, ptr %v37
    %v66 = add i64 0, 0
    br label %if_63_merge
if_63_else:
    br label %if_63_merge
if_63_merge:
    %v71 = add i64 0, 46
    %v72.b = icmp eq i64 %v3, %v71
    %v72 = zext i1 %v72.b to i64
    %v73.cb = icmp ne i64 %v72, 0
    br i1 %v73.cb, label %if_73_then, label %if_73_else
if_73_then:
    %v75 = load i64, ptr %v5
    %v76 = add i64 0, 46
    %v77.b = icmp eq i64 %v75, %v76
    %v77 = zext i1 %v77.b to i64
    br label %if_73_merge
if_73_else:
    %v80 = add i64 0, 0
    br label %if_73_merge
if_73_merge:
    %v83 = phi i64 [ %v77, %if_73_then ], [ %v80, %if_73_else ]
    %v84.cb = icmp ne i64 %v83, 0
    br i1 %v84.cb, label %if_84_then, label %if_84_else
if_84_then:
    %v86 = load i64, ptr %v21
    %v87 = add i64 0, 61
    %v88.b = icmp eq i64 %v86, %v87
    %v88 = zext i1 %v88.b to i64
    br label %if_84_merge
if_84_else:
    %v91 = add i64 0, 0
    br label %if_84_merge
if_84_merge:
    %v94 = phi i64 [ %v88, %if_84_then ], [ %v91, %if_84_else ]
    %v95.cb = icmp ne i64 %v94, 0
    br i1 %v95.cb, label %if_95_then, label %if_95_else
if_95_then:
    %v97 = getelementptr i8, ptr @.str_215, i64 16
    store ptr %v97, ptr %v37
    %v98 = add i64 0, 0
    br label %if_95_merge
if_95_else:
    br label %if_95_merge
if_95_merge:
    %v103 = load ptr, ptr %v37
    %v104 = getelementptr i8, ptr @.str_5, i64 16
    %v105.e = call i64 @orion_text_eq(ptr %v103, ptr %v104)
    %v105 = add i64 %v105.e, 0
    %v106.cb = icmp ne i64 %v105, 0
    br i1 %v106.cb, label %if_106_then, label %if_106_else
if_106_then:
    %v108 = load i64, ptr %v5
    %v109 = call ptr @prog__slx_scan_op_short(i64 %v3, i64 %v108)
    store ptr %v109, ptr %v37
    %v110 = add i64 0, 0
    br label %if_106_merge
if_106_else:
    br label %if_106_merge
if_106_merge:
    %v115 = load ptr, ptr %v37
    ret ptr %v115
}

define ptr @prog__slx_scan_op_short(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_5, i64 16
    %v3 = alloca ptr, align 8
    store ptr %v2, ptr %v3
    %v4 = add i64 0, 0
    %v5 = add i64 0, 61
    %v6.b = icmp eq i64 %v0, %v5
    %v6 = zext i1 %v6.b to i64
    %v7.cb = icmp ne i64 %v6, 0
    br i1 %v7.cb, label %if_7_then, label %if_7_else
if_7_then:
    %v9 = add i64 0, 61
    %v10.b = icmp eq i64 %v1, %v9
    %v10 = zext i1 %v10.b to i64
    br label %if_7_merge
if_7_else:
    %v13 = add i64 0, 0
    br label %if_7_merge
if_7_merge:
    %v16 = phi i64 [ %v10, %if_7_then ], [ %v13, %if_7_else ]
    %v17.cb = icmp ne i64 %v16, 0
    br i1 %v17.cb, label %if_17_then, label %if_17_else
if_17_then:
    %v19 = getelementptr i8, ptr @.str_216, i64 16
    store ptr %v19, ptr %v3
    %v20 = add i64 0, 0
    br label %if_17_merge
if_17_else:
    br label %if_17_merge
if_17_merge:
    %v25 = add i64 0, 33
    %v26.b = icmp eq i64 %v0, %v25
    %v26 = zext i1 %v26.b to i64
    %v27.cb = icmp ne i64 %v26, 0
    br i1 %v27.cb, label %if_27_then, label %if_27_else
if_27_then:
    %v29 = add i64 0, 61
    %v30.b = icmp eq i64 %v1, %v29
    %v30 = zext i1 %v30.b to i64
    br label %if_27_merge
if_27_else:
    %v33 = add i64 0, 0
    br label %if_27_merge
if_27_merge:
    %v36 = phi i64 [ %v30, %if_27_then ], [ %v33, %if_27_else ]
    %v37.cb = icmp ne i64 %v36, 0
    br i1 %v37.cb, label %if_37_then, label %if_37_else
if_37_then:
    %v39 = getelementptr i8, ptr @.str_217, i64 16
    store ptr %v39, ptr %v3
    %v40 = add i64 0, 0
    br label %if_37_merge
if_37_else:
    br label %if_37_merge
if_37_merge:
    %v45 = add i64 0, 60
    %v46.b = icmp eq i64 %v0, %v45
    %v46 = zext i1 %v46.b to i64
    %v47.cb = icmp ne i64 %v46, 0
    br i1 %v47.cb, label %if_47_then, label %if_47_else
if_47_then:
    %v49 = add i64 0, 61
    %v50.b = icmp eq i64 %v1, %v49
    %v50 = zext i1 %v50.b to i64
    br label %if_47_merge
if_47_else:
    %v53 = add i64 0, 0
    br label %if_47_merge
if_47_merge:
    %v56 = phi i64 [ %v50, %if_47_then ], [ %v53, %if_47_else ]
    %v57.cb = icmp ne i64 %v56, 0
    br i1 %v57.cb, label %if_57_then, label %if_57_else
if_57_then:
    %v59 = getelementptr i8, ptr @.str_218, i64 16
    store ptr %v59, ptr %v3
    %v60 = add i64 0, 0
    br label %if_57_merge
if_57_else:
    br label %if_57_merge
if_57_merge:
    %v65 = add i64 0, 62
    %v66.b = icmp eq i64 %v0, %v65
    %v66 = zext i1 %v66.b to i64
    %v67.cb = icmp ne i64 %v66, 0
    br i1 %v67.cb, label %if_67_then, label %if_67_else
if_67_then:
    %v69 = add i64 0, 61
    %v70.b = icmp eq i64 %v1, %v69
    %v70 = zext i1 %v70.b to i64
    br label %if_67_merge
if_67_else:
    %v73 = add i64 0, 0
    br label %if_67_merge
if_67_merge:
    %v76 = phi i64 [ %v70, %if_67_then ], [ %v73, %if_67_else ]
    %v77.cb = icmp ne i64 %v76, 0
    br i1 %v77.cb, label %if_77_then, label %if_77_else
if_77_then:
    %v79 = getelementptr i8, ptr @.str_219, i64 16
    store ptr %v79, ptr %v3
    %v80 = add i64 0, 0
    br label %if_77_merge
if_77_else:
    br label %if_77_merge
if_77_merge:
    %v85 = add i64 0, 45
    %v86.b = icmp eq i64 %v0, %v85
    %v86 = zext i1 %v86.b to i64
    %v87.cb = icmp ne i64 %v86, 0
    br i1 %v87.cb, label %if_87_then, label %if_87_else
if_87_then:
    %v89 = add i64 0, 62
    %v90.b = icmp eq i64 %v1, %v89
    %v90 = zext i1 %v90.b to i64
    br label %if_87_merge
if_87_else:
    %v93 = add i64 0, 0
    br label %if_87_merge
if_87_merge:
    %v96 = phi i64 [ %v90, %if_87_then ], [ %v93, %if_87_else ]
    %v97.cb = icmp ne i64 %v96, 0
    br i1 %v97.cb, label %if_97_then, label %if_97_else
if_97_then:
    %v99 = getelementptr i8, ptr @.str_220, i64 16
    store ptr %v99, ptr %v3
    %v100 = add i64 0, 0
    br label %if_97_merge
if_97_else:
    br label %if_97_merge
if_97_merge:
    %v105 = add i64 0, 43
    %v106.b = icmp eq i64 %v0, %v105
    %v106 = zext i1 %v106.b to i64
    %v107.cb = icmp ne i64 %v106, 0
    br i1 %v107.cb, label %if_107_then, label %if_107_else
if_107_then:
    %v109 = add i64 0, 61
    %v110.b = icmp eq i64 %v1, %v109
    %v110 = zext i1 %v110.b to i64
    br label %if_107_merge
if_107_else:
    %v113 = add i64 0, 0
    br label %if_107_merge
if_107_merge:
    %v116 = phi i64 [ %v110, %if_107_then ], [ %v113, %if_107_else ]
    %v117.cb = icmp ne i64 %v116, 0
    br i1 %v117.cb, label %if_117_then, label %if_117_else
if_117_then:
    %v119 = getelementptr i8, ptr @.str_221, i64 16
    store ptr %v119, ptr %v3
    %v120 = add i64 0, 0
    br label %if_117_merge
if_117_else:
    br label %if_117_merge
if_117_merge:
    %v125 = add i64 0, 45
    %v126.b = icmp eq i64 %v0, %v125
    %v126 = zext i1 %v126.b to i64
    %v127.cb = icmp ne i64 %v126, 0
    br i1 %v127.cb, label %if_127_then, label %if_127_else
if_127_then:
    %v129 = add i64 0, 61
    %v130.b = icmp eq i64 %v1, %v129
    %v130 = zext i1 %v130.b to i64
    br label %if_127_merge
if_127_else:
    %v133 = add i64 0, 0
    br label %if_127_merge
if_127_merge:
    %v136 = phi i64 [ %v130, %if_127_then ], [ %v133, %if_127_else ]
    %v137.cb = icmp ne i64 %v136, 0
    br i1 %v137.cb, label %if_137_then, label %if_137_else
if_137_then:
    %v139 = getelementptr i8, ptr @.str_222, i64 16
    store ptr %v139, ptr %v3
    %v140 = add i64 0, 0
    br label %if_137_merge
if_137_else:
    br label %if_137_merge
if_137_merge:
    %v145 = add i64 0, 42
    %v146.b = icmp eq i64 %v0, %v145
    %v146 = zext i1 %v146.b to i64
    %v147.cb = icmp ne i64 %v146, 0
    br i1 %v147.cb, label %if_147_then, label %if_147_else
if_147_then:
    %v149 = add i64 0, 61
    %v150.b = icmp eq i64 %v1, %v149
    %v150 = zext i1 %v150.b to i64
    br label %if_147_merge
if_147_else:
    %v153 = add i64 0, 0
    br label %if_147_merge
if_147_merge:
    %v156 = phi i64 [ %v150, %if_147_then ], [ %v153, %if_147_else ]
    %v157.cb = icmp ne i64 %v156, 0
    br i1 %v157.cb, label %if_157_then, label %if_157_else
if_157_then:
    %v159 = getelementptr i8, ptr @.str_223, i64 16
    store ptr %v159, ptr %v3
    %v160 = add i64 0, 0
    br label %if_157_merge
if_157_else:
    br label %if_157_merge
if_157_merge:
    %v165 = add i64 0, 47
    %v166.b = icmp eq i64 %v0, %v165
    %v166 = zext i1 %v166.b to i64
    %v167.cb = icmp ne i64 %v166, 0
    br i1 %v167.cb, label %if_167_then, label %if_167_else
if_167_then:
    %v169 = add i64 0, 61
    %v170.b = icmp eq i64 %v1, %v169
    %v170 = zext i1 %v170.b to i64
    br label %if_167_merge
if_167_else:
    %v173 = add i64 0, 0
    br label %if_167_merge
if_167_merge:
    %v176 = phi i64 [ %v170, %if_167_then ], [ %v173, %if_167_else ]
    %v177.cb = icmp ne i64 %v176, 0
    br i1 %v177.cb, label %if_177_then, label %if_177_else
if_177_then:
    %v179 = getelementptr i8, ptr @.str_224, i64 16
    store ptr %v179, ptr %v3
    %v180 = add i64 0, 0
    br label %if_177_merge
if_177_else:
    br label %if_177_merge
if_177_merge:
    %v185 = load ptr, ptr %v3
    %v186 = getelementptr i8, ptr @.str_5, i64 16
    %v187.e = call i64 @orion_text_eq(ptr %v185, ptr %v186)
    %v187 = add i64 %v187.e, 0
    %v188.cb = icmp ne i64 %v187, 0
    br i1 %v188.cb, label %if_188_then, label %if_188_else
if_188_then:
    %v190 = call ptr @prog__slx_scan_op_single(i64 %v0)
    store ptr %v190, ptr %v3
    %v191 = add i64 0, 0
    br label %if_188_merge
if_188_else:
    br label %if_188_merge
if_188_merge:
    %v196 = load ptr, ptr %v3
    ret ptr %v196
}

define ptr @prog__slx_scan_op_single(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = getelementptr i8, ptr @.str_5, i64 16
    %v2 = alloca ptr, align 8
    store ptr %v1, ptr %v2
    %v3 = add i64 0, 0
    %v4 = add i64 0, 43
    %v5.b = icmp eq i64 %v0, %v4
    %v5 = zext i1 %v5.b to i64
    %v6.cb = icmp ne i64 %v5, 0
    br i1 %v6.cb, label %if_6_then, label %if_6_else
if_6_then:
    %v8 = getelementptr i8, ptr @.str_225, i64 16
    store ptr %v8, ptr %v2
    %v9 = add i64 0, 0
    br label %if_6_merge
if_6_else:
    br label %if_6_merge
if_6_merge:
    %v14 = add i64 0, 45
    %v15.b = icmp eq i64 %v0, %v14
    %v15 = zext i1 %v15.b to i64
    %v16.cb = icmp ne i64 %v15, 0
    br i1 %v16.cb, label %if_16_then, label %if_16_else
if_16_then:
    %v18 = getelementptr i8, ptr @.str_226, i64 16
    store ptr %v18, ptr %v2
    %v19 = add i64 0, 0
    br label %if_16_merge
if_16_else:
    br label %if_16_merge
if_16_merge:
    %v24 = add i64 0, 42
    %v25.b = icmp eq i64 %v0, %v24
    %v25 = zext i1 %v25.b to i64
    %v26.cb = icmp ne i64 %v25, 0
    br i1 %v26.cb, label %if_26_then, label %if_26_else
if_26_then:
    %v28 = getelementptr i8, ptr @.str_227, i64 16
    store ptr %v28, ptr %v2
    %v29 = add i64 0, 0
    br label %if_26_merge
if_26_else:
    br label %if_26_merge
if_26_merge:
    %v34 = add i64 0, 47
    %v35.b = icmp eq i64 %v0, %v34
    %v35 = zext i1 %v35.b to i64
    %v36.cb = icmp ne i64 %v35, 0
    br i1 %v36.cb, label %if_36_then, label %if_36_else
if_36_then:
    %v38 = getelementptr i8, ptr @.str_228, i64 16
    store ptr %v38, ptr %v2
    %v39 = add i64 0, 0
    br label %if_36_merge
if_36_else:
    br label %if_36_merge
if_36_merge:
    %v44 = add i64 0, 61
    %v45.b = icmp eq i64 %v0, %v44
    %v45 = zext i1 %v45.b to i64
    %v46.cb = icmp ne i64 %v45, 0
    br i1 %v46.cb, label %if_46_then, label %if_46_else
if_46_then:
    %v48 = getelementptr i8, ptr @.str_229, i64 16
    store ptr %v48, ptr %v2
    %v49 = add i64 0, 0
    br label %if_46_merge
if_46_else:
    br label %if_46_merge
if_46_merge:
    %v54 = add i64 0, 60
    %v55.b = icmp eq i64 %v0, %v54
    %v55 = zext i1 %v55.b to i64
    %v56.cb = icmp ne i64 %v55, 0
    br i1 %v56.cb, label %if_56_then, label %if_56_else
if_56_then:
    %v58 = getelementptr i8, ptr @.str_230, i64 16
    store ptr %v58, ptr %v2
    %v59 = add i64 0, 0
    br label %if_56_merge
if_56_else:
    br label %if_56_merge
if_56_merge:
    %v64 = add i64 0, 62
    %v65.b = icmp eq i64 %v0, %v64
    %v65 = zext i1 %v65.b to i64
    %v66.cb = icmp ne i64 %v65, 0
    br i1 %v66.cb, label %if_66_then, label %if_66_else
if_66_then:
    %v68 = getelementptr i8, ptr @.str_231, i64 16
    store ptr %v68, ptr %v2
    %v69 = add i64 0, 0
    br label %if_66_merge
if_66_else:
    br label %if_66_merge
if_66_merge:
    %v74 = add i64 0, 33
    %v75.b = icmp eq i64 %v0, %v74
    %v75 = zext i1 %v75.b to i64
    %v76.cb = icmp ne i64 %v75, 0
    br i1 %v76.cb, label %if_76_then, label %if_76_else
if_76_then:
    %v78 = getelementptr i8, ptr @.str_232, i64 16
    store ptr %v78, ptr %v2
    %v79 = add i64 0, 0
    br label %if_76_merge
if_76_else:
    br label %if_76_merge
if_76_merge:
    %v84 = add i64 0, 40
    %v85.b = icmp eq i64 %v0, %v84
    %v85 = zext i1 %v85.b to i64
    %v86.cb = icmp ne i64 %v85, 0
    br i1 %v86.cb, label %if_86_then, label %if_86_else
if_86_then:
    %v88 = getelementptr i8, ptr @.str_233, i64 16
    store ptr %v88, ptr %v2
    %v89 = add i64 0, 0
    br label %if_86_merge
if_86_else:
    br label %if_86_merge
if_86_merge:
    %v94 = add i64 0, 41
    %v95.b = icmp eq i64 %v0, %v94
    %v95 = zext i1 %v95.b to i64
    %v96.cb = icmp ne i64 %v95, 0
    br i1 %v96.cb, label %if_96_then, label %if_96_else
if_96_then:
    %v98 = getelementptr i8, ptr @.str_234, i64 16
    store ptr %v98, ptr %v2
    %v99 = add i64 0, 0
    br label %if_96_merge
if_96_else:
    br label %if_96_merge
if_96_merge:
    %v104 = add i64 0, 44
    %v105.b = icmp eq i64 %v0, %v104
    %v105 = zext i1 %v105.b to i64
    %v106.cb = icmp ne i64 %v105, 0
    br i1 %v106.cb, label %if_106_then, label %if_106_else
if_106_then:
    %v108 = getelementptr i8, ptr @.str_235, i64 16
    store ptr %v108, ptr %v2
    %v109 = add i64 0, 0
    br label %if_106_merge
if_106_else:
    br label %if_106_merge
if_106_merge:
    %v114 = add i64 0, 58
    %v115.b = icmp eq i64 %v0, %v114
    %v115 = zext i1 %v115.b to i64
    %v116.cb = icmp ne i64 %v115, 0
    br i1 %v116.cb, label %if_116_then, label %if_116_else
if_116_then:
    %v118 = getelementptr i8, ptr @.str_236, i64 16
    store ptr %v118, ptr %v2
    %v119 = add i64 0, 0
    br label %if_116_merge
if_116_else:
    br label %if_116_merge
if_116_merge:
    %v124 = add i64 0, 59
    %v125.b = icmp eq i64 %v0, %v124
    %v125 = zext i1 %v125.b to i64
    %v126.cb = icmp ne i64 %v125, 0
    br i1 %v126.cb, label %if_126_then, label %if_126_else
if_126_then:
    %v128 = getelementptr i8, ptr @.str_237, i64 16
    store ptr %v128, ptr %v2
    %v129 = add i64 0, 0
    br label %if_126_merge
if_126_else:
    br label %if_126_merge
if_126_merge:
    %v134 = add i64 0, 46
    %v135.b = icmp eq i64 %v0, %v134
    %v135 = zext i1 %v135.b to i64
    %v136.cb = icmp ne i64 %v135, 0
    br i1 %v136.cb, label %if_136_then, label %if_136_else
if_136_then:
    %v138 = getelementptr i8, ptr @.str_103, i64 16
    store ptr %v138, ptr %v2
    %v139 = add i64 0, 0
    br label %if_136_merge
if_136_else:
    br label %if_136_merge
if_136_merge:
    %v144 = add i64 0, 91
    %v145.b = icmp eq i64 %v0, %v144
    %v145 = zext i1 %v145.b to i64
    %v146.cb = icmp ne i64 %v145, 0
    br i1 %v146.cb, label %if_146_then, label %if_146_else
if_146_then:
    %v148 = getelementptr i8, ptr @.str_238, i64 16
    store ptr %v148, ptr %v2
    %v149 = add i64 0, 0
    br label %if_146_merge
if_146_else:
    br label %if_146_merge
if_146_merge:
    %v154 = add i64 0, 93
    %v155.b = icmp eq i64 %v0, %v154
    %v155 = zext i1 %v155.b to i64
    %v156.cb = icmp ne i64 %v155, 0
    br i1 %v156.cb, label %if_156_then, label %if_156_else
if_156_then:
    %v158 = getelementptr i8, ptr @.str_239, i64 16
    store ptr %v158, ptr %v2
    %v159 = add i64 0, 0
    br label %if_156_merge
if_156_else:
    br label %if_156_merge
if_156_merge:
    %v164 = add i64 0, 123
    %v165.b = icmp eq i64 %v0, %v164
    %v165 = zext i1 %v165.b to i64
    %v166.cb = icmp ne i64 %v165, 0
    br i1 %v166.cb, label %if_166_then, label %if_166_else
if_166_then:
    %v168 = getelementptr i8, ptr @.str_240, i64 16
    store ptr %v168, ptr %v2
    %v169 = add i64 0, 0
    br label %if_166_merge
if_166_else:
    br label %if_166_merge
if_166_merge:
    %v174 = add i64 0, 125
    %v175.b = icmp eq i64 %v0, %v174
    %v175 = zext i1 %v175.b to i64
    %v176.cb = icmp ne i64 %v175, 0
    br i1 %v176.cb, label %if_176_then, label %if_176_else
if_176_then:
    %v178 = getelementptr i8, ptr @.str_241, i64 16
    store ptr %v178, ptr %v2
    %v179 = add i64 0, 0
    br label %if_176_merge
if_176_else:
    br label %if_176_merge
if_176_merge:
    %v184 = add i64 0, 63
    %v185.b = icmp eq i64 %v0, %v184
    %v185 = zext i1 %v185.b to i64
    %v186.cb = icmp ne i64 %v185, 0
    br i1 %v186.cb, label %if_186_then, label %if_186_else
if_186_then:
    %v188 = getelementptr i8, ptr @.str_242, i64 16
    store ptr %v188, ptr %v2
    %v189 = add i64 0, 0
    br label %if_186_merge
if_186_else:
    br label %if_186_merge
if_186_merge:
    %v194 = add i64 0, 64
    %v195.b = icmp eq i64 %v0, %v194
    %v195 = zext i1 %v195.b to i64
    %v196.cb = icmp ne i64 %v195, 0
    br i1 %v196.cb, label %if_196_then, label %if_196_else
if_196_then:
    %v198 = getelementptr i8, ptr @.str_243, i64 16
    store ptr %v198, ptr %v2
    %v199 = add i64 0, 0
    br label %if_196_merge
if_196_else:
    br label %if_196_merge
if_196_merge:
    %v204 = add i64 0, 38
    %v205.b = icmp eq i64 %v0, %v204
    %v205 = zext i1 %v205.b to i64
    %v206.cb = icmp ne i64 %v205, 0
    br i1 %v206.cb, label %if_206_then, label %if_206_else
if_206_then:
    %v208 = getelementptr i8, ptr @.str_244, i64 16
    store ptr %v208, ptr %v2
    %v209 = add i64 0, 0
    br label %if_206_merge
if_206_else:
    br label %if_206_merge
if_206_merge:
    %v214 = add i64 0, 124
    %v215.b = icmp eq i64 %v0, %v214
    %v215 = zext i1 %v215.b to i64
    %v216.cb = icmp ne i64 %v215, 0
    br i1 %v216.cb, label %if_216_then, label %if_216_else
if_216_then:
    %v218 = getelementptr i8, ptr @.str_95, i64 16
    store ptr %v218, ptr %v2
    %v219 = add i64 0, 0
    br label %if_216_merge
if_216_else:
    br label %if_216_merge
if_216_merge:
    %v224 = add i64 0, 94
    %v225.b = icmp eq i64 %v0, %v224
    %v225 = zext i1 %v225.b to i64
    %v226.cb = icmp ne i64 %v225, 0
    br i1 %v226.cb, label %if_226_then, label %if_226_else
if_226_then:
    %v228 = getelementptr i8, ptr @.str_245, i64 16
    store ptr %v228, ptr %v2
    %v229 = add i64 0, 0
    br label %if_226_merge
if_226_else:
    br label %if_226_merge
if_226_merge:
    %v234 = add i64 0, 37
    %v235.b = icmp eq i64 %v0, %v234
    %v235 = zext i1 %v235.b to i64
    %v236.cb = icmp ne i64 %v235, 0
    br i1 %v236.cb, label %if_236_then, label %if_236_else
if_236_then:
    %v238 = getelementptr i8, ptr @.str_246, i64 16
    store ptr %v238, ptr %v2
    %v239 = add i64 0, 0
    br label %if_236_merge
if_236_else:
    br label %if_236_merge
if_236_merge:
    %v244 = load ptr, ptr %v2
    ret ptr %v244
}

define i64 @prog__slx_skip_comment(ptr %p0, i64 %p1, i64 %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = alloca i64, align 8
    store i64 %v1, ptr %v3
    %v4 = add i64 0, 0
    br label %loop_5_header
loop_5_header:
    %v7 = load i64, ptr %v3
    %v8.b = icmp sge i64 %v7, %v2
    %v8 = zext i1 %v8.b to i64
    %v9.cb = icmp ne i64 %v8, 0
    br i1 %v9.cb, label %if_9_then, label %if_9_else
if_9_then:
    br label %loop_5_end
if_9_else:
    br label %if_9_merge
if_9_merge:
    %v15 = load i64, ptr %v3
    %v16 = call i64 @orion_list_at(ptr %v0, i64 %v15)
    %v17 = call i64 @prog__slx_is_newline(i64 %v16)
    %v18.cb = icmp ne i64 %v17, 0
    br i1 %v18.cb, label %if_18_then, label %if_18_else
if_18_then:
    br label %loop_5_end
if_18_else:
    br label %if_18_merge
if_18_merge:
    %v24 = load i64, ptr %v3
    %v25 = add i64 0, 1
    %v26 = add i64 %v24, %v25
    store i64 %v26, ptr %v3
    %v27 = add i64 0, 0
    br label %loop_5_header
loop_5_end:
    %v30 = load i64, ptr %v3
    ret i64 %v30
}

define ptr @prog__slx_push_token(ptr %p0, ptr %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i8, ptr @.str_247, i64 16
    %v3 = call ptr @orion_slot_get(ptr %v2)
    %v4 = getelementptr i8, ptr @.str_118, i64 16
    %v5.i = call i64 @orion_map_get(ptr %v1, ptr %v4)
    %v5.raw = inttoptr i64 %v5.i to ptr
    %v5.isnull = icmp eq i64 %v5.i, 0
    %v5 = select i1 %v5.isnull, ptr getelementptr(i8, ptr @.str_empty_h, i64 16), ptr %v5.raw
    %v6 = getelementptr i8, ptr @.str_211, i64 16
    %v7.e = call i64 @orion_text_eq(ptr %v5, ptr %v6)
    %v7 = add i64 %v7.e, 0
    %v8 = getelementptr i8, ptr @.str_211, i64 16
    %v9.e = call i64 @orion_text_eq(ptr %v3, ptr %v8)
    %v9 = add i64 %v9.e, 0
    %v10.cb = icmp ne i64 %v9, 0
    br i1 %v10.cb, label %if_10_then, label %if_10_else
if_10_then:
    br label %if_10_merge
if_10_else:
    %v14 = getelementptr i8, ptr @.str_5, i64 16
    %v15.e = call i64 @orion_text_eq(ptr %v3, ptr %v14)
    %v15 = add i64 %v15.e, 0
    br label %if_10_merge
if_10_merge:
    %v18 = phi i64 [ %v9, %if_10_then ], [ %v15, %if_10_else ]
    %v19.cb = icmp ne i64 %v7, 0
    br i1 %v19.cb, label %if_19_then, label %if_19_else
if_19_then:
    br label %if_19_merge
if_19_else:
    %v23 = add i64 0, 0
    br label %if_19_merge
if_19_merge:
    %v26 = phi i64 [ %v18, %if_19_then ], [ %v23, %if_19_else ]
    %v27 = alloca ptr, align 8
    store ptr %v0, ptr %v27
    %v28 = add i64 0, 0
    %v29.n = icmp eq i64 %v26, 0
    %v29 = zext i1 %v29.n to i64
    %v30.cb = icmp ne i64 %v29, 0
    br i1 %v30.cb, label %if_30_then, label %if_30_else
if_30_then:
    %v32 = load ptr, ptr %v27
    %v33.p = ptrtoint ptr %v1 to i64
    %v33 = call ptr @orion_list_push_mut(ptr %v32, i64 %v33.p)
    store ptr %v33, ptr %v27
    %v34 = add i64 0, 0
    %v35 = getelementptr i8, ptr @.str_247, i64 16
    %v36 = getelementptr i8, ptr @.str_118, i64 16
    %v37.i = call i64 @orion_map_get(ptr %v1, ptr %v36)
    %v37.raw = inttoptr i64 %v37.i to ptr
    %v37.isnull = icmp eq i64 %v37.i, 0
    %v37 = select i1 %v37.isnull, ptr getelementptr(i8, ptr @.str_empty_h, i64 16), ptr %v37.raw
    %v38.ev = call ptr @orion_slot_evac(ptr %v37, ptr %v35, i64 1)
    %v38.sp = ptrtoint ptr %v38.ev to i64
    %v38 = call i64 @orion_slot_set(ptr %v35, i64 %v38.sp)
    br label %if_30_merge
if_30_else:
    br label %if_30_merge
if_30_merge:
    %v43 = load ptr, ptr %v27
    ret ptr %v43
}

define ptr @prog__self_lex(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = call ptr @orion_bytes_from_text(ptr %v0)
    %v2 = call i64 @orion_list_len(ptr %v1)
    %v3 = getelementptr i8, ptr @.str_247, i64 16
    %v4 = getelementptr i8, ptr @.str_5, i64 16
    %v5.ev = call ptr @orion_slot_evac(ptr %v4, ptr %v3, i64 1)
    %v5.sp = ptrtoint ptr %v5.ev to i64
    %v5 = call i64 @orion_slot_set(ptr %v3, i64 %v5.sp)
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = alloca ptr, align 8
    store ptr %v6, ptr %v7
    %v8 = add i64 0, 0
    %v9 = add i64 0, 0
    %v10 = alloca i64, align 8
    store i64 %v9, ptr %v10
    %v11 = add i64 0, 0
    %v12 = add i64 0, 1
    %v13 = alloca i64, align 8
    store i64 %v12, ptr %v13
    %v14 = add i64 0, 0
    %v15 = add i64 0, 0
    %v16 = alloca i64, align 8
    store i64 %v15, ptr %v16
    %v17 = add i64 0, 0
    br label %loop_18_header
loop_18_header:
    %v20 = load i64, ptr %v10
    %v21.b = icmp sge i64 %v20, %v2
    %v21 = zext i1 %v21.b to i64
    %v22.cb = icmp ne i64 %v21, 0
    br i1 %v22.cb, label %if_22_then, label %if_22_else
if_22_then:
    br label %loop_18_end
if_22_else:
    br label %if_22_merge
if_22_merge:
    %v28 = load i64, ptr %v10
    %v29 = call i64 @orion_list_at(ptr %v1, i64 %v28)
    %v30 = load i64, ptr %v10
    %v31 = load i64, ptr %v16
    %v32 = sub i64 %v30, %v31
    %v33 = call i64 @prog__slx_is_newline(i64 %v29)
    %v34 = call i64 @prog__slx_is_space(i64 %v29)
    %v35 = add i64 0, 35
    %v36.b = icmp eq i64 %v29, %v35
    %v36 = zext i1 %v36.b to i64
    %v37 = add i64 0, 34
    %v38.b = icmp eq i64 %v29, %v37
    %v38 = zext i1 %v38.b to i64
    %v39 = add i64 0, 39
    %v40.b = icmp eq i64 %v29, %v39
    %v40 = zext i1 %v40.b to i64
    %v41 = call i64 @prog__slx_is_digit(i64 %v29)
    %v42 = call i64 @prog__slx_is_ident_start(i64 %v29)
    %v43.cb = icmp ne i64 %v33, 0
    br i1 %v43.cb, label %if_43_then, label %if_43_else
if_43_then:
    %v45 = load ptr, ptr %v7
    %v46 = getelementptr i8, ptr @.str_211, i64 16
    %v47 = getelementptr i8, ptr @.str_116, i64 16
    %v48 = load i64, ptr %v13
    %v49 = call ptr @prog__slx_make_token(ptr %v46, ptr %v47, i64 %v48, i64 %v32)
    %v50 = call ptr @prog__slx_push_token(ptr %v45, ptr %v49)
    store ptr %v50, ptr %v7
    %v51 = add i64 0, 0
    %v52 = load i64, ptr %v13
    %v53 = add i64 0, 1
    %v54 = add i64 %v52, %v53
    store i64 %v54, ptr %v13
    %v55 = add i64 0, 0
    %v56 = load i64, ptr %v10
    %v57 = add i64 0, 1
    %v58 = add i64 %v56, %v57
    store i64 %v58, ptr %v10
    %v59 = add i64 0, 0
    %v60 = load i64, ptr %v10
    store i64 %v60, ptr %v16
    %v61 = add i64 0, 0
    br label %if_43_merge
if_43_else:
    br label %if_43_merge
if_43_merge:
    %v66.cb = icmp ne i64 %v34, 0
    br i1 %v66.cb, label %if_66_then, label %if_66_else
if_66_then:
    %v68.n = icmp eq i64 %v33, 0
    %v68 = zext i1 %v68.n to i64
    br label %if_66_merge
if_66_else:
    %v71 = add i64 0, 0
    br label %if_66_merge
if_66_merge:
    %v74 = phi i64 [ %v68, %if_66_then ], [ %v71, %if_66_else ]
    %v75.cb = icmp ne i64 %v74, 0
    br i1 %v75.cb, label %if_75_then, label %if_75_else
if_75_then:
    %v77 = load i64, ptr %v10
    %v78 = add i64 0, 1
    %v79 = add i64 %v77, %v78
    store i64 %v79, ptr %v10
    %v80 = add i64 0, 0
    br label %if_75_merge
if_75_else:
    br label %if_75_merge
if_75_merge:
    %v85.cb = icmp ne i64 %v36, 0
    br i1 %v85.cb, label %if_85_then, label %if_85_else
if_85_then:
    %v87 = load i64, ptr %v10
    %v88 = call i64 @prog__slx_skip_comment(ptr %v1, i64 %v87, i64 %v2)
    store i64 %v88, ptr %v10
    %v89 = add i64 0, 0
    br label %if_85_merge
if_85_else:
    br label %if_85_merge
if_85_merge:
    %v94.cb = icmp ne i64 %v38, 0
    br i1 %v94.cb, label %if_94_then, label %if_94_else
if_94_then:
    %v96 = load i64, ptr %v10
    %v97 = load i64, ptr %v13
    %v98 = call ptr @prog__slx_scan_string(ptr %v1, i64 %v96, i64 %v2, i64 %v97, i64 %v32)
    %v99 = load ptr, ptr %v7
    %v100 = getelementptr i8, ptr @.str_122, i64 16
    %v101.i = call i64 @orion_map_get(ptr %v98, ptr %v100)
    %v101.raw = inttoptr i64 %v101.i to ptr
    %v101.isnull = icmp eq i64 %v101.i, 0
    %v101 = select i1 %v101.isnull, ptr getelementptr(i8, ptr @.str_empty_h, i64 16), ptr %v101.raw
    %v102 = call ptr @prog__slx_push_token(ptr %v99, ptr %v101)
    store ptr %v102, ptr %v7
    %v103 = add i64 0, 0
    %v104 = getelementptr i8, ptr @.str_124, i64 16
    %v105 = call i64 @orion_map_get(ptr %v98, ptr %v104)
    store i64 %v105, ptr %v10
    %v106 = add i64 0, 0
    br label %if_94_merge
if_94_else:
    br label %if_94_merge
if_94_merge:
    %v111.cb = icmp ne i64 %v40, 0
    br i1 %v111.cb, label %if_111_then, label %if_111_else
if_111_then:
    %v113 = load i64, ptr %v10
    %v114 = load i64, ptr %v13
    %v115 = call ptr @prog__slx_scan_char(ptr %v1, i64 %v113, i64 %v2, i64 %v114, i64 %v32)
    %v116 = load ptr, ptr %v7
    %v117 = getelementptr i8, ptr @.str_122, i64 16
    %v118.i = call i64 @orion_map_get(ptr %v115, ptr %v117)
    %v118.raw = inttoptr i64 %v118.i to ptr
    %v118.isnull = icmp eq i64 %v118.i, 0
    %v118 = select i1 %v118.isnull, ptr getelementptr(i8, ptr @.str_empty_h, i64 16), ptr %v118.raw
    %v119 = call ptr @prog__slx_push_token(ptr %v116, ptr %v118)
    store ptr %v119, ptr %v7
    %v120 = add i64 0, 0
    %v121 = getelementptr i8, ptr @.str_124, i64 16
    %v122 = call i64 @orion_map_get(ptr %v115, ptr %v121)
    store i64 %v122, ptr %v10
    %v123 = add i64 0, 0
    br label %if_111_merge
if_111_else:
    br label %if_111_merge
if_111_merge:
    %v128.cb = icmp ne i64 %v41, 0
    br i1 %v128.cb, label %if_128_then, label %if_128_else
if_128_then:
    %v130 = load i64, ptr %v10
    %v131 = load i64, ptr %v13
    %v132 = call ptr @prog__slx_scan_number(ptr %v1, i64 %v130, i64 %v2, i64 %v131, i64 %v32)
    %v133 = load ptr, ptr %v7
    %v134 = getelementptr i8, ptr @.str_122, i64 16
    %v135.i = call i64 @orion_map_get(ptr %v132, ptr %v134)
    %v135.raw = inttoptr i64 %v135.i to ptr
    %v135.isnull = icmp eq i64 %v135.i, 0
    %v135 = select i1 %v135.isnull, ptr getelementptr(i8, ptr @.str_empty_h, i64 16), ptr %v135.raw
    %v136 = call ptr @prog__slx_push_token(ptr %v133, ptr %v135)
    store ptr %v136, ptr %v7
    %v137 = add i64 0, 0
    %v138 = getelementptr i8, ptr @.str_124, i64 16
    %v139 = call i64 @orion_map_get(ptr %v132, ptr %v138)
    store i64 %v139, ptr %v10
    %v140 = add i64 0, 0
    br label %if_128_merge
if_128_else:
    br label %if_128_merge
if_128_merge:
    %v145.cb = icmp ne i64 %v42, 0
    br i1 %v145.cb, label %if_145_then, label %if_145_else
if_145_then:
    %v147 = load i64, ptr %v10
    %v148 = load i64, ptr %v13
    %v149 = call ptr @prog__slx_scan_ident(ptr %v1, i64 %v147, i64 %v2, i64 %v148, i64 %v32)
    %v150 = load ptr, ptr %v7
    %v151 = getelementptr i8, ptr @.str_122, i64 16
    %v152.i = call i64 @orion_map_get(ptr %v149, ptr %v151)
    %v152.raw = inttoptr i64 %v152.i to ptr
    %v152.isnull = icmp eq i64 %v152.i, 0
    %v152 = select i1 %v152.isnull, ptr getelementptr(i8, ptr @.str_empty_h, i64 16), ptr %v152.raw
    %v153 = call ptr @prog__slx_push_token(ptr %v150, ptr %v152)
    store ptr %v153, ptr %v7
    %v154 = add i64 0, 0
    %v155 = getelementptr i8, ptr @.str_124, i64 16
    %v156 = call i64 @orion_map_get(ptr %v149, ptr %v155)
    store i64 %v156, ptr %v10
    %v157 = add i64 0, 0
    br label %if_145_merge
if_145_else:
    br label %if_145_merge
if_145_merge:
    %v162.cb = icmp ne i64 %v33, 0
    br i1 %v162.cb, label %if_162_then, label %if_162_else
if_162_then:
    br label %if_162_merge
if_162_else:
    br label %if_162_merge
if_162_merge:
    %v168 = phi i64 [ %v33, %if_162_then ], [ %v34, %if_162_else ]
    %v169.cb = icmp ne i64 %v168, 0
    br i1 %v169.cb, label %if_169_then, label %if_169_else
if_169_then:
    br label %if_169_merge
if_169_else:
    br label %if_169_merge
if_169_merge:
    %v175 = phi i64 [ %v168, %if_169_then ], [ %v36, %if_169_else ]
    %v176.cb = icmp ne i64 %v175, 0
    br i1 %v176.cb, label %if_176_then, label %if_176_else
if_176_then:
    br label %if_176_merge
if_176_else:
    br label %if_176_merge
if_176_merge:
    %v182 = phi i64 [ %v175, %if_176_then ], [ %v38, %if_176_else ]
    %v183.cb = icmp ne i64 %v182, 0
    br i1 %v183.cb, label %if_183_then, label %if_183_else
if_183_then:
    br label %if_183_merge
if_183_else:
    br label %if_183_merge
if_183_merge:
    %v189 = phi i64 [ %v182, %if_183_then ], [ %v40, %if_183_else ]
    %v190.cb = icmp ne i64 %v189, 0
    br i1 %v190.cb, label %if_190_then, label %if_190_else
if_190_then:
    br label %if_190_merge
if_190_else:
    br label %if_190_merge
if_190_merge:
    %v196 = phi i64 [ %v189, %if_190_then ], [ %v41, %if_190_else ]
    %v197.cb = icmp ne i64 %v196, 0
    br i1 %v197.cb, label %if_197_then, label %if_197_else
if_197_then:
    br label %if_197_merge
if_197_else:
    br label %if_197_merge
if_197_merge:
    %v203 = phi i64 [ %v196, %if_197_then ], [ %v42, %if_197_else ]
    %v204.n = icmp eq i64 %v203, 0
    %v204 = zext i1 %v204.n to i64
    %v205.cb = icmp ne i64 %v204, 0
    br i1 %v205.cb, label %if_205_then, label %if_205_else
if_205_then:
    %v207 = load i64, ptr %v10
    %v208 = call ptr @prog__slx_scan_op(ptr %v1, i64 %v207, i64 %v2)
    %v209 = getelementptr i8, ptr @.str_5, i64 16
    %v210.e = call i64 @orion_text_eq(ptr %v208, ptr %v209)
    %v210 = add i64 %v210.e, 0
    %v211.cb = icmp ne i64 %v210, 0
    br i1 %v211.cb, label %if_211_then, label %if_211_else
if_211_then:
    %v213 = load i64, ptr %v10
    %v214 = add i64 0, 1
    %v215 = add i64 %v213, %v214
    store i64 %v215, ptr %v10
    %v216 = add i64 0, 0
    br label %if_211_merge
if_211_else:
    %v219 = call ptr @orion_bytes_from_text(ptr %v208)
    %v220 = call i64 @orion_list_len(ptr %v219)
    %v221 = load ptr, ptr %v7
    %v222 = getelementptr i8, ptr @.str_248, i64 16
    %v223 = load i64, ptr %v13
    %v224 = call ptr @prog__slx_make_token(ptr %v222, ptr %v208, i64 %v223, i64 %v32)
    %v225 = call ptr @prog__slx_push_token(ptr %v221, ptr %v224)
    store ptr %v225, ptr %v7
    %v226 = add i64 0, 0
    %v227 = load i64, ptr %v10
    %v228 = add i64 %v227, %v220
    store i64 %v228, ptr %v10
    %v229 = add i64 0, 0
    br label %if_211_merge
if_211_merge:
    %v232 = phi i64 [ %v216, %if_211_then ], [ %v229, %if_211_else ]
    br label %if_205_merge
if_205_else:
    br label %if_205_merge
if_205_merge:
    br label %loop_18_header
loop_18_end:
    %v239 = load ptr, ptr %v7
    %v240 = getelementptr i8, ptr @.str_211, i64 16
    %v241 = getelementptr i8, ptr @.str_116, i64 16
    %v242 = load i64, ptr %v13
    %v243 = load i64, ptr %v16
    %v244 = sub i64 %v2, %v243
    %v245 = call ptr @prog__slx_make_token(ptr %v240, ptr %v241, i64 %v242, i64 %v244)
    %v246 = call ptr @prog__slx_push_token(ptr %v239, ptr %v245)
    store ptr %v246, ptr %v7
    %v247 = add i64 0, 0
    %v248 = getelementptr i8, ptr @.str_249, i64 16
    %v249 = getelementptr i8, ptr @.str_5, i64 16
    %v250 = load i64, ptr %v13
    %v251 = load i64, ptr %v16
    %v252 = sub i64 %v2, %v251
    %v253 = call ptr @prog__slx_make_token(ptr %v248, ptr %v249, i64 %v250, i64 %v252)
    %v254 = load ptr, ptr %v7
    %v255.p = ptrtoint ptr %v253 to i64
    %v255 = call ptr @orion_list_push(ptr %v254, i64 %v255.p)
    store ptr %v255, ptr %v7
    %v256 = add i64 0, 0
    %v257 = load ptr, ptr %v7
    ret ptr %v257
}

define ptr @prog__psr_arg_to_node(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = call ptr @orion_bytes_from_text(ptr %v0)
    %v2 = call i64 @orion_list_len(ptr %v1)
    %v3 = add i64 0, 0
    %v4.b = icmp sgt i64 %v2, %v3
    %v4 = zext i1 %v4.b to i64
    %v5 = alloca i64, align 8
    store i64 %v4, ptr %v5
    %v6 = add i64 0, 0
    %v7 = add i64 0, 0
    %v8 = add i64 0, 1
    %v9 = sub i64 %v7, %v8
    %v10 = alloca i64, align 8
    store i64 %v9, ptr %v10
    %v11 = add i64 0, 0
    %v12 = add i64 0, 0
    %v13 = add i64 0, 1
    %v14 = sub i64 %v12, %v13
    %v15 = alloca i64, align 8
    store i64 %v14, ptr %v15
    %v16 = add i64 0, 0
    %v17 = add i64 0, 0
    %v18 = alloca i64, align 8
    store i64 %v17, ptr %v18
    %v19 = add i64 0, 0
    br label %for_17_header
for_17_header:
    %v22 = load i64, ptr %v18
    %v23.b = icmp slt i64 %v22, %v2
    %v23 = zext i1 %v23.b to i64
    %v24.cb = icmp ne i64 %v23, 0
    br i1 %v24.cb, label %for_17_body, label %for_17_end
for_17_body:
    %v26 = call i64 @orion_list_at(ptr %v1, i64 %v22)
    %v27 = add i64 0, 48
    %v28.b = icmp slt i64 %v26, %v27
    %v28 = zext i1 %v28.b to i64
    %v29.cb = icmp ne i64 %v28, 0
    br i1 %v29.cb, label %if_29_then, label %if_29_else
if_29_then:
    br label %if_29_merge
if_29_else:
    %v33 = add i64 0, 57
    %v34.b = icmp sgt i64 %v26, %v33
    %v34 = zext i1 %v34.b to i64
    br label %if_29_merge
if_29_merge:
    %v37 = phi i64 [ %v28, %if_29_then ], [ %v34, %if_29_else ]
    %v38.cb = icmp ne i64 %v37, 0
    br i1 %v38.cb, label %if_38_then, label %if_38_else
if_38_then:
    %v40 = add i64 0, 0
    store i64 %v40, ptr %v5
    %v41 = add i64 0, 0
    br label %if_38_merge
if_38_else:
    br label %if_38_merge
if_38_merge:
    %v46 = add i64 0, 46
    %v47.b = icmp eq i64 %v26, %v46
    %v47 = zext i1 %v47.b to i64
    %v48.cb = icmp ne i64 %v47, 0
    br i1 %v48.cb, label %if_48_then, label %if_48_else
if_48_then:
    %v50 = load i64, ptr %v10
    %v51 = add i64 0, 0
    %v52 = add i64 0, 1
    %v53 = sub i64 %v51, %v52
    %v54.b = icmp eq i64 %v50, %v53
    %v54 = zext i1 %v54.b to i64
    br label %if_48_merge
if_48_else:
    %v57 = add i64 0, 0
    br label %if_48_merge
if_48_merge:
    %v60 = phi i64 [ %v54, %if_48_then ], [ %v57, %if_48_else ]
    %v61.cb = icmp ne i64 %v60, 0
    br i1 %v61.cb, label %if_61_then, label %if_61_else
if_61_then:
    store i64 %v22, ptr %v10
    %v63 = add i64 0, 0
    br label %if_61_merge
if_61_else:
    br label %if_61_merge
if_61_merge:
    %v68 = add i64 0, 40
    %v69.b = icmp eq i64 %v26, %v68
    %v69 = zext i1 %v69.b to i64
    %v70.cb = icmp ne i64 %v69, 0
    br i1 %v70.cb, label %if_70_then, label %if_70_else
if_70_then:
    %v72 = load i64, ptr %v15
    %v73 = add i64 0, 0
    %v74 = add i64 0, 1
    %v75 = sub i64 %v73, %v74
    %v76.b = icmp eq i64 %v72, %v75
    %v76 = zext i1 %v76.b to i64
    br label %if_70_merge
if_70_else:
    %v79 = add i64 0, 0
    br label %if_70_merge
if_70_merge:
    %v82 = phi i64 [ %v76, %if_70_then ], [ %v79, %if_70_else ]
    %v83.cb = icmp ne i64 %v82, 0
    br i1 %v83.cb, label %if_83_then, label %if_83_else
if_83_then:
    store i64 %v22, ptr %v15
    %v85 = add i64 0, 0
    br label %if_83_merge
if_83_else:
    br label %if_83_merge
if_83_merge:
    br label %for_17_step
for_17_step:
    %v92 = add i64 0, 1
    %v93 = add i64 %v22, %v92
    store i64 %v93, ptr %v18
    %v94 = add i64 0, 0
    br label %for_17_header
for_17_end:
    %v97 = load i64, ptr %v15
    %v98 = add i64 0, 0
    %v99.b = icmp sgt i64 %v97, %v98
    %v99 = zext i1 %v99.b to i64
    %v100 = load i64, ptr %v10
    %v101 = add i64 0, 0
    %v102.b = icmp sgt i64 %v100, %v101
    %v102 = zext i1 %v102.b to i64
    %v103.cb = icmp ne i64 %v102, 0
    br i1 %v103.cb, label %if_103_then, label %if_103_else
if_103_then:
    %v105 = load i64, ptr %v5
    %v106.n = icmp eq i64 %v105, 0
    %v106 = zext i1 %v106.n to i64
    br label %if_103_merge
if_103_else:
    %v109 = add i64 0, 0
    br label %if_103_merge
if_103_merge:
    %v112 = phi i64 [ %v106, %if_103_then ], [ %v109, %if_103_else ]
    %v113.cb = icmp ne i64 %v112, 0
    br i1 %v113.cb, label %if_113_then, label %if_113_else
if_113_then:
    %v115.n = icmp eq i64 %v99, 0
    %v115 = zext i1 %v115.n to i64
    br label %if_113_merge
if_113_else:
    %v118 = add i64 0, 0
    br label %if_113_merge
if_113_merge:
    %v121 = phi i64 [ %v115, %if_113_then ], [ %v118, %if_113_else ]
    %v122 = load i64, ptr %v5
    %v123.cb = icmp ne i64 %v122, 0
    br i1 %v123.cb, label %if_123_then, label %if_123_else
if_123_then:
    %v125 = getelementptr i8, ptr @.str_118, i64 16
    %v126 = getelementptr i8, ptr @.str_250, i64 16
    %v127 = getelementptr i8, ptr @.str_119, i64 16
    %v128 = call ptr @orion_map_new(i64 2)
    %v128.p0 = ptrtoint ptr %v126 to i64
    call void @orion_map_set(ptr %v128, ptr %v125, i64 %v128.p0)
    %v128.p1 = ptrtoint ptr %v0 to i64
    call void @orion_map_set(ptr %v128, ptr %v127, i64 %v128.p1)
    br label %if_123_merge
if_123_else:
    %v131.cb = icmp ne i64 %v99, 0
    br i1 %v131.cb, label %if_131_then, label %if_131_else
if_131_then:
    %v133 = add i64 0, 0
    %v134 = load i64, ptr %v15
    %v135 = call ptr @orion_bytes_slice(ptr %v1, i64 %v133, i64 %v134)
    %v136 = call ptr @orion_bytes_to_text(ptr %v135)
    %v137 = call ptr @prog__psr_trim_ws(ptr %v136)
    %v138 = load i64, ptr %v15
    %v139 = add i64 0, 1
    %v140 = add i64 %v138, %v139
    %v141 = add i64 0, 1
    %v142 = sub i64 %v2, %v141
    %v143 = call ptr @orion_bytes_slice(ptr %v1, i64 %v140, i64 %v142)
    %v144 = call ptr @orion_bytes_to_text(ptr %v143)
    %v145 = call ptr @orion_bytes_from_text(ptr %v144)
    %v146 = call i64 @orion_list_len(ptr %v145)
    %v147 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v148 = alloca ptr, align 8
    store ptr %v147, ptr %v148
    %v149 = add i64 0, 0
    %v150 = add i64 0, 0
    %v151 = alloca i64, align 8
    store i64 %v150, ptr %v151
    %v152 = add i64 0, 0
    %v153 = add i64 0, 0
    %v154 = alloca i64, align 8
    store i64 %v153, ptr %v154
    %v155 = add i64 0, 0
    %v156 = add i64 0, 0
    %v157 = alloca i64, align 8
    store i64 %v156, ptr %v157
    %v158 = add i64 0, 0
    br label %for_156_header
for_156_header:
    %v161 = load i64, ptr %v157
    %v162.b = icmp slt i64 %v161, %v146
    %v162 = zext i1 %v162.b to i64
    %v163.cb = icmp ne i64 %v162, 0
    br i1 %v163.cb, label %for_156_body, label %for_156_end
for_156_body:
    %v165 = call i64 @orion_list_at(ptr %v145, i64 %v161)
    %v166 = add i64 0, 40
    %v167.b = icmp eq i64 %v165, %v166
    %v167 = zext i1 %v167.b to i64
    %v168.cb = icmp ne i64 %v167, 0
    br i1 %v168.cb, label %if_168_then, label %if_168_else
if_168_then:
    %v170 = load i64, ptr %v154
    %v171 = add i64 0, 1
    %v172 = add i64 %v170, %v171
    store i64 %v172, ptr %v154
    %v173 = add i64 0, 0
    br label %if_168_merge
if_168_else:
    br label %if_168_merge
if_168_merge:
    %v178 = add i64 0, 41
    %v179.b = icmp eq i64 %v165, %v178
    %v179 = zext i1 %v179.b to i64
    %v180.cb = icmp ne i64 %v179, 0
    br i1 %v180.cb, label %if_180_then, label %if_180_else
if_180_then:
    %v182 = load i64, ptr %v154
    %v183 = add i64 0, 1
    %v184 = sub i64 %v182, %v183
    store i64 %v184, ptr %v154
    %v185 = add i64 0, 0
    br label %if_180_merge
if_180_else:
    br label %if_180_merge
if_180_merge:
    %v190 = add i64 0, 44
    %v191.b = icmp eq i64 %v165, %v190
    %v191 = zext i1 %v191.b to i64
    %v192.cb = icmp ne i64 %v191, 0
    br i1 %v192.cb, label %if_192_then, label %if_192_else
if_192_then:
    %v194 = load i64, ptr %v154
    %v195 = add i64 0, 0
    %v196.b = icmp eq i64 %v194, %v195
    %v196 = zext i1 %v196.b to i64
    br label %if_192_merge
if_192_else:
    %v199 = add i64 0, 0
    br label %if_192_merge
if_192_merge:
    %v202 = phi i64 [ %v196, %if_192_then ], [ %v199, %if_192_else ]
    %v203.cb = icmp ne i64 %v202, 0
    br i1 %v203.cb, label %if_203_then, label %if_203_else
if_203_then:
    %v205 = load i64, ptr %v151
    %v206 = call ptr @orion_bytes_slice(ptr %v145, i64 %v205, i64 %v161)
    %v207 = call ptr @orion_bytes_to_text(ptr %v206)
    %v208 = call ptr @prog__psr_trim_ws(ptr %v207)
    %v209 = load ptr, ptr %v148
    %v210 = call ptr @prog__psr_arg_to_node(ptr %v208)
    %v211.p = ptrtoint ptr %v210 to i64
    %v211 = call ptr @orion_list_push(ptr %v209, i64 %v211.p)
    store ptr %v211, ptr %v148
    %v212 = add i64 0, 0
    %v213 = add i64 0, 1
    %v214 = add i64 %v161, %v213
    store i64 %v214, ptr %v151
    %v215 = add i64 0, 0
    br label %if_203_merge
if_203_else:
    br label %if_203_merge
if_203_merge:
    br label %for_156_step
for_156_step:
    %v222 = add i64 0, 1
    %v223 = add i64 %v161, %v222
    store i64 %v223, ptr %v157
    %v224 = add i64 0, 0
    br label %for_156_header
for_156_end:
    %v227 = add i64 0, 0
    %v228.b = icmp sgt i64 %v146, %v227
    %v228 = zext i1 %v228.b to i64
    %v229.cb = icmp ne i64 %v228, 0
    br i1 %v229.cb, label %if_229_then, label %if_229_else
if_229_then:
    %v231 = load i64, ptr %v151
    %v232 = call ptr @orion_bytes_slice(ptr %v145, i64 %v231, i64 %v146)
    %v233 = call ptr @orion_bytes_to_text(ptr %v232)
    %v234 = call ptr @prog__psr_trim_ws(ptr %v233)
    %v235 = load ptr, ptr %v148
    %v236 = call ptr @prog__psr_arg_to_node(ptr %v234)
    %v237.p = ptrtoint ptr %v236 to i64
    %v237 = call ptr @orion_list_push(ptr %v235, i64 %v237.p)
    store ptr %v237, ptr %v148
    %v238 = add i64 0, 0
    br label %if_229_merge
if_229_else:
    br label %if_229_merge
if_229_merge:
    %v243 = getelementptr i8, ptr @.str_118, i64 16
    %v244 = getelementptr i8, ptr @.str_251, i64 16
    %v245 = getelementptr i8, ptr @.str_252, i64 16
    %v246 = getelementptr i8, ptr @.str_253, i64 16
    %v247 = load ptr, ptr %v148
    %v248 = call ptr @orion_map_new(i64 3)
    %v248.p0 = ptrtoint ptr %v244 to i64
    call void @orion_map_set(ptr %v248, ptr %v243, i64 %v248.p0)
    %v248.p1 = ptrtoint ptr %v137 to i64
    call void @orion_map_set(ptr %v248, ptr %v245, i64 %v248.p1)
    %v248.p2 = ptrtoint ptr %v247 to i64
    call void @orion_map_set(ptr %v248, ptr %v246, i64 %v248.p2)
    br label %if_131_merge
if_131_else:
    %v251.cb = icmp ne i64 %v121, 0
    br i1 %v251.cb, label %if_251_then, label %if_251_else
if_251_then:
    %v253 = add i64 0, 0
    %v254 = load i64, ptr %v10
    %v255 = call ptr @orion_bytes_slice(ptr %v1, i64 %v253, i64 %v254)
    %v256 = call ptr @orion_bytes_to_text(ptr %v255)
    %v257 = call ptr @prog__psr_trim_ws(ptr %v256)
    %v258 = load i64, ptr %v10
    %v259 = add i64 0, 1
    %v260 = add i64 %v258, %v259
    %v261 = call ptr @orion_bytes_slice(ptr %v1, i64 %v260, i64 %v2)
    %v262 = call ptr @orion_bytes_to_text(ptr %v261)
    %v263 = call ptr @prog__psr_trim_ws(ptr %v262)
    %v264 = getelementptr i8, ptr @.str_118, i64 16
    %v265 = getelementptr i8, ptr @.str_254, i64 16
    %v266 = getelementptr i8, ptr @.str_255, i64 16
    %v267 = getelementptr i8, ptr @.str_118, i64 16
    %v268 = getelementptr i8, ptr @.str_256, i64 16
    %v269 = getelementptr i8, ptr @.str_257, i64 16
    %v270 = call ptr @orion_map_new(i64 2)
    %v270.p0 = ptrtoint ptr %v268 to i64
    call void @orion_map_set(ptr %v270, ptr %v267, i64 %v270.p0)
    %v270.p1 = ptrtoint ptr %v257 to i64
    call void @orion_map_set(ptr %v270, ptr %v269, i64 %v270.p1)
    %v271 = getelementptr i8, ptr @.str_258, i64 16
    %v272 = call ptr @orion_map_new(i64 3)
    %v272.p0 = ptrtoint ptr %v265 to i64
    call void @orion_map_set(ptr %v272, ptr %v264, i64 %v272.p0)
    %v272.p1 = ptrtoint ptr %v270 to i64
    call void @orion_map_set(ptr %v272, ptr %v266, i64 %v272.p1)
    %v272.p2 = ptrtoint ptr %v263 to i64
    call void @orion_map_set(ptr %v272, ptr %v271, i64 %v272.p2)
    br label %if_251_merge
if_251_else:
    %v275 = getelementptr i8, ptr @.str_118, i64 16
    %v276 = getelementptr i8, ptr @.str_256, i64 16
    %v277 = getelementptr i8, ptr @.str_257, i64 16
    %v278 = call ptr @orion_map_new(i64 2)
    %v278.p0 = ptrtoint ptr %v276 to i64
    call void @orion_map_set(ptr %v278, ptr %v275, i64 %v278.p0)
    %v278.p1 = ptrtoint ptr %v0 to i64
    call void @orion_map_set(ptr %v278, ptr %v277, i64 %v278.p1)
    br label %if_251_merge
if_251_merge:
    %v281 = phi ptr [ %v272, %if_251_then ], [ %v278, %if_251_else ]
    br label %if_131_merge
if_131_merge:
    %v284 = phi ptr [ %v248, %if_229_merge ], [ %v281, %if_251_merge ]
    br label %if_123_merge
if_123_merge:
    %v287 = phi ptr [ %v128, %if_123_then ], [ %v284, %if_131_merge ]
    ret ptr %v287
}

define ptr @prog__psr_trim_ws(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = call ptr @orion_bytes_from_text(ptr %v0)
    %v2 = call i64 @orion_list_len(ptr %v1)
    %v3 = add i64 0, 0
    %v4 = alloca i64, align 8
    store i64 %v3, ptr %v4
    %v5 = add i64 0, 0
    br label %loop_6_header
loop_6_header:
    %v8 = load i64, ptr %v4
    %v9.b = icmp sge i64 %v8, %v2
    %v9 = zext i1 %v9.b to i64
    %v10.cb = icmp ne i64 %v9, 0
    br i1 %v10.cb, label %if_10_then, label %if_10_else
if_10_then:
    br label %loop_6_end
if_10_else:
    br label %if_10_merge
if_10_merge:
    %v16 = load i64, ptr %v4
    %v17 = call i64 @orion_list_at(ptr %v1, i64 %v16)
    %v18 = add i64 0, 32
    %v19.b = icmp eq i64 %v17, %v18
    %v19 = zext i1 %v19.b to i64
    %v20.cb = icmp ne i64 %v19, 0
    br i1 %v20.cb, label %if_20_then, label %if_20_else
if_20_then:
    br label %if_20_merge
if_20_else:
    %v24 = add i64 0, 9
    %v25.b = icmp eq i64 %v17, %v24
    %v25 = zext i1 %v25.b to i64
    br label %if_20_merge
if_20_merge:
    %v28 = phi i64 [ %v19, %if_20_then ], [ %v25, %if_20_else ]
    %v29.cb = icmp ne i64 %v28, 0
    br i1 %v29.cb, label %if_29_then, label %if_29_else
if_29_then:
    br label %if_29_merge
if_29_else:
    %v33 = add i64 0, 10
    %v34.b = icmp eq i64 %v17, %v33
    %v34 = zext i1 %v34.b to i64
    br label %if_29_merge
if_29_merge:
    %v37 = phi i64 [ %v28, %if_29_then ], [ %v34, %if_29_else ]
    %v38.cb = icmp ne i64 %v37, 0
    br i1 %v38.cb, label %if_38_then, label %if_38_else
if_38_then:
    br label %if_38_merge
if_38_else:
    %v42 = add i64 0, 13
    %v43.b = icmp eq i64 %v17, %v42
    %v43 = zext i1 %v43.b to i64
    br label %if_38_merge
if_38_merge:
    %v46 = phi i64 [ %v37, %if_38_then ], [ %v43, %if_38_else ]
    %v47.n = icmp eq i64 %v46, 0
    %v47 = zext i1 %v47.n to i64
    %v48.cb = icmp ne i64 %v47, 0
    br i1 %v48.cb, label %if_48_then, label %if_48_else
if_48_then:
    br label %loop_6_end
if_48_else:
    br label %if_48_merge
if_48_merge:
    %v54 = load i64, ptr %v4
    %v55 = add i64 0, 1
    %v56 = add i64 %v54, %v55
    store i64 %v56, ptr %v4
    %v57 = add i64 0, 0
    br label %loop_6_header
loop_6_end:
    %v60 = alloca i64, align 8
    store i64 %v2, ptr %v60
    %v61 = add i64 0, 0
    br label %loop_62_header
loop_62_header:
    %v64 = load i64, ptr %v60
    %v65 = load i64, ptr %v4
    %v66.b = icmp sle i64 %v64, %v65
    %v66 = zext i1 %v66.b to i64
    %v67.cb = icmp ne i64 %v66, 0
    br i1 %v67.cb, label %if_67_then, label %if_67_else
if_67_then:
    br label %loop_62_end
if_67_else:
    br label %if_67_merge
if_67_merge:
    %v73 = load i64, ptr %v60
    %v74 = add i64 0, 1
    %v75 = sub i64 %v73, %v74
    %v76 = call i64 @orion_list_at(ptr %v1, i64 %v75)
    %v77 = add i64 0, 32
    %v78.b = icmp eq i64 %v76, %v77
    %v78 = zext i1 %v78.b to i64
    %v79.cb = icmp ne i64 %v78, 0
    br i1 %v79.cb, label %if_79_then, label %if_79_else
if_79_then:
    br label %if_79_merge
if_79_else:
    %v83 = add i64 0, 9
    %v84.b = icmp eq i64 %v76, %v83
    %v84 = zext i1 %v84.b to i64
    br label %if_79_merge
if_79_merge:
    %v87 = phi i64 [ %v78, %if_79_then ], [ %v84, %if_79_else ]
    %v88.cb = icmp ne i64 %v87, 0
    br i1 %v88.cb, label %if_88_then, label %if_88_else
if_88_then:
    br label %if_88_merge
if_88_else:
    %v92 = add i64 0, 10
    %v93.b = icmp eq i64 %v76, %v92
    %v93 = zext i1 %v93.b to i64
    br label %if_88_merge
if_88_merge:
    %v96 = phi i64 [ %v87, %if_88_then ], [ %v93, %if_88_else ]
    %v97.cb = icmp ne i64 %v96, 0
    br i1 %v97.cb, label %if_97_then, label %if_97_else
if_97_then:
    br label %if_97_merge
if_97_else:
    %v101 = add i64 0, 13
    %v102.b = icmp eq i64 %v76, %v101
    %v102 = zext i1 %v102.b to i64
    br label %if_97_merge
if_97_merge:
    %v105 = phi i64 [ %v96, %if_97_then ], [ %v102, %if_97_else ]
    %v106.n = icmp eq i64 %v105, 0
    %v106 = zext i1 %v106.n to i64
    %v107.cb = icmp ne i64 %v106, 0
    br i1 %v107.cb, label %if_107_then, label %if_107_else
if_107_then:
    br label %loop_62_end
if_107_else:
    br label %if_107_merge
if_107_merge:
    %v113 = load i64, ptr %v60
    %v114 = add i64 0, 1
    %v115 = sub i64 %v113, %v114
    store i64 %v115, ptr %v60
    %v116 = add i64 0, 0
    br label %loop_62_header
loop_62_end:
    %v119 = load i64, ptr %v4
    %v120 = load i64, ptr %v60
    %v121 = call ptr @orion_bytes_slice(ptr %v1, i64 %v119, i64 %v120)
    %v122 = call ptr @orion_bytes_to_text(ptr %v121)
    ret ptr %v122
}

define ptr @prog__psr_peek_kind(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = call i64 @orion_list_len(ptr %v0)
    %v3.b = icmp sge i64 %v1, %v2
    %v3 = zext i1 %v3.b to i64
    %v4.cb = icmp ne i64 %v3, 0
    br i1 %v4.cb, label %if_4_then, label %if_4_else
if_4_then:
    %v6 = getelementptr i8, ptr @.str_249, i64 16
    br label %if_4_merge
if_4_else:
    %v9.i = call i64 @orion_list_at(ptr %v0, i64 %v1)
    %v9 = inttoptr i64 %v9.i to ptr
    %v10 = getelementptr i8, ptr @.str_118, i64 16
    %v11.i = call i64 @orion_map_get(ptr %v9, ptr %v10)
    %v11.raw = inttoptr i64 %v11.i to ptr
    %v11.isnull = icmp eq i64 %v11.i, 0
    %v11 = select i1 %v11.isnull, ptr getelementptr(i8, ptr @.str_empty_h, i64 16), ptr %v11.raw
    br label %if_4_merge
if_4_merge:
    %v14 = phi ptr [ %v6, %if_4_then ], [ %v11, %if_4_else ]
    ret ptr %v14
}

define ptr @prog__psr_peek_value(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = call i64 @orion_list_len(ptr %v0)
    %v3.b = icmp sge i64 %v1, %v2
    %v3 = zext i1 %v3.b to i64
    %v4.cb = icmp ne i64 %v3, 0
    br i1 %v4.cb, label %if_4_then, label %if_4_else
if_4_then:
    %v6 = getelementptr i8, ptr @.str_5, i64 16
    br label %if_4_merge
if_4_else:
    %v9.i = call i64 @orion_list_at(ptr %v0, i64 %v1)
    %v9 = inttoptr i64 %v9.i to ptr
    %v10 = getelementptr i8, ptr @.str_119, i64 16
    %v11.i = call i64 @orion_map_get(ptr %v9, ptr %v10)
    %v11.raw = inttoptr i64 %v11.i to ptr
    %v11.isnull = icmp eq i64 %v11.i, 0
    %v11 = select i1 %v11.isnull, ptr getelementptr(i8, ptr @.str_empty_h, i64 16), ptr %v11.raw
    br label %if_4_merge
if_4_merge:
    %v14 = phi ptr [ %v6, %if_4_then ], [ %v11, %if_4_else ]
    ret ptr %v14
}

define i64 @prog__psr_skip_newlines(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = alloca i64, align 8
    store i64 %v1, ptr %v2
    %v3 = add i64 0, 0
    br label %loop_4_header
loop_4_header:
    %v6 = load i64, ptr %v2
    %v7 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v6)
    %v8 = getelementptr i8, ptr @.str_211, i64 16
    %v9.e = call i64 @orion_text_eq(ptr %v7, ptr %v8)
    %v9 = xor i64 %v9.e, 1
    %v10.cb = icmp ne i64 %v9, 0
    br i1 %v10.cb, label %if_10_then, label %if_10_else
if_10_then:
    br label %loop_4_end
if_10_else:
    br label %if_10_merge
if_10_merge:
    %v16 = load i64, ptr %v2
    %v17 = add i64 0, 1
    %v18 = add i64 %v16, %v17
    store i64 %v18, ptr %v2
    %v19 = add i64 0, 0
    br label %loop_4_header
loop_4_end:
    %v22 = load i64, ptr %v2
    ret i64 %v22
}

define ptr @prog__psr_parse_type(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v1)
    %v3 = getelementptr i8, ptr @.str_123, i64 16
    %v4.e = call i64 @orion_text_eq(ptr %v2, ptr %v3)
    %v4 = add i64 %v4.e, 0
    %v5.cb = icmp ne i64 %v4, 0
    br i1 %v5.cb, label %if_5_then, label %if_5_else
if_5_then:
    %v7 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v1)
    %v8 = getelementptr i8, ptr @.str_125, i64 16
    %v9.e = call i64 @orion_text_eq(ptr %v7, ptr %v8)
    %v9 = add i64 %v9.e, 0
    br label %if_5_merge
if_5_else:
    %v12 = add i64 0, 0
    br label %if_5_merge
if_5_merge:
    %v15 = phi i64 [ %v9, %if_5_then ], [ %v12, %if_5_else ]
    %v16.cb = icmp ne i64 %v15, 0
    br i1 %v16.cb, label %if_16_then, label %if_16_else
if_16_then:
    %v18 = add i64 0, 1
    %v19 = add i64 %v1, %v18
    %v20 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v19)
    %v21 = getelementptr i8, ptr @.str_248, i64 16
    %v22.e = call i64 @orion_text_eq(ptr %v20, ptr %v21)
    %v22 = add i64 %v22.e, 0
    br label %if_16_merge
if_16_else:
    %v25 = add i64 0, 0
    br label %if_16_merge
if_16_merge:
    %v28 = phi i64 [ %v22, %if_16_then ], [ %v25, %if_16_else ]
    %v29.cb = icmp ne i64 %v28, 0
    br i1 %v29.cb, label %if_29_then, label %if_29_else
if_29_then:
    %v31 = add i64 0, 1
    %v32 = add i64 %v1, %v31
    %v33 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v32)
    %v34 = getelementptr i8, ptr @.str_233, i64 16
    %v35.e = call i64 @orion_text_eq(ptr %v33, ptr %v34)
    %v35 = add i64 %v35.e, 0
    br label %if_29_merge
if_29_else:
    %v38 = add i64 0, 0
    br label %if_29_merge
if_29_merge:
    %v41 = phi i64 [ %v35, %if_29_then ], [ %v38, %if_29_else ]
    %v42.cb = icmp ne i64 %v41, 0
    br i1 %v42.cb, label %if_42_then, label %if_42_else
if_42_then:
    %v44 = call ptr @prog__psr_parse_fn_type(ptr %v0, i64 %v1)
    ret ptr %v44
if_42_else:
    br label %if_42_merge
if_42_merge:
    %v49 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v1)
    %v50 = getelementptr i8, ptr @.str_248, i64 16
    %v51.e = call i64 @orion_text_eq(ptr %v49, ptr %v50)
    %v51 = add i64 %v51.e, 0
    %v52.cb = icmp ne i64 %v51, 0
    br i1 %v52.cb, label %if_52_then, label %if_52_else
if_52_then:
    %v54 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v1)
    %v55 = getelementptr i8, ptr @.str_233, i64 16
    %v56.e = call i64 @orion_text_eq(ptr %v54, ptr %v55)
    %v56 = add i64 %v56.e, 0
    br label %if_52_merge
if_52_else:
    %v59 = add i64 0, 0
    br label %if_52_merge
if_52_merge:
    %v62 = phi i64 [ %v56, %if_52_then ], [ %v59, %if_52_else ]
    %v63.cb = icmp ne i64 %v62, 0
    br i1 %v63.cb, label %if_63_then, label %if_63_else
if_63_then:
    %v65 = add i64 0, 1
    %v66 = add i64 %v1, %v65
    %v67 = alloca i64, align 8
    store i64 %v66, ptr %v67
    %v68 = add i64 0, 0
    %v69 = getelementptr i8, ptr @.str_118, i64 16
    %v70 = getelementptr i8, ptr @.str_259, i64 16
    %v71 = getelementptr i8, ptr @.str_257, i64 16
    %v72 = getelementptr i8, ptr @.str_209, i64 16
    %v73 = call ptr @orion_map_new(i64 2)
    %v73.p0 = ptrtoint ptr %v70 to i64
    call void @orion_map_set(ptr %v73, ptr %v69, i64 %v73.p0)
    %v73.p1 = ptrtoint ptr %v72 to i64
    call void @orion_map_set(ptr %v73, ptr %v71, i64 %v73.p1)
    %v74 = call ptr @orion_list_new(i64 1)
    %v74.lp0 = ptrtoint ptr %v73 to i64
    call void @orion_list_set(ptr %v74, i64 0, i64 %v74.lp0)
    %v75 = add i64 0, 0
    %v76 = add i64 0, 0
    %v77 = call ptr @orion_list_slice(ptr %v74, i64 %v75, i64 %v76)
    %v78 = alloca ptr, align 8
    store ptr %v77, ptr %v78
    %v79 = add i64 0, 0
    br label %loop_80_header
loop_80_header:
    %v82 = load i64, ptr %v67
    %v83 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v82)
    %v84 = getelementptr i8, ptr @.str_248, i64 16
    %v85.e = call i64 @orion_text_eq(ptr %v83, ptr %v84)
    %v85 = add i64 %v85.e, 0
    %v86.cb = icmp ne i64 %v85, 0
    br i1 %v86.cb, label %if_86_then, label %if_86_else
if_86_then:
    %v88 = load i64, ptr %v67
    %v89 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v88)
    %v90 = getelementptr i8, ptr @.str_234, i64 16
    %v91.e = call i64 @orion_text_eq(ptr %v89, ptr %v90)
    %v91 = add i64 %v91.e, 0
    br label %if_86_merge
if_86_else:
    %v94 = add i64 0, 0
    br label %if_86_merge
if_86_merge:
    %v97 = phi i64 [ %v91, %if_86_then ], [ %v94, %if_86_else ]
    %v98.cb = icmp ne i64 %v97, 0
    br i1 %v98.cb, label %if_98_then, label %if_98_else
if_98_then:
    %v100 = load i64, ptr %v67
    %v101 = add i64 0, 1
    %v102 = add i64 %v100, %v101
    store i64 %v102, ptr %v67
    %v103 = add i64 0, 0
    br label %loop_80_end
if_98_else:
    br label %if_98_merge
if_98_merge:
    %v108 = load i64, ptr %v67
    %v109 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v108)
    %v110 = getelementptr i8, ptr @.str_249, i64 16
    %v111.e = call i64 @orion_text_eq(ptr %v109, ptr %v110)
    %v111 = add i64 %v111.e, 0
    %v112.cb = icmp ne i64 %v111, 0
    br i1 %v112.cb, label %if_112_then, label %if_112_else
if_112_then:
    br label %loop_80_end
if_112_else:
    br label %if_112_merge
if_112_merge:
    %v118 = load i64, ptr %v67
    %v119 = call ptr @prog__psr_parse_type(ptr %v0, i64 %v118)
    %v120 = load ptr, ptr %v78
    %v121 = getelementptr i8, ptr @.str_260, i64 16
    %v122.i = call i64 @orion_map_get(ptr %v119, ptr %v121)
    %v122.raw = inttoptr i64 %v122.i to ptr
    %v122.isnull = icmp eq i64 %v122.i, 0
    %v122 = select i1 %v122.isnull, ptr @orion_empty_list, ptr %v122.raw
    %v123.p = ptrtoint ptr %v122 to i64
    %v123 = call ptr @orion_list_push(ptr %v120, i64 %v123.p)
    store ptr %v123, ptr %v78
    %v124 = add i64 0, 0
    %v125 = getelementptr i8, ptr @.str_124, i64 16
    %v126 = call i64 @orion_map_get(ptr %v119, ptr %v125)
    store i64 %v126, ptr %v67
    %v127 = add i64 0, 0
    %v128 = load i64, ptr %v67
    %v129 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v128)
    %v130 = getelementptr i8, ptr @.str_248, i64 16
    %v131.e = call i64 @orion_text_eq(ptr %v129, ptr %v130)
    %v131 = add i64 %v131.e, 0
    %v132.cb = icmp ne i64 %v131, 0
    br i1 %v132.cb, label %if_132_then, label %if_132_else
if_132_then:
    %v134 = load i64, ptr %v67
    %v135 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v134)
    %v136 = getelementptr i8, ptr @.str_235, i64 16
    %v137.e = call i64 @orion_text_eq(ptr %v135, ptr %v136)
    %v137 = add i64 %v137.e, 0
    br label %if_132_merge
if_132_else:
    %v140 = add i64 0, 0
    br label %if_132_merge
if_132_merge:
    %v143 = phi i64 [ %v137, %if_132_then ], [ %v140, %if_132_else ]
    %v144.cb = icmp ne i64 %v143, 0
    br i1 %v144.cb, label %if_144_then, label %if_144_else
if_144_then:
    %v146 = load i64, ptr %v67
    %v147 = add i64 0, 1
    %v148 = add i64 %v146, %v147
    store i64 %v148, ptr %v67
    %v149 = add i64 0, 0
    br label %if_144_merge
if_144_else:
    br label %if_144_merge
if_144_merge:
    br label %loop_80_header
loop_80_end:
    %v156 = getelementptr i8, ptr @.str_260, i64 16
    %v157 = getelementptr i8, ptr @.str_118, i64 16
    %v158 = getelementptr i8, ptr @.str_261, i64 16
    %v159 = getelementptr i8, ptr @.str_262, i64 16
    %v160 = load ptr, ptr %v78
    %v161 = call ptr @orion_map_new(i64 2)
    %v161.p0 = ptrtoint ptr %v158 to i64
    call void @orion_map_set(ptr %v161, ptr %v157, i64 %v161.p0)
    %v161.p1 = ptrtoint ptr %v160 to i64
    call void @orion_map_set(ptr %v161, ptr %v159, i64 %v161.p1)
    %v162 = getelementptr i8, ptr @.str_124, i64 16
    %v163 = load i64, ptr %v67
    %v164 = call ptr @orion_map_new(i64 2)
    %v164.p0 = ptrtoint ptr %v161 to i64
    call void @orion_map_set(ptr %v164, ptr %v156, i64 %v164.p0)
    call void @orion_map_set(ptr %v164, ptr %v162, i64 %v163)
    ret ptr %v164
if_63_else:
    br label %if_63_merge
if_63_merge:
    %v169 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v1)
    %v170 = getelementptr i8, ptr @.str_248, i64 16
    %v171.e = call i64 @orion_text_eq(ptr %v169, ptr %v170)
    %v171 = add i64 %v171.e, 0
    %v172.cb = icmp ne i64 %v171, 0
    br i1 %v172.cb, label %if_172_then, label %if_172_else
if_172_then:
    %v174 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v1)
    %v175 = getelementptr i8, ptr @.str_238, i64 16
    %v176.e = call i64 @orion_text_eq(ptr %v174, ptr %v175)
    %v176 = add i64 %v176.e, 0
    br label %if_172_merge
if_172_else:
    %v179 = add i64 0, 0
    br label %if_172_merge
if_172_merge:
    %v182 = phi i64 [ %v176, %if_172_then ], [ %v179, %if_172_else ]
    %v183.cb = icmp ne i64 %v182, 0
    br i1 %v183.cb, label %if_183_then, label %if_183_else
if_183_then:
    %v185 = add i64 0, 1
    %v186 = add i64 %v1, %v185
    %v187 = call ptr @prog__psr_parse_type(ptr %v0, i64 %v186)
    %v188 = getelementptr i8, ptr @.str_124, i64 16
    %v189 = call i64 @orion_map_get(ptr %v187, ptr %v188)
    %v190 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v189)
    %v191 = getelementptr i8, ptr @.str_248, i64 16
    %v192.e = call i64 @orion_text_eq(ptr %v190, ptr %v191)
    %v192 = add i64 %v192.e, 0
    %v193.cb = icmp ne i64 %v192, 0
    br i1 %v193.cb, label %if_193_then, label %if_193_else
if_193_then:
    %v195 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v189)
    %v196 = getelementptr i8, ptr @.str_239, i64 16
    %v197.e = call i64 @orion_text_eq(ptr %v195, ptr %v196)
    %v197 = add i64 %v197.e, 0
    br label %if_193_merge
if_193_else:
    %v200 = add i64 0, 0
    br label %if_193_merge
if_193_merge:
    %v203 = phi i64 [ %v197, %if_193_then ], [ %v200, %if_193_else ]
    %v204.cb = icmp ne i64 %v203, 0
    br i1 %v204.cb, label %if_204_then, label %if_204_else
if_204_then:
    %v206 = getelementptr i8, ptr @.str_260, i64 16
    %v207 = getelementptr i8, ptr @.str_118, i64 16
    %v208 = getelementptr i8, ptr @.str_263, i64 16
    %v209 = getelementptr i8, ptr @.str_264, i64 16
    %v210 = getelementptr i8, ptr @.str_260, i64 16
    %v211.i = call i64 @orion_map_get(ptr %v187, ptr %v210)
    %v211.raw = inttoptr i64 %v211.i to ptr
    %v211.isnull = icmp eq i64 %v211.i, 0
    %v211 = select i1 %v211.isnull, ptr @orion_empty_list, ptr %v211.raw
    %v212 = call ptr @orion_map_new(i64 2)
    %v212.p0 = ptrtoint ptr %v208 to i64
    call void @orion_map_set(ptr %v212, ptr %v207, i64 %v212.p0)
    %v212.p1 = ptrtoint ptr %v211 to i64
    call void @orion_map_set(ptr %v212, ptr %v209, i64 %v212.p1)
    %v213 = getelementptr i8, ptr @.str_124, i64 16
    %v214 = add i64 0, 1
    %v215 = add i64 %v189, %v214
    %v216 = call ptr @orion_map_new(i64 2)
    %v216.p0 = ptrtoint ptr %v212 to i64
    call void @orion_map_set(ptr %v216, ptr %v206, i64 %v216.p0)
    call void @orion_map_set(ptr %v216, ptr %v213, i64 %v215)
    br label %if_204_merge
if_204_else:
    %v219 = getelementptr i8, ptr @.str_260, i64 16
    %v220 = getelementptr i8, ptr @.str_118, i64 16
    %v221 = getelementptr i8, ptr @.str_265, i64 16
    %v222 = getelementptr i8, ptr @.str_266, i64 16
    %v223 = getelementptr i8, ptr @.str_267, i64 16
    %v224 = call ptr @orion_map_new(i64 2)
    %v224.p0 = ptrtoint ptr %v221 to i64
    call void @orion_map_set(ptr %v224, ptr %v220, i64 %v224.p0)
    %v224.p1 = ptrtoint ptr %v223 to i64
    call void @orion_map_set(ptr %v224, ptr %v222, i64 %v224.p1)
    %v225 = getelementptr i8, ptr @.str_124, i64 16
    %v226 = call ptr @orion_map_new(i64 2)
    %v226.p0 = ptrtoint ptr %v224 to i64
    call void @orion_map_set(ptr %v226, ptr %v219, i64 %v226.p0)
    call void @orion_map_set(ptr %v226, ptr %v225, i64 %v189)
    br label %if_204_merge
if_204_merge:
    %v229 = phi ptr [ %v216, %if_204_then ], [ %v226, %if_204_else ]
    br label %if_183_merge
if_183_else:
    %v232 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v1)
    %v233 = getelementptr i8, ptr @.str_209, i64 16
    %v234.e = call i64 @orion_text_eq(ptr %v232, ptr %v233)
    %v234 = add i64 %v234.e, 0
    %v235.cb = icmp ne i64 %v234, 0
    br i1 %v235.cb, label %if_235_then, label %if_235_else
if_235_then:
    %v237 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v1)
    %v238 = add i64 0, 1
    %v239 = add i64 %v1, %v238
    %v240 = alloca i64, align 8
    store i64 %v239, ptr %v240
    %v241 = add i64 0, 0
    %v242 = load i64, ptr %v240
    %v243 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v242)
    %v244 = load i64, ptr %v240
    %v245 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v244)
    %v246 = getelementptr i8, ptr @.str_248, i64 16
    %v247.e = call i64 @orion_text_eq(ptr %v243, ptr %v246)
    %v247 = add i64 %v247.e, 0
    %v248.cb = icmp ne i64 %v247, 0
    br i1 %v248.cb, label %if_248_then, label %if_248_else
if_248_then:
    %v250 = getelementptr i8, ptr @.str_215, i64 16
    %v251.e = call i64 @orion_text_eq(ptr %v245, ptr %v250)
    %v251 = add i64 %v251.e, 0
    %v252.cb = icmp ne i64 %v251, 0
    br i1 %v252.cb, label %if_252_then, label %if_252_else
if_252_then:
    br label %if_252_merge
if_252_else:
    %v256 = getelementptr i8, ptr @.str_214, i64 16
    %v257.e = call i64 @orion_text_eq(ptr %v245, ptr %v256)
    %v257 = add i64 %v257.e, 0
    br label %if_252_merge
if_252_merge:
    %v260 = phi i64 [ %v251, %if_252_then ], [ %v257, %if_252_else ]
    br label %if_248_merge
if_248_else:
    %v263 = add i64 0, 0
    br label %if_248_merge
if_248_merge:
    %v266 = phi i64 [ %v260, %if_252_merge ], [ %v263, %if_248_else ]
    %v267.cb = icmp ne i64 %v266, 0
    br i1 %v267.cb, label %if_267_then, label %if_267_else
if_267_then:
    %v269 = load i64, ptr %v240
    %v270 = add i64 0, 1
    %v271 = add i64 %v269, %v270
    store i64 %v271, ptr %v240
    %v272 = add i64 0, 0
    %v273 = load i64, ptr %v240
    %v274 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v273)
    %v275 = getelementptr i8, ptr @.str_248, i64 16
    %v276.e = call i64 @orion_text_eq(ptr %v274, ptr %v275)
    %v276 = add i64 %v276.e, 0
    %v277.cb = icmp ne i64 %v276, 0
    br i1 %v277.cb, label %if_277_then, label %if_277_else
if_277_then:
    %v279 = load i64, ptr %v240
    %v280 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v279)
    %v281 = getelementptr i8, ptr @.str_103, i64 16
    %v282.e = call i64 @orion_text_eq(ptr %v280, ptr %v281)
    %v282 = add i64 %v282.e, 0
    br label %if_277_merge
if_277_else:
    %v285 = add i64 0, 0
    br label %if_277_merge
if_277_merge:
    %v288 = phi i64 [ %v282, %if_277_then ], [ %v285, %if_277_else ]
    %v289.cb = icmp ne i64 %v288, 0
    br i1 %v289.cb, label %if_289_then, label %if_289_else
if_289_then:
    %v291 = load i64, ptr %v240
    %v292 = add i64 0, 1
    %v293 = add i64 %v291, %v292
    store i64 %v293, ptr %v240
    %v294 = add i64 0, 0
    br label %if_289_merge
if_289_else:
    br label %if_289_merge
if_289_merge:
    %v299 = load i64, ptr %v240
    %v300 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v299)
    %v301 = load i64, ptr %v240
    %v302 = add i64 0, 1
    %v303 = add i64 %v301, %v302
    store i64 %v303, ptr %v240
    %v304 = add i64 0, 0
    %v305 = getelementptr i8, ptr @.str_215, i64 16
    %v306.e = call i64 @orion_text_eq(ptr %v245, ptr %v305)
    %v306 = add i64 %v306.e, 0
    %v307 = getelementptr i8, ptr @.str_260, i64 16
    %v308 = getelementptr i8, ptr @.str_118, i64 16
    %v309 = getelementptr i8, ptr @.str_268, i64 16
    %v310 = getelementptr i8, ptr @.str_269, i64 16
    %v311 = getelementptr i8, ptr @.str_270, i64 16
    %v312 = getelementptr i8, ptr @.str_271, i64 16
    %v313 = call ptr @orion_map_new(i64 4)
    %v313.p0 = ptrtoint ptr %v309 to i64
    call void @orion_map_set(ptr %v313, ptr %v308, i64 %v313.p0)
    %v313.p1 = ptrtoint ptr %v237 to i64
    call void @orion_map_set(ptr %v313, ptr %v310, i64 %v313.p1)
    %v313.p2 = ptrtoint ptr %v300 to i64
    call void @orion_map_set(ptr %v313, ptr %v311, i64 %v313.p2)
    call void @orion_map_set(ptr %v313, ptr %v312, i64 %v306)
    %v314 = getelementptr i8, ptr @.str_124, i64 16
    %v315 = load i64, ptr %v240
    %v316 = call ptr @orion_map_new(i64 2)
    %v316.p0 = ptrtoint ptr %v313 to i64
    call void @orion_map_set(ptr %v316, ptr %v307, i64 %v316.p0)
    call void @orion_map_set(ptr %v316, ptr %v314, i64 %v315)
    br label %if_267_merge
if_267_else:
    %v319 = getelementptr i8, ptr @.str_260, i64 16
    %v320 = getelementptr i8, ptr @.str_118, i64 16
    %v321 = getelementptr i8, ptr @.str_259, i64 16
    %v322 = getelementptr i8, ptr @.str_257, i64 16
    %v323 = call ptr @orion_map_new(i64 2)
    %v323.p0 = ptrtoint ptr %v321 to i64
    call void @orion_map_set(ptr %v323, ptr %v320, i64 %v323.p0)
    %v323.p1 = ptrtoint ptr %v237 to i64
    call void @orion_map_set(ptr %v323, ptr %v322, i64 %v323.p1)
    %v324 = getelementptr i8, ptr @.str_124, i64 16
    %v325 = add i64 0, 1
    %v326 = add i64 %v1, %v325
    %v327 = call ptr @orion_map_new(i64 2)
    %v327.p0 = ptrtoint ptr %v323 to i64
    call void @orion_map_set(ptr %v327, ptr %v319, i64 %v327.p0)
    call void @orion_map_set(ptr %v327, ptr %v324, i64 %v326)
    br label %if_267_merge
if_267_merge:
    %v330 = phi ptr [ %v316, %if_289_merge ], [ %v327, %if_267_else ]
    br label %if_235_merge
if_235_else:
    %v333 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v1)
    %v334 = add i64 0, 1
    %v335 = add i64 %v1, %v334
    %v336 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v335)
    %v337 = getelementptr i8, ptr @.str_248, i64 16
    %v338.e = call i64 @orion_text_eq(ptr %v336, ptr %v337)
    %v338 = add i64 %v338.e, 0
    %v339.cb = icmp ne i64 %v338, 0
    br i1 %v339.cb, label %if_339_then, label %if_339_else
if_339_then:
    %v341 = add i64 0, 1
    %v342 = add i64 %v1, %v341
    %v343 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v342)
    %v344 = getelementptr i8, ptr @.str_230, i64 16
    %v345.e = call i64 @orion_text_eq(ptr %v343, ptr %v344)
    %v345 = add i64 %v345.e, 0
    br label %if_339_merge
if_339_else:
    %v348 = add i64 0, 0
    br label %if_339_merge
if_339_merge:
    %v351 = phi i64 [ %v345, %if_339_then ], [ %v348, %if_339_else ]
    %v352.cb = icmp ne i64 %v351, 0
    br i1 %v352.cb, label %if_352_then, label %if_352_else
if_352_then:
    %v354 = add i64 0, 2
    %v355 = add i64 %v1, %v354
    %v356 = alloca i64, align 8
    store i64 %v355, ptr %v356
    %v357 = add i64 0, 0
    %v358 = getelementptr i8, ptr @.str_118, i64 16
    %v359 = getelementptr i8, ptr @.str_259, i64 16
    %v360 = getelementptr i8, ptr @.str_257, i64 16
    %v361 = getelementptr i8, ptr @.str_209, i64 16
    %v362 = call ptr @orion_map_new(i64 2)
    %v362.p0 = ptrtoint ptr %v359 to i64
    call void @orion_map_set(ptr %v362, ptr %v358, i64 %v362.p0)
    %v362.p1 = ptrtoint ptr %v361 to i64
    call void @orion_map_set(ptr %v362, ptr %v360, i64 %v362.p1)
    %v363 = call ptr @orion_list_new(i64 1)
    %v363.lp0 = ptrtoint ptr %v362 to i64
    call void @orion_list_set(ptr %v363, i64 0, i64 %v363.lp0)
    %v364 = add i64 0, 0
    %v365 = add i64 0, 0
    %v366 = call ptr @orion_list_slice(ptr %v363, i64 %v364, i64 %v365)
    %v367 = alloca ptr, align 8
    store ptr %v366, ptr %v367
    %v368 = add i64 0, 0
    br label %loop_369_header
loop_369_header:
    %v371 = load i64, ptr %v356
    %v372 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v371)
    %v373 = getelementptr i8, ptr @.str_248, i64 16
    %v374.e = call i64 @orion_text_eq(ptr %v372, ptr %v373)
    %v374 = add i64 %v374.e, 0
    %v375.cb = icmp ne i64 %v374, 0
    br i1 %v375.cb, label %if_375_then, label %if_375_else
if_375_then:
    %v377 = load i64, ptr %v356
    %v378 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v377)
    %v379 = getelementptr i8, ptr @.str_231, i64 16
    %v380.e = call i64 @orion_text_eq(ptr %v378, ptr %v379)
    %v380 = add i64 %v380.e, 0
    br label %if_375_merge
if_375_else:
    %v383 = add i64 0, 0
    br label %if_375_merge
if_375_merge:
    %v386 = phi i64 [ %v380, %if_375_then ], [ %v383, %if_375_else ]
    %v387.cb = icmp ne i64 %v386, 0
    br i1 %v387.cb, label %if_387_then, label %if_387_else
if_387_then:
    %v389 = load i64, ptr %v356
    %v390 = add i64 0, 1
    %v391 = add i64 %v389, %v390
    store i64 %v391, ptr %v356
    %v392 = add i64 0, 0
    br label %loop_369_end
if_387_else:
    br label %if_387_merge
if_387_merge:
    %v397 = load i64, ptr %v356
    %v398 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v397)
    %v399 = getelementptr i8, ptr @.str_249, i64 16
    %v400.e = call i64 @orion_text_eq(ptr %v398, ptr %v399)
    %v400 = add i64 %v400.e, 0
    %v401.cb = icmp ne i64 %v400, 0
    br i1 %v401.cb, label %if_401_then, label %if_401_else
if_401_then:
    br label %loop_369_end
if_401_else:
    br label %if_401_merge
if_401_merge:
    %v407 = load i64, ptr %v356
    %v408 = call ptr @prog__psr_parse_type(ptr %v0, i64 %v407)
    %v409 = load ptr, ptr %v367
    %v410 = getelementptr i8, ptr @.str_260, i64 16
    %v411.i = call i64 @orion_map_get(ptr %v408, ptr %v410)
    %v411.raw = inttoptr i64 %v411.i to ptr
    %v411.isnull = icmp eq i64 %v411.i, 0
    %v411 = select i1 %v411.isnull, ptr @orion_empty_list, ptr %v411.raw
    %v412.p = ptrtoint ptr %v411 to i64
    %v412 = call ptr @orion_list_push(ptr %v409, i64 %v412.p)
    store ptr %v412, ptr %v367
    %v413 = add i64 0, 0
    %v414 = getelementptr i8, ptr @.str_124, i64 16
    %v415 = call i64 @orion_map_get(ptr %v408, ptr %v414)
    store i64 %v415, ptr %v356
    %v416 = add i64 0, 0
    %v417 = load i64, ptr %v356
    %v418 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v417)
    %v419 = getelementptr i8, ptr @.str_248, i64 16
    %v420.e = call i64 @orion_text_eq(ptr %v418, ptr %v419)
    %v420 = add i64 %v420.e, 0
    %v421.cb = icmp ne i64 %v420, 0
    br i1 %v421.cb, label %if_421_then, label %if_421_else
if_421_then:
    %v423 = load i64, ptr %v356
    %v424 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v423)
    %v425 = getelementptr i8, ptr @.str_235, i64 16
    %v426.e = call i64 @orion_text_eq(ptr %v424, ptr %v425)
    %v426 = add i64 %v426.e, 0
    br label %if_421_merge
if_421_else:
    %v429 = add i64 0, 0
    br label %if_421_merge
if_421_merge:
    %v432 = phi i64 [ %v426, %if_421_then ], [ %v429, %if_421_else ]
    %v433.cb = icmp ne i64 %v432, 0
    br i1 %v433.cb, label %if_433_then, label %if_433_else
if_433_then:
    %v435 = load i64, ptr %v356
    %v436 = add i64 0, 1
    %v437 = add i64 %v435, %v436
    store i64 %v437, ptr %v356
    %v438 = add i64 0, 0
    br label %if_433_merge
if_433_else:
    br label %if_433_merge
if_433_merge:
    br label %loop_369_header
loop_369_end:
    %v445 = getelementptr i8, ptr @.str_260, i64 16
    %v446 = getelementptr i8, ptr @.str_118, i64 16
    %v447 = getelementptr i8, ptr @.str_259, i64 16
    %v448 = getelementptr i8, ptr @.str_257, i64 16
    %v449 = getelementptr i8, ptr @.str_253, i64 16
    %v450 = load ptr, ptr %v367
    %v451 = call ptr @orion_map_new(i64 3)
    %v451.p0 = ptrtoint ptr %v447 to i64
    call void @orion_map_set(ptr %v451, ptr %v446, i64 %v451.p0)
    %v451.p1 = ptrtoint ptr %v333 to i64
    call void @orion_map_set(ptr %v451, ptr %v448, i64 %v451.p1)
    %v451.p2 = ptrtoint ptr %v450 to i64
    call void @orion_map_set(ptr %v451, ptr %v449, i64 %v451.p2)
    %v452 = getelementptr i8, ptr @.str_124, i64 16
    %v453 = load i64, ptr %v356
    %v454 = call ptr @orion_map_new(i64 2)
    %v454.p0 = ptrtoint ptr %v451 to i64
    call void @orion_map_set(ptr %v454, ptr %v445, i64 %v454.p0)
    call void @orion_map_set(ptr %v454, ptr %v452, i64 %v453)
    br label %if_352_merge
if_352_else:
    %v457 = getelementptr i8, ptr @.str_260, i64 16
    %v458 = getelementptr i8, ptr @.str_118, i64 16
    %v459 = getelementptr i8, ptr @.str_259, i64 16
    %v460 = getelementptr i8, ptr @.str_257, i64 16
    %v461 = call ptr @orion_map_new(i64 2)
    %v461.p0 = ptrtoint ptr %v459 to i64
    call void @orion_map_set(ptr %v461, ptr %v458, i64 %v461.p0)
    %v461.p1 = ptrtoint ptr %v333 to i64
    call void @orion_map_set(ptr %v461, ptr %v460, i64 %v461.p1)
    %v462 = getelementptr i8, ptr @.str_124, i64 16
    %v463 = add i64 0, 1
    %v464 = add i64 %v1, %v463
    %v465 = call ptr @orion_map_new(i64 2)
    %v465.p0 = ptrtoint ptr %v461 to i64
    call void @orion_map_set(ptr %v465, ptr %v457, i64 %v465.p0)
    call void @orion_map_set(ptr %v465, ptr %v462, i64 %v464)
    br label %if_352_merge
if_352_merge:
    %v468 = phi ptr [ %v454, %loop_369_end ], [ %v465, %if_352_else ]
    br label %if_235_merge
if_235_merge:
    %v471 = phi ptr [ %v330, %if_267_merge ], [ %v468, %if_352_merge ]
    br label %if_183_merge
if_183_merge:
    %v474 = phi ptr [ %v229, %if_204_merge ], [ %v471, %if_235_merge ]
    ret ptr %v474
}

define ptr @prog__psr_parse_fn_type(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, 2
    %v3 = add i64 %v1, %v2
    %v4 = alloca i64, align 8
    store i64 %v3, ptr %v4
    %v5 = add i64 0, 0
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = alloca ptr, align 8
    store ptr %v6, ptr %v7
    %v8 = add i64 0, 0
    br label %loop_9_header
loop_9_header:
    %v11 = load i64, ptr %v4
    %v12 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v11)
    %v13 = load i64, ptr %v4
    %v14 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v13)
    %v15 = getelementptr i8, ptr @.str_248, i64 16
    %v16.e = call i64 @orion_text_eq(ptr %v12, ptr %v15)
    %v16 = add i64 %v16.e, 0
    %v17.cb = icmp ne i64 %v16, 0
    br i1 %v17.cb, label %if_17_then, label %if_17_else
if_17_then:
    %v19 = getelementptr i8, ptr @.str_234, i64 16
    %v20.e = call i64 @orion_text_eq(ptr %v14, ptr %v19)
    %v20 = add i64 %v20.e, 0
    br label %if_17_merge
if_17_else:
    %v23 = add i64 0, 0
    br label %if_17_merge
if_17_merge:
    %v26 = phi i64 [ %v20, %if_17_then ], [ %v23, %if_17_else ]
    %v27.cb = icmp ne i64 %v26, 0
    br i1 %v27.cb, label %if_27_then, label %if_27_else
if_27_then:
    %v29 = load i64, ptr %v4
    %v30 = add i64 0, 1
    %v31 = add i64 %v29, %v30
    store i64 %v31, ptr %v4
    %v32 = add i64 0, 0
    br label %loop_9_end
if_27_else:
    br label %if_27_merge
if_27_merge:
    %v37 = getelementptr i8, ptr @.str_249, i64 16
    %v38.e = call i64 @orion_text_eq(ptr %v12, ptr %v37)
    %v38 = add i64 %v38.e, 0
    %v39.cb = icmp ne i64 %v38, 0
    br i1 %v39.cb, label %if_39_then, label %if_39_else
if_39_then:
    br label %loop_9_end
if_39_else:
    br label %if_39_merge
if_39_merge:
    %v45 = load i64, ptr %v4
    %v46 = call ptr @prog__psr_parse_type(ptr %v0, i64 %v45)
    %v47 = load ptr, ptr %v7
    %v48 = getelementptr i8, ptr @.str_260, i64 16
    %v49.i = call i64 @orion_map_get(ptr %v46, ptr %v48)
    %v49.raw = inttoptr i64 %v49.i to ptr
    %v49.isnull = icmp eq i64 %v49.i, 0
    %v49 = select i1 %v49.isnull, ptr @orion_empty_list, ptr %v49.raw
    %v50.p = ptrtoint ptr %v49 to i64
    %v50 = call ptr @orion_list_push(ptr %v47, i64 %v50.p)
    store ptr %v50, ptr %v7
    %v51 = add i64 0, 0
    %v52 = getelementptr i8, ptr @.str_124, i64 16
    %v53 = call i64 @orion_map_get(ptr %v46, ptr %v52)
    store i64 %v53, ptr %v4
    %v54 = add i64 0, 0
    %v55 = load i64, ptr %v4
    %v56 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v55)
    %v57 = getelementptr i8, ptr @.str_248, i64 16
    %v58.e = call i64 @orion_text_eq(ptr %v56, ptr %v57)
    %v58 = add i64 %v58.e, 0
    %v59.cb = icmp ne i64 %v58, 0
    br i1 %v59.cb, label %if_59_then, label %if_59_else
if_59_then:
    %v61 = load i64, ptr %v4
    %v62 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v61)
    %v63 = getelementptr i8, ptr @.str_235, i64 16
    %v64.e = call i64 @orion_text_eq(ptr %v62, ptr %v63)
    %v64 = add i64 %v64.e, 0
    br label %if_59_merge
if_59_else:
    %v67 = add i64 0, 0
    br label %if_59_merge
if_59_merge:
    %v70 = phi i64 [ %v64, %if_59_then ], [ %v67, %if_59_else ]
    %v71.cb = icmp ne i64 %v70, 0
    br i1 %v71.cb, label %if_71_then, label %if_71_else
if_71_then:
    %v73 = load i64, ptr %v4
    %v74 = add i64 0, 1
    %v75 = add i64 %v73, %v74
    store i64 %v75, ptr %v4
    %v76 = add i64 0, 0
    br label %if_71_merge
if_71_else:
    br label %if_71_merge
if_71_merge:
    br label %loop_9_header
loop_9_end:
    %v83 = getelementptr i8, ptr @.str_118, i64 16
    %v84 = getelementptr i8, ptr @.str_259, i64 16
    %v85 = getelementptr i8, ptr @.str_257, i64 16
    %v86 = getelementptr i8, ptr @.str_272, i64 16
    %v87 = call ptr @orion_map_new(i64 2)
    %v87.p0 = ptrtoint ptr %v84 to i64
    call void @orion_map_set(ptr %v87, ptr %v83, i64 %v87.p0)
    %v87.p1 = ptrtoint ptr %v86 to i64
    call void @orion_map_set(ptr %v87, ptr %v85, i64 %v87.p1)
    %v88 = alloca ptr, align 8
    store ptr %v87, ptr %v88
    %v89 = add i64 0, 0
    %v90 = load i64, ptr %v4
    %v91 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v90)
    %v92 = getelementptr i8, ptr @.str_248, i64 16
    %v93.e = call i64 @orion_text_eq(ptr %v91, ptr %v92)
    %v93 = add i64 %v93.e, 0
    %v94.cb = icmp ne i64 %v93, 0
    br i1 %v94.cb, label %if_94_then, label %if_94_else
if_94_then:
    %v96 = load i64, ptr %v4
    %v97 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v96)
    %v98 = getelementptr i8, ptr @.str_220, i64 16
    %v99.e = call i64 @orion_text_eq(ptr %v97, ptr %v98)
    %v99 = add i64 %v99.e, 0
    br label %if_94_merge
if_94_else:
    %v102 = add i64 0, 0
    br label %if_94_merge
if_94_merge:
    %v105 = phi i64 [ %v99, %if_94_then ], [ %v102, %if_94_else ]
    %v106.cb = icmp ne i64 %v105, 0
    br i1 %v106.cb, label %if_106_then, label %if_106_else
if_106_then:
    %v108 = load i64, ptr %v4
    %v109 = add i64 0, 1
    %v110 = add i64 %v108, %v109
    store i64 %v110, ptr %v4
    %v111 = add i64 0, 0
    %v112 = load i64, ptr %v4
    %v113 = call ptr @prog__psr_parse_type(ptr %v0, i64 %v112)
    %v114 = getelementptr i8, ptr @.str_260, i64 16
    %v115.i = call i64 @orion_map_get(ptr %v113, ptr %v114)
    %v115.raw = inttoptr i64 %v115.i to ptr
    %v115.isnull = icmp eq i64 %v115.i, 0
    %v115 = select i1 %v115.isnull, ptr @orion_empty_list, ptr %v115.raw
    store ptr %v115, ptr %v88
    %v116 = add i64 0, 0
    %v117 = getelementptr i8, ptr @.str_124, i64 16
    %v118 = call i64 @orion_map_get(ptr %v113, ptr %v117)
    store i64 %v118, ptr %v4
    %v119 = add i64 0, 0
    br label %if_106_merge
if_106_else:
    br label %if_106_merge
if_106_merge:
    %v124 = getelementptr i8, ptr @.str_260, i64 16
    %v125 = getelementptr i8, ptr @.str_118, i64 16
    %v126 = getelementptr i8, ptr @.str_273, i64 16
    %v127 = getelementptr i8, ptr @.str_274, i64 16
    %v128 = load ptr, ptr %v7
    %v129 = getelementptr i8, ptr @.str_275, i64 16
    %v130 = load ptr, ptr %v88
    %v131 = call ptr @orion_map_new(i64 3)
    %v131.p0 = ptrtoint ptr %v126 to i64
    call void @orion_map_set(ptr %v131, ptr %v125, i64 %v131.p0)
    %v131.p1 = ptrtoint ptr %v128 to i64
    call void @orion_map_set(ptr %v131, ptr %v127, i64 %v131.p1)
    %v131.p2 = ptrtoint ptr %v130 to i64
    call void @orion_map_set(ptr %v131, ptr %v129, i64 %v131.p2)
    %v132 = getelementptr i8, ptr @.str_124, i64 16
    %v133 = load i64, ptr %v4
    %v134 = call ptr @orion_map_new(i64 2)
    %v134.p0 = ptrtoint ptr %v131 to i64
    call void @orion_map_set(ptr %v134, ptr %v124, i64 %v134.p0)
    call void @orion_map_set(ptr %v134, ptr %v132, i64 %v133)
    ret ptr %v134
}

define ptr @prog__psr_parse_arm_body(ptr %p0, i64 %p1, i64 %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v1)
    %v4 = getelementptr i8, ptr @.str_211, i64 16
    %v5.e = call i64 @orion_text_eq(ptr %v3, ptr %v4)
    %v5 = add i64 %v5.e, 0
    %v6.cb = icmp ne i64 %v5, 0
    br i1 %v6.cb, label %if_6_then, label %if_6_else
if_6_then:
    %v8 = call i64 @prog__psr_skip_newlines(ptr %v0, i64 %v1)
    %v9 = call i64 @prog__psr_peek_col(ptr %v0, i64 %v8)
    %v10.b = icmp sgt i64 %v9, %v2
    %v10 = zext i1 %v10.b to i64
    %v11.cb = icmp ne i64 %v10, 0
    br i1 %v11.cb, label %if_11_then, label %if_11_else
if_11_then:
    %v13 = call ptr @prog__psr_parse_body_at(ptr %v0, i64 %v8, i64 %v9)
    ret ptr %v13
if_11_else:
    br label %if_11_merge
if_11_merge:
    br label %if_6_merge
if_6_else:
    br label %if_6_merge
if_6_merge:
    %v22 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v1)
    %v23 = getelementptr i8, ptr @.str_123, i64 16
    %v24.e = call i64 @orion_text_eq(ptr %v22, ptr %v23)
    %v24 = add i64 %v24.e, 0
    %v25.cb = icmp ne i64 %v24, 0
    br i1 %v25.cb, label %if_25_then, label %if_25_else
if_25_then:
    %v27 = add i64 0, 1
    %v28 = add i64 %v1, %v27
    %v29 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v28)
    %v30 = getelementptr i8, ptr @.str_248, i64 16
    %v31.e = call i64 @orion_text_eq(ptr %v29, ptr %v30)
    %v31 = add i64 %v31.e, 0
    br label %if_25_merge
if_25_else:
    %v34 = add i64 0, 0
    br label %if_25_merge
if_25_merge:
    %v37 = phi i64 [ %v31, %if_25_then ], [ %v34, %if_25_else ]
    %v38.cb = icmp ne i64 %v37, 0
    br i1 %v38.cb, label %if_38_then, label %if_38_else
if_38_then:
    %v40 = add i64 0, 1
    %v41 = add i64 %v1, %v40
    %v42 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v41)
    %v43 = getelementptr i8, ptr @.str_229, i64 16
    %v44.e = call i64 @orion_text_eq(ptr %v42, ptr %v43)
    %v44 = add i64 %v44.e, 0
    %v45.cb = icmp ne i64 %v44, 0
    br i1 %v45.cb, label %if_45_then, label %if_45_else
if_45_then:
    br label %if_45_merge
if_45_else:
    %v49 = getelementptr i8, ptr @.str_221, i64 16
    %v50.e = call i64 @orion_text_eq(ptr %v42, ptr %v49)
    %v50 = add i64 %v50.e, 0
    br label %if_45_merge
if_45_merge:
    %v53 = phi i64 [ %v44, %if_45_then ], [ %v50, %if_45_else ]
    %v54.cb = icmp ne i64 %v53, 0
    br i1 %v54.cb, label %if_54_then, label %if_54_else
if_54_then:
    br label %if_54_merge
if_54_else:
    %v58 = getelementptr i8, ptr @.str_222, i64 16
    %v59.e = call i64 @orion_text_eq(ptr %v42, ptr %v58)
    %v59 = add i64 %v59.e, 0
    br label %if_54_merge
if_54_merge:
    %v62 = phi i64 [ %v53, %if_54_then ], [ %v59, %if_54_else ]
    %v63.cb = icmp ne i64 %v62, 0
    br i1 %v63.cb, label %if_63_then, label %if_63_else
if_63_then:
    br label %if_63_merge
if_63_else:
    %v67 = getelementptr i8, ptr @.str_223, i64 16
    %v68.e = call i64 @orion_text_eq(ptr %v42, ptr %v67)
    %v68 = add i64 %v68.e, 0
    br label %if_63_merge
if_63_merge:
    %v71 = phi i64 [ %v62, %if_63_then ], [ %v68, %if_63_else ]
    %v72.cb = icmp ne i64 %v71, 0
    br i1 %v72.cb, label %if_72_then, label %if_72_else
if_72_then:
    br label %if_72_merge
if_72_else:
    %v76 = getelementptr i8, ptr @.str_224, i64 16
    %v77.e = call i64 @orion_text_eq(ptr %v42, ptr %v76)
    %v77 = add i64 %v77.e, 0
    br label %if_72_merge
if_72_merge:
    %v80 = phi i64 [ %v71, %if_72_then ], [ %v77, %if_72_else ]
    %v81.cb = icmp ne i64 %v80, 0
    br i1 %v81.cb, label %if_81_then, label %if_81_else
if_81_then:
    %v83 = call i64 @prog__psr_peek_col(ptr %v0, i64 %v1)
    %v84 = call ptr @prog__psr_parse_body_at(ptr %v0, i64 %v1, i64 %v83)
    ret ptr %v84
if_81_else:
    br label %if_81_merge
if_81_merge:
    br label %if_38_merge
if_38_else:
    br label %if_38_merge
if_38_merge:
    %v93 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v1)
    %v94 = getelementptr i8, ptr @.str_123, i64 16
    %v95.e = call i64 @orion_text_eq(ptr %v93, ptr %v94)
    %v95 = add i64 %v95.e, 0
    %v96.cb = icmp ne i64 %v95, 0
    br i1 %v96.cb, label %if_96_then, label %if_96_else
if_96_then:
    %v98 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v1)
    %v99 = getelementptr i8, ptr @.str_157, i64 16
    %v100.e = call i64 @orion_text_eq(ptr %v98, ptr %v99)
    %v100 = add i64 %v100.e, 0
    %v101.cb = icmp ne i64 %v100, 0
    br i1 %v101.cb, label %if_101_then, label %if_101_else
if_101_then:
    br label %if_101_merge
if_101_else:
    %v105 = getelementptr i8, ptr @.str_159, i64 16
    %v106.e = call i64 @orion_text_eq(ptr %v98, ptr %v105)
    %v106 = add i64 %v106.e, 0
    br label %if_101_merge
if_101_merge:
    %v109 = phi i64 [ %v100, %if_101_then ], [ %v106, %if_101_else ]
    %v110.cb = icmp ne i64 %v109, 0
    br i1 %v110.cb, label %if_110_then, label %if_110_else
if_110_then:
    br label %if_110_merge
if_110_else:
    %v114 = getelementptr i8, ptr @.str_20, i64 16
    %v115.e = call i64 @orion_text_eq(ptr %v98, ptr %v114)
    %v115 = add i64 %v115.e, 0
    br label %if_110_merge
if_110_merge:
    %v118 = phi i64 [ %v109, %if_110_then ], [ %v115, %if_110_else ]
    %v119.cb = icmp ne i64 %v118, 0
    br i1 %v119.cb, label %if_119_then, label %if_119_else
if_119_then:
    %v121 = call i64 @prog__psr_peek_col(ptr %v0, i64 %v1)
    %v122 = call ptr @prog__psr_parse_body_at(ptr %v0, i64 %v1, i64 %v121)
    ret ptr %v122
if_119_else:
    br label %if_119_merge
if_119_merge:
    br label %if_96_merge
if_96_else:
    br label %if_96_merge
if_96_merge:
    %v131 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v1)
    ret ptr %v131
}

define ptr @prog__psr_parse_sub_pattern(ptr %p0, i64 %p1, ptr %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr %p2, i64 0
    %v3 = alloca i64, align 8
    store i64 %v1, ptr %v3
    %v4 = add i64 0, 0
    %v5 = alloca ptr, align 8
    store ptr %v2, ptr %v5
    %v6 = add i64 0, 0
    %v7 = load i64, ptr %v3
    %v8 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v7)
    %v9 = getelementptr i8, ptr @.str_248, i64 16
    %v10.e = call i64 @orion_text_eq(ptr %v8, ptr %v9)
    %v10 = add i64 %v10.e, 0
    %v11.cb = icmp ne i64 %v10, 0
    br i1 %v11.cb, label %if_11_then, label %if_11_else
if_11_then:
    %v13 = load i64, ptr %v3
    %v14 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v13)
    %v15 = getelementptr i8, ptr @.str_233, i64 16
    %v16.e = call i64 @orion_text_eq(ptr %v14, ptr %v15)
    %v16 = add i64 %v16.e, 0
    br label %if_11_merge
if_11_else:
    %v19 = add i64 0, 0
    br label %if_11_merge
if_11_merge:
    %v22 = phi i64 [ %v16, %if_11_then ], [ %v19, %if_11_else ]
    %v23.cb = icmp ne i64 %v22, 0
    br i1 %v23.cb, label %if_23_then, label %if_23_else
if_23_then:
    %v25 = load i64, ptr %v3
    %v26 = add i64 0, 1
    %v27 = add i64 %v25, %v26
    store i64 %v27, ptr %v3
    %v28 = add i64 0, 0
    %v29 = getelementptr i8, ptr @.str_5, i64 16
    %v30 = alloca ptr, align 8
    store ptr %v29, ptr %v30
    %v31 = add i64 0, 0
    br label %loop_32_header
loop_32_header:
    %v34 = load i64, ptr %v3
    %v35 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v34)
    %v36 = load i64, ptr %v3
    %v37 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v36)
    %v38 = getelementptr i8, ptr @.str_249, i64 16
    %v39.e = call i64 @orion_text_eq(ptr %v35, ptr %v38)
    %v39 = add i64 %v39.e, 0
    %v40.cb = icmp ne i64 %v39, 0
    br i1 %v40.cb, label %if_40_then, label %if_40_else
if_40_then:
    br label %loop_32_end
if_40_else:
    br label %if_40_merge
if_40_merge:
    %v46 = getelementptr i8, ptr @.str_248, i64 16
    %v47.e = call i64 @orion_text_eq(ptr %v35, ptr %v46)
    %v47 = add i64 %v47.e, 0
    %v48.cb = icmp ne i64 %v47, 0
    br i1 %v48.cb, label %if_48_then, label %if_48_else
if_48_then:
    %v50 = getelementptr i8, ptr @.str_234, i64 16
    %v51.e = call i64 @orion_text_eq(ptr %v37, ptr %v50)
    %v51 = add i64 %v51.e, 0
    br label %if_48_merge
if_48_else:
    %v54 = add i64 0, 0
    br label %if_48_merge
if_48_merge:
    %v57 = phi i64 [ %v51, %if_48_then ], [ %v54, %if_48_else ]
    %v58.cb = icmp ne i64 %v57, 0
    br i1 %v58.cb, label %if_58_then, label %if_58_else
if_58_then:
    %v60 = load i64, ptr %v3
    %v61 = add i64 0, 1
    %v62 = add i64 %v60, %v61
    store i64 %v62, ptr %v3
    %v63 = add i64 0, 0
    br label %loop_32_end
if_58_else:
    br label %if_58_merge
if_58_merge:
    %v68 = getelementptr i8, ptr @.str_123, i64 16
    %v69.e = call i64 @orion_text_eq(ptr %v35, ptr %v68)
    %v69 = add i64 %v69.e, 0
    %v70.cb = icmp ne i64 %v69, 0
    br i1 %v70.cb, label %if_70_then, label %if_70_else
if_70_then:
    %v72 = load ptr, ptr %v30
    %v73 = call i64 @orion_tlen(ptr %v72)
    %v74 = add i64 0, 0
    %v75.b = icmp eq i64 %v73, %v74
    %v75 = zext i1 %v75.b to i64
    %v76.cb = icmp ne i64 %v75, 0
    br i1 %v76.cb, label %if_76_then, label %if_76_else
if_76_then:
    %v78 = getelementptr i8, ptr @.str_5, i64 16
    br label %if_76_merge
if_76_else:
    %v81 = getelementptr i8, ptr @.str_235, i64 16
    br label %if_76_merge
if_76_merge:
    %v84 = phi ptr [ %v78, %if_76_then ], [ %v81, %if_76_else ]
    %v85 = load ptr, ptr %v30
    %v86 = call ptr @orion_text_concat(ptr %v85, ptr %v84)
    %v87 = call ptr @orion_text_concat(ptr %v86, ptr %v37)
    store ptr %v87, ptr %v30
    %v88 = add i64 0, 0
    br label %if_70_merge
if_70_else:
    br label %if_70_merge
if_70_merge:
    %v93 = load i64, ptr %v3
    %v94 = add i64 0, 1
    %v95 = add i64 %v93, %v94
    store i64 %v95, ptr %v3
    %v96 = add i64 0, 0
    br label %loop_32_header
loop_32_end:
    %v99 = getelementptr i8, ptr @.str_243, i64 16
    %v100 = call ptr @orion_text_concat(ptr %v99, ptr %v2)
    %v101 = getelementptr i8, ptr @.str_236, i64 16
    %v102 = call ptr @orion_text_concat(ptr %v100, ptr %v101)
    %v103 = load ptr, ptr %v30
    %v104 = call ptr @orion_text_concat(ptr %v102, ptr %v103)
    store ptr %v104, ptr %v5
    %v105 = add i64 0, 0
    br label %if_23_merge
if_23_else:
    br label %if_23_merge
if_23_merge:
    %v110 = getelementptr i8, ptr @.str_276, i64 16
    %v111 = load ptr, ptr %v5
    %v112 = getelementptr i8, ptr @.str_124, i64 16
    %v113 = load i64, ptr %v3
    %v114 = call ptr @orion_map_new(i64 2)
    %v114.p0 = ptrtoint ptr %v111 to i64
    call void @orion_map_set(ptr %v114, ptr %v110, i64 %v114.p0)
    call void @orion_map_set(ptr %v114, ptr %v112, i64 %v113)
    ret ptr %v114
}

define ptr @prog__psr_parse_match_node(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, 1
    %v3 = add i64 %v1, %v2
    %v4 = alloca i64, align 8
    store i64 %v3, ptr %v4
    %v5 = add i64 0, 0
    %v6 = load i64, ptr %v4
    %v7 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v6)
    %v8 = getelementptr i8, ptr @.str_248, i64 16
    %v9.e = call i64 @orion_text_eq(ptr %v7, ptr %v8)
    %v9 = add i64 %v9.e, 0
    %v10.cb = icmp ne i64 %v9, 0
    br i1 %v10.cb, label %if_10_then, label %if_10_else
if_10_then:
    %v12 = load i64, ptr %v4
    %v13 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v12)
    %v14 = getelementptr i8, ptr @.str_236, i64 16
    %v15.e = call i64 @orion_text_eq(ptr %v13, ptr %v14)
    %v15 = add i64 %v15.e, 0
    br label %if_10_merge
if_10_else:
    %v18 = add i64 0, 0
    br label %if_10_merge
if_10_merge:
    %v21 = phi i64 [ %v15, %if_10_then ], [ %v18, %if_10_else ]
    %v22.cb = icmp ne i64 %v21, 0
    br i1 %v22.cb, label %if_22_then, label %if_22_else
if_22_then:
    %v24 = load i64, ptr %v4
    %v25 = add i64 0, 1
    %v26 = add i64 %v24, %v25
    %v27 = call ptr @prog__psr_parse_cond_match(ptr %v0, i64 %v26)
    ret ptr %v27
if_22_else:
    br label %if_22_merge
if_22_merge:
    %v32 = load i64, ptr %v4
    %v33 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v32)
    %v34 = getelementptr i8, ptr @.str_124, i64 16
    %v35 = call i64 @orion_map_get(ptr %v33, ptr %v34)
    store i64 %v35, ptr %v4
    %v36 = add i64 0, 0
    %v37 = load i64, ptr %v4
    %v38 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v37)
    %v39 = getelementptr i8, ptr @.str_248, i64 16
    %v40.e = call i64 @orion_text_eq(ptr %v38, ptr %v39)
    %v40 = add i64 %v40.e, 0
    %v41.cb = icmp ne i64 %v40, 0
    br i1 %v41.cb, label %if_41_then, label %if_41_else
if_41_then:
    %v43 = load i64, ptr %v4
    %v44 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v43)
    %v45 = getelementptr i8, ptr @.str_236, i64 16
    %v46.e = call i64 @orion_text_eq(ptr %v44, ptr %v45)
    %v46 = add i64 %v46.e, 0
    br label %if_41_merge
if_41_else:
    %v49 = add i64 0, 0
    br label %if_41_merge
if_41_merge:
    %v52 = phi i64 [ %v46, %if_41_then ], [ %v49, %if_41_else ]
    %v53.cb = icmp ne i64 %v52, 0
    br i1 %v53.cb, label %if_53_then, label %if_53_else
if_53_then:
    %v55 = load i64, ptr %v4
    %v56 = add i64 0, 1
    %v57 = add i64 %v55, %v56
    store i64 %v57, ptr %v4
    %v58 = add i64 0, 0
    br label %if_53_merge
if_53_else:
    br label %if_53_merge
if_53_merge:
    %v63 = load i64, ptr %v4
    %v64 = call i64 @prog__psr_skip_newlines(ptr %v0, i64 %v63)
    store i64 %v64, ptr %v4
    %v65 = add i64 0, 0
    %v66 = load i64, ptr %v4
    %v67 = call i64 @prog__psr_peek_col(ptr %v0, i64 %v66)
    %v68 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v69 = alloca ptr, align 8
    store ptr %v68, ptr %v69
    %v70 = add i64 0, 0
    br label %loop_71_header
loop_71_header:
    %v73 = load i64, ptr %v4
    %v74 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v73)
    %v75 = load i64, ptr %v4
    %v76 = call i64 @prog__psr_peek_col(ptr %v0, i64 %v75)
    %v77 = getelementptr i8, ptr @.str_249, i64 16
    %v78.e = call i64 @orion_text_eq(ptr %v74, ptr %v77)
    %v78 = add i64 %v78.e, 0
    %v79.cb = icmp ne i64 %v78, 0
    br i1 %v79.cb, label %if_79_then, label %if_79_else
if_79_then:
    br label %loop_71_end
if_79_else:
    br label %if_79_merge
if_79_merge:
    %v85.b = icmp slt i64 %v76, %v67
    %v85 = zext i1 %v85.b to i64
    %v86.cb = icmp ne i64 %v85, 0
    br i1 %v86.cb, label %if_86_then, label %if_86_else
if_86_then:
    br label %loop_71_end
if_86_else:
    br label %if_86_merge
if_86_merge:
    %v92 = load i64, ptr %v4
    %v93 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v92)
    %v94 = alloca ptr, align 8
    store ptr %v93, ptr %v94
    %v95 = add i64 0, 0
    %v96 = load i64, ptr %v4
    %v97 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v96)
    %v98 = alloca ptr, align 8
    store ptr %v97, ptr %v98
    %v99 = add i64 0, 0
    %v100 = load ptr, ptr %v98
    %v101 = getelementptr i8, ptr @.str_248, i64 16
    %v102.e = call i64 @orion_text_eq(ptr %v100, ptr %v101)
    %v102 = add i64 %v102.e, 0
    %v103.cb = icmp ne i64 %v102, 0
    br i1 %v103.cb, label %if_103_then, label %if_103_else
if_103_then:
    %v105 = load ptr, ptr %v94
    %v106 = getelementptr i8, ptr @.str_233, i64 16
    %v107.e = call i64 @orion_text_eq(ptr %v105, ptr %v106)
    %v107 = add i64 %v107.e, 0
    br label %if_103_merge
if_103_else:
    %v110 = add i64 0, 0
    br label %if_103_merge
if_103_merge:
    %v113 = phi i64 [ %v107, %if_103_then ], [ %v110, %if_103_else ]
    %v114 = load i64, ptr %v4
    %v115 = add i64 0, 1
    %v116 = add i64 %v114, %v115
    store i64 %v116, ptr %v4
    %v117 = add i64 0, 0
    %v118 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v119 = alloca ptr, align 8
    store ptr %v118, ptr %v119
    %v120 = add i64 0, 0
    %v121.cb = icmp ne i64 %v113, 0
    br i1 %v121.cb, label %if_121_then, label %if_121_else
if_121_then:
    %v123 = getelementptr i8, ptr @.str_277, i64 16
    store ptr %v123, ptr %v98
    %v124 = add i64 0, 0
    %v125 = getelementptr i8, ptr @.str_277, i64 16
    store ptr %v125, ptr %v94
    %v126 = add i64 0, 0
    br label %loop_127_header
loop_127_header:
    %v129 = load i64, ptr %v4
    %v130 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v129)
    %v131 = load i64, ptr %v4
    %v132 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v131)
    %v133 = load i64, ptr %v4
    %v134 = getelementptr i8, ptr @.str_248, i64 16
    %v135.e = call i64 @orion_text_eq(ptr %v130, ptr %v134)
    %v135 = add i64 %v135.e, 0
    %v136.cb = icmp ne i64 %v135, 0
    br i1 %v136.cb, label %if_136_then, label %if_136_else
if_136_then:
    %v138 = getelementptr i8, ptr @.str_234, i64 16
    %v139.e = call i64 @orion_text_eq(ptr %v132, ptr %v138)
    %v139 = add i64 %v139.e, 0
    br label %if_136_merge
if_136_else:
    %v142 = add i64 0, 0
    br label %if_136_merge
if_136_merge:
    %v145 = phi i64 [ %v139, %if_136_then ], [ %v142, %if_136_else ]
    %v146.cb = icmp ne i64 %v145, 0
    br i1 %v146.cb, label %if_146_then, label %if_146_else
if_146_then:
    %v148 = load i64, ptr %v4
    %v149 = add i64 0, 1
    %v150 = add i64 %v148, %v149
    store i64 %v150, ptr %v4
    %v151 = add i64 0, 0
    br label %loop_127_end
if_146_else:
    br label %if_146_merge
if_146_merge:
    %v156 = getelementptr i8, ptr @.str_249, i64 16
    %v157.e = call i64 @orion_text_eq(ptr %v130, ptr %v156)
    %v157 = add i64 %v157.e, 0
    %v158.cb = icmp ne i64 %v157, 0
    br i1 %v158.cb, label %if_158_then, label %if_158_else
if_158_then:
    br label %loop_127_end
if_158_else:
    br label %if_158_merge
if_158_merge:
    %v164 = getelementptr i8, ptr @.str_123, i64 16
    %v165.e = call i64 @orion_text_eq(ptr %v130, ptr %v164)
    %v165 = add i64 %v165.e, 0
    %v166.cb = icmp ne i64 %v165, 0
    br i1 %v166.cb, label %if_166_then, label %if_166_else
if_166_then:
    %v168 = load ptr, ptr %v119
    %v169.p = ptrtoint ptr %v132 to i64
    %v169 = call ptr @orion_list_push(ptr %v168, i64 %v169.p)
    store ptr %v169, ptr %v119
    %v170 = add i64 0, 0
    %v171 = load i64, ptr %v4
    %v172 = add i64 0, 1
    %v173 = add i64 %v171, %v172
    store i64 %v173, ptr %v4
    %v174 = add i64 0, 0
    br label %if_166_merge
if_166_else:
    br label %if_166_merge
if_166_merge:
    %v179 = getelementptr i8, ptr @.str_248, i64 16
    %v180.e = call i64 @orion_text_eq(ptr %v130, ptr %v179)
    %v180 = add i64 %v180.e, 0
    %v181.cb = icmp ne i64 %v180, 0
    br i1 %v181.cb, label %if_181_then, label %if_181_else
if_181_then:
    %v183 = getelementptr i8, ptr @.str_235, i64 16
    %v184.e = call i64 @orion_text_eq(ptr %v132, ptr %v183)
    %v184 = add i64 %v184.e, 0
    br label %if_181_merge
if_181_else:
    %v187 = add i64 0, 0
    br label %if_181_merge
if_181_merge:
    %v190 = phi i64 [ %v184, %if_181_then ], [ %v187, %if_181_else ]
    %v191.cb = icmp ne i64 %v190, 0
    br i1 %v191.cb, label %if_191_then, label %if_191_else
if_191_then:
    %v193 = load i64, ptr %v4
    %v194 = add i64 0, 1
    %v195 = add i64 %v193, %v194
    store i64 %v195, ptr %v4
    %v196 = add i64 0, 0
    br label %if_191_merge
if_191_else:
    br label %if_191_merge
if_191_merge:
    %v201 = load i64, ptr %v4
    %v202.b = icmp eq i64 %v201, %v133
    %v202 = zext i1 %v202.b to i64
    %v203.cb = icmp ne i64 %v202, 0
    br i1 %v203.cb, label %if_203_then, label %if_203_else
if_203_then:
    %v205 = load i64, ptr %v4
    %v206 = add i64 0, 1
    %v207 = add i64 %v205, %v206
    store i64 %v207, ptr %v4
    %v208 = add i64 0, 0
    br label %if_203_merge
if_203_else:
    br label %if_203_merge
if_203_merge:
    br label %loop_127_header
loop_127_end:
    br label %if_121_merge
if_121_else:
    br label %if_121_merge
if_121_merge:
    %v219.n = icmp eq i64 %v113, 0
    %v219 = zext i1 %v219.n to i64
    %v220.cb = icmp ne i64 %v219, 0
    br i1 %v220.cb, label %if_220_then, label %if_220_else
if_220_then:
    %v222 = load i64, ptr %v4
    %v223 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v222)
    %v224 = getelementptr i8, ptr @.str_248, i64 16
    %v225.e = call i64 @orion_text_eq(ptr %v223, ptr %v224)
    %v225 = add i64 %v225.e, 0
    br label %if_220_merge
if_220_else:
    %v228 = add i64 0, 0
    br label %if_220_merge
if_220_merge:
    %v231 = phi i64 [ %v225, %if_220_then ], [ %v228, %if_220_else ]
    %v232.cb = icmp ne i64 %v231, 0
    br i1 %v232.cb, label %if_232_then, label %if_232_else
if_232_then:
    %v234 = load i64, ptr %v4
    %v235 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v234)
    %v236 = getelementptr i8, ptr @.str_233, i64 16
    %v237.e = call i64 @orion_text_eq(ptr %v235, ptr %v236)
    %v237 = add i64 %v237.e, 0
    br label %if_232_merge
if_232_else:
    %v240 = add i64 0, 0
    br label %if_232_merge
if_232_merge:
    %v243 = phi i64 [ %v237, %if_232_then ], [ %v240, %if_232_else ]
    %v244.cb = icmp ne i64 %v243, 0
    br i1 %v244.cb, label %if_244_then, label %if_244_else
if_244_then:
    %v246 = load i64, ptr %v4
    %v247 = add i64 0, 1
    %v248 = add i64 %v246, %v247
    store i64 %v248, ptr %v4
    %v249 = add i64 0, 0
    br label %loop_250_header
loop_250_header:
    %v252 = load i64, ptr %v4
    %v253 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v252)
    %v254 = load i64, ptr %v4
    %v255 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v254)
    %v256 = load i64, ptr %v4
    %v257 = getelementptr i8, ptr @.str_248, i64 16
    %v258.e = call i64 @orion_text_eq(ptr %v253, ptr %v257)
    %v258 = add i64 %v258.e, 0
    %v259.cb = icmp ne i64 %v258, 0
    br i1 %v259.cb, label %if_259_then, label %if_259_else
if_259_then:
    %v261 = getelementptr i8, ptr @.str_234, i64 16
    %v262.e = call i64 @orion_text_eq(ptr %v255, ptr %v261)
    %v262 = add i64 %v262.e, 0
    br label %if_259_merge
if_259_else:
    %v265 = add i64 0, 0
    br label %if_259_merge
if_259_merge:
    %v268 = phi i64 [ %v262, %if_259_then ], [ %v265, %if_259_else ]
    %v269.cb = icmp ne i64 %v268, 0
    br i1 %v269.cb, label %if_269_then, label %if_269_else
if_269_then:
    %v271 = load i64, ptr %v4
    %v272 = add i64 0, 1
    %v273 = add i64 %v271, %v272
    store i64 %v273, ptr %v4
    %v274 = add i64 0, 0
    br label %loop_250_end
if_269_else:
    br label %if_269_merge
if_269_merge:
    %v279 = getelementptr i8, ptr @.str_249, i64 16
    %v280.e = call i64 @orion_text_eq(ptr %v253, ptr %v279)
    %v280 = add i64 %v280.e, 0
    %v281.cb = icmp ne i64 %v280, 0
    br i1 %v281.cb, label %if_281_then, label %if_281_else
if_281_then:
    br label %loop_250_end
if_281_else:
    br label %if_281_merge
if_281_merge:
    %v287 = getelementptr i8, ptr @.str_123, i64 16
    %v288.e = call i64 @orion_text_eq(ptr %v253, ptr %v287)
    %v288 = add i64 %v288.e, 0
    %v289.cb = icmp ne i64 %v288, 0
    br i1 %v289.cb, label %if_289_then, label %if_289_else
if_289_then:
    %v291 = load i64, ptr %v4
    %v292 = add i64 0, 1
    %v293 = add i64 %v291, %v292
    %v294 = call ptr @prog__psr_parse_sub_pattern(ptr %v0, i64 %v293, ptr %v255)
    %v295 = load ptr, ptr %v119
    %v296 = getelementptr i8, ptr @.str_276, i64 16
    %v297.i = call i64 @orion_map_get(ptr %v294, ptr %v296)
    %v297.raw = inttoptr i64 %v297.i to ptr
    %v297.isnull = icmp eq i64 %v297.i, 0
    %v297 = select i1 %v297.isnull, ptr getelementptr(i8, ptr @.str_empty_h, i64 16), ptr %v297.raw
    %v298.p = ptrtoint ptr %v297 to i64
    %v298 = call ptr @orion_list_push(ptr %v295, i64 %v298.p)
    store ptr %v298, ptr %v119
    %v299 = add i64 0, 0
    %v300 = getelementptr i8, ptr @.str_124, i64 16
    %v301 = call i64 @orion_map_get(ptr %v294, ptr %v300)
    store i64 %v301, ptr %v4
    %v302 = add i64 0, 0
    br label %if_289_merge
if_289_else:
    br label %if_289_merge
if_289_merge:
    %v307 = getelementptr i8, ptr @.str_248, i64 16
    %v308.e = call i64 @orion_text_eq(ptr %v253, ptr %v307)
    %v308 = add i64 %v308.e, 0
    %v309.cb = icmp ne i64 %v308, 0
    br i1 %v309.cb, label %if_309_then, label %if_309_else
if_309_then:
    %v311 = getelementptr i8, ptr @.str_235, i64 16
    %v312.e = call i64 @orion_text_eq(ptr %v255, ptr %v311)
    %v312 = add i64 %v312.e, 0
    br label %if_309_merge
if_309_else:
    %v315 = add i64 0, 0
    br label %if_309_merge
if_309_merge:
    %v318 = phi i64 [ %v312, %if_309_then ], [ %v315, %if_309_else ]
    %v319.cb = icmp ne i64 %v318, 0
    br i1 %v319.cb, label %if_319_then, label %if_319_else
if_319_then:
    %v321 = load i64, ptr %v4
    %v322 = add i64 0, 1
    %v323 = add i64 %v321, %v322
    store i64 %v323, ptr %v4
    %v324 = add i64 0, 0
    br label %if_319_merge
if_319_else:
    br label %if_319_merge
if_319_merge:
    %v329 = load i64, ptr %v4
    %v330.b = icmp eq i64 %v329, %v256
    %v330 = zext i1 %v330.b to i64
    %v331.cb = icmp ne i64 %v330, 0
    br i1 %v331.cb, label %if_331_then, label %if_331_else
if_331_then:
    %v333 = load i64, ptr %v4
    %v334 = add i64 0, 1
    %v335 = add i64 %v333, %v334
    store i64 %v335, ptr %v4
    %v336 = add i64 0, 0
    br label %if_331_merge
if_331_else:
    br label %if_331_merge
if_331_merge:
    br label %loop_250_header
loop_250_end:
    br label %if_244_merge
if_244_else:
    br label %if_244_merge
if_244_merge:
    %v347 = add i64 0, 0
    %v348 = call ptr @orion_list_new(i64 1)
    call void @orion_list_set(ptr %v348, i64 0, i64 %v347)
    %v349 = add i64 0, 0
    %v350 = add i64 0, 0
    %v351 = call ptr @orion_list_slice(ptr %v348, i64 %v349, i64 %v350)
    %v352 = alloca ptr, align 8
    store ptr %v351, ptr %v352
    %v353 = add i64 0, 0
    br label %loop_354_header
loop_354_header:
    %v356 = load i64, ptr %v4
    %v357 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v356)
    %v358 = getelementptr i8, ptr @.str_248, i64 16
    %v359.e = call i64 @orion_text_eq(ptr %v357, ptr %v358)
    %v359 = add i64 %v359.e, 0
    %v360.cb = icmp ne i64 %v359, 0
    br i1 %v360.cb, label %if_360_then, label %if_360_else
if_360_then:
    %v362 = load i64, ptr %v4
    %v363 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v362)
    %v364 = getelementptr i8, ptr @.str_95, i64 16
    %v365.e = call i64 @orion_text_eq(ptr %v363, ptr %v364)
    %v365 = add i64 %v365.e, 0
    br label %if_360_merge
if_360_else:
    %v368 = add i64 0, 0
    br label %if_360_merge
if_360_merge:
    %v371 = phi i64 [ %v365, %if_360_then ], [ %v368, %if_360_else ]
    %v372.cb = icmp ne i64 %v371, 0
    br i1 %v372.cb, label %if_372_then, label %if_372_else
if_372_then:
    %v374 = load i64, ptr %v4
    %v375 = add i64 0, 1
    %v376 = add i64 %v374, %v375
    store i64 %v376, ptr %v4
    %v377 = add i64 0, 0
    %v378 = load ptr, ptr %v352
    %v379 = load i64, ptr %v4
    %v380 = call ptr @orion_list_push(ptr %v378, i64 %v379)
    store ptr %v380, ptr %v352
    %v381 = add i64 0, 0
    %v382 = load i64, ptr %v4
    %v383 = add i64 0, 1
    %v384 = add i64 %v382, %v383
    store i64 %v384, ptr %v4
    %v385 = add i64 0, 0
    br label %if_372_merge
if_372_else:
    br label %loop_354_end
if_372_merge:
    br label %loop_354_header
loop_354_end:
    %v392 = getelementptr i8, ptr @.str_118, i64 16
    %v393 = getelementptr i8, ptr @.str_250, i64 16
    %v394 = getelementptr i8, ptr @.str_119, i64 16
    %v395 = getelementptr i8, ptr @.str_278, i64 16
    %v396 = call ptr @orion_map_new(i64 2)
    %v396.p0 = ptrtoint ptr %v393 to i64
    call void @orion_map_set(ptr %v396, ptr %v392, i64 %v396.p0)
    %v396.p1 = ptrtoint ptr %v395 to i64
    call void @orion_map_set(ptr %v396, ptr %v394, i64 %v396.p1)
    %v397 = alloca ptr, align 8
    store ptr %v396, ptr %v397
    %v398 = add i64 0, 0
    %v399 = add i64 0, 0
    %v400 = alloca i64, align 8
    store i64 %v399, ptr %v400
    %v401 = add i64 0, 0
    %v402 = load i64, ptr %v4
    %v403 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v402)
    %v404 = getelementptr i8, ptr @.str_123, i64 16
    %v405.e = call i64 @orion_text_eq(ptr %v403, ptr %v404)
    %v405 = add i64 %v405.e, 0
    %v406.cb = icmp ne i64 %v405, 0
    br i1 %v406.cb, label %if_406_then, label %if_406_else
if_406_then:
    %v408 = load i64, ptr %v4
    %v409 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v408)
    %v410 = getelementptr i8, ptr @.str_143, i64 16
    %v411.e = call i64 @orion_text_eq(ptr %v409, ptr %v410)
    %v411 = add i64 %v411.e, 0
    br label %if_406_merge
if_406_else:
    %v414 = add i64 0, 0
    br label %if_406_merge
if_406_merge:
    %v417 = phi i64 [ %v411, %if_406_then ], [ %v414, %if_406_else ]
    %v418.cb = icmp ne i64 %v417, 0
    br i1 %v418.cb, label %if_418_then, label %if_418_else
if_418_then:
    %v420 = load i64, ptr %v4
    %v421 = add i64 0, 1
    %v422 = add i64 %v420, %v421
    %v423 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v422)
    %v424 = getelementptr i8, ptr @.str_260, i64 16
    %v425.i = call i64 @orion_map_get(ptr %v423, ptr %v424)
    %v425.raw = inttoptr i64 %v425.i to ptr
    %v425.isnull = icmp eq i64 %v425.i, 0
    %v425 = select i1 %v425.isnull, ptr @orion_empty_list, ptr %v425.raw
    store ptr %v425, ptr %v397
    %v426 = add i64 0, 0
    %v427 = add i64 0, 1
    store i64 %v427, ptr %v400
    %v428 = add i64 0, 0
    %v429 = getelementptr i8, ptr @.str_124, i64 16
    %v430 = call i64 @orion_map_get(ptr %v423, ptr %v429)
    store i64 %v430, ptr %v4
    %v431 = add i64 0, 0
    br label %if_418_merge
if_418_else:
    br label %if_418_merge
if_418_merge:
    %v436 = load i64, ptr %v4
    %v437 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v436)
    %v438 = getelementptr i8, ptr @.str_248, i64 16
    %v439.e = call i64 @orion_text_eq(ptr %v437, ptr %v438)
    %v439 = add i64 %v439.e, 0
    %v440.cb = icmp ne i64 %v439, 0
    br i1 %v440.cb, label %if_440_then, label %if_440_else
if_440_then:
    %v442 = load i64, ptr %v4
    %v443 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v442)
    %v444 = getelementptr i8, ptr @.str_220, i64 16
    %v445.e = call i64 @orion_text_eq(ptr %v443, ptr %v444)
    %v445 = add i64 %v445.e, 0
    br label %if_440_merge
if_440_else:
    %v448 = add i64 0, 0
    br label %if_440_merge
if_440_merge:
    %v451 = phi i64 [ %v445, %if_440_then ], [ %v448, %if_440_else ]
    %v452.cb = icmp ne i64 %v451, 0
    br i1 %v452.cb, label %if_452_then, label %if_452_else
if_452_then:
    %v454 = load i64, ptr %v4
    %v455 = add i64 0, 1
    %v456 = add i64 %v454, %v455
    store i64 %v456, ptr %v4
    %v457 = add i64 0, 0
    br label %if_452_merge
if_452_else:
    br label %if_452_merge
if_452_merge:
    %v462 = load i64, ptr %v4
    %v463 = call ptr @prog__psr_parse_arm_body(ptr %v0, i64 %v462, i64 %v67)
    %v464 = getelementptr i8, ptr @.str_279, i64 16
    %v465 = load ptr, ptr %v94
    %v466 = getelementptr i8, ptr @.str_280, i64 16
    %v467 = load ptr, ptr %v98
    %v468 = getelementptr i8, ptr @.str_281, i64 16
    %v469 = load ptr, ptr %v119
    %v470 = getelementptr i8, ptr @.str_282, i64 16
    %v471 = getelementptr i8, ptr @.str_260, i64 16
    %v472.i = call i64 @orion_map_get(ptr %v463, ptr %v471)
    %v472.raw = inttoptr i64 %v472.i to ptr
    %v472.isnull = icmp eq i64 %v472.i, 0
    %v472 = select i1 %v472.isnull, ptr @orion_empty_list, ptr %v472.raw
    %v473 = call ptr @orion_map_new(i64 4)
    %v473.p0 = ptrtoint ptr %v465 to i64
    call void @orion_map_set(ptr %v473, ptr %v464, i64 %v473.p0)
    %v473.p1 = ptrtoint ptr %v467 to i64
    call void @orion_map_set(ptr %v473, ptr %v466, i64 %v473.p1)
    %v473.p2 = ptrtoint ptr %v469 to i64
    call void @orion_map_set(ptr %v473, ptr %v468, i64 %v473.p2)
    %v473.p3 = ptrtoint ptr %v472 to i64
    call void @orion_map_set(ptr %v473, ptr %v470, i64 %v473.p3)
    %v474 = alloca ptr, align 8
    store ptr %v473, ptr %v474
    %v475 = add i64 0, 0
    %v476 = load i64, ptr %v400
    %v477.cb = icmp ne i64 %v476, 0
    br i1 %v477.cb, label %if_477_then, label %if_477_else
if_477_then:
    %v479 = load ptr, ptr %v474
    %v480 = getelementptr i8, ptr @.str_283, i64 16
    %v481 = load ptr, ptr %v397
    %v482.p = ptrtoint ptr %v481 to i64
    call void @orion_map_set(ptr %v479, ptr %v480, i64 %v482.p)
    %v482 = getelementptr i8, ptr %v479, i64 0
    store ptr %v482, ptr %v474
    %v483 = add i64 0, 0
    br label %if_477_merge
if_477_else:
    br label %if_477_merge
if_477_merge:
    %v488 = load ptr, ptr %v69
    %v489 = load ptr, ptr %v474
    %v490.p = ptrtoint ptr %v489 to i64
    %v490 = call ptr @orion_list_push(ptr %v488, i64 %v490.p)
    store ptr %v490, ptr %v69
    %v491 = add i64 0, 0
    %v492 = load ptr, ptr %v352
    %v493 = call i64 @orion_list_len(ptr %v492)
    %v494 = add i64 0, 0
    %v495 = alloca i64, align 8
    store i64 %v494, ptr %v495
    %v496 = add i64 0, 0
    br label %for_494_header
for_494_header:
    %v499 = load i64, ptr %v495
    %v500.b = icmp slt i64 %v499, %v493
    %v500 = zext i1 %v500.b to i64
    %v501.cb = icmp ne i64 %v500, 0
    br i1 %v501.cb, label %for_494_body, label %for_494_end
for_494_body:
    %v503 = load ptr, ptr %v352
    %v504 = call i64 @orion_list_at(ptr %v503, i64 %v499)
    %v505 = getelementptr i8, ptr @.str_279, i64 16
    %v506 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v504)
    %v507 = getelementptr i8, ptr @.str_280, i64 16
    %v508 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v504)
    %v509 = getelementptr i8, ptr @.str_281, i64 16
    %v510 = getelementptr i8, ptr @.str_5, i64 16
    %v511 = call ptr @orion_list_new(i64 1)
    %v511.lp0 = ptrtoint ptr %v510 to i64
    call void @orion_list_set(ptr %v511, i64 0, i64 %v511.lp0)
    %v512 = add i64 0, 0
    %v513 = add i64 0, 0
    %v514 = call ptr @orion_list_slice(ptr %v511, i64 %v512, i64 %v513)
    %v515 = getelementptr i8, ptr @.str_282, i64 16
    %v516 = getelementptr i8, ptr @.str_260, i64 16
    %v517.i = call i64 @orion_map_get(ptr %v463, ptr %v516)
    %v517.raw = inttoptr i64 %v517.i to ptr
    %v517.isnull = icmp eq i64 %v517.i, 0
    %v517 = select i1 %v517.isnull, ptr @orion_empty_list, ptr %v517.raw
    %v518 = call ptr @orion_map_new(i64 4)
    %v518.p0 = ptrtoint ptr %v506 to i64
    call void @orion_map_set(ptr %v518, ptr %v505, i64 %v518.p0)
    %v518.p1 = ptrtoint ptr %v508 to i64
    call void @orion_map_set(ptr %v518, ptr %v507, i64 %v518.p1)
    %v518.p2 = ptrtoint ptr %v514 to i64
    call void @orion_map_set(ptr %v518, ptr %v509, i64 %v518.p2)
    %v518.p3 = ptrtoint ptr %v517 to i64
    call void @orion_map_set(ptr %v518, ptr %v515, i64 %v518.p3)
    %v519 = alloca ptr, align 8
    store ptr %v518, ptr %v519
    %v520 = add i64 0, 0
    %v521 = load i64, ptr %v400
    %v522.cb = icmp ne i64 %v521, 0
    br i1 %v522.cb, label %if_522_then, label %if_522_else
if_522_then:
    %v524 = load ptr, ptr %v519
    %v525 = getelementptr i8, ptr @.str_283, i64 16
    %v526 = load ptr, ptr %v397
    %v527.p = ptrtoint ptr %v526 to i64
    call void @orion_map_set(ptr %v524, ptr %v525, i64 %v527.p)
    %v527 = getelementptr i8, ptr %v524, i64 0
    store ptr %v527, ptr %v519
    %v528 = add i64 0, 0
    br label %if_522_merge
if_522_else:
    br label %if_522_merge
if_522_merge:
    %v533 = load ptr, ptr %v69
    %v534 = load ptr, ptr %v519
    %v535.p = ptrtoint ptr %v534 to i64
    %v535 = call ptr @orion_list_push(ptr %v533, i64 %v535.p)
    store ptr %v535, ptr %v69
    %v536 = add i64 0, 0
    br label %for_494_step
for_494_step:
    %v539 = add i64 0, 1
    %v540 = add i64 %v499, %v539
    store i64 %v540, ptr %v495
    %v541 = add i64 0, 0
    br label %for_494_header
for_494_end:
    %v544 = getelementptr i8, ptr @.str_124, i64 16
    %v545 = call i64 @orion_map_get(ptr %v463, ptr %v544)
    store i64 %v545, ptr %v4
    %v546 = add i64 0, 0
    %v547 = load i64, ptr %v4
    %v548 = call i64 @prog__psr_skip_newlines(ptr %v0, i64 %v547)
    store i64 %v548, ptr %v4
    %v549 = add i64 0, 0
    br label %loop_71_header
loop_71_end:
    %v552 = getelementptr i8, ptr @.str_260, i64 16
    %v553 = getelementptr i8, ptr @.str_118, i64 16
    %v554 = getelementptr i8, ptr @.str_284, i64 16
    %v555 = getelementptr i8, ptr @.str_285, i64 16
    %v556 = getelementptr i8, ptr @.str_260, i64 16
    %v557.i = call i64 @orion_map_get(ptr %v33, ptr %v556)
    %v557.raw = inttoptr i64 %v557.i to ptr
    %v557.isnull = icmp eq i64 %v557.i, 0
    %v557 = select i1 %v557.isnull, ptr @orion_empty_list, ptr %v557.raw
    %v558 = getelementptr i8, ptr @.str_286, i64 16
    %v559 = load ptr, ptr %v69
    %v560 = call ptr @orion_map_new(i64 3)
    %v560.p0 = ptrtoint ptr %v554 to i64
    call void @orion_map_set(ptr %v560, ptr %v553, i64 %v560.p0)
    %v560.p1 = ptrtoint ptr %v557 to i64
    call void @orion_map_set(ptr %v560, ptr %v555, i64 %v560.p1)
    %v560.p2 = ptrtoint ptr %v559 to i64
    call void @orion_map_set(ptr %v560, ptr %v558, i64 %v560.p2)
    %v561 = getelementptr i8, ptr @.str_124, i64 16
    %v562 = load i64, ptr %v4
    %v563 = call ptr @orion_map_new(i64 2)
    %v563.p0 = ptrtoint ptr %v560 to i64
    call void @orion_map_set(ptr %v563, ptr %v552, i64 %v563.p0)
    call void @orion_map_set(ptr %v563, ptr %v561, i64 %v562)
    ret ptr %v563
}

define ptr @prog__psr_parse_cond_match(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = call i64 @prog__psr_skip_newlines(ptr %v0, i64 %v1)
    %v3 = alloca i64, align 8
    store i64 %v2, ptr %v3
    %v4 = add i64 0, 0
    %v5 = load i64, ptr %v3
    %v6 = call i64 @prog__psr_peek_col(ptr %v0, i64 %v5)
    %v7 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v8 = alloca ptr, align 8
    store ptr %v7, ptr %v8
    %v9 = add i64 0, 0
    %v10 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v11 = alloca ptr, align 8
    store ptr %v10, ptr %v11
    %v12 = add i64 0, 0
    %v13 = getelementptr i8, ptr @.str_118, i64 16
    %v14 = getelementptr i8, ptr @.str_250, i64 16
    %v15 = getelementptr i8, ptr @.str_119, i64 16
    %v16 = getelementptr i8, ptr @.str_210, i64 16
    %v17 = call ptr @orion_map_new(i64 2)
    %v17.p0 = ptrtoint ptr %v14 to i64
    call void @orion_map_set(ptr %v17, ptr %v13, i64 %v17.p0)
    %v17.p1 = ptrtoint ptr %v16 to i64
    call void @orion_map_set(ptr %v17, ptr %v15, i64 %v17.p1)
    %v18 = alloca ptr, align 8
    store ptr %v17, ptr %v18
    %v19 = add i64 0, 0
    br label %loop_20_header
loop_20_header:
    %v22 = load i64, ptr %v3
    %v23 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v22)
    %v24 = load i64, ptr %v3
    %v25 = call i64 @prog__psr_peek_col(ptr %v0, i64 %v24)
    %v26 = getelementptr i8, ptr @.str_249, i64 16
    %v27.e = call i64 @orion_text_eq(ptr %v23, ptr %v26)
    %v27 = add i64 %v27.e, 0
    %v28.cb = icmp ne i64 %v27, 0
    br i1 %v28.cb, label %if_28_then, label %if_28_else
if_28_then:
    br label %loop_20_end
if_28_else:
    br label %if_28_merge
if_28_merge:
    %v34.b = icmp slt i64 %v25, %v6
    %v34 = zext i1 %v34.b to i64
    %v35.cb = icmp ne i64 %v34, 0
    br i1 %v35.cb, label %if_35_then, label %if_35_else
if_35_then:
    br label %loop_20_end
if_35_else:
    br label %if_35_merge
if_35_merge:
    %v41 = getelementptr i8, ptr @.str_123, i64 16
    %v42.e = call i64 @orion_text_eq(ptr %v23, ptr %v41)
    %v42 = add i64 %v42.e, 0
    %v43.cb = icmp ne i64 %v42, 0
    br i1 %v43.cb, label %if_43_then, label %if_43_else
if_43_then:
    %v45 = load i64, ptr %v3
    %v46 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v45)
    %v47 = getelementptr i8, ptr @.str_145, i64 16
    %v48.e = call i64 @orion_text_eq(ptr %v46, ptr %v47)
    %v48 = add i64 %v48.e, 0
    br label %if_43_merge
if_43_else:
    %v51 = add i64 0, 0
    br label %if_43_merge
if_43_merge:
    %v54 = phi i64 [ %v48, %if_43_then ], [ %v51, %if_43_else ]
    %v55.cb = icmp ne i64 %v54, 0
    br i1 %v55.cb, label %if_55_then, label %if_55_else
if_55_then:
    %v57 = load i64, ptr %v3
    %v58 = add i64 0, 1
    %v59 = add i64 %v57, %v58
    store i64 %v59, ptr %v3
    %v60 = add i64 0, 0
    %v61 = load i64, ptr %v3
    %v62 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v61)
    %v63 = getelementptr i8, ptr @.str_248, i64 16
    %v64.e = call i64 @orion_text_eq(ptr %v62, ptr %v63)
    %v64 = add i64 %v64.e, 0
    %v65.cb = icmp ne i64 %v64, 0
    br i1 %v65.cb, label %if_65_then, label %if_65_else
if_65_then:
    %v67 = load i64, ptr %v3
    %v68 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v67)
    %v69 = getelementptr i8, ptr @.str_236, i64 16
    %v70.e = call i64 @orion_text_eq(ptr %v68, ptr %v69)
    %v70 = add i64 %v70.e, 0
    br label %if_65_merge
if_65_else:
    %v73 = add i64 0, 0
    br label %if_65_merge
if_65_merge:
    %v76 = phi i64 [ %v70, %if_65_then ], [ %v73, %if_65_else ]
    %v77.cb = icmp ne i64 %v76, 0
    br i1 %v77.cb, label %if_77_then, label %if_77_else
if_77_then:
    %v79 = load i64, ptr %v3
    %v80 = add i64 0, 1
    %v81 = add i64 %v79, %v80
    store i64 %v81, ptr %v3
    %v82 = add i64 0, 0
    br label %if_77_merge
if_77_else:
    br label %if_77_merge
if_77_merge:
    %v87 = load i64, ptr %v3
    %v88 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v87)
    %v89 = getelementptr i8, ptr @.str_248, i64 16
    %v90.e = call i64 @orion_text_eq(ptr %v88, ptr %v89)
    %v90 = add i64 %v90.e, 0
    %v91.cb = icmp ne i64 %v90, 0
    br i1 %v91.cb, label %if_91_then, label %if_91_else
if_91_then:
    %v93 = load i64, ptr %v3
    %v94 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v93)
    %v95 = getelementptr i8, ptr @.str_220, i64 16
    %v96.e = call i64 @orion_text_eq(ptr %v94, ptr %v95)
    %v96 = add i64 %v96.e, 0
    br label %if_91_merge
if_91_else:
    %v99 = add i64 0, 0
    br label %if_91_merge
if_91_merge:
    %v102 = phi i64 [ %v96, %if_91_then ], [ %v99, %if_91_else ]
    %v103.cb = icmp ne i64 %v102, 0
    br i1 %v103.cb, label %if_103_then, label %if_103_else
if_103_then:
    %v105 = load i64, ptr %v3
    %v106 = add i64 0, 1
    %v107 = add i64 %v105, %v106
    store i64 %v107, ptr %v3
    %v108 = add i64 0, 0
    br label %if_103_merge
if_103_else:
    br label %if_103_merge
if_103_merge:
    %v113 = load i64, ptr %v3
    %v114 = call ptr @prog__psr_parse_arm_body(ptr %v0, i64 %v113, i64 %v6)
    %v115 = getelementptr i8, ptr @.str_260, i64 16
    %v116.i = call i64 @orion_map_get(ptr %v114, ptr %v115)
    %v116.raw = inttoptr i64 %v116.i to ptr
    %v116.isnull = icmp eq i64 %v116.i, 0
    %v116 = select i1 %v116.isnull, ptr @orion_empty_list, ptr %v116.raw
    store ptr %v116, ptr %v18
    %v117 = add i64 0, 0
    %v118 = getelementptr i8, ptr @.str_124, i64 16
    %v119 = call i64 @orion_map_get(ptr %v114, ptr %v118)
    store i64 %v119, ptr %v3
    %v120 = add i64 0, 0
    %v121 = load i64, ptr %v3
    %v122 = call i64 @prog__psr_skip_newlines(ptr %v0, i64 %v121)
    store i64 %v122, ptr %v3
    %v123 = add i64 0, 0
    br label %loop_20_end
if_55_else:
    br label %if_55_merge
if_55_merge:
    %v128 = load i64, ptr %v3
    %v129 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v128)
    %v130 = getelementptr i8, ptr @.str_124, i64 16
    %v131 = call i64 @orion_map_get(ptr %v129, ptr %v130)
    store i64 %v131, ptr %v3
    %v132 = add i64 0, 0
    %v133 = load i64, ptr %v3
    %v134 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v133)
    %v135 = getelementptr i8, ptr @.str_248, i64 16
    %v136.e = call i64 @orion_text_eq(ptr %v134, ptr %v135)
    %v136 = add i64 %v136.e, 0
    %v137.cb = icmp ne i64 %v136, 0
    br i1 %v137.cb, label %if_137_then, label %if_137_else
if_137_then:
    %v139 = load i64, ptr %v3
    %v140 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v139)
    %v141 = getelementptr i8, ptr @.str_236, i64 16
    %v142.e = call i64 @orion_text_eq(ptr %v140, ptr %v141)
    %v142 = add i64 %v142.e, 0
    br label %if_137_merge
if_137_else:
    %v145 = add i64 0, 0
    br label %if_137_merge
if_137_merge:
    %v148 = phi i64 [ %v142, %if_137_then ], [ %v145, %if_137_else ]
    %v149.cb = icmp ne i64 %v148, 0
    br i1 %v149.cb, label %if_149_then, label %if_149_else
if_149_then:
    %v151 = load i64, ptr %v3
    %v152 = add i64 0, 1
    %v153 = add i64 %v151, %v152
    store i64 %v153, ptr %v3
    %v154 = add i64 0, 0
    br label %if_149_merge
if_149_else:
    br label %if_149_merge
if_149_merge:
    %v159 = load i64, ptr %v3
    %v160 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v159)
    %v161 = getelementptr i8, ptr @.str_248, i64 16
    %v162.e = call i64 @orion_text_eq(ptr %v160, ptr %v161)
    %v162 = add i64 %v162.e, 0
    %v163.cb = icmp ne i64 %v162, 0
    br i1 %v163.cb, label %if_163_then, label %if_163_else
if_163_then:
    %v165 = load i64, ptr %v3
    %v166 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v165)
    %v167 = getelementptr i8, ptr @.str_220, i64 16
    %v168.e = call i64 @orion_text_eq(ptr %v166, ptr %v167)
    %v168 = add i64 %v168.e, 0
    br label %if_163_merge
if_163_else:
    %v171 = add i64 0, 0
    br label %if_163_merge
if_163_merge:
    %v174 = phi i64 [ %v168, %if_163_then ], [ %v171, %if_163_else ]
    %v175.cb = icmp ne i64 %v174, 0
    br i1 %v175.cb, label %if_175_then, label %if_175_else
if_175_then:
    %v177 = load i64, ptr %v3
    %v178 = add i64 0, 1
    %v179 = add i64 %v177, %v178
    store i64 %v179, ptr %v3
    %v180 = add i64 0, 0
    br label %if_175_merge
if_175_else:
    br label %if_175_merge
if_175_merge:
    %v185 = load i64, ptr %v3
    %v186 = call ptr @prog__psr_parse_arm_body(ptr %v0, i64 %v185, i64 %v6)
    %v187 = load ptr, ptr %v8
    %v188 = getelementptr i8, ptr @.str_260, i64 16
    %v189.i = call i64 @orion_map_get(ptr %v129, ptr %v188)
    %v189.raw = inttoptr i64 %v189.i to ptr
    %v189.isnull = icmp eq i64 %v189.i, 0
    %v189 = select i1 %v189.isnull, ptr @orion_empty_list, ptr %v189.raw
    %v190.p = ptrtoint ptr %v189 to i64
    %v190 = call ptr @orion_list_push(ptr %v187, i64 %v190.p)
    store ptr %v190, ptr %v8
    %v191 = add i64 0, 0
    %v192 = load ptr, ptr %v11
    %v193 = getelementptr i8, ptr @.str_260, i64 16
    %v194.i = call i64 @orion_map_get(ptr %v186, ptr %v193)
    %v194.raw = inttoptr i64 %v194.i to ptr
    %v194.isnull = icmp eq i64 %v194.i, 0
    %v194 = select i1 %v194.isnull, ptr @orion_empty_list, ptr %v194.raw
    %v195.p = ptrtoint ptr %v194 to i64
    %v195 = call ptr @orion_list_push(ptr %v192, i64 %v195.p)
    store ptr %v195, ptr %v11
    %v196 = add i64 0, 0
    %v197 = getelementptr i8, ptr @.str_124, i64 16
    %v198 = call i64 @orion_map_get(ptr %v186, ptr %v197)
    store i64 %v198, ptr %v3
    %v199 = add i64 0, 0
    %v200 = load i64, ptr %v3
    %v201 = call i64 @prog__psr_skip_newlines(ptr %v0, i64 %v200)
    store i64 %v201, ptr %v3
    %v202 = add i64 0, 0
    br label %loop_20_header
loop_20_end:
    %v205 = load ptr, ptr %v8
    %v206 = call i64 @orion_list_len(ptr %v205)
    %v207 = load ptr, ptr %v18
    %v208 = alloca ptr, align 8
    store ptr %v207, ptr %v208
    %v209 = add i64 0, 0
    %v210 = add i64 0, 0
    %v211 = alloca i64, align 8
    store i64 %v210, ptr %v211
    %v212 = add i64 0, 0
    br label %for_210_header
for_210_header:
    %v215 = load i64, ptr %v211
    %v216.b = icmp slt i64 %v215, %v206
    %v216 = zext i1 %v216.b to i64
    %v217.cb = icmp ne i64 %v216, 0
    br i1 %v217.cb, label %for_210_body, label %for_210_end
for_210_body:
    %v219 = add i64 0, 1
    %v220 = sub i64 %v206, %v219
    %v221 = sub i64 %v220, %v215
    %v222 = getelementptr i8, ptr @.str_118, i64 16
    %v223 = getelementptr i8, ptr @.str_287, i64 16
    %v224 = getelementptr i8, ptr @.str_288, i64 16
    %v225 = load ptr, ptr %v8
    %v226.i = call i64 @orion_list_at(ptr %v225, i64 %v221)
    %v226 = inttoptr i64 %v226.i to ptr
    %v227 = getelementptr i8, ptr @.str_289, i64 16
    %v228 = load ptr, ptr %v11
    %v229.i = call i64 @orion_list_at(ptr %v228, i64 %v221)
    %v229 = inttoptr i64 %v229.i to ptr
    %v230 = getelementptr i8, ptr @.str_145, i64 16
    %v231 = load ptr, ptr %v208
    %v232 = call ptr @orion_map_new(i64 4)
    %v232.p0 = ptrtoint ptr %v223 to i64
    call void @orion_map_set(ptr %v232, ptr %v222, i64 %v232.p0)
    %v232.p1 = ptrtoint ptr %v226 to i64
    call void @orion_map_set(ptr %v232, ptr %v224, i64 %v232.p1)
    %v232.p2 = ptrtoint ptr %v229 to i64
    call void @orion_map_set(ptr %v232, ptr %v227, i64 %v232.p2)
    %v232.p3 = ptrtoint ptr %v231 to i64
    call void @orion_map_set(ptr %v232, ptr %v230, i64 %v232.p3)
    store ptr %v232, ptr %v208
    %v233 = add i64 0, 0
    br label %for_210_step
for_210_step:
    %v236 = add i64 0, 1
    %v237 = add i64 %v215, %v236
    store i64 %v237, ptr %v211
    %v238 = add i64 0, 0
    br label %for_210_header
for_210_end:
    %v241 = getelementptr i8, ptr @.str_260, i64 16
    %v242 = load ptr, ptr %v208
    %v243 = getelementptr i8, ptr @.str_124, i64 16
    %v244 = load i64, ptr %v3
    %v245 = call ptr @orion_map_new(i64 2)
    %v245.p0 = ptrtoint ptr %v242 to i64
    call void @orion_map_set(ptr %v245, ptr %v241, i64 %v245.p0)
    call void @orion_map_set(ptr %v245, ptr %v243, i64 %v244)
    ret ptr %v245
}

define ptr @prog__psr_parse_for_collect(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, 1
    %v3 = add i64 %v1, %v2
    %v4 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v3)
    %v5 = add i64 0, 2
    %v6 = add i64 %v1, %v5
    %v7 = alloca i64, align 8
    store i64 %v6, ptr %v7
    %v8 = add i64 0, 0
    %v9 = load i64, ptr %v7
    %v10 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v9)
    %v11 = getelementptr i8, ptr @.str_123, i64 16
    %v12.e = call i64 @orion_text_eq(ptr %v10, ptr %v11)
    %v12 = add i64 %v12.e, 0
    %v13.cb = icmp ne i64 %v12, 0
    br i1 %v13.cb, label %if_13_then, label %if_13_else
if_13_then:
    %v15 = load i64, ptr %v7
    %v16 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v15)
    %v17 = getelementptr i8, ptr @.str_149, i64 16
    %v18.e = call i64 @orion_text_eq(ptr %v16, ptr %v17)
    %v18 = add i64 %v18.e, 0
    br label %if_13_merge
if_13_else:
    %v21 = add i64 0, 0
    br label %if_13_merge
if_13_merge:
    %v24 = phi i64 [ %v18, %if_13_then ], [ %v21, %if_13_else ]
    %v25.cb = icmp ne i64 %v24, 0
    br i1 %v25.cb, label %if_25_then, label %if_25_else
if_25_then:
    %v27 = load i64, ptr %v7
    %v28 = add i64 0, 1
    %v29 = add i64 %v27, %v28
    store i64 %v29, ptr %v7
    %v30 = add i64 0, 0
    br label %if_25_merge
if_25_else:
    br label %if_25_merge
if_25_merge:
    %v35 = load i64, ptr %v7
    %v36 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v35)
    %v37 = getelementptr i8, ptr @.str_260, i64 16
    %v38.i = call i64 @orion_map_get(ptr %v36, ptr %v37)
    %v38.raw = inttoptr i64 %v38.i to ptr
    %v38.isnull = icmp eq i64 %v38.i, 0
    %v38 = select i1 %v38.isnull, ptr @orion_empty_list, ptr %v38.raw
    %v39 = getelementptr i8, ptr @.str_124, i64 16
    %v40 = call i64 @orion_map_get(ptr %v36, ptr %v39)
    store i64 %v40, ptr %v7
    %v41 = add i64 0, 0
    %v42 = load i64, ptr %v7
    %v43 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v42)
    %v44 = getelementptr i8, ptr @.str_123, i64 16
    %v45.e = call i64 @orion_text_eq(ptr %v43, ptr %v44)
    %v45 = add i64 %v45.e, 0
    %v46.cb = icmp ne i64 %v45, 0
    br i1 %v46.cb, label %if_46_then, label %if_46_else
if_46_then:
    %v48 = load i64, ptr %v7
    %v49 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v48)
    %v50 = getelementptr i8, ptr @.str_153, i64 16
    %v51.e = call i64 @orion_text_eq(ptr %v49, ptr %v50)
    %v51 = add i64 %v51.e, 0
    br label %if_46_merge
if_46_else:
    %v54 = add i64 0, 0
    br label %if_46_merge
if_46_merge:
    %v57 = phi i64 [ %v51, %if_46_then ], [ %v54, %if_46_else ]
    %v58 = getelementptr i8, ptr @.str_118, i64 16
    %v59 = getelementptr i8, ptr @.str_250, i64 16
    %v60 = getelementptr i8, ptr @.str_119, i64 16
    %v61 = getelementptr i8, ptr @.str_278, i64 16
    %v62 = call ptr @orion_map_new(i64 2)
    %v62.p0 = ptrtoint ptr %v59 to i64
    call void @orion_map_set(ptr %v62, ptr %v58, i64 %v62.p0)
    %v62.p1 = ptrtoint ptr %v61 to i64
    call void @orion_map_set(ptr %v62, ptr %v60, i64 %v62.p1)
    %v63 = alloca ptr, align 8
    store ptr %v62, ptr %v63
    %v64 = add i64 0, 0
    %v65.cb = icmp ne i64 %v57, 0
    br i1 %v65.cb, label %if_65_then, label %if_65_else
if_65_then:
    %v67 = load i64, ptr %v7
    %v68 = add i64 0, 1
    %v69 = add i64 %v67, %v68
    store i64 %v69, ptr %v7
    %v70 = add i64 0, 0
    %v71 = load i64, ptr %v7
    %v72 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v71)
    %v73 = getelementptr i8, ptr @.str_260, i64 16
    %v74.i = call i64 @orion_map_get(ptr %v72, ptr %v73)
    %v74.raw = inttoptr i64 %v74.i to ptr
    %v74.isnull = icmp eq i64 %v74.i, 0
    %v74 = select i1 %v74.isnull, ptr @orion_empty_list, ptr %v74.raw
    store ptr %v74, ptr %v63
    %v75 = add i64 0, 0
    %v76 = getelementptr i8, ptr @.str_124, i64 16
    %v77 = call i64 @orion_map_get(ptr %v72, ptr %v76)
    store i64 %v77, ptr %v7
    %v78 = add i64 0, 0
    br label %if_65_merge
if_65_else:
    br label %if_65_merge
if_65_merge:
    %v83 = load i64, ptr %v7
    %v84 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v83)
    %v85 = getelementptr i8, ptr @.str_248, i64 16
    %v86.e = call i64 @orion_text_eq(ptr %v84, ptr %v85)
    %v86 = add i64 %v86.e, 0
    %v87.cb = icmp ne i64 %v86, 0
    br i1 %v87.cb, label %if_87_then, label %if_87_else
if_87_then:
    %v89 = load i64, ptr %v7
    %v90 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v89)
    %v91 = getelementptr i8, ptr @.str_236, i64 16
    %v92.e = call i64 @orion_text_eq(ptr %v90, ptr %v91)
    %v92 = add i64 %v92.e, 0
    br label %if_87_merge
if_87_else:
    %v95 = add i64 0, 0
    br label %if_87_merge
if_87_merge:
    %v98 = phi i64 [ %v92, %if_87_then ], [ %v95, %if_87_else ]
    %v99.cb = icmp ne i64 %v98, 0
    br i1 %v99.cb, label %if_99_then, label %if_99_else
if_99_then:
    %v101 = load i64, ptr %v7
    %v102 = add i64 0, 1
    %v103 = add i64 %v101, %v102
    store i64 %v103, ptr %v7
    %v104 = add i64 0, 0
    br label %if_99_merge
if_99_else:
    br label %if_99_merge
if_99_merge:
    %v109 = load i64, ptr %v7
    %v110 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v109)
    %v111 = getelementptr i8, ptr @.str_260, i64 16
    %v112.i = call i64 @orion_map_get(ptr %v110, ptr %v111)
    %v112.raw = inttoptr i64 %v112.i to ptr
    %v112.isnull = icmp eq i64 %v112.i, 0
    %v112 = select i1 %v112.isnull, ptr @orion_empty_list, ptr %v112.raw
    %v113 = getelementptr i8, ptr @.str_124, i64 16
    %v114 = call i64 @orion_map_get(ptr %v110, ptr %v113)
    store i64 %v114, ptr %v7
    %v115 = add i64 0, 0
    %v116 = getelementptr i8, ptr @.str_118, i64 16
    %v117 = getelementptr i8, ptr @.str_251, i64 16
    %v118 = getelementptr i8, ptr @.str_252, i64 16
    %v119 = getelementptr i8, ptr @.str_290, i64 16
    %v120 = getelementptr i8, ptr @.str_253, i64 16
    %v121 = getelementptr i8, ptr @.str_118, i64 16
    %v122 = getelementptr i8, ptr @.str_256, i64 16
    %v123 = getelementptr i8, ptr @.str_257, i64 16
    %v124 = getelementptr i8, ptr @.str_291, i64 16
    %v125 = call ptr @orion_map_new(i64 2)
    %v125.p0 = ptrtoint ptr %v122 to i64
    call void @orion_map_set(ptr %v125, ptr %v121, i64 %v125.p0)
    %v125.p1 = ptrtoint ptr %v124 to i64
    call void @orion_map_set(ptr %v125, ptr %v123, i64 %v125.p1)
    %v126 = call ptr @orion_list_new(i64 2)
    %v126.lp0 = ptrtoint ptr %v125 to i64
    call void @orion_list_set(ptr %v126, i64 0, i64 %v126.lp0)
    %v126.lp1 = ptrtoint ptr %v112 to i64
    call void @orion_list_set(ptr %v126, i64 1, i64 %v126.lp1)
    %v127 = call ptr @orion_map_new(i64 3)
    %v127.p0 = ptrtoint ptr %v117 to i64
    call void @orion_map_set(ptr %v127, ptr %v116, i64 %v127.p0)
    %v127.p1 = ptrtoint ptr %v119 to i64
    call void @orion_map_set(ptr %v127, ptr %v118, i64 %v127.p1)
    %v127.p2 = ptrtoint ptr %v126 to i64
    call void @orion_map_set(ptr %v127, ptr %v120, i64 %v127.p2)
    %v128 = getelementptr i8, ptr @.str_118, i64 16
    %v129 = getelementptr i8, ptr @.str_292, i64 16
    %v130 = getelementptr i8, ptr @.str_257, i64 16
    %v131 = getelementptr i8, ptr @.str_291, i64 16
    %v132 = getelementptr i8, ptr @.str_119, i64 16
    %v133 = call ptr @orion_map_new(i64 3)
    %v133.p0 = ptrtoint ptr %v129 to i64
    call void @orion_map_set(ptr %v133, ptr %v128, i64 %v133.p0)
    %v133.p1 = ptrtoint ptr %v131 to i64
    call void @orion_map_set(ptr %v133, ptr %v130, i64 %v133.p1)
    %v133.p2 = ptrtoint ptr %v127 to i64
    call void @orion_map_set(ptr %v133, ptr %v132, i64 %v133.p2)
    %v134 = alloca ptr, align 8
    store ptr %v133, ptr %v134
    %v135 = add i64 0, 0
    %v136.cb = icmp ne i64 %v57, 0
    br i1 %v136.cb, label %if_136_then, label %if_136_else
if_136_then:
    %v138 = getelementptr i8, ptr @.str_118, i64 16
    %v139 = getelementptr i8, ptr @.str_293, i64 16
    %v140 = getelementptr i8, ptr @.str_288, i64 16
    %v141 = load ptr, ptr %v63
    %v142 = getelementptr i8, ptr @.str_289, i64 16
    %v143 = getelementptr i8, ptr @.str_118, i64 16
    %v144 = getelementptr i8, ptr @.str_294, i64 16
    %v145 = getelementptr i8, ptr @.str_295, i64 16
    %v146 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v147.p = ptrtoint ptr %v133 to i64
    %v147 = call ptr @orion_list_push(ptr %v146, i64 %v147.p)
    %v148 = call ptr @orion_map_new(i64 2)
    %v148.p0 = ptrtoint ptr %v144 to i64
    call void @orion_map_set(ptr %v148, ptr %v143, i64 %v148.p0)
    %v148.p1 = ptrtoint ptr %v147 to i64
    call void @orion_map_set(ptr %v148, ptr %v145, i64 %v148.p1)
    %v149 = getelementptr i8, ptr @.str_145, i64 16
    %v150 = getelementptr i8, ptr @.str_118, i64 16
    %v151 = getelementptr i8, ptr @.str_294, i64 16
    %v152 = getelementptr i8, ptr @.str_295, i64 16
    %v153 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v154 = call ptr @orion_map_new(i64 2)
    %v154.p0 = ptrtoint ptr %v151 to i64
    call void @orion_map_set(ptr %v154, ptr %v150, i64 %v154.p0)
    %v154.p1 = ptrtoint ptr %v153 to i64
    call void @orion_map_set(ptr %v154, ptr %v152, i64 %v154.p1)
    %v155 = call ptr @orion_map_new(i64 4)
    %v155.p0 = ptrtoint ptr %v139 to i64
    call void @orion_map_set(ptr %v155, ptr %v138, i64 %v155.p0)
    %v155.p1 = ptrtoint ptr %v141 to i64
    call void @orion_map_set(ptr %v155, ptr %v140, i64 %v155.p1)
    %v155.p2 = ptrtoint ptr %v148 to i64
    call void @orion_map_set(ptr %v155, ptr %v142, i64 %v155.p2)
    %v155.p3 = ptrtoint ptr %v154 to i64
    call void @orion_map_set(ptr %v155, ptr %v149, i64 %v155.p3)
    store ptr %v155, ptr %v134
    %v156 = add i64 0, 0
    br label %if_136_merge
if_136_else:
    br label %if_136_merge
if_136_merge:
    %v161 = getelementptr i8, ptr @.str_118, i64 16
    %v162 = getelementptr i8, ptr @.str_296, i64 16
    %v163 = getelementptr i8, ptr @.str_297, i64 16
    %v164 = getelementptr i8, ptr @.str_298, i64 16
    %v165 = getelementptr i8, ptr @.str_5, i64 16
    %v166 = getelementptr i8, ptr @.str_299, i64 16
    %v167 = getelementptr i8, ptr @.str_282, i64 16
    %v168 = getelementptr i8, ptr @.str_118, i64 16
    %v169 = getelementptr i8, ptr @.str_294, i64 16
    %v170 = getelementptr i8, ptr @.str_295, i64 16
    %v171 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v172 = load ptr, ptr %v134
    %v173.p = ptrtoint ptr %v172 to i64
    %v173 = call ptr @orion_list_push(ptr %v171, i64 %v173.p)
    %v174 = call ptr @orion_map_new(i64 2)
    %v174.p0 = ptrtoint ptr %v169 to i64
    call void @orion_map_set(ptr %v174, ptr %v168, i64 %v174.p0)
    %v174.p1 = ptrtoint ptr %v173 to i64
    call void @orion_map_set(ptr %v174, ptr %v170, i64 %v174.p1)
    %v175 = call ptr @orion_map_new(i64 5)
    %v175.p0 = ptrtoint ptr %v162 to i64
    call void @orion_map_set(ptr %v175, ptr %v161, i64 %v175.p0)
    %v175.p1 = ptrtoint ptr %v4 to i64
    call void @orion_map_set(ptr %v175, ptr %v163, i64 %v175.p1)
    %v175.p2 = ptrtoint ptr %v165 to i64
    call void @orion_map_set(ptr %v175, ptr %v164, i64 %v175.p2)
    %v175.p3 = ptrtoint ptr %v38 to i64
    call void @orion_map_set(ptr %v175, ptr %v166, i64 %v175.p3)
    %v175.p4 = ptrtoint ptr %v174 to i64
    call void @orion_map_set(ptr %v175, ptr %v167, i64 %v175.p4)
    %v176 = getelementptr i8, ptr @.str_118, i64 16
    %v177 = getelementptr i8, ptr @.str_300, i64 16
    %v178 = getelementptr i8, ptr @.str_257, i64 16
    %v179 = getelementptr i8, ptr @.str_291, i64 16
    %v180 = getelementptr i8, ptr @.str_119, i64 16
    %v181 = getelementptr i8, ptr @.str_118, i64 16
    %v182 = getelementptr i8, ptr @.str_301, i64 16
    %v183 = getelementptr i8, ptr @.str_302, i64 16
    %v184 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v185 = call ptr @orion_map_new(i64 2)
    %v185.p0 = ptrtoint ptr %v182 to i64
    call void @orion_map_set(ptr %v185, ptr %v181, i64 %v185.p0)
    %v185.p1 = ptrtoint ptr %v184 to i64
    call void @orion_map_set(ptr %v185, ptr %v183, i64 %v185.p1)
    %v186 = call ptr @orion_map_new(i64 3)
    %v186.p0 = ptrtoint ptr %v177 to i64
    call void @orion_map_set(ptr %v186, ptr %v176, i64 %v186.p0)
    %v186.p1 = ptrtoint ptr %v179 to i64
    call void @orion_map_set(ptr %v186, ptr %v178, i64 %v186.p1)
    %v186.p2 = ptrtoint ptr %v185 to i64
    call void @orion_map_set(ptr %v186, ptr %v180, i64 %v186.p2)
    %v187 = getelementptr i8, ptr @.str_118, i64 16
    %v188 = getelementptr i8, ptr @.str_303, i64 16
    %v189 = getelementptr i8, ptr @.str_304, i64 16
    %v190 = getelementptr i8, ptr @.str_118, i64 16
    %v191 = getelementptr i8, ptr @.str_256, i64 16
    %v192 = getelementptr i8, ptr @.str_257, i64 16
    %v193 = getelementptr i8, ptr @.str_291, i64 16
    %v194 = call ptr @orion_map_new(i64 2)
    %v194.p0 = ptrtoint ptr %v191 to i64
    call void @orion_map_set(ptr %v194, ptr %v190, i64 %v194.p0)
    %v194.p1 = ptrtoint ptr %v193 to i64
    call void @orion_map_set(ptr %v194, ptr %v192, i64 %v194.p1)
    %v195 = call ptr @orion_map_new(i64 2)
    %v195.p0 = ptrtoint ptr %v188 to i64
    call void @orion_map_set(ptr %v195, ptr %v187, i64 %v195.p0)
    %v195.p1 = ptrtoint ptr %v194 to i64
    call void @orion_map_set(ptr %v195, ptr %v189, i64 %v195.p1)
    %v196 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v197.p = ptrtoint ptr %v186 to i64
    %v197 = call ptr @orion_list_push(ptr %v196, i64 %v197.p)
    %v198.p = ptrtoint ptr %v175 to i64
    %v198 = call ptr @orion_list_push(ptr %v197, i64 %v198.p)
    %v199.p = ptrtoint ptr %v195 to i64
    %v199 = call ptr @orion_list_push(ptr %v198, i64 %v199.p)
    %v200 = getelementptr i8, ptr @.str_260, i64 16
    %v201 = getelementptr i8, ptr @.str_118, i64 16
    %v202 = getelementptr i8, ptr @.str_294, i64 16
    %v203 = getelementptr i8, ptr @.str_295, i64 16
    %v204 = call ptr @orion_map_new(i64 2)
    %v204.p0 = ptrtoint ptr %v202 to i64
    call void @orion_map_set(ptr %v204, ptr %v201, i64 %v204.p0)
    %v204.p1 = ptrtoint ptr %v199 to i64
    call void @orion_map_set(ptr %v204, ptr %v203, i64 %v204.p1)
    %v205 = getelementptr i8, ptr @.str_124, i64 16
    %v206 = load i64, ptr %v7
    %v207 = call ptr @orion_map_new(i64 2)
    %v207.p0 = ptrtoint ptr %v204 to i64
    call void @orion_map_set(ptr %v207, ptr %v200, i64 %v207.p0)
    call void @orion_map_set(ptr %v207, ptr %v205, i64 %v206)
    ret ptr %v207
}

define ptr @prog__psr_parse_par_loop(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, 2
    %v3 = add i64 %v1, %v2
    %v4 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v3)
    %v5 = add i64 0, 3
    %v6 = add i64 %v1, %v5
    %v7 = alloca i64, align 8
    store i64 %v6, ptr %v7
    %v8 = add i64 0, 0
    %v9 = load i64, ptr %v7
    %v10 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v9)
    %v11 = getelementptr i8, ptr @.str_123, i64 16
    %v12.e = call i64 @orion_text_eq(ptr %v10, ptr %v11)
    %v12 = add i64 %v12.e, 0
    %v13.cb = icmp ne i64 %v12, 0
    br i1 %v13.cb, label %if_13_then, label %if_13_else
if_13_then:
    %v15 = load i64, ptr %v7
    %v16 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v15)
    %v17 = getelementptr i8, ptr @.str_149, i64 16
    %v18.e = call i64 @orion_text_eq(ptr %v16, ptr %v17)
    %v18 = add i64 %v18.e, 0
    br label %if_13_merge
if_13_else:
    %v21 = add i64 0, 0
    br label %if_13_merge
if_13_merge:
    %v24 = phi i64 [ %v18, %if_13_then ], [ %v21, %if_13_else ]
    %v25.cb = icmp ne i64 %v24, 0
    br i1 %v25.cb, label %if_25_then, label %if_25_else
if_25_then:
    %v27 = load i64, ptr %v7
    %v28 = add i64 0, 1
    %v29 = add i64 %v27, %v28
    store i64 %v29, ptr %v7
    %v30 = add i64 0, 0
    br label %if_25_merge
if_25_else:
    br label %if_25_merge
if_25_merge:
    %v35 = load i64, ptr %v7
    %v36 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v35)
    %v37 = getelementptr i8, ptr @.str_260, i64 16
    %v38.i = call i64 @orion_map_get(ptr %v36, ptr %v37)
    %v38.raw = inttoptr i64 %v38.i to ptr
    %v38.isnull = icmp eq i64 %v38.i, 0
    %v38 = select i1 %v38.isnull, ptr @orion_empty_list, ptr %v38.raw
    %v39 = getelementptr i8, ptr @.str_124, i64 16
    %v40 = call i64 @orion_map_get(ptr %v36, ptr %v39)
    store i64 %v40, ptr %v7
    %v41 = add i64 0, 0
    %v42 = load i64, ptr %v7
    %v43 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v42)
    %v44 = load i64, ptr %v7
    %v45 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v44)
    %v46 = getelementptr i8, ptr @.str_248, i64 16
    %v47.e = call i64 @orion_text_eq(ptr %v45, ptr %v46)
    %v47 = add i64 %v47.e, 0
    %v48.cb = icmp ne i64 %v47, 0
    br i1 %v48.cb, label %if_48_then, label %if_48_else
if_48_then:
    %v50 = getelementptr i8, ptr @.str_214, i64 16
    %v51.e = call i64 @orion_text_eq(ptr %v43, ptr %v50)
    %v51 = add i64 %v51.e, 0
    %v52.cb = icmp ne i64 %v51, 0
    br i1 %v52.cb, label %if_52_then, label %if_52_else
if_52_then:
    br label %if_52_merge
if_52_else:
    %v56 = getelementptr i8, ptr @.str_215, i64 16
    %v57.e = call i64 @orion_text_eq(ptr %v43, ptr %v56)
    %v57 = add i64 %v57.e, 0
    br label %if_52_merge
if_52_merge:
    %v60 = phi i64 [ %v51, %if_52_then ], [ %v57, %if_52_else ]
    br label %if_48_merge
if_48_else:
    %v63 = add i64 0, 0
    br label %if_48_merge
if_48_merge:
    %v66 = phi i64 [ %v60, %if_52_merge ], [ %v63, %if_48_else ]
    %v67 = getelementptr i8, ptr @.str_118, i64 16
    %v68 = getelementptr i8, ptr @.str_250, i64 16
    %v69 = getelementptr i8, ptr @.str_119, i64 16
    %v70 = getelementptr i8, ptr @.str_210, i64 16
    %v71 = call ptr @orion_map_new(i64 2)
    %v71.p0 = ptrtoint ptr %v68 to i64
    call void @orion_map_set(ptr %v71, ptr %v67, i64 %v71.p0)
    %v71.p1 = ptrtoint ptr %v70 to i64
    call void @orion_map_set(ptr %v71, ptr %v69, i64 %v71.p1)
    %v72 = alloca ptr, align 8
    store ptr %v71, ptr %v72
    %v73 = add i64 0, 0
    %v74.cb = icmp ne i64 %v66, 0
    br i1 %v74.cb, label %if_74_then, label %if_74_else
if_74_then:
    %v76 = load i64, ptr %v7
    %v77 = add i64 0, 1
    %v78 = add i64 %v76, %v77
    store i64 %v78, ptr %v7
    %v79 = add i64 0, 0
    %v80 = load i64, ptr %v7
    %v81 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v80)
    %v82 = getelementptr i8, ptr @.str_260, i64 16
    %v83.i = call i64 @orion_map_get(ptr %v81, ptr %v82)
    %v83.raw = inttoptr i64 %v83.i to ptr
    %v83.isnull = icmp eq i64 %v83.i, 0
    %v83 = select i1 %v83.isnull, ptr @orion_empty_list, ptr %v83.raw
    store ptr %v83, ptr %v72
    %v84 = add i64 0, 0
    %v85 = getelementptr i8, ptr @.str_124, i64 16
    %v86 = call i64 @orion_map_get(ptr %v81, ptr %v85)
    store i64 %v86, ptr %v7
    %v87 = add i64 0, 0
    br label %if_74_merge
if_74_else:
    br label %if_74_merge
if_74_merge:
    %v92 = load i64, ptr %v7
    %v93 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v92)
    %v94 = getelementptr i8, ptr @.str_248, i64 16
    %v95.e = call i64 @orion_text_eq(ptr %v93, ptr %v94)
    %v95 = add i64 %v95.e, 0
    %v96.cb = icmp ne i64 %v95, 0
    br i1 %v96.cb, label %if_96_then, label %if_96_else
if_96_then:
    %v98 = load i64, ptr %v7
    %v99 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v98)
    %v100 = getelementptr i8, ptr @.str_236, i64 16
    %v101.e = call i64 @orion_text_eq(ptr %v99, ptr %v100)
    %v101 = add i64 %v101.e, 0
    br label %if_96_merge
if_96_else:
    %v104 = add i64 0, 0
    br label %if_96_merge
if_96_merge:
    %v107 = phi i64 [ %v101, %if_96_then ], [ %v104, %if_96_else ]
    %v108.cb = icmp ne i64 %v107, 0
    br i1 %v108.cb, label %if_108_then, label %if_108_else
if_108_then:
    %v110 = load i64, ptr %v7
    %v111 = add i64 0, 1
    %v112 = add i64 %v110, %v111
    store i64 %v112, ptr %v7
    %v113 = add i64 0, 0
    br label %if_108_merge
if_108_else:
    br label %if_108_merge
if_108_merge:
    %v118 = load i64, ptr %v7
    %v119 = call i64 @prog__psr_peek_col(ptr %v0, i64 %v118)
    %v120 = load i64, ptr %v7
    %v121 = call ptr @prog__psr_parse_body_at(ptr %v0, i64 %v120, i64 %v119)
    %v122 = getelementptr i8, ptr @.str_260, i64 16
    %v123.i = call i64 @orion_map_get(ptr %v121, ptr %v122)
    %v123.raw = inttoptr i64 %v123.i to ptr
    %v123.isnull = icmp eq i64 %v123.i, 0
    %v123 = select i1 %v123.isnull, ptr @orion_empty_list, ptr %v123.raw
    %v124 = alloca ptr, align 8
    store ptr %v123, ptr %v124
    %v125 = add i64 0, 0
    %v126 = getelementptr i8, ptr @.str_124, i64 16
    %v127 = call i64 @orion_map_get(ptr %v121, ptr %v126)
    store i64 %v127, ptr %v7
    %v128 = add i64 0, 0
    %v129 = getelementptr i8, ptr @.str_118, i64 16
    %v130 = getelementptr i8, ptr @.str_303, i64 16
    %v131 = getelementptr i8, ptr @.str_304, i64 16
    %v132 = getelementptr i8, ptr @.str_118, i64 16
    %v133 = getelementptr i8, ptr @.str_250, i64 16
    %v134 = getelementptr i8, ptr @.str_119, i64 16
    %v135 = getelementptr i8, ptr @.str_210, i64 16
    %v136 = call ptr @orion_map_new(i64 2)
    %v136.p0 = ptrtoint ptr %v133 to i64
    call void @orion_map_set(ptr %v136, ptr %v132, i64 %v136.p0)
    %v136.p1 = ptrtoint ptr %v135 to i64
    call void @orion_map_set(ptr %v136, ptr %v134, i64 %v136.p1)
    %v137 = call ptr @orion_map_new(i64 2)
    %v137.p0 = ptrtoint ptr %v130 to i64
    call void @orion_map_set(ptr %v137, ptr %v129, i64 %v137.p0)
    %v137.p1 = ptrtoint ptr %v136 to i64
    call void @orion_map_set(ptr %v137, ptr %v131, i64 %v137.p1)
    %v138 = load ptr, ptr %v124
    %v139 = getelementptr i8, ptr @.str_118, i64 16
    %v140.i = call i64 @orion_map_get(ptr %v138, ptr %v139)
    %v140.raw = inttoptr i64 %v140.i to ptr
    %v140.isnull = icmp eq i64 %v140.i, 0
    %v140 = select i1 %v140.isnull, ptr getelementptr(i8, ptr @.str_empty_h, i64 16), ptr %v140.raw
    %v141 = getelementptr i8, ptr @.str_294, i64 16
    %v142.e = call i64 @orion_text_eq(ptr %v140, ptr %v141)
    %v142 = add i64 %v142.e, 0
    %v143.cb = icmp ne i64 %v142, 0
    br i1 %v143.cb, label %if_143_then, label %if_143_else
if_143_then:
    %v145 = load ptr, ptr %v124
    %v146 = getelementptr i8, ptr @.str_295, i64 16
    %v147 = load ptr, ptr %v124
    %v148 = getelementptr i8, ptr @.str_295, i64 16
    %v149.i = call i64 @orion_map_get(ptr %v147, ptr %v148)
    %v149.raw = inttoptr i64 %v149.i to ptr
    %v149.isnull = icmp eq i64 %v149.i, 0
    %v149 = select i1 %v149.isnull, ptr @orion_empty_list, ptr %v149.raw
    %v150.p = ptrtoint ptr %v137 to i64
    %v150 = call ptr @orion_list_push(ptr %v149, i64 %v150.p)
    %v151.p = ptrtoint ptr %v150 to i64
    call void @orion_map_set(ptr %v145, ptr %v146, i64 %v151.p)
    %v151 = getelementptr i8, ptr %v145, i64 0
    store ptr %v151, ptr %v124
    %v152 = add i64 0, 0
    br label %if_143_merge
if_143_else:
    %v155 = getelementptr i8, ptr @.str_118, i64 16
    %v156 = getelementptr i8, ptr @.str_294, i64 16
    %v157 = getelementptr i8, ptr @.str_295, i64 16
    %v158 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v159 = getelementptr i8, ptr @.str_118, i64 16
    %v160 = getelementptr i8, ptr @.str_303, i64 16
    %v161 = getelementptr i8, ptr @.str_304, i64 16
    %v162 = load ptr, ptr %v124
    %v163 = call ptr @orion_map_new(i64 2)
    %v163.p0 = ptrtoint ptr %v160 to i64
    call void @orion_map_set(ptr %v163, ptr %v159, i64 %v163.p0)
    %v163.p1 = ptrtoint ptr %v162 to i64
    call void @orion_map_set(ptr %v163, ptr %v161, i64 %v163.p1)
    %v164.p = ptrtoint ptr %v163 to i64
    %v164 = call ptr @orion_list_push(ptr %v158, i64 %v164.p)
    %v165.p = ptrtoint ptr %v137 to i64
    %v165 = call ptr @orion_list_push(ptr %v164, i64 %v165.p)
    %v166 = call ptr @orion_map_new(i64 2)
    %v166.p0 = ptrtoint ptr %v156 to i64
    call void @orion_map_set(ptr %v166, ptr %v155, i64 %v166.p0)
    %v166.p1 = ptrtoint ptr %v165 to i64
    call void @orion_map_set(ptr %v166, ptr %v157, i64 %v166.p1)
    store ptr %v166, ptr %v124
    %v167 = add i64 0, 0
    br label %if_143_merge
if_143_merge:
    %v170 = phi i64 [ %v152, %if_143_then ], [ %v167, %if_143_else ]
    %v171 = getelementptr i8, ptr @.str_305, i64 16
    %v172 = call ptr @orion_int_to_text(i64 %v1)
    %v173 = call ptr @orion_text_concat(ptr %v171, ptr %v172)
    %v174 = getelementptr i8, ptr @.str_118, i64 16
    %v175 = getelementptr i8, ptr @.str_306, i64 16
    %v176 = getelementptr i8, ptr @.str_274, i64 16
    %v177 = getelementptr i8, ptr @.str_307, i64 16
    %v178 = call ptr @orion_list_new(i64 1)
    %v178.lp0 = ptrtoint ptr %v177 to i64
    call void @orion_list_set(ptr %v178, i64 0, i64 %v178.lp0)
    %v179 = getelementptr i8, ptr @.str_308, i64 16
    %v180 = getelementptr i8, ptr @.str_118, i64 16
    %v181 = getelementptr i8, ptr @.str_259, i64 16
    %v182 = getelementptr i8, ptr @.str_257, i64 16
    %v183 = getelementptr i8, ptr @.str_209, i64 16
    %v184 = call ptr @orion_map_new(i64 2)
    %v184.p0 = ptrtoint ptr %v181 to i64
    call void @orion_map_set(ptr %v184, ptr %v180, i64 %v184.p0)
    %v184.p1 = ptrtoint ptr %v183 to i64
    call void @orion_map_set(ptr %v184, ptr %v182, i64 %v184.p1)
    %v185 = call ptr @orion_list_new(i64 1)
    %v185.lp0 = ptrtoint ptr %v184 to i64
    call void @orion_list_set(ptr %v185, i64 0, i64 %v185.lp0)
    %v186 = getelementptr i8, ptr @.str_282, i64 16
    %v187 = load ptr, ptr %v124
    %v188 = call ptr @orion_map_new(i64 4)
    %v188.p0 = ptrtoint ptr %v175 to i64
    call void @orion_map_set(ptr %v188, ptr %v174, i64 %v188.p0)
    %v188.p1 = ptrtoint ptr %v178 to i64
    call void @orion_map_set(ptr %v188, ptr %v176, i64 %v188.p1)
    %v188.p2 = ptrtoint ptr %v185 to i64
    call void @orion_map_set(ptr %v188, ptr %v179, i64 %v188.p2)
    %v188.p3 = ptrtoint ptr %v187 to i64
    call void @orion_map_set(ptr %v188, ptr %v186, i64 %v188.p3)
    %v189 = getelementptr i8, ptr @.str_118, i64 16
    %v190 = getelementptr i8, ptr @.str_251, i64 16
    %v191 = getelementptr i8, ptr @.str_252, i64 16
    %v192 = getelementptr i8, ptr @.str_290, i64 16
    %v193 = getelementptr i8, ptr @.str_253, i64 16
    %v194 = getelementptr i8, ptr @.str_118, i64 16
    %v195 = getelementptr i8, ptr @.str_256, i64 16
    %v196 = getelementptr i8, ptr @.str_257, i64 16
    %v197 = call ptr @orion_map_new(i64 2)
    %v197.p0 = ptrtoint ptr %v195 to i64
    call void @orion_map_set(ptr %v197, ptr %v194, i64 %v197.p0)
    %v197.p1 = ptrtoint ptr %v173 to i64
    call void @orion_map_set(ptr %v197, ptr %v196, i64 %v197.p1)
    %v198 = call ptr @orion_list_new(i64 2)
    %v198.lp0 = ptrtoint ptr %v197 to i64
    call void @orion_list_set(ptr %v198, i64 0, i64 %v198.lp0)
    %v198.lp1 = ptrtoint ptr %v188 to i64
    call void @orion_list_set(ptr %v198, i64 1, i64 %v198.lp1)
    %v199 = call ptr @orion_map_new(i64 3)
    %v199.p0 = ptrtoint ptr %v190 to i64
    call void @orion_map_set(ptr %v199, ptr %v189, i64 %v199.p0)
    %v199.p1 = ptrtoint ptr %v192 to i64
    call void @orion_map_set(ptr %v199, ptr %v191, i64 %v199.p1)
    %v199.p2 = ptrtoint ptr %v198 to i64
    call void @orion_map_set(ptr %v199, ptr %v193, i64 %v199.p2)
    %v200 = getelementptr i8, ptr @.str_118, i64 16
    %v201 = getelementptr i8, ptr @.str_292, i64 16
    %v202 = getelementptr i8, ptr @.str_257, i64 16
    %v203 = getelementptr i8, ptr @.str_119, i64 16
    %v204 = call ptr @orion_map_new(i64 3)
    %v204.p0 = ptrtoint ptr %v201 to i64
    call void @orion_map_set(ptr %v204, ptr %v200, i64 %v204.p0)
    %v204.p1 = ptrtoint ptr %v173 to i64
    call void @orion_map_set(ptr %v204, ptr %v202, i64 %v204.p1)
    %v204.p2 = ptrtoint ptr %v199 to i64
    call void @orion_map_set(ptr %v204, ptr %v203, i64 %v204.p2)
    %v205 = getelementptr i8, ptr @.str_118, i64 16
    %v206 = getelementptr i8, ptr @.str_294, i64 16
    %v207 = getelementptr i8, ptr @.str_295, i64 16
    %v208 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v209.p = ptrtoint ptr %v204 to i64
    %v209 = call ptr @orion_list_push(ptr %v208, i64 %v209.p)
    %v210 = call ptr @orion_map_new(i64 2)
    %v210.p0 = ptrtoint ptr %v206 to i64
    call void @orion_map_set(ptr %v210, ptr %v205, i64 %v210.p0)
    %v210.p1 = ptrtoint ptr %v209 to i64
    call void @orion_map_set(ptr %v210, ptr %v207, i64 %v210.p1)
    %v211 = getelementptr i8, ptr @.str_118, i64 16
    %v212 = getelementptr i8, ptr @.str_296, i64 16
    %v213 = getelementptr i8, ptr @.str_297, i64 16
    %v214 = getelementptr i8, ptr @.str_298, i64 16
    %v215 = getelementptr i8, ptr @.str_5, i64 16
    %v216 = getelementptr i8, ptr @.str_299, i64 16
    %v217 = getelementptr i8, ptr @.str_282, i64 16
    %v218 = call ptr @orion_map_new(i64 5)
    %v218.p0 = ptrtoint ptr %v212 to i64
    call void @orion_map_set(ptr %v218, ptr %v211, i64 %v218.p0)
    %v218.p1 = ptrtoint ptr %v4 to i64
    call void @orion_map_set(ptr %v218, ptr %v213, i64 %v218.p1)
    %v218.p2 = ptrtoint ptr %v215 to i64
    call void @orion_map_set(ptr %v218, ptr %v214, i64 %v218.p2)
    %v218.p3 = ptrtoint ptr %v38 to i64
    call void @orion_map_set(ptr %v218, ptr %v216, i64 %v218.p3)
    %v218.p4 = ptrtoint ptr %v210 to i64
    call void @orion_map_set(ptr %v218, ptr %v217, i64 %v218.p4)
    %v219 = alloca ptr, align 8
    store ptr %v218, ptr %v219
    %v220 = add i64 0, 0
    %v221.cb = icmp ne i64 %v66, 0
    br i1 %v221.cb, label %if_221_then, label %if_221_else
if_221_then:
    %v223 = getelementptr i8, ptr @.str_118, i64 16
    %v224 = getelementptr i8, ptr @.str_309, i64 16
    %v225 = getelementptr i8, ptr @.str_297, i64 16
    %v226 = getelementptr i8, ptr @.str_269, i64 16
    %v227 = getelementptr i8, ptr @.str_270, i64 16
    %v228 = load ptr, ptr %v72
    %v229 = getelementptr i8, ptr @.str_271, i64 16
    %v230 = getelementptr i8, ptr @.str_215, i64 16
    %v231.e = call i64 @orion_text_eq(ptr %v43, ptr %v230)
    %v231 = add i64 %v231.e, 0
    %v232.cb = icmp ne i64 %v231, 0
    br i1 %v232.cb, label %if_232_then, label %if_232_else
if_232_then:
    %v234 = add i64 0, 1
    br label %if_232_merge
if_232_else:
    %v237 = add i64 0, 0
    br label %if_232_merge
if_232_merge:
    %v240 = phi i64 [ %v234, %if_232_then ], [ %v237, %if_232_else ]
    %v241 = getelementptr i8, ptr @.str_282, i64 16
    %v242 = call ptr @orion_map_new(i64 6)
    %v242.p0 = ptrtoint ptr %v224 to i64
    call void @orion_map_set(ptr %v242, ptr %v223, i64 %v242.p0)
    %v242.p1 = ptrtoint ptr %v4 to i64
    call void @orion_map_set(ptr %v242, ptr %v225, i64 %v242.p1)
    %v242.p2 = ptrtoint ptr %v38 to i64
    call void @orion_map_set(ptr %v242, ptr %v226, i64 %v242.p2)
    %v242.p3 = ptrtoint ptr %v228 to i64
    call void @orion_map_set(ptr %v242, ptr %v227, i64 %v242.p3)
    call void @orion_map_set(ptr %v242, ptr %v229, i64 %v240)
    %v242.p5 = ptrtoint ptr %v210 to i64
    call void @orion_map_set(ptr %v242, ptr %v241, i64 %v242.p5)
    store ptr %v242, ptr %v219
    %v243 = add i64 0, 0
    br label %if_221_merge
if_221_else:
    br label %if_221_merge
if_221_merge:
    %v248 = getelementptr i8, ptr @.str_118, i64 16
    %v249 = getelementptr i8, ptr @.str_300, i64 16
    %v250 = getelementptr i8, ptr @.str_257, i64 16
    %v251 = getelementptr i8, ptr @.str_119, i64 16
    %v252 = getelementptr i8, ptr @.str_118, i64 16
    %v253 = getelementptr i8, ptr @.str_301, i64 16
    %v254 = getelementptr i8, ptr @.str_302, i64 16
    %v255 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v256 = call ptr @orion_map_new(i64 2)
    %v256.p0 = ptrtoint ptr %v253 to i64
    call void @orion_map_set(ptr %v256, ptr %v252, i64 %v256.p0)
    %v256.p1 = ptrtoint ptr %v255 to i64
    call void @orion_map_set(ptr %v256, ptr %v254, i64 %v256.p1)
    %v257 = call ptr @orion_map_new(i64 3)
    %v257.p0 = ptrtoint ptr %v249 to i64
    call void @orion_map_set(ptr %v257, ptr %v248, i64 %v257.p0)
    %v257.p1 = ptrtoint ptr %v173 to i64
    call void @orion_map_set(ptr %v257, ptr %v250, i64 %v257.p1)
    %v257.p2 = ptrtoint ptr %v256 to i64
    call void @orion_map_set(ptr %v257, ptr %v251, i64 %v257.p2)
    %v258 = getelementptr i8, ptr @.str_118, i64 16
    %v259 = getelementptr i8, ptr @.str_303, i64 16
    %v260 = getelementptr i8, ptr @.str_304, i64 16
    %v261 = getelementptr i8, ptr @.str_118, i64 16
    %v262 = getelementptr i8, ptr @.str_251, i64 16
    %v263 = getelementptr i8, ptr @.str_252, i64 16
    %v264 = getelementptr i8, ptr @.str_310, i64 16
    %v265 = getelementptr i8, ptr @.str_253, i64 16
    %v266 = getelementptr i8, ptr @.str_118, i64 16
    %v267 = getelementptr i8, ptr @.str_256, i64 16
    %v268 = getelementptr i8, ptr @.str_257, i64 16
    %v269 = call ptr @orion_map_new(i64 2)
    %v269.p0 = ptrtoint ptr %v267 to i64
    call void @orion_map_set(ptr %v269, ptr %v266, i64 %v269.p0)
    %v269.p1 = ptrtoint ptr %v173 to i64
    call void @orion_map_set(ptr %v269, ptr %v268, i64 %v269.p1)
    %v270 = getelementptr i8, ptr @.str_118, i64 16
    %v271 = getelementptr i8, ptr @.str_250, i64 16
    %v272 = getelementptr i8, ptr @.str_119, i64 16
    %v273 = getelementptr i8, ptr @.str_210, i64 16
    %v274 = call ptr @orion_map_new(i64 2)
    %v274.p0 = ptrtoint ptr %v271 to i64
    call void @orion_map_set(ptr %v274, ptr %v270, i64 %v274.p0)
    %v274.p1 = ptrtoint ptr %v273 to i64
    call void @orion_map_set(ptr %v274, ptr %v272, i64 %v274.p1)
    %v275 = call ptr @orion_list_new(i64 2)
    %v275.lp0 = ptrtoint ptr %v269 to i64
    call void @orion_list_set(ptr %v275, i64 0, i64 %v275.lp0)
    %v275.lp1 = ptrtoint ptr %v274 to i64
    call void @orion_list_set(ptr %v275, i64 1, i64 %v275.lp1)
    %v276 = call ptr @orion_map_new(i64 3)
    %v276.p0 = ptrtoint ptr %v262 to i64
    call void @orion_map_set(ptr %v276, ptr %v261, i64 %v276.p0)
    %v276.p1 = ptrtoint ptr %v264 to i64
    call void @orion_map_set(ptr %v276, ptr %v263, i64 %v276.p1)
    %v276.p2 = ptrtoint ptr %v275 to i64
    call void @orion_map_set(ptr %v276, ptr %v265, i64 %v276.p2)
    %v277 = call ptr @orion_map_new(i64 2)
    %v277.p0 = ptrtoint ptr %v259 to i64
    call void @orion_map_set(ptr %v277, ptr %v258, i64 %v277.p0)
    %v277.p1 = ptrtoint ptr %v276 to i64
    call void @orion_map_set(ptr %v277, ptr %v260, i64 %v277.p1)
    %v278 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v279.p = ptrtoint ptr %v257 to i64
    %v279 = call ptr @orion_list_push(ptr %v278, i64 %v279.p)
    %v280 = load ptr, ptr %v219
    %v281.p = ptrtoint ptr %v280 to i64
    %v281 = call ptr @orion_list_push(ptr %v279, i64 %v281.p)
    %v282.p = ptrtoint ptr %v277 to i64
    %v282 = call ptr @orion_list_push(ptr %v281, i64 %v282.p)
    %v283 = getelementptr i8, ptr @.str_260, i64 16
    %v284 = getelementptr i8, ptr @.str_118, i64 16
    %v285 = getelementptr i8, ptr @.str_294, i64 16
    %v286 = getelementptr i8, ptr @.str_295, i64 16
    %v287 = call ptr @orion_map_new(i64 2)
    %v287.p0 = ptrtoint ptr %v285 to i64
    call void @orion_map_set(ptr %v287, ptr %v284, i64 %v287.p0)
    %v287.p1 = ptrtoint ptr %v282 to i64
    call void @orion_map_set(ptr %v287, ptr %v286, i64 %v287.p1)
    %v288 = getelementptr i8, ptr @.str_124, i64 16
    %v289 = load i64, ptr %v7
    %v290 = call ptr @orion_map_new(i64 2)
    %v290.p0 = ptrtoint ptr %v287 to i64
    call void @orion_map_set(ptr %v290, ptr %v283, i64 %v290.p0)
    call void @orion_map_set(ptr %v290, ptr %v288, i64 %v289)
    ret ptr %v290
}

define ptr @prog__psr_parse_primary(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v1)
    %v3 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v1)
    %v4 = getelementptr i8, ptr @.str_123, i64 16
    %v5.e = call i64 @orion_text_eq(ptr %v2, ptr %v4)
    %v5 = add i64 %v5.e, 0
    %v6.cb = icmp ne i64 %v5, 0
    br i1 %v6.cb, label %if_6_then, label %if_6_else
if_6_then:
    %v8 = getelementptr i8, ptr @.str_171, i64 16
    %v9.e = call i64 @orion_text_eq(ptr %v3, ptr %v8)
    %v9 = add i64 %v9.e, 0
    br label %if_6_merge
if_6_else:
    %v12 = add i64 0, 0
    br label %if_6_merge
if_6_merge:
    %v15 = phi i64 [ %v9, %if_6_then ], [ %v12, %if_6_else ]
    %v16 = getelementptr i8, ptr @.str_248, i64 16
    %v17.e = call i64 @orion_text_eq(ptr %v2, ptr %v16)
    %v17 = add i64 %v17.e, 0
    %v18.cb = icmp ne i64 %v17, 0
    br i1 %v18.cb, label %if_18_then, label %if_18_else
if_18_then:
    %v20 = getelementptr i8, ptr @.str_226, i64 16
    %v21.e = call i64 @orion_text_eq(ptr %v3, ptr %v20)
    %v21 = add i64 %v21.e, 0
    br label %if_18_merge
if_18_else:
    %v24 = add i64 0, 0
    br label %if_18_merge
if_18_merge:
    %v27 = phi i64 [ %v21, %if_18_then ], [ %v24, %if_18_else ]
    %v28 = getelementptr i8, ptr @.str_260, i64 16
    %v29 = getelementptr i8, ptr @.str_118, i64 16
    %v30 = getelementptr i8, ptr @.str_265, i64 16
    %v31 = getelementptr i8, ptr @.str_266, i64 16
    %v32 = getelementptr i8, ptr @.str_5, i64 16
    %v33 = call ptr @orion_map_new(i64 2)
    %v33.p0 = ptrtoint ptr %v30 to i64
    call void @orion_map_set(ptr %v33, ptr %v29, i64 %v33.p0)
    %v33.p1 = ptrtoint ptr %v32 to i64
    call void @orion_map_set(ptr %v33, ptr %v31, i64 %v33.p1)
    %v34 = getelementptr i8, ptr @.str_124, i64 16
    %v35 = call ptr @orion_map_new(i64 2)
    %v35.p0 = ptrtoint ptr %v33 to i64
    call void @orion_map_set(ptr %v35, ptr %v28, i64 %v35.p0)
    call void @orion_map_set(ptr %v35, ptr %v34, i64 %v1)
    %v36 = alloca ptr, align 8
    store ptr %v35, ptr %v36
    %v37 = add i64 0, 0
    %v38.cb = icmp ne i64 %v15, 0
    br i1 %v38.cb, label %if_38_then, label %if_38_else
if_38_then:
    %v40 = add i64 0, 1
    %v41 = add i64 %v1, %v40
    %v42 = call ptr @prog__psr_parse_primary(ptr %v0, i64 %v41)
    %v43 = getelementptr i8, ptr @.str_124, i64 16
    %v44 = call i64 @orion_map_get(ptr %v42, ptr %v43)
    %v45 = getelementptr i8, ptr @.str_260, i64 16
    %v46.i = call i64 @orion_map_get(ptr %v42, ptr %v45)
    %v46.raw = inttoptr i64 %v46.i to ptr
    %v46.isnull = icmp eq i64 %v46.i, 0
    %v46 = select i1 %v46.isnull, ptr @orion_empty_list, ptr %v46.raw
    %v47 = call ptr @prog__psr_parse_postfix(ptr %v0, i64 %v44, ptr %v46)
    %v48 = getelementptr i8, ptr @.str_260, i64 16
    %v49 = getelementptr i8, ptr @.str_118, i64 16
    %v50 = getelementptr i8, ptr @.str_311, i64 16
    %v51 = getelementptr i8, ptr @.str_312, i64 16
    %v52 = getelementptr i8, ptr @.str_171, i64 16
    %v53 = getelementptr i8, ptr @.str_313, i64 16
    %v54 = getelementptr i8, ptr @.str_260, i64 16
    %v55.i = call i64 @orion_map_get(ptr %v47, ptr %v54)
    %v55.raw = inttoptr i64 %v55.i to ptr
    %v55.isnull = icmp eq i64 %v55.i, 0
    %v55 = select i1 %v55.isnull, ptr @orion_empty_list, ptr %v55.raw
    %v56 = call ptr @orion_map_new(i64 3)
    %v56.p0 = ptrtoint ptr %v50 to i64
    call void @orion_map_set(ptr %v56, ptr %v49, i64 %v56.p0)
    %v56.p1 = ptrtoint ptr %v52 to i64
    call void @orion_map_set(ptr %v56, ptr %v51, i64 %v56.p1)
    %v56.p2 = ptrtoint ptr %v55 to i64
    call void @orion_map_set(ptr %v56, ptr %v53, i64 %v56.p2)
    %v57 = getelementptr i8, ptr @.str_124, i64 16
    %v58 = getelementptr i8, ptr @.str_124, i64 16
    %v59 = call i64 @orion_map_get(ptr %v47, ptr %v58)
    %v60 = call ptr @orion_map_new(i64 2)
    %v60.p0 = ptrtoint ptr %v56 to i64
    call void @orion_map_set(ptr %v60, ptr %v48, i64 %v60.p0)
    call void @orion_map_set(ptr %v60, ptr %v57, i64 %v59)
    store ptr %v60, ptr %v36
    %v61 = add i64 0, 0
    br label %if_38_merge
if_38_else:
    br label %if_38_merge
if_38_merge:
    %v66.cb = icmp ne i64 %v27, 0
    br i1 %v66.cb, label %if_66_then, label %if_66_else
if_66_then:
    %v68 = add i64 0, 1
    %v69 = add i64 %v1, %v68
    %v70 = call ptr @prog__psr_parse_primary(ptr %v0, i64 %v69)
    %v71 = getelementptr i8, ptr @.str_124, i64 16
    %v72 = call i64 @orion_map_get(ptr %v70, ptr %v71)
    %v73 = getelementptr i8, ptr @.str_260, i64 16
    %v74.i = call i64 @orion_map_get(ptr %v70, ptr %v73)
    %v74.raw = inttoptr i64 %v74.i to ptr
    %v74.isnull = icmp eq i64 %v74.i, 0
    %v74 = select i1 %v74.isnull, ptr @orion_empty_list, ptr %v74.raw
    %v75 = call ptr @prog__psr_parse_postfix(ptr %v0, i64 %v72, ptr %v74)
    %v76 = getelementptr i8, ptr @.str_260, i64 16
    %v77 = getelementptr i8, ptr @.str_118, i64 16
    %v78 = getelementptr i8, ptr @.str_311, i64 16
    %v79 = getelementptr i8, ptr @.str_312, i64 16
    %v80 = getelementptr i8, ptr @.str_314, i64 16
    %v81 = getelementptr i8, ptr @.str_313, i64 16
    %v82 = getelementptr i8, ptr @.str_260, i64 16
    %v83.i = call i64 @orion_map_get(ptr %v75, ptr %v82)
    %v83.raw = inttoptr i64 %v83.i to ptr
    %v83.isnull = icmp eq i64 %v83.i, 0
    %v83 = select i1 %v83.isnull, ptr @orion_empty_list, ptr %v83.raw
    %v84 = call ptr @orion_map_new(i64 3)
    %v84.p0 = ptrtoint ptr %v78 to i64
    call void @orion_map_set(ptr %v84, ptr %v77, i64 %v84.p0)
    %v84.p1 = ptrtoint ptr %v80 to i64
    call void @orion_map_set(ptr %v84, ptr %v79, i64 %v84.p1)
    %v84.p2 = ptrtoint ptr %v83 to i64
    call void @orion_map_set(ptr %v84, ptr %v81, i64 %v84.p2)
    %v85 = getelementptr i8, ptr @.str_124, i64 16
    %v86 = getelementptr i8, ptr @.str_124, i64 16
    %v87 = call i64 @orion_map_get(ptr %v75, ptr %v86)
    %v88 = call ptr @orion_map_new(i64 2)
    %v88.p0 = ptrtoint ptr %v84 to i64
    call void @orion_map_set(ptr %v88, ptr %v76, i64 %v88.p0)
    call void @orion_map_set(ptr %v88, ptr %v85, i64 %v87)
    store ptr %v88, ptr %v36
    %v89 = add i64 0, 0
    br label %if_66_merge
if_66_else:
    br label %if_66_merge
if_66_merge:
    %v94 = getelementptr i8, ptr @.str_123, i64 16
    %v95.e = call i64 @orion_text_eq(ptr %v2, ptr %v94)
    %v95 = add i64 %v95.e, 0
    %v96 = getelementptr i8, ptr @.str_209, i64 16
    %v97.e = call i64 @orion_text_eq(ptr %v2, ptr %v96)
    %v97 = add i64 %v97.e, 0
    %v98 = getelementptr i8, ptr @.str_208, i64 16
    %v99.e = call i64 @orion_text_eq(ptr %v2, ptr %v98)
    %v99 = add i64 %v99.e, 0
    %v100 = getelementptr i8, ptr @.str_212, i64 16
    %v101.e = call i64 @orion_text_eq(ptr %v2, ptr %v100)
    %v101 = add i64 %v101.e, 0
    %v102 = getelementptr i8, ptr @.str_248, i64 16
    %v103.e = call i64 @orion_text_eq(ptr %v2, ptr %v102)
    %v103 = add i64 %v103.e, 0
    %v104.cb = icmp ne i64 %v103, 0
    br i1 %v104.cb, label %if_104_then, label %if_104_else
if_104_then:
    %v106 = getelementptr i8, ptr @.str_238, i64 16
    %v107.e = call i64 @orion_text_eq(ptr %v3, ptr %v106)
    %v107 = add i64 %v107.e, 0
    br label %if_104_merge
if_104_else:
    %v110 = add i64 0, 0
    br label %if_104_merge
if_104_merge:
    %v113 = phi i64 [ %v107, %if_104_then ], [ %v110, %if_104_else ]
    %v114 = getelementptr i8, ptr @.str_248, i64 16
    %v115.e = call i64 @orion_text_eq(ptr %v2, ptr %v114)
    %v115 = add i64 %v115.e, 0
    %v116.cb = icmp ne i64 %v115, 0
    br i1 %v116.cb, label %if_116_then, label %if_116_else
if_116_then:
    %v118 = getelementptr i8, ptr @.str_240, i64 16
    %v119.e = call i64 @orion_text_eq(ptr %v3, ptr %v118)
    %v119 = add i64 %v119.e, 0
    br label %if_116_merge
if_116_else:
    %v122 = add i64 0, 0
    br label %if_116_merge
if_116_merge:
    %v125 = phi i64 [ %v119, %if_116_then ], [ %v122, %if_116_else ]
    %v126 = getelementptr i8, ptr @.str_248, i64 16
    %v127.e = call i64 @orion_text_eq(ptr %v2, ptr %v126)
    %v127 = add i64 %v127.e, 0
    %v128.cb = icmp ne i64 %v127, 0
    br i1 %v128.cb, label %if_128_then, label %if_128_else
if_128_then:
    %v130 = getelementptr i8, ptr @.str_233, i64 16
    %v131.e = call i64 @orion_text_eq(ptr %v3, ptr %v130)
    %v131 = add i64 %v131.e, 0
    br label %if_128_merge
if_128_else:
    %v134 = add i64 0, 0
    br label %if_128_merge
if_128_merge:
    %v137 = phi i64 [ %v131, %if_128_then ], [ %v134, %if_128_else ]
    %v138.cb = icmp ne i64 %v95, 0
    br i1 %v138.cb, label %if_138_then, label %if_138_else
if_138_then:
    %v140 = getelementptr i8, ptr @.str_143, i64 16
    %v141.e = call i64 @orion_text_eq(ptr %v3, ptr %v140)
    %v141 = add i64 %v141.e, 0
    br label %if_138_merge
if_138_else:
    %v144 = add i64 0, 0
    br label %if_138_merge
if_138_merge:
    %v147 = phi i64 [ %v141, %if_138_then ], [ %v144, %if_138_else ]
    %v148.cb = icmp ne i64 %v95, 0
    br i1 %v148.cb, label %if_148_then, label %if_148_else
if_148_then:
    %v150 = getelementptr i8, ptr @.str_161, i64 16
    %v151.e = call i64 @orion_text_eq(ptr %v3, ptr %v150)
    %v151 = add i64 %v151.e, 0
    br label %if_148_merge
if_148_else:
    %v154 = add i64 0, 0
    br label %if_148_merge
if_148_merge:
    %v157 = phi i64 [ %v151, %if_148_then ], [ %v154, %if_148_else ]
    %v158.cb = icmp ne i64 %v95, 0
    br i1 %v158.cb, label %if_158_then, label %if_158_else
if_158_then:
    %v160 = getelementptr i8, ptr @.str_155, i64 16
    %v161.e = call i64 @orion_text_eq(ptr %v3, ptr %v160)
    %v161 = add i64 %v161.e, 0
    br label %if_158_merge
if_158_else:
    %v164 = add i64 0, 0
    br label %if_158_merge
if_158_merge:
    %v167 = phi i64 [ %v161, %if_158_then ], [ %v164, %if_158_else ]
    %v168.cb = icmp ne i64 %v95, 0
    br i1 %v168.cb, label %if_168_then, label %if_168_else
if_168_then:
    %v170 = getelementptr i8, ptr @.str_125, i64 16
    %v171.e = call i64 @orion_text_eq(ptr %v3, ptr %v170)
    %v171 = add i64 %v171.e, 0
    br label %if_168_merge
if_168_else:
    %v174 = add i64 0, 0
    br label %if_168_merge
if_168_merge:
    %v177 = phi i64 [ %v171, %if_168_then ], [ %v174, %if_168_else ]
    %v178.cb = icmp ne i64 %v177, 0
    br i1 %v178.cb, label %if_178_then, label %if_178_else
if_178_then:
    %v180 = add i64 0, 1
    %v181 = add i64 %v1, %v180
    %v182 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v181)
    %v183 = getelementptr i8, ptr @.str_248, i64 16
    %v184.e = call i64 @orion_text_eq(ptr %v182, ptr %v183)
    %v184 = add i64 %v184.e, 0
    br label %if_178_merge
if_178_else:
    %v187 = add i64 0, 0
    br label %if_178_merge
if_178_merge:
    %v190 = phi i64 [ %v184, %if_178_then ], [ %v187, %if_178_else ]
    %v191.cb = icmp ne i64 %v190, 0
    br i1 %v191.cb, label %if_191_then, label %if_191_else
if_191_then:
    %v193 = add i64 0, 1
    %v194 = add i64 %v1, %v193
    %v195 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v194)
    %v196 = getelementptr i8, ptr @.str_233, i64 16
    %v197.e = call i64 @orion_text_eq(ptr %v195, ptr %v196)
    %v197 = add i64 %v197.e, 0
    br label %if_191_merge
if_191_else:
    %v200 = add i64 0, 0
    br label %if_191_merge
if_191_merge:
    %v203 = phi i64 [ %v197, %if_191_then ], [ %v200, %if_191_else ]
    %v204.cb = icmp ne i64 %v95, 0
    br i1 %v204.cb, label %if_204_then, label %if_204_else
if_204_then:
    %v206 = getelementptr i8, ptr @.str_315, i64 16
    %v207.e = call i64 @orion_text_eq(ptr %v3, ptr %v206)
    %v207 = add i64 %v207.e, 0
    br label %if_204_merge
if_204_else:
    %v210 = add i64 0, 0
    br label %if_204_merge
if_204_merge:
    %v213 = phi i64 [ %v207, %if_204_then ], [ %v210, %if_204_else ]
    %v214.cb = icmp ne i64 %v213, 0
    br i1 %v214.cb, label %if_214_then, label %if_214_else
if_214_then:
    %v216 = add i64 0, 1
    %v217 = add i64 %v1, %v216
    %v218 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v217)
    %v219 = getelementptr i8, ptr @.str_123, i64 16
    %v220.e = call i64 @orion_text_eq(ptr %v218, ptr %v219)
    %v220 = add i64 %v220.e, 0
    br label %if_214_merge
if_214_else:
    %v223 = add i64 0, 0
    br label %if_214_merge
if_214_merge:
    %v226 = phi i64 [ %v220, %if_214_then ], [ %v223, %if_214_else ]
    %v227.cb = icmp ne i64 %v95, 0
    br i1 %v227.cb, label %if_227_then, label %if_227_else
if_227_then:
    %v229.n = icmp eq i64 %v147, 0
    %v229 = zext i1 %v229.n to i64
    br label %if_227_merge
if_227_else:
    %v232 = add i64 0, 0
    br label %if_227_merge
if_227_merge:
    %v235 = phi i64 [ %v229, %if_227_then ], [ %v232, %if_227_else ]
    %v236.cb = icmp ne i64 %v235, 0
    br i1 %v236.cb, label %if_236_then, label %if_236_else
if_236_then:
    %v238.n = icmp eq i64 %v15, 0
    %v238 = zext i1 %v238.n to i64
    br label %if_236_merge
if_236_else:
    %v241 = add i64 0, 0
    br label %if_236_merge
if_236_merge:
    %v244 = phi i64 [ %v238, %if_236_then ], [ %v241, %if_236_else ]
    %v245.cb = icmp ne i64 %v244, 0
    br i1 %v245.cb, label %if_245_then, label %if_245_else
if_245_then:
    %v247.n = icmp eq i64 %v157, 0
    %v247 = zext i1 %v247.n to i64
    br label %if_245_merge
if_245_else:
    %v250 = add i64 0, 0
    br label %if_245_merge
if_245_merge:
    %v253 = phi i64 [ %v247, %if_245_then ], [ %v250, %if_245_else ]
    %v254.cb = icmp ne i64 %v253, 0
    br i1 %v254.cb, label %if_254_then, label %if_254_else
if_254_then:
    %v256.n = icmp eq i64 %v167, 0
    %v256 = zext i1 %v256.n to i64
    br label %if_254_merge
if_254_else:
    %v259 = add i64 0, 0
    br label %if_254_merge
if_254_merge:
    %v262 = phi i64 [ %v256, %if_254_then ], [ %v259, %if_254_else ]
    %v263.cb = icmp ne i64 %v262, 0
    br i1 %v263.cb, label %if_263_then, label %if_263_else
if_263_then:
    %v265.n = icmp eq i64 %v203, 0
    %v265 = zext i1 %v265.n to i64
    br label %if_263_merge
if_263_else:
    %v268 = add i64 0, 0
    br label %if_263_merge
if_263_merge:
    %v271 = phi i64 [ %v265, %if_263_then ], [ %v268, %if_263_else ]
    %v272.cb = icmp ne i64 %v271, 0
    br i1 %v272.cb, label %if_272_then, label %if_272_else
if_272_then:
    %v274.n = icmp eq i64 %v226, 0
    %v274 = zext i1 %v274.n to i64
    br label %if_272_merge
if_272_else:
    %v277 = add i64 0, 0
    br label %if_272_merge
if_272_merge:
    %v280 = phi i64 [ %v274, %if_272_then ], [ %v277, %if_272_else ]
    %v281.cb = icmp ne i64 %v280, 0
    br i1 %v281.cb, label %if_281_then, label %if_281_else
if_281_then:
    %v283 = add i64 0, 1
    %v284 = add i64 %v1, %v283
    %v285 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v284)
    %v286 = getelementptr i8, ptr @.str_248, i64 16
    %v287.e = call i64 @orion_text_eq(ptr %v285, ptr %v286)
    %v287 = add i64 %v287.e, 0
    br label %if_281_merge
if_281_else:
    %v290 = add i64 0, 0
    br label %if_281_merge
if_281_merge:
    %v293 = phi i64 [ %v287, %if_281_then ], [ %v290, %if_281_else ]
    %v294.cb = icmp ne i64 %v293, 0
    br i1 %v294.cb, label %if_294_then, label %if_294_else
if_294_then:
    %v296 = add i64 0, 1
    %v297 = add i64 %v1, %v296
    %v298 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v297)
    %v299 = getelementptr i8, ptr @.str_233, i64 16
    %v300.e = call i64 @orion_text_eq(ptr %v298, ptr %v299)
    %v300 = add i64 %v300.e, 0
    br label %if_294_merge
if_294_else:
    %v303 = add i64 0, 0
    br label %if_294_merge
if_294_merge:
    %v306 = phi i64 [ %v300, %if_294_then ], [ %v303, %if_294_else ]
    %v307 = getelementptr i8, ptr @.str_260, i64 16
    %v308 = getelementptr i8, ptr @.str_118, i64 16
    %v309 = getelementptr i8, ptr @.str_265, i64 16
    %v310 = getelementptr i8, ptr @.str_266, i64 16
    %v311 = getelementptr i8, ptr @.str_316, i64 16
    %v312 = call ptr @orion_map_new(i64 2)
    %v312.p0 = ptrtoint ptr %v309 to i64
    call void @orion_map_set(ptr %v312, ptr %v308, i64 %v312.p0)
    %v312.p1 = ptrtoint ptr %v311 to i64
    call void @orion_map_set(ptr %v312, ptr %v310, i64 %v312.p1)
    %v313 = getelementptr i8, ptr @.str_124, i64 16
    %v314 = call ptr @orion_map_new(i64 2)
    %v314.p0 = ptrtoint ptr %v312 to i64
    call void @orion_map_set(ptr %v314, ptr %v307, i64 %v314.p0)
    call void @orion_map_set(ptr %v314, ptr %v313, i64 %v1)
    %v315 = alloca ptr, align 8
    store ptr %v314, ptr %v315
    %v316 = add i64 0, 0
    %v317.cb = icmp ne i64 %v226, 0
    br i1 %v317.cb, label %if_317_then, label %if_317_else
if_317_then:
    %v319 = add i64 0, 1
    %v320 = add i64 %v1, %v319
    %v321 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v320)
    %v322 = add i64 0, 2
    %v323 = add i64 %v1, %v322
    %v324 = alloca i64, align 8
    store i64 %v323, ptr %v324
    %v325 = add i64 0, 0
    %v326 = load i64, ptr %v324
    %v327 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v326)
    %v328 = getelementptr i8, ptr @.str_248, i64 16
    %v329.e = call i64 @orion_text_eq(ptr %v327, ptr %v328)
    %v329 = add i64 %v329.e, 0
    %v330.cb = icmp ne i64 %v329, 0
    br i1 %v330.cb, label %if_330_then, label %if_330_else
if_330_then:
    %v332 = load i64, ptr %v324
    %v333 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v332)
    %v334 = getelementptr i8, ptr @.str_103, i64 16
    %v335.e = call i64 @orion_text_eq(ptr %v333, ptr %v334)
    %v335 = add i64 %v335.e, 0
    br label %if_330_merge
if_330_else:
    %v338 = add i64 0, 0
    br label %if_330_merge
if_330_merge:
    %v341 = phi i64 [ %v335, %if_330_then ], [ %v338, %if_330_else ]
    %v342.cb = icmp ne i64 %v341, 0
    br i1 %v342.cb, label %if_342_then, label %if_342_else
if_342_then:
    %v344 = load i64, ptr %v324
    %v345 = add i64 0, 1
    %v346 = add i64 %v344, %v345
    store i64 %v346, ptr %v324
    %v347 = add i64 0, 0
    br label %if_342_merge
if_342_else:
    br label %if_342_merge
if_342_merge:
    %v352 = load i64, ptr %v324
    %v353 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v352)
    %v354 = load i64, ptr %v324
    %v355 = call ptr @prog__psr_parse_call(ptr %v0, i64 %v354, ptr %v353)
    %v356 = getelementptr i8, ptr @.str_260, i64 16
    %v357.i = call i64 @orion_map_get(ptr %v355, ptr %v356)
    %v357.raw = inttoptr i64 %v357.i to ptr
    %v357.isnull = icmp eq i64 %v357.i, 0
    %v357 = select i1 %v357.isnull, ptr @orion_empty_list, ptr %v357.raw
    %v358 = getelementptr i8, ptr @.str_253, i64 16
    %v359.i = call i64 @orion_map_get(ptr %v357, ptr %v358)
    %v359.raw = inttoptr i64 %v359.i to ptr
    %v359.isnull = icmp eq i64 %v359.i, 0
    %v359 = select i1 %v359.isnull, ptr @orion_empty_list, ptr %v359.raw
    %v360 = getelementptr i8, ptr @.str_260, i64 16
    %v361 = getelementptr i8, ptr @.str_118, i64 16
    %v362 = getelementptr i8, ptr @.str_317, i64 16
    %v363 = getelementptr i8, ptr @.str_318, i64 16
    %v364 = getelementptr i8, ptr @.str_312, i64 16
    %v365 = getelementptr i8, ptr @.str_253, i64 16
    %v366 = call ptr @orion_map_new(i64 4)
    %v366.p0 = ptrtoint ptr %v362 to i64
    call void @orion_map_set(ptr %v366, ptr %v361, i64 %v366.p0)
    %v366.p1 = ptrtoint ptr %v321 to i64
    call void @orion_map_set(ptr %v366, ptr %v363, i64 %v366.p1)
    %v366.p2 = ptrtoint ptr %v353 to i64
    call void @orion_map_set(ptr %v366, ptr %v364, i64 %v366.p2)
    %v366.p3 = ptrtoint ptr %v359 to i64
    call void @orion_map_set(ptr %v366, ptr %v365, i64 %v366.p3)
    %v367 = getelementptr i8, ptr @.str_124, i64 16
    %v368 = getelementptr i8, ptr @.str_124, i64 16
    %v369 = call i64 @orion_map_get(ptr %v355, ptr %v368)
    %v370 = call ptr @orion_map_new(i64 2)
    %v370.p0 = ptrtoint ptr %v366 to i64
    call void @orion_map_set(ptr %v370, ptr %v360, i64 %v370.p0)
    call void @orion_map_set(ptr %v370, ptr %v367, i64 %v369)
    store ptr %v370, ptr %v315
    %v371 = add i64 0, 0
    br label %if_317_merge
if_317_else:
    br label %if_317_merge
if_317_merge:
    %v376.cb = icmp ne i64 %v147, 0
    br i1 %v376.cb, label %if_376_then, label %if_376_else
if_376_then:
    %v378 = call ptr @prog__psr_parse_if(ptr %v0, i64 %v1)
    store ptr %v378, ptr %v315
    %v379 = add i64 0, 0
    br label %if_376_merge
if_376_else:
    br label %if_376_merge
if_376_merge:
    %v384.cb = icmp ne i64 %v167, 0
    br i1 %v384.cb, label %if_384_then, label %if_384_else
if_384_then:
    %v386 = call ptr @prog__psr_parse_for_collect(ptr %v0, i64 %v1)
    store ptr %v386, ptr %v315
    %v387 = add i64 0, 0
    br label %if_384_merge
if_384_else:
    br label %if_384_merge
if_384_merge:
    %v392.cb = icmp ne i64 %v157, 0
    br i1 %v392.cb, label %if_392_then, label %if_392_else
if_392_then:
    %v394 = call ptr @prog__psr_parse_match_node(ptr %v0, i64 %v1)
    store ptr %v394, ptr %v315
    %v395 = add i64 0, 0
    br label %if_392_merge
if_392_else:
    br label %if_392_merge
if_392_merge:
    %v400.cb = icmp ne i64 %v203, 0
    br i1 %v400.cb, label %if_400_then, label %if_400_else
if_400_then:
    %v402 = add i64 0, 2
    %v403 = add i64 %v1, %v402
    %v404 = alloca i64, align 8
    store i64 %v403, ptr %v404
    %v405 = add i64 0, 0
    %v406 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v407 = alloca ptr, align 8
    store ptr %v406, ptr %v407
    %v408 = add i64 0, 0
    %v409 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v410 = alloca ptr, align 8
    store ptr %v409, ptr %v410
    %v411 = add i64 0, 0
    br label %loop_412_header
loop_412_header:
    %v414 = load i64, ptr %v404
    %v415 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v414)
    %v416 = load i64, ptr %v404
    %v417 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v416)
    %v418 = getelementptr i8, ptr @.str_248, i64 16
    %v419.e = call i64 @orion_text_eq(ptr %v415, ptr %v418)
    %v419 = add i64 %v419.e, 0
    %v420.cb = icmp ne i64 %v419, 0
    br i1 %v420.cb, label %if_420_then, label %if_420_else
if_420_then:
    %v422 = getelementptr i8, ptr @.str_234, i64 16
    %v423.e = call i64 @orion_text_eq(ptr %v417, ptr %v422)
    %v423 = add i64 %v423.e, 0
    br label %if_420_merge
if_420_else:
    %v426 = add i64 0, 0
    br label %if_420_merge
if_420_merge:
    %v429 = phi i64 [ %v423, %if_420_then ], [ %v426, %if_420_else ]
    %v430.cb = icmp ne i64 %v429, 0
    br i1 %v430.cb, label %if_430_then, label %if_430_else
if_430_then:
    %v432 = load i64, ptr %v404
    %v433 = add i64 0, 1
    %v434 = add i64 %v432, %v433
    store i64 %v434, ptr %v404
    %v435 = add i64 0, 0
    br label %loop_412_end
if_430_else:
    br label %if_430_merge
if_430_merge:
    %v440 = getelementptr i8, ptr @.str_249, i64 16
    %v441.e = call i64 @orion_text_eq(ptr %v415, ptr %v440)
    %v441 = add i64 %v441.e, 0
    %v442.cb = icmp ne i64 %v441, 0
    br i1 %v442.cb, label %if_442_then, label %if_442_else
if_442_then:
    br label %loop_412_end
if_442_else:
    br label %if_442_merge
if_442_merge:
    %v448 = getelementptr i8, ptr @.str_123, i64 16
    %v449.e = call i64 @orion_text_eq(ptr %v415, ptr %v448)
    %v449 = add i64 %v449.e, 0
    %v450.cb = icmp ne i64 %v449, 0
    br i1 %v450.cb, label %if_450_then, label %if_450_else
if_450_then:
    %v452 = load ptr, ptr %v407
    %v453.p = ptrtoint ptr %v417 to i64
    %v453 = call ptr @orion_list_push(ptr %v452, i64 %v453.p)
    store ptr %v453, ptr %v407
    %v454 = add i64 0, 0
    %v455 = load i64, ptr %v404
    %v456 = add i64 0, 1
    %v457 = add i64 %v455, %v456
    store i64 %v457, ptr %v404
    %v458 = add i64 0, 0
    %v459 = load i64, ptr %v404
    %v460 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v459)
    %v461 = getelementptr i8, ptr @.str_248, i64 16
    %v462.e = call i64 @orion_text_eq(ptr %v460, ptr %v461)
    %v462 = add i64 %v462.e, 0
    %v463.cb = icmp ne i64 %v462, 0
    br i1 %v463.cb, label %if_463_then, label %if_463_else
if_463_then:
    %v465 = load i64, ptr %v404
    %v466 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v465)
    %v467 = getelementptr i8, ptr @.str_236, i64 16
    %v468.e = call i64 @orion_text_eq(ptr %v466, ptr %v467)
    %v468 = add i64 %v468.e, 0
    br label %if_463_merge
if_463_else:
    %v471 = add i64 0, 0
    br label %if_463_merge
if_463_merge:
    %v474 = phi i64 [ %v468, %if_463_then ], [ %v471, %if_463_else ]
    %v475.cb = icmp ne i64 %v474, 0
    br i1 %v475.cb, label %if_475_then, label %if_475_else
if_475_then:
    %v477 = load i64, ptr %v404
    %v478 = add i64 0, 1
    %v479 = add i64 %v477, %v478
    store i64 %v479, ptr %v404
    %v480 = add i64 0, 0
    %v481 = load i64, ptr %v404
    %v482 = call ptr @prog__psr_parse_type(ptr %v0, i64 %v481)
    %v483 = load ptr, ptr %v410
    %v484 = getelementptr i8, ptr @.str_260, i64 16
    %v485.i = call i64 @orion_map_get(ptr %v482, ptr %v484)
    %v485.raw = inttoptr i64 %v485.i to ptr
    %v485.isnull = icmp eq i64 %v485.i, 0
    %v485 = select i1 %v485.isnull, ptr @orion_empty_list, ptr %v485.raw
    %v486.p = ptrtoint ptr %v485 to i64
    %v486 = call ptr @orion_list_push(ptr %v483, i64 %v486.p)
    store ptr %v486, ptr %v410
    %v487 = add i64 0, 0
    %v488 = getelementptr i8, ptr @.str_124, i64 16
    %v489 = call i64 @orion_map_get(ptr %v482, ptr %v488)
    store i64 %v489, ptr %v404
    %v490 = add i64 0, 0
    br label %if_475_merge
if_475_else:
    %v493 = load ptr, ptr %v410
    %v494 = getelementptr i8, ptr @.str_118, i64 16
    %v495 = getelementptr i8, ptr @.str_259, i64 16
    %v496 = getelementptr i8, ptr @.str_257, i64 16
    %v497 = getelementptr i8, ptr @.str_209, i64 16
    %v498 = call ptr @orion_map_new(i64 2)
    %v498.p0 = ptrtoint ptr %v495 to i64
    call void @orion_map_set(ptr %v498, ptr %v494, i64 %v498.p0)
    %v498.p1 = ptrtoint ptr %v497 to i64
    call void @orion_map_set(ptr %v498, ptr %v496, i64 %v498.p1)
    %v499.p = ptrtoint ptr %v498 to i64
    %v499 = call ptr @orion_list_push(ptr %v493, i64 %v499.p)
    store ptr %v499, ptr %v410
    %v500 = add i64 0, 0
    br label %if_475_merge
if_475_merge:
    %v503 = phi i64 [ %v490, %if_475_then ], [ %v500, %if_475_else ]
    br label %if_450_merge
if_450_else:
    br label %if_450_merge
if_450_merge:
    %v508 = getelementptr i8, ptr @.str_248, i64 16
    %v509.e = call i64 @orion_text_eq(ptr %v415, ptr %v508)
    %v509 = add i64 %v509.e, 0
    %v510.cb = icmp ne i64 %v509, 0
    br i1 %v510.cb, label %if_510_then, label %if_510_else
if_510_then:
    %v512 = getelementptr i8, ptr @.str_235, i64 16
    %v513.e = call i64 @orion_text_eq(ptr %v417, ptr %v512)
    %v513 = add i64 %v513.e, 0
    br label %if_510_merge
if_510_else:
    %v516 = add i64 0, 0
    br label %if_510_merge
if_510_merge:
    %v519 = phi i64 [ %v513, %if_510_then ], [ %v516, %if_510_else ]
    %v520.cb = icmp ne i64 %v519, 0
    br i1 %v520.cb, label %if_520_then, label %if_520_else
if_520_then:
    %v522 = load i64, ptr %v404
    %v523 = add i64 0, 1
    %v524 = add i64 %v522, %v523
    store i64 %v524, ptr %v404
    %v525 = add i64 0, 0
    br label %if_520_merge
if_520_else:
    br label %if_520_merge
if_520_merge:
    br label %loop_412_header
loop_412_end:
    %v532 = load i64, ptr %v404
    %v533 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v532)
    %v534 = getelementptr i8, ptr @.str_248, i64 16
    %v535.e = call i64 @orion_text_eq(ptr %v533, ptr %v534)
    %v535 = add i64 %v535.e, 0
    %v536.cb = icmp ne i64 %v535, 0
    br i1 %v536.cb, label %if_536_then, label %if_536_else
if_536_then:
    %v538 = load i64, ptr %v404
    %v539 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v538)
    %v540 = getelementptr i8, ptr @.str_236, i64 16
    %v541.e = call i64 @orion_text_eq(ptr %v539, ptr %v540)
    %v541 = add i64 %v541.e, 0
    br label %if_536_merge
if_536_else:
    %v544 = add i64 0, 0
    br label %if_536_merge
if_536_merge:
    %v547 = phi i64 [ %v541, %if_536_then ], [ %v544, %if_536_else ]
    %v548.cb = icmp ne i64 %v547, 0
    br i1 %v548.cb, label %if_548_then, label %if_548_else
if_548_then:
    %v550 = load i64, ptr %v404
    %v551 = add i64 0, 1
    %v552 = add i64 %v550, %v551
    store i64 %v552, ptr %v404
    %v553 = add i64 0, 0
    br label %if_548_merge
if_548_else:
    br label %if_548_merge
if_548_merge:
    %v558 = load i64, ptr %v404
    %v559 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v558)
    %v560 = getelementptr i8, ptr @.str_260, i64 16
    %v561 = getelementptr i8, ptr @.str_118, i64 16
    %v562 = getelementptr i8, ptr @.str_306, i64 16
    %v563 = getelementptr i8, ptr @.str_274, i64 16
    %v564 = load ptr, ptr %v407
    %v565 = getelementptr i8, ptr @.str_308, i64 16
    %v566 = load ptr, ptr %v410
    %v567 = getelementptr i8, ptr @.str_282, i64 16
    %v568 = getelementptr i8, ptr @.str_260, i64 16
    %v569.i = call i64 @orion_map_get(ptr %v559, ptr %v568)
    %v569.raw = inttoptr i64 %v569.i to ptr
    %v569.isnull = icmp eq i64 %v569.i, 0
    %v569 = select i1 %v569.isnull, ptr @orion_empty_list, ptr %v569.raw
    %v570 = call ptr @orion_map_new(i64 4)
    %v570.p0 = ptrtoint ptr %v562 to i64
    call void @orion_map_set(ptr %v570, ptr %v561, i64 %v570.p0)
    %v570.p1 = ptrtoint ptr %v564 to i64
    call void @orion_map_set(ptr %v570, ptr %v563, i64 %v570.p1)
    %v570.p2 = ptrtoint ptr %v566 to i64
    call void @orion_map_set(ptr %v570, ptr %v565, i64 %v570.p2)
    %v570.p3 = ptrtoint ptr %v569 to i64
    call void @orion_map_set(ptr %v570, ptr %v567, i64 %v570.p3)
    %v571 = getelementptr i8, ptr @.str_124, i64 16
    %v572 = getelementptr i8, ptr @.str_124, i64 16
    %v573 = call i64 @orion_map_get(ptr %v559, ptr %v572)
    %v574 = call ptr @orion_map_new(i64 2)
    %v574.p0 = ptrtoint ptr %v570 to i64
    call void @orion_map_set(ptr %v574, ptr %v560, i64 %v574.p0)
    call void @orion_map_set(ptr %v574, ptr %v571, i64 %v573)
    store ptr %v574, ptr %v315
    %v575 = add i64 0, 0
    br label %if_400_merge
if_400_else:
    br label %if_400_merge
if_400_merge:
    %v580.cb = icmp ne i64 %v306, 0
    br i1 %v580.cb, label %if_580_then, label %if_580_else
if_580_then:
    %v582 = call ptr @prog__psr_parse_call(ptr %v0, i64 %v1, ptr %v3)
    store ptr %v582, ptr %v315
    %v583 = add i64 0, 0
    br label %if_580_merge
if_580_else:
    br label %if_580_merge
if_580_merge:
    %v588.cb = icmp ne i64 %v95, 0
    br i1 %v588.cb, label %if_588_then, label %if_588_else
if_588_then:
    %v590 = getelementptr i8, ptr @.str_163, i64 16
    %v591.e = call i64 @orion_text_eq(ptr %v3, ptr %v590)
    %v591 = add i64 %v591.e, 0
    br label %if_588_merge
if_588_else:
    %v594 = add i64 0, 0
    br label %if_588_merge
if_588_merge:
    %v597 = phi i64 [ %v591, %if_588_then ], [ %v594, %if_588_else ]
    %v598.cb = icmp ne i64 %v95, 0
    br i1 %v598.cb, label %if_598_then, label %if_598_else
if_598_then:
    %v600 = getelementptr i8, ptr @.str_165, i64 16
    %v601.e = call i64 @orion_text_eq(ptr %v3, ptr %v600)
    %v601 = add i64 %v601.e, 0
    br label %if_598_merge
if_598_else:
    %v604 = add i64 0, 0
    br label %if_598_merge
if_598_merge:
    %v607 = phi i64 [ %v601, %if_598_then ], [ %v604, %if_598_else ]
    %v608.cb = icmp ne i64 %v95, 0
    br i1 %v608.cb, label %if_608_then, label %if_608_else
if_608_then:
    %v610.n = icmp eq i64 %v306, 0
    %v610 = zext i1 %v610.n to i64
    br label %if_608_merge
if_608_else:
    %v613 = add i64 0, 0
    br label %if_608_merge
if_608_merge:
    %v616 = phi i64 [ %v610, %if_608_then ], [ %v613, %if_608_else ]
    %v617.cb = icmp ne i64 %v616, 0
    br i1 %v617.cb, label %if_617_then, label %if_617_else
if_617_then:
    %v619.n = icmp eq i64 %v147, 0
    %v619 = zext i1 %v619.n to i64
    br label %if_617_merge
if_617_else:
    %v622 = add i64 0, 0
    br label %if_617_merge
if_617_merge:
    %v625 = phi i64 [ %v619, %if_617_then ], [ %v622, %if_617_else ]
    %v626.cb = icmp ne i64 %v625, 0
    br i1 %v626.cb, label %if_626_then, label %if_626_else
if_626_then:
    %v628.n = icmp eq i64 %v157, 0
    %v628 = zext i1 %v628.n to i64
    br label %if_626_merge
if_626_else:
    %v631 = add i64 0, 0
    br label %if_626_merge
if_626_merge:
    %v634 = phi i64 [ %v628, %if_626_then ], [ %v631, %if_626_else ]
    %v635.cb = icmp ne i64 %v634, 0
    br i1 %v635.cb, label %if_635_then, label %if_635_else
if_635_then:
    %v637.n = icmp eq i64 %v167, 0
    %v637 = zext i1 %v637.n to i64
    br label %if_635_merge
if_635_else:
    %v640 = add i64 0, 0
    br label %if_635_merge
if_635_merge:
    %v643 = phi i64 [ %v637, %if_635_then ], [ %v640, %if_635_else ]
    %v644.cb = icmp ne i64 %v643, 0
    br i1 %v644.cb, label %if_644_then, label %if_644_else
if_644_then:
    %v646.n = icmp eq i64 %v203, 0
    %v646 = zext i1 %v646.n to i64
    br label %if_644_merge
if_644_else:
    %v649 = add i64 0, 0
    br label %if_644_merge
if_644_merge:
    %v652 = phi i64 [ %v646, %if_644_then ], [ %v649, %if_644_else ]
    %v653.cb = icmp ne i64 %v652, 0
    br i1 %v653.cb, label %if_653_then, label %if_653_else
if_653_then:
    %v655.n = icmp eq i64 %v597, 0
    %v655 = zext i1 %v655.n to i64
    br label %if_653_merge
if_653_else:
    %v658 = add i64 0, 0
    br label %if_653_merge
if_653_merge:
    %v661 = phi i64 [ %v655, %if_653_then ], [ %v658, %if_653_else ]
    %v662.cb = icmp ne i64 %v661, 0
    br i1 %v662.cb, label %if_662_then, label %if_662_else
if_662_then:
    %v664.n = icmp eq i64 %v607, 0
    %v664 = zext i1 %v664.n to i64
    br label %if_662_merge
if_662_else:
    %v667 = add i64 0, 0
    br label %if_662_merge
if_662_merge:
    %v670 = phi i64 [ %v664, %if_662_then ], [ %v667, %if_662_else ]
    %v671.cb = icmp ne i64 %v670, 0
    br i1 %v671.cb, label %if_671_then, label %if_671_else
if_671_then:
    %v673.n = icmp eq i64 %v226, 0
    %v673 = zext i1 %v673.n to i64
    br label %if_671_merge
if_671_else:
    %v676 = add i64 0, 0
    br label %if_671_merge
if_671_merge:
    %v679 = phi i64 [ %v673, %if_671_then ], [ %v676, %if_671_else ]
    %v680.cb = icmp ne i64 %v679, 0
    br i1 %v680.cb, label %if_680_then, label %if_680_else
if_680_then:
    %v682 = add i64 0, 1
    %v683 = add i64 %v1, %v682
    %v684 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v683)
    %v685 = add i64 0, 1
    %v686 = add i64 %v1, %v685
    %v687 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v686)
    %v688 = call ptr @orion_bytes_from_text(ptr %v3)
    %v689 = add i64 0, 0
    %v690 = alloca i64, align 8
    store i64 %v689, ptr %v690
    %v691 = add i64 0, 0
    %v692 = call i64 @orion_list_len(ptr %v688)
    %v693 = add i64 0, 0
    %v694.b = icmp sgt i64 %v692, %v693
    %v694 = zext i1 %v694.b to i64
    %v695.cb = icmp ne i64 %v694, 0
    br i1 %v695.cb, label %if_695_then, label %if_695_else
if_695_then:
    %v697 = add i64 0, 0
    %v698 = call i64 @orion_list_at(ptr %v688, i64 %v697)
    %v699 = add i64 0, 65
    %v700.b = icmp sge i64 %v698, %v699
    %v700 = zext i1 %v700.b to i64
    %v701.cb = icmp ne i64 %v700, 0
    br i1 %v701.cb, label %if_701_then, label %if_701_else
if_701_then:
    %v703 = add i64 0, 90
    %v704.b = icmp sle i64 %v698, %v703
    %v704 = zext i1 %v704.b to i64
    br label %if_701_merge
if_701_else:
    %v707 = add i64 0, 0
    br label %if_701_merge
if_701_merge:
    %v710 = phi i64 [ %v704, %if_701_then ], [ %v707, %if_701_else ]
    %v711.cb = icmp ne i64 %v710, 0
    br i1 %v711.cb, label %if_711_then, label %if_711_else
if_711_then:
    %v713 = add i64 0, 1
    store i64 %v713, ptr %v690
    %v714 = add i64 0, 0
    br label %if_711_merge
if_711_else:
    br label %if_711_merge
if_711_merge:
    br label %if_695_merge
if_695_else:
    br label %if_695_merge
if_695_merge:
    %v723 = getelementptr i8, ptr @.str_248, i64 16
    %v724.e = call i64 @orion_text_eq(ptr %v684, ptr %v723)
    %v724 = add i64 %v724.e, 0
    %v725.cb = icmp ne i64 %v724, 0
    br i1 %v725.cb, label %if_725_then, label %if_725_else
if_725_then:
    %v727 = getelementptr i8, ptr @.str_240, i64 16
    %v728.e = call i64 @orion_text_eq(ptr %v687, ptr %v727)
    %v728 = add i64 %v728.e, 0
    br label %if_725_merge
if_725_else:
    %v731 = add i64 0, 0
    br label %if_725_merge
if_725_merge:
    %v734 = phi i64 [ %v728, %if_725_then ], [ %v731, %if_725_else ]
    %v735.cb = icmp ne i64 %v734, 0
    br i1 %v735.cb, label %if_735_then, label %if_735_else
if_735_then:
    %v737 = load i64, ptr %v690
    br label %if_735_merge
if_735_else:
    %v740 = add i64 0, 0
    br label %if_735_merge
if_735_merge:
    %v743 = phi i64 [ %v737, %if_735_then ], [ %v740, %if_735_else ]
    %v744.i = call i64 @orion_list_at(ptr %v0, i64 %v1)
    %v744 = inttoptr i64 %v744.i to ptr
    %v745 = getelementptr i8, ptr @.str_120, i64 16
    %v746 = call i64 @orion_map_get(ptr %v744, ptr %v745)
    %v747 = getelementptr i8, ptr @.str_121, i64 16
    %v748 = call i64 @orion_map_get(ptr %v744, ptr %v747)
    %v749.cb = icmp ne i64 %v743, 0
    br i1 %v749.cb, label %if_749_then, label %if_749_else
if_749_then:
    %v751 = add i64 0, 2
    %v752 = add i64 %v1, %v751
    %v753 = call ptr @prog__psr_parse_struct_cons(ptr %v0, i64 %v752, ptr %v3)
    store ptr %v753, ptr %v315
    %v754 = add i64 0, 0
    br label %if_749_merge
if_749_else:
    %v757 = getelementptr i8, ptr @.str_260, i64 16
    %v758 = getelementptr i8, ptr @.str_118, i64 16
    %v759 = getelementptr i8, ptr @.str_256, i64 16
    %v760 = getelementptr i8, ptr @.str_257, i64 16
    %v761 = getelementptr i8, ptr @.str_120, i64 16
    %v762 = getelementptr i8, ptr @.str_121, i64 16
    %v763 = call ptr @orion_map_new(i64 4)
    %v763.p0 = ptrtoint ptr %v759 to i64
    call void @orion_map_set(ptr %v763, ptr %v758, i64 %v763.p0)
    %v763.p1 = ptrtoint ptr %v3 to i64
    call void @orion_map_set(ptr %v763, ptr %v760, i64 %v763.p1)
    call void @orion_map_set(ptr %v763, ptr %v761, i64 %v746)
    call void @orion_map_set(ptr %v763, ptr %v762, i64 %v748)
    %v764 = getelementptr i8, ptr @.str_124, i64 16
    %v765 = add i64 0, 1
    %v766 = add i64 %v1, %v765
    %v767 = call ptr @orion_map_new(i64 2)
    %v767.p0 = ptrtoint ptr %v763 to i64
    call void @orion_map_set(ptr %v767, ptr %v757, i64 %v767.p0)
    call void @orion_map_set(ptr %v767, ptr %v764, i64 %v766)
    store ptr %v767, ptr %v315
    %v768 = add i64 0, 0
    br label %if_749_merge
if_749_merge:
    %v771 = phi i64 [ %v754, %if_749_then ], [ %v768, %if_749_else ]
    br label %if_680_merge
if_680_else:
    br label %if_680_merge
if_680_merge:
    %v776.cb = icmp ne i64 %v597, 0
    br i1 %v776.cb, label %if_776_then, label %if_776_else
if_776_then:
    %v778 = getelementptr i8, ptr @.str_260, i64 16
    %v779 = getelementptr i8, ptr @.str_118, i64 16
    %v780 = getelementptr i8, ptr @.str_250, i64 16
    %v781 = getelementptr i8, ptr @.str_119, i64 16
    %v782 = getelementptr i8, ptr @.str_278, i64 16
    %v783 = call ptr @orion_map_new(i64 2)
    %v783.p0 = ptrtoint ptr %v780 to i64
    call void @orion_map_set(ptr %v783, ptr %v779, i64 %v783.p0)
    %v783.p1 = ptrtoint ptr %v782 to i64
    call void @orion_map_set(ptr %v783, ptr %v781, i64 %v783.p1)
    %v784 = getelementptr i8, ptr @.str_124, i64 16
    %v785 = add i64 0, 1
    %v786 = add i64 %v1, %v785
    %v787 = call ptr @orion_map_new(i64 2)
    %v787.p0 = ptrtoint ptr %v783 to i64
    call void @orion_map_set(ptr %v787, ptr %v778, i64 %v787.p0)
    call void @orion_map_set(ptr %v787, ptr %v784, i64 %v786)
    store ptr %v787, ptr %v315
    %v788 = add i64 0, 0
    br label %if_776_merge
if_776_else:
    br label %if_776_merge
if_776_merge:
    %v793.cb = icmp ne i64 %v607, 0
    br i1 %v793.cb, label %if_793_then, label %if_793_else
if_793_then:
    %v795 = getelementptr i8, ptr @.str_260, i64 16
    %v796 = getelementptr i8, ptr @.str_118, i64 16
    %v797 = getelementptr i8, ptr @.str_250, i64 16
    %v798 = getelementptr i8, ptr @.str_119, i64 16
    %v799 = getelementptr i8, ptr @.str_210, i64 16
    %v800 = call ptr @orion_map_new(i64 2)
    %v800.p0 = ptrtoint ptr %v797 to i64
    call void @orion_map_set(ptr %v800, ptr %v796, i64 %v800.p0)
    %v800.p1 = ptrtoint ptr %v799 to i64
    call void @orion_map_set(ptr %v800, ptr %v798, i64 %v800.p1)
    %v801 = getelementptr i8, ptr @.str_124, i64 16
    %v802 = add i64 0, 1
    %v803 = add i64 %v1, %v802
    %v804 = call ptr @orion_map_new(i64 2)
    %v804.p0 = ptrtoint ptr %v800 to i64
    call void @orion_map_set(ptr %v804, ptr %v795, i64 %v804.p0)
    call void @orion_map_set(ptr %v804, ptr %v801, i64 %v803)
    store ptr %v804, ptr %v315
    %v805 = add i64 0, 0
    br label %if_793_merge
if_793_else:
    br label %if_793_merge
if_793_merge:
    %v810.cb = icmp ne i64 %v97, 0
    br i1 %v810.cb, label %if_810_then, label %if_810_else
if_810_then:
    %v812 = getelementptr i8, ptr @.str_260, i64 16
    %v813 = getelementptr i8, ptr @.str_118, i64 16
    %v814 = getelementptr i8, ptr @.str_250, i64 16
    %v815 = getelementptr i8, ptr @.str_119, i64 16
    %v816 = call ptr @orion_map_new(i64 2)
    %v816.p0 = ptrtoint ptr %v814 to i64
    call void @orion_map_set(ptr %v816, ptr %v813, i64 %v816.p0)
    %v816.p1 = ptrtoint ptr %v3 to i64
    call void @orion_map_set(ptr %v816, ptr %v815, i64 %v816.p1)
    %v817 = getelementptr i8, ptr @.str_124, i64 16
    %v818 = add i64 0, 1
    %v819 = add i64 %v1, %v818
    %v820 = call ptr @orion_map_new(i64 2)
    %v820.p0 = ptrtoint ptr %v816 to i64
    call void @orion_map_set(ptr %v820, ptr %v812, i64 %v820.p0)
    call void @orion_map_set(ptr %v820, ptr %v817, i64 %v819)
    store ptr %v820, ptr %v315
    %v821 = add i64 0, 0
    br label %if_810_merge
if_810_else:
    br label %if_810_merge
if_810_merge:
    %v826.cb = icmp ne i64 %v99, 0
    br i1 %v826.cb, label %if_826_then, label %if_826_else
if_826_then:
    %v828 = getelementptr i8, ptr @.str_260, i64 16
    %v829 = getelementptr i8, ptr @.str_118, i64 16
    %v830 = getelementptr i8, ptr @.str_319, i64 16
    %v831 = getelementptr i8, ptr @.str_119, i64 16
    %v832 = call ptr @orion_map_new(i64 2)
    %v832.p0 = ptrtoint ptr %v830 to i64
    call void @orion_map_set(ptr %v832, ptr %v829, i64 %v832.p0)
    %v832.p1 = ptrtoint ptr %v3 to i64
    call void @orion_map_set(ptr %v832, ptr %v831, i64 %v832.p1)
    %v833 = getelementptr i8, ptr @.str_124, i64 16
    %v834 = add i64 0, 1
    %v835 = add i64 %v1, %v834
    %v836 = call ptr @orion_map_new(i64 2)
    %v836.p0 = ptrtoint ptr %v832 to i64
    call void @orion_map_set(ptr %v836, ptr %v828, i64 %v836.p0)
    call void @orion_map_set(ptr %v836, ptr %v833, i64 %v835)
    store ptr %v836, ptr %v315
    %v837 = add i64 0, 0
    br label %if_826_merge
if_826_else:
    br label %if_826_merge
if_826_merge:
    %v842.cb = icmp ne i64 %v101, 0
    br i1 %v842.cb, label %if_842_then, label %if_842_else
if_842_then:
    %v844 = getelementptr i8, ptr @.str_260, i64 16
    %v845 = call ptr @prog__psr_interpolate_str(ptr %v3)
    %v846 = getelementptr i8, ptr @.str_124, i64 16
    %v847 = add i64 0, 1
    %v848 = add i64 %v1, %v847
    %v849 = call ptr @orion_map_new(i64 2)
    %v849.p0 = ptrtoint ptr %v845 to i64
    call void @orion_map_set(ptr %v849, ptr %v844, i64 %v849.p0)
    call void @orion_map_set(ptr %v849, ptr %v846, i64 %v848)
    store ptr %v849, ptr %v315
    %v850 = add i64 0, 0
    br label %if_842_merge
if_842_else:
    br label %if_842_merge
if_842_merge:
    %v855.cb = icmp ne i64 %v113, 0
    br i1 %v855.cb, label %if_855_then, label %if_855_else
if_855_then:
    %v857 = call ptr @prog__psr_parse_list_literal(ptr %v0, i64 %v1)
    store ptr %v857, ptr %v315
    %v858 = add i64 0, 0
    br label %if_855_merge
if_855_else:
    br label %if_855_merge
if_855_merge:
    %v863.cb = icmp ne i64 %v125, 0
    br i1 %v863.cb, label %if_863_then, label %if_863_else
if_863_then:
    %v865 = call ptr @prog__psr_parse_map_literal(ptr %v0, i64 %v1)
    store ptr %v865, ptr %v315
    %v866 = add i64 0, 0
    br label %if_863_merge
if_863_else:
    br label %if_863_merge
if_863_merge:
    %v871.cb = icmp ne i64 %v15, 0
    br i1 %v871.cb, label %if_871_then, label %if_871_else
if_871_then:
    %v873 = load ptr, ptr %v36
    store ptr %v873, ptr %v315
    %v874 = add i64 0, 0
    br label %if_871_merge
if_871_else:
    br label %if_871_merge
if_871_merge:
    %v879.cb = icmp ne i64 %v27, 0
    br i1 %v879.cb, label %if_879_then, label %if_879_else
if_879_then:
    %v881 = load ptr, ptr %v36
    store ptr %v881, ptr %v315
    %v882 = add i64 0, 0
    br label %if_879_merge
if_879_else:
    br label %if_879_merge
if_879_merge:
    %v887.cb = icmp ne i64 %v137, 0
    br i1 %v887.cb, label %if_887_then, label %if_887_else
if_887_then:
    %v889 = add i64 0, 1
    %v890 = add i64 %v1, %v889
    %v891 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v890)
    %v892 = getelementptr i8, ptr @.str_124, i64 16
    %v893 = call i64 @orion_map_get(ptr %v891, ptr %v892)
    %v894 = alloca i64, align 8
    store i64 %v893, ptr %v894
    %v895 = add i64 0, 0
    %v896 = call ptr @orion_list_new(i64 1)
    %v896.lp0 = ptrtoint ptr %v891 to i64
    call void @orion_list_set(ptr %v896, i64 0, i64 %v896.lp0)
    %v897 = add i64 0, 0
    %v898 = add i64 0, 0
    %v899 = call ptr @orion_list_slice(ptr %v896, i64 %v897, i64 %v898)
    %v900 = getelementptr i8, ptr @.str_260, i64 16
    %v901.i = call i64 @orion_map_get(ptr %v891, ptr %v900)
    %v901.raw = inttoptr i64 %v901.i to ptr
    %v901.isnull = icmp eq i64 %v901.i, 0
    %v901 = select i1 %v901.isnull, ptr @orion_empty_list, ptr %v901.raw
    %v902.p = ptrtoint ptr %v901 to i64
    %v902 = call ptr @orion_list_push(ptr %v899, i64 %v902.p)
    %v903 = alloca ptr, align 8
    store ptr %v902, ptr %v903
    %v904 = add i64 0, 0
    %v905 = add i64 0, 0
    %v906 = alloca i64, align 8
    store i64 %v905, ptr %v906
    %v907 = add i64 0, 0
    br label %loop_908_header
loop_908_header:
    %v910 = load i64, ptr %v894
    %v911 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v910)
    %v912 = getelementptr i8, ptr @.str_248, i64 16
    %v913.e = call i64 @orion_text_eq(ptr %v911, ptr %v912)
    %v913 = add i64 %v913.e, 0
    %v914.cb = icmp ne i64 %v913, 0
    br i1 %v914.cb, label %if_914_then, label %if_914_else
if_914_then:
    %v916 = load i64, ptr %v894
    %v917 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v916)
    %v918 = getelementptr i8, ptr @.str_235, i64 16
    %v919.e = call i64 @orion_text_eq(ptr %v917, ptr %v918)
    %v919 = add i64 %v919.e, 0
    br label %if_914_merge
if_914_else:
    %v922 = add i64 0, 0
    br label %if_914_merge
if_914_merge:
    %v925 = phi i64 [ %v919, %if_914_then ], [ %v922, %if_914_else ]
    %v926.cb = icmp ne i64 %v925, 0
    br i1 %v926.cb, label %if_926_then, label %if_926_else
if_926_then:
    %v928 = add i64 0, 1
    store i64 %v928, ptr %v906
    %v929 = add i64 0, 0
    %v930 = load i64, ptr %v894
    %v931 = add i64 0, 1
    %v932 = add i64 %v930, %v931
    store i64 %v932, ptr %v894
    %v933 = add i64 0, 0
    %v934 = load i64, ptr %v894
    %v935 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v934)
    %v936 = getelementptr i8, ptr @.str_248, i64 16
    %v937.e = call i64 @orion_text_eq(ptr %v935, ptr %v936)
    %v937 = add i64 %v937.e, 0
    %v938.cb = icmp ne i64 %v937, 0
    br i1 %v938.cb, label %if_938_then, label %if_938_else
if_938_then:
    %v940 = load i64, ptr %v894
    %v941 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v940)
    %v942 = getelementptr i8, ptr @.str_234, i64 16
    %v943.e = call i64 @orion_text_eq(ptr %v941, ptr %v942)
    %v943 = add i64 %v943.e, 0
    br label %if_938_merge
if_938_else:
    %v946 = add i64 0, 0
    br label %if_938_merge
if_938_merge:
    %v949 = phi i64 [ %v943, %if_938_then ], [ %v946, %if_938_else ]
    %v950.cb = icmp ne i64 %v949, 0
    br i1 %v950.cb, label %if_950_then, label %if_950_else
if_950_then:
    br label %loop_908_end
if_950_else:
    br label %if_950_merge
if_950_merge:
    %v956 = load i64, ptr %v894
    %v957 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v956)
    %v958 = load ptr, ptr %v903
    %v959 = getelementptr i8, ptr @.str_260, i64 16
    %v960.i = call i64 @orion_map_get(ptr %v957, ptr %v959)
    %v960.raw = inttoptr i64 %v960.i to ptr
    %v960.isnull = icmp eq i64 %v960.i, 0
    %v960 = select i1 %v960.isnull, ptr @orion_empty_list, ptr %v960.raw
    %v961.p = ptrtoint ptr %v960 to i64
    %v961 = call ptr @orion_list_push(ptr %v958, i64 %v961.p)
    store ptr %v961, ptr %v903
    %v962 = add i64 0, 0
    %v963 = getelementptr i8, ptr @.str_124, i64 16
    %v964 = call i64 @orion_map_get(ptr %v957, ptr %v963)
    store i64 %v964, ptr %v894
    %v965 = add i64 0, 0
    br label %if_926_merge
if_926_else:
    br label %loop_908_end
if_926_merge:
    br label %loop_908_header
loop_908_end:
    %v972 = load i64, ptr %v894
    %v973 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v972)
    %v974 = getelementptr i8, ptr @.str_248, i64 16
    %v975.e = call i64 @orion_text_eq(ptr %v973, ptr %v974)
    %v975 = add i64 %v975.e, 0
    %v976.cb = icmp ne i64 %v975, 0
    br i1 %v976.cb, label %if_976_then, label %if_976_else
if_976_then:
    %v978 = load i64, ptr %v894
    %v979 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v978)
    %v980 = getelementptr i8, ptr @.str_234, i64 16
    %v981.e = call i64 @orion_text_eq(ptr %v979, ptr %v980)
    %v981 = add i64 %v981.e, 0
    br label %if_976_merge
if_976_else:
    %v984 = add i64 0, 0
    br label %if_976_merge
if_976_merge:
    %v987 = phi i64 [ %v981, %if_976_then ], [ %v984, %if_976_else ]
    %v988.cb = icmp ne i64 %v987, 0
    br i1 %v988.cb, label %if_988_then, label %if_988_else
if_988_then:
    %v990 = load i64, ptr %v894
    %v991 = add i64 0, 1
    %v992 = add i64 %v990, %v991
    store i64 %v992, ptr %v894
    %v993 = add i64 0, 0
    br label %if_988_merge
if_988_else:
    br label %if_988_merge
if_988_merge:
    %v998 = load i64, ptr %v906
    %v999.cb = icmp ne i64 %v998, 0
    br i1 %v999.cb, label %if_999_then, label %if_999_else
if_999_then:
    %v1001 = getelementptr i8, ptr @.str_260, i64 16
    %v1002 = getelementptr i8, ptr @.str_118, i64 16
    %v1003 = getelementptr i8, ptr @.str_320, i64 16
    %v1004 = getelementptr i8, ptr @.str_302, i64 16
    %v1005 = load ptr, ptr %v903
    %v1006 = call ptr @orion_map_new(i64 2)
    %v1006.p0 = ptrtoint ptr %v1003 to i64
    call void @orion_map_set(ptr %v1006, ptr %v1002, i64 %v1006.p0)
    %v1006.p1 = ptrtoint ptr %v1005 to i64
    call void @orion_map_set(ptr %v1006, ptr %v1004, i64 %v1006.p1)
    %v1007 = getelementptr i8, ptr @.str_124, i64 16
    %v1008 = load i64, ptr %v894
    %v1009 = call ptr @orion_map_new(i64 2)
    %v1009.p0 = ptrtoint ptr %v1006 to i64
    call void @orion_map_set(ptr %v1009, ptr %v1001, i64 %v1009.p0)
    call void @orion_map_set(ptr %v1009, ptr %v1007, i64 %v1008)
    store ptr %v1009, ptr %v315
    %v1010 = add i64 0, 0
    br label %if_999_merge
if_999_else:
    %v1013 = getelementptr i8, ptr @.str_260, i64 16
    %v1014 = getelementptr i8, ptr @.str_260, i64 16
    %v1015.i = call i64 @orion_map_get(ptr %v891, ptr %v1014)
    %v1015.raw = inttoptr i64 %v1015.i to ptr
    %v1015.isnull = icmp eq i64 %v1015.i, 0
    %v1015 = select i1 %v1015.isnull, ptr @orion_empty_list, ptr %v1015.raw
    %v1016 = getelementptr i8, ptr @.str_124, i64 16
    %v1017 = load i64, ptr %v894
    %v1018 = call ptr @orion_map_new(i64 2)
    %v1018.p0 = ptrtoint ptr %v1015 to i64
    call void @orion_map_set(ptr %v1018, ptr %v1013, i64 %v1018.p0)
    call void @orion_map_set(ptr %v1018, ptr %v1016, i64 %v1017)
    store ptr %v1018, ptr %v315
    %v1019 = add i64 0, 0
    br label %if_999_merge
if_999_merge:
    %v1022 = phi i64 [ %v1010, %if_999_then ], [ %v1019, %if_999_else ]
    br label %if_887_merge
if_887_else:
    br label %if_887_merge
if_887_merge:
    %v1027 = load ptr, ptr %v315
    ret ptr %v1027
}

define ptr @prog__psr_parse_struct_cons(ptr %p0, i64 %p1, ptr %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr %p2, i64 0
    %v3 = alloca i64, align 8
    store i64 %v1, ptr %v3
    %v4 = add i64 0, 0
    %v5 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v6 = alloca ptr, align 8
    store ptr %v5, ptr %v6
    %v7 = add i64 0, 0
    %v8 = getelementptr i8, ptr @.str_118, i64 16
    %v9 = getelementptr i8, ptr @.str_250, i64 16
    %v10 = getelementptr i8, ptr @.str_119, i64 16
    %v11 = getelementptr i8, ptr @.str_210, i64 16
    %v12 = call ptr @orion_map_new(i64 2)
    %v12.p0 = ptrtoint ptr %v9 to i64
    call void @orion_map_set(ptr %v12, ptr %v8, i64 %v12.p0)
    %v12.p1 = ptrtoint ptr %v11 to i64
    call void @orion_map_set(ptr %v12, ptr %v10, i64 %v12.p1)
    %v13 = alloca ptr, align 8
    store ptr %v12, ptr %v13
    %v14 = add i64 0, 0
    %v15 = add i64 0, 0
    %v16 = alloca i64, align 8
    store i64 %v15, ptr %v16
    %v17 = add i64 0, 0
    br label %loop_18_header
loop_18_header:
    %v20 = load i64, ptr %v3
    %v21 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v20)
    %v22 = load i64, ptr %v3
    %v23 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v22)
    %v24 = getelementptr i8, ptr @.str_248, i64 16
    %v25.e = call i64 @orion_text_eq(ptr %v21, ptr %v24)
    %v25 = add i64 %v25.e, 0
    %v26.cb = icmp ne i64 %v25, 0
    br i1 %v26.cb, label %if_26_then, label %if_26_else
if_26_then:
    %v28 = getelementptr i8, ptr @.str_241, i64 16
    %v29.e = call i64 @orion_text_eq(ptr %v23, ptr %v28)
    %v29 = add i64 %v29.e, 0
    br label %if_26_merge
if_26_else:
    %v32 = add i64 0, 0
    br label %if_26_merge
if_26_merge:
    %v35 = phi i64 [ %v29, %if_26_then ], [ %v32, %if_26_else ]
    %v36 = getelementptr i8, ptr @.str_249, i64 16
    %v37.e = call i64 @orion_text_eq(ptr %v21, ptr %v36)
    %v37 = add i64 %v37.e, 0
    %v38 = getelementptr i8, ptr @.str_211, i64 16
    %v39.e = call i64 @orion_text_eq(ptr %v21, ptr %v38)
    %v39 = add i64 %v39.e, 0
    %v40 = getelementptr i8, ptr @.str_123, i64 16
    %v41.e = call i64 @orion_text_eq(ptr %v21, ptr %v40)
    %v41 = add i64 %v41.e, 0
    %v42 = getelementptr i8, ptr @.str_248, i64 16
    %v43.e = call i64 @orion_text_eq(ptr %v21, ptr %v42)
    %v43 = add i64 %v43.e, 0
    %v44.cb = icmp ne i64 %v43, 0
    br i1 %v44.cb, label %if_44_then, label %if_44_else
if_44_then:
    %v46 = getelementptr i8, ptr @.str_103, i64 16
    %v47.e = call i64 @orion_text_eq(ptr %v23, ptr %v46)
    %v47 = add i64 %v47.e, 0
    br label %if_44_merge
if_44_else:
    %v50 = add i64 0, 0
    br label %if_44_merge
if_44_merge:
    %v53 = phi i64 [ %v47, %if_44_then ], [ %v50, %if_44_else ]
    %v54.cb = icmp ne i64 %v53, 0
    br i1 %v54.cb, label %if_54_then, label %if_54_else
if_54_then:
    %v56 = load i64, ptr %v3
    %v57 = add i64 0, 1
    %v58 = add i64 %v56, %v57
    %v59 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v58)
    %v60 = getelementptr i8, ptr @.str_248, i64 16
    %v61.e = call i64 @orion_text_eq(ptr %v59, ptr %v60)
    %v61 = add i64 %v61.e, 0
    br label %if_54_merge
if_54_else:
    %v64 = add i64 0, 0
    br label %if_54_merge
if_54_merge:
    %v67 = phi i64 [ %v61, %if_54_then ], [ %v64, %if_54_else ]
    %v68.cb = icmp ne i64 %v67, 0
    br i1 %v68.cb, label %if_68_then, label %if_68_else
if_68_then:
    %v70 = load i64, ptr %v3
    %v71 = add i64 0, 1
    %v72 = add i64 %v70, %v71
    %v73 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v72)
    %v74 = getelementptr i8, ptr @.str_103, i64 16
    %v75.e = call i64 @orion_text_eq(ptr %v73, ptr %v74)
    %v75 = add i64 %v75.e, 0
    br label %if_68_merge
if_68_else:
    %v78 = add i64 0, 0
    br label %if_68_merge
if_68_merge:
    %v81 = phi i64 [ %v75, %if_68_then ], [ %v78, %if_68_else ]
    %v82.cb = icmp ne i64 %v35, 0
    br i1 %v82.cb, label %if_82_then, label %if_82_else
if_82_then:
    %v84 = load i64, ptr %v3
    %v85 = add i64 0, 1
    %v86 = add i64 %v84, %v85
    store i64 %v86, ptr %v3
    %v87 = add i64 0, 0
    br label %loop_18_end
if_82_else:
    br label %if_82_merge
if_82_merge:
    %v92.cb = icmp ne i64 %v37, 0
    br i1 %v92.cb, label %if_92_then, label %if_92_else
if_92_then:
    br label %loop_18_end
if_92_else:
    br label %if_92_merge
if_92_merge:
    %v98.cb = icmp ne i64 %v39, 0
    br i1 %v98.cb, label %if_98_then, label %if_98_else
if_98_then:
    %v100 = load i64, ptr %v3
    %v101 = add i64 0, 1
    %v102 = add i64 %v100, %v101
    store i64 %v102, ptr %v3
    %v103 = add i64 0, 0
    br label %if_98_merge
if_98_else:
    br label %if_98_merge
if_98_merge:
    %v108.cb = icmp ne i64 %v81, 0
    br i1 %v108.cb, label %if_108_then, label %if_108_else
if_108_then:
    %v110 = load i64, ptr %v3
    %v111 = add i64 0, 2
    %v112 = add i64 %v110, %v111
    %v113 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v112)
    %v114 = getelementptr i8, ptr @.str_260, i64 16
    %v115.i = call i64 @orion_map_get(ptr %v113, ptr %v114)
    %v115.raw = inttoptr i64 %v115.i to ptr
    %v115.isnull = icmp eq i64 %v115.i, 0
    %v115 = select i1 %v115.isnull, ptr @orion_empty_list, ptr %v115.raw
    store ptr %v115, ptr %v13
    %v116 = add i64 0, 0
    %v117 = add i64 0, 1
    store i64 %v117, ptr %v16
    %v118 = add i64 0, 0
    %v119 = getelementptr i8, ptr @.str_124, i64 16
    %v120 = call i64 @orion_map_get(ptr %v113, ptr %v119)
    store i64 %v120, ptr %v3
    %v121 = add i64 0, 0
    %v122 = load i64, ptr %v3
    %v123 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v122)
    %v124 = getelementptr i8, ptr @.str_248, i64 16
    %v125.e = call i64 @orion_text_eq(ptr %v123, ptr %v124)
    %v125 = add i64 %v125.e, 0
    %v126.cb = icmp ne i64 %v125, 0
    br i1 %v126.cb, label %if_126_then, label %if_126_else
if_126_then:
    %v128 = load i64, ptr %v3
    %v129 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v128)
    %v130 = getelementptr i8, ptr @.str_235, i64 16
    %v131.e = call i64 @orion_text_eq(ptr %v129, ptr %v130)
    %v131 = add i64 %v131.e, 0
    br label %if_126_merge
if_126_else:
    %v134 = add i64 0, 0
    br label %if_126_merge
if_126_merge:
    %v137 = phi i64 [ %v131, %if_126_then ], [ %v134, %if_126_else ]
    %v138.cb = icmp ne i64 %v137, 0
    br i1 %v138.cb, label %if_138_then, label %if_138_else
if_138_then:
    %v140 = load i64, ptr %v3
    %v141 = add i64 0, 1
    %v142 = add i64 %v140, %v141
    store i64 %v142, ptr %v3
    %v143 = add i64 0, 0
    br label %if_138_merge
if_138_else:
    br label %if_138_merge
if_138_merge:
    br label %if_108_merge
if_108_else:
    br label %if_108_merge
if_108_merge:
    %v152.cb = icmp ne i64 %v41, 0
    br i1 %v152.cb, label %if_152_then, label %if_152_else
if_152_then:
    %v154 = load i64, ptr %v3
    %v155 = add i64 0, 1
    %v156 = add i64 %v154, %v155
    store i64 %v156, ptr %v3
    %v157 = add i64 0, 0
    %v158 = load i64, ptr %v3
    %v159 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v158)
    %v160 = getelementptr i8, ptr @.str_248, i64 16
    %v161.e = call i64 @orion_text_eq(ptr %v159, ptr %v160)
    %v161 = add i64 %v161.e, 0
    %v162.cb = icmp ne i64 %v161, 0
    br i1 %v162.cb, label %if_162_then, label %if_162_else
if_162_then:
    %v164 = load i64, ptr %v3
    %v165 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v164)
    %v166 = getelementptr i8, ptr @.str_236, i64 16
    %v167.e = call i64 @orion_text_eq(ptr %v165, ptr %v166)
    %v167 = add i64 %v167.e, 0
    br label %if_162_merge
if_162_else:
    %v170 = add i64 0, 0
    br label %if_162_merge
if_162_merge:
    %v173 = phi i64 [ %v167, %if_162_then ], [ %v170, %if_162_else ]
    %v174.cb = icmp ne i64 %v173, 0
    br i1 %v174.cb, label %if_174_then, label %if_174_else
if_174_then:
    %v176 = load i64, ptr %v3
    %v177 = add i64 0, 1
    %v178 = add i64 %v176, %v177
    store i64 %v178, ptr %v3
    %v179 = add i64 0, 0
    br label %if_174_merge
if_174_else:
    br label %if_174_merge
if_174_merge:
    %v184 = load i64, ptr %v3
    %v185 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v184)
    %v186 = load ptr, ptr %v6
    %v187 = getelementptr i8, ptr @.str_257, i64 16
    %v188 = getelementptr i8, ptr @.str_119, i64 16
    %v189 = getelementptr i8, ptr @.str_260, i64 16
    %v190.i = call i64 @orion_map_get(ptr %v185, ptr %v189)
    %v190.raw = inttoptr i64 %v190.i to ptr
    %v190.isnull = icmp eq i64 %v190.i, 0
    %v190 = select i1 %v190.isnull, ptr @orion_empty_list, ptr %v190.raw
    %v191 = call ptr @orion_map_new(i64 2)
    %v191.p0 = ptrtoint ptr %v23 to i64
    call void @orion_map_set(ptr %v191, ptr %v187, i64 %v191.p0)
    %v191.p1 = ptrtoint ptr %v190 to i64
    call void @orion_map_set(ptr %v191, ptr %v188, i64 %v191.p1)
    %v192.p = ptrtoint ptr %v191 to i64
    %v192 = call ptr @orion_list_push(ptr %v186, i64 %v192.p)
    store ptr %v192, ptr %v6
    %v193 = add i64 0, 0
    %v194 = getelementptr i8, ptr @.str_124, i64 16
    %v195 = call i64 @orion_map_get(ptr %v185, ptr %v194)
    store i64 %v195, ptr %v3
    %v196 = add i64 0, 0
    %v197 = load i64, ptr %v3
    %v198 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v197)
    %v199 = getelementptr i8, ptr @.str_248, i64 16
    %v200.e = call i64 @orion_text_eq(ptr %v198, ptr %v199)
    %v200 = add i64 %v200.e, 0
    %v201.cb = icmp ne i64 %v200, 0
    br i1 %v201.cb, label %if_201_then, label %if_201_else
if_201_then:
    %v203 = load i64, ptr %v3
    %v204 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v203)
    %v205 = getelementptr i8, ptr @.str_235, i64 16
    %v206.e = call i64 @orion_text_eq(ptr %v204, ptr %v205)
    %v206 = add i64 %v206.e, 0
    br label %if_201_merge
if_201_else:
    %v209 = add i64 0, 0
    br label %if_201_merge
if_201_merge:
    %v212 = phi i64 [ %v206, %if_201_then ], [ %v209, %if_201_else ]
    %v213.cb = icmp ne i64 %v212, 0
    br i1 %v213.cb, label %if_213_then, label %if_213_else
if_213_then:
    %v215 = load i64, ptr %v3
    %v216 = add i64 0, 1
    %v217 = add i64 %v215, %v216
    store i64 %v217, ptr %v3
    %v218 = add i64 0, 0
    br label %if_213_merge
if_213_else:
    br label %if_213_merge
if_213_merge:
    br label %if_152_merge
if_152_else:
    br label %if_152_merge
if_152_merge:
    %v227.cb = icmp ne i64 %v35, 0
    br i1 %v227.cb, label %if_227_then, label %if_227_else
if_227_then:
    br label %if_227_merge
if_227_else:
    br label %if_227_merge
if_227_merge:
    %v233 = phi i64 [ %v35, %if_227_then ], [ %v39, %if_227_else ]
    %v234.cb = icmp ne i64 %v233, 0
    br i1 %v234.cb, label %if_234_then, label %if_234_else
if_234_then:
    br label %if_234_merge
if_234_else:
    br label %if_234_merge
if_234_merge:
    %v240 = phi i64 [ %v233, %if_234_then ], [ %v41, %if_234_else ]
    %v241.cb = icmp ne i64 %v240, 0
    br i1 %v241.cb, label %if_241_then, label %if_241_else
if_241_then:
    br label %if_241_merge
if_241_else:
    br label %if_241_merge
if_241_merge:
    %v247 = phi i64 [ %v240, %if_241_then ], [ %v81, %if_241_else ]
    %v248.n = icmp eq i64 %v247, 0
    %v248 = zext i1 %v248.n to i64
    %v249.cb = icmp ne i64 %v248, 0
    br i1 %v249.cb, label %if_249_then, label %if_249_else
if_249_then:
    %v251 = load i64, ptr %v3
    %v252 = add i64 0, 1
    %v253 = add i64 %v251, %v252
    store i64 %v253, ptr %v3
    %v254 = add i64 0, 0
    br label %if_249_merge
if_249_else:
    br label %if_249_merge
if_249_merge:
    br label %loop_18_header
loop_18_end:
    %v261 = getelementptr i8, ptr @.str_118, i64 16
    %v262 = getelementptr i8, ptr @.str_321, i64 16
    %v263 = getelementptr i8, ptr @.str_257, i64 16
    %v264 = getelementptr i8, ptr @.str_322, i64 16
    %v265 = load ptr, ptr %v6
    %v266 = call ptr @orion_map_new(i64 3)
    %v266.p0 = ptrtoint ptr %v262 to i64
    call void @orion_map_set(ptr %v266, ptr %v261, i64 %v266.p0)
    %v266.p1 = ptrtoint ptr %v2 to i64
    call void @orion_map_set(ptr %v266, ptr %v263, i64 %v266.p1)
    %v266.p2 = ptrtoint ptr %v265 to i64
    call void @orion_map_set(ptr %v266, ptr %v264, i64 %v266.p2)
    %v267 = alloca ptr, align 8
    store ptr %v266, ptr %v267
    %v268 = add i64 0, 0
    %v269 = load i64, ptr %v16
    %v270.cb = icmp ne i64 %v269, 0
    br i1 %v270.cb, label %if_270_then, label %if_270_else
if_270_then:
    %v272 = load ptr, ptr %v267
    %v273 = getelementptr i8, ptr @.str_323, i64 16
    %v274 = load ptr, ptr %v13
    %v275.p = ptrtoint ptr %v274 to i64
    call void @orion_map_set(ptr %v272, ptr %v273, i64 %v275.p)
    %v275 = getelementptr i8, ptr %v272, i64 0
    store ptr %v275, ptr %v267
    %v276 = add i64 0, 0
    br label %if_270_merge
if_270_else:
    br label %if_270_merge
if_270_merge:
    %v281 = getelementptr i8, ptr @.str_260, i64 16
    %v282 = load ptr, ptr %v267
    %v283 = getelementptr i8, ptr @.str_124, i64 16
    %v284 = load i64, ptr %v3
    %v285 = call ptr @orion_map_new(i64 2)
    %v285.p0 = ptrtoint ptr %v282 to i64
    call void @orion_map_set(ptr %v285, ptr %v281, i64 %v285.p0)
    call void @orion_map_set(ptr %v285, ptr %v283, i64 %v284)
    ret ptr %v285
}

define ptr @prog__psr_interpolate_str(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = call ptr @orion_bytes_from_text(ptr %v0)
    %v2 = call i64 @orion_list_len(ptr %v1)
    %v3 = add i64 0, 0
    %v4 = alloca i64, align 8
    store i64 %v3, ptr %v4
    %v5 = add i64 0, 0
    %v6 = add i64 0, 0
    %v7 = alloca i64, align 8
    store i64 %v6, ptr %v7
    %v8 = add i64 0, 0
    br label %for_6_header
for_6_header:
    %v11 = load i64, ptr %v7
    %v12.b = icmp slt i64 %v11, %v2
    %v12 = zext i1 %v12.b to i64
    %v13.cb = icmp ne i64 %v12, 0
    br i1 %v13.cb, label %for_6_body, label %for_6_end
for_6_body:
    %v15 = call i64 @orion_list_at(ptr %v1, i64 %v11)
    %v16 = add i64 0, 0
    %v17.b = icmp sgt i64 %v11, %v16
    %v17 = zext i1 %v17.b to i64
    %v18.cb = icmp ne i64 %v17, 0
    br i1 %v18.cb, label %if_18_then, label %if_18_else
if_18_then:
    %v20 = add i64 0, 1
    %v21 = sub i64 %v11, %v20
    %v22 = call i64 @orion_list_at(ptr %v1, i64 %v21)
    br label %if_18_merge
if_18_else:
    %v25 = add i64 0, 0
    br label %if_18_merge
if_18_merge:
    %v28 = phi i64 [ %v22, %if_18_then ], [ %v25, %if_18_else ]
    %v29 = add i64 0, 123
    %v30.b = icmp eq i64 %v15, %v29
    %v30 = zext i1 %v30.b to i64
    %v31.cb = icmp ne i64 %v30, 0
    br i1 %v31.cb, label %if_31_then, label %if_31_else
if_31_then:
    %v33 = add i64 0, 92
    %v34.b = icmp ne i64 %v28, %v33
    %v34 = zext i1 %v34.b to i64
    br label %if_31_merge
if_31_else:
    %v37 = add i64 0, 0
    br label %if_31_merge
if_31_merge:
    %v40 = phi i64 [ %v34, %if_31_then ], [ %v37, %if_31_else ]
    %v41.cb = icmp ne i64 %v40, 0
    br i1 %v41.cb, label %if_41_then, label %if_41_else
if_41_then:
    %v43 = add i64 0, 1
    store i64 %v43, ptr %v4
    %v44 = add i64 0, 0
    br label %if_41_merge
if_41_else:
    br label %if_41_merge
if_41_merge:
    br label %for_6_step
for_6_step:
    %v51 = add i64 0, 1
    %v52 = add i64 %v11, %v51
    store i64 %v52, ptr %v7
    %v53 = add i64 0, 0
    br label %for_6_header
for_6_end:
    %v56 = alloca ptr, align 8
    store ptr %v0, ptr %v56
    %v57 = add i64 0, 0
    %v58 = load i64, ptr %v4
    %v59 = add i64 0, 0
    %v60.b = icmp eq i64 %v58, %v59
    %v60 = zext i1 %v60.b to i64
    %v61.cb = icmp ne i64 %v60, 0
    br i1 %v61.cb, label %if_61_then, label %if_61_else
if_61_then:
    %v63 = add i64 0, 0
    %v64 = call ptr @orion_bytes_zeros(i64 %v63)
    %v65 = alloca ptr, align 8
    store ptr %v64, ptr %v65
    %v66 = add i64 0, 0
    %v67 = add i64 0, 0
    %v68 = alloca i64, align 8
    store i64 %v67, ptr %v68
    %v69 = add i64 0, 0
    br label %loop_70_header
loop_70_header:
    %v72 = load i64, ptr %v68
    %v73.b = icmp sge i64 %v72, %v2
    %v73 = zext i1 %v73.b to i64
    %v74.cb = icmp ne i64 %v73, 0
    br i1 %v74.cb, label %if_74_then, label %if_74_else
if_74_then:
    br label %loop_70_end
if_74_else:
    br label %if_74_merge
if_74_merge:
    %v80 = load i64, ptr %v68
    %v81 = call i64 @orion_list_at(ptr %v1, i64 %v80)
    %v82 = add i64 0, 92
    %v83.b = icmp eq i64 %v81, %v82
    %v83 = zext i1 %v83.b to i64
    %v84.cb = icmp ne i64 %v83, 0
    br i1 %v84.cb, label %if_84_then, label %if_84_else
if_84_then:
    %v86 = load i64, ptr %v68
    %v87 = add i64 0, 1
    %v88 = add i64 %v86, %v87
    %v89.b = icmp slt i64 %v88, %v2
    %v89 = zext i1 %v89.b to i64
    br label %if_84_merge
if_84_else:
    %v92 = add i64 0, 0
    br label %if_84_merge
if_84_merge:
    %v95 = phi i64 [ %v89, %if_84_then ], [ %v92, %if_84_else ]
    %v96.cb = icmp ne i64 %v95, 0
    br i1 %v96.cb, label %if_96_then, label %if_96_else
if_96_then:
    %v98 = load i64, ptr %v68
    %v99 = add i64 0, 1
    %v100 = add i64 %v98, %v99
    %v101 = call i64 @orion_list_at(ptr %v1, i64 %v100)
    %v102 = add i64 0, 123
    %v103.b = icmp eq i64 %v101, %v102
    %v103 = zext i1 %v103.b to i64
    %v104.cb = icmp ne i64 %v103, 0
    br i1 %v104.cb, label %if_104_then, label %if_104_else
if_104_then:
    br label %if_104_merge
if_104_else:
    %v108 = add i64 0, 125
    %v109.b = icmp eq i64 %v101, %v108
    %v109 = zext i1 %v109.b to i64
    br label %if_104_merge
if_104_merge:
    %v112 = phi i64 [ %v103, %if_104_then ], [ %v109, %if_104_else ]
    %v113.cb = icmp ne i64 %v112, 0
    br i1 %v113.cb, label %if_113_then, label %if_113_else
if_113_then:
    %v115 = load ptr, ptr %v65
    %v116 = load i64, ptr %v68
    %v117 = add i64 0, 1
    %v118 = add i64 %v116, %v117
    %v119 = load i64, ptr %v68
    %v120 = add i64 0, 2
    %v121 = add i64 %v119, %v120
    %v122 = call ptr @orion_bytes_slice(ptr %v1, i64 %v118, i64 %v121)
    %v123 = call ptr @orion_bytes_concat(ptr %v115, ptr %v122)
    store ptr %v123, ptr %v65
    %v124 = add i64 0, 0
    %v125 = load i64, ptr %v68
    %v126 = add i64 0, 2
    %v127 = add i64 %v125, %v126
    store i64 %v127, ptr %v68
    %v128 = add i64 0, 0
    br label %if_113_merge
if_113_else:
    %v131 = load ptr, ptr %v65
    %v132 = load i64, ptr %v68
    %v133 = load i64, ptr %v68
    %v134 = add i64 0, 1
    %v135 = add i64 %v133, %v134
    %v136 = call ptr @orion_bytes_slice(ptr %v1, i64 %v132, i64 %v135)
    %v137 = call ptr @orion_bytes_concat(ptr %v131, ptr %v136)
    store ptr %v137, ptr %v65
    %v138 = add i64 0, 0
    %v139 = load i64, ptr %v68
    %v140 = add i64 0, 1
    %v141 = add i64 %v139, %v140
    store i64 %v141, ptr %v68
    %v142 = add i64 0, 0
    br label %if_113_merge
if_113_merge:
    %v145 = phi i64 [ %v128, %if_113_then ], [ %v142, %if_113_else ]
    br label %if_96_merge
if_96_else:
    %v148 = load ptr, ptr %v65
    %v149 = load i64, ptr %v68
    %v150 = load i64, ptr %v68
    %v151 = add i64 0, 1
    %v152 = add i64 %v150, %v151
    %v153 = call ptr @orion_bytes_slice(ptr %v1, i64 %v149, i64 %v152)
    %v154 = call ptr @orion_bytes_concat(ptr %v148, ptr %v153)
    store ptr %v154, ptr %v65
    %v155 = add i64 0, 0
    %v156 = load i64, ptr %v68
    %v157 = add i64 0, 1
    %v158 = add i64 %v156, %v157
    store i64 %v158, ptr %v68
    %v159 = add i64 0, 0
    br label %if_96_merge
if_96_merge:
    %v162 = phi i64 [ %v145, %if_113_merge ], [ %v159, %if_96_else ]
    br label %loop_70_header
loop_70_end:
    %v165 = load ptr, ptr %v65
    %v166 = call ptr @orion_bytes_to_text(ptr %v165)
    store ptr %v166, ptr %v56
    %v167 = add i64 0, 0
    br label %if_61_merge
if_61_else:
    br label %if_61_merge
if_61_merge:
    %v172 = getelementptr i8, ptr @.str_118, i64 16
    %v173 = getelementptr i8, ptr @.str_324, i64 16
    %v174 = getelementptr i8, ptr @.str_119, i64 16
    %v175 = load ptr, ptr %v56
    %v176 = call ptr @orion_map_new(i64 2)
    %v176.p0 = ptrtoint ptr %v173 to i64
    call void @orion_map_set(ptr %v176, ptr %v172, i64 %v176.p0)
    %v176.p1 = ptrtoint ptr %v175 to i64
    call void @orion_map_set(ptr %v176, ptr %v174, i64 %v176.p1)
    %v177 = alloca ptr, align 8
    store ptr %v176, ptr %v177
    %v178 = add i64 0, 0
    %v179 = load i64, ptr %v4
    %v180 = add i64 0, 1
    %v181.b = icmp eq i64 %v179, %v180
    %v181 = zext i1 %v181.b to i64
    %v182.cb = icmp ne i64 %v181, 0
    br i1 %v182.cb, label %if_182_then, label %if_182_else
if_182_then:
    %v184 = getelementptr i8, ptr @.str_118, i64 16
    %v185 = getelementptr i8, ptr @.str_324, i64 16
    %v186 = getelementptr i8, ptr @.str_119, i64 16
    %v187 = getelementptr i8, ptr @.str_5, i64 16
    %v188 = call ptr @orion_map_new(i64 2)
    %v188.p0 = ptrtoint ptr %v185 to i64
    call void @orion_map_set(ptr %v188, ptr %v184, i64 %v188.p0)
    %v188.p1 = ptrtoint ptr %v187 to i64
    call void @orion_map_set(ptr %v188, ptr %v186, i64 %v188.p1)
    %v189 = alloca ptr, align 8
    store ptr %v188, ptr %v189
    %v190 = add i64 0, 0
    %v191 = add i64 0, 0
    %v192 = alloca i64, align 8
    store i64 %v191, ptr %v192
    %v193 = add i64 0, 0
    %v194 = add i64 0, 0
    %v195 = call ptr @orion_bytes_zeros(i64 %v194)
    %v196 = alloca ptr, align 8
    store ptr %v195, ptr %v196
    %v197 = add i64 0, 0
    %v198 = add i64 0, 0
    %v199 = alloca i64, align 8
    store i64 %v198, ptr %v199
    %v200 = add i64 0, 0
    br label %loop_201_header
loop_201_header:
    %v203 = load i64, ptr %v199
    %v204.b = icmp sge i64 %v203, %v2
    %v204 = zext i1 %v204.b to i64
    %v205.cb = icmp ne i64 %v204, 0
    br i1 %v205.cb, label %if_205_then, label %if_205_else
if_205_then:
    br label %loop_201_end
if_205_else:
    br label %if_205_merge
if_205_merge:
    %v211 = load i64, ptr %v199
    %v212 = call i64 @orion_list_at(ptr %v1, i64 %v211)
    %v213 = add i64 0, 92
    %v214.b = icmp eq i64 %v212, %v213
    %v214 = zext i1 %v214.b to i64
    %v215.cb = icmp ne i64 %v214, 0
    br i1 %v215.cb, label %if_215_then, label %if_215_else
if_215_then:
    %v217 = load i64, ptr %v199
    %v218 = add i64 0, 1
    %v219 = add i64 %v217, %v218
    %v220.b = icmp slt i64 %v219, %v2
    %v220 = zext i1 %v220.b to i64
    br label %if_215_merge
if_215_else:
    %v223 = add i64 0, 0
    br label %if_215_merge
if_215_merge:
    %v226 = phi i64 [ %v220, %if_215_then ], [ %v223, %if_215_else ]
    %v227.cb = icmp ne i64 %v226, 0
    br i1 %v227.cb, label %if_227_then, label %if_227_else
if_227_then:
    %v229 = load i64, ptr %v199
    %v230 = add i64 0, 1
    %v231 = add i64 %v229, %v230
    %v232 = call i64 @orion_list_at(ptr %v1, i64 %v231)
    br label %if_227_merge
if_227_else:
    %v235 = add i64 0, 0
    br label %if_227_merge
if_227_merge:
    %v238 = phi i64 [ %v232, %if_227_then ], [ %v235, %if_227_else ]
    %v239 = add i64 0, 92
    %v240.b = icmp eq i64 %v212, %v239
    %v240 = zext i1 %v240.b to i64
    %v241.cb = icmp ne i64 %v240, 0
    br i1 %v241.cb, label %if_241_then, label %if_241_else
if_241_then:
    %v243 = add i64 0, 123
    %v244.b = icmp eq i64 %v238, %v243
    %v244 = zext i1 %v244.b to i64
    %v245.cb = icmp ne i64 %v244, 0
    br i1 %v245.cb, label %if_245_then, label %if_245_else
if_245_then:
    br label %if_245_merge
if_245_else:
    %v249 = add i64 0, 125
    %v250.b = icmp eq i64 %v238, %v249
    %v250 = zext i1 %v250.b to i64
    br label %if_245_merge
if_245_merge:
    %v253 = phi i64 [ %v244, %if_245_then ], [ %v250, %if_245_else ]
    br label %if_241_merge
if_241_else:
    %v256 = add i64 0, 0
    br label %if_241_merge
if_241_merge:
    %v259 = phi i64 [ %v253, %if_245_merge ], [ %v256, %if_241_else ]
    %v260.cb = icmp ne i64 %v259, 0
    br i1 %v260.cb, label %if_260_then, label %if_260_else
if_260_then:
    %v262 = load ptr, ptr %v196
    %v263 = load i64, ptr %v199
    %v264 = add i64 0, 1
    %v265 = add i64 %v263, %v264
    %v266 = load i64, ptr %v199
    %v267 = add i64 0, 2
    %v268 = add i64 %v266, %v267
    %v269 = call ptr @orion_bytes_slice(ptr %v1, i64 %v265, i64 %v268)
    %v270 = call ptr @orion_bytes_concat(ptr %v262, ptr %v269)
    store ptr %v270, ptr %v196
    %v271 = add i64 0, 0
    %v272 = load i64, ptr %v199
    %v273 = add i64 0, 2
    %v274 = add i64 %v272, %v273
    store i64 %v274, ptr %v199
    %v275 = add i64 0, 0
    br label %if_260_merge
if_260_else:
    br label %if_260_merge
if_260_merge:
    %v280 = add i64 0, 123
    %v281.b = icmp eq i64 %v212, %v280
    %v281 = zext i1 %v281.b to i64
    %v282.cb = icmp ne i64 %v281, 0
    br i1 %v282.cb, label %if_282_then, label %if_282_else
if_282_then:
    %v284.n = icmp eq i64 %v259, 0
    %v284 = zext i1 %v284.n to i64
    br label %if_282_merge
if_282_else:
    %v287 = add i64 0, 0
    br label %if_282_merge
if_282_merge:
    %v290 = phi i64 [ %v284, %if_282_then ], [ %v287, %if_282_else ]
    %v291.n = icmp eq i64 %v290, 0
    %v291 = zext i1 %v291.n to i64
    %v292.cb = icmp ne i64 %v291, 0
    br i1 %v292.cb, label %if_292_then, label %if_292_else
if_292_then:
    %v294.n = icmp eq i64 %v259, 0
    %v294 = zext i1 %v294.n to i64
    br label %if_292_merge
if_292_else:
    %v297 = add i64 0, 0
    br label %if_292_merge
if_292_merge:
    %v300 = phi i64 [ %v294, %if_292_then ], [ %v297, %if_292_else ]
    %v301.cb = icmp ne i64 %v300, 0
    br i1 %v301.cb, label %if_301_then, label %if_301_else
if_301_then:
    %v303 = load ptr, ptr %v196
    %v304 = load i64, ptr %v199
    %v305 = load i64, ptr %v199
    %v306 = add i64 0, 1
    %v307 = add i64 %v305, %v306
    %v308 = call ptr @orion_bytes_slice(ptr %v1, i64 %v304, i64 %v307)
    %v309 = call ptr @orion_bytes_concat(ptr %v303, ptr %v308)
    store ptr %v309, ptr %v196
    %v310 = add i64 0, 0
    %v311 = load i64, ptr %v199
    %v312 = add i64 0, 1
    %v313 = add i64 %v311, %v312
    store i64 %v313, ptr %v199
    %v314 = add i64 0, 0
    br label %if_301_merge
if_301_else:
    br label %if_301_merge
if_301_merge:
    %v319.cb = icmp ne i64 %v290, 0
    br i1 %v319.cb, label %if_319_then, label %if_319_else
if_319_then:
    %v321 = load ptr, ptr %v196
    %v322 = call i64 @orion_list_len(ptr %v321)
    %v323 = add i64 0, 0
    %v324.b = icmp sgt i64 %v322, %v323
    %v324 = zext i1 %v324.b to i64
    %v325.cb = icmp ne i64 %v324, 0
    br i1 %v325.cb, label %if_325_then, label %if_325_else
if_325_then:
    %v327 = getelementptr i8, ptr @.str_118, i64 16
    %v328 = getelementptr i8, ptr @.str_324, i64 16
    %v329 = getelementptr i8, ptr @.str_119, i64 16
    %v330 = load ptr, ptr %v196
    %v331 = call ptr @orion_bytes_to_text(ptr %v330)
    %v332 = call ptr @orion_map_new(i64 2)
    %v332.p0 = ptrtoint ptr %v328 to i64
    call void @orion_map_set(ptr %v332, ptr %v327, i64 %v332.p0)
    %v332.p1 = ptrtoint ptr %v331 to i64
    call void @orion_map_set(ptr %v332, ptr %v329, i64 %v332.p1)
    %v333 = load i64, ptr %v192
    %v334 = add i64 0, 0
    %v335.b = icmp eq i64 %v333, %v334
    %v335 = zext i1 %v335.b to i64
    %v336.cb = icmp ne i64 %v335, 0
    br i1 %v336.cb, label %if_336_then, label %if_336_else
if_336_then:
    store ptr %v332, ptr %v189
    %v338 = add i64 0, 0
    %v339 = add i64 0, 1
    store i64 %v339, ptr %v192
    %v340 = add i64 0, 0
    br label %if_336_merge
if_336_else:
    br label %if_336_merge
if_336_merge:
    %v345 = add i64 0, 1
    %v346.b = icmp eq i64 %v333, %v345
    %v346 = zext i1 %v346.b to i64
    %v347.cb = icmp ne i64 %v346, 0
    br i1 %v347.cb, label %if_347_then, label %if_347_else
if_347_then:
    %v349 = getelementptr i8, ptr @.str_118, i64 16
    %v350 = getelementptr i8, ptr @.str_325, i64 16
    %v351 = getelementptr i8, ptr @.str_312, i64 16
    %v352 = getelementptr i8, ptr @.str_225, i64 16
    %v353 = getelementptr i8, ptr @.str_326, i64 16
    %v354 = load ptr, ptr %v189
    %v355 = getelementptr i8, ptr @.str_327, i64 16
    %v356 = call ptr @orion_map_new(i64 4)
    %v356.p0 = ptrtoint ptr %v350 to i64
    call void @orion_map_set(ptr %v356, ptr %v349, i64 %v356.p0)
    %v356.p1 = ptrtoint ptr %v352 to i64
    call void @orion_map_set(ptr %v356, ptr %v351, i64 %v356.p1)
    %v356.p2 = ptrtoint ptr %v354 to i64
    call void @orion_map_set(ptr %v356, ptr %v353, i64 %v356.p2)
    %v356.p3 = ptrtoint ptr %v332 to i64
    call void @orion_map_set(ptr %v356, ptr %v355, i64 %v356.p3)
    store ptr %v356, ptr %v189
    %v357 = add i64 0, 0
    br label %if_347_merge
if_347_else:
    br label %if_347_merge
if_347_merge:
    br label %if_325_merge
if_325_else:
    br label %if_325_merge
if_325_merge:
    %v366 = add i64 0, 0
    %v367 = call ptr @orion_bytes_zeros(i64 %v366)
    store ptr %v367, ptr %v196
    %v368 = add i64 0, 0
    %v369 = load i64, ptr %v199
    %v370 = add i64 0, 1
    %v371 = add i64 %v369, %v370
    store i64 %v371, ptr %v199
    %v372 = add i64 0, 0
    %v373 = load i64, ptr %v199
    br label %loop_374_header
loop_374_header:
    %v376 = load i64, ptr %v199
    %v377.b = icmp sge i64 %v376, %v2
    %v377 = zext i1 %v377.b to i64
    %v378.cb = icmp ne i64 %v377, 0
    br i1 %v378.cb, label %if_378_then, label %if_378_else
if_378_then:
    br label %loop_374_end
if_378_else:
    br label %if_378_merge
if_378_merge:
    %v384 = load i64, ptr %v199
    %v385 = call i64 @orion_list_at(ptr %v1, i64 %v384)
    %v386 = add i64 0, 125
    %v387.b = icmp eq i64 %v385, %v386
    %v387 = zext i1 %v387.b to i64
    %v388.cb = icmp ne i64 %v387, 0
    br i1 %v388.cb, label %if_388_then, label %if_388_else
if_388_then:
    br label %loop_374_end
if_388_else:
    br label %if_388_merge
if_388_merge:
    %v394 = load i64, ptr %v199
    %v395 = add i64 0, 1
    %v396 = add i64 %v394, %v395
    store i64 %v396, ptr %v199
    %v397 = add i64 0, 0
    br label %loop_374_header
loop_374_end:
    %v400 = load i64, ptr %v199
    %v401 = call ptr @orion_bytes_slice(ptr %v1, i64 %v373, i64 %v400)
    %v402 = call ptr @orion_bytes_to_text(ptr %v401)
    %v403 = getelementptr i8, ptr @.str_118, i64 16
    %v404 = getelementptr i8, ptr @.str_256, i64 16
    %v405 = getelementptr i8, ptr @.str_257, i64 16
    %v406 = call ptr @orion_map_new(i64 2)
    %v406.p0 = ptrtoint ptr %v404 to i64
    call void @orion_map_set(ptr %v406, ptr %v403, i64 %v406.p0)
    %v406.p1 = ptrtoint ptr %v402 to i64
    call void @orion_map_set(ptr %v406, ptr %v405, i64 %v406.p1)
    %v407 = alloca ptr, align 8
    store ptr %v406, ptr %v407
    %v408 = add i64 0, 0
    %v409 = call ptr @orion_bytes_from_text(ptr %v402)
    %v410 = call i64 @orion_list_len(ptr %v409)
    %v411 = add i64 0, 0
    %v412.b = icmp sgt i64 %v410, %v411
    %v412 = zext i1 %v412.b to i64
    %v413.cb = icmp ne i64 %v412, 0
    br i1 %v413.cb, label %if_413_then, label %if_413_else
if_413_then:
    %v415 = call ptr @prog__self_lex(ptr %v402)
    %v416 = add i64 0, 0
    %v417 = call ptr @prog__psr_parse_expr(ptr %v415, i64 %v416)
    %v418 = getelementptr i8, ptr @.str_260, i64 16
    %v419.i = call i64 @orion_map_get(ptr %v417, ptr %v418)
    %v419.raw = inttoptr i64 %v419.i to ptr
    %v419.isnull = icmp eq i64 %v419.i, 0
    %v419 = select i1 %v419.isnull, ptr @orion_empty_list, ptr %v419.raw
    store ptr %v419, ptr %v407
    %v420 = add i64 0, 0
    br label %if_413_merge
if_413_else:
    br label %if_413_merge
if_413_merge:
    %v425 = getelementptr i8, ptr @.str_118, i64 16
    %v426 = getelementptr i8, ptr @.str_251, i64 16
    %v427 = getelementptr i8, ptr @.str_252, i64 16
    %v428 = getelementptr i8, ptr @.str_328, i64 16
    %v429 = getelementptr i8, ptr @.str_253, i64 16
    %v430 = load ptr, ptr %v407
    %v431 = call ptr @orion_list_new(i64 1)
    %v431.lp0 = ptrtoint ptr %v430 to i64
    call void @orion_list_set(ptr %v431, i64 0, i64 %v431.lp0)
    %v432 = call ptr @orion_map_new(i64 3)
    %v432.p0 = ptrtoint ptr %v426 to i64
    call void @orion_map_set(ptr %v432, ptr %v425, i64 %v432.p0)
    %v432.p1 = ptrtoint ptr %v428 to i64
    call void @orion_map_set(ptr %v432, ptr %v427, i64 %v432.p1)
    %v432.p2 = ptrtoint ptr %v431 to i64
    call void @orion_map_set(ptr %v432, ptr %v429, i64 %v432.p2)
    %v433 = load i64, ptr %v192
    %v434 = add i64 0, 0
    %v435.b = icmp eq i64 %v433, %v434
    %v435 = zext i1 %v435.b to i64
    %v436.cb = icmp ne i64 %v435, 0
    br i1 %v436.cb, label %if_436_then, label %if_436_else
if_436_then:
    store ptr %v432, ptr %v189
    %v438 = add i64 0, 0
    %v439 = add i64 0, 1
    store i64 %v439, ptr %v192
    %v440 = add i64 0, 0
    br label %if_436_merge
if_436_else:
    br label %if_436_merge
if_436_merge:
    %v445 = add i64 0, 1
    %v446.b = icmp eq i64 %v433, %v445
    %v446 = zext i1 %v446.b to i64
    %v447.cb = icmp ne i64 %v446, 0
    br i1 %v447.cb, label %if_447_then, label %if_447_else
if_447_then:
    %v449 = getelementptr i8, ptr @.str_118, i64 16
    %v450 = getelementptr i8, ptr @.str_325, i64 16
    %v451 = getelementptr i8, ptr @.str_312, i64 16
    %v452 = getelementptr i8, ptr @.str_225, i64 16
    %v453 = getelementptr i8, ptr @.str_326, i64 16
    %v454 = load ptr, ptr %v189
    %v455 = getelementptr i8, ptr @.str_327, i64 16
    %v456 = call ptr @orion_map_new(i64 4)
    %v456.p0 = ptrtoint ptr %v450 to i64
    call void @orion_map_set(ptr %v456, ptr %v449, i64 %v456.p0)
    %v456.p1 = ptrtoint ptr %v452 to i64
    call void @orion_map_set(ptr %v456, ptr %v451, i64 %v456.p1)
    %v456.p2 = ptrtoint ptr %v454 to i64
    call void @orion_map_set(ptr %v456, ptr %v453, i64 %v456.p2)
    %v456.p3 = ptrtoint ptr %v432 to i64
    call void @orion_map_set(ptr %v456, ptr %v455, i64 %v456.p3)
    store ptr %v456, ptr %v189
    %v457 = add i64 0, 0
    br label %if_447_merge
if_447_else:
    br label %if_447_merge
if_447_merge:
    %v462 = load i64, ptr %v199
    %v463.b = icmp slt i64 %v462, %v2
    %v463 = zext i1 %v463.b to i64
    %v464.cb = icmp ne i64 %v463, 0
    br i1 %v464.cb, label %if_464_then, label %if_464_else
if_464_then:
    %v466 = load i64, ptr %v199
    %v467 = add i64 0, 1
    %v468 = add i64 %v466, %v467
    store i64 %v468, ptr %v199
    %v469 = add i64 0, 0
    br label %if_464_merge
if_464_else:
    br label %if_464_merge
if_464_merge:
    br label %if_319_merge
if_319_else:
    br label %if_319_merge
if_319_merge:
    br label %loop_201_header
loop_201_end:
    %v480 = load ptr, ptr %v196
    %v481 = call i64 @orion_list_len(ptr %v480)
    %v482 = add i64 0, 0
    %v483.b = icmp sgt i64 %v481, %v482
    %v483 = zext i1 %v483.b to i64
    %v484.cb = icmp ne i64 %v483, 0
    br i1 %v484.cb, label %if_484_then, label %if_484_else
if_484_then:
    %v486 = getelementptr i8, ptr @.str_118, i64 16
    %v487 = getelementptr i8, ptr @.str_324, i64 16
    %v488 = getelementptr i8, ptr @.str_119, i64 16
    %v489 = load ptr, ptr %v196
    %v490 = call ptr @orion_bytes_to_text(ptr %v489)
    %v491 = call ptr @orion_map_new(i64 2)
    %v491.p0 = ptrtoint ptr %v487 to i64
    call void @orion_map_set(ptr %v491, ptr %v486, i64 %v491.p0)
    %v491.p1 = ptrtoint ptr %v490 to i64
    call void @orion_map_set(ptr %v491, ptr %v488, i64 %v491.p1)
    %v492 = load i64, ptr %v192
    %v493 = add i64 0, 0
    %v494.b = icmp eq i64 %v492, %v493
    %v494 = zext i1 %v494.b to i64
    %v495.cb = icmp ne i64 %v494, 0
    br i1 %v495.cb, label %if_495_then, label %if_495_else
if_495_then:
    store ptr %v491, ptr %v189
    %v497 = add i64 0, 0
    br label %if_495_merge
if_495_else:
    br label %if_495_merge
if_495_merge:
    %v502 = add i64 0, 1
    %v503.b = icmp eq i64 %v492, %v502
    %v503 = zext i1 %v503.b to i64
    %v504.cb = icmp ne i64 %v503, 0
    br i1 %v504.cb, label %if_504_then, label %if_504_else
if_504_then:
    %v506 = getelementptr i8, ptr @.str_118, i64 16
    %v507 = getelementptr i8, ptr @.str_325, i64 16
    %v508 = getelementptr i8, ptr @.str_312, i64 16
    %v509 = getelementptr i8, ptr @.str_225, i64 16
    %v510 = getelementptr i8, ptr @.str_326, i64 16
    %v511 = load ptr, ptr %v189
    %v512 = getelementptr i8, ptr @.str_327, i64 16
    %v513 = call ptr @orion_map_new(i64 4)
    %v513.p0 = ptrtoint ptr %v507 to i64
    call void @orion_map_set(ptr %v513, ptr %v506, i64 %v513.p0)
    %v513.p1 = ptrtoint ptr %v509 to i64
    call void @orion_map_set(ptr %v513, ptr %v508, i64 %v513.p1)
    %v513.p2 = ptrtoint ptr %v511 to i64
    call void @orion_map_set(ptr %v513, ptr %v510, i64 %v513.p2)
    %v513.p3 = ptrtoint ptr %v491 to i64
    call void @orion_map_set(ptr %v513, ptr %v512, i64 %v513.p3)
    store ptr %v513, ptr %v189
    %v514 = add i64 0, 0
    br label %if_504_merge
if_504_else:
    br label %if_504_merge
if_504_merge:
    br label %if_484_merge
if_484_else:
    br label %if_484_merge
if_484_merge:
    %v523 = load ptr, ptr %v189
    store ptr %v523, ptr %v177
    %v524 = add i64 0, 0
    br label %if_182_merge
if_182_else:
    br label %if_182_merge
if_182_merge:
    %v529 = load ptr, ptr %v177
    ret ptr %v529
}

define ptr @prog__psr_parse_map_literal(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, 1
    %v3 = add i64 %v1, %v2
    %v4 = alloca i64, align 8
    store i64 %v3, ptr %v4
    %v5 = add i64 0, 0
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = alloca ptr, align 8
    store ptr %v6, ptr %v7
    %v8 = add i64 0, 0
    br label %loop_9_header
loop_9_header:
    %v11 = load i64, ptr %v4
    %v12 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v11)
    %v13 = load i64, ptr %v4
    %v14 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v13)
    %v15 = getelementptr i8, ptr @.str_248, i64 16
    %v16.e = call i64 @orion_text_eq(ptr %v12, ptr %v15)
    %v16 = add i64 %v16.e, 0
    %v17.cb = icmp ne i64 %v16, 0
    br i1 %v17.cb, label %if_17_then, label %if_17_else
if_17_then:
    %v19 = getelementptr i8, ptr @.str_241, i64 16
    %v20.e = call i64 @orion_text_eq(ptr %v14, ptr %v19)
    %v20 = add i64 %v20.e, 0
    br label %if_17_merge
if_17_else:
    %v23 = add i64 0, 0
    br label %if_17_merge
if_17_merge:
    %v26 = phi i64 [ %v20, %if_17_then ], [ %v23, %if_17_else ]
    %v27 = getelementptr i8, ptr @.str_249, i64 16
    %v28.e = call i64 @orion_text_eq(ptr %v12, ptr %v27)
    %v28 = add i64 %v28.e, 0
    %v29.cb = icmp ne i64 %v26, 0
    br i1 %v29.cb, label %if_29_then, label %if_29_else
if_29_then:
    %v31 = load i64, ptr %v4
    %v32 = add i64 0, 1
    %v33 = add i64 %v31, %v32
    store i64 %v33, ptr %v4
    %v34 = add i64 0, 0
    br label %loop_9_end
if_29_else:
    br label %if_29_merge
if_29_merge:
    %v39.cb = icmp ne i64 %v28, 0
    br i1 %v39.cb, label %if_39_then, label %if_39_else
if_39_then:
    br label %loop_9_end
if_39_else:
    br label %if_39_merge
if_39_merge:
    %v45 = getelementptr i8, ptr @.str_212, i64 16
    %v46.e = call i64 @orion_text_eq(ptr %v12, ptr %v45)
    %v46 = add i64 %v46.e, 0
    %v47.cb = icmp ne i64 %v46, 0
    br i1 %v47.cb, label %if_47_then, label %if_47_else
if_47_then:
    %v49 = load i64, ptr %v4
    %v50 = add i64 0, 1
    %v51 = add i64 %v49, %v50
    store i64 %v51, ptr %v4
    %v52 = add i64 0, 0
    %v53 = load i64, ptr %v4
    %v54 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v53)
    %v55 = getelementptr i8, ptr @.str_248, i64 16
    %v56.e = call i64 @orion_text_eq(ptr %v54, ptr %v55)
    %v56 = add i64 %v56.e, 0
    %v57.cb = icmp ne i64 %v56, 0
    br i1 %v57.cb, label %if_57_then, label %if_57_else
if_57_then:
    %v59 = load i64, ptr %v4
    %v60 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v59)
    %v61 = getelementptr i8, ptr @.str_236, i64 16
    %v62.e = call i64 @orion_text_eq(ptr %v60, ptr %v61)
    %v62 = add i64 %v62.e, 0
    br label %if_57_merge
if_57_else:
    %v65 = add i64 0, 0
    br label %if_57_merge
if_57_merge:
    %v68 = phi i64 [ %v62, %if_57_then ], [ %v65, %if_57_else ]
    %v69.cb = icmp ne i64 %v68, 0
    br i1 %v69.cb, label %if_69_then, label %if_69_else
if_69_then:
    %v71 = load i64, ptr %v4
    %v72 = add i64 0, 1
    %v73 = add i64 %v71, %v72
    store i64 %v73, ptr %v4
    %v74 = add i64 0, 0
    br label %if_69_merge
if_69_else:
    br label %if_69_merge
if_69_merge:
    %v79 = load i64, ptr %v4
    %v80 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v79)
    %v81 = load ptr, ptr %v7
    %v82 = getelementptr i8, ptr @.str_329, i64 16
    %v83 = getelementptr i8, ptr @.str_119, i64 16
    %v84 = getelementptr i8, ptr @.str_260, i64 16
    %v85.i = call i64 @orion_map_get(ptr %v80, ptr %v84)
    %v85.raw = inttoptr i64 %v85.i to ptr
    %v85.isnull = icmp eq i64 %v85.i, 0
    %v85 = select i1 %v85.isnull, ptr @orion_empty_list, ptr %v85.raw
    %v86 = call ptr @orion_map_new(i64 2)
    %v86.p0 = ptrtoint ptr %v14 to i64
    call void @orion_map_set(ptr %v86, ptr %v82, i64 %v86.p0)
    %v86.p1 = ptrtoint ptr %v85 to i64
    call void @orion_map_set(ptr %v86, ptr %v83, i64 %v86.p1)
    %v87.p = ptrtoint ptr %v86 to i64
    %v87 = call ptr @orion_list_push(ptr %v81, i64 %v87.p)
    store ptr %v87, ptr %v7
    %v88 = add i64 0, 0
    %v89 = getelementptr i8, ptr @.str_124, i64 16
    %v90 = call i64 @orion_map_get(ptr %v80, ptr %v89)
    store i64 %v90, ptr %v4
    %v91 = add i64 0, 0
    %v92 = load i64, ptr %v4
    %v93 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v92)
    %v94 = getelementptr i8, ptr @.str_248, i64 16
    %v95.e = call i64 @orion_text_eq(ptr %v93, ptr %v94)
    %v95 = add i64 %v95.e, 0
    %v96.cb = icmp ne i64 %v95, 0
    br i1 %v96.cb, label %if_96_then, label %if_96_else
if_96_then:
    %v98 = load i64, ptr %v4
    %v99 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v98)
    %v100 = getelementptr i8, ptr @.str_235, i64 16
    %v101.e = call i64 @orion_text_eq(ptr %v99, ptr %v100)
    %v101 = add i64 %v101.e, 0
    br label %if_96_merge
if_96_else:
    %v104 = add i64 0, 0
    br label %if_96_merge
if_96_merge:
    %v107 = phi i64 [ %v101, %if_96_then ], [ %v104, %if_96_else ]
    %v108.cb = icmp ne i64 %v107, 0
    br i1 %v108.cb, label %if_108_then, label %if_108_else
if_108_then:
    %v110 = load i64, ptr %v4
    %v111 = add i64 0, 1
    %v112 = add i64 %v110, %v111
    store i64 %v112, ptr %v4
    %v113 = add i64 0, 0
    br label %if_108_merge
if_108_else:
    br label %if_108_merge
if_108_merge:
    br label %if_47_merge
if_47_else:
    br label %if_47_merge
if_47_merge:
    br label %loop_9_header
loop_9_end:
    %v124 = getelementptr i8, ptr @.str_260, i64 16
    %v125 = getelementptr i8, ptr @.str_118, i64 16
    %v126 = getelementptr i8, ptr @.str_330, i64 16
    %v127 = getelementptr i8, ptr @.str_331, i64 16
    %v128 = load ptr, ptr %v7
    %v129 = call ptr @orion_map_new(i64 2)
    %v129.p0 = ptrtoint ptr %v126 to i64
    call void @orion_map_set(ptr %v129, ptr %v125, i64 %v129.p0)
    %v129.p1 = ptrtoint ptr %v128 to i64
    call void @orion_map_set(ptr %v129, ptr %v127, i64 %v129.p1)
    %v130 = getelementptr i8, ptr @.str_124, i64 16
    %v131 = load i64, ptr %v4
    %v132 = call ptr @orion_map_new(i64 2)
    %v132.p0 = ptrtoint ptr %v129 to i64
    call void @orion_map_set(ptr %v132, ptr %v124, i64 %v132.p0)
    call void @orion_map_set(ptr %v132, ptr %v130, i64 %v131)
    ret ptr %v132
}

define ptr @prog__psr_parse_list_literal(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, 1
    %v3 = add i64 %v1, %v2
    %v4 = alloca i64, align 8
    store i64 %v3, ptr %v4
    %v5 = add i64 0, 0
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = alloca ptr, align 8
    store ptr %v6, ptr %v7
    %v8 = add i64 0, 0
    br label %loop_9_header
loop_9_header:
    %v11 = load i64, ptr %v4
    %v12 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v11)
    %v13 = load i64, ptr %v4
    %v14 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v13)
    %v15 = getelementptr i8, ptr @.str_248, i64 16
    %v16.e = call i64 @orion_text_eq(ptr %v12, ptr %v15)
    %v16 = add i64 %v16.e, 0
    %v17.cb = icmp ne i64 %v16, 0
    br i1 %v17.cb, label %if_17_then, label %if_17_else
if_17_then:
    %v19 = getelementptr i8, ptr @.str_239, i64 16
    %v20.e = call i64 @orion_text_eq(ptr %v14, ptr %v19)
    %v20 = add i64 %v20.e, 0
    br label %if_17_merge
if_17_else:
    %v23 = add i64 0, 0
    br label %if_17_merge
if_17_merge:
    %v26 = phi i64 [ %v20, %if_17_then ], [ %v23, %if_17_else ]
    %v27 = getelementptr i8, ptr @.str_249, i64 16
    %v28.e = call i64 @orion_text_eq(ptr %v12, ptr %v27)
    %v28 = add i64 %v28.e, 0
    %v29.cb = icmp ne i64 %v26, 0
    br i1 %v29.cb, label %if_29_then, label %if_29_else
if_29_then:
    %v31 = load i64, ptr %v4
    %v32 = add i64 0, 1
    %v33 = add i64 %v31, %v32
    store i64 %v33, ptr %v4
    %v34 = add i64 0, 0
    br label %loop_9_end
if_29_else:
    br label %if_29_merge
if_29_merge:
    %v39.cb = icmp ne i64 %v28, 0
    br i1 %v39.cb, label %if_39_then, label %if_39_else
if_39_then:
    br label %loop_9_end
if_39_else:
    br label %if_39_merge
if_39_merge:
    %v45 = load i64, ptr %v4
    %v46 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v45)
    %v47 = load ptr, ptr %v7
    %v48 = getelementptr i8, ptr @.str_260, i64 16
    %v49.i = call i64 @orion_map_get(ptr %v46, ptr %v48)
    %v49.raw = inttoptr i64 %v49.i to ptr
    %v49.isnull = icmp eq i64 %v49.i, 0
    %v49 = select i1 %v49.isnull, ptr @orion_empty_list, ptr %v49.raw
    %v50.p = ptrtoint ptr %v49 to i64
    %v50 = call ptr @orion_list_push(ptr %v47, i64 %v50.p)
    store ptr %v50, ptr %v7
    %v51 = add i64 0, 0
    %v52 = getelementptr i8, ptr @.str_124, i64 16
    %v53 = call i64 @orion_map_get(ptr %v46, ptr %v52)
    store i64 %v53, ptr %v4
    %v54 = add i64 0, 0
    %v55 = load i64, ptr %v4
    %v56 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v55)
    %v57 = getelementptr i8, ptr @.str_248, i64 16
    %v58.e = call i64 @orion_text_eq(ptr %v56, ptr %v57)
    %v58 = add i64 %v58.e, 0
    %v59.cb = icmp ne i64 %v58, 0
    br i1 %v59.cb, label %if_59_then, label %if_59_else
if_59_then:
    %v61 = load i64, ptr %v4
    %v62 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v61)
    %v63 = getelementptr i8, ptr @.str_235, i64 16
    %v64.e = call i64 @orion_text_eq(ptr %v62, ptr %v63)
    %v64 = add i64 %v64.e, 0
    br label %if_59_merge
if_59_else:
    %v67 = add i64 0, 0
    br label %if_59_merge
if_59_merge:
    %v70 = phi i64 [ %v64, %if_59_then ], [ %v67, %if_59_else ]
    %v71.cb = icmp ne i64 %v70, 0
    br i1 %v71.cb, label %if_71_then, label %if_71_else
if_71_then:
    %v73 = load i64, ptr %v4
    %v74 = add i64 0, 1
    %v75 = add i64 %v73, %v74
    store i64 %v75, ptr %v4
    %v76 = add i64 0, 0
    br label %if_71_merge
if_71_else:
    br label %if_71_merge
if_71_merge:
    br label %loop_9_header
loop_9_end:
    %v83 = getelementptr i8, ptr @.str_260, i64 16
    %v84 = getelementptr i8, ptr @.str_118, i64 16
    %v85 = getelementptr i8, ptr @.str_301, i64 16
    %v86 = getelementptr i8, ptr @.str_302, i64 16
    %v87 = load ptr, ptr %v7
    %v88 = call ptr @orion_map_new(i64 2)
    %v88.p0 = ptrtoint ptr %v85 to i64
    call void @orion_map_set(ptr %v88, ptr %v84, i64 %v88.p0)
    %v88.p1 = ptrtoint ptr %v87 to i64
    call void @orion_map_set(ptr %v88, ptr %v86, i64 %v88.p1)
    %v89 = getelementptr i8, ptr @.str_124, i64 16
    %v90 = load i64, ptr %v4
    %v91 = call ptr @orion_map_new(i64 2)
    %v91.p0 = ptrtoint ptr %v88 to i64
    call void @orion_map_set(ptr %v91, ptr %v83, i64 %v91.p0)
    call void @orion_map_set(ptr %v91, ptr %v89, i64 %v90)
    ret ptr %v91
}

define ptr @prog__psr_parse_if(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, 1
    %v3 = add i64 %v1, %v2
    %v4 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v3)
    %v5 = getelementptr i8, ptr @.str_124, i64 16
    %v6 = call i64 @orion_map_get(ptr %v4, ptr %v5)
    %v7 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v6)
    %v8 = getelementptr i8, ptr @.str_123, i64 16
    %v9.e = call i64 @orion_text_eq(ptr %v7, ptr %v8)
    %v9 = add i64 %v9.e, 0
    %v10.cb = icmp ne i64 %v9, 0
    br i1 %v10.cb, label %if_10_then, label %if_10_else
if_10_then:
    %v12 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v6)
    %v13 = getelementptr i8, ptr @.str_289, i64 16
    %v14.e = call i64 @orion_text_eq(ptr %v12, ptr %v13)
    %v14 = add i64 %v14.e, 0
    br label %if_10_merge
if_10_else:
    %v17 = add i64 0, 0
    br label %if_10_merge
if_10_merge:
    %v20 = phi i64 [ %v14, %if_10_then ], [ %v17, %if_10_else ]
    %v21 = alloca i64, align 8
    store i64 %v6, ptr %v21
    %v22 = add i64 0, 0
    %v23.cb = icmp ne i64 %v20, 0
    br i1 %v23.cb, label %if_23_then, label %if_23_else
if_23_then:
    %v25 = add i64 0, 1
    %v26 = add i64 %v6, %v25
    store i64 %v26, ptr %v21
    %v27 = add i64 0, 0
    br label %if_23_merge
if_23_else:
    br label %if_23_merge
if_23_merge:
    %v32 = load i64, ptr %v21
    %v33 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v32)
    %v34 = getelementptr i8, ptr @.str_124, i64 16
    %v35 = call i64 @orion_map_get(ptr %v33, ptr %v34)
    store i64 %v35, ptr %v21
    %v36 = add i64 0, 0
    %v37 = load i64, ptr %v21
    %v38 = call i64 @prog__psr_skip_newlines(ptr %v0, i64 %v37)
    %v39 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v38)
    %v40 = getelementptr i8, ptr @.str_123, i64 16
    %v41.e = call i64 @orion_text_eq(ptr %v39, ptr %v40)
    %v41 = add i64 %v41.e, 0
    %v42.cb = icmp ne i64 %v41, 0
    br i1 %v42.cb, label %if_42_then, label %if_42_else
if_42_then:
    %v44 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v38)
    %v45 = getelementptr i8, ptr @.str_145, i64 16
    %v46.e = call i64 @orion_text_eq(ptr %v44, ptr %v45)
    %v46 = add i64 %v46.e, 0
    br label %if_42_merge
if_42_else:
    %v49 = add i64 0, 0
    br label %if_42_merge
if_42_merge:
    %v52 = phi i64 [ %v46, %if_42_then ], [ %v49, %if_42_else ]
    %v53.cb = icmp ne i64 %v52, 0
    br i1 %v53.cb, label %if_53_then, label %if_53_else
if_53_then:
    %v55 = add i64 0, 1
    %v56 = add i64 %v38, %v55
    %v57 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v56)
    %v58 = getelementptr i8, ptr @.str_248, i64 16
    %v59.e = call i64 @orion_text_eq(ptr %v57, ptr %v58)
    %v59 = add i64 %v59.e, 0
    br label %if_53_merge
if_53_else:
    %v62 = add i64 0, 0
    br label %if_53_merge
if_53_merge:
    %v65 = phi i64 [ %v59, %if_53_then ], [ %v62, %if_53_else ]
    %v66.cb = icmp ne i64 %v65, 0
    br i1 %v66.cb, label %if_66_then, label %if_66_else
if_66_then:
    %v68 = add i64 0, 1
    %v69 = add i64 %v38, %v68
    %v70 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v69)
    %v71 = getelementptr i8, ptr @.str_236, i64 16
    %v72.e = call i64 @orion_text_eq(ptr %v70, ptr %v71)
    %v72 = add i64 %v72.e, 0
    br label %if_66_merge
if_66_else:
    %v75 = add i64 0, 0
    br label %if_66_merge
if_66_merge:
    %v78 = phi i64 [ %v72, %if_66_then ], [ %v75, %if_66_else ]
    %v79.cb = icmp ne i64 %v52, 0
    br i1 %v79.cb, label %if_79_then, label %if_79_else
if_79_then:
    %v81.n = icmp eq i64 %v78, 0
    %v81 = zext i1 %v81.n to i64
    br label %if_79_merge
if_79_else:
    %v84 = add i64 0, 0
    br label %if_79_merge
if_79_merge:
    %v87 = phi i64 [ %v81, %if_79_then ], [ %v84, %if_79_else ]
    %v88 = getelementptr i8, ptr @.str_118, i64 16
    %v89 = getelementptr i8, ptr @.str_250, i64 16
    %v90 = getelementptr i8, ptr @.str_119, i64 16
    %v91 = getelementptr i8, ptr @.str_210, i64 16
    %v92 = call ptr @orion_map_new(i64 2)
    %v92.p0 = ptrtoint ptr %v89 to i64
    call void @orion_map_set(ptr %v92, ptr %v88, i64 %v92.p0)
    %v92.p1 = ptrtoint ptr %v91 to i64
    call void @orion_map_set(ptr %v92, ptr %v90, i64 %v92.p1)
    %v93 = alloca ptr, align 8
    store ptr %v92, ptr %v93
    %v94 = add i64 0, 0
    %v95.cb = icmp ne i64 %v87, 0
    br i1 %v95.cb, label %if_95_then, label %if_95_else
if_95_then:
    %v97 = add i64 0, 1
    %v98 = add i64 %v38, %v97
    %v99 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v98)
    %v100 = getelementptr i8, ptr @.str_260, i64 16
    %v101.i = call i64 @orion_map_get(ptr %v99, ptr %v100)
    %v101.raw = inttoptr i64 %v101.i to ptr
    %v101.isnull = icmp eq i64 %v101.i, 0
    %v101 = select i1 %v101.isnull, ptr @orion_empty_list, ptr %v101.raw
    store ptr %v101, ptr %v93
    %v102 = add i64 0, 0
    %v103 = getelementptr i8, ptr @.str_124, i64 16
    %v104 = call i64 @orion_map_get(ptr %v99, ptr %v103)
    store i64 %v104, ptr %v21
    %v105 = add i64 0, 0
    br label %if_95_merge
if_95_else:
    br label %if_95_merge
if_95_merge:
    %v110 = getelementptr i8, ptr @.str_260, i64 16
    %v111 = getelementptr i8, ptr @.str_118, i64 16
    %v112 = getelementptr i8, ptr @.str_287, i64 16
    %v113 = getelementptr i8, ptr @.str_288, i64 16
    %v114 = getelementptr i8, ptr @.str_260, i64 16
    %v115.i = call i64 @orion_map_get(ptr %v4, ptr %v114)
    %v115.raw = inttoptr i64 %v115.i to ptr
    %v115.isnull = icmp eq i64 %v115.i, 0
    %v115 = select i1 %v115.isnull, ptr @orion_empty_list, ptr %v115.raw
    %v116 = getelementptr i8, ptr @.str_289, i64 16
    %v117 = getelementptr i8, ptr @.str_260, i64 16
    %v118.i = call i64 @orion_map_get(ptr %v33, ptr %v117)
    %v118.raw = inttoptr i64 %v118.i to ptr
    %v118.isnull = icmp eq i64 %v118.i, 0
    %v118 = select i1 %v118.isnull, ptr @orion_empty_list, ptr %v118.raw
    %v119 = getelementptr i8, ptr @.str_145, i64 16
    %v120 = load ptr, ptr %v93
    %v121 = call ptr @orion_map_new(i64 4)
    %v121.p0 = ptrtoint ptr %v112 to i64
    call void @orion_map_set(ptr %v121, ptr %v111, i64 %v121.p0)
    %v121.p1 = ptrtoint ptr %v115 to i64
    call void @orion_map_set(ptr %v121, ptr %v113, i64 %v121.p1)
    %v121.p2 = ptrtoint ptr %v118 to i64
    call void @orion_map_set(ptr %v121, ptr %v116, i64 %v121.p2)
    %v121.p3 = ptrtoint ptr %v120 to i64
    call void @orion_map_set(ptr %v121, ptr %v119, i64 %v121.p3)
    %v122 = getelementptr i8, ptr @.str_124, i64 16
    %v123 = load i64, ptr %v21
    %v124 = call ptr @orion_map_new(i64 2)
    %v124.p0 = ptrtoint ptr %v121 to i64
    call void @orion_map_set(ptr %v124, ptr %v110, i64 %v124.p0)
    call void @orion_map_set(ptr %v124, ptr %v122, i64 %v123)
    ret ptr %v124
}

define ptr @prog__psr_ifchain_at(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2.i = call i64 @orion_list_at(ptr %v0, i64 %v1)
    %v2 = inttoptr i64 %v2.i to ptr
    ret ptr %v2
}

define ptr @prog__psr_parse_call(ptr %p0, i64 %p1, ptr %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr %p2, i64 0
    %v3.i = call i64 @orion_list_at(ptr %v0, i64 %v1)
    %v3 = inttoptr i64 %v3.i to ptr
    %v4 = getelementptr i8, ptr @.str_120, i64 16
    %v5 = call i64 @orion_map_get(ptr %v3, ptr %v4)
    %v6 = getelementptr i8, ptr @.str_121, i64 16
    %v7 = call i64 @orion_map_get(ptr %v3, ptr %v6)
    %v8 = add i64 0, 2
    %v9 = add i64 %v1, %v8
    %v10 = alloca i64, align 8
    store i64 %v9, ptr %v10
    %v11 = add i64 0, 0
    %v12 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v13 = alloca ptr, align 8
    store ptr %v12, ptr %v13
    %v14 = add i64 0, 0
    br label %loop_15_header
loop_15_header:
    %v17 = load i64, ptr %v10
    %v18 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v17)
    %v19 = getelementptr i8, ptr @.str_248, i64 16
    %v20.e = call i64 @orion_text_eq(ptr %v18, ptr %v19)
    %v20 = add i64 %v20.e, 0
    %v21.cb = icmp ne i64 %v20, 0
    br i1 %v21.cb, label %if_21_then, label %if_21_else
if_21_then:
    %v23 = load i64, ptr %v10
    %v24 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v23)
    %v25 = getelementptr i8, ptr @.str_234, i64 16
    %v26.e = call i64 @orion_text_eq(ptr %v24, ptr %v25)
    %v26 = add i64 %v26.e, 0
    br label %if_21_merge
if_21_else:
    %v29 = add i64 0, 0
    br label %if_21_merge
if_21_merge:
    %v32 = phi i64 [ %v26, %if_21_then ], [ %v29, %if_21_else ]
    %v33.cb = icmp ne i64 %v32, 0
    br i1 %v33.cb, label %if_33_then, label %if_33_else
if_33_then:
    %v35 = load i64, ptr %v10
    %v36 = add i64 0, 1
    %v37 = add i64 %v35, %v36
    store i64 %v37, ptr %v10
    %v38 = add i64 0, 0
    br label %loop_15_end
if_33_else:
    br label %if_33_merge
if_33_merge:
    %v43 = load i64, ptr %v10
    %v44 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v43)
    %v45 = getelementptr i8, ptr @.str_249, i64 16
    %v46.e = call i64 @orion_text_eq(ptr %v44, ptr %v45)
    %v46 = add i64 %v46.e, 0
    %v47.cb = icmp ne i64 %v46, 0
    br i1 %v47.cb, label %if_47_then, label %if_47_else
if_47_then:
    br label %loop_15_end
if_47_else:
    br label %if_47_merge
if_47_merge:
    %v53 = load i64, ptr %v10
    %v54 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v53)
    %v55 = getelementptr i8, ptr @.str_123, i64 16
    %v56.e = call i64 @orion_text_eq(ptr %v54, ptr %v55)
    %v56 = add i64 %v56.e, 0
    %v57.cb = icmp ne i64 %v56, 0
    br i1 %v57.cb, label %if_57_then, label %if_57_else
if_57_then:
    %v59 = load i64, ptr %v10
    %v60 = add i64 0, 1
    %v61 = add i64 %v59, %v60
    %v62 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v61)
    %v63 = getelementptr i8, ptr @.str_248, i64 16
    %v64.e = call i64 @orion_text_eq(ptr %v62, ptr %v63)
    %v64 = add i64 %v64.e, 0
    br label %if_57_merge
if_57_else:
    %v67 = add i64 0, 0
    br label %if_57_merge
if_57_merge:
    %v70 = phi i64 [ %v64, %if_57_then ], [ %v67, %if_57_else ]
    %v71.cb = icmp ne i64 %v70, 0
    br i1 %v71.cb, label %if_71_then, label %if_71_else
if_71_then:
    %v73 = load i64, ptr %v10
    %v74 = add i64 0, 1
    %v75 = add i64 %v73, %v74
    %v76 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v75)
    %v77 = getelementptr i8, ptr @.str_229, i64 16
    %v78.e = call i64 @orion_text_eq(ptr %v76, ptr %v77)
    %v78 = add i64 %v78.e, 0
    br label %if_71_merge
if_71_else:
    %v81 = add i64 0, 0
    br label %if_71_merge
if_71_merge:
    %v84 = phi i64 [ %v78, %if_71_then ], [ %v81, %if_71_else ]
    %v85.cb = icmp ne i64 %v84, 0
    br i1 %v85.cb, label %if_85_then, label %if_85_else
if_85_then:
    %v87 = load i64, ptr %v10
    %v88 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v87)
    %v89 = load i64, ptr %v10
    %v90 = add i64 0, 2
    %v91 = add i64 %v89, %v90
    %v92 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v91)
    %v93 = load ptr, ptr %v13
    %v94 = getelementptr i8, ptr @.str_118, i64 16
    %v95 = getelementptr i8, ptr @.str_332, i64 16
    %v96 = getelementptr i8, ptr @.str_257, i64 16
    %v97 = getelementptr i8, ptr @.str_119, i64 16
    %v98 = getelementptr i8, ptr @.str_260, i64 16
    %v99.i = call i64 @orion_map_get(ptr %v92, ptr %v98)
    %v99.raw = inttoptr i64 %v99.i to ptr
    %v99.isnull = icmp eq i64 %v99.i, 0
    %v99 = select i1 %v99.isnull, ptr @orion_empty_list, ptr %v99.raw
    %v100 = call ptr @orion_map_new(i64 3)
    %v100.p0 = ptrtoint ptr %v95 to i64
    call void @orion_map_set(ptr %v100, ptr %v94, i64 %v100.p0)
    %v100.p1 = ptrtoint ptr %v88 to i64
    call void @orion_map_set(ptr %v100, ptr %v96, i64 %v100.p1)
    %v100.p2 = ptrtoint ptr %v99 to i64
    call void @orion_map_set(ptr %v100, ptr %v97, i64 %v100.p2)
    %v101.p = ptrtoint ptr %v100 to i64
    %v101 = call ptr @orion_list_push(ptr %v93, i64 %v101.p)
    store ptr %v101, ptr %v13
    %v102 = add i64 0, 0
    %v103 = getelementptr i8, ptr @.str_124, i64 16
    %v104 = call i64 @orion_map_get(ptr %v92, ptr %v103)
    store i64 %v104, ptr %v10
    %v105 = add i64 0, 0
    br label %if_85_merge
if_85_else:
    %v108 = load i64, ptr %v10
    %v109 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v108)
    %v110 = load ptr, ptr %v13
    %v111 = getelementptr i8, ptr @.str_260, i64 16
    %v112.i = call i64 @orion_map_get(ptr %v109, ptr %v111)
    %v112.raw = inttoptr i64 %v112.i to ptr
    %v112.isnull = icmp eq i64 %v112.i, 0
    %v112 = select i1 %v112.isnull, ptr @orion_empty_list, ptr %v112.raw
    %v113.p = ptrtoint ptr %v112 to i64
    %v113 = call ptr @orion_list_push(ptr %v110, i64 %v113.p)
    store ptr %v113, ptr %v13
    %v114 = add i64 0, 0
    %v115 = getelementptr i8, ptr @.str_124, i64 16
    %v116 = call i64 @orion_map_get(ptr %v109, ptr %v115)
    store i64 %v116, ptr %v10
    %v117 = add i64 0, 0
    br label %if_85_merge
if_85_merge:
    %v120 = phi i64 [ %v105, %if_85_then ], [ %v117, %if_85_else ]
    %v121 = load i64, ptr %v10
    %v122 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v121)
    %v123 = getelementptr i8, ptr @.str_248, i64 16
    %v124.e = call i64 @orion_text_eq(ptr %v122, ptr %v123)
    %v124 = add i64 %v124.e, 0
    %v125.cb = icmp ne i64 %v124, 0
    br i1 %v125.cb, label %if_125_then, label %if_125_else
if_125_then:
    %v127 = load i64, ptr %v10
    %v128 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v127)
    %v129 = getelementptr i8, ptr @.str_235, i64 16
    %v130.e = call i64 @orion_text_eq(ptr %v128, ptr %v129)
    %v130 = add i64 %v130.e, 0
    br label %if_125_merge
if_125_else:
    %v133 = add i64 0, 0
    br label %if_125_merge
if_125_merge:
    %v136 = phi i64 [ %v130, %if_125_then ], [ %v133, %if_125_else ]
    %v137.cb = icmp ne i64 %v136, 0
    br i1 %v137.cb, label %if_137_then, label %if_137_else
if_137_then:
    %v139 = load i64, ptr %v10
    %v140 = add i64 0, 1
    %v141 = add i64 %v139, %v140
    store i64 %v141, ptr %v10
    %v142 = add i64 0, 0
    br label %if_137_merge
if_137_else:
    br label %if_137_merge
if_137_merge:
    br label %loop_15_header
loop_15_end:
    %v149 = getelementptr i8, ptr @.str_260, i64 16
    %v150 = getelementptr i8, ptr @.str_118, i64 16
    %v151 = getelementptr i8, ptr @.str_251, i64 16
    %v152 = getelementptr i8, ptr @.str_252, i64 16
    %v153 = getelementptr i8, ptr @.str_253, i64 16
    %v154 = load ptr, ptr %v13
    %v155 = getelementptr i8, ptr @.str_120, i64 16
    %v156 = getelementptr i8, ptr @.str_121, i64 16
    %v157 = call ptr @orion_map_new(i64 5)
    %v157.p0 = ptrtoint ptr %v151 to i64
    call void @orion_map_set(ptr %v157, ptr %v150, i64 %v157.p0)
    %v157.p1 = ptrtoint ptr %v2 to i64
    call void @orion_map_set(ptr %v157, ptr %v152, i64 %v157.p1)
    %v157.p2 = ptrtoint ptr %v154 to i64
    call void @orion_map_set(ptr %v157, ptr %v153, i64 %v157.p2)
    call void @orion_map_set(ptr %v157, ptr %v155, i64 %v5)
    call void @orion_map_set(ptr %v157, ptr %v156, i64 %v7)
    %v158 = getelementptr i8, ptr @.str_124, i64 16
    %v159 = load i64, ptr %v10
    %v160 = call ptr @orion_map_new(i64 2)
    %v160.p0 = ptrtoint ptr %v157 to i64
    call void @orion_map_set(ptr %v160, ptr %v149, i64 %v160.p0)
    call void @orion_map_set(ptr %v160, ptr %v158, i64 %v159)
    ret ptr %v160
}

define i64 @prog__psr_op_prec(ptr %p0, ptr %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = add i64 0, 0
    %v3 = alloca i64, align 8
    store i64 %v2, ptr %v3
    %v4 = add i64 0, 0
    %v5 = getelementptr i8, ptr @.str_123, i64 16
    %v6.e = call i64 @orion_text_eq(ptr %v0, ptr %v5)
    %v6 = add i64 %v6.e, 0
    %v7 = getelementptr i8, ptr @.str_248, i64 16
    %v8.e = call i64 @orion_text_eq(ptr %v0, ptr %v7)
    %v8 = add i64 %v8.e, 0
    %v9.cb = icmp ne i64 %v6, 0
    br i1 %v9.cb, label %if_9_then, label %if_9_else
if_9_then:
    %v11 = getelementptr i8, ptr @.str_169, i64 16
    %v12.e = call i64 @orion_text_eq(ptr %v1, ptr %v11)
    %v12 = add i64 %v12.e, 0
    br label %if_9_merge
if_9_else:
    %v15 = add i64 0, 0
    br label %if_9_merge
if_9_merge:
    %v18 = phi i64 [ %v12, %if_9_then ], [ %v15, %if_9_else ]
    %v19.cb = icmp ne i64 %v18, 0
    br i1 %v19.cb, label %if_19_then, label %if_19_else
if_19_then:
    %v21 = add i64 0, 5
    store i64 %v21, ptr %v3
    %v22 = add i64 0, 0
    br label %if_19_merge
if_19_else:
    br label %if_19_merge
if_19_merge:
    %v27.cb = icmp ne i64 %v6, 0
    br i1 %v27.cb, label %if_27_then, label %if_27_else
if_27_then:
    %v29 = getelementptr i8, ptr @.str_167, i64 16
    %v30.e = call i64 @orion_text_eq(ptr %v1, ptr %v29)
    %v30 = add i64 %v30.e, 0
    br label %if_27_merge
if_27_else:
    %v33 = add i64 0, 0
    br label %if_27_merge
if_27_merge:
    %v36 = phi i64 [ %v30, %if_27_then ], [ %v33, %if_27_else ]
    %v37.cb = icmp ne i64 %v36, 0
    br i1 %v37.cb, label %if_37_then, label %if_37_else
if_37_then:
    %v39 = add i64 0, 7
    store i64 %v39, ptr %v3
    %v40 = add i64 0, 0
    br label %if_37_merge
if_37_else:
    br label %if_37_merge
if_37_merge:
    %v45.cb = icmp ne i64 %v8, 0
    br i1 %v45.cb, label %if_45_then, label %if_45_else
if_45_then:
    %v47 = getelementptr i8, ptr @.str_216, i64 16
    %v48.e = call i64 @orion_text_eq(ptr %v1, ptr %v47)
    %v48 = add i64 %v48.e, 0
    %v49.cb = icmp ne i64 %v48, 0
    br i1 %v49.cb, label %if_49_then, label %if_49_else
if_49_then:
    br label %if_49_merge
if_49_else:
    %v53 = getelementptr i8, ptr @.str_217, i64 16
    %v54.e = call i64 @orion_text_eq(ptr %v1, ptr %v53)
    %v54 = add i64 %v54.e, 0
    br label %if_49_merge
if_49_merge:
    %v57 = phi i64 [ %v48, %if_49_then ], [ %v54, %if_49_else ]
    %v58.cb = icmp ne i64 %v57, 0
    br i1 %v58.cb, label %if_58_then, label %if_58_else
if_58_then:
    br label %if_58_merge
if_58_else:
    %v62 = getelementptr i8, ptr @.str_230, i64 16
    %v63.e = call i64 @orion_text_eq(ptr %v1, ptr %v62)
    %v63 = add i64 %v63.e, 0
    br label %if_58_merge
if_58_merge:
    %v66 = phi i64 [ %v57, %if_58_then ], [ %v63, %if_58_else ]
    %v67.cb = icmp ne i64 %v66, 0
    br i1 %v67.cb, label %if_67_then, label %if_67_else
if_67_then:
    br label %if_67_merge
if_67_else:
    %v71 = getelementptr i8, ptr @.str_231, i64 16
    %v72.e = call i64 @orion_text_eq(ptr %v1, ptr %v71)
    %v72 = add i64 %v72.e, 0
    br label %if_67_merge
if_67_merge:
    %v75 = phi i64 [ %v66, %if_67_then ], [ %v72, %if_67_else ]
    %v76.cb = icmp ne i64 %v75, 0
    br i1 %v76.cb, label %if_76_then, label %if_76_else
if_76_then:
    br label %if_76_merge
if_76_else:
    %v80 = getelementptr i8, ptr @.str_218, i64 16
    %v81.e = call i64 @orion_text_eq(ptr %v1, ptr %v80)
    %v81 = add i64 %v81.e, 0
    br label %if_76_merge
if_76_merge:
    %v84 = phi i64 [ %v75, %if_76_then ], [ %v81, %if_76_else ]
    %v85.cb = icmp ne i64 %v84, 0
    br i1 %v85.cb, label %if_85_then, label %if_85_else
if_85_then:
    br label %if_85_merge
if_85_else:
    %v89 = getelementptr i8, ptr @.str_219, i64 16
    %v90.e = call i64 @orion_text_eq(ptr %v1, ptr %v89)
    %v90 = add i64 %v90.e, 0
    br label %if_85_merge
if_85_merge:
    %v93 = phi i64 [ %v84, %if_85_then ], [ %v90, %if_85_else ]
    %v94 = getelementptr i8, ptr @.str_225, i64 16
    %v95.e = call i64 @orion_text_eq(ptr %v1, ptr %v94)
    %v95 = add i64 %v95.e, 0
    %v96.cb = icmp ne i64 %v95, 0
    br i1 %v96.cb, label %if_96_then, label %if_96_else
if_96_then:
    br label %if_96_merge
if_96_else:
    %v100 = getelementptr i8, ptr @.str_226, i64 16
    %v101.e = call i64 @orion_text_eq(ptr %v1, ptr %v100)
    %v101 = add i64 %v101.e, 0
    br label %if_96_merge
if_96_merge:
    %v104 = phi i64 [ %v95, %if_96_then ], [ %v101, %if_96_else ]
    %v105 = getelementptr i8, ptr @.str_227, i64 16
    %v106.e = call i64 @orion_text_eq(ptr %v1, ptr %v105)
    %v106 = add i64 %v106.e, 0
    %v107.cb = icmp ne i64 %v106, 0
    br i1 %v107.cb, label %if_107_then, label %if_107_else
if_107_then:
    br label %if_107_merge
if_107_else:
    %v111 = getelementptr i8, ptr @.str_228, i64 16
    %v112.e = call i64 @orion_text_eq(ptr %v1, ptr %v111)
    %v112 = add i64 %v112.e, 0
    br label %if_107_merge
if_107_merge:
    %v115 = phi i64 [ %v106, %if_107_then ], [ %v112, %if_107_else ]
    %v116.cb = icmp ne i64 %v115, 0
    br i1 %v116.cb, label %if_116_then, label %if_116_else
if_116_then:
    br label %if_116_merge
if_116_else:
    %v120 = getelementptr i8, ptr @.str_246, i64 16
    %v121.e = call i64 @orion_text_eq(ptr %v1, ptr %v120)
    %v121 = add i64 %v121.e, 0
    br label %if_116_merge
if_116_merge:
    %v124 = phi i64 [ %v115, %if_116_then ], [ %v121, %if_116_else ]
    %v125.cb = icmp ne i64 %v93, 0
    br i1 %v125.cb, label %if_125_then, label %if_125_else
if_125_then:
    %v127 = add i64 0, 10
    store i64 %v127, ptr %v3
    %v128 = add i64 0, 0
    br label %if_125_merge
if_125_else:
    br label %if_125_merge
if_125_merge:
    %v133.cb = icmp ne i64 %v104, 0
    br i1 %v133.cb, label %if_133_then, label %if_133_else
if_133_then:
    %v135 = add i64 0, 20
    store i64 %v135, ptr %v3
    %v136 = add i64 0, 0
    br label %if_133_merge
if_133_else:
    br label %if_133_merge
if_133_merge:
    %v141.cb = icmp ne i64 %v124, 0
    br i1 %v141.cb, label %if_141_then, label %if_141_else
if_141_then:
    %v143 = add i64 0, 30
    store i64 %v143, ptr %v3
    %v144 = add i64 0, 0
    br label %if_141_merge
if_141_else:
    br label %if_141_merge
if_141_merge:
    br label %if_45_merge
if_45_else:
    br label %if_45_merge
if_45_merge:
    %v153 = load i64, ptr %v3
    ret i64 %v153
}

define ptr @prog__psr_parse_postfix(ptr %p0, i64 %p1, ptr %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr %p2, i64 0
    %v3 = alloca ptr, align 8
    store ptr %v2, ptr %v3
    %v4 = add i64 0, 0
    %v5 = alloca i64, align 8
    store i64 %v1, ptr %v5
    %v6 = add i64 0, 0
    br label %loop_7_header
loop_7_header:
    %v9 = load i64, ptr %v5
    %v10 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v9)
    %v11 = load i64, ptr %v5
    %v12 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v11)
    %v13 = getelementptr i8, ptr @.str_248, i64 16
    %v14.e = call i64 @orion_text_eq(ptr %v10, ptr %v13)
    %v14 = add i64 %v14.e, 0
    %v15.cb = icmp ne i64 %v14, 0
    br i1 %v15.cb, label %if_15_then, label %if_15_else
if_15_then:
    %v17 = getelementptr i8, ptr @.str_103, i64 16
    %v18.e = call i64 @orion_text_eq(ptr %v12, ptr %v17)
    %v18 = add i64 %v18.e, 0
    br label %if_15_merge
if_15_else:
    %v21 = add i64 0, 0
    br label %if_15_merge
if_15_merge:
    %v24 = phi i64 [ %v18, %if_15_then ], [ %v21, %if_15_else ]
    %v25 = load i64, ptr %v5
    %v26.i = call i64 @orion_list_at(ptr %v0, i64 %v25)
    %v26 = inttoptr i64 %v26.i to ptr
    %v27.cb = icmp ne i64 %v24, 0
    br i1 %v27.cb, label %if_27_then, label %if_27_else
if_27_then:
    %v29 = getelementptr i8, ptr @.str_120, i64 16
    %v30 = call i64 @orion_map_get(ptr %v26, ptr %v29)
    br label %if_27_merge
if_27_else:
    %v33 = add i64 0, 0
    br label %if_27_merge
if_27_merge:
    %v36 = phi i64 [ %v30, %if_27_then ], [ %v33, %if_27_else ]
    %v37.cb = icmp ne i64 %v24, 0
    br i1 %v37.cb, label %if_37_then, label %if_37_else
if_37_then:
    %v39 = getelementptr i8, ptr @.str_121, i64 16
    %v40 = call i64 @orion_map_get(ptr %v26, ptr %v39)
    br label %if_37_merge
if_37_else:
    %v43 = add i64 0, 0
    br label %if_37_merge
if_37_merge:
    %v46 = phi i64 [ %v40, %if_37_then ], [ %v43, %if_37_else ]
    %v47.cb = icmp ne i64 %v24, 0
    br i1 %v47.cb, label %if_47_then, label %if_47_else
if_47_then:
    %v49 = load i64, ptr %v5
    %v50 = add i64 0, 1
    %v51 = add i64 %v49, %v50
    %v52 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v51)
    %v53 = load i64, ptr %v5
    %v54 = add i64 0, 2
    %v55 = add i64 %v53, %v54
    store i64 %v55, ptr %v5
    %v56 = add i64 0, 0
    %v57 = load i64, ptr %v5
    %v58 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v57)
    %v59 = getelementptr i8, ptr @.str_248, i64 16
    %v60.e = call i64 @orion_text_eq(ptr %v58, ptr %v59)
    %v60 = add i64 %v60.e, 0
    %v61.cb = icmp ne i64 %v60, 0
    br i1 %v61.cb, label %if_61_then, label %if_61_else
if_61_then:
    %v63 = load i64, ptr %v5
    %v64 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v63)
    %v65 = getelementptr i8, ptr @.str_233, i64 16
    %v66.e = call i64 @orion_text_eq(ptr %v64, ptr %v65)
    %v66 = add i64 %v66.e, 0
    br label %if_61_merge
if_61_else:
    %v69 = add i64 0, 0
    br label %if_61_merge
if_61_merge:
    %v72 = phi i64 [ %v66, %if_61_then ], [ %v69, %if_61_else ]
    %v73.cb = icmp ne i64 %v72, 0
    br i1 %v73.cb, label %if_73_then, label %if_73_else
if_73_then:
    %v75 = load i64, ptr %v5
    %v76 = add i64 0, 1
    %v77 = add i64 %v75, %v76
    store i64 %v77, ptr %v5
    %v78 = add i64 0, 0
    %v79 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v80 = alloca ptr, align 8
    store ptr %v79, ptr %v80
    %v81 = add i64 0, 0
    br label %loop_82_header
loop_82_header:
    %v84 = load i64, ptr %v5
    %v85 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v84)
    %v86 = load i64, ptr %v5
    %v87 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v86)
    %v88 = getelementptr i8, ptr @.str_248, i64 16
    %v89.e = call i64 @orion_text_eq(ptr %v85, ptr %v88)
    %v89 = add i64 %v89.e, 0
    %v90.cb = icmp ne i64 %v89, 0
    br i1 %v90.cb, label %if_90_then, label %if_90_else
if_90_then:
    %v92 = getelementptr i8, ptr @.str_234, i64 16
    %v93.e = call i64 @orion_text_eq(ptr %v87, ptr %v92)
    %v93 = add i64 %v93.e, 0
    br label %if_90_merge
if_90_else:
    %v96 = add i64 0, 0
    br label %if_90_merge
if_90_merge:
    %v99 = phi i64 [ %v93, %if_90_then ], [ %v96, %if_90_else ]
    %v100.cb = icmp ne i64 %v99, 0
    br i1 %v100.cb, label %if_100_then, label %if_100_else
if_100_then:
    %v102 = load i64, ptr %v5
    %v103 = add i64 0, 1
    %v104 = add i64 %v102, %v103
    store i64 %v104, ptr %v5
    %v105 = add i64 0, 0
    br label %loop_82_end
if_100_else:
    br label %if_100_merge
if_100_merge:
    %v110 = getelementptr i8, ptr @.str_249, i64 16
    %v111.e = call i64 @orion_text_eq(ptr %v85, ptr %v110)
    %v111 = add i64 %v111.e, 0
    %v112.cb = icmp ne i64 %v111, 0
    br i1 %v112.cb, label %if_112_then, label %if_112_else
if_112_then:
    br label %loop_82_end
if_112_else:
    br label %if_112_merge
if_112_merge:
    %v118 = load i64, ptr %v5
    %v119 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v118)
    %v120 = load ptr, ptr %v80
    %v121 = getelementptr i8, ptr @.str_260, i64 16
    %v122.i = call i64 @orion_map_get(ptr %v119, ptr %v121)
    %v122.raw = inttoptr i64 %v122.i to ptr
    %v122.isnull = icmp eq i64 %v122.i, 0
    %v122 = select i1 %v122.isnull, ptr @orion_empty_list, ptr %v122.raw
    %v123.p = ptrtoint ptr %v122 to i64
    %v123 = call ptr @orion_list_push(ptr %v120, i64 %v123.p)
    store ptr %v123, ptr %v80
    %v124 = add i64 0, 0
    %v125 = getelementptr i8, ptr @.str_124, i64 16
    %v126 = call i64 @orion_map_get(ptr %v119, ptr %v125)
    store i64 %v126, ptr %v5
    %v127 = add i64 0, 0
    %v128 = load i64, ptr %v5
    %v129 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v128)
    %v130 = getelementptr i8, ptr @.str_248, i64 16
    %v131.e = call i64 @orion_text_eq(ptr %v129, ptr %v130)
    %v131 = add i64 %v131.e, 0
    %v132.cb = icmp ne i64 %v131, 0
    br i1 %v132.cb, label %if_132_then, label %if_132_else
if_132_then:
    %v134 = load i64, ptr %v5
    %v135 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v134)
    %v136 = getelementptr i8, ptr @.str_235, i64 16
    %v137.e = call i64 @orion_text_eq(ptr %v135, ptr %v136)
    %v137 = add i64 %v137.e, 0
    br label %if_132_merge
if_132_else:
    %v140 = add i64 0, 0
    br label %if_132_merge
if_132_merge:
    %v143 = phi i64 [ %v137, %if_132_then ], [ %v140, %if_132_else ]
    %v144.cb = icmp ne i64 %v143, 0
    br i1 %v144.cb, label %if_144_then, label %if_144_else
if_144_then:
    %v146 = load i64, ptr %v5
    %v147 = add i64 0, 1
    %v148 = add i64 %v146, %v147
    store i64 %v148, ptr %v5
    %v149 = add i64 0, 0
    br label %if_144_merge
if_144_else:
    br label %if_144_merge
if_144_merge:
    br label %loop_82_header
loop_82_end:
    %v156 = getelementptr i8, ptr @.str_118, i64 16
    %v157 = getelementptr i8, ptr @.str_333, i64 16
    %v158 = getelementptr i8, ptr @.str_334, i64 16
    %v159 = load ptr, ptr %v3
    %v160 = getelementptr i8, ptr @.str_335, i64 16
    %v161 = getelementptr i8, ptr @.str_253, i64 16
    %v162 = load ptr, ptr %v80
    %v163 = getelementptr i8, ptr @.str_120, i64 16
    %v164 = getelementptr i8, ptr @.str_121, i64 16
    %v165 = call ptr @orion_map_new(i64 6)
    %v165.p0 = ptrtoint ptr %v157 to i64
    call void @orion_map_set(ptr %v165, ptr %v156, i64 %v165.p0)
    %v165.p1 = ptrtoint ptr %v159 to i64
    call void @orion_map_set(ptr %v165, ptr %v158, i64 %v165.p1)
    %v165.p2 = ptrtoint ptr %v52 to i64
    call void @orion_map_set(ptr %v165, ptr %v160, i64 %v165.p2)
    %v165.p3 = ptrtoint ptr %v162 to i64
    call void @orion_map_set(ptr %v165, ptr %v161, i64 %v165.p3)
    call void @orion_map_set(ptr %v165, ptr %v163, i64 %v36)
    call void @orion_map_set(ptr %v165, ptr %v164, i64 %v46)
    store ptr %v165, ptr %v3
    %v166 = add i64 0, 0
    br label %if_73_merge
if_73_else:
    %v169 = getelementptr i8, ptr @.str_118, i64 16
    %v170 = getelementptr i8, ptr @.str_254, i64 16
    %v171 = getelementptr i8, ptr @.str_255, i64 16
    %v172 = load ptr, ptr %v3
    %v173 = getelementptr i8, ptr @.str_258, i64 16
    %v174 = getelementptr i8, ptr @.str_120, i64 16
    %v175 = getelementptr i8, ptr @.str_121, i64 16
    %v176 = call ptr @orion_map_new(i64 5)
    %v176.p0 = ptrtoint ptr %v170 to i64
    call void @orion_map_set(ptr %v176, ptr %v169, i64 %v176.p0)
    %v176.p1 = ptrtoint ptr %v172 to i64
    call void @orion_map_set(ptr %v176, ptr %v171, i64 %v176.p1)
    %v176.p2 = ptrtoint ptr %v52 to i64
    call void @orion_map_set(ptr %v176, ptr %v173, i64 %v176.p2)
    call void @orion_map_set(ptr %v176, ptr %v174, i64 %v36)
    call void @orion_map_set(ptr %v176, ptr %v175, i64 %v46)
    store ptr %v176, ptr %v3
    %v177 = add i64 0, 0
    br label %if_73_merge
if_73_merge:
    %v180 = phi i64 [ %v166, %loop_82_end ], [ %v177, %if_73_else ]
    br label %if_47_merge
if_47_else:
    br label %if_47_merge
if_47_merge:
    %v185 = getelementptr i8, ptr @.str_248, i64 16
    %v186.e = call i64 @orion_text_eq(ptr %v10, ptr %v185)
    %v186 = add i64 %v186.e, 0
    %v187.cb = icmp ne i64 %v186, 0
    br i1 %v187.cb, label %if_187_then, label %if_187_else
if_187_then:
    %v189 = getelementptr i8, ptr @.str_238, i64 16
    %v190.e = call i64 @orion_text_eq(ptr %v12, ptr %v189)
    %v190 = add i64 %v190.e, 0
    br label %if_187_merge
if_187_else:
    %v193 = add i64 0, 0
    br label %if_187_merge
if_187_merge:
    %v196 = phi i64 [ %v190, %if_187_then ], [ %v193, %if_187_else ]
    %v197.cb = icmp ne i64 %v196, 0
    br i1 %v197.cb, label %if_197_then, label %if_197_else
if_197_then:
    %v199 = load i64, ptr %v5
    %v200 = add i64 0, 1
    %v201 = add i64 %v199, %v200
    %v202 = call ptr @prog__psr_parse_expr(ptr %v0, i64 %v201)
    %v203 = getelementptr i8, ptr @.str_124, i64 16
    %v204 = call i64 @orion_map_get(ptr %v202, ptr %v203)
    store i64 %v204, ptr %v5
    %v205 = add i64 0, 0
    %v206 = load i64, ptr %v5
    %v207 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v206)
    %v208 = getelementptr i8, ptr @.str_248, i64 16
    %v209.e = call i64 @orion_text_eq(ptr %v207, ptr %v208)
    %v209 = add i64 %v209.e, 0
    %v210.cb = icmp ne i64 %v209, 0
    br i1 %v210.cb, label %if_210_then, label %if_210_else
if_210_then:
    %v212 = load i64, ptr %v5
    %v213 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v212)
    %v214 = getelementptr i8, ptr @.str_239, i64 16
    %v215.e = call i64 @orion_text_eq(ptr %v213, ptr %v214)
    %v215 = add i64 %v215.e, 0
    br label %if_210_merge
if_210_else:
    %v218 = add i64 0, 0
    br label %if_210_merge
if_210_merge:
    %v221 = phi i64 [ %v215, %if_210_then ], [ %v218, %if_210_else ]
    %v222.cb = icmp ne i64 %v221, 0
    br i1 %v222.cb, label %if_222_then, label %if_222_else
if_222_then:
    %v224 = load i64, ptr %v5
    %v225 = add i64 0, 1
    %v226 = add i64 %v224, %v225
    store i64 %v226, ptr %v5
    %v227 = add i64 0, 0
    br label %if_222_merge
if_222_else:
    br label %if_222_merge
if_222_merge:
    %v232 = getelementptr i8, ptr @.str_118, i64 16
    %v233 = getelementptr i8, ptr @.str_336, i64 16
    %v234 = getelementptr i8, ptr @.str_255, i64 16
    %v235 = load ptr, ptr %v3
    %v236 = getelementptr i8, ptr @.str_337, i64 16
    %v237 = getelementptr i8, ptr @.str_260, i64 16
    %v238.i = call i64 @orion_map_get(ptr %v202, ptr %v237)
    %v238.raw = inttoptr i64 %v238.i to ptr
    %v238.isnull = icmp eq i64 %v238.i, 0
    %v238 = select i1 %v238.isnull, ptr @orion_empty_list, ptr %v238.raw
    %v239 = call ptr @orion_map_new(i64 3)
    %v239.p0 = ptrtoint ptr %v233 to i64
    call void @orion_map_set(ptr %v239, ptr %v232, i64 %v239.p0)
    %v239.p1 = ptrtoint ptr %v235 to i64
    call void @orion_map_set(ptr %v239, ptr %v234, i64 %v239.p1)
    %v239.p2 = ptrtoint ptr %v238 to i64
    call void @orion_map_set(ptr %v239, ptr %v236, i64 %v239.p2)
    store ptr %v239, ptr %v3
    %v240 = add i64 0, 0
    br label %if_197_merge
if_197_else:
    br label %if_197_merge
if_197_merge:
    %v245 = getelementptr i8, ptr @.str_248, i64 16
    %v246.e = call i64 @orion_text_eq(ptr %v10, ptr %v245)
    %v246 = add i64 %v246.e, 0
    %v247.cb = icmp ne i64 %v246, 0
    br i1 %v247.cb, label %if_247_then, label %if_247_else
if_247_then:
    %v249 = getelementptr i8, ptr @.str_242, i64 16
    %v250.e = call i64 @orion_text_eq(ptr %v12, ptr %v249)
    %v250 = add i64 %v250.e, 0
    br label %if_247_merge
if_247_else:
    %v253 = add i64 0, 0
    br label %if_247_merge
if_247_merge:
    %v256 = phi i64 [ %v250, %if_247_then ], [ %v253, %if_247_else ]
    %v257.cb = icmp ne i64 %v256, 0
    br i1 %v257.cb, label %if_257_then, label %if_257_else
if_257_then:
    %v259 = getelementptr i8, ptr @.str_118, i64 16
    %v260 = getelementptr i8, ptr @.str_338, i64 16
    %v261 = getelementptr i8, ptr @.str_339, i64 16
    %v262 = load ptr, ptr %v3
    %v263 = call ptr @orion_map_new(i64 2)
    %v263.p0 = ptrtoint ptr %v260 to i64
    call void @orion_map_set(ptr %v263, ptr %v259, i64 %v263.p0)
    %v263.p1 = ptrtoint ptr %v262 to i64
    call void @orion_map_set(ptr %v263, ptr %v261, i64 %v263.p1)
    store ptr %v263, ptr %v3
    %v264 = add i64 0, 0
    %v265 = load i64, ptr %v5
    %v266 = add i64 0, 1
    %v267 = add i64 %v265, %v266
    store i64 %v267, ptr %v5
    %v268 = add i64 0, 0
    br label %if_257_merge
if_257_else:
    br label %if_257_merge
if_257_merge:
    %v273.n = icmp eq i64 %v24, 0
    %v273 = zext i1 %v273.n to i64
    %v274.cb = icmp ne i64 %v273, 0
    br i1 %v274.cb, label %if_274_then, label %if_274_else
if_274_then:
    %v276.n = icmp eq i64 %v196, 0
    %v276 = zext i1 %v276.n to i64
    br label %if_274_merge
if_274_else:
    %v279 = add i64 0, 0
    br label %if_274_merge
if_274_merge:
    %v282 = phi i64 [ %v276, %if_274_then ], [ %v279, %if_274_else ]
    %v283.cb = icmp ne i64 %v282, 0
    br i1 %v283.cb, label %if_283_then, label %if_283_else
if_283_then:
    %v285.n = icmp eq i64 %v256, 0
    %v285 = zext i1 %v285.n to i64
    br label %if_283_merge
if_283_else:
    %v288 = add i64 0, 0
    br label %if_283_merge
if_283_merge:
    %v291 = phi i64 [ %v285, %if_283_then ], [ %v288, %if_283_else ]
    %v292.cb = icmp ne i64 %v291, 0
    br i1 %v292.cb, label %if_292_then, label %if_292_else
if_292_then:
    br label %loop_7_end
if_292_else:
    br label %if_292_merge
if_292_merge:
    br label %loop_7_header
loop_7_end:
    %v300 = getelementptr i8, ptr @.str_260, i64 16
    %v301 = load ptr, ptr %v3
    %v302 = getelementptr i8, ptr @.str_124, i64 16
    %v303 = load i64, ptr %v5
    %v304 = call ptr @orion_map_new(i64 2)
    %v304.p0 = ptrtoint ptr %v301 to i64
    call void @orion_map_set(ptr %v304, ptr %v300, i64 %v304.p0)
    call void @orion_map_set(ptr %v304, ptr %v302, i64 %v303)
    ret ptr %v304
}

define ptr @prog__psr_parse_expr_at(ptr %p0, i64 %p1, i64 %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = call ptr @prog__psr_parse_primary(ptr %v0, i64 %v1)
    %v4 = getelementptr i8, ptr @.str_124, i64 16
    %v5 = call i64 @orion_map_get(ptr %v3, ptr %v4)
    %v6 = getelementptr i8, ptr @.str_260, i64 16
    %v7.i = call i64 @orion_map_get(ptr %v3, ptr %v6)
    %v7.raw = inttoptr i64 %v7.i to ptr
    %v7.isnull = icmp eq i64 %v7.i, 0
    %v7 = select i1 %v7.isnull, ptr @orion_empty_list, ptr %v7.raw
    %v8 = call ptr @prog__psr_parse_postfix(ptr %v0, i64 %v5, ptr %v7)
    %v9 = getelementptr i8, ptr @.str_260, i64 16
    %v10.i = call i64 @orion_map_get(ptr %v8, ptr %v9)
    %v10.raw = inttoptr i64 %v10.i to ptr
    %v10.isnull = icmp eq i64 %v10.i, 0
    %v10 = select i1 %v10.isnull, ptr @orion_empty_list, ptr %v10.raw
    %v11 = alloca ptr, align 8
    store ptr %v10, ptr %v11
    %v12 = add i64 0, 0
    %v13 = getelementptr i8, ptr @.str_124, i64 16
    %v14 = call i64 @orion_map_get(ptr %v8, ptr %v13)
    %v15 = alloca i64, align 8
    store i64 %v14, ptr %v15
    %v16 = add i64 0, 0
    br label %loop_17_header
loop_17_header:
    %v19 = load i64, ptr %v15
    %v20 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v19)
    %v21 = load i64, ptr %v15
    %v22 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v21)
    %v23 = call i64 @prog__psr_op_prec(ptr %v20, ptr %v22)
    %v24 = add i64 0, 0
    %v25.b = icmp eq i64 %v23, %v24
    %v25 = zext i1 %v25.b to i64
    %v26.cb = icmp ne i64 %v25, 0
    br i1 %v26.cb, label %if_26_then, label %if_26_else
if_26_then:
    br label %if_26_merge
if_26_else:
    %v30.b = icmp slt i64 %v23, %v2
    %v30 = zext i1 %v30.b to i64
    br label %if_26_merge
if_26_merge:
    %v33 = phi i64 [ %v25, %if_26_then ], [ %v30, %if_26_else ]
    %v34.cb = icmp ne i64 %v33, 0
    br i1 %v34.cb, label %if_34_then, label %if_34_else
if_34_then:
    br label %loop_17_end
if_34_else:
    br label %if_34_merge
if_34_merge:
    %v40 = load i64, ptr %v15
    %v41 = add i64 0, 1
    %v42 = add i64 %v40, %v41
    %v43 = add i64 0, 1
    %v44 = add i64 %v23, %v43
    %v45 = call ptr @prog__psr_parse_expr_at(ptr %v0, i64 %v42, i64 %v44)
    %v46 = getelementptr i8, ptr @.str_118, i64 16
    %v47 = getelementptr i8, ptr @.str_325, i64 16
    %v48 = getelementptr i8, ptr @.str_312, i64 16
    %v49 = getelementptr i8, ptr @.str_326, i64 16
    %v50 = load ptr, ptr %v11
    %v51 = getelementptr i8, ptr @.str_327, i64 16
    %v52 = getelementptr i8, ptr @.str_260, i64 16
    %v53.i = call i64 @orion_map_get(ptr %v45, ptr %v52)
    %v53.raw = inttoptr i64 %v53.i to ptr
    %v53.isnull = icmp eq i64 %v53.i, 0
    %v53 = select i1 %v53.isnull, ptr @orion_empty_list, ptr %v53.raw
    %v54 = call ptr @orion_map_new(i64 4)
    %v54.p0 = ptrtoint ptr %v47 to i64
    call void @orion_map_set(ptr %v54, ptr %v46, i64 %v54.p0)
    %v54.p1 = ptrtoint ptr %v22 to i64
    call void @orion_map_set(ptr %v54, ptr %v48, i64 %v54.p1)
    %v54.p2 = ptrtoint ptr %v50 to i64
    call void @orion_map_set(ptr %v54, ptr %v49, i64 %v54.p2)
    %v54.p3 = ptrtoint ptr %v53 to i64
    call void @orion_map_set(ptr %v54, ptr %v51, i64 %v54.p3)
    store ptr %v54, ptr %v11
    %v55 = add i64 0, 0
    %v56 = getelementptr i8, ptr @.str_124, i64 16
    %v57 = call i64 @orion_map_get(ptr %v45, ptr %v56)
    store i64 %v57, ptr %v15
    %v58 = add i64 0, 0
    br label %loop_17_header
loop_17_end:
    %v61 = getelementptr i8, ptr @.str_260, i64 16
    %v62 = load ptr, ptr %v11
    %v63 = getelementptr i8, ptr @.str_124, i64 16
    %v64 = load i64, ptr %v15
    %v65 = call ptr @orion_map_new(i64 2)
    %v65.p0 = ptrtoint ptr %v62 to i64
    call void @orion_map_set(ptr %v65, ptr %v61, i64 %v65.p0)
    call void @orion_map_set(ptr %v65, ptr %v63, i64 %v64)
    ret ptr %v65
}

define ptr @prog__psr_parse_expr(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, 1
    %v3 = call ptr @prog__psr_parse_expr_at(ptr %v0, i64 %v1, i64 %v2)
    ret ptr %v3
}

define ptr @prog__psr_parse_params(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = alloca i64, align 8
    store i64 %v1, ptr %v2
    %v3 = add i64 0, 0
    %v4 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v5 = alloca ptr, align 8
    store ptr %v4, ptr %v5
    %v6 = add i64 0, 0
    br label %loop_7_header
loop_7_header:
    %v9 = load i64, ptr %v2
    %v10 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v9)
    %v11 = getelementptr i8, ptr @.str_248, i64 16
    %v12.e = call i64 @orion_text_eq(ptr %v10, ptr %v11)
    %v12 = add i64 %v12.e, 0
    %v13.cb = icmp ne i64 %v12, 0
    br i1 %v13.cb, label %if_13_then, label %if_13_else
if_13_then:
    %v15 = load i64, ptr %v2
    %v16 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v15)
    %v17 = getelementptr i8, ptr @.str_234, i64 16
    %v18.e = call i64 @orion_text_eq(ptr %v16, ptr %v17)
    %v18 = add i64 %v18.e, 0
    br label %if_13_merge
if_13_else:
    %v21 = add i64 0, 0
    br label %if_13_merge
if_13_merge:
    %v24 = phi i64 [ %v18, %if_13_then ], [ %v21, %if_13_else ]
    %v25.cb = icmp ne i64 %v24, 0
    br i1 %v25.cb, label %if_25_then, label %if_25_else
if_25_then:
    %v27 = load i64, ptr %v2
    %v28 = add i64 0, 1
    %v29 = add i64 %v27, %v28
    store i64 %v29, ptr %v2
    %v30 = add i64 0, 0
    br label %loop_7_end
if_25_else:
    br label %if_25_merge
if_25_merge:
    %v35 = load i64, ptr %v2
    %v36 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v35)
    %v37 = load i64, ptr %v2
    %v38 = add i64 0, 1
    %v39 = add i64 %v37, %v38
    store i64 %v39, ptr %v2
    %v40 = add i64 0, 0
    %v41 = load i64, ptr %v2
    %v42 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v41)
    %v43 = getelementptr i8, ptr @.str_248, i64 16
    %v44.e = call i64 @orion_text_eq(ptr %v42, ptr %v43)
    %v44 = add i64 %v44.e, 0
    %v45.cb = icmp ne i64 %v44, 0
    br i1 %v45.cb, label %if_45_then, label %if_45_else
if_45_then:
    %v47 = load i64, ptr %v2
    %v48 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v47)
    %v49 = getelementptr i8, ptr @.str_236, i64 16
    %v50.e = call i64 @orion_text_eq(ptr %v48, ptr %v49)
    %v50 = add i64 %v50.e, 0
    br label %if_45_merge
if_45_else:
    %v53 = add i64 0, 0
    br label %if_45_merge
if_45_merge:
    %v56 = phi i64 [ %v50, %if_45_then ], [ %v53, %if_45_else ]
    %v57.cb = icmp ne i64 %v56, 0
    br i1 %v57.cb, label %if_57_then, label %if_57_else
if_57_then:
    %v59 = load i64, ptr %v2
    %v60 = add i64 0, 1
    %v61 = add i64 %v59, %v60
    store i64 %v61, ptr %v2
    %v62 = add i64 0, 0
    %v63 = load i64, ptr %v2
    %v64 = call ptr @prog__psr_parse_type(ptr %v0, i64 %v63)
    %v65 = load ptr, ptr %v5
    %v66 = getelementptr i8, ptr @.str_257, i64 16
    %v67 = getelementptr i8, ptr @.str_340, i64 16
    %v68 = getelementptr i8, ptr @.str_260, i64 16
    %v69.i = call i64 @orion_map_get(ptr %v64, ptr %v68)
    %v69.raw = inttoptr i64 %v69.i to ptr
    %v69.isnull = icmp eq i64 %v69.i, 0
    %v69 = select i1 %v69.isnull, ptr @orion_empty_list, ptr %v69.raw
    %v70 = call ptr @orion_map_new(i64 2)
    %v70.p0 = ptrtoint ptr %v36 to i64
    call void @orion_map_set(ptr %v70, ptr %v66, i64 %v70.p0)
    %v70.p1 = ptrtoint ptr %v69 to i64
    call void @orion_map_set(ptr %v70, ptr %v67, i64 %v70.p1)
    %v71.p = ptrtoint ptr %v70 to i64
    %v71 = call ptr @orion_list_push(ptr %v65, i64 %v71.p)
    store ptr %v71, ptr %v5
    %v72 = add i64 0, 0
    %v73 = getelementptr i8, ptr @.str_124, i64 16
    %v74 = call i64 @orion_map_get(ptr %v64, ptr %v73)
    store i64 %v74, ptr %v2
    %v75 = add i64 0, 0
    br label %if_57_merge
if_57_else:
    br label %if_57_merge
if_57_merge:
    %v80.n = icmp eq i64 %v56, 0
    %v80 = zext i1 %v80.n to i64
    %v81.cb = icmp ne i64 %v80, 0
    br i1 %v81.cb, label %if_81_then, label %if_81_else
if_81_then:
    %v83 = load ptr, ptr %v5
    %v84 = getelementptr i8, ptr @.str_257, i64 16
    %v85 = getelementptr i8, ptr @.str_340, i64 16
    %v86 = getelementptr i8, ptr @.str_118, i64 16
    %v87 = getelementptr i8, ptr @.str_341, i64 16
    %v88 = call ptr @orion_map_new(i64 1)
    %v88.p0 = ptrtoint ptr %v87 to i64
    call void @orion_map_set(ptr %v88, ptr %v86, i64 %v88.p0)
    %v89 = call ptr @orion_map_new(i64 2)
    %v89.p0 = ptrtoint ptr %v36 to i64
    call void @orion_map_set(ptr %v89, ptr %v84, i64 %v89.p0)
    %v89.p1 = ptrtoint ptr %v88 to i64
    call void @orion_map_set(ptr %v89, ptr %v85, i64 %v89.p1)
    %v90.p = ptrtoint ptr %v89 to i64
    %v90 = call ptr @orion_list_push(ptr %v83, i64 %v90.p)
    store ptr %v90, ptr %v5
    %v91 = add i64 0, 0
    br label %if_81_merge
if_81_else:
    br label %if_81_merge
if_81_merge:
    %v96 = load i64, ptr %v2
    %v97 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v96)
    %v98 = getelementptr i8, ptr @.str_248, i64 16
    %v99.e = call i64 @orion_text_eq(ptr %v97, ptr %v98)
    %v99 = add i64 %v99.e, 0
    %v100.cb = icmp ne i64 %v99, 0
    br i1 %v100.cb, label %if_100_then, label %if_100_else
if_100_then:
    %v102 = load i64, ptr %v2
    %v103 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v102)
    %v104 = getelementptr i8, ptr @.str_235, i64 16
    %v105.e = call i64 @orion_text_eq(ptr %v103, ptr %v104)
    %v105 = add i64 %v105.e, 0
    br label %if_100_merge
if_100_else:
    %v108 = add i64 0, 0
    br label %if_100_merge
if_100_merge:
    %v111 = phi i64 [ %v105, %if_100_then ], [ %v108, %if_100_else ]
    %v112.cb = icmp ne i64 %v111, 0
    br i1 %v112.cb, label %if_112_then, label %if_112_else
if_112_then:
    %v114 = load i64, ptr %v2
    %v115 = add i64 0, 1
    %v116 = add i64 %v114, %v115
    store i64 %v116, ptr %v2
    %v117 = add i64 0, 0
    br label %if_112_merge
if_112_else:
    br label %if_112_merge
if_112_merge:
    br label %loop_7_header
loop_7_end:
    %v124 = getelementptr i8, ptr @.str_260, i64 16
    %v125 = load ptr, ptr %v5
    %v126 = getelementptr i8, ptr @.str_124, i64 16
    %v127 = load i64, ptr %v2
    %v128 = call ptr @orion_map_new(i64 2)
    %v128.p0 = ptrtoint ptr %v125 to i64
    call void @orion_map_set(ptr %v128, ptr %v124, i64 %v128.p0)
    call void @orion_map_set(ptr %v128, ptr %v126, i64 %v127)
    ret ptr %v128
}

define i64 @prog__psr_peek_col(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = call i64 @prog__psr_skip_newlines(ptr %v0, i64 %v1)
    %v3 = call i64 @orion_list_len(ptr %v0)
    %v4.b = icmp sge i64 %v2, %v3
    %v4 = zext i1 %v4.b to i64
    %v5.cb = icmp ne i64 %v4, 0
    br i1 %v5.cb, label %if_5_then, label %if_5_else
if_5_then:
    %v7 = add i64 0, 0
    br label %if_5_merge
if_5_else:
    %v10.i = call i64 @orion_list_at(ptr %v0, i64 %v2)
    %v10 = inttoptr i64 %v10.i to ptr
    %v11 = getelementptr i8, ptr @.str_121, i64 16
    %v12 = call i64 @orion_map_get(ptr %v10, ptr %v11)
    br label %if_5_merge
if_5_merge:
    %v15 = phi i64 [ %v7, %if_5_then ], [ %v12, %if_5_else ]
    ret i64 %v15
}

define i64 @prog__psr_peek_line(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = call i64 @prog__psr_skip_newlines(ptr %v0, i64 %v1)
    %v3 = call i64 @orion_list_len(ptr %v0)
    %v4.b = icmp sge i64 %v2, %v3
    %v4 = zext i1 %v4.b to i64
    %v5.cb = icmp ne i64 %v4, 0
    br i1 %v5.cb, label %if_5_then, label %if_5_else
if_5_then:
    %v7 = add i64 0, 0
    br label %if_5_merge
if_5_else:
    %v10.i = call i64 @orion_list_at(ptr %v0, i64 %v2)
    %v10 = inttoptr i64 %v10.i to ptr
    %v11 = getelementptr i8, ptr @.str_120, i64 16
    %v12 = call i64 @orion_map_get(ptr %v10, ptr %v11)
    br label %if_5_merge
if_5_merge:
    %v15 = phi i64 [ %v7, %if_5_then ], [ %v12, %if_5_else ]
    ret i64 %v15
}

define i64 @prog__psr_match_bracket(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = call i64 @orion_list_len(ptr %v0)
    %v3 = add i64 0, 0
    %v4 = alloca i64, align 8
    store i64 %v3, ptr %v4
    %v5 = add i64 0, 0
    %v6 = add i64 0, 0
    %v7 = add i64 0, 1
    %v8 = sub i64 %v6, %v7
    %v9 = alloca i64, align 8
    store i64 %v8, ptr %v9
    %v10 = add i64 0, 0
    %v11 = alloca i64, align 8
    store i64 %v1, ptr %v11
    %v12 = add i64 0, 0
    br label %loop_13_header
loop_13_header:
    %v15 = load i64, ptr %v11
    %v16.b = icmp sge i64 %v15, %v2
    %v16 = zext i1 %v16.b to i64
    %v17.cb = icmp ne i64 %v16, 0
    br i1 %v17.cb, label %if_17_then, label %if_17_else
if_17_then:
    br label %if_17_merge
if_17_else:
    %v21 = load i64, ptr %v9
    %v22 = add i64 0, 0
    %v23.b = icmp sge i64 %v21, %v22
    %v23 = zext i1 %v23.b to i64
    br label %if_17_merge
if_17_merge:
    %v26 = phi i64 [ %v16, %if_17_then ], [ %v23, %if_17_else ]
    %v27.cb = icmp ne i64 %v26, 0
    br i1 %v27.cb, label %if_27_then, label %if_27_else
if_27_then:
    br label %loop_13_end
if_27_else:
    br label %if_27_merge
if_27_merge:
    %v33 = load i64, ptr %v11
    %v34 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v33)
    %v35 = load i64, ptr %v11
    %v36 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v35)
    %v37 = getelementptr i8, ptr @.str_249, i64 16
    %v38.e = call i64 @orion_text_eq(ptr %v34, ptr %v37)
    %v38 = add i64 %v38.e, 0
    %v39.cb = icmp ne i64 %v38, 0
    br i1 %v39.cb, label %if_39_then, label %if_39_else
if_39_then:
    br label %loop_13_end
if_39_else:
    br label %if_39_merge
if_39_merge:
    %v45 = getelementptr i8, ptr @.str_248, i64 16
    %v46.e = call i64 @orion_text_eq(ptr %v34, ptr %v45)
    %v46 = add i64 %v46.e, 0
    %v47.cb = icmp ne i64 %v46, 0
    br i1 %v47.cb, label %if_47_then, label %if_47_else
if_47_then:
    %v49 = getelementptr i8, ptr @.str_238, i64 16
    %v50.e = call i64 @orion_text_eq(ptr %v36, ptr %v49)
    %v50 = add i64 %v50.e, 0
    br label %if_47_merge
if_47_else:
    %v53 = add i64 0, 0
    br label %if_47_merge
if_47_merge:
    %v56 = phi i64 [ %v50, %if_47_then ], [ %v53, %if_47_else ]
    %v57.cb = icmp ne i64 %v56, 0
    br i1 %v57.cb, label %if_57_then, label %if_57_else
if_57_then:
    %v59 = load i64, ptr %v4
    %v60 = add i64 0, 1
    %v61 = add i64 %v59, %v60
    store i64 %v61, ptr %v4
    %v62 = add i64 0, 0
    br label %if_57_merge
if_57_else:
    br label %if_57_merge
if_57_merge:
    %v67 = getelementptr i8, ptr @.str_248, i64 16
    %v68.e = call i64 @orion_text_eq(ptr %v34, ptr %v67)
    %v68 = add i64 %v68.e, 0
    %v69.cb = icmp ne i64 %v68, 0
    br i1 %v69.cb, label %if_69_then, label %if_69_else
if_69_then:
    %v71 = getelementptr i8, ptr @.str_239, i64 16
    %v72.e = call i64 @orion_text_eq(ptr %v36, ptr %v71)
    %v72 = add i64 %v72.e, 0
    br label %if_69_merge
if_69_else:
    %v75 = add i64 0, 0
    br label %if_69_merge
if_69_merge:
    %v78 = phi i64 [ %v72, %if_69_then ], [ %v75, %if_69_else ]
    %v79.cb = icmp ne i64 %v78, 0
    br i1 %v79.cb, label %if_79_then, label %if_79_else
if_79_then:
    %v81 = load i64, ptr %v4
    %v82 = add i64 0, 1
    %v83 = sub i64 %v81, %v82
    store i64 %v83, ptr %v4
    %v84 = add i64 0, 0
    %v85 = load i64, ptr %v4
    %v86 = add i64 0, 0
    %v87.b = icmp eq i64 %v85, %v86
    %v87 = zext i1 %v87.b to i64
    %v88.cb = icmp ne i64 %v87, 0
    br i1 %v88.cb, label %if_88_then, label %if_88_else
if_88_then:
    %v90 = load i64, ptr %v11
    store i64 %v90, ptr %v9
    %v91 = add i64 0, 0
    br label %if_88_merge
if_88_else:
    br label %if_88_merge
if_88_merge:
    br label %if_79_merge
if_79_else:
    br label %if_79_merge
if_79_merge:
    %v100 = load i64, ptr %v11
    %v101 = add i64 0, 1
    %v102 = add i64 %v100, %v101
    store i64 %v102, ptr %v11
    %v103 = add i64 0, 0
    br label %loop_13_header
loop_13_end:
    %v106 = load i64, ptr %v9
    ret i64 %v106
}

define ptr @prog__psr_parse_body_at(ptr %p0, i64 %p1, i64 %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = call i64 @prog__psr_skip_newlines(ptr %v0, i64 %v1)
    %v4 = alloca i64, align 8
    store i64 %v3, ptr %v4
    %v5 = add i64 0, 0
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    %v7 = alloca ptr, align 8
    store ptr %v6, ptr %v7
    %v8 = add i64 0, 0
    br label %loop_9_header
loop_9_header:
    %v11 = load i64, ptr %v4
    %v12 = call i64 @prog__psr_skip_newlines(ptr %v0, i64 %v11)
    store i64 %v12, ptr %v4
    %v13 = add i64 0, 0
    %v14 = load i64, ptr %v4
    %v15 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v14)
    %v16 = load i64, ptr %v4
    %v17 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v16)
    %v18 = load i64, ptr %v4
    %v19 = call i64 @orion_list_len(ptr %v0)
    %v20.b = icmp sge i64 %v18, %v19
    %v20 = zext i1 %v20.b to i64
    %v21.cb = icmp ne i64 %v20, 0
    br i1 %v21.cb, label %if_21_then, label %if_21_else
if_21_then:
    %v23 = add i64 0, 0
    br label %if_21_merge
if_21_else:
    %v26 = load i64, ptr %v4
    %v27.i = call i64 @orion_list_at(ptr %v0, i64 %v26)
    %v27 = inttoptr i64 %v27.i to ptr
    %v28 = getelementptr i8, ptr @.str_121, i64 16
    %v29 = call i64 @orion_map_get(ptr %v27, ptr %v28)
    br label %if_21_merge
if_21_merge:
    %v32 = phi i64 [ %v23, %if_21_then ], [ %v29, %if_21_else ]
    %v33 = getelementptr i8, ptr @.str_249, i64 16
    %v34.e = call i64 @orion_text_eq(ptr %v15, ptr %v33)
    %v34 = add i64 %v34.e, 0
    %v35 = getelementptr i8, ptr @.str_125, i64 16
    %v36.e = call i64 @orion_text_eq(ptr %v17, ptr %v35)
    %v36 = add i64 %v36.e, 0
    %v37.cb = icmp ne i64 %v36, 0
    br i1 %v37.cb, label %if_37_then, label %if_37_else
if_37_then:
    %v39 = load i64, ptr %v4
    %v40 = add i64 0, 1
    %v41 = add i64 %v39, %v40
    %v42 = call ptr @prog__psr_peek_kind(ptr %v0, i64 %v41)
    %v43 = getelementptr i8, ptr @.str_248, i64 16
    %v44.e = call i64 @orion_text_eq(ptr %v42, ptr %v43)
    %v44 = add i64 %v44.e, 0
    br label %if_37_merge
if_37_else:
    %v47 = add i64 0, 0
    br label %if_37_merge
if_37_merge:
    %v50 = phi i64 [ %v44, %if_37_then ], [ %v47, %if_37_else ]
    %v51.cb = icmp ne i64 %v50, 0
    br i1 %v51.cb, label %if_51_then, label %if_51_else
if_51_then:
    %v53 = load i64, ptr %v4
    %v54 = add i64 0, 1
    %v55 = add i64 %v53, %v54
    %v56 = call ptr @prog__psr_peek_value(ptr %v0, i64 %v55)
    %v57 = getelementptr i8, ptr @.str_233, i64 16
    %v58.e = call i64 @orion_text_eq(ptr %v56, ptr %v57)
    %v58 = add i64 %v58.e, 0
    br label %if_51_merge
if_51_else:
    %v61 = add i64 0, 0
    br label %if_51_merge
if_51_merge:
    %v64 = phi i64 [ %v58, %if_51_then ], [ %v61, %if_51_else ]
    %v65 = getelementptr i8, ptr @.str_340, i64 16
    %v66.e = call i64 @orion_text_eq(ptr %v17, ptr %v65)
    %v66 = add i64 %v66.e, 0
    br label %loop_9_header
loop_9_end:
    ret ptr null
}

define i64 @orion_main() {
entry:
    %v0 = add i64 0, 0
    ret i64 %v0
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
