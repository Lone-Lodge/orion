; orion_emit_llvm output
target datalayout = "e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc19.44.35209"
declare i32 @printf(ptr, ...)
declare i32 @puts(ptr)
declare ptr @malloc(i64)
declare ptr @orion_f64_literal_hex(ptr)
declare i64 @orion_par_run(ptr, i64)
declare i64 @orion_trace_enter(ptr)
declare i64 @orion_trail_note_trap()
declare i64 @orion_breakpoint(ptr)
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
  %_1 = call ptr @memcpy(ptr %buf, ptr %a, i64 %la)
  %tail = getelementptr i8, ptr %buf, i64 %la
  %_2 = call ptr @memcpy(ptr %tail, ptr %b, i64 %lb)
  ret ptr %buf
}

define ptr @orion_int_to_text(i64 %n) {
entry:
  %scratch = alloca [24 x i8]
  %neg = icmp slt i64 %n, 0
  %flip = sub i64 0, %n
  %mag = select i1 %neg, i64 %flip, i64 %n
  br label %dig
dig:
  %w = phi i64 [ %mag, %entry ], [ %q, %dig ]
  %pos = phi i64 [ 24, %entry ], [ %pos1, %dig ]
  %pos1 = add i64 %pos, -1
  %q = udiv i64 %w, 10
  %q10 = mul i64 %q, 10
  %rem = sub i64 %w, %q10
  %chr = add i64 %rem, 48
  %byte = trunc i64 %chr to i8
  %slot = getelementptr i8, ptr %scratch, i64 %pos1
  store i8 %byte, ptr %slot
  %more = icmp ne i64 %q, 0
  br i1 %more, label %dig, label %done
done:
  %ndig = sub i64 24, %pos1
  %sign = zext i1 %neg to i64
  %len = add i64 %ndig, %sign
  %buf = call ptr @orion_text_alloc(i64 %len)
  %src = getelementptr i8, ptr %scratch, i64 %pos1
  %dst = getelementptr i8, ptr %buf, i64 %sign
  %_c = call ptr @memcpy(ptr %dst, ptr %src, i64 %ndig)
  br i1 %neg, label %minus, label %fin
minus:
  store i8 45, ptr %buf
  br label %fin
fin:
  ret ptr %buf
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
  %_att = call i64 @orion_trail_note_trap()
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
  %_rt = call i64 @orion_trail_note_trap()
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
  %_et = call i64 @orion_trail_note_trap()
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


@.str_0 = private unnamed_addr constant [18 x i8] c"\05\C2\0A\00\00\00\00\00\01\00\00\00\00\00\00\00v\00", align 8
@.str_1 = private unnamed_addr constant [18 x i8] c"\F8\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00i\00", align 8
@.str_2 = private unnamed_addr constant [17 x i8] c"\05\15\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00", align 8
@.str_3 = private unnamed_addr constant [33 x i8] c"\D0\3B\2F\29\00\00\00\00\10\00\00\00\00\00\00\000123456789abcdef\00", align 8
@.str_4 = private unnamed_addr constant [21 x i8] c"\AC\5C\D3\38\00\00\00\00\04\00\00\00\00\00\00\00null\00", align 8
@.str_5 = private unnamed_addr constant [22 x i8] c"\04\66\48\1D\00\00\00\00\05\00\00\00\00\00\00\00false\00", align 8
@.str_6 = private unnamed_addr constant [21 x i8] c"\C7\69\A0\39\00\00\00\00\04\00\00\00\00\00\00\00true\00", align 8
@.str_7 = private unnamed_addr constant [18 x i8] c"\EA\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00[\00", align 8
@.str_8 = private unnamed_addr constant [18 x i8] c"\BB\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00,\00", align 8
@.str_9 = private unnamed_addr constant [18 x i8] c"\EC\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00]\00", align 8
@.str_10 = private unnamed_addr constant [18 x i8] c"\C9\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00:\00", align 8
@.str_11 = private unnamed_addr constant [24 x i8] c"\DA\05\23\04\00\00\00\00\07\00\00\00\00\00\00\00[1,2,3]\00", align 8
@.str_12 = private unnamed_addr constant [19 x i8] c"\CE\41\81\05\00\00\00\00\02\00\00\00\00\00\00\00hi\00", align 8
@.str_13 = private unnamed_addr constant [21 x i8] c"\60\E9\A0\2E\00\00\00\00\04\00\00\00\00\00\00\00\22hi\22\00", align 8
@.str_14 = private unnamed_addr constant [20 x i8] c"\36\5E\E1\05\00\00\00\00\03\00\00\00\00\00\00\00age\00", align 8
@.str_15 = private unnamed_addr constant [21 x i8] c"\74\20\CE\38\00\00\00\00\04\00\00\00\00\00\00\00name\00", align 8
@.str_16 = private unnamed_addr constant [19 x i8] c"\7A\32\81\05\00\00\00\00\02\00\00\00\00\00\00\00Jo\00", align 8

define i64 @json__jsn_ws(ptr %p0, i64 %p1) {
entry:
    %v3 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = call i64 @orion_list_len(ptr %v0)
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
    %v17 = add i64 0, 32
    %v18.b = icmp eq i64 %v16, %v17
    %v18 = zext i1 %v18.b to i64
    %v19.cb = icmp ne i64 %v18, 0
    br i1 %v19.cb, label %if_19_then, label %if_19_else
if_19_then:
    br label %if_19_merge
if_19_else:
    %v23 = add i64 0, 9
    %v24.b = icmp eq i64 %v16, %v23
    %v24 = zext i1 %v24.b to i64
    br label %if_19_merge
if_19_merge:
    %v27 = phi i64 [ %v18, %if_19_then ], [ %v24, %if_19_else ]
    %v28.cb = icmp ne i64 %v27, 0
    br i1 %v28.cb, label %if_28_then, label %if_28_else
if_28_then:
    br label %if_28_merge
if_28_else:
    %v32 = add i64 0, 10
    %v33.b = icmp eq i64 %v16, %v32
    %v33 = zext i1 %v33.b to i64
    br label %if_28_merge
if_28_merge:
    %v36 = phi i64 [ %v27, %if_28_then ], [ %v33, %if_28_else ]
    %v37.cb = icmp ne i64 %v36, 0
    br i1 %v37.cb, label %if_37_then, label %if_37_else
if_37_then:
    br label %if_37_merge
if_37_else:
    %v41 = add i64 0, 13
    %v42.b = icmp eq i64 %v16, %v41
    %v42 = zext i1 %v42.b to i64
    br label %if_37_merge
if_37_merge:
    %v45 = phi i64 [ %v36, %if_37_then ], [ %v42, %if_37_else ]
    %v46.cb = icmp ne i64 %v45, 0
    br i1 %v46.cb, label %if_46_then, label %if_46_else
if_46_then:
    %v48 = load i64, ptr %v3
    %v49 = add i64 0, 1
    %v50 = add i64 %v48, %v49
    store i64 %v50, ptr %v3
    %v51 = add i64 0, 0
    br label %if_46_merge
if_46_else:
    br label %loop_5_end
if_46_merge:
    br label %loop_5_header
loop_5_end:
    %v58 = load i64, ptr %v3
    ret i64 %v58
}

define i64 @json__jsn_str_end(ptr %p0, i64 %p1) {
entry:
    %v5 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = call i64 @orion_list_len(ptr %v0)
    %v3 = add i64 0, 1
    %v4 = add i64 %v1, %v3
    store i64 %v4, ptr %v5
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
    %v19 = add i64 0, 92
    %v20.b = icmp eq i64 %v18, %v19
    %v20 = zext i1 %v20.b to i64
    %v21.cb = icmp ne i64 %v20, 0
    br i1 %v21.cb, label %if_21_then, label %if_21_else
if_21_then:
    %v23 = load i64, ptr %v5
    %v24 = add i64 0, 2
    %v25 = add i64 %v23, %v24
    store i64 %v25, ptr %v5
    %v26 = add i64 0, 0
    br label %if_21_merge
if_21_else:
    %v29 = add i64 0, 34
    %v30.b = icmp eq i64 %v18, %v29
    %v30 = zext i1 %v30.b to i64
    %v31.cb = icmp ne i64 %v30, 0
    br i1 %v31.cb, label %if_31_then, label %if_31_else
if_31_then:
    %v33 = load i64, ptr %v5
    %v34 = add i64 0, 1
    %v35 = add i64 %v33, %v34
    store i64 %v35, ptr %v5
    %v36 = add i64 0, 0
    br label %loop_7_end
if_31_else:
    br label %if_31_merge
if_31_merge:
    %v41 = load i64, ptr %v5
    %v42 = add i64 0, 1
    %v43 = add i64 %v41, %v42
    store i64 %v43, ptr %v5
    %v44 = add i64 0, 0
    br label %if_21_merge
if_21_merge:
    %v47 = phi i64 [ %v26, %if_21_then ], [ %v44, %if_31_merge ]
    br label %loop_7_header
loop_7_end:
    %v50 = load i64, ptr %v5
    ret i64 %v50
}

define i64 @json__jsn_has_escape(ptr %p0, i64 %p1, i64 %p2) {
entry:
    %v4 = alloca i64, align 8
    %v6 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = add i64 0, 0
    store i64 %v3, ptr %v4
    %v5 = add i64 0, 0
    store i64 %v1, ptr %v6
    %v7 = add i64 0, 0
    br label %loop_8_header
loop_8_header:
    %v10 = load i64, ptr %v6
    %v11.b = icmp sge i64 %v10, %v2
    %v11 = zext i1 %v11.b to i64
    %v12.cb = icmp ne i64 %v11, 0
    br i1 %v12.cb, label %if_12_then, label %if_12_else
if_12_then:
    br label %loop_8_end
if_12_else:
    br label %if_12_merge
if_12_merge:
    %v18 = load i64, ptr %v6
    %v19 = call i64 @orion_list_at(ptr %v0, i64 %v18)
    %v20 = add i64 0, 92
    %v21.b = icmp eq i64 %v19, %v20
    %v21 = zext i1 %v21.b to i64
    %v22.cb = icmp ne i64 %v21, 0
    br i1 %v22.cb, label %if_22_then, label %if_22_else
if_22_then:
    %v24 = add i64 0, 1
    store i64 %v24, ptr %v4
    %v25 = add i64 0, 0
    br label %loop_8_end
if_22_else:
    br label %if_22_merge
if_22_merge:
    %v30 = load i64, ptr %v6
    %v31 = add i64 0, 1
    %v32 = add i64 %v30, %v31
    store i64 %v32, ptr %v6
    %v33 = add i64 0, 0
    br label %loop_8_header
loop_8_end:
    %v36 = load i64, ptr %v4
    ret i64 %v36
}

define i64 @json__jsn_hex_val(i64 %p0) {
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
    %v13.cb = icmp ne i64 %v12, 0
    br i1 %v13.cb, label %if_13_then, label %if_13_else
if_13_then:
    %v15 = add i64 0, 48
    %v16 = sub i64 %v0, %v15
    br label %if_13_merge
if_13_else:
    %v19 = add i64 0, 97
    %v20.b = icmp sge i64 %v0, %v19
    %v20 = zext i1 %v20.b to i64
    %v21.cb = icmp ne i64 %v20, 0
    br i1 %v21.cb, label %if_21_then, label %if_21_else
if_21_then:
    %v23 = add i64 0, 102
    %v24.b = icmp sle i64 %v0, %v23
    %v24 = zext i1 %v24.b to i64
    br label %if_21_merge
if_21_else:
    %v27 = add i64 0, 0
    br label %if_21_merge
if_21_merge:
    %v30 = phi i64 [ %v24, %if_21_then ], [ %v27, %if_21_else ]
    %v31.cb = icmp ne i64 %v30, 0
    br i1 %v31.cb, label %if_31_then, label %if_31_else
if_31_then:
    %v33 = add i64 0, 87
    %v34 = sub i64 %v0, %v33
    br label %if_31_merge
if_31_else:
    %v37 = add i64 0, 65
    %v38.b = icmp sge i64 %v0, %v37
    %v38 = zext i1 %v38.b to i64
    %v39.cb = icmp ne i64 %v38, 0
    br i1 %v39.cb, label %if_39_then, label %if_39_else
if_39_then:
    %v41 = add i64 0, 70
    %v42.b = icmp sle i64 %v0, %v41
    %v42 = zext i1 %v42.b to i64
    br label %if_39_merge
if_39_else:
    %v45 = add i64 0, 0
    br label %if_39_merge
if_39_merge:
    %v48 = phi i64 [ %v42, %if_39_then ], [ %v45, %if_39_else ]
    %v49.cb = icmp ne i64 %v48, 0
    br i1 %v49.cb, label %if_49_then, label %if_49_else
if_49_then:
    %v51 = add i64 0, 55
    %v52 = sub i64 %v0, %v51
    br label %if_49_merge
if_49_else:
    %v55 = add i64 0, 0
    br label %if_49_merge
if_49_merge:
    %v58 = phi i64 [ %v52, %if_49_then ], [ %v55, %if_49_else ]
    br label %if_31_merge
if_31_merge:
    %v61 = phi i64 [ %v34, %if_31_then ], [ %v58, %if_49_merge ]
    br label %if_13_merge
if_13_merge:
    %v64 = phi i64 [ %v16, %if_13_then ], [ %v61, %if_31_merge ]
    ret i64 %v64
}

define ptr @json__jsn_unescape(ptr %p0, i64 %p1, i64 %p2) {
entry:
    %v8 = alloca ptr, align 8
    %v10 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = add i64 0, %p2
    %v3 = add i64 0, 0
    %v4 = call ptr @orion_list_new(i64 1)
    call void @orion_list_set(ptr %v4, i64 0, i64 %v3)
    %v5 = add i64 0, 0
    %v6 = add i64 0, 0
    %v7 = call ptr @orion_list_slice(ptr %v4, i64 %v5, i64 %v6)
    store ptr %v7, ptr %v8
    %v9 = add i64 0, 0
    store i64 %v1, ptr %v10
    %v11 = add i64 0, 0
    br label %loop_12_header
loop_12_header:
    %v14 = load i64, ptr %v10
    %v15.b = icmp sge i64 %v14, %v2
    %v15 = zext i1 %v15.b to i64
    %v16.cb = icmp ne i64 %v15, 0
    br i1 %v16.cb, label %if_16_then, label %if_16_else
if_16_then:
    br label %loop_12_end
if_16_else:
    br label %if_16_merge
if_16_merge:
    %v22 = load i64, ptr %v10
    %v23 = call i64 @orion_list_at(ptr %v0, i64 %v22)
    %v24 = add i64 0, 92
    %v25.b = icmp ne i64 %v23, %v24
    %v25 = zext i1 %v25.b to i64
    %v26.cb = icmp ne i64 %v25, 0
    br i1 %v26.cb, label %if_26_then, label %if_26_else
if_26_then:
    %v28 = load ptr, ptr %v8
    %v29 = call ptr @orion_list_push_mut(ptr %v28, i64 %v23)
    store ptr %v29, ptr %v8
    %v30 = add i64 0, 0
    %v31 = load i64, ptr %v10
    %v32 = add i64 0, 1
    %v33 = add i64 %v31, %v32
    store i64 %v33, ptr %v10
    %v34 = add i64 0, 0
    br label %if_26_merge
if_26_else:
    %v37 = load i64, ptr %v10
    %v38 = add i64 0, 1
    %v39 = add i64 %v37, %v38
    %v40.b = icmp sge i64 %v39, %v2
    %v40 = zext i1 %v40.b to i64
    %v41.cb = icmp ne i64 %v40, 0
    br i1 %v41.cb, label %if_41_then, label %if_41_else
if_41_then:
    %v43 = load i64, ptr %v10
    %v44 = add i64 0, 1
    %v45 = add i64 %v43, %v44
    store i64 %v45, ptr %v10
    %v46 = add i64 0, 0
    br label %if_41_merge
if_41_else:
    %v49 = load i64, ptr %v10
    %v50 = add i64 0, 1
    %v51 = add i64 %v49, %v50
    %v52 = call i64 @orion_list_at(ptr %v0, i64 %v51)
    %v53 = load i64, ptr %v10
    %v54 = add i64 0, 2
    %v55 = add i64 %v53, %v54
    store i64 %v55, ptr %v10
    %v56 = add i64 0, 0
    %v57 = add i64 0, 110
    %v58.b = icmp eq i64 %v52, %v57
    %v58 = zext i1 %v58.b to i64
    %v59.cb = icmp ne i64 %v58, 0
    br i1 %v59.cb, label %if_59_then, label %if_59_else
if_59_then:
    %v61 = load ptr, ptr %v8
    %v62 = add i64 0, 10
    %v63 = call ptr @orion_list_push_mut(ptr %v61, i64 %v62)
    store ptr %v63, ptr %v8
    %v64 = add i64 0, 0
    br label %if_59_merge
if_59_else:
    br label %if_59_merge
if_59_merge:
    %v69 = add i64 0, 114
    %v70.b = icmp eq i64 %v52, %v69
    %v70 = zext i1 %v70.b to i64
    %v71.cb = icmp ne i64 %v70, 0
    br i1 %v71.cb, label %if_71_then, label %if_71_else
if_71_then:
    %v73 = load ptr, ptr %v8
    %v74 = add i64 0, 13
    %v75 = call ptr @orion_list_push_mut(ptr %v73, i64 %v74)
    store ptr %v75, ptr %v8
    %v76 = add i64 0, 0
    br label %if_71_merge
if_71_else:
    br label %if_71_merge
if_71_merge:
    %v81 = add i64 0, 116
    %v82.b = icmp eq i64 %v52, %v81
    %v82 = zext i1 %v82.b to i64
    %v83.cb = icmp ne i64 %v82, 0
    br i1 %v83.cb, label %if_83_then, label %if_83_else
if_83_then:
    %v85 = load ptr, ptr %v8
    %v86 = add i64 0, 9
    %v87 = call ptr @orion_list_push_mut(ptr %v85, i64 %v86)
    store ptr %v87, ptr %v8
    %v88 = add i64 0, 0
    br label %if_83_merge
if_83_else:
    br label %if_83_merge
if_83_merge:
    %v93 = add i64 0, 98
    %v94.b = icmp eq i64 %v52, %v93
    %v94 = zext i1 %v94.b to i64
    %v95.cb = icmp ne i64 %v94, 0
    br i1 %v95.cb, label %if_95_then, label %if_95_else
if_95_then:
    %v97 = load ptr, ptr %v8
    %v98 = add i64 0, 8
    %v99 = call ptr @orion_list_push_mut(ptr %v97, i64 %v98)
    store ptr %v99, ptr %v8
    %v100 = add i64 0, 0
    br label %if_95_merge
if_95_else:
    br label %if_95_merge
if_95_merge:
    %v105 = add i64 0, 102
    %v106.b = icmp eq i64 %v52, %v105
    %v106 = zext i1 %v106.b to i64
    %v107.cb = icmp ne i64 %v106, 0
    br i1 %v107.cb, label %if_107_then, label %if_107_else
if_107_then:
    %v109 = load ptr, ptr %v8
    %v110 = add i64 0, 12
    %v111 = call ptr @orion_list_push_mut(ptr %v109, i64 %v110)
    store ptr %v111, ptr %v8
    %v112 = add i64 0, 0
    br label %if_107_merge
if_107_else:
    br label %if_107_merge
if_107_merge:
    %v117 = add i64 0, 34
    %v118.b = icmp eq i64 %v52, %v117
    %v118 = zext i1 %v118.b to i64
    %v119.cb = icmp ne i64 %v118, 0
    br i1 %v119.cb, label %if_119_then, label %if_119_else
if_119_then:
    %v121 = load ptr, ptr %v8
    %v122 = add i64 0, 34
    %v123 = call ptr @orion_list_push_mut(ptr %v121, i64 %v122)
    store ptr %v123, ptr %v8
    %v124 = add i64 0, 0
    br label %if_119_merge
if_119_else:
    br label %if_119_merge
if_119_merge:
    %v129 = add i64 0, 92
    %v130.b = icmp eq i64 %v52, %v129
    %v130 = zext i1 %v130.b to i64
    %v131.cb = icmp ne i64 %v130, 0
    br i1 %v131.cb, label %if_131_then, label %if_131_else
if_131_then:
    %v133 = load ptr, ptr %v8
    %v134 = add i64 0, 92
    %v135 = call ptr @orion_list_push_mut(ptr %v133, i64 %v134)
    store ptr %v135, ptr %v8
    %v136 = add i64 0, 0
    br label %if_131_merge
if_131_else:
    br label %if_131_merge
if_131_merge:
    %v141 = add i64 0, 47
    %v142.b = icmp eq i64 %v52, %v141
    %v142 = zext i1 %v142.b to i64
    %v143.cb = icmp ne i64 %v142, 0
    br i1 %v143.cb, label %if_143_then, label %if_143_else
if_143_then:
    %v145 = load ptr, ptr %v8
    %v146 = add i64 0, 47
    %v147 = call ptr @orion_list_push_mut(ptr %v145, i64 %v146)
    store ptr %v147, ptr %v8
    %v148 = add i64 0, 0
    br label %if_143_merge
if_143_else:
    br label %if_143_merge
if_143_merge:
    %v153 = add i64 0, 117
    %v154.b = icmp eq i64 %v52, %v153
    %v154 = zext i1 %v154.b to i64
    %v155.cb = icmp ne i64 %v154, 0
    br i1 %v155.cb, label %if_155_then, label %if_155_else
if_155_then:
    %v157 = load i64, ptr %v10
    %v158 = add i64 0, 3
    %v159 = add i64 %v157, %v158
    %v160.b = icmp slt i64 %v159, %v2
    %v160 = zext i1 %v160.b to i64
    %v161.cb = icmp ne i64 %v160, 0
    br i1 %v161.cb, label %if_161_then, label %if_161_else
if_161_then:
    %v163 = load i64, ptr %v10
    %v164 = call i64 @orion_list_at(ptr %v0, i64 %v163)
    %v165 = call i64 @json__jsn_hex_val(i64 %v164)
    %v166 = add i64 0, 4096
    %v167 = mul i64 %v165, %v166
    %v168 = load i64, ptr %v10
    %v169 = add i64 0, 1
    %v170 = add i64 %v168, %v169
    %v171 = call i64 @orion_list_at(ptr %v0, i64 %v170)
    %v172 = call i64 @json__jsn_hex_val(i64 %v171)
    %v173 = add i64 0, 256
    %v174 = mul i64 %v172, %v173
    %v175 = add i64 %v167, %v174
    %v176 = load i64, ptr %v10
    %v177 = add i64 0, 2
    %v178 = add i64 %v176, %v177
    %v179 = call i64 @orion_list_at(ptr %v0, i64 %v178)
    %v180 = call i64 @json__jsn_hex_val(i64 %v179)
    %v181 = add i64 0, 16
    %v182 = mul i64 %v180, %v181
    %v183 = add i64 %v175, %v182
    %v184 = load i64, ptr %v10
    %v185 = add i64 0, 3
    %v186 = add i64 %v184, %v185
    %v187 = call i64 @orion_list_at(ptr %v0, i64 %v186)
    %v188 = call i64 @json__jsn_hex_val(i64 %v187)
    %v189 = add i64 %v183, %v188
    %v190 = load i64, ptr %v10
    %v191 = add i64 0, 4
    %v192 = add i64 %v190, %v191
    store i64 %v192, ptr %v10
    %v193 = add i64 0, 0
    %v194 = add i64 0, 128
    %v195.b = icmp slt i64 %v189, %v194
    %v195 = zext i1 %v195.b to i64
    %v196.cb = icmp ne i64 %v195, 0
    br i1 %v196.cb, label %if_196_then, label %if_196_else
if_196_then:
    %v198 = load ptr, ptr %v8
    %v199 = call ptr @orion_list_push_mut(ptr %v198, i64 %v189)
    store ptr %v199, ptr %v8
    %v200 = add i64 0, 0
    br label %if_196_merge
if_196_else:
    %v203 = add i64 0, 2048
    %v204.b = icmp slt i64 %v189, %v203
    %v204 = zext i1 %v204.b to i64
    %v205.cb = icmp ne i64 %v204, 0
    br i1 %v205.cb, label %if_205_then, label %if_205_else
if_205_then:
    %v207 = load ptr, ptr %v8
    %v208 = add i64 0, 192
    %v209 = add i64 0, 64
    %v210 = call i64 @orion_idiv(i64 %v189, i64 %v209)
    %v211 = add i64 %v208, %v210
    %v212 = call ptr @orion_list_push_mut(ptr %v207, i64 %v211)
    store ptr %v212, ptr %v8
    %v213 = add i64 0, 0
    %v214 = load ptr, ptr %v8
    %v215 = add i64 0, 128
    %v216 = add i64 %v215, %v189
    %v217 = add i64 0, 64
    %v218 = call i64 @orion_idiv(i64 %v189, i64 %v217)
    %v219 = add i64 0, 64
    %v220 = mul i64 %v218, %v219
    %v221 = sub i64 %v216, %v220
    %v222 = call ptr @orion_list_push_mut(ptr %v214, i64 %v221)
    store ptr %v222, ptr %v8
    %v223 = add i64 0, 0
    br label %if_205_merge
if_205_else:
    %v226 = add i64 0, 4096
    %v227 = call i64 @orion_idiv(i64 %v189, i64 %v226)
    %v228 = add i64 0, 4096
    %v229 = mul i64 %v227, %v228
    %v230 = sub i64 %v189, %v229
    %v231 = add i64 0, 64
    %v232 = call i64 @orion_idiv(i64 %v230, i64 %v231)
    %v233 = add i64 0, 4096
    %v234 = mul i64 %v227, %v233
    %v235 = sub i64 %v189, %v234
    %v236 = add i64 0, 64
    %v237 = mul i64 %v232, %v236
    %v238 = sub i64 %v235, %v237
    %v239 = load ptr, ptr %v8
    %v240 = add i64 0, 224
    %v241 = add i64 %v240, %v227
    %v242 = call ptr @orion_list_push_mut(ptr %v239, i64 %v241)
    store ptr %v242, ptr %v8
    %v243 = add i64 0, 0
    %v244 = load ptr, ptr %v8
    %v245 = add i64 0, 128
    %v246 = add i64 %v245, %v232
    %v247 = call ptr @orion_list_push_mut(ptr %v244, i64 %v246)
    store ptr %v247, ptr %v8
    %v248 = add i64 0, 0
    %v249 = load ptr, ptr %v8
    %v250 = add i64 0, 128
    %v251 = add i64 %v250, %v238
    %v252 = call ptr @orion_list_push_mut(ptr %v249, i64 %v251)
    store ptr %v252, ptr %v8
    %v253 = add i64 0, 0
    br label %if_205_merge
if_205_merge:
    %v256 = phi i64 [ %v223, %if_205_then ], [ %v253, %if_205_else ]
    br label %if_196_merge
if_196_merge:
    %v259 = phi i64 [ %v200, %if_196_then ], [ %v256, %if_205_merge ]
    br label %if_161_merge
if_161_else:
    br label %if_161_merge
if_161_merge:
    br label %if_155_merge
if_155_else:
    br label %if_155_merge
if_155_merge:
    br label %if_41_merge
if_41_merge:
    br label %if_26_merge
if_26_merge:
    br label %loop_12_header
loop_12_end:
    %v274 = load ptr, ptr %v8
    %v275 = call ptr @orion_bytes_to_text(ptr %v274)
    ret ptr %v275
}

define ptr @json__jsn_value(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = call i64 @json__jsn_ws(ptr %v0, i64 %v1)
    %v3 = call i64 @orion_list_len(ptr %v0)
    %v4.b = icmp sge i64 %v2, %v3
    %v4 = zext i1 %v4.b to i64
    %v5.cb = icmp ne i64 %v4, 0
    br i1 %v5.cb, label %if_5_then, label %if_5_else
if_5_then:
    %v7 = getelementptr i8, ptr @.str_0, i64 16
    %v8 = add i64 0, 0
    %v9 = getelementptr i8, ptr @.str_1, i64 16
    %v10 = call ptr @orion_map_new(i64 2)
    call void @orion_map_set(ptr %v10, ptr %v7, i64 %v8)
    call void @orion_map_set(ptr %v10, ptr %v9, i64 %v2)
    br label %if_5_merge
if_5_else:
    %v13 = call i64 @orion_list_at(ptr %v0, i64 %v2)
    %v14 = add i64 0, 123
    %v15.b = icmp eq i64 %v13, %v14
    %v15 = zext i1 %v15.b to i64
    %v16.cb = icmp ne i64 %v15, 0
    br i1 %v16.cb, label %if_16_then, label %if_16_else
if_16_then:
    %v18 = call ptr @json__jsn_object(ptr %v0, i64 %v2)
    br label %if_16_merge
if_16_else:
    %v21 = add i64 0, 91
    %v22.b = icmp eq i64 %v13, %v21
    %v22 = zext i1 %v22.b to i64
    %v23.cb = icmp ne i64 %v22, 0
    br i1 %v23.cb, label %if_23_then, label %if_23_else
if_23_then:
    %v25 = call ptr @json__jsn_array(ptr %v0, i64 %v2)
    br label %if_23_merge
if_23_else:
    %v28 = add i64 0, 34
    %v29.b = icmp eq i64 %v13, %v28
    %v29 = zext i1 %v29.b to i64
    %v30.cb = icmp ne i64 %v29, 0
    br i1 %v30.cb, label %if_30_then, label %if_30_else
if_30_then:
    %v32 = call i64 @json__jsn_str_end(ptr %v0, i64 %v2)
    %v33 = add i64 0, 1
    %v34 = add i64 %v2, %v33
    %v35 = add i64 0, 1
    %v36 = sub i64 %v32, %v35
    %v37 = call i64 @json__jsn_has_escape(ptr %v0, i64 %v34, i64 %v36)
    %v38.cb = icmp ne i64 %v37, 0
    br i1 %v38.cb, label %if_38_then, label %if_38_else
if_38_then:
    %v40 = call ptr @json__jsn_unescape(ptr %v0, i64 %v34, i64 %v36)
    br label %if_38_merge
if_38_else:
    %v43 = call ptr @orion_bytes_slice(ptr %v0, i64 %v34, i64 %v36)
    %v44 = call ptr @orion_bytes_to_text(ptr %v43)
    br label %if_38_merge
if_38_merge:
    %v47 = phi ptr [ %v40, %if_38_then ], [ %v44, %if_38_else ]
    %v48 = getelementptr i8, ptr @.str_0, i64 16
    %v49 = getelementptr i8, ptr @.str_1, i64 16
    %v50 = call ptr @orion_map_new(i64 2)
    %v50.p0 = ptrtoint ptr %v47 to i64
    call void @orion_map_set(ptr %v50, ptr %v48, i64 %v50.p0)
    call void @orion_map_set(ptr %v50, ptr %v49, i64 %v32)
    br label %if_30_merge
if_30_else:
    %v53 = add i64 0, 116
    %v54.b = icmp eq i64 %v13, %v53
    %v54 = zext i1 %v54.b to i64
    %v55.cb = icmp ne i64 %v54, 0
    br i1 %v55.cb, label %if_55_then, label %if_55_else
if_55_then:
    %v57 = getelementptr i8, ptr @.str_0, i64 16
    %v58 = add i64 0, 1
    %v59 = getelementptr i8, ptr @.str_1, i64 16
    %v60 = add i64 0, 4
    %v61 = add i64 %v2, %v60
    %v62 = call ptr @orion_map_new(i64 2)
    call void @orion_map_set(ptr %v62, ptr %v57, i64 %v58)
    call void @orion_map_set(ptr %v62, ptr %v59, i64 %v61)
    br label %if_55_merge
if_55_else:
    %v65 = add i64 0, 102
    %v66.b = icmp eq i64 %v13, %v65
    %v66 = zext i1 %v66.b to i64
    %v67.cb = icmp ne i64 %v66, 0
    br i1 %v67.cb, label %if_67_then, label %if_67_else
if_67_then:
    %v69 = getelementptr i8, ptr @.str_0, i64 16
    %v70 = add i64 0, 0
    %v71 = getelementptr i8, ptr @.str_1, i64 16
    %v72 = add i64 0, 5
    %v73 = add i64 %v2, %v72
    %v74 = call ptr @orion_map_new(i64 2)
    call void @orion_map_set(ptr %v74, ptr %v69, i64 %v70)
    call void @orion_map_set(ptr %v74, ptr %v71, i64 %v73)
    br label %if_67_merge
if_67_else:
    %v77 = add i64 0, 110
    %v78.b = icmp eq i64 %v13, %v77
    %v78 = zext i1 %v78.b to i64
    %v79.cb = icmp ne i64 %v78, 0
    br i1 %v79.cb, label %if_79_then, label %if_79_else
if_79_then:
    %v81 = getelementptr i8, ptr @.str_0, i64 16
    %v82 = add i64 0, 0
    %v83 = getelementptr i8, ptr @.str_1, i64 16
    %v84 = add i64 0, 4
    %v85 = add i64 %v2, %v84
    %v86 = call ptr @orion_map_new(i64 2)
    call void @orion_map_set(ptr %v86, ptr %v81, i64 %v82)
    call void @orion_map_set(ptr %v86, ptr %v83, i64 %v85)
    br label %if_79_merge
if_79_else:
    %v89 = call ptr @json__jsn_number(ptr %v0, i64 %v2)
    br label %if_79_merge
if_79_merge:
    %v92 = phi ptr [ %v86, %if_79_then ], [ %v89, %if_79_else ]
    br label %if_67_merge
if_67_merge:
    %v95 = phi ptr [ %v74, %if_67_then ], [ %v92, %if_79_merge ]
    br label %if_55_merge
if_55_merge:
    %v98 = phi ptr [ %v62, %if_55_then ], [ %v95, %if_67_merge ]
    br label %if_30_merge
if_30_merge:
    %v101 = phi ptr [ %v50, %if_38_merge ], [ %v98, %if_55_merge ]
    br label %if_23_merge
if_23_merge:
    %v104 = phi ptr [ %v25, %if_23_then ], [ %v101, %if_30_merge ]
    br label %if_16_merge
if_16_merge:
    %v107 = phi ptr [ %v18, %if_16_then ], [ %v104, %if_23_merge ]
    br label %if_5_merge
if_5_merge:
    %v110 = phi ptr [ %v10, %if_5_then ], [ %v107, %if_16_merge ]
    ret ptr %v110
}

define ptr @json__jsn_number(ptr %p0, i64 %p1) {
entry:
    %v3 = alloca i64, align 8
    %v6 = alloca i64, align 8
    %v25 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = call i64 @orion_list_len(ptr %v0)
    store i64 %v1, ptr %v3
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    store i64 %v5, ptr %v6
    %v7 = add i64 0, 0
    %v8 = load i64, ptr %v3
    %v9 = call i64 @orion_list_at(ptr %v0, i64 %v8)
    %v10 = add i64 0, 45
    %v11.b = icmp eq i64 %v9, %v10
    %v11 = zext i1 %v11.b to i64
    %v12.cb = icmp ne i64 %v11, 0
    br i1 %v12.cb, label %if_12_then, label %if_12_else
if_12_then:
    %v14 = add i64 0, 1
    store i64 %v14, ptr %v6
    %v15 = add i64 0, 0
    %v16 = load i64, ptr %v3
    %v17 = add i64 0, 1
    %v18 = add i64 %v16, %v17
    store i64 %v18, ptr %v3
    %v19 = add i64 0, 0
    br label %if_12_merge
if_12_else:
    br label %if_12_merge
if_12_merge:
    %v24 = add i64 0, 0
    store i64 %v24, ptr %v25
    %v26 = add i64 0, 0
    br label %loop_27_header
loop_27_header:
    %v29 = load i64, ptr %v3
    %v30.b = icmp sge i64 %v29, %v2
    %v30 = zext i1 %v30.b to i64
    %v31.cb = icmp ne i64 %v30, 0
    br i1 %v31.cb, label %if_31_then, label %if_31_else
if_31_then:
    br label %loop_27_end
if_31_else:
    br label %if_31_merge
if_31_merge:
    %v37 = load i64, ptr %v3
    %v38 = call i64 @orion_list_at(ptr %v0, i64 %v37)
    %v39 = add i64 0, 48
    %v40.b = icmp sge i64 %v38, %v39
    %v40 = zext i1 %v40.b to i64
    %v41.cb = icmp ne i64 %v40, 0
    br i1 %v41.cb, label %if_41_then, label %if_41_else
if_41_then:
    %v43 = add i64 0, 57
    %v44.b = icmp sle i64 %v38, %v43
    %v44 = zext i1 %v44.b to i64
    br label %if_41_merge
if_41_else:
    %v47 = add i64 0, 0
    br label %if_41_merge
if_41_merge:
    %v50 = phi i64 [ %v44, %if_41_then ], [ %v47, %if_41_else ]
    %v51.cb = icmp ne i64 %v50, 0
    br i1 %v51.cb, label %if_51_then, label %if_51_else
if_51_then:
    %v53 = load i64, ptr %v25
    %v54 = add i64 0, 10
    %v55 = mul i64 %v53, %v54
    %v56 = add i64 0, 48
    %v57 = sub i64 %v38, %v56
    %v58 = add i64 %v55, %v57
    store i64 %v58, ptr %v25
    %v59 = add i64 0, 0
    %v60 = load i64, ptr %v3
    %v61 = add i64 0, 1
    %v62 = add i64 %v60, %v61
    store i64 %v62, ptr %v3
    %v63 = add i64 0, 0
    br label %if_51_merge
if_51_else:
    br label %loop_27_end
if_51_merge:
    br label %loop_27_header
loop_27_end:
    br label %loop_70_header
loop_70_header:
    %v72 = load i64, ptr %v3
    %v73.b = icmp sge i64 %v72, %v2
    %v73 = zext i1 %v73.b to i64
    %v74.cb = icmp ne i64 %v73, 0
    br i1 %v74.cb, label %if_74_then, label %if_74_else
if_74_then:
    br label %loop_70_end
if_74_else:
    br label %if_74_merge
if_74_merge:
    %v80 = load i64, ptr %v3
    %v81 = call i64 @orion_list_at(ptr %v0, i64 %v80)
    %v82 = add i64 0, 46
    %v83.b = icmp eq i64 %v81, %v82
    %v83 = zext i1 %v83.b to i64
    %v84.cb = icmp ne i64 %v83, 0
    br i1 %v84.cb, label %if_84_then, label %if_84_else
if_84_then:
    br label %if_84_merge
if_84_else:
    %v88 = add i64 0, 101
    %v89.b = icmp eq i64 %v81, %v88
    %v89 = zext i1 %v89.b to i64
    br label %if_84_merge
if_84_merge:
    %v92 = phi i64 [ %v83, %if_84_then ], [ %v89, %if_84_else ]
    %v93.cb = icmp ne i64 %v92, 0
    br i1 %v93.cb, label %if_93_then, label %if_93_else
if_93_then:
    br label %if_93_merge
if_93_else:
    %v97 = add i64 0, 69
    %v98.b = icmp eq i64 %v81, %v97
    %v98 = zext i1 %v98.b to i64
    br label %if_93_merge
if_93_merge:
    %v101 = phi i64 [ %v92, %if_93_then ], [ %v98, %if_93_else ]
    %v102.cb = icmp ne i64 %v101, 0
    br i1 %v102.cb, label %if_102_then, label %if_102_else
if_102_then:
    br label %if_102_merge
if_102_else:
    %v106 = add i64 0, 43
    %v107.b = icmp eq i64 %v81, %v106
    %v107 = zext i1 %v107.b to i64
    br label %if_102_merge
if_102_merge:
    %v110 = phi i64 [ %v101, %if_102_then ], [ %v107, %if_102_else ]
    %v111.cb = icmp ne i64 %v110, 0
    br i1 %v111.cb, label %if_111_then, label %if_111_else
if_111_then:
    br label %if_111_merge
if_111_else:
    %v115 = add i64 0, 48
    %v116.b = icmp sge i64 %v81, %v115
    %v116 = zext i1 %v116.b to i64
    %v117.cb = icmp ne i64 %v116, 0
    br i1 %v117.cb, label %if_117_then, label %if_117_else
if_117_then:
    %v119 = add i64 0, 57
    %v120.b = icmp sle i64 %v81, %v119
    %v120 = zext i1 %v120.b to i64
    br label %if_117_merge
if_117_else:
    %v123 = add i64 0, 0
    br label %if_117_merge
if_117_merge:
    %v126 = phi i64 [ %v120, %if_117_then ], [ %v123, %if_117_else ]
    br label %if_111_merge
if_111_merge:
    %v129 = phi i64 [ %v110, %if_111_then ], [ %v126, %if_117_merge ]
    %v130.cb = icmp ne i64 %v129, 0
    br i1 %v130.cb, label %if_130_then, label %if_130_else
if_130_then:
    %v132 = load i64, ptr %v3
    %v133 = add i64 0, 1
    %v134 = add i64 %v132, %v133
    store i64 %v134, ptr %v3
    %v135 = add i64 0, 0
    br label %if_130_merge
if_130_else:
    %v138 = add i64 0, 45
    %v139.b = icmp eq i64 %v81, %v138
    %v139 = zext i1 %v139.b to i64
    %v140.cb = icmp ne i64 %v139, 0
    br i1 %v140.cb, label %if_140_then, label %if_140_else
if_140_then:
    %v142 = load i64, ptr %v3
    %v143 = add i64 0, 1
    %v144 = add i64 %v142, %v143
    store i64 %v144, ptr %v3
    %v145 = add i64 0, 0
    br label %if_140_merge
if_140_else:
    br label %loop_70_end
if_140_merge:
    br label %if_130_merge
if_130_merge:
    %v152 = phi i64 [ %v135, %if_130_then ], [ %v145, %if_140_merge ]
    br label %loop_70_header
loop_70_end:
    %v155 = getelementptr i8, ptr @.str_0, i64 16
    %v156 = load i64, ptr %v6
    %v157.cb = icmp ne i64 %v156, 0
    br i1 %v157.cb, label %if_157_then, label %if_157_else
if_157_then:
    %v159 = add i64 0, 0
    %v160 = load i64, ptr %v25
    %v161 = sub i64 %v159, %v160
    br label %if_157_merge
if_157_else:
    %v164 = load i64, ptr %v25
    br label %if_157_merge
if_157_merge:
    %v167 = phi i64 [ %v161, %if_157_then ], [ %v164, %if_157_else ]
    %v168 = getelementptr i8, ptr @.str_1, i64 16
    %v169 = load i64, ptr %v3
    %v170 = call ptr @orion_map_new(i64 2)
    call void @orion_map_set(ptr %v170, ptr %v155, i64 %v167)
    call void @orion_map_set(ptr %v170, ptr %v168, i64 %v169)
    ret ptr %v170
}

define ptr @json__jsn_object(ptr %p0, i64 %p1) {
entry:
    %v4 = alloca ptr, align 8
    %v8 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = call i64 @orion_list_len(ptr %v0)
    %v3 = call ptr @orion_map_new(i64 0)
    store ptr %v3, ptr %v4
    %v5 = add i64 0, 0
    %v6 = add i64 0, 1
    %v7 = add i64 %v1, %v6
    store i64 %v7, ptr %v8
    %v9 = add i64 0, 0
    br label %loop_10_header
loop_10_header:
    %v12 = load i64, ptr %v8
    %v13 = call i64 @json__jsn_ws(ptr %v0, i64 %v12)
    store i64 %v13, ptr %v8
    %v14 = add i64 0, 0
    %v15 = load i64, ptr %v8
    %v16.b = icmp sge i64 %v15, %v2
    %v16 = zext i1 %v16.b to i64
    %v17.cb = icmp ne i64 %v16, 0
    br i1 %v17.cb, label %if_17_then, label %if_17_else
if_17_then:
    br label %loop_10_end
if_17_else:
    br label %if_17_merge
if_17_merge:
    %v23 = load i64, ptr %v8
    %v24 = call i64 @orion_list_at(ptr %v0, i64 %v23)
    %v25 = add i64 0, 125
    %v26.b = icmp eq i64 %v24, %v25
    %v26 = zext i1 %v26.b to i64
    %v27.cb = icmp ne i64 %v26, 0
    br i1 %v27.cb, label %if_27_then, label %if_27_else
if_27_then:
    %v29 = load i64, ptr %v8
    %v30 = add i64 0, 1
    %v31 = add i64 %v29, %v30
    store i64 %v31, ptr %v8
    %v32 = add i64 0, 0
    br label %loop_10_end
if_27_else:
    br label %if_27_merge
if_27_merge:
    %v37 = add i64 0, 44
    %v38.b = icmp eq i64 %v24, %v37
    %v38 = zext i1 %v38.b to i64
    %v39.cb = icmp ne i64 %v38, 0
    br i1 %v39.cb, label %if_39_then, label %if_39_else
if_39_then:
    %v41 = load i64, ptr %v8
    %v42 = add i64 0, 1
    %v43 = add i64 %v41, %v42
    store i64 %v43, ptr %v8
    %v44 = add i64 0, 0
    br label %loop_10_header
if_39_else:
    br label %if_39_merge
if_39_merge:
    %v49 = add i64 0, 34
    %v50.b = icmp ne i64 %v24, %v49
    %v50 = zext i1 %v50.b to i64
    %v51.cb = icmp ne i64 %v50, 0
    br i1 %v51.cb, label %if_51_then, label %if_51_else
if_51_then:
    %v53 = load i64, ptr %v8
    %v54 = add i64 0, 1
    %v55 = add i64 %v53, %v54
    store i64 %v55, ptr %v8
    %v56 = add i64 0, 0
    br label %loop_10_header
if_51_else:
    br label %if_51_merge
if_51_merge:
    %v61 = load i64, ptr %v8
    %v62 = call i64 @json__jsn_str_end(ptr %v0, i64 %v61)
    %v63 = load i64, ptr %v8
    %v64 = add i64 0, 1
    %v65 = add i64 %v63, %v64
    %v66 = add i64 0, 1
    %v67 = sub i64 %v62, %v66
    %v68 = call ptr @orion_bytes_slice(ptr %v0, i64 %v65, i64 %v67)
    %v69 = call ptr @orion_bytes_to_text(ptr %v68)
    %v70 = call i64 @json__jsn_ws(ptr %v0, i64 %v62)
    store i64 %v70, ptr %v8
    %v71 = add i64 0, 0
    %v72 = load i64, ptr %v8
    %v73.b = icmp slt i64 %v72, %v2
    %v73 = zext i1 %v73.b to i64
    %v74.cb = icmp ne i64 %v73, 0
    br i1 %v74.cb, label %if_74_then, label %if_74_else
if_74_then:
    %v76 = load i64, ptr %v8
    %v77 = call i64 @orion_list_at(ptr %v0, i64 %v76)
    %v78 = add i64 0, 58
    %v79.b = icmp eq i64 %v77, %v78
    %v79 = zext i1 %v79.b to i64
    %v80.cb = icmp ne i64 %v79, 0
    br i1 %v80.cb, label %if_80_then, label %if_80_else
if_80_then:
    %v82 = load i64, ptr %v8
    %v83 = add i64 0, 1
    %v84 = add i64 %v82, %v83
    store i64 %v84, ptr %v8
    %v85 = add i64 0, 0
    br label %if_80_merge
if_80_else:
    br label %if_80_merge
if_80_merge:
    br label %if_74_merge
if_74_else:
    br label %if_74_merge
if_74_merge:
    %v94 = load i64, ptr %v8
    %v95 = call ptr @json__jsn_value(ptr %v0, i64 %v94)
    %v96 = load ptr, ptr %v4
    %v97 = getelementptr i8, ptr @.str_0, i64 16
    %v98.i = call i64 @orion_map_get(ptr %v95, ptr %v97)
    %v98.raw = inttoptr i64 %v98.i to ptr
    %v98.isnull = icmp eq i64 %v98.i, 0
    %v98 = select i1 %v98.isnull, ptr getelementptr(i8, ptr @.str_empty_h, i64 16), ptr %v98.raw
    %v99.p = ptrtoint ptr %v98 to i64
    call void @orion_map_set(ptr %v96, ptr %v69, i64 %v99.p)
    %v99 = getelementptr i8, ptr %v96, i64 0
    store ptr %v99, ptr %v4
    %v100 = add i64 0, 0
    %v101 = getelementptr i8, ptr @.str_1, i64 16
    %v102 = call i64 @orion_map_get(ptr %v95, ptr %v101)
    store i64 %v102, ptr %v8
    %v103 = add i64 0, 0
    br label %loop_10_header
loop_10_end:
    %v106 = getelementptr i8, ptr @.str_0, i64 16
    %v107 = load ptr, ptr %v4
    %v108 = getelementptr i8, ptr @.str_1, i64 16
    %v109 = load i64, ptr %v8
    %v110 = call ptr @orion_map_new(i64 2)
    %v110.p0 = ptrtoint ptr %v107 to i64
    call void @orion_map_set(ptr %v110, ptr %v106, i64 %v110.p0)
    call void @orion_map_set(ptr %v110, ptr %v108, i64 %v109)
    ret ptr %v110
}

define ptr @json__jsn_array(ptr %p0, i64 %p1) {
entry:
    %v4 = alloca ptr, align 8
    %v8 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = call i64 @orion_list_len(ptr %v0)
    %v3 = getelementptr i64, ptr @orion_empty_list, i64 0
    store ptr %v3, ptr %v4
    %v5 = add i64 0, 0
    %v6 = add i64 0, 1
    %v7 = add i64 %v1, %v6
    store i64 %v7, ptr %v8
    %v9 = add i64 0, 0
    br label %loop_10_header
loop_10_header:
    %v12 = load i64, ptr %v8
    %v13 = call i64 @json__jsn_ws(ptr %v0, i64 %v12)
    store i64 %v13, ptr %v8
    %v14 = add i64 0, 0
    %v15 = load i64, ptr %v8
    %v16.b = icmp sge i64 %v15, %v2
    %v16 = zext i1 %v16.b to i64
    %v17.cb = icmp ne i64 %v16, 0
    br i1 %v17.cb, label %if_17_then, label %if_17_else
if_17_then:
    br label %loop_10_end
if_17_else:
    br label %if_17_merge
if_17_merge:
    %v23 = load i64, ptr %v8
    %v24 = call i64 @orion_list_at(ptr %v0, i64 %v23)
    %v25 = add i64 0, 93
    %v26.b = icmp eq i64 %v24, %v25
    %v26 = zext i1 %v26.b to i64
    %v27.cb = icmp ne i64 %v26, 0
    br i1 %v27.cb, label %if_27_then, label %if_27_else
if_27_then:
    %v29 = load i64, ptr %v8
    %v30 = add i64 0, 1
    %v31 = add i64 %v29, %v30
    store i64 %v31, ptr %v8
    %v32 = add i64 0, 0
    br label %loop_10_end
if_27_else:
    br label %if_27_merge
if_27_merge:
    %v37 = add i64 0, 44
    %v38.b = icmp eq i64 %v24, %v37
    %v38 = zext i1 %v38.b to i64
    %v39.cb = icmp ne i64 %v38, 0
    br i1 %v39.cb, label %if_39_then, label %if_39_else
if_39_then:
    %v41 = load i64, ptr %v8
    %v42 = add i64 0, 1
    %v43 = add i64 %v41, %v42
    store i64 %v43, ptr %v8
    %v44 = add i64 0, 0
    br label %loop_10_header
if_39_else:
    br label %if_39_merge
if_39_merge:
    %v49 = load i64, ptr %v8
    %v50 = call ptr @json__jsn_value(ptr %v0, i64 %v49)
    %v51 = load ptr, ptr %v4
    %v52 = getelementptr i8, ptr @.str_0, i64 16
    %v53.i = call i64 @orion_map_get(ptr %v50, ptr %v52)
    %v53.raw = inttoptr i64 %v53.i to ptr
    %v53.isnull = icmp eq i64 %v53.i, 0
    %v53 = select i1 %v53.isnull, ptr getelementptr(i8, ptr @.str_empty_h, i64 16), ptr %v53.raw
    %v54.p = ptrtoint ptr %v53 to i64
    %v54 = call ptr @orion_list_push_mut(ptr %v51, i64 %v54.p)
    store ptr %v54, ptr %v4
    %v55 = add i64 0, 0
    %v56 = getelementptr i8, ptr @.str_1, i64 16
    %v57 = call i64 @orion_map_get(ptr %v50, ptr %v56)
    store i64 %v57, ptr %v8
    %v58 = add i64 0, 0
    br label %loop_10_header
loop_10_end:
    %v61 = getelementptr i8, ptr @.str_0, i64 16
    %v62 = load ptr, ptr %v4
    %v63 = getelementptr i8, ptr @.str_1, i64 16
    %v64 = load i64, ptr %v8
    %v65 = call ptr @orion_map_new(i64 2)
    %v65.p0 = ptrtoint ptr %v62 to i64
    call void @orion_map_set(ptr %v65, ptr %v61, i64 %v65.p0)
    call void @orion_map_set(ptr %v65, ptr %v63, i64 %v64)
    ret ptr %v65
}

define ptr @json__json_parse(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = call ptr @orion_bytes_from_text(ptr %v0)
    %v2 = add i64 0, 0
    %v3 = call ptr @json__jsn_value(ptr %v1, i64 %v2)
    %v4 = getelementptr i8, ptr @.str_0, i64 16
    %v5.i = call i64 @orion_map_get(ptr %v3, ptr %v4)
    %v5.raw = inttoptr i64 %v5.i to ptr
    %v5.isnull = icmp eq i64 %v5.i, 0
    %v5 = select i1 %v5.isnull, ptr @orion_empty_list, ptr %v5.raw
    ret ptr %v5
}

define ptr @json__json_obj(ptr %p0, ptr %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = call i64 @orion_map_has(ptr %v0, ptr %v1)
    %v3.cb = icmp ne i64 %v2, 0
    br i1 %v3.cb, label %if_3_then, label %if_3_else
if_3_then:
    %v5.i = call i64 @orion_map_get(ptr %v0, ptr %v1)
    %v5.raw = inttoptr i64 %v5.i to ptr
    %v5.isnull = icmp eq i64 %v5.i, 0
    %v5 = select i1 %v5.isnull, ptr @orion_empty_list, ptr %v5.raw
    br label %if_3_merge
if_3_else:
    %v8 = call ptr @orion_map_new(i64 0)
    br label %if_3_merge
if_3_merge:
    %v11 = phi ptr [ %v5, %if_3_then ], [ %v8, %if_3_else ]
    ret ptr %v11
}

define ptr @json__json_text(ptr %p0, ptr %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = call i64 @orion_map_has(ptr %v0, ptr %v1)
    %v3.cb = icmp ne i64 %v2, 0
    br i1 %v3.cb, label %if_3_then, label %if_3_else
if_3_then:
    %v5.i = call i64 @orion_map_get(ptr %v0, ptr %v1)
    %v5.raw = inttoptr i64 %v5.i to ptr
    %v5.isnull = icmp eq i64 %v5.i, 0
    %v5 = select i1 %v5.isnull, ptr getelementptr(i8, ptr @.str_empty_h, i64 16), ptr %v5.raw
    br label %if_3_merge
if_3_else:
    %v8 = getelementptr i8, ptr @.str_2, i64 16
    br label %if_3_merge
if_3_merge:
    %v11 = phi ptr [ %v5, %if_3_then ], [ %v8, %if_3_else ]
    ret ptr %v11
}

define i64 @json__json_int(ptr %p0, ptr %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = call i64 @orion_map_has(ptr %v0, ptr %v1)
    %v3.cb = icmp ne i64 %v2, 0
    br i1 %v3.cb, label %if_3_then, label %if_3_else
if_3_then:
    %v5 = call i64 @orion_map_get(ptr %v0, ptr %v1)
    br label %if_3_merge
if_3_else:
    %v8 = add i64 0, 0
    br label %if_3_merge
if_3_merge:
    %v11 = phi i64 [ %v5, %if_3_then ], [ %v8, %if_3_else ]
    ret i64 %v11
}

define ptr @json__json_list(ptr %p0, ptr %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = call i64 @orion_map_has(ptr %v0, ptr %v1)
    %v3.cb = icmp ne i64 %v2, 0
    br i1 %v3.cb, label %if_3_then, label %if_3_else
if_3_then:
    %v5.i = call i64 @orion_map_get(ptr %v0, ptr %v1)
    %v5.raw = inttoptr i64 %v5.i to ptr
    %v5.isnull = icmp eq i64 %v5.i, 0
    %v5 = select i1 %v5.isnull, ptr @orion_empty_list, ptr %v5.raw
    br label %if_3_merge
if_3_else:
    %v8 = getelementptr i64, ptr @orion_empty_list, i64 0
    br label %if_3_merge
if_3_merge:
    %v11 = phi ptr [ %v5, %if_3_then ], [ %v8, %if_3_else ]
    ret ptr %v11
}

define i64 @json__json_has(ptr %p0, ptr %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = call i64 @orion_map_has(ptr %v0, ptr %v1)
    ret i64 %v2
}

define ptr @json__json_escape(ptr %p0) {
entry:
    %v8 = alloca ptr, align 8
    %v11 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = call ptr @orion_bytes_from_text(ptr %v0)
    %v2 = call i64 @orion_list_len(ptr %v1)
    %v3 = add i64 0, 0
    %v4 = call ptr @orion_list_new(i64 1)
    call void @orion_list_set(ptr %v4, i64 0, i64 %v3)
    %v5 = add i64 0, 0
    %v6 = add i64 0, 0
    %v7 = call ptr @orion_list_slice(ptr %v4, i64 %v5, i64 %v6)
    store ptr %v7, ptr %v8
    %v9 = add i64 0, 0
    %v10 = add i64 0, 0
    store i64 %v10, ptr %v11
    %v12 = add i64 0, 0
    br label %for_10_header
for_10_header:
    %v15 = load i64, ptr %v11
    %v16.b = icmp slt i64 %v15, %v2
    %v16 = zext i1 %v16.b to i64
    %v17.cb = icmp ne i64 %v16, 0
    br i1 %v17.cb, label %for_10_body, label %for_10_end
for_10_body:
    %v19 = call i64 @orion_list_at(ptr %v1, i64 %v15)
    %v20 = add i64 0, 34
    %v21.b = icmp eq i64 %v19, %v20
    %v21 = zext i1 %v21.b to i64
    %v22.cb = icmp ne i64 %v21, 0
    br i1 %v22.cb, label %if_22_then, label %if_22_else
if_22_then:
    %v24 = load ptr, ptr %v8
    %v25 = add i64 0, 92
    %v26 = call ptr @orion_list_push_mut(ptr %v24, i64 %v25)
    store ptr %v26, ptr %v8
    %v27 = add i64 0, 0
    %v28 = load ptr, ptr %v8
    %v29 = add i64 0, 34
    %v30 = call ptr @orion_list_push_mut(ptr %v28, i64 %v29)
    store ptr %v30, ptr %v8
    %v31 = add i64 0, 0
    br label %if_22_merge
if_22_else:
    %v34 = add i64 0, 92
    %v35.b = icmp eq i64 %v19, %v34
    %v35 = zext i1 %v35.b to i64
    %v36.cb = icmp ne i64 %v35, 0
    br i1 %v36.cb, label %if_36_then, label %if_36_else
if_36_then:
    %v38 = load ptr, ptr %v8
    %v39 = add i64 0, 92
    %v40 = call ptr @orion_list_push_mut(ptr %v38, i64 %v39)
    store ptr %v40, ptr %v8
    %v41 = add i64 0, 0
    %v42 = load ptr, ptr %v8
    %v43 = add i64 0, 92
    %v44 = call ptr @orion_list_push_mut(ptr %v42, i64 %v43)
    store ptr %v44, ptr %v8
    %v45 = add i64 0, 0
    br label %if_36_merge
if_36_else:
    %v48 = add i64 0, 10
    %v49.b = icmp eq i64 %v19, %v48
    %v49 = zext i1 %v49.b to i64
    %v50.cb = icmp ne i64 %v49, 0
    br i1 %v50.cb, label %if_50_then, label %if_50_else
if_50_then:
    %v52 = load ptr, ptr %v8
    %v53 = add i64 0, 92
    %v54 = call ptr @orion_list_push_mut(ptr %v52, i64 %v53)
    store ptr %v54, ptr %v8
    %v55 = add i64 0, 0
    %v56 = load ptr, ptr %v8
    %v57 = add i64 0, 110
    %v58 = call ptr @orion_list_push_mut(ptr %v56, i64 %v57)
    store ptr %v58, ptr %v8
    %v59 = add i64 0, 0
    br label %if_50_merge
if_50_else:
    %v62 = add i64 0, 13
    %v63.b = icmp eq i64 %v19, %v62
    %v63 = zext i1 %v63.b to i64
    %v64.cb = icmp ne i64 %v63, 0
    br i1 %v64.cb, label %if_64_then, label %if_64_else
if_64_then:
    %v66 = load ptr, ptr %v8
    %v67 = add i64 0, 92
    %v68 = call ptr @orion_list_push_mut(ptr %v66, i64 %v67)
    store ptr %v68, ptr %v8
    %v69 = add i64 0, 0
    %v70 = load ptr, ptr %v8
    %v71 = add i64 0, 114
    %v72 = call ptr @orion_list_push_mut(ptr %v70, i64 %v71)
    store ptr %v72, ptr %v8
    %v73 = add i64 0, 0
    br label %if_64_merge
if_64_else:
    %v76 = add i64 0, 9
    %v77.b = icmp eq i64 %v19, %v76
    %v77 = zext i1 %v77.b to i64
    %v78.cb = icmp ne i64 %v77, 0
    br i1 %v78.cb, label %if_78_then, label %if_78_else
if_78_then:
    %v80 = load ptr, ptr %v8
    %v81 = add i64 0, 92
    %v82 = call ptr @orion_list_push_mut(ptr %v80, i64 %v81)
    store ptr %v82, ptr %v8
    %v83 = add i64 0, 0
    %v84 = load ptr, ptr %v8
    %v85 = add i64 0, 116
    %v86 = call ptr @orion_list_push_mut(ptr %v84, i64 %v85)
    store ptr %v86, ptr %v8
    %v87 = add i64 0, 0
    br label %if_78_merge
if_78_else:
    %v90 = add i64 0, 32
    %v91.b = icmp slt i64 %v19, %v90
    %v91 = zext i1 %v91.b to i64
    %v92.cb = icmp ne i64 %v91, 0
    br i1 %v92.cb, label %if_92_then, label %if_92_else
if_92_then:
    %v94 = getelementptr i8, ptr @.str_3, i64 16
    %v95 = call ptr @orion_bytes_from_text(ptr %v94)
    %v96 = load ptr, ptr %v8
    %v97 = add i64 0, 92
    %v98 = call ptr @orion_list_push_mut(ptr %v96, i64 %v97)
    store ptr %v98, ptr %v8
    %v99 = add i64 0, 0
    %v100 = load ptr, ptr %v8
    %v101 = add i64 0, 117
    %v102 = call ptr @orion_list_push_mut(ptr %v100, i64 %v101)
    store ptr %v102, ptr %v8
    %v103 = add i64 0, 0
    %v104 = load ptr, ptr %v8
    %v105 = add i64 0, 48
    %v106 = call ptr @orion_list_push_mut(ptr %v104, i64 %v105)
    store ptr %v106, ptr %v8
    %v107 = add i64 0, 0
    %v108 = load ptr, ptr %v8
    %v109 = add i64 0, 48
    %v110 = call ptr @orion_list_push_mut(ptr %v108, i64 %v109)
    store ptr %v110, ptr %v8
    %v111 = add i64 0, 0
    %v112 = load ptr, ptr %v8
    %v113 = add i64 0, 16
    %v114 = call i64 @orion_idiv(i64 %v19, i64 %v113)
    %v115 = call i64 @orion_list_at(ptr %v95, i64 %v114)
    %v116 = call ptr @orion_list_push_mut(ptr %v112, i64 %v115)
    store ptr %v116, ptr %v8
    %v117 = add i64 0, 0
    %v118 = load ptr, ptr %v8
    %v119 = add i64 0, 16
    %v120 = call i64 @orion_idiv(i64 %v19, i64 %v119)
    %v121 = add i64 0, 16
    %v122 = mul i64 %v120, %v121
    %v123 = sub i64 %v19, %v122
    %v124 = call i64 @orion_list_at(ptr %v95, i64 %v123)
    %v125 = call ptr @orion_list_push_mut(ptr %v118, i64 %v124)
    store ptr %v125, ptr %v8
    %v126 = add i64 0, 0
    br label %if_92_merge
if_92_else:
    %v129 = load ptr, ptr %v8
    %v130 = call ptr @orion_list_push_mut(ptr %v129, i64 %v19)
    store ptr %v130, ptr %v8
    %v131 = add i64 0, 0
    br label %if_92_merge
if_92_merge:
    %v134 = phi i64 [ %v126, %if_92_then ], [ %v131, %if_92_else ]
    br label %if_78_merge
if_78_merge:
    %v137 = phi i64 [ %v87, %if_78_then ], [ %v134, %if_92_merge ]
    br label %if_64_merge
if_64_merge:
    %v140 = phi i64 [ %v73, %if_64_then ], [ %v137, %if_78_merge ]
    br label %if_50_merge
if_50_merge:
    %v143 = phi i64 [ %v59, %if_50_then ], [ %v140, %if_64_merge ]
    br label %if_36_merge
if_36_merge:
    %v146 = phi i64 [ %v45, %if_36_then ], [ %v143, %if_50_merge ]
    br label %if_22_merge
if_22_merge:
    %v149 = phi i64 [ %v31, %if_22_then ], [ %v146, %if_36_merge ]
    br label %for_10_step
for_10_step:
    %v152 = add i64 0, 1
    %v153 = add i64 %v15, %v152
    store i64 %v153, ptr %v11
    %v154 = add i64 0, 0
    br label %for_10_header
for_10_end:
    %v157 = load ptr, ptr %v8
    %v158 = call ptr @orion_bytes_to_text(ptr %v157)
    ret ptr %v158
}

define ptr @json__jnull() {
entry:
    %v0 = add i64 0, 0
    %v1 = add i64 0, 0
    %v2 = add i64 0, 0
    %v3 = call ptr @orion_alloc(i64 24)
    %v3.f0 = getelementptr i64, ptr %v3, i64 0
    store i64 %v0, ptr %v3.f0
    %v3.f1 = getelementptr i64, ptr %v3, i64 1
    store i64 %v1, ptr %v3.f1
    %v3.f2 = getelementptr i64, ptr %v3, i64 2
    store i64 %v2, ptr %v3.f2
    ret ptr %v3
}

define ptr @json__jbool(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, 1
    %v2 = add i64 0, 0
    %v3 = call ptr @orion_alloc(i64 24)
    %v3.f0 = getelementptr i64, ptr %v3, i64 0
    store i64 %v1, ptr %v3.f0
    %v3.f1 = getelementptr i64, ptr %v3, i64 1
    store i64 %v0, ptr %v3.f1
    %v3.f2 = getelementptr i64, ptr %v3, i64 2
    store i64 %v2, ptr %v3.f2
    ret ptr %v3
}

define ptr @json__jint(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, 2
    %v2 = add i64 0, 0
    %v3 = call ptr @orion_alloc(i64 24)
    %v3.f0 = getelementptr i64, ptr %v3, i64 0
    store i64 %v1, ptr %v3.f0
    %v3.f1 = getelementptr i64, ptr %v3, i64 1
    store i64 %v0, ptr %v3.f1
    %v3.f2 = getelementptr i64, ptr %v3, i64 2
    store i64 %v2, ptr %v3.f2
    ret ptr %v3
}

define ptr @json__jfloat(double %p0) {
entry:
    %v0 = fadd double %p0, 0x0000000000000000
    %v1 = add i64 0, 3
    %v2 = add i64 0, 0
    %v3 = call ptr @orion_alloc(i64 24)
    %v3.f0 = getelementptr i64, ptr %v3, i64 0
    store i64 %v1, ptr %v3.f0
    %v3.f1 = getelementptr i64, ptr %v3, i64 1
    %v3.f1.b = bitcast double %v0 to i64
    store i64 %v3.f1.b, ptr %v3.f1
    %v3.f2 = getelementptr i64, ptr %v3, i64 2
    store i64 %v2, ptr %v3.f2
    ret ptr %v3
}

define ptr @json__jstr(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, 4
    %v2 = add i64 0, 0
    %v3 = call ptr @orion_alloc(i64 24)
    %v3.f0 = getelementptr i64, ptr %v3, i64 0
    store i64 %v1, ptr %v3.f0
    %v3.f1 = getelementptr i64, ptr %v3, i64 1
    %v3.f1.i = ptrtoint ptr %v0 to i64
    store i64 %v3.f1.i, ptr %v3.f1
    %v3.f2 = getelementptr i64, ptr %v3, i64 2
    store i64 %v2, ptr %v3.f2
    ret ptr %v3
}

define ptr @json__jarr(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, 5
    %v2 = add i64 0, 0
    %v3 = call ptr @orion_alloc(i64 24)
    %v3.f0 = getelementptr i64, ptr %v3, i64 0
    store i64 %v1, ptr %v3.f0
    %v3.f1 = getelementptr i64, ptr %v3, i64 1
    %v3.f1.i = ptrtoint ptr %v0 to i64
    store i64 %v3.f1.i, ptr %v3.f1
    %v3.f2 = getelementptr i64, ptr %v3, i64 2
    store i64 %v2, ptr %v3.f2
    ret ptr %v3
}

define ptr @json__jobj(ptr %p0, ptr %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = add i64 0, 6
    %v3 = call ptr @orion_alloc(i64 24)
    %v3.f0 = getelementptr i64, ptr %v3, i64 0
    store i64 %v2, ptr %v3.f0
    %v3.f1 = getelementptr i64, ptr %v3, i64 1
    %v3.f1.i = ptrtoint ptr %v0 to i64
    store i64 %v3.f1.i, ptr %v3.f1
    %v3.f2 = getelementptr i64, ptr %v3, i64 2
    %v3.f2.i = ptrtoint ptr %v1 to i64
    store i64 %v3.f2.i, ptr %v3.f2
    ret ptr %v3
}

define ptr @json__json_stringify(ptr %p0) {
entry:
    %v1 = alloca ptr, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v2 = add i64 0, 0
    %v3.slot = getelementptr i64, ptr %v0, i64 0
    %v3 = load i64, ptr %v3.slot
    %v4.b = icmp eq i64 %v3, %v2
    %v4 = zext i1 %v4.b to i64
    %v5.cb = icmp ne i64 %v4, 0
    br i1 %v5.cb, label %match_1_arm_0_body, label %match_1_arm_0_next
match_1_arm_0_body:
    %v7 = getelementptr i8, ptr @.str_4, i64 16
    store ptr %v7, ptr %v1
    %v8 = add i64 0, 0
    br label %match_1_end
match_1_arm_0_next:
    %v11 = add i64 0, 1
    %v12.slot = getelementptr i64, ptr %v0, i64 0
    %v12 = load i64, ptr %v12.slot
    %v13.b = icmp eq i64 %v12, %v11
    %v13 = zext i1 %v13.b to i64
    %v14.cb = icmp ne i64 %v13, 0
    br i1 %v14.cb, label %match_1_arm_1_body, label %match_1_arm_1_next
match_1_arm_1_body:
    %v16.slot = getelementptr i64, ptr %v0, i64 1
    %v16 = load i64, ptr %v16.slot
    %v17 = add i64 0, 0
    %v18.b = icmp eq i64 %v16, %v17
    %v18 = zext i1 %v18.b to i64
    %v19.cb = icmp ne i64 %v18, 0
    br i1 %v19.cb, label %if_19_then, label %if_19_else
if_19_then:
    %v21 = getelementptr i8, ptr @.str_5, i64 16
    br label %if_19_merge
if_19_else:
    %v24 = getelementptr i8, ptr @.str_6, i64 16
    br label %if_19_merge
if_19_merge:
    %v27 = phi ptr [ %v21, %if_19_then ], [ %v24, %if_19_else ]
    store ptr %v27, ptr %v1
    %v28 = add i64 0, 0
    br label %match_1_end
match_1_arm_1_next:
    %v31 = add i64 0, 2
    %v32.slot = getelementptr i64, ptr %v0, i64 0
    %v32 = load i64, ptr %v32.slot
    %v33.b = icmp eq i64 %v32, %v31
    %v33 = zext i1 %v33.b to i64
    %v34.cb = icmp ne i64 %v33, 0
    br i1 %v34.cb, label %match_1_arm_2_body, label %match_1_arm_2_next
match_1_arm_2_body:
    %v36.slot = getelementptr i64, ptr %v0, i64 1
    %v36 = load i64, ptr %v36.slot
    %v37 = call ptr @orion_int_to_text(i64 %v36)
    store ptr %v37, ptr %v1
    %v38 = add i64 0, 0
    br label %match_1_end
match_1_arm_2_next:
    %v41 = add i64 0, 3
    %v42.slot = getelementptr i64, ptr %v0, i64 0
    %v42 = load i64, ptr %v42.slot
    %v43.b = icmp eq i64 %v42, %v41
    %v43 = zext i1 %v43.b to i64
    %v44.cb = icmp ne i64 %v43, 0
    br i1 %v44.cb, label %match_1_arm_3_body, label %match_1_arm_3_next
match_1_arm_3_body:
    %v46.slot = getelementptr i64, ptr %v0, i64 1
    %v46.b = load i64, ptr %v46.slot
    %v46 = bitcast i64 %v46.b to double
    %v47 = call ptr @orion_f64_to_text(double %v46)
    store ptr %v47, ptr %v1
    %v48 = add i64 0, 0
    br label %match_1_end
match_1_arm_3_next:
    %v51 = add i64 0, 4
    %v52.slot = getelementptr i64, ptr %v0, i64 0
    %v52 = load i64, ptr %v52.slot
    %v53.b = icmp eq i64 %v52, %v51
    %v53 = zext i1 %v53.b to i64
    %v54.cb = icmp ne i64 %v53, 0
    br i1 %v54.cb, label %match_1_arm_4_body, label %match_1_arm_4_next
match_1_arm_4_body:
    %v56.slot = getelementptr i64, ptr %v0, i64 1
    %v56.i = load i64, ptr %v56.slot
    %v56 = inttoptr i64 %v56.i to ptr
    %v57 = call ptr @json__jsn_quote(ptr %v56)
    store ptr %v57, ptr %v1
    %v58 = add i64 0, 0
    br label %match_1_end
match_1_arm_4_next:
    %v61 = add i64 0, 5
    %v62.slot = getelementptr i64, ptr %v0, i64 0
    %v62 = load i64, ptr %v62.slot
    %v63.b = icmp eq i64 %v62, %v61
    %v63 = zext i1 %v63.b to i64
    %v64.cb = icmp ne i64 %v63, 0
    br i1 %v64.cb, label %match_1_arm_5_body, label %match_1_arm_5_next
match_1_arm_5_body:
    %v66.slot = getelementptr i64, ptr %v0, i64 1
    %v66.i = load i64, ptr %v66.slot
    %v66 = inttoptr i64 %v66.i to ptr
    %v67 = call ptr @json__jsn_arr_text(ptr %v66)
    store ptr %v67, ptr %v1
    %v68 = add i64 0, 0
    br label %match_1_end
match_1_arm_5_next:
    %v71 = add i64 0, 6
    %v72.slot = getelementptr i64, ptr %v0, i64 0
    %v72 = load i64, ptr %v72.slot
    %v73.b = icmp eq i64 %v72, %v71
    %v73 = zext i1 %v73.b to i64
    %v74.cb = icmp ne i64 %v73, 0
    br i1 %v74.cb, label %match_1_arm_6_body, label %match_1_arm_6_next
match_1_arm_6_body:
    %v76.slot = getelementptr i64, ptr %v0, i64 1
    %v76.i = load i64, ptr %v76.slot
    %v76 = inttoptr i64 %v76.i to ptr
    %v77.slot = getelementptr i64, ptr %v0, i64 2
    %v77.i = load i64, ptr %v77.slot
    %v77 = inttoptr i64 %v77.i to ptr
    %v78 = call ptr @json__jsn_obj_text(ptr %v76, ptr %v77)
    store ptr %v78, ptr %v1
    %v79 = add i64 0, 0
    br label %match_1_end
match_1_arm_6_next:
    %v82 = add i64 0, 0
    store i64 %v82, ptr %v1
    %v83 = add i64 0, 0
    br label %match_1_end
match_1_end:
    %v86 = load ptr, ptr %v1
    ret ptr %v86
}

define ptr @json__jsn_quote(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, 34
    %v2 = call ptr @orion_list_new(i64 1)
    call void @orion_list_set(ptr %v2, i64 0, i64 %v1)
    %v3 = call ptr @orion_bytes_to_text(ptr %v2)
    %v4 = call ptr @json__json_escape(ptr %v0)
    %v5 = call ptr @orion_list_new(i64 3)
    %v5.lp0 = ptrtoint ptr %v3 to i64
    call void @orion_list_set(ptr %v5, i64 0, i64 %v5.lp0)
    %v5.lp1 = ptrtoint ptr %v4 to i64
    call void @orion_list_set(ptr %v5, i64 1, i64 %v5.lp1)
    %v5.lp2 = ptrtoint ptr %v3 to i64
    call void @orion_list_set(ptr %v5, i64 2, i64 %v5.lp2)
    %v6 = call ptr @orion_text_join(ptr %v5)
    ret ptr %v6
}

define ptr @json__jsn_arr_text(ptr %p0) {
entry:
    %v2 = alloca ptr, align 8
    %v6 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr @.str_7, i64 16
    store ptr %v1, ptr %v2
    %v3 = add i64 0, 0
    %v4 = add i64 0, 0
    %v5 = call i64 @orion_list_len(ptr %v0)
    store i64 %v4, ptr %v6
    %v7 = add i64 0, 0
    br label %for_4_header
for_4_header:
    %v10 = load i64, ptr %v6
    %v11.b = icmp slt i64 %v10, %v5
    %v11 = zext i1 %v11.b to i64
    %v12.cb = icmp ne i64 %v11, 0
    br i1 %v12.cb, label %for_4_body, label %for_4_end
for_4_body:
    %v14 = add i64 0, 0
    %v15.b = icmp sgt i64 %v10, %v14
    %v15 = zext i1 %v15.b to i64
    %v16.cb = icmp ne i64 %v15, 0
    br i1 %v16.cb, label %if_16_then, label %if_16_else
if_16_then:
    %v18 = load ptr, ptr %v2
    %v19 = getelementptr i8, ptr @.str_8, i64 16
    %v20 = call ptr @orion_text_concat(ptr %v18, ptr %v19)
    store ptr %v20, ptr %v2
    %v21 = add i64 0, 0
    br label %if_16_merge
if_16_else:
    br label %if_16_merge
if_16_merge:
    %v26 = load ptr, ptr %v2
    %v27.i = call i64 @orion_list_at(ptr %v0, i64 %v10)
    %v27 = inttoptr i64 %v27.i to ptr
    %v28 = call ptr @json__json_stringify(ptr %v27)
    %v29 = call ptr @orion_text_concat(ptr %v26, ptr %v28)
    store ptr %v29, ptr %v2
    %v30 = add i64 0, 0
    br label %for_4_step
for_4_step:
    %v33 = add i64 0, 1
    %v34 = add i64 %v10, %v33
    store i64 %v34, ptr %v6
    %v35 = add i64 0, 0
    br label %for_4_header
for_4_end:
    %v38 = load ptr, ptr %v2
    %v39 = getelementptr i8, ptr @.str_9, i64 16
    %v40 = call ptr @orion_text_concat(ptr %v38, ptr %v39)
    ret ptr %v40
}

define ptr @json__jsn_obj_text(ptr %p0, ptr %p1) {
entry:
    %v8 = alloca ptr, align 8
    %v12 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = add i64 0, 123
    %v3 = call ptr @orion_list_new(i64 1)
    call void @orion_list_set(ptr %v3, i64 0, i64 %v2)
    %v4 = call ptr @orion_bytes_to_text(ptr %v3)
    %v5 = add i64 0, 125
    %v6 = call ptr @orion_list_new(i64 1)
    call void @orion_list_set(ptr %v6, i64 0, i64 %v5)
    %v7 = call ptr @orion_bytes_to_text(ptr %v6)
    store ptr %v4, ptr %v8
    %v9 = add i64 0, 0
    %v10 = call i64 @orion_list_len(ptr %v0)
    %v11 = add i64 0, 0
    store i64 %v11, ptr %v12
    %v13 = add i64 0, 0
    br label %for_11_header
for_11_header:
    %v16 = load i64, ptr %v12
    %v17.b = icmp slt i64 %v16, %v10
    %v17 = zext i1 %v17.b to i64
    %v18.cb = icmp ne i64 %v17, 0
    br i1 %v18.cb, label %for_11_body, label %for_11_end
for_11_body:
    %v20 = add i64 0, 0
    %v21.b = icmp sgt i64 %v16, %v20
    %v21 = zext i1 %v21.b to i64
    %v22.cb = icmp ne i64 %v21, 0
    br i1 %v22.cb, label %if_22_then, label %if_22_else
if_22_then:
    %v24 = load ptr, ptr %v8
    %v25 = getelementptr i8, ptr @.str_8, i64 16
    %v26 = call ptr @orion_text_concat(ptr %v24, ptr %v25)
    store ptr %v26, ptr %v8
    %v27 = add i64 0, 0
    br label %if_22_merge
if_22_else:
    br label %if_22_merge
if_22_merge:
    %v32 = load ptr, ptr %v8
    %v33.i = call i64 @orion_list_at(ptr %v0, i64 %v16)
    %v33 = inttoptr i64 %v33.i to ptr
    %v34 = call ptr @json__jsn_quote(ptr %v33)
    %v35 = getelementptr i8, ptr @.str_10, i64 16
    %v36.i = call i64 @orion_list_at(ptr %v1, i64 %v16)
    %v36 = inttoptr i64 %v36.i to ptr
    %v37 = call ptr @json__json_stringify(ptr %v36)
    %v38 = call ptr @orion_list_new(i64 4)
    %v38.lp0 = ptrtoint ptr %v32 to i64
    call void @orion_list_set(ptr %v38, i64 0, i64 %v38.lp0)
    %v38.lp1 = ptrtoint ptr %v34 to i64
    call void @orion_list_set(ptr %v38, i64 1, i64 %v38.lp1)
    %v38.lp2 = ptrtoint ptr %v35 to i64
    call void @orion_list_set(ptr %v38, i64 2, i64 %v38.lp2)
    %v38.lp3 = ptrtoint ptr %v37 to i64
    call void @orion_list_set(ptr %v38, i64 3, i64 %v38.lp3)
    %v39 = call ptr @orion_text_join(ptr %v38)
    store ptr %v39, ptr %v8
    %v40 = add i64 0, 0
    br label %for_11_step
for_11_step:
    %v43 = add i64 0, 1
    %v44 = add i64 %v16, %v43
    store i64 %v44, ptr %v12
    %v45 = add i64 0, 0
    br label %for_11_header
for_11_end:
    %v48 = load ptr, ptr %v8
    %v49 = call ptr @orion_text_concat(ptr %v48, ptr %v7)
    ret ptr %v49
}

define i64 @orion_main() {
entry:
    %v0 = add i64 0, 1
    %v1 = call ptr @json__jint(i64 %v0)
    %v2 = add i64 0, 2
    %v3 = call ptr @json__jint(i64 %v2)
    %v4 = add i64 0, 3
    %v5 = call ptr @json__jint(i64 %v4)
    %v6 = call ptr @orion_list_new(i64 3)
    %v6.lp0 = ptrtoint ptr %v1 to i64
    call void @orion_list_set(ptr %v6, i64 0, i64 %v6.lp0)
    %v6.lp1 = ptrtoint ptr %v3 to i64
    call void @orion_list_set(ptr %v6, i64 1, i64 %v6.lp1)
    %v6.lp2 = ptrtoint ptr %v5 to i64
    call void @orion_list_set(ptr %v6, i64 2, i64 %v6.lp2)
    %v7 = call ptr @json__jarr(ptr %v6)
    %v8 = call ptr @json__json_stringify(ptr %v7)
    %v9 = getelementptr i8, ptr @.str_11, i64 16
    %v10.e = call i64 @orion_text_eq(ptr %v8, ptr %v9)
    %v10 = add i64 %v10.e, 0
    %v11.cb = icmp ne i64 %v10, 0
    br i1 %v11.cb, label %if_11_then, label %if_11_else
if_11_then:
    %v13 = add i64 0, 1
    br label %if_11_merge
if_11_else:
    %v16 = add i64 0, 0
    br label %if_11_merge
if_11_merge:
    %v19 = phi i64 [ %v13, %if_11_then ], [ %v16, %if_11_else ]
    %v20 = call ptr @json__jnull()
    %v21 = call ptr @json__json_stringify(ptr %v20)
    %v22 = getelementptr i8, ptr @.str_4, i64 16
    %v23.e = call i64 @orion_text_eq(ptr %v21, ptr %v22)
    %v23 = add i64 %v23.e, 0
    %v24.cb = icmp ne i64 %v23, 0
    br i1 %v24.cb, label %if_24_then, label %if_24_else
if_24_then:
    %v26 = add i64 0, 1
    %v27 = call ptr @json__jbool(i64 %v26)
    %v28 = call ptr @json__json_stringify(ptr %v27)
    %v29 = getelementptr i8, ptr @.str_6, i64 16
    %v30.e = call i64 @orion_text_eq(ptr %v28, ptr %v29)
    %v30 = add i64 %v30.e, 0
    br label %if_24_merge
if_24_else:
    %v33 = add i64 0, 0
    br label %if_24_merge
if_24_merge:
    %v36 = phi i64 [ %v30, %if_24_then ], [ %v33, %if_24_else ]
    %v37.cb = icmp ne i64 %v36, 0
    br i1 %v37.cb, label %if_37_then, label %if_37_else
if_37_then:
    %v39 = add i64 0, 0
    %v40 = call ptr @json__jbool(i64 %v39)
    %v41 = call ptr @json__json_stringify(ptr %v40)
    %v42 = getelementptr i8, ptr @.str_5, i64 16
    %v43.e = call i64 @orion_text_eq(ptr %v41, ptr %v42)
    %v43 = add i64 %v43.e, 0
    br label %if_37_merge
if_37_else:
    %v46 = add i64 0, 0
    br label %if_37_merge
if_37_merge:
    %v49 = phi i64 [ %v43, %if_37_then ], [ %v46, %if_37_else ]
    %v50.cb = icmp ne i64 %v49, 0
    br i1 %v50.cb, label %if_50_then, label %if_50_else
if_50_then:
    %v52 = add i64 0, 1
    br label %if_50_merge
if_50_else:
    %v55 = add i64 0, 0
    br label %if_50_merge
if_50_merge:
    %v58 = phi i64 [ %v52, %if_50_then ], [ %v55, %if_50_else ]
    %v59 = getelementptr i8, ptr @.str_12, i64 16
    %v60 = call ptr @json__jstr(ptr %v59)
    %v61 = call ptr @json__json_stringify(ptr %v60)
    %v62 = getelementptr i8, ptr @.str_13, i64 16
    %v63.e = call i64 @orion_text_eq(ptr %v61, ptr %v62)
    %v63 = add i64 %v63.e, 0
    %v64.cb = icmp ne i64 %v63, 0
    br i1 %v64.cb, label %if_64_then, label %if_64_else
if_64_then:
    %v66 = add i64 0, 1
    br label %if_64_merge
if_64_else:
    %v69 = add i64 0, 0
    br label %if_64_merge
if_64_merge:
    %v72 = phi i64 [ %v66, %if_64_then ], [ %v69, %if_64_else ]
    %v73 = getelementptr i8, ptr @.str_14, i64 16
    %v74 = getelementptr i8, ptr @.str_15, i64 16
    %v75 = call ptr @orion_list_new(i64 2)
    %v75.lp0 = ptrtoint ptr %v73 to i64
    call void @orion_list_set(ptr %v75, i64 0, i64 %v75.lp0)
    %v75.lp1 = ptrtoint ptr %v74 to i64
    call void @orion_list_set(ptr %v75, i64 1, i64 %v75.lp1)
    %v76 = add i64 0, 42
    %v77 = call ptr @json__jint(i64 %v76)
    %v78 = getelementptr i8, ptr @.str_16, i64 16
    %v79 = call ptr @json__jstr(ptr %v78)
    %v80 = call ptr @orion_list_new(i64 2)
    %v80.lp0 = ptrtoint ptr %v77 to i64
    call void @orion_list_set(ptr %v80, i64 0, i64 %v80.lp0)
    %v80.lp1 = ptrtoint ptr %v79 to i64
    call void @orion_list_set(ptr %v80, i64 1, i64 %v80.lp1)
    %v81 = call ptr @json__jobj(ptr %v75, ptr %v80)
    %v82 = call ptr @json__json_stringify(ptr %v81)
    %v83 = call ptr @json__json_parse(ptr %v82)
    %v84 = getelementptr i8, ptr @.str_14, i64 16
    %v85 = call i64 @json__json_int(ptr %v83, ptr %v84)
    %v86 = add i64 0, 42
    %v87.b = icmp eq i64 %v85, %v86
    %v87 = zext i1 %v87.b to i64
    %v88.cb = icmp ne i64 %v87, 0
    br i1 %v88.cb, label %if_88_then, label %if_88_else
if_88_then:
    %v90 = getelementptr i8, ptr @.str_15, i64 16
    %v91 = call ptr @json__json_text(ptr %v83, ptr %v90)
    %v92 = getelementptr i8, ptr @.str_16, i64 16
    %v93.e = call i64 @orion_text_eq(ptr %v91, ptr %v92)
    %v93 = add i64 %v93.e, 0
    br label %if_88_merge
if_88_else:
    %v96 = add i64 0, 0
    br label %if_88_merge
if_88_merge:
    %v99 = phi i64 [ %v93, %if_88_then ], [ %v96, %if_88_else ]
    %v100.cb = icmp ne i64 %v99, 0
    br i1 %v100.cb, label %if_100_then, label %if_100_else
if_100_then:
    %v102 = add i64 0, 1
    br label %if_100_merge
if_100_else:
    %v105 = add i64 0, 0
    br label %if_100_merge
if_100_merge:
    %v108 = phi i64 [ %v102, %if_100_then ], [ %v105, %if_100_else ]
    %v109 = add i64 0, 16
    %v110 = mul i64 %v19, %v109
    %v111 = add i64 0, 16
    %v112 = mul i64 %v58, %v111
    %v113 = add i64 %v110, %v112
    %v114 = add i64 0, 16
    %v115 = mul i64 %v72, %v114
    %v116 = add i64 %v113, %v115
    %v117 = add i64 0, 16
    %v118 = mul i64 %v108, %v117
    %v119 = add i64 %v116, %v118
    ret i64 %v119
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
