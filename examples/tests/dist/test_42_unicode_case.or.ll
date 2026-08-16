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


@.str_0 = private unnamed_addr constant [17 x i8] c"\05\15\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00", align 8
@.str_1 = private unnamed_addr constant [18 x i8] c"\99\C1\0A\00\00\00\00\00\01\00\00\00\00\00\00\00\0A\00", align 8
@.str_2 = private unnamed_addr constant [30 x i8] c"\20\90\DD\39\00\00\00\00\0D\00\00\00\00\00\00\00\C3\A5sa \C3\A4r glad\00", align 8
@.str_3 = private unnamed_addr constant [30 x i8] c"\8D\1E\AA\07\00\00\00\00\0D\00\00\00\00\00\00\00\C3\85SA \C3\84R GLAD\00", align 8
@.str_4 = private unnamed_addr constant [30 x i8] c"\3D\D8\AD\31\00\00\00\00\0D\00\00\00\00\00\00\00R\C3\84KSM\C3\96RG\C3\85S\00", align 8
@.str_5 = private unnamed_addr constant [30 x i8] c"\AB\90\16\1B\00\00\00\00\0D\00\00\00\00\00\00\00r\C3\A4ksm\C3\B6rg\C3\A5s\00", align 8
@.str_6 = private unnamed_addr constant [25 x i8] c"\41\00\0D\10\00\00\00\00\08\00\00\00\00\00\00\00\CE\BF\CE\B4\CF\8C\CF\82\00", align 8
@.str_7 = private unnamed_addr constant [25 x i8] c"\75\B9\2A\25\00\00\00\00\08\00\00\00\00\00\00\00\CE\9F\CE\94\CE\8C\CE\A3\00", align 8
@.str_8 = private unnamed_addr constant [33 x i8] c"\C1\56\79\38\00\00\00\00\10\00\00\00\00\00\00\00\CE\95\CE\9B\CE\9B\CE\97\CE\9D\CE\99\CE\9A\CE\86\00", align 8
@.str_9 = private unnamed_addr constant [33 x i8] c"\CF\A9\C1\23\00\00\00\00\10\00\00\00\00\00\00\00\CE\B5\CE\BB\CE\BB\CE\B7\CE\BD\CE\B9\CE\BA\CE\AC\00", align 8
@.str_10 = private unnamed_addr constant [32 x i8] c"\5C\A1\3C\0D\00\00\00\00\0F\00\00\00\00\00\00\00\D0\BF\D1\80\D0\B8\D0\B2\D0\B5\D1\82 \D1\90\00", align 8
@.str_11 = private unnamed_addr constant [32 x i8] c"\AD\09\8E\03\00\00\00\00\0F\00\00\00\00\00\00\00\D0\9F\D0\A0\D0\98\D0\92\D0\95\D0\A2 \D0\80\00", align 8
@.str_12 = private unnamed_addr constant [29 x i8] c"\00\5F\93\12\00\00\00\00\0C\00\00\00\00\00\00\00\D0\9F\D0\A0\D0\98\D0\92\D0\95\D0\A2\00", align 8
@.str_13 = private unnamed_addr constant [29 x i8] c"\67\AB\A9\20\00\00\00\00\0C\00\00\00\00\00\00\00\D0\BF\D1\80\D0\B8\D0\B2\D0\B5\D1\82\00", align 8
@.str_14 = private unnamed_addr constant [26 x i8] c"\3F\BC\ED\09\00\00\00\00\09\00\00\00\00\00\00\00\C4\8De\C5\A1tina\00", align 8
@.str_15 = private unnamed_addr constant [26 x i8] c"\3E\A5\63\39\00\00\00\00\09\00\00\00\00\00\00\00\C4\8CE\C5\A0TINA\00", align 8
@.str_16 = private unnamed_addr constant [29 x i8] c"\DC\B7\88\22\00\00\00\00\0C\00\00\00\00\00\00\00\E6\97\A5\E6\9C\AC\E8\AA\9E ok\00", align 8
@.str_17 = private unnamed_addr constant [29 x i8] c"\5C\A7\88\22\00\00\00\00\0C\00\00\00\00\00\00\00\E6\97\A5\E6\9C\AC\E8\AA\9E OK\00", align 8
@.str_18 = private unnamed_addr constant [21 x i8] c"\56\EC\A8\08\00\00\00\00\04\00\00\00\00\00\00\00\C3\A5sa\00", align 8

define i64 @text__is_empty(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = call i64 @orion_tlen(ptr %v0)
    %v2 = add i64 0, 0
    %v3.b = icmp eq i64 %v1, %v2
    %v3 = zext i1 %v3.b to i64
    ret i64 %v3
}

define i64 @text__byte_count(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = call ptr @orion_bytes_from_text(ptr %v0)
    %v2 = call i64 @orion_list_len(ptr %v1)
    ret i64 %v2
}

define i64 @text__starts_with(ptr %p0, ptr %p1) {
entry:
    %v15 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = call ptr @orion_bytes_from_text(ptr %v0)
    %v3 = call ptr @orion_bytes_from_text(ptr %v1)
    %v4 = call i64 @orion_list_len(ptr %v2)
    %v5 = call i64 @orion_list_len(ptr %v3)
    %v6.b = icmp sgt i64 %v5, %v4
    %v6 = zext i1 %v6.b to i64
    %v7.cb = icmp ne i64 %v6, 0
    br i1 %v7.cb, label %if_7_then, label %if_7_else
if_7_then:
    %v9 = add i64 0, 0
    ret i64 %v9
if_7_else:
    br label %if_7_merge
if_7_merge:
    %v14 = add i64 0, 0
    store i64 %v14, ptr %v15
    %v16 = add i64 0, 0
    br label %for_14_header
for_14_header:
    %v19 = load i64, ptr %v15
    %v20.b = icmp slt i64 %v19, %v5
    %v20 = zext i1 %v20.b to i64
    %v21.cb = icmp ne i64 %v20, 0
    br i1 %v21.cb, label %for_14_body, label %for_14_end
for_14_body:
    %v23 = call i64 @orion_list_at(ptr %v2, i64 %v19)
    %v24 = call i64 @orion_list_at(ptr %v3, i64 %v19)
    %v25.b = icmp ne i64 %v23, %v24
    %v25 = zext i1 %v25.b to i64
    %v26.cb = icmp ne i64 %v25, 0
    br i1 %v26.cb, label %if_26_then, label %if_26_else
if_26_then:
    %v28 = add i64 0, 0
    ret i64 %v28
if_26_else:
    br label %if_26_merge
if_26_merge:
    br label %for_14_step
for_14_step:
    %v35 = add i64 0, 1
    %v36 = add i64 %v19, %v35
    store i64 %v36, ptr %v15
    %v37 = add i64 0, 0
    br label %for_14_header
for_14_end:
    %v40 = add i64 0, 1
    ret i64 %v40
}

define i64 @text__ends_with(ptr %p0, ptr %p1) {
entry:
    %v16 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = call ptr @orion_bytes_from_text(ptr %v0)
    %v3 = call ptr @orion_bytes_from_text(ptr %v1)
    %v4 = call i64 @orion_list_len(ptr %v2)
    %v5 = call i64 @orion_list_len(ptr %v3)
    %v6.b = icmp sgt i64 %v5, %v4
    %v6 = zext i1 %v6.b to i64
    %v7.cb = icmp ne i64 %v6, 0
    br i1 %v7.cb, label %if_7_then, label %if_7_else
if_7_then:
    %v9 = add i64 0, 0
    ret i64 %v9
if_7_else:
    br label %if_7_merge
if_7_merge:
    %v14 = sub i64 %v4, %v5
    %v15 = add i64 0, 0
    store i64 %v15, ptr %v16
    %v17 = add i64 0, 0
    br label %for_15_header
for_15_header:
    %v20 = load i64, ptr %v16
    %v21.b = icmp slt i64 %v20, %v5
    %v21 = zext i1 %v21.b to i64
    %v22.cb = icmp ne i64 %v21, 0
    br i1 %v22.cb, label %for_15_body, label %for_15_end
for_15_body:
    %v24 = add i64 %v20, %v14
    %v25 = call i64 @orion_list_at(ptr %v2, i64 %v24)
    %v26 = call i64 @orion_list_at(ptr %v3, i64 %v20)
    %v27.b = icmp ne i64 %v25, %v26
    %v27 = zext i1 %v27.b to i64
    %v28.cb = icmp ne i64 %v27, 0
    br i1 %v28.cb, label %if_28_then, label %if_28_else
if_28_then:
    %v30 = add i64 0, 0
    ret i64 %v30
if_28_else:
    br label %if_28_merge
if_28_merge:
    br label %for_15_step
for_15_step:
    %v37 = add i64 0, 1
    %v38 = add i64 %v20, %v37
    store i64 %v38, ptr %v16
    %v39 = add i64 0, 0
    br label %for_15_header
for_15_end:
    %v42 = add i64 0, 1
    ret i64 %v42
}

define ptr @text__repeat(ptr %p0, i64 %p1) {
entry:
    %v3 = alloca ptr, align 8
    %v10 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr @.str_0, i64 16
    store ptr %v2, ptr %v3
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    %v6.b = icmp sgt i64 %v1, %v5
    %v6 = zext i1 %v6.b to i64
    %v7.cb = icmp ne i64 %v6, 0
    br i1 %v7.cb, label %if_7_then, label %if_7_else
if_7_then:
    %v9 = add i64 0, 0
    store i64 %v9, ptr %v10
    %v11 = add i64 0, 0
    br label %for_9_header
for_9_header:
    %v14 = load i64, ptr %v10
    %v15.b = icmp slt i64 %v14, %v1
    %v15 = zext i1 %v15.b to i64
    %v16.cb = icmp ne i64 %v15, 0
    br i1 %v16.cb, label %for_9_body, label %for_9_end
for_9_body:
    %v18 = load ptr, ptr %v3
    %v19 = call ptr @orion_text_concat(ptr %v18, ptr %v0)
    store ptr %v19, ptr %v3
    %v20 = add i64 0, 0
    br label %for_9_step
for_9_step:
    %v23 = add i64 0, 1
    %v24 = add i64 %v14, %v23
    store i64 %v24, ptr %v10
    %v25 = add i64 0, 0
    br label %for_9_header
for_9_end:
    br label %if_7_merge
if_7_else:
    br label %if_7_merge
if_7_merge:
    %v32 = load ptr, ptr %v3
    ret ptr %v32
}

define ptr @text__reverse(ptr %p0) {
entry:
    %v5 = alloca ptr, align 8
    %v8 = alloca i64, align 8
    %v23 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = call ptr @orion_bytes_from_text(ptr %v0)
    %v2 = call i64 @orion_list_len(ptr %v1)
    %v3 = add i64 0, 0
    %v4 = call ptr @orion_bytes_zeros(i64 %v3)
    store ptr %v4, ptr %v5
    %v6 = add i64 0, 0
    %v7 = add i64 0, 0
    store i64 %v7, ptr %v8
    %v9 = add i64 0, 0
    br label %loop_10_header
loop_10_header:
    %v12 = load i64, ptr %v8
    %v13.b = icmp sge i64 %v12, %v2
    %v13 = zext i1 %v13.b to i64
    %v14.cb = icmp ne i64 %v13, 0
    br i1 %v14.cb, label %if_14_then, label %if_14_else
if_14_then:
    br label %loop_10_end
if_14_else:
    br label %if_14_merge
if_14_merge:
    %v20 = load i64, ptr %v8
    %v21 = add i64 0, 1
    %v22 = add i64 %v20, %v21
    store i64 %v22, ptr %v23
    %v24 = add i64 0, 0
    br label %loop_25_header
loop_25_header:
    %v27 = load i64, ptr %v23
    %v28.b = icmp sge i64 %v27, %v2
    %v28 = zext i1 %v28.b to i64
    %v29.cb = icmp ne i64 %v28, 0
    br i1 %v29.cb, label %if_29_then, label %if_29_else
if_29_then:
    br label %loop_25_end
if_29_else:
    br label %if_29_merge
if_29_merge:
    %v35 = load i64, ptr %v23
    %v36 = call i64 @orion_list_at(ptr %v1, i64 %v35)
    %v37 = add i64 0, 128
    %v38.b = icmp sge i64 %v36, %v37
    %v38 = zext i1 %v38.b to i64
    %v39.cb = icmp ne i64 %v38, 0
    br i1 %v39.cb, label %if_39_then, label %if_39_else
if_39_then:
    %v41 = add i64 0, 192
    %v42.b = icmp slt i64 %v36, %v41
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
    %v51 = load i64, ptr %v23
    %v52 = add i64 0, 1
    %v53 = add i64 %v51, %v52
    store i64 %v53, ptr %v23
    %v54 = add i64 0, 0
    br label %if_49_merge
if_49_else:
    br label %loop_25_end
if_49_merge:
    br label %loop_25_header
loop_25_end:
    %v61 = load i64, ptr %v8
    %v62 = load i64, ptr %v23
    %v63 = call ptr @orion_bytes_slice(ptr %v1, i64 %v61, i64 %v62)
    %v64 = load ptr, ptr %v5
    %v65 = call ptr @orion_bytes_concat(ptr %v63, ptr %v64)
    store ptr %v65, ptr %v5
    %v66 = add i64 0, 0
    %v67 = load i64, ptr %v23
    store i64 %v67, ptr %v8
    %v68 = add i64 0, 0
    br label %loop_10_header
loop_10_end:
    %v71 = load ptr, ptr %v5
    %v72 = call ptr @orion_bytes_to_text(ptr %v71)
    ret ptr %v72
}

