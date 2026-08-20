; orion_emit_llvm output
target datalayout = "e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc19.44.35209"
declare i32 @printf(ptr, ...)
declare i32 @puts(ptr)
declare ptr @malloc(i64)
declare ptr @orion_f64_literal_hex(ptr)
declare i64 @orion_text_to_int(ptr)
declare double @orion_text_to_f64(ptr)
declare i64 @orion_par_run(ptr, i64)
declare i64 @orion_trace_enter(ptr)
declare i64 @orion_line(ptr)
declare i64 @orion_dbg_i(ptr, i64)
declare i64 @orion_trace_exit()
declare i64 @orion_slot_watch(ptr)
declare i64 @orion_dbg_t(ptr, ptr)
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
declare i64 @orion_task_pump()
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

declare ptr @orion_file_read(ptr)
declare i64 @orion_file_write(ptr, ptr)

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

declare i64 @orion_require_at(i64, ptr)
declare i64 @orion_ensure_at(i64, ptr)

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

define ptr @orion_arguments() {
entry:
  %n = load i64, ptr @orion_argc
  %out = call ptr @orion_list_new(i64 %n)
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %bdy ]
  %done = icmp sge i64 %i, %n
  br i1 %done, label %after, label %bdy
bdy:
  %arr = load ptr, ptr @orion_argv
  %slot = getelementptr ptr, ptr %arr, i64 %i
  %raw = load ptr, ptr %slot
  %t = call ptr @orion_text_from_c(ptr %raw)
  %ti = ptrtoint ptr %t to i64
  call void @orion_list_set(ptr %out, i64 %i, i64 %ti)
  %i_next = add i64 %i, 1
  br label %hdr
after:
  ret ptr %out
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


@.str_0 = private unnamed_addr constant [32 x i8] c"\93\0D\14\24\00\00\00\00\0F\00\00\00\00\00\00\00ASSERT FAILED: \00", align 8

define ptr @iter__each(ptr %p0, ptr %p1) {
entry:
    %v3 = alloca ptr, align 8
    %v7 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i64, ptr @orion_empty_list, i64 0
    store ptr %v2, ptr %v3
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    %v6 = call i64 @orion_list_len(ptr %v0)
    store i64 %v5, ptr %v7
    %v8 = add i64 0, 0
    br label %for_5_header
for_5_header:
    %v11 = load i64, ptr %v7
    %v12.b = icmp slt i64 %v11, %v6
    %v12 = zext i1 %v12.b to i64
    %v13.cb = icmp ne i64 %v12, 0
    br i1 %v13.cb, label %for_5_body, label %for_5_end
for_5_body:
    %v15 = load ptr, ptr %v3
    %v16 = call i64 @orion_list_at(ptr %v0, i64 %v11)
    %v17.fpi = call i64 @orion_list_at(ptr %v1, i64 0)
    %v17.flg = call i64 @orion_list_at(ptr %v1, i64 1)
    %v17.p = inttoptr i64 %v17.fpi to ptr
    %v17.isl = icmp eq i64 %v17.flg, 1
    br i1 %v17.isl, label %clam17, label %cpln17
clam17:
    %v17.r1 = call i64 %v17.p(ptr %v1, i64 %v16)
    br label %cmrg17
cpln17:
    %v17.r2 = call i64 %v17.p(i64 %v16)
    br label %cmrg17
cmrg17:
    %v17 = phi i64 [ %v17.r1, %clam17 ], [ %v17.r2, %cpln17 ]
    %v18 = call ptr @orion_list_push_mut(ptr %v15, i64 %v17)
    store ptr %v18, ptr %v3
    %v19 = add i64 0, 0
    br label %for_5_step
for_5_step:
    %v22 = add i64 0, 1
    %v23 = add i64 %v11, %v22
    store i64 %v23, ptr %v7
    %v24 = add i64 0, 0
    br label %for_5_header
for_5_end:
    %v27 = load ptr, ptr %v3
    ret ptr %v27
}

