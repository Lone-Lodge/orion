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
declare i64 @orion_mic_open(i64)
declare i64 @orion_mic_level()
declare i64 @orion_mic_buffered()
declare i64 @orion_mic_rate()
declare i64 @orion_mic_take_wav(ptr)
declare void @orion_mic_close()
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


@.str_0 = private unnamed_addr constant [22 x i8] c"\F5\CC\B9\0A\00\00\00\00\05\00\00\00\00\00\00\00orion\00", align 8
@.str_1 = private unnamed_addr constant [18 x i8] c"\F0\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00a\00", align 8
@.str_2 = private unnamed_addr constant [18 x i8] c"\F1\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00b\00", align 8
@.str_3 = private unnamed_addr constant [18 x i8] c"\F2\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00c\00", align 8
@.str_4 = private unnamed_addr constant [22 x i8] c"\CE\1D\48\36\00\00\00\00\05\00\00\00\00\00\00\00a1b2c\00", align 8
@.str_5 = private unnamed_addr constant [18 x i8] c"\BC\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00-\00", align 8
@.str_6 = private unnamed_addr constant [34 x i8] c"\2F\39\1C\1B\00\00\00\00\11\00\00\00\00\00\00\00orion-orion-orion\00", align 8
@.str_7 = private unnamed_addr constant [19 x i8] c"\B4\44\81\05\00\00\00\00\02\00\00\00\00\00\00\00n=\00", align 8
@.str_8 = private unnamed_addr constant [18 x i8] c"\B0\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00!\00", align 8
@.str_9 = private unnamed_addr constant [22 x i8] c"\83\FC\9C\2D\00\00\00\00\05\00\00\00\00\00\00\00n=-7!\00", align 8
@.str_10 = private unnamed_addr constant [18 x i8] c"\EA\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00[\00", align 8
@.str_11 = private unnamed_addr constant [19 x i8] c"\1F\3C\81\05\00\00\00\00\02\00\00\00\00\00\00\00][\00", align 8
@.str_12 = private unnamed_addr constant [18 x i8] c"\EC\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00]\00", align 8
@.str_13 = private unnamed_addr constant [26 x i8] c"\19\C2\F5\0B\00\00\00\00\09\00\00\00\00\00\00\00[0][0][0]\00", align 8
@.str_14 = private unnamed_addr constant [18 x i8] c"\05\C2\0A\00\00\00\00\00\01\00\00\00\00\00\00\00v\00", align 8
@.str_15 = private unnamed_addr constant [38 x i8] c"\33\6C\53\07\00\00\00\00\15\00\00\00\00\00\00\00v1234567890123456789v\00", align 8
@.str_16 = private unnamed_addr constant [18 x i8] c"\0A\C2\0A\00\00\00\00\00\01\00\00\00\00\00\00\00{\00", align 8
@.str_17 = private unnamed_addr constant [19 x i8] c"\51\4C\81\05\00\00\00\00\02\00\00\00\00\00\00\00}-\00", align 8
@.str_18 = private unnamed_addr constant [22 x i8] c"\03\61\DD\21\00\00\00\00\05\00\00\00\00\00\00\00{1}-2\00", align 8
@.str_19 = private unnamed_addr constant [21 x i8] c"\07\E1\7E\39\00\00\00\00\04\00\00\00\00\00\00\00sum=\00", align 8
@.str_20 = private unnamed_addr constant [18 x i8] c"\BE\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00/\00", align 8
@.str_21 = private unnamed_addr constant [18 x i8] c"\BD\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00.\00", align 8
@.str_22 = private unnamed_addr constant [25 x i8] c"\96\A7\D1\36\00\00\00\00\08\00\00\00\00\00\00\00sum=3/2.\00", align 8