define i64 @text__cp_size(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, 128
    %v2.b = icmp slt i64 %v0, %v1
    %v2 = zext i1 %v2.b to i64
    %v3.cb = icmp ne i64 %v2, 0
    br i1 %v3.cb, label %if_3_then, label %if_3_else
if_3_then:
    %v5 = add i64 0, 1
    br label %if_3_merge
if_3_else:
    %v8 = add i64 0, 224
    %v9.b = icmp slt i64 %v0, %v8
    %v9 = zext i1 %v9.b to i64
    %v10.cb = icmp ne i64 %v9, 0
    br i1 %v10.cb, label %if_10_then, label %if_10_else
if_10_then:
    %v12 = add i64 0, 2
    br label %if_10_merge
if_10_else:
    %v15 = add i64 0, 240
    %v16.b = icmp slt i64 %v0, %v15
    %v16 = zext i1 %v16.b to i64
    %v17.cb = icmp ne i64 %v16, 0
    br i1 %v17.cb, label %if_17_then, label %if_17_else
if_17_then:
    %v19 = add i64 0, 3
    br label %if_17_merge
if_17_else:
    %v22 = add i64 0, 4
    br label %if_17_merge
if_17_merge:
    %v25 = phi i64 [ %v19, %if_17_then ], [ %v22, %if_17_else ]
    br label %if_10_merge
if_10_merge:
    %v28 = phi i64 [ %v12, %if_10_then ], [ %v25, %if_17_merge ]
    br label %if_3_merge
if_3_merge:
    %v31 = phi i64 [ %v5, %if_3_then ], [ %v28, %if_10_merge ]
    ret i64 %v31
}

define i64 @text__cp_at(ptr %p0, i64 %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = call i64 @orion_list_len(ptr %v0)
    %v3 = call i64 @orion_list_at(ptr %v0, i64 %v1)
    %v4 = call i64 @text__cp_size(i64 %v3)
    %v5 = add i64 %v1, %v4
    %v6.b = icmp sgt i64 %v5, %v2
    %v6 = zext i1 %v6.b to i64
    %v7.cb = icmp ne i64 %v6, 0
    br i1 %v7.cb, label %if_7_then, label %if_7_else
if_7_then:
    br label %if_7_merge
if_7_else:
    %v11 = add i64 0, 1
    %v12.b = icmp eq i64 %v4, %v11
    %v12 = zext i1 %v12.b to i64
    %v13.cb = icmp ne i64 %v12, 0
    br i1 %v13.cb, label %if_13_then, label %if_13_else
if_13_then:
    br label %if_13_merge
if_13_else:
    %v17 = add i64 0, 2
    %v18.b = icmp eq i64 %v4, %v17
    %v18 = zext i1 %v18.b to i64
    %v19.cb = icmp ne i64 %v18, 0
    br i1 %v19.cb, label %if_19_then, label %if_19_else
if_19_then:
    %v21 = add i64 0, 31
    %v22 = and i64 %v3, %v21
    %v23 = add i64 0, 6
    %v24 = shl i64 %v22, %v23
    %v25 = add i64 0, 1
    %v26 = add i64 %v1, %v25
    %v27 = call i64 @orion_list_at(ptr %v0, i64 %v26)
    %v28 = add i64 0, 63
    %v29 = and i64 %v27, %v28
    %v30 = or i64 %v24, %v29
    br label %if_19_merge
if_19_else:
    %v33 = add i64 0, 3
    %v34.b = icmp eq i64 %v4, %v33
    %v34 = zext i1 %v34.b to i64
    %v35.cb = icmp ne i64 %v34, 0
    br i1 %v35.cb, label %if_35_then, label %if_35_else
if_35_then:
    %v37 = add i64 0, 15
    %v38 = and i64 %v3, %v37
    %v39 = add i64 0, 12
    %v40 = shl i64 %v38, %v39
    %v41 = add i64 0, 1
    %v42 = add i64 %v1, %v41
    %v43 = call i64 @orion_list_at(ptr %v0, i64 %v42)
    %v44 = add i64 0, 63
    %v45 = and i64 %v43, %v44
    %v46 = add i64 0, 6
    %v47 = shl i64 %v45, %v46
    %v48 = or i64 %v40, %v47
    %v49 = add i64 0, 2
    %v50 = add i64 %v1, %v49
    %v51 = call i64 @orion_list_at(ptr %v0, i64 %v50)
    %v52 = add i64 0, 63
    %v53 = and i64 %v51, %v52
    %v54 = or i64 %v48, %v53
    br label %if_35_merge
if_35_else:
    %v57 = add i64 0, 7
    %v58 = and i64 %v3, %v57
    %v59 = add i64 0, 18
    %v60 = shl i64 %v58, %v59
    %v61 = add i64 0, 1
    %v62 = add i64 %v1, %v61
    %v63 = call i64 @orion_list_at(ptr %v0, i64 %v62)
    %v64 = add i64 0, 63
    %v65 = and i64 %v63, %v64
    %v66 = add i64 0, 12
    %v67 = shl i64 %v65, %v66
    %v68 = or i64 %v60, %v67
    %v69 = add i64 0, 2
    %v70 = add i64 %v1, %v69
    %v71 = call i64 @orion_list_at(ptr %v0, i64 %v70)
    %v72 = add i64 0, 63
    %v73 = and i64 %v71, %v72
    %v74 = add i64 0, 6
    %v75 = shl i64 %v73, %v74
    %v76 = or i64 %v68, %v75
    %v77 = add i64 0, 3
    %v78 = add i64 %v1, %v77
    %v79 = call i64 @orion_list_at(ptr %v0, i64 %v78)
    %v80 = add i64 0, 63
    %v81 = and i64 %v79, %v80
    %v82 = or i64 %v76, %v81
    br label %if_35_merge
if_35_merge:
    %v85 = phi i64 [ %v54, %if_35_then ], [ %v82, %if_35_else ]
    br label %if_19_merge
if_19_merge:
    %v88 = phi i64 [ %v30, %if_19_then ], [ %v85, %if_35_merge ]
    br label %if_13_merge
if_13_merge:
    %v91 = phi i64 [ %v3, %if_13_then ], [ %v88, %if_19_merge ]
    br label %if_7_merge
if_7_merge:
    %v94 = phi i64 [ %v3, %if_7_then ], [ %v91, %if_13_merge ]
    ret i64 %v94
}

define ptr @text__cp_bytes(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, 128
    %v2.b = icmp slt i64 %v0, %v1
    %v2 = zext i1 %v2.b to i64
    %v3.cb = icmp ne i64 %v2, 0
    br i1 %v3.cb, label %if_3_then, label %if_3_else
if_3_then:
    %v5 = call ptr @orion_list_new(i64 1)
    call void @orion_list_set(ptr %v5, i64 0, i64 %v0)
    br label %if_3_merge
if_3_else:
    %v8 = add i64 0, 2048
    %v9.b = icmp slt i64 %v0, %v8
    %v9 = zext i1 %v9.b to i64
    %v10.cb = icmp ne i64 %v9, 0
    br i1 %v10.cb, label %if_10_then, label %if_10_else
if_10_then:
    %v12 = add i64 0, 192
    %v13 = add i64 0, 6
    %v14 = ashr i64 %v0, %v13
    %v15 = or i64 %v12, %v14
    %v16 = add i64 0, 128
    %v17 = add i64 0, 63
    %v18 = and i64 %v0, %v17
    %v19 = or i64 %v16, %v18
    %v20 = call ptr @orion_list_new(i64 2)
    call void @orion_list_set(ptr %v20, i64 0, i64 %v15)
    call void @orion_list_set(ptr %v20, i64 1, i64 %v19)
    br label %if_10_merge
if_10_else:
    %v23 = add i64 0, 65536
    %v24.b = icmp slt i64 %v0, %v23
    %v24 = zext i1 %v24.b to i64
    %v25.cb = icmp ne i64 %v24, 0
    br i1 %v25.cb, label %if_25_then, label %if_25_else
if_25_then:
    %v27 = add i64 0, 224
    %v28 = add i64 0, 12
    %v29 = ashr i64 %v0, %v28
    %v30 = or i64 %v27, %v29
    %v31 = add i64 0, 128
    %v32 = add i64 0, 6
    %v33 = ashr i64 %v0, %v32
    %v34 = add i64 0, 63
    %v35 = and i64 %v33, %v34
    %v36 = or i64 %v31, %v35
    %v37 = add i64 0, 128
    %v38 = add i64 0, 63
    %v39 = and i64 %v0, %v38
    %v40 = or i64 %v37, %v39
    %v41 = call ptr @orion_list_new(i64 3)
    call void @orion_list_set(ptr %v41, i64 0, i64 %v30)
    call void @orion_list_set(ptr %v41, i64 1, i64 %v36)
    call void @orion_list_set(ptr %v41, i64 2, i64 %v40)
    br label %if_25_merge
if_25_else:
    %v44 = add i64 0, 240
    %v45 = add i64 0, 18
    %v46 = ashr i64 %v0, %v45
    %v47 = or i64 %v44, %v46
    %v48 = add i64 0, 128
    %v49 = add i64 0, 12
    %v50 = ashr i64 %v0, %v49
    %v51 = add i64 0, 63
    %v52 = and i64 %v50, %v51
    %v53 = or i64 %v48, %v52
    %v54 = add i64 0, 128
    %v55 = add i64 0, 6
    %v56 = ashr i64 %v0, %v55
    %v57 = add i64 0, 63
    %v58 = and i64 %v56, %v57
    %v59 = or i64 %v54, %v58
    %v60 = add i64 0, 128
    %v61 = add i64 0, 63
    %v62 = and i64 %v0, %v61
    %v63 = or i64 %v60, %v62
    %v64 = call ptr @orion_list_new(i64 4)
    call void @orion_list_set(ptr %v64, i64 0, i64 %v47)
    call void @orion_list_set(ptr %v64, i64 1, i64 %v53)
    call void @orion_list_set(ptr %v64, i64 2, i64 %v59)
    call void @orion_list_set(ptr %v64, i64 3, i64 %v63)
    br label %if_25_merge
if_25_merge:
    %v67 = phi ptr [ %v41, %if_25_then ], [ %v64, %if_25_else ]
    br label %if_10_merge
if_10_merge:
    %v70 = phi ptr [ %v20, %if_10_then ], [ %v67, %if_25_merge ]
    br label %if_3_merge
if_3_merge:
    %v73 = phi ptr [ %v5, %if_3_then ], [ %v70, %if_10_merge ]
    ret ptr %v73
}