define ptr @iter__keep(ptr %p0, ptr %p1) {
entry:
    %v3 = alloca ptr, align 8
    %v7 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = getelementptr i64, ptr @orion_empty_list, i64 0
    store ptr %v2, ptr %v3
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    %v6 = call i64 @orion_list_len(ptr %v0)
    store i64 %v5, ptr %v7
    %v8 = add i64 0, 0
    br label %for_5_header
for_5_header:
    %v11 = load i64, ptr %v7
    %v12.b = icmp slt i64 %v11, %v6
    %v12 = zext i1 %v12.b to i64
    %v13.cb = icmp ne i64 %v12, 0
    br i1 %v13.cb, label %for_5_body, label %for_5_end
for_5_body:
    %v15 = call i64 @orion_list_at(ptr %v0, i64 %v11)
    %v16.fpi = call i64 @orion_list_at(ptr %v1, i64 0)
    %v16.flg = call i64 @orion_list_at(ptr %v1, i64 1)
    %v16.p = inttoptr i64 %v16.fpi to ptr
    %v16.isl = icmp eq i64 %v16.flg, 1
    br i1 %v16.isl, label %clam16, label %cpln16
clam16:
    %v16.r1 = call i64 %v16.p(ptr %v1, i64 %v15)
    br label %cmrg16
cpln16:
    %v16.r2 = call i64 %v16.p(i64 %v15)
    br label %cmrg16
cmrg16:
    %v16 = phi i64 [ %v16.r1, %clam16 ], [ %v16.r2, %cpln16 ]
    %v17.cb = icmp ne i64 %v16, 0
    br i1 %v17.cb, label %if_17_then, label %if_17_else
if_17_then:
    %v19 = load ptr, ptr %v3
    %v20 = call ptr @orion_list_push_mut(ptr %v19, i64 %v15)
    store ptr %v20, ptr %v3
    %v21 = add i64 0, 0
    br label %if_17_merge
if_17_else:
    br label %if_17_merge
if_17_merge:
    br label %for_5_step
for_5_step:
    %v28 = add i64 0, 1
    %v29 = add i64 %v11, %v28
    store i64 %v29, ptr %v7
    %v30 = add i64 0, 0
    br label %for_5_header
for_5_end:
    %v33 = load ptr, ptr %v3
    ret ptr %v33
}

define i64 @iter__combine(ptr %p0, i64 %p1, ptr %p2) {
entry:
    %v3 = alloca i64, align 8
    %v7 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, %p1
    %v2 = getelementptr i8, ptr %p2, i64 0
    store i64 %v1, ptr %v3
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    %v6 = call i64 @orion_list_len(ptr %v0)
    store i64 %v5, ptr %v7
    %v8 = add i64 0, 0
    br label %for_5_header
for_5_header:
    %v11 = load i64, ptr %v7
    %v12.b = icmp slt i64 %v11, %v6
    %v12 = zext i1 %v12.b to i64
    %v13.cb = icmp ne i64 %v12, 0
    br i1 %v13.cb, label %for_5_body, label %for_5_end
for_5_body:
    %v15 = load i64, ptr %v3
    %v16 = call i64 @orion_list_at(ptr %v0, i64 %v11)
    %v17.fpi = call i64 @orion_list_at(ptr %v2, i64 0)
    %v17.flg = call i64 @orion_list_at(ptr %v2, i64 1)
    %v17.p = inttoptr i64 %v17.fpi to ptr
    %v17.isl = icmp eq i64 %v17.flg, 1
    br i1 %v17.isl, label %clam17, label %cpln17
clam17:
    %v17.r1 = call i64 %v17.p(ptr %v2, i64 %v15, i64 %v16)
    br label %cmrg17
cpln17:
    %v17.r2 = call i64 %v17.p(i64 %v15, i64 %v16)
    br label %cmrg17
cmrg17:
    %v17 = phi i64 [ %v17.r1, %clam17 ], [ %v17.r2, %cpln17 ]
    store i64 %v17, ptr %v3
    %v18 = add i64 0, 0
    br label %for_5_step
for_5_step:
    %v21 = add i64 0, 1
    %v22 = add i64 %v11, %v21
    store i64 %v22, ptr %v7
    %v23 = add i64 0, 0
    br label %for_5_header
for_5_end:
    %v26 = load i64, ptr %v3
    ret i64 %v26
}

