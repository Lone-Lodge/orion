; orion_emit_llvm output
declare i32 @printf(ptr, ...)
declare i32 @puts(ptr)
declare ptr @malloc(i64)
declare i64 @strlen(ptr)
declare ptr @strcpy(ptr, ptr)
declare ptr @strcat(ptr, ptr)
declare i32 @strcmp(ptr, ptr)
declare i32 @snprintf(ptr, i64, ptr, ...)
@.fmt_int = private unnamed_addr constant [6 x i8] c"%lld\0A\00"
@.fmt_int_raw = private unnamed_addr constant [5 x i8] c"%lld\00"

define ptr @orion_text_concat(ptr %a, ptr %b) {
entry:
  %la = call i64 @strlen(ptr %a)
  %lb = call i64 @strlen(ptr %b)
  %sum = add i64 %la, %lb
  %total = add i64 %sum, 1
  %buf = call ptr @malloc(i64 %total)
  %_1 = call ptr @strcpy(ptr %buf, ptr %a)
  %_2 = call ptr @strcat(ptr %buf, ptr %b)
  ret ptr %buf
}

define ptr @orion_int_to_text(i64 %n) {
entry:
  %buf = call ptr @malloc(i64 32)
  %_ = call i32 (ptr, i64, ptr, ...) @snprintf(ptr %buf, i64 32, ptr @.fmt_int_raw, i64 %n)
  ret ptr %buf
}

declare ptr @memcpy(ptr, ptr, i64)

define ptr @orion_text_slice(ptr %src, i64 %lo, i64 %hi) {
entry:
  %src_len = call i64 @strlen(ptr %src)
  %lo_neg = icmp slt i64 %lo, 0
  %lo_safe = select i1 %lo_neg, i64 0, i64 %lo
  %hi_big = icmp sgt i64 %hi, %src_len
  %hi_safe = select i1 %hi_big, i64 %src_len, i64 %hi
  %hi_lt_lo = icmp slt i64 %hi_safe, %lo_safe
  %hi_final = select i1 %hi_lt_lo, i64 %lo_safe, i64 %hi_safe
  %slice_len = sub i64 %hi_final, %lo_safe
  %total = add i64 %slice_len, 1
  %buf = call ptr @malloc(i64 %total)
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
  %src_len = call i64 @strlen(ptr %src)
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
  %buf_sz = add i64 %list_len, 1
  %buf = call ptr @malloc(i64 %buf_sz)
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

define ptr @orion_slot_get(ptr %key) {
entry:
  %m = load ptr, ptr @orion_slots
  %is_null = icmp eq ptr %m, null
  br i1 %is_null, label %init, label %get
init:
  %new = call ptr @orion_map_new(i64 16)
  store ptr %new, ptr @orion_slots
  br label %get
get:
  %m2 = load ptr, ptr @orion_slots
  %has = call i64 @orion_map_has(ptr %m2, ptr %key)
  %miss = icmp eq i64 %has, 0
  br i1 %miss, label %empty, label %fetch
empty:
  ret ptr @.empty_str
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
  %new = call ptr @orion_map_new(i64 16)
  store ptr %new, ptr @orion_slots
  br label %store
store:
  %m2 = load ptr, ptr @orion_slots
  call void @orion_map_set(ptr %m2, ptr %key, i64 %val)
  ret i64 0
}

declare ptr @fopen(ptr, ptr)
declare i32 @fclose(ptr)
declare i64 @fread(ptr, i64, i64, ptr)
declare i64 @fwrite(ptr, i64, i64, ptr)
declare i32 @fseek(ptr, i64, i32)
declare i64 @ftell(ptr)
@.fmode_r = private unnamed_addr constant [3 x i8] c"rb\00"
@.fmode_w = private unnamed_addr constant [3 x i8] c"wb\00"
@.empty_str = private unnamed_addr constant [1 x i8] c"\00"

define ptr @orion_file_read(ptr %path) {
entry:
  %fp = call ptr @fopen(ptr %path, ptr @.fmode_r)
  %is_null = icmp eq ptr %fp, null
  br i1 %is_null, label %err, label %ok
err:
  ret ptr @.empty_str
ok:
  %_seek = call i32 @fseek(ptr %fp, i64 0, i32 2)
  %size = call i64 @ftell(ptr %fp)
  %_rew = call i32 @fseek(ptr %fp, i64 0, i32 0)
  %buf_sz = add i64 %size, 1
  %buf = call ptr @malloc(i64 %buf_sz)
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
  %len = call i64 @strlen(ptr %content)
  %_wrote = call i64 @fwrite(ptr %content, i64 1, i64 %len, ptr %fp)
  %_close = call i32 @fclose(ptr %fp)
  ret i64 1
}

define ptr @orion_list_new(i64 %cap) {
entry:
  %bytes = mul i64 %cap, 8
  %total = add i64 %bytes, 8
  %buf = call ptr @malloc(i64 %total)
  store i64 %cap, ptr %buf
  ret ptr %buf
}

define i64 @orion_list_len(ptr %list) {
entry:
  %len = load i64, ptr %list
  ret i64 %len
}

define i64 @orion_list_at(ptr %list, i64 %idx) {
entry:
  %offset = add i64 %idx, 1
  %slot = getelementptr i64, ptr %list, i64 %offset
  %val = load i64, ptr %slot
  ret i64 %val
}

define void @orion_list_set(ptr %list, i64 %idx, i64 %val) {
entry:
  %offset = add i64 %idx, 1
  %slot = getelementptr i64, ptr %list, i64 %offset
  store i64 %val, ptr %slot
  ret void
}

define ptr @orion_list_push(ptr %list, i64 %val) {
entry:
  %old_len = load i64, ptr %list
  %new_len = add i64 %old_len, 1
  %new_list = call ptr @orion_list_new(i64 %new_len)
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %bdy ]
  %done = icmp sge i64 %i, %old_len
  br i1 %done, label %after, label %bdy
bdy:
  %item = call i64 @orion_list_at(ptr %list, i64 %i)
  call void @orion_list_set(ptr %new_list, i64 %i, i64 %item)
  %i_next = add i64 %i, 1
  br label %hdr
after:
  call void @orion_list_set(ptr %new_list, i64 %old_len, i64 %val)
  ret ptr %new_list
}