define i64 @text__latin_a_pair_even(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, 256
    %v2.b = icmp sge i64 %v0, %v1
    %v2 = zext i1 %v2.b to i64
    %v3.cb = icmp ne i64 %v2, 0
    br i1 %v3.cb, label %if_3_then, label %if_3_else
if_3_then:
    %v5 = add i64 0, 311
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
    br label %if_13_merge
if_13_else:
    %v17 = add i64 0, 330
    %v18.b = icmp sge i64 %v0, %v17
    %v18 = zext i1 %v18.b to i64
    %v19.cb = icmp ne i64 %v18, 0
    br i1 %v19.cb, label %if_19_then, label %if_19_else
if_19_then:
    %v21 = add i64 0, 375
    %v22.b = icmp sle i64 %v0, %v21
    %v22 = zext i1 %v22.b to i64
    br label %if_19_merge
if_19_else:
    %v25 = add i64 0, 0
    br label %if_19_merge
if_19_merge:
    %v28 = phi i64 [ %v22, %if_19_then ], [ %v25, %if_19_else ]
    br label %if_13_merge
if_13_merge:
    %v31 = phi i64 [ %v12, %if_13_then ], [ %v28, %if_19_merge ]
    ret i64 %v31
}

define i64 @text__latin_a_pair_odd(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, 313
    %v2.b = icmp sge i64 %v0, %v1
    %v2 = zext i1 %v2.b to i64
    %v3.cb = icmp ne i64 %v2, 0
    br i1 %v3.cb, label %if_3_then, label %if_3_else
if_3_then:
    %v5 = add i64 0, 328
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
    br label %if_13_merge
if_13_else:
    %v17 = add i64 0, 377
    %v18.b = icmp sge i64 %v0, %v17
    %v18 = zext i1 %v18.b to i64
    %v19.cb = icmp ne i64 %v18, 0
    br i1 %v19.cb, label %if_19_then, label %if_19_else
if_19_then:
    %v21 = add i64 0, 382
    %v22.b = icmp sle i64 %v0, %v21
    %v22 = zext i1 %v22.b to i64
    br label %if_19_merge
if_19_else:
    %v25 = add i64 0, 0
    br label %if_19_merge
if_19_merge:
    %v28 = phi i64 [ %v22, %if_19_then ], [ %v25, %if_19_else ]
    br label %if_13_merge
if_13_merge:
    %v31 = phi i64 [ %v12, %if_13_then ], [ %v28, %if_19_merge ]
    ret i64 %v31
}

define i64 @text__cyrillic_pair_even(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, 1120
    %v2.b = icmp sge i64 %v0, %v1
    %v2 = zext i1 %v2.b to i64
    %v3.cb = icmp ne i64 %v2, 0
    br i1 %v3.cb, label %if_3_then, label %if_3_else
if_3_then:
    %v5 = add i64 0, 1153
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
    br label %if_13_merge
if_13_else:
    %v17 = add i64 0, 1162
    %v18.b = icmp sge i64 %v0, %v17
    %v18 = zext i1 %v18.b to i64
    %v19.cb = icmp ne i64 %v18, 0
    br i1 %v19.cb, label %if_19_then, label %if_19_else
if_19_then:
    %v21 = add i64 0, 1215
    %v22.b = icmp sle i64 %v0, %v21
    %v22 = zext i1 %v22.b to i64
    br label %if_19_merge
if_19_else:
    %v25 = add i64 0, 0
    br label %if_19_merge
if_19_merge:
    %v28 = phi i64 [ %v22, %if_19_then ], [ %v25, %if_19_else ]
    br label %if_13_merge
if_13_merge:
    %v31 = phi i64 [ %v12, %if_13_then ], [ %v28, %if_19_merge ]
    %v32.cb = icmp ne i64 %v31, 0
    br i1 %v32.cb, label %if_32_then, label %if_32_else
if_32_then:
    br label %if_32_merge
if_32_else:
    %v36 = add i64 0, 1232
    %v37.b = icmp sge i64 %v0, %v36
    %v37 = zext i1 %v37.b to i64
    %v38.cb = icmp ne i64 %v37, 0
    br i1 %v38.cb, label %if_38_then, label %if_38_else
if_38_then:
    %v40 = add i64 0, 1327
    %v41.b = icmp sle i64 %v0, %v40
    %v41 = zext i1 %v41.b to i64
    br label %if_38_merge
if_38_else:
    %v44 = add i64 0, 0
    br label %if_38_merge
if_38_merge:
    %v47 = phi i64 [ %v41, %if_38_then ], [ %v44, %if_38_else ]
    br label %if_32_merge
if_32_merge:
    %v50 = phi i64 [ %v31, %if_32_then ], [ %v47, %if_38_merge ]
    ret i64 %v50
}

define i64 @text__cyrillic_pair_odd(i64 %p0) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, 1217
    %v2.b = icmp sge i64 %v0, %v1
    %v2 = zext i1 %v2.b to i64
    %v3.cb = icmp ne i64 %v2, 0
    br i1 %v3.cb, label %if_3_then, label %if_3_else
if_3_then:
    %v5 = add i64 0, 1230
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