define i64 @iter__any(ptr %p0, ptr %p1) {
entry:
    %v3 = alloca i64, align 8
    %v7 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = add i64 0, 0
    store i64 %v2, ptr %v3
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    %v6 = call i64 @orion_list_len(ptr %v0)
    store i64 %v5, ptr %v7
    %v8 = add i64 0, 0
    br label %for_5_header
for_5_header:
    %v11 = load i64, ptr %v7
    %v12.b = icmp slt i64 %v11, %v6
    %v12 = zext i1 %v12.b to i64
    %v13.cb = icmp ne i64 %v12, 0
    br i1 %v13.cb, label %for_5_body, label %for_5_end
for_5_body:
    %v15 = call i64 @orion_list_at(ptr %v0, i64 %v11)
    %v16.fpi = call i64 @orion_list_at(ptr %v1, i64 0)
    %v16.flg = call i64 @orion_list_at(ptr %v1, i64 1)
    %v16.p = inttoptr i64 %v16.fpi to ptr
    %v16.isl = icmp eq i64 %v16.flg, 1
    br i1 %v16.isl, label %clam16, label %cpln16
clam16:
    %v16.r1 = call i64 %v16.p(ptr %v1, i64 %v15)
    br label %cmrg16
cpln16:
    %v16.r2 = call i64 %v16.p(i64 %v15)
    br label %cmrg16
cmrg16:
    %v16 = phi i64 [ %v16.r1, %clam16 ], [ %v16.r2, %cpln16 ]
    %v17.cb = icmp ne i64 %v16, 0
    br i1 %v17.cb, label %if_17_then, label %if_17_else
if_17_then:
    %v19 = add i64 0, 1
    store i64 %v19, ptr %v3
    %v20 = add i64 0, 0
    br label %if_17_merge
if_17_else:
    br label %if_17_merge
if_17_merge:
    br label %for_5_step
for_5_step:
    %v27 = add i64 0, 1
    %v28 = add i64 %v11, %v27
    store i64 %v28, ptr %v7
    %v29 = add i64 0, 0
    br label %for_5_header
for_5_end:
    %v32 = load i64, ptr %v3
    ret i64 %v32
}

define i64 @iter__all(ptr %p0, ptr %p1) {
entry:
    %v3 = alloca i64, align 8
    %v7 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = add i64 0, 1
    store i64 %v2, ptr %v3
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    %v6 = call i64 @orion_list_len(ptr %v0)
    store i64 %v5, ptr %v7
    %v8 = add i64 0, 0
    br label %for_5_header
for_5_header:
    %v11 = load i64, ptr %v7
    %v12.b = icmp slt i64 %v11, %v6
    %v12 = zext i1 %v12.b to i64
    %v13.cb = icmp ne i64 %v12, 0
    br i1 %v13.cb, label %for_5_body, label %for_5_end
for_5_body:
    %v15 = call i64 @orion_list_at(ptr %v0, i64 %v11)
    %v16.fpi = call i64 @orion_list_at(ptr %v1, i64 0)
    %v16.flg = call i64 @orion_list_at(ptr %v1, i64 1)
    %v16.p = inttoptr i64 %v16.fpi to ptr
    %v16.isl = icmp eq i64 %v16.flg, 1
    br i1 %v16.isl, label %clam16, label %cpln16
clam16:
    %v16.r1 = call i64 %v16.p(ptr %v1, i64 %v15)
    br label %cmrg16
cpln16:
    %v16.r2 = call i64 %v16.p(i64 %v15)
    br label %cmrg16
cmrg16:
    %v16 = phi i64 [ %v16.r1, %clam16 ], [ %v16.r2, %cpln16 ]
    %v17.n = icmp eq i64 %v16, 0
    %v17 = zext i1 %v17.n to i64
    %v18.cb = icmp ne i64 %v17, 0
    br i1 %v18.cb, label %if_18_then, label %if_18_else
if_18_then:
    %v20 = add i64 0, 0
    store i64 %v20, ptr %v3
    %v21 = add i64 0, 0
    br label %if_18_merge
if_18_else:
    br label %if_18_merge
if_18_merge:
    br label %for_5_step
for_5_step:
    %v28 = add i64 0, 1
    %v29 = add i64 %v11, %v28
    store i64 %v29, ptr %v7
    %v30 = add i64 0, 0
    br label %for_5_header
for_5_end:
    %v33 = load i64, ptr %v3
    ret i64 %v33
}