; SIMD-style elementwise list ops. Generic int-list version — type
; specialization (real <N x i64> vector ops) is a future optimization.
define ptr @orion_vec_add(ptr %a, ptr %b) {
entry:
  %la = load i64, ptr %a
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
  %la = load i64, ptr %a
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
  %la = load i64, ptr %a
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
  %la = load i64, ptr %a
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

define ptr @orion_map_new(i64 %cap) {
entry:
  %entry_bytes = mul i64 %cap, 16
  %total = add i64 %entry_bytes, 8
  %buf = call ptr @malloc(i64 %total)
  store i64 0, ptr %buf
  ret ptr %buf
}

define void @orion_map_set(ptr %map, ptr %key, i64 %val) {
entry:
  %len = load i64, ptr %map
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %step ]
  %done = icmp sge i64 %i, %len
  br i1 %done, label %append, label %check
check:
  %idx2 = mul i64 %i, 2
  %ki = add i64 %idx2, 1
  %k_slot = getelementptr i64, ptr %map, i64 %ki
  %k_int = load i64, ptr %k_slot
  %k_ptr = inttoptr i64 %k_int to ptr
  %cmp = call i32 @strcmp(ptr %k_ptr, ptr %key)
  %eq = icmp eq i32 %cmp, 0
  br i1 %eq, label %update, label %step
step:
  %i_next = add i64 %i, 1
  br label %hdr
update:
  %vi = add i64 %idx2, 2
  %v_slot = getelementptr i64, ptr %map, i64 %vi
  store i64 %val, ptr %v_slot
  ret void
append:
  %new_idx2 = mul i64 %len, 2
  %new_ki = add i64 %new_idx2, 1
  %new_vi = add i64 %new_idx2, 2
  %new_k_slot = getelementptr i64, ptr %map, i64 %new_ki
  %new_v_slot = getelementptr i64, ptr %map, i64 %new_vi
  %key_int = ptrtoint ptr %key to i64
  store i64 %key_int, ptr %new_k_slot
  store i64 %val, ptr %new_v_slot
  %new_len = add i64 %len, 1
  store i64 %new_len, ptr %map
  ret void
}

define i64 @orion_map_get(ptr %map, ptr %key) {
entry:
  %len = load i64, ptr %map
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %step ]
  %done = icmp sge i64 %i, %len
  br i1 %done, label %miss, label %body
body:
  %ki = mul i64 %i, 2
  %ki1 = add i64 %ki, 1
  %vi = add i64 %ki, 2
  %k_slot = getelementptr i64, ptr %map, i64 %ki1
  %k_int = load i64, ptr %k_slot
  %k_ptr = inttoptr i64 %k_int to ptr
  %cmp = call i32 @strcmp(ptr %k_ptr, ptr %key)
  %eq = icmp eq i32 %cmp, 0
  br i1 %eq, label %hit, label %step
hit:
  %v_slot = getelementptr i64, ptr %map, i64 %vi
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
  %len = load i64, ptr %map
  br label %hdr
hdr:
  %i = phi i64 [ 0, %entry ], [ %i_next, %step ]
  %done = icmp sge i64 %i, %len
  br i1 %done, label %miss, label %body
body:
  %ki = mul i64 %i, 2
  %ki1 = add i64 %ki, 1
  %k_slot = getelementptr i64, ptr %map, i64 %ki1
  %k_int = load i64, ptr %k_slot
  %k_ptr = inttoptr i64 %k_int to ptr
  %cmp = call i32 @strcmp(ptr %k_ptr, ptr %key)
  %eq = icmp eq i32 %cmp, 0
  br i1 %eq, label %hit, label %step
hit:
  ret i64 1
step:
  %i_next = add i64 %i, 1
  br label %hdr
miss:
  ret i64 0
}