define i64 @text__upper_cp(i64 %p0) {
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
    %v13.cb = icmp ne i64 %v12, 0
    br i1 %v13.cb, label %if_13_then, label %if_13_else
if_13_then:
    %v15 = add i64 0, 32
    %v16 = sub i64 %v0, %v15
    br label %if_13_merge
if_13_else:
    %v19 = add i64 0, 181
    %v20.b = icmp eq i64 %v0, %v19
    %v20 = zext i1 %v20.b to i64
    %v21.cb = icmp ne i64 %v20, 0
    br i1 %v21.cb, label %if_21_then, label %if_21_else
if_21_then:
    %v23 = add i64 0, 924
    br label %if_21_merge
if_21_else:
    %v26 = add i64 0, 224
    %v27.b = icmp sge i64 %v0, %v26
    %v27 = zext i1 %v27.b to i64
    %v28.cb = icmp ne i64 %v27, 0
    br i1 %v28.cb, label %if_28_then, label %if_28_else
if_28_then:
    %v30 = add i64 0, 254
    %v31.b = icmp sle i64 %v0, %v30
    %v31 = zext i1 %v31.b to i64
    br label %if_28_merge
if_28_else:
    %v34 = add i64 0, 0
    br label %if_28_merge
if_28_merge:
    %v37 = phi i64 [ %v31, %if_28_then ], [ %v34, %if_28_else ]
    %v38.cb = icmp ne i64 %v37, 0
    br i1 %v38.cb, label %if_38_then, label %if_38_else
if_38_then:
    %v40 = add i64 0, 247
    %v41.b = icmp ne i64 %v0, %v40
    %v41 = zext i1 %v41.b to i64
    br label %if_38_merge
if_38_else:
    %v44 = add i64 0, 0
    br label %if_38_merge
if_38_merge:
    %v47 = phi i64 [ %v41, %if_38_then ], [ %v44, %if_38_else ]
    %v48.cb = icmp ne i64 %v47, 0
    br i1 %v48.cb, label %if_48_then, label %if_48_else
if_48_then:
    %v50 = add i64 0, 32
    %v51 = sub i64 %v0, %v50
    br label %if_48_merge
if_48_else:
    %v54 = add i64 0, 255
    %v55.b = icmp eq i64 %v0, %v54
    %v55 = zext i1 %v55.b to i64
    %v56.cb = icmp ne i64 %v55, 0
    br i1 %v56.cb, label %if_56_then, label %if_56_else
if_56_then:
    %v58 = add i64 0, 376
    br label %if_56_merge
if_56_else:
    %v61 = add i64 0, 305
    %v62.b = icmp eq i64 %v0, %v61
    %v62 = zext i1 %v62.b to i64
    %v63.cb = icmp ne i64 %v62, 0
    br i1 %v63.cb, label %if_63_then, label %if_63_else
if_63_then:
    %v65 = add i64 0, 73
    br label %if_63_merge
if_63_else:
    %v68 = add i64 0, 383
    %v69.b = icmp eq i64 %v0, %v68
    %v69 = zext i1 %v69.b to i64
    %v70.cb = icmp ne i64 %v69, 0
    br i1 %v70.cb, label %if_70_then, label %if_70_else
if_70_then:
    %v72 = add i64 0, 83
    br label %if_70_merge
if_70_else:
    %v75 = call i64 @text__latin_a_pair_even(i64 %v0)
    %v76.cb = icmp ne i64 %v75, 0
    br i1 %v76.cb, label %if_76_then, label %if_76_else
if_76_then:
    %v78 = add i64 0, 2
    %v79 = call i64 @orion_imod(i64 %v0, i64 %v78)
    %v80 = add i64 0, 1
    %v81.b = icmp eq i64 %v79, %v80
    %v81 = zext i1 %v81.b to i64
    %v82.cb = icmp ne i64 %v81, 0
    br i1 %v82.cb, label %if_82_then, label %if_82_else
if_82_then:
    %v84 = add i64 0, 1
    %v85 = sub i64 %v0, %v84
    br label %if_82_merge
if_82_else:
    br label %if_82_merge
if_82_merge:
    %v90 = phi i64 [ %v85, %if_82_then ], [ %v0, %if_82_else ]
    br label %if_76_merge
if_76_else:
    %v93 = call i64 @text__latin_a_pair_odd(i64 %v0)
    %v94.cb = icmp ne i64 %v93, 0
    br i1 %v94.cb, label %if_94_then, label %if_94_else
if_94_then:
    %v96 = add i64 0, 2
    %v97 = call i64 @orion_imod(i64 %v0, i64 %v96)
    %v98 = add i64 0, 0
    %v99.b = icmp eq i64 %v97, %v98
    %v99 = zext i1 %v99.b to i64
    %v100.cb = icmp ne i64 %v99, 0
    br i1 %v100.cb, label %if_100_then, label %if_100_else
if_100_then:
    %v102 = add i64 0, 1
    %v103 = sub i64 %v0, %v102
    br label %if_100_merge
if_100_else:
    br label %if_100_merge
if_100_merge:
    %v108 = phi i64 [ %v103, %if_100_then ], [ %v0, %if_100_else ]
    br label %if_94_merge
if_94_else:
    %v111 = add i64 0, 962
    %v112.b = icmp eq i64 %v0, %v111
    %v112 = zext i1 %v112.b to i64
    %v113.cb = icmp ne i64 %v112, 0
    br i1 %v113.cb, label %if_113_then, label %if_113_else
if_113_then:
    %v115 = add i64 0, 931
    br label %if_113_merge
if_113_else:
    %v118 = add i64 0, 945
    %v119.b = icmp sge i64 %v0, %v118
    %v119 = zext i1 %v119.b to i64
    %v120.cb = icmp ne i64 %v119, 0
    br i1 %v120.cb, label %if_120_then, label %if_120_else
if_120_then:
    %v122 = add i64 0, 961
    %v123.b = icmp sle i64 %v0, %v122
    %v123 = zext i1 %v123.b to i64
    br label %if_120_merge
if_120_else:
    %v126 = add i64 0, 0
    br label %if_120_merge
if_120_merge:
    %v129 = phi i64 [ %v123, %if_120_then ], [ %v126, %if_120_else ]
    %v130.cb = icmp ne i64 %v129, 0
    br i1 %v130.cb, label %if_130_then, label %if_130_else
if_130_then:
    %v132 = add i64 0, 32
    %v133 = sub i64 %v0, %v132
    br label %if_130_merge
if_130_else:
    %v136 = add i64 0, 963
    %v137.b = icmp sge i64 %v0, %v136
    %v137 = zext i1 %v137.b to i64
    %v138.cb = icmp ne i64 %v137, 0
    br i1 %v138.cb, label %if_138_then, label %if_138_else
if_138_then:
    %v140 = add i64 0, 971
    %v141.b = icmp sle i64 %v0, %v140
    %v141 = zext i1 %v141.b to i64
    br label %if_138_merge
if_138_else:
    %v144 = add i64 0, 0
    br label %if_138_merge
if_138_merge:
    %v147 = phi i64 [ %v141, %if_138_then ], [ %v144, %if_138_else ]
    %v148.cb = icmp ne i64 %v147, 0
    br i1 %v148.cb, label %if_148_then, label %if_148_else
if_148_then:
    %v150 = add i64 0, 32
    %v151 = sub i64 %v0, %v150
    br label %if_148_merge
if_148_else:
    %v154 = add i64 0, 940
    %v155.b = icmp eq i64 %v0, %v154
    %v155 = zext i1 %v155.b to i64
    %v156.cb = icmp ne i64 %v155, 0
    br i1 %v156.cb, label %if_156_then, label %if_156_else
if_156_then:
    %v158 = add i64 0, 902
    br label %if_156_merge
if_156_else:
    %v161 = add i64 0, 941
    %v162.b = icmp sge i64 %v0, %v161
    %v162 = zext i1 %v162.b to i64
    %v163.cb = icmp ne i64 %v162, 0
    br i1 %v163.cb, label %if_163_then, label %if_163_else
if_163_then:
    %v165 = add i64 0, 943
    %v166.b = icmp sle i64 %v0, %v165
    %v166 = zext i1 %v166.b to i64
    br label %if_163_merge
if_163_else:
    %v169 = add i64 0, 0
    br label %if_163_merge
if_163_merge:
    %v172 = phi i64 [ %v166, %if_163_then ], [ %v169, %if_163_else ]
    %v173.cb = icmp ne i64 %v172, 0
    br i1 %v173.cb, label %if_173_then, label %if_173_else
if_173_then:
    %v175 = add i64 0, 37
    %v176 = sub i64 %v0, %v175
    br label %if_173_merge
if_173_else:
    %v179 = add i64 0, 972
    %v180.b = icmp eq i64 %v0, %v179
    %v180 = zext i1 %v180.b to i64
    %v181.cb = icmp ne i64 %v180, 0
    br i1 %v181.cb, label %if_181_then, label %if_181_else
if_181_then:
    %v183 = add i64 0, 908
    br label %if_181_merge
if_181_else:
    %v186 = add i64 0, 973
    %v187.b = icmp sge i64 %v0, %v186
    %v187 = zext i1 %v187.b to i64
    %v188.cb = icmp ne i64 %v187, 0
    br i1 %v188.cb, label %if_188_then, label %if_188_else
if_188_then:
    %v190 = add i64 0, 974
    %v191.b = icmp sle i64 %v0, %v190
    %v191 = zext i1 %v191.b to i64
    br label %if_188_merge
if_188_else:
    %v194 = add i64 0, 0
    br label %if_188_merge
if_188_merge:
    %v197 = phi i64 [ %v191, %if_188_then ], [ %v194, %if_188_else ]
    %v198.cb = icmp ne i64 %v197, 0
    br i1 %v198.cb, label %if_198_then, label %if_198_else
if_198_then:
    %v200 = add i64 0, 63
    %v201 = sub i64 %v0, %v200
    br label %if_198_merge
if_198_else:
    %v204 = add i64 0, 1072
    %v205.b = icmp sge i64 %v0, %v204
    %v205 = zext i1 %v205.b to i64
    %v206.cb = icmp ne i64 %v205, 0
    br i1 %v206.cb, label %if_206_then, label %if_206_else
if_206_then:
    %v208 = add i64 0, 1103
    %v209.b = icmp sle i64 %v0, %v208
    %v209 = zext i1 %v209.b to i64
    br label %if_206_merge
if_206_else:
    %v212 = add i64 0, 0
    br label %if_206_merge
if_206_merge:
    %v215 = phi i64 [ %v209, %if_206_then ], [ %v212, %if_206_else ]
    %v216.cb = icmp ne i64 %v215, 0
    br i1 %v216.cb, label %if_216_then, label %if_216_else
if_216_then:
    %v218 = add i64 0, 32
    %v219 = sub i64 %v0, %v218
    br label %if_216_merge
if_216_else:
    %v222 = add i64 0, 1104
    %v223.b = icmp sge i64 %v0, %v222
    %v223 = zext i1 %v223.b to i64
    %v224.cb = icmp ne i64 %v223, 0
    br i1 %v224.cb, label %if_224_then, label %if_224_else
if_224_then:
    %v226 = add i64 0, 1119
    %v227.b = icmp sle i64 %v0, %v226
    %v227 = zext i1 %v227.b to i64
    br label %if_224_merge
if_224_else:
    %v230 = add i64 0, 0
    br label %if_224_merge
if_224_merge:
    %v233 = phi i64 [ %v227, %if_224_then ], [ %v230, %if_224_else ]
    %v234.cb = icmp ne i64 %v233, 0
    br i1 %v234.cb, label %if_234_then, label %if_234_else
if_234_then:
    %v236 = add i64 0, 80
    %v237 = sub i64 %v0, %v236
    br label %if_234_merge
if_234_else:
    %v240 = call i64 @text__cyrillic_pair_even(i64 %v0)
    %v241.cb = icmp ne i64 %v240, 0
    br i1 %v241.cb, label %if_241_then, label %if_241_else
if_241_then:
    %v243 = add i64 0, 2
    %v244 = call i64 @orion_imod(i64 %v0, i64 %v243)
    %v245 = add i64 0, 1
    %v246.b = icmp eq i64 %v244, %v245
    %v246 = zext i1 %v246.b to i64
    %v247.cb = icmp ne i64 %v246, 0
    br i1 %v247.cb, label %if_247_then, label %if_247_else
if_247_then:
    %v249 = add i64 0, 1
    %v250 = sub i64 %v0, %v249
    br label %if_247_merge
if_247_else:
    br label %if_247_merge
if_247_merge:
    %v255 = phi i64 [ %v250, %if_247_then ], [ %v0, %if_247_else ]
    br label %if_241_merge
if_241_else:
    %v258 = call i64 @text__cyrillic_pair_odd(i64 %v0)
    %v259.cb = icmp ne i64 %v258, 0
    br i1 %v259.cb, label %if_259_then, label %if_259_else
if_259_then:
    %v261 = add i64 0, 2
    %v262 = call i64 @orion_imod(i64 %v0, i64 %v261)
    %v263 = add i64 0, 0
    %v264.b = icmp eq i64 %v262, %v263
    %v264 = zext i1 %v264.b to i64
    %v265.cb = icmp ne i64 %v264, 0
    br i1 %v265.cb, label %if_265_then, label %if_265_else
if_265_then:
    %v267 = add i64 0, 1
    %v268 = sub i64 %v0, %v267
    br label %if_265_merge
if_265_else:
    br label %if_265_merge
if_265_merge:
    %v273 = phi i64 [ %v268, %if_265_then ], [ %v0, %if_265_else ]
    br label %if_259_merge
if_259_else:
    br label %if_259_merge
if_259_merge:
    %v278 = phi i64 [ %v273, %if_265_merge ], [ %v0, %if_259_else ]
    br label %if_241_merge
if_241_merge:
    %v281 = phi i64 [ %v255, %if_247_merge ], [ %v278, %if_259_merge ]
    br label %if_234_merge
if_234_merge:
    %v284 = phi i64 [ %v237, %if_234_then ], [ %v281, %if_241_merge ]
    br label %if_216_merge
if_216_merge:
    %v287 = phi i64 [ %v219, %if_216_then ], [ %v284, %if_234_merge ]
    br label %if_198_merge
if_198_merge:
    %v290 = phi i64 [ %v201, %if_198_then ], [ %v287, %if_216_merge ]
    br label %if_181_merge
if_181_merge:
    %v293 = phi i64 [ %v183, %if_181_then ], [ %v290, %if_198_merge ]
    br label %if_173_merge
if_173_merge:
    %v296 = phi i64 [ %v176, %if_173_then ], [ %v293, %if_181_merge ]
    br label %if_156_merge
if_156_merge:
    %v299 = phi i64 [ %v158, %if_156_then ], [ %v296, %if_173_merge ]
    br label %if_148_merge
if_148_merge:
    %v302 = phi i64 [ %v151, %if_148_then ], [ %v299, %if_156_merge ]
    br label %if_130_merge
if_130_merge:
    %v305 = phi i64 [ %v133, %if_130_then ], [ %v302, %if_148_merge ]
    br label %if_113_merge
if_113_merge:
    %v308 = phi i64 [ %v115, %if_113_then ], [ %v305, %if_130_merge ]
    br label %if_94_merge
if_94_merge:
    %v311 = phi i64 [ %v108, %if_100_merge ], [ %v308, %if_113_merge ]
    br label %if_76_merge
if_76_merge:
    %v314 = phi i64 [ %v90, %if_82_merge ], [ %v311, %if_94_merge ]
    br label %if_70_merge
if_70_merge:
    %v317 = phi i64 [ %v72, %if_70_then ], [ %v314, %if_76_merge ]
    br label %if_63_merge
if_63_merge:
    %v320 = phi i64 [ %v65, %if_63_then ], [ %v317, %if_70_merge ]
    br label %if_56_merge
if_56_merge:
    %v323 = phi i64 [ %v58, %if_56_then ], [ %v320, %if_63_merge ]
    br label %if_48_merge
if_48_merge:
    %v326 = phi i64 [ %v51, %if_48_then ], [ %v323, %if_56_merge ]
    br label %if_21_merge
if_21_merge:
    %v329 = phi i64 [ %v23, %if_21_then ], [ %v326, %if_48_merge ]
    br label %if_13_merge
if_13_merge:
    %v332 = phi i64 [ %v16, %if_13_then ], [ %v329, %if_21_merge ]
    ret i64 %v332
}