define i64 @iter__find_index(ptr %p0, ptr %p1) {
entry:
    %v5 = alloca i64, align 8
    %v9 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = add i64 0, 0
    %v3 = add i64 0, 1
    %v4 = sub i64 %v2, %v3
    store i64 %v4, ptr %v5
    %v6 = add i64 0, 0
    %v7 = add i64 0, 0
    %v8 = call i64 @orion_list_len(ptr %v0)
    store i64 %v7, ptr %v9
    %v10 = add i64 0, 0
    br label %for_7_header
for_7_header:
    %v13 = load i64, ptr %v9
    %v14.b = icmp slt i64 %v13, %v8
    %v14 = zext i1 %v14.b to i64
    %v15.cb = icmp ne i64 %v14, 0
    br i1 %v15.cb, label %for_7_body, label %for_7_end
for_7_body:
    %v17 = load i64, ptr %v5
    %v18 = add i64 0, 0
    %v19.b = icmp slt i64 %v17, %v18
    %v19 = zext i1 %v19.b to i64
    %v20.cb = icmp ne i64 %v19, 0
    br i1 %v20.cb, label %if_20_then, label %if_20_else
if_20_then:
    %v22 = call i64 @orion_list_at(ptr %v0, i64 %v13)
    %v23.fpi = call i64 @orion_list_at(ptr %v1, i64 0)
    %v23.flg = call i64 @orion_list_at(ptr %v1, i64 1)
    %v23.p = inttoptr i64 %v23.fpi to ptr
    %v23.isl = icmp eq i64 %v23.flg, 1
    br i1 %v23.isl, label %clam23, label %cpln23
clam23:
    %v23.r1 = call i64 %v23.p(ptr %v1, i64 %v22)
    br label %cmrg23
cpln23:
    %v23.r2 = call i64 %v23.p(i64 %v22)
    br label %cmrg23
cmrg23:
    %v23 = phi i64 [ %v23.r1, %clam23 ], [ %v23.r2, %cpln23 ]
    %v24.cb = icmp ne i64 %v23, 0
    br i1 %v24.cb, label %if_24_then, label %if_24_else
if_24_then:
    store i64 %v13, ptr %v5
    %v26 = add i64 0, 0
    br label %if_24_merge
if_24_else:
    br label %if_24_merge
if_24_merge:
    br label %if_20_merge
if_20_else:
    br label %if_20_merge
if_20_merge:
    br label %for_7_step
for_7_step:
    %v37 = add i64 0, 1
    %v38 = add i64 %v13, %v37
    store i64 %v38, ptr %v9
    %v39 = add i64 0, 0
    br label %for_7_header
for_7_end:
    %v42 = load i64, ptr %v5
    ret i64 %v42
}

define i64 @iter__count(ptr %p0, ptr %p1) {
entry:
    %v3 = alloca i64, align 8
    %v7 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = add i64 0, 0
    store i64 %v2, ptr %v3
    %v4 = add i64 0, 0
    %v5 = add i64 0, 0
    %v6 = call i64 @orion_list_len(ptr %v0)
    store i64 %v5, ptr %v7
    %v8 = add i64 0, 0
    br label %for_5_header
for_5_header:
    %v11 = load i64, ptr %v7
    %v12.b = icmp slt i64 %v11, %v6
    %v12 = zext i1 %v12.b to i64
    %v13.cb = icmp ne i64 %v12, 0
    br i1 %v13.cb, label %for_5_body, label %for_5_end
for_5_body:
    %v15 = call i64 @orion_list_at(ptr %v0, i64 %v11)
    %v16.fpi = call i64 @orion_list_at(ptr %v1, i64 0)
    %v16.flg = call i64 @orion_list_at(ptr %v1, i64 1)
    %v16.p = inttoptr i64 %v16.fpi to ptr
    %v16.isl = icmp eq i64 %v16.flg, 1
    br i1 %v16.isl, label %clam16, label %cpln16
clam16:
    %v16.r1 = call i64 %v16.p(ptr %v1, i64 %v15)
    br label %cmrg16
cpln16:
    %v16.r2 = call i64 %v16.p(i64 %v15)
    br label %cmrg16
cmrg16:
    %v16 = phi i64 [ %v16.r1, %clam16 ], [ %v16.r2, %cpln16 ]
    %v17.cb = icmp ne i64 %v16, 0
    br i1 %v17.cb, label %if_17_then, label %if_17_else
if_17_then:
    %v19 = load i64, ptr %v3
    %v20 = add i64 0, 1
    %v21 = add i64 %v19, %v20
    store i64 %v21, ptr %v3
    %v22 = add i64 0, 0
    br label %if_17_merge
if_17_else:
    br label %if_17_merge
if_17_merge:
    br label %for_5_step
for_5_step:
    %v29 = add i64 0, 1
    %v30 = add i64 %v11, %v29
    store i64 %v30, ptr %v7
    %v31 = add i64 0, 0
    br label %for_5_header
for_5_end:
    %v34 = load i64, ptr %v3
    ret i64 %v34
}