define i64 @orion_main() {
entry:
    %v4 = alloca i64, align 8
    %v0 = add i64 0, 1
    %v1 = add i64 0, 2
    %v2 = getelementptr i8, ptr @.str_0, i64 16
    %v3 = add i64 0, 0
    store i64 %v3, ptr %v4
    %v5 = add i64 0, 0
    %v6 = getelementptr i8, ptr @.str_1, i64 16
    %v7 = call ptr @orion_int_to_text(i64 %v0)
    %v8 = getelementptr i8, ptr @.str_2, i64 16
    %v9 = call ptr @orion_int_to_text(i64 %v1)
    %v10 = getelementptr i8, ptr @.str_3, i64 16
    %v11 = call ptr @orion_list_new(i64 5)
    %v11.lp0 = ptrtoint ptr %v6 to i64
    call void @orion_list_set(ptr %v11, i64 0, i64 %v11.lp0)
    %v11.lp1 = ptrtoint ptr %v7 to i64
    call void @orion_list_set(ptr %v11, i64 1, i64 %v11.lp1)
    %v11.lp2 = ptrtoint ptr %v8 to i64
    call void @orion_list_set(ptr %v11, i64 2, i64 %v11.lp2)
    %v11.lp3 = ptrtoint ptr %v9 to i64
    call void @orion_list_set(ptr %v11, i64 3, i64 %v11.lp3)
    %v11.lp4 = ptrtoint ptr %v10 to i64
    call void @orion_list_set(ptr %v11, i64 4, i64 %v11.lp4)
    %v12 = call ptr @orion_text_join(ptr %v11)
    %v13 = getelementptr i8, ptr @.str_4, i64 16
    %v14.e = call i64 @orion_text_eq(ptr %v12, ptr %v13)
    %v14 = add i64 %v14.e, 0
    %v15.cb = icmp ne i64 %v14, 0
    br i1 %v15.cb, label %if_15_then, label %if_15_else
if_15_then:
    %v17 = load i64, ptr %v4
    %v18 = add i64 0, 1
    %v19 = add i64 %v17, %v18
    store i64 %v19, ptr %v4
    %v20 = add i64 0, 0
    br label %if_15_merge
if_15_else:
    br label %if_15_merge
if_15_merge:
    %v25 = getelementptr i8, ptr @.str_5, i64 16
    %v26 = getelementptr i8, ptr @.str_5, i64 16
    %v27 = call ptr @orion_list_new(i64 5)
    %v27.lp0 = ptrtoint ptr %v2 to i64
    call void @orion_list_set(ptr %v27, i64 0, i64 %v27.lp0)
    %v27.lp1 = ptrtoint ptr %v25 to i64
    call void @orion_list_set(ptr %v27, i64 1, i64 %v27.lp1)
    %v27.lp2 = ptrtoint ptr %v2 to i64
    call void @orion_list_set(ptr %v27, i64 2, i64 %v27.lp2)
    %v27.lp3 = ptrtoint ptr %v26 to i64
    call void @orion_list_set(ptr %v27, i64 3, i64 %v27.lp3)
    %v27.lp4 = ptrtoint ptr %v2 to i64
    call void @orion_list_set(ptr %v27, i64 4, i64 %v27.lp4)
    %v28 = call ptr @orion_text_join(ptr %v27)
    %v29 = getelementptr i8, ptr @.str_6, i64 16
    %v30.e = call i64 @orion_text_eq(ptr %v28, ptr %v29)
    %v30 = add i64 %v30.e, 0
    %v31.cb = icmp ne i64 %v30, 0
    br i1 %v31.cb, label %if_31_then, label %if_31_else
if_31_then:
    %v33 = load i64, ptr %v4
    %v34 = add i64 0, 1
    %v35 = add i64 %v33, %v34
    store i64 %v35, ptr %v4
    %v36 = add i64 0, 0
    br label %if_31_merge
if_31_else:
    br label %if_31_merge
if_31_merge:
    %v41 = add i64 0, 0
    %v42 = add i64 0, 7
    %v43 = sub i64 %v41, %v42
    %v44 = getelementptr i8, ptr @.str_7, i64 16
    %v45 = call ptr @orion_int_to_text(i64 %v43)
    %v46 = getelementptr i8, ptr @.str_8, i64 16
    %v47 = call ptr @orion_list_new(i64 3)
    %v47.lp0 = ptrtoint ptr %v44 to i64
    call void @orion_list_set(ptr %v47, i64 0, i64 %v47.lp0)
    %v47.lp1 = ptrtoint ptr %v45 to i64
    call void @orion_list_set(ptr %v47, i64 1, i64 %v47.lp1)
    %v47.lp2 = ptrtoint ptr %v46 to i64
    call void @orion_list_set(ptr %v47, i64 2, i64 %v47.lp2)
    %v48 = call ptr @orion_text_join(ptr %v47)
    %v49 = getelementptr i8, ptr @.str_9, i64 16
    %v50.e = call i64 @orion_text_eq(ptr %v48, ptr %v49)
    %v50 = add i64 %v50.e, 0
    %v51.cb = icmp ne i64 %v50, 0
    br i1 %v51.cb, label %if_51_then, label %if_51_else
if_51_then:
    %v53 = load i64, ptr %v4
    %v54 = add i64 0, 1
    %v55 = add i64 %v53, %v54
    store i64 %v55, ptr %v4
    %v56 = add i64 0, 0
    br label %if_51_merge
if_51_else:
    br label %if_51_merge
if_51_merge:
    %v61 = add i64 0, 0
    %v62 = getelementptr i8, ptr @.str_10, i64 16
    %v63 = call ptr @orion_int_to_text(i64 %v61)
    %v64 = getelementptr i8, ptr @.str_11, i64 16
    %v65 = call ptr @orion_int_to_text(i64 %v61)
    %v66 = getelementptr i8, ptr @.str_11, i64 16
    %v67 = call ptr @orion_int_to_text(i64 %v61)
    %v68 = getelementptr i8, ptr @.str_12, i64 16
    %v69 = call ptr @orion_list_new(i64 7)
    %v69.lp0 = ptrtoint ptr %v62 to i64
    call void @orion_list_set(ptr %v69, i64 0, i64 %v69.lp0)
    %v69.lp1 = ptrtoint ptr %v63 to i64
    call void @orion_list_set(ptr %v69, i64 1, i64 %v69.lp1)
    %v69.lp2 = ptrtoint ptr %v64 to i64
    call void @orion_list_set(ptr %v69, i64 2, i64 %v69.lp2)
    %v69.lp3 = ptrtoint ptr %v65 to i64
    call void @orion_list_set(ptr %v69, i64 3, i64 %v69.lp3)
    %v69.lp4 = ptrtoint ptr %v66 to i64
    call void @orion_list_set(ptr %v69, i64 4, i64 %v69.lp4)
    %v69.lp5 = ptrtoint ptr %v67 to i64
    call void @orion_list_set(ptr %v69, i64 5, i64 %v69.lp5)
    %v69.lp6 = ptrtoint ptr %v68 to i64
    call void @orion_list_set(ptr %v69, i64 6, i64 %v69.lp6)
    %v70 = call ptr @orion_text_join(ptr %v69)
    %v71 = getelementptr i8, ptr @.str_13, i64 16
    %v72.e = call i64 @orion_text_eq(ptr %v70, ptr %v71)
    %v72 = add i64 %v72.e, 0
    %v73.cb = icmp ne i64 %v72, 0
    br i1 %v73.cb, label %if_73_then, label %if_73_else
if_73_then:
    %v75 = load i64, ptr %v4
    %v76 = add i64 0, 1
    %v77 = add i64 %v75, %v76
    store i64 %v77, ptr %v4
    %v78 = add i64 0, 0
    br label %if_73_merge
if_73_else:
    br label %if_73_merge
if_73_merge:
    %v83 = add i64 0, 1234567890123456789
    %v84 = getelementptr i8, ptr @.str_14, i64 16
    %v85 = call ptr @orion_int_to_text(i64 %v83)
    %v86 = getelementptr i8, ptr @.str_14, i64 16
    %v87 = call ptr @orion_list_new(i64 3)
    %v87.lp0 = ptrtoint ptr %v84 to i64
    call void @orion_list_set(ptr %v87, i64 0, i64 %v87.lp0)
    %v87.lp1 = ptrtoint ptr %v85 to i64
    call void @orion_list_set(ptr %v87, i64 1, i64 %v87.lp1)
    %v87.lp2 = ptrtoint ptr %v86 to i64
    call void @orion_list_set(ptr %v87, i64 2, i64 %v87.lp2)
    %v88 = call ptr @orion_text_join(ptr %v87)
    %v89 = getelementptr i8, ptr @.str_15, i64 16
    %v90.e = call i64 @orion_text_eq(ptr %v88, ptr %v89)
    %v90 = add i64 %v90.e, 0
    %v91.cb = icmp ne i64 %v90, 0
    br i1 %v91.cb, label %if_91_then, label %if_91_else
if_91_then:
    %v93 = load i64, ptr %v4
    %v94 = add i64 0, 1
    %v95 = add i64 %v93, %v94
    store i64 %v95, ptr %v4
    %v96 = add i64 0, 0
    br label %if_91_merge
if_91_else:
    br label %if_91_merge
if_91_merge:
    %v101 = getelementptr i8, ptr @.str_16, i64 16
    %v102 = call ptr @orion_int_to_text(i64 %v0)
    %v103 = getelementptr i8, ptr @.str_17, i64 16
    %v104 = call ptr @orion_int_to_text(i64 %v1)
    %v105 = call ptr @orion_list_new(i64 4)
    %v105.lp0 = ptrtoint ptr %v101 to i64
    call void @orion_list_set(ptr %v105, i64 0, i64 %v105.lp0)
    %v105.lp1 = ptrtoint ptr %v102 to i64
    call void @orion_list_set(ptr %v105, i64 1, i64 %v105.lp1)
    %v105.lp2 = ptrtoint ptr %v103 to i64
    call void @orion_list_set(ptr %v105, i64 2, i64 %v105.lp2)
    %v105.lp3 = ptrtoint ptr %v104 to i64
    call void @orion_list_set(ptr %v105, i64 3, i64 %v105.lp3)
    %v106 = call ptr @orion_text_join(ptr %v105)
    %v107 = getelementptr i8, ptr @.str_18, i64 16
    %v108.e = call i64 @orion_text_eq(ptr %v106, ptr %v107)
    %v108 = add i64 %v108.e, 0
    %v109.cb = icmp ne i64 %v108, 0
    br i1 %v109.cb, label %if_109_then, label %if_109_else
if_109_then:
    %v111 = load i64, ptr %v4
    %v112 = add i64 0, 1
    %v113 = add i64 %v111, %v112
    store i64 %v113, ptr %v4
    %v114 = add i64 0, 0
    br label %if_109_merge
if_109_else:
    br label %if_109_merge
if_109_merge:
    %v119 = getelementptr i8, ptr @.str_0, i64 16
    %v120.e = call i64 @orion_text_eq(ptr %v2, ptr %v119)
    %v120 = add i64 %v120.e, 0
    %v121.cb = icmp ne i64 %v120, 0
    br i1 %v121.cb, label %if_121_then, label %if_121_else
if_121_then:
    %v123 = load i64, ptr %v4
    %v124 = add i64 0, 1
    %v125 = add i64 %v123, %v124
    store i64 %v125, ptr %v4
    %v126 = add i64 0, 0
    br label %if_121_merge
if_121_else:
    br label %if_121_merge
if_121_merge:
    %v131 = getelementptr i8, ptr @.str_19, i64 16
    %v132 = add i64 %v0, %v1
    %v133 = call ptr @orion_int_to_text(i64 %v132)
    %v134 = getelementptr i8, ptr @.str_20, i64 16
    %v135 = mul i64 %v0, %v1
    %v136 = call ptr @orion_int_to_text(i64 %v135)
    %v137 = getelementptr i8, ptr @.str_21, i64 16
    %v138 = call ptr @orion_list_new(i64 5)
    %v138.lp0 = ptrtoint ptr %v131 to i64
    call void @orion_list_set(ptr %v138, i64 0, i64 %v138.lp0)
    %v138.lp1 = ptrtoint ptr %v133 to i64
    call void @orion_list_set(ptr %v138, i64 1, i64 %v138.lp1)
    %v138.lp2 = ptrtoint ptr %v134 to i64
    call void @orion_list_set(ptr %v138, i64 2, i64 %v138.lp2)
    %v138.lp3 = ptrtoint ptr %v136 to i64
    call void @orion_list_set(ptr %v138, i64 3, i64 %v138.lp3)
    %v138.lp4 = ptrtoint ptr %v137 to i64
    call void @orion_list_set(ptr %v138, i64 4, i64 %v138.lp4)
    %v139 = call ptr @orion_text_join(ptr %v138)
    %v140 = getelementptr i8, ptr @.str_22, i64 16
    %v141.e = call i64 @orion_text_eq(ptr %v139, ptr %v140)
    %v141 = add i64 %v141.e, 0
    %v142.cb = icmp ne i64 %v141, 0
    br i1 %v142.cb, label %if_142_then, label %if_142_else
if_142_then:
    %v144 = load i64, ptr %v4
    %v145 = add i64 0, 1
    %v146 = add i64 %v144, %v145
    store i64 %v146, ptr %v4
    %v147 = add i64 0, 0
    br label %if_142_merge
if_142_else:
    br label %if_142_merge
if_142_merge:
    %v152 = call i64 @orion_tlen(ptr %v12)
    %v153 = call i64 @orion_tlen(ptr %v48)
    %v154 = add i64 %v152, %v153
    %v155 = add i64 0, 5
    %v156 = add i64 0, 5
    %v157 = add i64 %v155, %v156
    %v158.b = icmp eq i64 %v154, %v157
    %v158 = zext i1 %v158.b to i64
    %v159.cb = icmp ne i64 %v158, 0
    br i1 %v159.cb, label %if_159_then, label %if_159_else
if_159_then:
    %v161 = load i64, ptr %v4
    %v162 = add i64 0, 1
    %v163 = add i64 %v161, %v162
    store i64 %v163, ptr %v4
    %v164 = add i64 0, 0
    br label %if_159_merge
if_159_else:
    br label %if_159_merge
if_159_merge:
    %v169 = load i64, ptr %v4
    %v170 = add i64 0, 9
    %v171.b = icmp eq i64 %v169, %v170
    %v171 = zext i1 %v171.b to i64
    %v172.cb = icmp ne i64 %v171, 0
    br i1 %v172.cb, label %if_172_then, label %if_172_else
if_172_then:
    %v174 = add i64 0, 42
    br label %if_172_merge
if_172_else:
    %v177 = load i64, ptr %v4
    br label %if_172_merge
if_172_merge:
    %v180 = phi i64 [ %v174, %if_172_then ], [ %v177, %if_172_else ]
    ret i64 %v180
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