define i64 @text__lower_cp(i64 %p0) {
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
    %v13.cb = icmp ne i64 %v12, 0
    br i1 %v13.cb, label %if_13_then, label %if_13_else
if_13_then:
    %v15 = add i64 0, 32
    %v16 = add i64 %v0, %v15
    br label %if_13_merge
if_13_else:
    %v19 = add i64 0, 192
    %v20.b = icmp sge i64 %v0, %v19
    %v20 = zext i1 %v20.b to i64
    %v21.cb = icmp ne i64 %v20, 0
    br i1 %v21.cb, label %if_21_then, label %if_21_else
if_21_then:
    %v23 = add i64 0, 222
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
    %v33 = add i64 0, 215
    %v34.b = icmp ne i64 %v0, %v33
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
    %v43 = add i64 0, 32
    %v44 = add i64 %v0, %v43
    br label %if_41_merge
if_41_else:
    %v47 = add i64 0, 304
    %v48.b = icmp eq i64 %v0, %v47
    %v48 = zext i1 %v48.b to i64
    %v49.cb = icmp ne i64 %v48, 0
    br i1 %v49.cb, label %if_49_then, label %if_49_else
if_49_then:
    %v51 = add i64 0, 105
    br label %if_49_merge
if_49_else:
    %v54 = add i64 0, 376
    %v55.b = icmp eq i64 %v0, %v54
    %v55 = zext i1 %v55.b to i64
    %v56.cb = icmp ne i64 %v55, 0
    br i1 %v56.cb, label %if_56_then, label %if_56_else
if_56_then:
    %v58 = add i64 0, 255
    br label %if_56_merge
if_56_else:
    %v61 = call i64 @text__latin_a_pair_even(i64 %v0)
    %v62.cb = icmp ne i64 %v61, 0
    br i1 %v62.cb, label %if_62_then, label %if_62_else
if_62_then:
    %v64 = add i64 0, 2
    %v65 = call i64 @orion_imod(i64 %v0, i64 %v64)
    %v66 = add i64 0, 0
    %v67.b = icmp eq i64 %v65, %v66
    %v67 = zext i1 %v67.b to i64
    %v68.cb = icmp ne i64 %v67, 0
    br i1 %v68.cb, label %if_68_then, label %if_68_else
if_68_then:
    %v70 = add i64 0, 1
    %v71 = add i64 %v0, %v70
    br label %if_68_merge
if_68_else:
    br label %if_68_merge
if_68_merge:
    %v76 = phi i64 [ %v71, %if_68_then ], [ %v0, %if_68_else ]
    br label %if_62_merge
if_62_else:
    %v79 = call i64 @text__latin_a_pair_odd(i64 %v0)
    %v80.cb = icmp ne i64 %v79, 0
    br i1 %v80.cb, label %if_80_then, label %if_80_else
if_80_then:
    %v82 = add i64 0, 2
    %v83 = call i64 @orion_imod(i64 %v0, i64 %v82)
    %v84 = add i64 0, 1
    %v85.b = icmp eq i64 %v83, %v84
    %v85 = zext i1 %v85.b to i64
    %v86.cb = icmp ne i64 %v85, 0
    br i1 %v86.cb, label %if_86_then, label %if_86_else
if_86_then:
    %v88 = add i64 0, 1
    %v89 = add i64 %v0, %v88
    br label %if_86_merge
if_86_else:
    br label %if_86_merge
if_86_merge:
    %v94 = phi i64 [ %v89, %if_86_then ], [ %v0, %if_86_else ]
    br label %if_80_merge
if_80_else:
    %v97 = add i64 0, 902
    %v98.b = icmp eq i64 %v0, %v97
    %v98 = zext i1 %v98.b to i64
    %v99.cb = icmp ne i64 %v98, 0
    br i1 %v99.cb, label %if_99_then, label %if_99_else
if_99_then:
    %v101 = add i64 0, 940
    br label %if_99_merge
if_99_else:
    %v104 = add i64 0, 904
    %v105.b = icmp sge i64 %v0, %v104
    %v105 = zext i1 %v105.b to i64
    %v106.cb = icmp ne i64 %v105, 0
    br i1 %v106.cb, label %if_106_then, label %if_106_else
if_106_then:
    %v108 = add i64 0, 906
    %v109.b = icmp sle i64 %v0, %v108
    %v109 = zext i1 %v109.b to i64
    br label %if_106_merge
if_106_else:
    %v112 = add i64 0, 0
    br label %if_106_merge
if_106_merge:
    %v115 = phi i64 [ %v109, %if_106_then ], [ %v112, %if_106_else ]
    %v116.cb = icmp ne i64 %v115, 0
    br i1 %v116.cb, label %if_116_then, label %if_116_else
if_116_then:
    %v118 = add i64 0, 37
    %v119 = add i64 %v0, %v118
    br label %if_116_merge
if_116_else:
    %v122 = add i64 0, 908
    %v123.b = icmp eq i64 %v0, %v122
    %v123 = zext i1 %v123.b to i64
    %v124.cb = icmp ne i64 %v123, 0
    br i1 %v124.cb, label %if_124_then, label %if_124_else
if_124_then:
    %v126 = add i64 0, 972
    br label %if_124_merge
if_124_else:
    %v129 = add i64 0, 910
    %v130.b = icmp sge i64 %v0, %v129
    %v130 = zext i1 %v130.b to i64
    %v131.cb = icmp ne i64 %v130, 0
    br i1 %v131.cb, label %if_131_then, label %if_131_else
if_131_then:
    %v133 = add i64 0, 911
    %v134.b = icmp sle i64 %v0, %v133
    %v134 = zext i1 %v134.b to i64
    br label %if_131_merge
if_131_else:
    %v137 = add i64 0, 0
    br label %if_131_merge
if_131_merge:
    %v140 = phi i64 [ %v134, %if_131_then ], [ %v137, %if_131_else ]
    %v141.cb = icmp ne i64 %v140, 0
    br i1 %v141.cb, label %if_141_then, label %if_141_else
if_141_then:
    %v143 = add i64 0, 63
    %v144 = add i64 %v0, %v143
    br label %if_141_merge
if_141_else:
    %v147 = add i64 0, 913
    %v148.b = icmp sge i64 %v0, %v147
    %v148 = zext i1 %v148.b to i64
    %v149.cb = icmp ne i64 %v148, 0
    br i1 %v149.cb, label %if_149_then, label %if_149_else
if_149_then:
    %v151 = add i64 0, 929
    %v152.b = icmp sle i64 %v0, %v151
    %v152 = zext i1 %v152.b to i64
    br label %if_149_merge
if_149_else:
    %v155 = add i64 0, 0
    br label %if_149_merge
if_149_merge:
    %v158 = phi i64 [ %v152, %if_149_then ], [ %v155, %if_149_else ]
    %v159.cb = icmp ne i64 %v158, 0
    br i1 %v159.cb, label %if_159_then, label %if_159_else
if_159_then:
    %v161 = add i64 0, 32
    %v162 = add i64 %v0, %v161
    br label %if_159_merge
if_159_else:
    %v165 = add i64 0, 931
    %v166.b = icmp sge i64 %v0, %v165
    %v166 = zext i1 %v166.b to i64
    %v167.cb = icmp ne i64 %v166, 0
    br i1 %v167.cb, label %if_167_then, label %if_167_else
if_167_then:
    %v169 = add i64 0, 939
    %v170.b = icmp sle i64 %v0, %v169
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
    %v179 = add i64 0, 32
    %v180 = add i64 %v0, %v179
    br label %if_177_merge
if_177_else:
    %v183 = add i64 0, 1040
    %v184.b = icmp sge i64 %v0, %v183
    %v184 = zext i1 %v184.b to i64
    %v185.cb = icmp ne i64 %v184, 0
    br i1 %v185.cb, label %if_185_then, label %if_185_else
if_185_then:
    %v187 = add i64 0, 1071
    %v188.b = icmp sle i64 %v0, %v187
    %v188 = zext i1 %v188.b to i64
    br label %if_185_merge
if_185_else:
    %v191 = add i64 0, 0
    br label %if_185_merge
if_185_merge:
    %v194 = phi i64 [ %v188, %if_185_then ], [ %v191, %if_185_else ]
    %v195.cb = icmp ne i64 %v194, 0
    br i1 %v195.cb, label %if_195_then, label %if_195_else
if_195_then:
    %v197 = add i64 0, 32
    %v198 = add i64 %v0, %v197
    br label %if_195_merge
if_195_else:
    %v201 = add i64 0, 1024
    %v202.b = icmp sge i64 %v0, %v201
    %v202 = zext i1 %v202.b to i64
    %v203.cb = icmp ne i64 %v202, 0
    br i1 %v203.cb, label %if_203_then, label %if_203_else
if_203_then:
    %v205 = add i64 0, 1039
    %v206.b = icmp sle i64 %v0, %v205
    %v206 = zext i1 %v206.b to i64
    br label %if_203_merge
if_203_else:
    %v209 = add i64 0, 0
    br label %if_203_merge
if_203_merge:
    %v212 = phi i64 [ %v206, %if_203_then ], [ %v209, %if_203_else ]
    %v213.cb = icmp ne i64 %v212, 0
    br i1 %v213.cb, label %if_213_then, label %if_213_else
if_213_then:
    %v215 = add i64 0, 80
    %v216 = add i64 %v0, %v215
    br label %if_213_merge
if_213_else:
    %v219 = call i64 @text__cyrillic_pair_even(i64 %v0)
    %v220.cb = icmp ne i64 %v219, 0
    br i1 %v220.cb, label %if_220_then, label %if_220_else
if_220_then:
    %v222 = add i64 0, 2
    %v223 = call i64 @orion_imod(i64 %v0, i64 %v222)
    %v224 = add i64 0, 0
    %v225.b = icmp eq i64 %v223, %v224
    %v225 = zext i1 %v225.b to i64
    %v226.cb = icmp ne i64 %v225, 0
    br i1 %v226.cb, label %if_226_then, label %if_226_else
if_226_then:
    %v228 = add i64 0, 1
    %v229 = add i64 %v0, %v228
    br label %if_226_merge
if_226_else:
    br label %if_226_merge
if_226_merge:
    %v234 = phi i64 [ %v229, %if_226_then ], [ %v0, %if_226_else ]
    br label %if_220_merge
if_220_else:
    %v237 = call i64 @text__cyrillic_pair_odd(i64 %v0)
    %v238.cb = icmp ne i64 %v237, 0
    br i1 %v238.cb, label %if_238_then, label %if_238_else
if_238_then:
    %v240 = add i64 0, 2
    %v241 = call i64 @orion_imod(i64 %v0, i64 %v240)
    %v242 = add i64 0, 1
    %v243.b = icmp eq i64 %v241, %v242
    %v243 = zext i1 %v243.b to i64
    %v244.cb = icmp ne i64 %v243, 0
    br i1 %v244.cb, label %if_244_then, label %if_244_else
if_244_then:
    %v246 = add i64 0, 1
    %v247 = add i64 %v0, %v246
    br label %if_244_merge
if_244_else:
    br label %if_244_merge
if_244_merge:
    %v252 = phi i64 [ %v247, %if_244_then ], [ %v0, %if_244_else ]
    br label %if_238_merge
if_238_else:
    br label %if_238_merge
if_238_merge:
    %v257 = phi i64 [ %v252, %if_244_merge ], [ %v0, %if_238_else ]
    br label %if_220_merge
if_220_merge:
    %v260 = phi i64 [ %v234, %if_226_merge ], [ %v257, %if_238_merge ]
    br label %if_213_merge
if_213_merge:
    %v263 = phi i64 [ %v216, %if_213_then ], [ %v260, %if_220_merge ]
    br label %if_195_merge
if_195_merge:
    %v266 = phi i64 [ %v198, %if_195_then ], [ %v263, %if_213_merge ]
    br label %if_177_merge
if_177_merge:
    %v269 = phi i64 [ %v180, %if_177_then ], [ %v266, %if_195_merge ]
    br label %if_159_merge
if_159_merge:
    %v272 = phi i64 [ %v162, %if_159_then ], [ %v269, %if_177_merge ]
    br label %if_141_merge
if_141_merge:
    %v275 = phi i64 [ %v144, %if_141_then ], [ %v272, %if_159_merge ]
    br label %if_124_merge
if_124_merge:
    %v278 = phi i64 [ %v126, %if_124_then ], [ %v275, %if_141_merge ]
    br label %if_116_merge
if_116_merge:
    %v281 = phi i64 [ %v119, %if_116_then ], [ %v278, %if_124_merge ]
    br label %if_99_merge
if_99_merge:
    %v284 = phi i64 [ %v101, %if_99_then ], [ %v281, %if_116_merge ]
    br label %if_80_merge
if_80_merge:
    %v287 = phi i64 [ %v94, %if_86_merge ], [ %v284, %if_99_merge ]
    br label %if_62_merge
if_62_merge:
    %v290 = phi i64 [ %v76, %if_68_merge ], [ %v287, %if_80_merge ]
    br label %if_56_merge
if_56_merge:
    %v293 = phi i64 [ %v58, %if_56_then ], [ %v290, %if_62_merge ]
    br label %if_49_merge
if_49_merge:
    %v296 = phi i64 [ %v51, %if_49_then ], [ %v293, %if_56_merge ]
    br label %if_41_merge
if_41_merge:
    %v299 = phi i64 [ %v44, %if_41_then ], [ %v296, %if_49_merge ]
    br label %if_13_merge
if_13_merge:
    %v302 = phi i64 [ %v16, %if_13_then ], [ %v299, %if_41_merge ]
    ret i64 %v302
}