define i64 @iter__sum(ptr %p0) {
entry:
    %v2 = alloca i64, align 8
    %v6 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = add i64 0, 0
    store i64 %v1, ptr %v2
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
    %v14 = load i64, ptr %v2
    %v15 = call i64 @orion_list_at(ptr %v0, i64 %v10)
    %v16 = add i64 %v14, %v15
    store i64 %v16, ptr %v2
    %v17 = add i64 0, 0
    br label %for_4_step
for_4_step:
    %v20 = add i64 0, 1
    %v21 = add i64 %v10, %v20
    store i64 %v21, ptr %v6
    %v22 = add i64 0, 0
    br label %for_4_header
for_4_end:
    %v25 = load i64, ptr %v2
    ret i64 %v25
}

define i64 @iter__max_by(ptr %p0, ptr %p1) {
entry:
    %v3 = alloca i64, align 8
    %v15 = alloca i64, align 8
    %v19 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = add i64 0, 0
    store i64 %v2, ptr %v3
    %v4 = add i64 0, 0
    %v5 = call i64 @orion_list_len(ptr %v0)
    %v6 = add i64 0, 0
    %v7.b = icmp sgt i64 %v5, %v6
    %v7 = zext i1 %v7.b to i64
    %v8.cb = icmp ne i64 %v7, 0
    br i1 %v8.cb, label %if_8_then, label %if_8_else
if_8_then:
    %v10 = add i64 0, 0
    %v11 = call i64 @orion_list_at(ptr %v0, i64 %v10)
    store i64 %v11, ptr %v3
    %v12 = add i64 0, 0
    %v13 = load i64, ptr %v3
    %v14.fpi = call i64 @orion_list_at(ptr %v1, i64 0)
    %v14.flg = call i64 @orion_list_at(ptr %v1, i64 1)
    %v14.p = inttoptr i64 %v14.fpi to ptr
    %v14.isl = icmp eq i64 %v14.flg, 1
    br i1 %v14.isl, label %clam14, label %cpln14
clam14:
    %v14.r1 = call i64 %v14.p(ptr %v1, i64 %v13)
    br label %cmrg14
cpln14:
    %v14.r2 = call i64 %v14.p(i64 %v13)
    br label %cmrg14
cmrg14:
    %v14 = phi i64 [ %v14.r1, %clam14 ], [ %v14.r2, %cpln14 ]
    store i64 %v14, ptr %v15
    %v16 = add i64 0, 0
    %v17 = add i64 0, 1
    %v18 = call i64 @orion_list_len(ptr %v0)
    store i64 %v17, ptr %v19
    %v20 = add i64 0, 0
    br label %for_17_header
for_17_header:
    %v23 = load i64, ptr %v19
    %v24.b = icmp slt i64 %v23, %v18
    %v24 = zext i1 %v24.b to i64
    %v25.cb = icmp ne i64 %v24, 0
    br i1 %v25.cb, label %for_17_body, label %for_17_end
for_17_body:
    %v27 = call i64 @orion_list_at(ptr %v0, i64 %v23)
    %v28.fpi = call i64 @orion_list_at(ptr %v1, i64 0)
    %v28.flg = call i64 @orion_list_at(ptr %v1, i64 1)
    %v28.p = inttoptr i64 %v28.fpi to ptr
    %v28.isl = icmp eq i64 %v28.flg, 1
    br i1 %v28.isl, label %clam28, label %cpln28
clam28:
    %v28.r1 = call i64 %v28.p(ptr %v1, i64 %v27)
    br label %cmrg28
cpln28:
    %v28.r2 = call i64 %v28.p(i64 %v27)
    br label %cmrg28
cmrg28:
    %v28 = phi i64 [ %v28.r1, %clam28 ], [ %v28.r2, %cpln28 ]
    %v29 = load i64, ptr %v15
    %v30.b = icmp sgt i64 %v28, %v29
    %v30 = zext i1 %v30.b to i64
    %v31.cb = icmp ne i64 %v30, 0
    br i1 %v31.cb, label %if_31_then, label %if_31_else
if_31_then:
    store i64 %v27, ptr %v3
    %v33 = add i64 0, 0
    store i64 %v28, ptr %v15
    %v34 = add i64 0, 0
    br label %if_31_merge
if_31_else:
    br label %if_31_merge
if_31_merge:
    br label %for_17_step
for_17_step:
    %v41 = add i64 0, 1
    %v42 = add i64 %v23, %v41
    store i64 %v42, ptr %v19
    %v43 = add i64 0, 0
    br label %for_17_header
for_17_end:
    br label %if_8_merge
if_8_else:
    br label %if_8_merge
if_8_merge:
    %v50 = load i64, ptr %v3
    ret i64 %v50
}