define ptr @text__map_case(ptr %p0, ptr %p1) {
entry:
    %v6 = alloca ptr, align 8
    %v9 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = call ptr @orion_bytes_from_text(ptr %v0)
    %v3 = call i64 @orion_list_len(ptr %v2)
    %v4 = add i64 0, 0
    %v5 = call ptr @orion_bytes_zeros(i64 %v4)
    store ptr %v5, ptr %v6
    %v7 = add i64 0, 0
    %v8 = add i64 0, 0
    store i64 %v8, ptr %v9
    %v10 = add i64 0, 0
    br label %loop_11_header
loop_11_header:
    %v13 = load i64, ptr %v9
    %v14.b = icmp sge i64 %v13, %v3
    %v14 = zext i1 %v14.b to i64
    %v15.cb = icmp ne i64 %v14, 0
    br i1 %v15.cb, label %if_15_then, label %if_15_else
if_15_then:
    br label %loop_11_end
if_15_else:
    br label %if_15_merge
if_15_merge:
    %v21 = load i64, ptr %v9
    %v22 = call i64 @text__cp_at(ptr %v2, i64 %v21)
    %v23 = load ptr, ptr %v6
    %v24.fpi = call i64 @orion_list_at(ptr %v1, i64 0)
    %v24.flg = call i64 @orion_list_at(ptr %v1, i64 1)
    %v24.p = inttoptr i64 %v24.fpi to ptr
    %v24.isl = icmp eq i64 %v24.flg, 1
    br i1 %v24.isl, label %clam24, label %cpln24
clam24:
    %v24.r1 = call i64 %v24.p(ptr %v1, i64 %v22)
    br label %cmrg24
cpln24:
    %v24.r2 = call i64 %v24.p(i64 %v22)
    br label %cmrg24
cmrg24:
    %v24 = phi i64 [ %v24.r1, %clam24 ], [ %v24.r2, %cpln24 ]
    %v25 = call ptr @text__cp_bytes(i64 %v24)
    %v26 = call ptr @orion_bytes_concat(ptr %v23, ptr %v25)
    store ptr %v26, ptr %v6
    %v27 = add i64 0, 0
    %v28 = load i64, ptr %v9
    %v29 = load i64, ptr %v9
    %v30 = call i64 @orion_list_at(ptr %v2, i64 %v29)
    %v31 = call i64 @text__cp_size(i64 %v30)
    %v32 = add i64 %v28, %v31
    store i64 %v32, ptr %v9
    %v33 = add i64 0, 0
    br label %loop_11_header
loop_11_end:
    %v36 = load ptr, ptr %v6
    %v37 = call ptr @orion_bytes_to_text(ptr %v36)
    ret ptr %v37
}

define ptr @text__upper(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = call ptr @orion_list_new(i64 2)
    %v1.fp = ptrtoint ptr @text__upper_cp to i64
    call void @orion_list_set(ptr %v1, i64 0, i64 %v1.fp)
    call void @orion_list_set(ptr %v1, i64 1, i64 0)
    %v2 = call ptr @text__map_case(ptr %v0, ptr %v1)
    ret ptr %v2
}

define ptr @text__lower(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = call ptr @orion_list_new(i64 2)
    %v1.fp = ptrtoint ptr @text__lower_cp to i64
    call void @orion_list_set(ptr %v1, i64 0, i64 %v1.fp)
    call void @orion_list_set(ptr %v1, i64 1, i64 0)
    %v2 = call ptr @text__map_case(ptr %v0, ptr %v1)
    ret ptr %v2
}

define i64 @text__characters(ptr %p0) {
entry:
    %v4 = alloca i64, align 8
    %v7 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = call ptr @orion_bytes_from_text(ptr %v0)
    %v2 = call i64 @orion_list_len(ptr %v1)
    %v3 = add i64 0, 0
    store i64 %v3, ptr %v4
    %v5 = add i64 0, 0
    %v6 = add i64 0, 0
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
    %v16 = add i64 0, 128
    %v17.b = icmp slt i64 %v15, %v16
    %v17 = zext i1 %v17.b to i64
    %v18.cb = icmp ne i64 %v17, 0
    br i1 %v18.cb, label %if_18_then, label %if_18_else
if_18_then:
    br label %if_18_merge
if_18_else:
    %v22 = add i64 0, 192
    %v23.b = icmp sge i64 %v15, %v22
    %v23 = zext i1 %v23.b to i64
    br label %if_18_merge
if_18_merge:
    %v26 = phi i64 [ %v17, %if_18_then ], [ %v23, %if_18_else ]
    %v27.cb = icmp ne i64 %v26, 0
    br i1 %v27.cb, label %if_27_then, label %if_27_else
if_27_then:
    %v29 = load i64, ptr %v4
    %v30 = add i64 0, 1
    %v31 = add i64 %v29, %v30
    store i64 %v31, ptr %v4
    %v32 = add i64 0, 0
    br label %if_27_merge
if_27_else:
    br label %if_27_merge
if_27_merge:
    br label %for_6_step
for_6_step:
    %v39 = add i64 0, 1
    %v40 = add i64 %v11, %v39
    store i64 %v40, ptr %v7
    %v41 = add i64 0, 0
    br label %for_6_header
for_6_end:
    %v44 = load i64, ptr %v4
    ret i64 %v44
}

define ptr @text__trim(ptr %p0) {
entry:
    %v4 = alloca i64, align 8
    %v6 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = call ptr @orion_bytes_from_text(ptr %v0)
    %v2 = call i64 @orion_list_len(ptr %v1)
    %v3 = add i64 0, 0
    store i64 %v3, ptr %v4
    %v5 = add i64 0, 0
    store i64 %v2, ptr %v6
    %v7 = add i64 0, 0
    br label %loop_8_header
loop_8_header:
    %v10 = load i64, ptr %v4
    %v11 = load i64, ptr %v6
    %v12.b = icmp sge i64 %v10, %v11
    %v12 = zext i1 %v12.b to i64
    %v13.cb = icmp ne i64 %v12, 0
    br i1 %v13.cb, label %if_13_then, label %if_13_else
if_13_then:
    br label %loop_8_end
if_13_else:
    br label %if_13_merge
if_13_merge:
    %v19 = load i64, ptr %v4
    %v20 = call i64 @orion_list_at(ptr %v1, i64 %v19)
    %v21 = add i64 0, 32
    %v22.b = icmp eq i64 %v20, %v21
    %v22 = zext i1 %v22.b to i64
    %v23.cb = icmp ne i64 %v22, 0
    br i1 %v23.cb, label %if_23_then, label %if_23_else
if_23_then:
    br label %if_23_merge
if_23_else:
    %v27 = add i64 0, 9
    %v28.b = icmp eq i64 %v20, %v27
    %v28 = zext i1 %v28.b to i64
    br label %if_23_merge
if_23_merge:
    %v31 = phi i64 [ %v22, %if_23_then ], [ %v28, %if_23_else ]
    %v32.cb = icmp ne i64 %v31, 0
    br i1 %v32.cb, label %if_32_then, label %if_32_else
if_32_then:
    br label %if_32_merge
if_32_else:
    %v36 = add i64 0, 10
    %v37.b = icmp eq i64 %v20, %v36
    %v37 = zext i1 %v37.b to i64
    br label %if_32_merge
if_32_merge:
    %v40 = phi i64 [ %v31, %if_32_then ], [ %v37, %if_32_else ]
    %v41.cb = icmp ne i64 %v40, 0
    br i1 %v41.cb, label %if_41_then, label %if_41_else
if_41_then:
    br label %if_41_merge
if_41_else:
    %v45 = add i64 0, 13
    %v46.b = icmp eq i64 %v20, %v45
    %v46 = zext i1 %v46.b to i64
    br label %if_41_merge
if_41_merge:
    %v49 = phi i64 [ %v40, %if_41_then ], [ %v46, %if_41_else ]
    %v50.cb = icmp ne i64 %v49, 0
    br i1 %v50.cb, label %if_50_then, label %if_50_else
if_50_then:
    %v52 = load i64, ptr %v4
    %v53 = add i64 0, 1
    %v54 = add i64 %v52, %v53
    store i64 %v54, ptr %v4
    %v55 = add i64 0, 0
    br label %if_50_merge
if_50_else:
    br label %loop_8_end
if_50_merge:
    br label %loop_8_header
loop_8_end:
    br label %loop_62_header
loop_62_header:
    %v64 = load i64, ptr %v6
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
    %v73 = load i64, ptr %v6
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
    %v106.cb = icmp ne i64 %v105, 0
    br i1 %v106.cb, label %if_106_then, label %if_106_else
if_106_then:
    %v108 = load i64, ptr %v6
    %v109 = add i64 0, 1
    %v110 = sub i64 %v108, %v109
    store i64 %v110, ptr %v6
    %v111 = add i64 0, 0
    br label %if_106_merge
if_106_else:
    br label %loop_62_end
if_106_merge:
    br label %loop_62_header
loop_62_end:
    %v118 = load i64, ptr %v4
    %v119 = load i64, ptr %v6
    %v120 = call ptr @orion_bytes_slice(ptr %v1, i64 %v118, i64 %v119)
    %v121 = call ptr @orion_bytes_to_text(ptr %v120)
    ret ptr %v121
}

define ptr @text__join(ptr %p0, ptr %p1) {
entry:
    %v3 = alloca ptr, align 8
    %v7 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i8, ptr @.str_0, i64 16
    store ptr %v2, ptr %v3
    %v4 = add i64 0, 0
    %v5 = call i64 @orion_list_len(ptr %v0)
    %v6 = add i64 0, 0
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
    %v15 = add i64 0, 0
    %v16.b = icmp sgt i64 %v11, %v15
    %v16 = zext i1 %v16.b to i64
    %v17.cb = icmp ne i64 %v16, 0
    br i1 %v17.cb, label %if_17_then, label %if_17_else
if_17_then:
    %v19 = load ptr, ptr %v3
    %v20 = call ptr @orion_text_concat(ptr %v19, ptr %v1)
    store ptr %v20, ptr %v3
    %v21 = add i64 0, 0
    br label %if_17_merge
if_17_else:
    br label %if_17_merge
if_17_merge:
    %v26 = load ptr, ptr %v3
    %v27.i = call i64 @orion_list_at(ptr %v0, i64 %v11)
    %v27 = inttoptr i64 %v27.i to ptr
    %v28 = call ptr @orion_text_concat(ptr %v26, ptr %v27)
    store ptr %v28, ptr %v3
    %v29 = add i64 0, 0
    br label %for_6_step
for_6_step:
    %v32 = add i64 0, 1
    %v33 = add i64 %v11, %v32
    store i64 %v33, ptr %v7
    %v34 = add i64 0, 0
    br label %for_6_header
for_6_end:
    %v37 = load ptr, ptr %v3
    ret ptr %v37
}

define ptr @text__split(ptr %p0, ptr %p1) {
entry:
    %v7 = alloca ptr, align 8
    %v19 = alloca i64, align 8
    %v22 = alloca i64, align 8
    %v36 = alloca i64, align 8
    %v39 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = call ptr @orion_bytes_from_text(ptr %v0)
    %v3 = call ptr @orion_bytes_from_text(ptr %v1)
    %v4 = call i64 @orion_list_len(ptr %v2)
    %v5 = call i64 @orion_list_len(ptr %v3)
    %v6 = getelementptr i64, ptr @orion_empty_list, i64 0
    store ptr %v6, ptr %v7
    %v8 = add i64 0, 0
    %v9 = add i64 0, 0
    %v10.b = icmp eq i64 %v5, %v9
    %v10 = zext i1 %v10.b to i64
    %v11.cb = icmp ne i64 %v10, 0
    br i1 %v11.cb, label %if_11_then, label %if_11_else
if_11_then:
    %v13 = load ptr, ptr %v7
    %v14.p = ptrtoint ptr %v0 to i64
    %v14 = call ptr @orion_list_push_mut(ptr %v13, i64 %v14.p)
    store ptr %v14, ptr %v7
    %v15 = add i64 0, 0
    br label %if_11_merge
if_11_else:
    %v18 = add i64 0, 0
    store i64 %v18, ptr %v19
    %v20 = add i64 0, 0
    %v21 = add i64 0, 0
    store i64 %v21, ptr %v22
    %v23 = add i64 0, 0
    br label %loop_24_header
loop_24_header:
    %v26 = load i64, ptr %v22
    %v27 = sub i64 %v4, %v5
    %v28.b = icmp sgt i64 %v26, %v27
    %v28 = zext i1 %v28.b to i64
    %v29.cb = icmp ne i64 %v28, 0
    br i1 %v29.cb, label %if_29_then, label %if_29_else
if_29_then:
    br label %loop_24_end
if_29_else:
    br label %if_29_merge
if_29_merge:
    %v35 = add i64 0, 1
    store i64 %v35, ptr %v36
    %v37 = add i64 0, 0
    %v38 = add i64 0, 0
    store i64 %v38, ptr %v39
    %v40 = add i64 0, 0
    br label %for_38_header
for_38_header:
    %v43 = load i64, ptr %v39
    %v44.b = icmp slt i64 %v43, %v5
    %v44 = zext i1 %v44.b to i64
    %v45.cb = icmp ne i64 %v44, 0
    br i1 %v45.cb, label %for_38_body, label %for_38_end
for_38_body:
    %v47 = load i64, ptr %v22
    %v48 = add i64 %v47, %v43
    %v49 = call i64 @orion_list_at(ptr %v2, i64 %v48)
    %v50 = call i64 @orion_list_at(ptr %v3, i64 %v43)
    %v51.b = icmp ne i64 %v49, %v50
    %v51 = zext i1 %v51.b to i64
    %v52.cb = icmp ne i64 %v51, 0
    br i1 %v52.cb, label %if_52_then, label %if_52_else
if_52_then:
    %v54 = add i64 0, 0
    store i64 %v54, ptr %v36
    %v55 = add i64 0, 0
    br label %if_52_merge
if_52_else:
    br label %if_52_merge
if_52_merge:
    br label %for_38_step
for_38_step:
    %v62 = add i64 0, 1
    %v63 = add i64 %v43, %v62
    store i64 %v63, ptr %v39
    %v64 = add i64 0, 0
    br label %for_38_header
for_38_end:
    %v67 = load i64, ptr %v36
    %v68.cb = icmp ne i64 %v67, 0
    br i1 %v68.cb, label %if_68_then, label %if_68_else
if_68_then:
    %v70 = load ptr, ptr %v7
    %v71 = load i64, ptr %v19
    %v72 = load i64, ptr %v22
    %v73 = call ptr @orion_bytes_slice(ptr %v2, i64 %v71, i64 %v72)
    %v74 = call ptr @orion_bytes_to_text(ptr %v73)
    %v75.p = ptrtoint ptr %v74 to i64
    %v75 = call ptr @orion_list_push_mut(ptr %v70, i64 %v75.p)
    store ptr %v75, ptr %v7
    %v76 = add i64 0, 0
    %v77 = load i64, ptr %v22
    %v78 = add i64 %v77, %v5
    store i64 %v78, ptr %v22
    %v79 = add i64 0, 0
    %v80 = load i64, ptr %v22
    store i64 %v80, ptr %v19
    %v81 = add i64 0, 0
    br label %if_68_merge
if_68_else:
    %v84 = load i64, ptr %v22
    %v85 = add i64 0, 1
    %v86 = add i64 %v84, %v85
    store i64 %v86, ptr %v22
    %v87 = add i64 0, 0
    br label %if_68_merge
if_68_merge:
    %v90 = phi i64 [ %v81, %if_68_then ], [ %v87, %if_68_else ]
    br label %loop_24_header
loop_24_end:
    %v93 = load ptr, ptr %v7
    %v94 = load i64, ptr %v19
    %v95 = call ptr @orion_bytes_slice(ptr %v2, i64 %v94, i64 %v4)
    %v96 = call ptr @orion_bytes_to_text(ptr %v95)
    %v97.p = ptrtoint ptr %v96 to i64
    %v97 = call ptr @orion_list_push_mut(ptr %v93, i64 %v97.p)
    store ptr %v97, ptr %v7
    %v98 = add i64 0, 0
    br label %if_11_merge
if_11_merge:
    %v101 = phi i64 [ %v15, %if_11_then ], [ %v98, %loop_24_end ]
    %v102 = load ptr, ptr %v7
    ret ptr %v102
}

define ptr @text__replace(ptr %p0, ptr %p1, ptr %p2) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i8, ptr %p2, i64 0
    %v3 = call ptr @text__split(ptr %v0, ptr %v1)
    %v4 = call ptr @text__join(ptr %v3, ptr %v2)
    ret ptr %v4
}

define i64 @text__index_of(ptr %p0, ptr %p1) {
entry:
    %v9 = alloca i64, align 8
    %v20 = alloca i64, align 8
    %v44 = alloca i64, align 8
    %v47 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = call ptr @orion_bytes_from_text(ptr %v0)
    %v3 = call ptr @orion_bytes_from_text(ptr %v1)
    %v4 = call i64 @orion_list_len(ptr %v2)
    %v5 = call i64 @orion_list_len(ptr %v3)
    %v6 = add i64 0, 0
    %v7 = add i64 0, 1
    %v8 = sub i64 %v6, %v7
    store i64 %v8, ptr %v9
    %v10 = add i64 0, 0
    %v11 = add i64 0, 0
    %v12.b = icmp eq i64 %v5, %v11
    %v12 = zext i1 %v12.b to i64
    %v13.cb = icmp ne i64 %v12, 0
    br i1 %v13.cb, label %if_13_then, label %if_13_else
if_13_then:
    %v15 = add i64 0, 0
    store i64 %v15, ptr %v9
    %v16 = add i64 0, 0
    br label %if_13_merge
if_13_else:
    %v19 = add i64 0, 0
    store i64 %v19, ptr %v20
    %v21 = add i64 0, 0
    br label %loop_22_header
loop_22_header:
    %v24 = load i64, ptr %v20
    %v25 = sub i64 %v4, %v5
    %v26.b = icmp sgt i64 %v24, %v25
    %v26 = zext i1 %v26.b to i64
    %v27.cb = icmp ne i64 %v26, 0
    br i1 %v27.cb, label %if_27_then, label %if_27_else
if_27_then:
    br label %if_27_merge
if_27_else:
    %v31 = load i64, ptr %v9
    %v32 = add i64 0, 0
    %v33.b = icmp sge i64 %v31, %v32
    %v33 = zext i1 %v33.b to i64
    br label %if_27_merge
if_27_merge:
    %v36 = phi i64 [ %v26, %if_27_then ], [ %v33, %if_27_else ]
    %v37.cb = icmp ne i64 %v36, 0
    br i1 %v37.cb, label %if_37_then, label %if_37_else
if_37_then:
    br label %loop_22_end
if_37_else:
    br label %if_37_merge
if_37_merge:
    %v43 = add i64 0, 1
    store i64 %v43, ptr %v44
    %v45 = add i64 0, 0
    %v46 = add i64 0, 0
    store i64 %v46, ptr %v47
    %v48 = add i64 0, 0
    br label %for_46_header
for_46_header:
    %v51 = load i64, ptr %v47
    %v52.b = icmp slt i64 %v51, %v5
    %v52 = zext i1 %v52.b to i64
    %v53.cb = icmp ne i64 %v52, 0
    br i1 %v53.cb, label %for_46_body, label %for_46_end
for_46_body:
    %v55 = load i64, ptr %v20
    %v56 = add i64 %v55, %v51
    %v57 = call i64 @orion_list_at(ptr %v2, i64 %v56)
    %v58 = call i64 @orion_list_at(ptr %v3, i64 %v51)
    %v59.b = icmp ne i64 %v57, %v58
    %v59 = zext i1 %v59.b to i64
    %v60.cb = icmp ne i64 %v59, 0
    br i1 %v60.cb, label %if_60_then, label %if_60_else
if_60_then:
    %v62 = add i64 0, 0
    store i64 %v62, ptr %v44
    %v63 = add i64 0, 0
    br label %if_60_merge
if_60_else:
    br label %if_60_merge
if_60_merge:
    br label %for_46_step
for_46_step:
    %v70 = add i64 0, 1
    %v71 = add i64 %v51, %v70
    store i64 %v71, ptr %v47
    %v72 = add i64 0, 0
    br label %for_46_header
for_46_end:
    %v75 = load i64, ptr %v44
    %v76.cb = icmp ne i64 %v75, 0
    br i1 %v76.cb, label %if_76_then, label %if_76_else
if_76_then:
    %v78 = load i64, ptr %v20
    store i64 %v78, ptr %v9
    %v79 = add i64 0, 0
    br label %if_76_merge
if_76_else:
    br label %if_76_merge
if_76_merge:
    %v84 = load i64, ptr %v20
    %v85 = add i64 0, 1
    %v86 = add i64 %v84, %v85
    store i64 %v86, ptr %v20
    %v87 = add i64 0, 0
    br label %loop_22_header
loop_22_end:
    br label %if_13_merge
if_13_merge:
    %v92 = load i64, ptr %v9
    ret i64 %v92
}

define ptr @text__pad_left(ptr %p0, i64 %p1, ptr %p2) {
entry:
    %v3 = alloca ptr, align 8
    %v6 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr %p2, i64 0
    store ptr %v0, ptr %v3
    %v4 = add i64 0, 0
    %v5 = call i64 @orion_tlen(ptr %v0)
    store i64 %v5, ptr %v6
    %v7 = add i64 0, 0
    br label %loop_8_header
loop_8_header:
    %v10 = load i64, ptr %v6
    %v11.b = icmp sge i64 %v10, %v1
    %v11 = zext i1 %v11.b to i64
    %v12.cb = icmp ne i64 %v11, 0
    br i1 %v12.cb, label %if_12_then, label %if_12_else
if_12_then:
    br label %loop_8_end
if_12_else:
    br label %if_12_merge
if_12_merge:
    %v18 = load ptr, ptr %v3
    %v19 = call ptr @orion_text_concat(ptr %v2, ptr %v18)
    store ptr %v19, ptr %v3
    %v20 = add i64 0, 0
    %v21 = load i64, ptr %v6
    %v22 = add i64 0, 1
    %v23 = add i64 %v21, %v22
    store i64 %v23, ptr %v6
    %v24 = add i64 0, 0
    br label %loop_8_header
loop_8_end:
    %v27 = load ptr, ptr %v3
    ret ptr %v27
}

define ptr @text__pad_right(ptr %p0, i64 %p1, ptr %p2) {
entry:
    %v3 = alloca ptr, align 8
    %v6 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr %p2, i64 0
    store ptr %v0, ptr %v3
    %v4 = add i64 0, 0
    %v5 = call i64 @orion_tlen(ptr %v0)
    store i64 %v5, ptr %v6
    %v7 = add i64 0, 0
    br label %loop_8_header
loop_8_header:
    %v10 = load i64, ptr %v6
    %v11.b = icmp sge i64 %v10, %v1
    %v11 = zext i1 %v11.b to i64
    %v12.cb = icmp ne i64 %v11, 0
    br i1 %v12.cb, label %if_12_then, label %if_12_else
if_12_then:
    br label %loop_8_end
if_12_else:
    br label %if_12_merge
if_12_merge:
    %v18 = load ptr, ptr %v3
    %v19 = call ptr @orion_text_concat(ptr %v18, ptr %v2)
    store ptr %v19, ptr %v3
    %v20 = add i64 0, 0
    %v21 = load i64, ptr %v6
    %v22 = add i64 0, 1
    %v23 = add i64 %v21, %v22
    store i64 %v23, ptr %v6
    %v24 = add i64 0, 0
    br label %loop_8_header
loop_8_end:
    %v27 = load ptr, ptr %v3
    ret ptr %v27
}

define ptr @text__lines(ptr %p0) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr @.str_1, i64 16
    %v2 = call ptr @text__split(ptr %v0, ptr %v1)
    ret ptr %v2
}