define i64 @iter__min_by(ptr %p0, ptr %p1) {
entry:
    %v3 = alloca i64, align 8
    %v15 = alloca i64, align 8
    %v19 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = add i64 0, 0
    store i64 %v2, ptr %v3
    %v4 = add i64 0, 0
    %v5 = call i64 @orion_list_len(ptr %v0)
    %v6 = add i64 0, 0
    %v7.b = icmp sgt i64 %v5, %v6
    %v7 = zext i1 %v7.b to i64
    %v8.cb = icmp ne i64 %v7, 0
    br i1 %v8.cb, label %if_8_then, label %if_8_else
if_8_then:
    %v10 = add i64 0, 0
    %v11 = call i64 @orion_list_at(ptr %v0, i64 %v10)
    store i64 %v11, ptr %v3
    %v12 = add i64 0, 0
    %v13 = load i64, ptr %v3
    %v14.fpi = call i64 @orion_list_at(ptr %v1, i64 0)
    %v14.flg = call i64 @orion_list_at(ptr %v1, i64 1)
    %v14.p = inttoptr i64 %v14.fpi to ptr
    %v14.isl = icmp eq i64 %v14.flg, 1
    br i1 %v14.isl, label %clam14, label %cpln14
clam14:
    %v14.r1 = call i64 %v14.p(ptr %v1, i64 %v13)
    br label %cmrg14
cpln14:
    %v14.r2 = call i64 %v14.p(i64 %v13)
    br label %cmrg14
cmrg14:
    %v14 = phi i64 [ %v14.r1, %clam14 ], [ %v14.r2, %cpln14 ]
    store i64 %v14, ptr %v15
    %v16 = add i64 0, 0
    %v17 = add i64 0, 1
    %v18 = call i64 @orion_list_len(ptr %v0)
    store i64 %v17, ptr %v19
    %v20 = add i64 0, 0
    br label %for_17_header
for_17_header:
    %v23 = load i64, ptr %v19
    %v24.b = icmp slt i64 %v23, %v18
    %v24 = zext i1 %v24.b to i64
    %v25.cb = icmp ne i64 %v24, 0
    br i1 %v25.cb, label %for_17_body, label %for_17_end
for_17_body:
    %v27 = call i64 @orion_list_at(ptr %v0, i64 %v23)
    %v28.fpi = call i64 @orion_list_at(ptr %v1, i64 0)
    %v28.flg = call i64 @orion_list_at(ptr %v1, i64 1)
    %v28.p = inttoptr i64 %v28.fpi to ptr
    %v28.isl = icmp eq i64 %v28.flg, 1
    br i1 %v28.isl, label %clam28, label %cpln28
clam28:
    %v28.r1 = call i64 %v28.p(ptr %v1, i64 %v27)
    br label %cmrg28
cpln28:
    %v28.r2 = call i64 %v28.p(i64 %v27)
    br label %cmrg28
cmrg28:
    %v28 = phi i64 [ %v28.r1, %clam28 ], [ %v28.r2, %cpln28 ]
    %v29 = load i64, ptr %v15
    %v30.b = icmp slt i64 %v28, %v29
    %v30 = zext i1 %v30.b to i64
    %v31.cb = icmp ne i64 %v30, 0
    br i1 %v31.cb, label %if_31_then, label %if_31_else
if_31_then:
    store i64 %v27, ptr %v3
    %v33 = add i64 0, 0
    store i64 %v28, ptr %v15
    %v34 = add i64 0, 0
    br label %if_31_merge
if_31_else:
    br label %if_31_merge
if_31_merge:
    br label %for_17_step
for_17_step:
    %v41 = add i64 0, 1
    %v42 = add i64 %v23, %v41
    store i64 %v42, ptr %v19
    %v43 = add i64 0, 0
    br label %for_17_header
for_17_end:
    br label %if_8_merge
if_8_else:
    br label %if_8_merge
if_8_merge:
    %v50 = load i64, ptr %v3
    ret i64 %v50
}