define i64 @text__int_from_text(ptr %p0) {
entry:
    %v4 = alloca i64, align 8
    %v7 = alloca i64, align 8
    %v34 = alloca i64, align 8
    %v37 = alloca i64, align 8
    %v40 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = call ptr @orion_bytes_from_text(ptr %v0)
    %v2 = call i64 @orion_list_len(ptr %v1)
    %v3 = add i64 0, 0
    store i64 %v3, ptr %v4
    %v5 = add i64 0, 0
    %v6 = add i64 0, 0
    store i64 %v6, ptr %v7
    %v8 = add i64 0, 0
    %v9 = add i64 0, 0
    %v10.b = icmp sgt i64 %v2, %v9
    %v10 = zext i1 %v10.b to i64
    %v11.cb = icmp ne i64 %v10, 0
    br i1 %v11.cb, label %if_11_then, label %if_11_else
if_11_then:
    %v13 = add i64 0, 0
    %v14 = call i64 @orion_list_at(ptr %v1, i64 %v13)
    %v15 = add i64 0, 45
    %v16.b = icmp eq i64 %v14, %v15
    %v16 = zext i1 %v16.b to i64
    br label %if_11_merge
if_11_else:
    %v19 = add i64 0, 0
    br label %if_11_merge
if_11_merge:
    %v22 = phi i64 [ %v16, %if_11_then ], [ %v19, %if_11_else ]
    %v23.cb = icmp ne i64 %v22, 0
    br i1 %v23.cb, label %if_23_then, label %if_23_else
if_23_then:
    %v25 = add i64 0, 1
    store i64 %v25, ptr %v7
    %v26 = add i64 0, 0
    %v27 = add i64 0, 1
    store i64 %v27, ptr %v4
    %v28 = add i64 0, 0
    br label %if_23_merge
if_23_else:
    br label %if_23_merge
if_23_merge:
    %v33 = add i64 0, 0
    store i64 %v33, ptr %v34
    %v35 = add i64 0, 0
    %v36 = add i64 0, 0
    store i64 %v36, ptr %v37
    %v38 = add i64 0, 0
    %v39 = load i64, ptr %v4
    store i64 %v39, ptr %v40
    %v41 = add i64 0, 0
    br label %for_39_header
for_39_header:
    %v44 = load i64, ptr %v40
    %v45.b = icmp slt i64 %v44, %v2
    %v45 = zext i1 %v45.b to i64
    %v46.cb = icmp ne i64 %v45, 0
    br i1 %v46.cb, label %for_39_body, label %for_39_end
for_39_body:
    %v48 = load i64, ptr %v37
    %v49.n = icmp eq i64 %v48, 0
    %v49 = zext i1 %v49.n to i64
    %v50.cb = icmp ne i64 %v49, 0
    br i1 %v50.cb, label %if_50_then, label %if_50_else
if_50_then:
    %v52 = call i64 @orion_list_at(ptr %v1, i64 %v44)
    %v53 = add i64 0, 48
    %v54.b = icmp sge i64 %v52, %v53
    %v54 = zext i1 %v54.b to i64
    %v55.cb = icmp ne i64 %v54, 0
    br i1 %v55.cb, label %if_55_then, label %if_55_else
if_55_then:
    %v57 = add i64 0, 57
    %v58.b = icmp sle i64 %v52, %v57
    %v58 = zext i1 %v58.b to i64
    br label %if_55_merge
if_55_else:
    %v61 = add i64 0, 0
    br label %if_55_merge
if_55_merge:
    %v64 = phi i64 [ %v58, %if_55_then ], [ %v61, %if_55_else ]
    %v65.cb = icmp ne i64 %v64, 0
    br i1 %v65.cb, label %if_65_then, label %if_65_else
if_65_then:
    %v67 = load i64, ptr %v34
    %v68 = add i64 0, 10
    %v69 = mul i64 %v67, %v68
    %v70 = add i64 0, 48
    %v71 = sub i64 %v52, %v70
    %v72 = add i64 %v69, %v71
    store i64 %v72, ptr %v34
    %v73 = add i64 0, 0
    br label %if_65_merge
if_65_else:
    %v76 = add i64 0, 1
    store i64 %v76, ptr %v37
    %v77 = add i64 0, 0
    br label %if_65_merge
if_65_merge:
    %v80 = phi i64 [ %v73, %if_65_then ], [ %v77, %if_65_else ]
    br label %if_50_merge
if_50_else:
    br label %if_50_merge
if_50_merge:
    br label %for_39_step
for_39_step:
    %v87 = add i64 0, 1
    %v88 = add i64 %v44, %v87
    store i64 %v88, ptr %v40
    %v89 = add i64 0, 0
    br label %for_39_header
for_39_end:
    %v92 = load i64, ptr %v7
    %v93.cb = icmp ne i64 %v92, 0
    br i1 %v93.cb, label %if_93_then, label %if_93_else
if_93_then:
    %v95 = add i64 0, 0
    %v96 = load i64, ptr %v34
    %v97 = sub i64 %v95, %v96
    br label %if_93_merge
if_93_else:
    %v100 = load i64, ptr %v34
    br label %if_93_merge
if_93_merge:
    %v103 = phi i64 [ %v97, %if_93_then ], [ %v100, %if_93_else ]
    ret i64 %v103
}

define i64 @orion_main() {
entry:
    %v0 = getelementptr i8, ptr @.str_2, i64 16
    %v1 = call ptr @text__upper(ptr %v0)
    %v2 = getelementptr i8, ptr @.str_3, i64 16
    %v3.e = call i64 @orion_text_eq(ptr %v1, ptr %v2)
    %v3 = add i64 %v3.e, 0
    %v4.cb = icmp ne i64 %v3, 0
    br i1 %v4.cb, label %if_4_then, label %if_4_else
if_4_then:
    %v6 = getelementptr i8, ptr @.str_4, i64 16
    %v7 = call ptr @text__lower(ptr %v6)
    %v8 = getelementptr i8, ptr @.str_5, i64 16
    %v9.e = call i64 @orion_text_eq(ptr %v7, ptr %v8)
    %v9 = add i64 %v9.e, 0
    br label %if_4_merge
if_4_else:
    %v12 = add i64 0, 0
    br label %if_4_merge
if_4_merge:
    %v15 = phi i64 [ %v9, %if_4_then ], [ %v12, %if_4_else ]
    %v16.cb = icmp ne i64 %v15, 0
    br i1 %v16.cb, label %if_16_then, label %if_16_else
if_16_then:
    %v18 = add i64 0, 12
    br label %if_16_merge
if_16_else:
    %v21 = add i64 0, 0
    br label %if_16_merge
if_16_merge:
    %v24 = phi i64 [ %v18, %if_16_then ], [ %v21, %if_16_else ]
    %v25 = getelementptr i8, ptr @.str_6, i64 16
    %v26 = call ptr @text__upper(ptr %v25)
    %v27 = getelementptr i8, ptr @.str_7, i64 16
    %v28.e = call i64 @orion_text_eq(ptr %v26, ptr %v27)
    %v28 = add i64 %v28.e, 0
    %v29.cb = icmp ne i64 %v28, 0
    br i1 %v29.cb, label %if_29_then, label %if_29_else
if_29_then:
    %v31 = getelementptr i8, ptr @.str_8, i64 16
    %v32 = call ptr @text__lower(ptr %v31)
    %v33 = getelementptr i8, ptr @.str_9, i64 16
    %v34.e = call i64 @orion_text_eq(ptr %v32, ptr %v33)
    %v34 = add i64 %v34.e, 0
    br label %if_29_merge
if_29_else:
    %v37 = add i64 0, 0
    br label %if_29_merge
if_29_merge:
    %v40 = phi i64 [ %v34, %if_29_then ], [ %v37, %if_29_else ]
    %v41.cb = icmp ne i64 %v40, 0
    br i1 %v41.cb, label %if_41_then, label %if_41_else
if_41_then:
    %v43 = add i64 0, 10
    br label %if_41_merge
if_41_else:
    %v46 = add i64 0, 0
    br label %if_41_merge
if_41_merge:
    %v49 = phi i64 [ %v43, %if_41_then ], [ %v46, %if_41_else ]
    %v50 = getelementptr i8, ptr @.str_10, i64 16
    %v51 = call ptr @text__upper(ptr %v50)
    %v52 = getelementptr i8, ptr @.str_11, i64 16
    %v53.e = call i64 @orion_text_eq(ptr %v51, ptr %v52)
    %v53 = add i64 %v53.e, 0
    %v54.cb = icmp ne i64 %v53, 0
    br i1 %v54.cb, label %if_54_then, label %if_54_else
if_54_then:
    %v56 = getelementptr i8, ptr @.str_12, i64 16
    %v57 = call ptr @text__lower(ptr %v56)
    %v58 = getelementptr i8, ptr @.str_13, i64 16
    %v59.e = call i64 @orion_text_eq(ptr %v57, ptr %v58)
    %v59 = add i64 %v59.e, 0
    br label %if_54_merge
if_54_else:
    %v62 = add i64 0, 0
    br label %if_54_merge
if_54_merge:
    %v65 = phi i64 [ %v59, %if_54_then ], [ %v62, %if_54_else ]
    %v66.cb = icmp ne i64 %v65, 0
    br i1 %v66.cb, label %if_66_then, label %if_66_else
if_66_then:
    %v68 = add i64 0, 10
    br label %if_66_merge
if_66_else:
    %v71 = add i64 0, 0
    br label %if_66_merge
if_66_merge:
    %v74 = phi i64 [ %v68, %if_66_then ], [ %v71, %if_66_else ]
    %v75 = getelementptr i8, ptr @.str_14, i64 16
    %v76 = call ptr @text__upper(ptr %v75)
    %v77 = getelementptr i8, ptr @.str_15, i64 16
    %v78.e = call i64 @orion_text_eq(ptr %v76, ptr %v77)
    %v78 = add i64 %v78.e, 0
    %v79.cb = icmp ne i64 %v78, 0
    br i1 %v79.cb, label %if_79_then, label %if_79_else
if_79_then:
    %v81 = getelementptr i8, ptr @.str_15, i64 16
    %v82 = call ptr @text__lower(ptr %v81)
    %v83 = getelementptr i8, ptr @.str_14, i64 16
    %v84.e = call i64 @orion_text_eq(ptr %v82, ptr %v83)
    %v84 = add i64 %v84.e, 0
    br label %if_79_merge
if_79_else:
    %v87 = add i64 0, 0
    br label %if_79_merge
if_79_merge:
    %v90 = phi i64 [ %v84, %if_79_then ], [ %v87, %if_79_else ]
    %v91.cb = icmp ne i64 %v90, 0
    br i1 %v91.cb, label %if_91_then, label %if_91_else
if_91_then:
    %v93 = add i64 0, 6
    br label %if_91_merge
if_91_else:
    %v96 = add i64 0, 0
    br label %if_91_merge
if_91_merge:
    %v99 = phi i64 [ %v93, %if_91_then ], [ %v96, %if_91_else ]
    %v100 = getelementptr i8, ptr @.str_16, i64 16
    %v101 = call ptr @text__upper(ptr %v100)
    %v102 = getelementptr i8, ptr @.str_17, i64 16
    %v103.e = call i64 @orion_text_eq(ptr %v101, ptr %v102)
    %v103 = add i64 %v103.e, 0
    %v104.cb = icmp ne i64 %v103, 0
    br i1 %v104.cb, label %if_104_then, label %if_104_else
if_104_then:
    %v106 = getelementptr i8, ptr @.str_18, i64 16
    %v107 = call i64 @text__characters(ptr %v106)
    %v108 = add i64 0, 3
    %v109.b = icmp eq i64 %v107, %v108
    %v109 = zext i1 %v109.b to i64
    br label %if_104_merge
if_104_else:
    %v112 = add i64 0, 0
    br label %if_104_merge
if_104_merge:
    %v115 = phi i64 [ %v109, %if_104_then ], [ %v112, %if_104_else ]
    %v116.cb = icmp ne i64 %v115, 0
    br i1 %v116.cb, label %if_116_then, label %if_116_else
if_116_then:
    %v118 = getelementptr i8, ptr @.str_18, i64 16
    %v119 = call i64 @orion_tlen(ptr %v118)
    %v120 = add i64 0, 4
    %v121.b = icmp eq i64 %v119, %v120
    %v121 = zext i1 %v121.b to i64
    br label %if_116_merge
if_116_else:
    %v124 = add i64 0, 0
    br label %if_116_merge
if_116_merge:
    %v127 = phi i64 [ %v121, %if_116_then ], [ %v124, %if_116_else ]
    %v128.cb = icmp ne i64 %v127, 0
    br i1 %v128.cb, label %if_128_then, label %if_128_else
if_128_then:
    %v130 = add i64 0, 4
    br label %if_128_merge
if_128_else:
    %v133 = add i64 0, 0
    br label %if_128_merge
if_128_merge:
    %v136 = phi i64 [ %v130, %if_128_then ], [ %v133, %if_128_else ]
    %v137 = add i64 %v24, %v49
    %v138 = add i64 %v137, %v74
    %v139 = add i64 %v138, %v99
    %v140 = add i64 %v139, %v136
    ret i64 %v140
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