define ptr @iter__sorted(ptr %p0, ptr %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2.slot = getelementptr i64, ptr %v1, i64 0
    %v2.i = load i64, ptr %v2.slot
    %v2 = inttoptr i64 %v2.i to ptr
    %v3 = call ptr @iter__sort_generic(ptr %v0, ptr %v2)
    ret ptr %v3
}

define ptr @iter__sort_by(ptr %p0, ptr %p1) {
entry:
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    %v2 = call ptr @iter__sort_generic(ptr %v0, ptr %v1)
    ret ptr %v2
}

define ptr @iter__sort_generic(ptr %p0, ptr %p1) {
entry:
    %v2 = alloca ptr, align 8
    %v5 = alloca ptr, align 8
    %v9 = alloca i64, align 8
    %v18 = alloca i64, align 8
    %v23 = alloca i64, align 8
    %v58 = alloca ptr, align 8
    %v63 = alloca i64, align 8
    %v0 = getelementptr i8, ptr %p0, i64 0
    %v1 = getelementptr i8, ptr %p1, i64 0
    store ptr %v0, ptr %v2
    %v3 = add i64 0, 0
    %v4 = getelementptr i64, ptr @orion_empty_list, i64 0
    store ptr %v4, ptr %v5
    %v6 = add i64 0, 0
    %v7 = add i64 0, 0
    %v8 = call i64 @orion_list_len(ptr %v0)
    store i64 %v7, ptr %v9
    %v10 = add i64 0, 0
    br label %for_7_header
for_7_header:
    %v13 = load i64, ptr %v9
    %v14.b = icmp slt i64 %v13, %v8
    %v14 = zext i1 %v14.b to i64
    %v15.cb = icmp ne i64 %v14, 0
    br i1 %v15.cb, label %for_7_body, label %for_7_end
for_7_body:
    %v17 = add i64 0, 0
    store i64 %v17, ptr %v18
    %v19 = add i64 0, 0
    %v20 = add i64 0, 1
    %v21 = load ptr, ptr %v2
    %v22 = call i64 @orion_list_len(ptr %v21)
    store i64 %v20, ptr %v23
    %v24 = add i64 0, 0
    br label %for_20_header
for_20_header:
    %v27 = load i64, ptr %v23
    %v28.b = icmp slt i64 %v27, %v22
    %v28 = zext i1 %v28.b to i64
    %v29.cb = icmp ne i64 %v28, 0
    br i1 %v29.cb, label %for_20_body, label %for_20_end
for_20_body:
    %v31 = load ptr, ptr %v2
    %v32 = call i64 @orion_list_at(ptr %v31, i64 %v27)
    %v33 = load ptr, ptr %v2
    %v34 = load i64, ptr %v18
    %v35 = call i64 @orion_list_at(ptr %v33, i64 %v34)
    %v36.fpi = call i64 @orion_list_at(ptr %v1, i64 0)
    %v36.flg = call i64 @orion_list_at(ptr %v1, i64 1)
    %v36.p = inttoptr i64 %v36.fpi to ptr
    %v36.isl = icmp eq i64 %v36.flg, 1
    br i1 %v36.isl, label %clam36, label %cpln36
clam36:
    %v36.r1 = call i64 %v36.p(ptr %v1, i64 %v32, i64 %v35)
    br label %cmrg36
cpln36:
    %v36.r2 = call i64 %v36.p(i64 %v32, i64 %v35)
    br label %cmrg36
cmrg36:
    %v36 = phi i64 [ %v36.r1, %clam36 ], [ %v36.r2, %cpln36 ]
    %v37.cb = icmp ne i64 %v36, 0
    br i1 %v37.cb, label %if_37_then, label %if_37_else
if_37_then:
    store i64 %v27, ptr %v18
    %v39 = add i64 0, 0
    br label %if_37_merge
if_37_else:
    br label %if_37_merge
if_37_merge:
    br label %for_20_step
for_20_step:
    %v46 = add i64 0, 1
    %v47 = add i64 %v27, %v46
    store i64 %v47, ptr %v23
    %v48 = add i64 0, 0
    br label %for_20_header
for_20_end:
    %v51 = load ptr, ptr %v5
    %v52 = load ptr, ptr %v2
    %v53 = load i64, ptr %v18
    %v54 = call i64 @orion_list_at(ptr %v52, i64 %v53)
    %v55 = call ptr @orion_list_push_mut(ptr %v51, i64 %v54)
    store ptr %v55, ptr %v5
    %v56 = add i64 0, 0
    %v57 = getelementptr i64, ptr @orion_empty_list, i64 0
    store ptr %v57, ptr %v58
    %v59 = add i64 0, 0
    %v60 = add i64 0, 0
    %v61 = load ptr, ptr %v2
    %v62 = call i64 @orion_list_len(ptr %v61)
    store i64 %v60, ptr %v63
    %v64 = add i64 0, 0
    br label %for_60_header
for_60_header:
    %v67 = load i64, ptr %v63
    %v68.b = icmp slt i64 %v67, %v62
    %v68 = zext i1 %v68.b to i64
    %v69.cb = icmp ne i64 %v68, 0
    br i1 %v69.cb, label %for_60_body, label %for_60_end
for_60_body:
    %v71 = load i64, ptr %v18
    %v72.b = icmp ne i64 %v67, %v71
    %v72 = zext i1 %v72.b to i64
    %v73.cb = icmp ne i64 %v72, 0
    br i1 %v73.cb, label %if_73_then, label %if_73_else
if_73_then:
    %v75 = load ptr, ptr %v58
    %v76 = load ptr, ptr %v2
    %v77 = call i64 @orion_list_at(ptr %v76, i64 %v67)
    %v78 = call ptr @orion_list_push(ptr %v75, i64 %v77)
    store ptr %v78, ptr %v58
    %v79 = add i64 0, 0
    br label %if_73_merge
if_73_else:
    br label %if_73_merge
if_73_merge:
    br label %for_60_step
for_60_step:
    %v86 = add i64 0, 1
    %v87 = add i64 %v67, %v86
    store i64 %v87, ptr %v63
    %v88 = add i64 0, 0
    br label %for_60_header
for_60_end:
    %v91 = load ptr, ptr %v58
    store ptr %v91, ptr %v2
    %v92 = add i64 0, 0
    br label %for_7_step
for_7_step:
    %v95 = add i64 0, 1
    %v96 = add i64 %v13, %v95
    store i64 %v96, ptr %v9
    %v97 = add i64 0, 0
    br label %for_7_header
for_7_end:
    %v100 = load ptr, ptr %v5
    ret ptr %v100
}

define i64 @assert__assert(i64 %p0, i64 %p1) {
entry:
    %v0 = add i64 0, %p0
    %v1 = add i64 0, %p1
    %v2.cb = icmp ne i64 %v0, 0
    br i1 %v2.cb, label %if_2_then, label %if_2_else
if_2_then:
    %v4 = add i64 0, 1
    br label %if_2_merge
if_2_else:
    %v7 = getelementptr i8, ptr @.str_0, i64 16
    %v8 = call ptr @orion_int_to_text(i64 %v1)
    %v9 = call ptr @orion_text_concat(ptr %v7, ptr %v8)
    call i32 @puts(ptr %v9)
    %v10 = add i64 0, 0
    %v11 = add i64 0, 0
    br label %if_2_merge
if_2_merge:
    %v14 = phi i64 [ %v4, %if_2_then ], [ %v11, %if_2_else ]
    ret i64 %v14
}

define i64 @orion_main() {
entry:
    %v0 = add i64 0, 40
    %v1 = add i64 0, 3
    %v2 = add i64 %v0, %v1
    ret i64 %v2
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
