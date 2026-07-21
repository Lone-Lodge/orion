# orb `orion_ir`

orion_ir — typed IR for orion-self.

Design:
  - SSA-form: each instruction PRODUCES exactly one value.
  - Other instructions REFERENCE values by ID (index into the
    function's instructions list).
  - Typed: every value has a type (i64, ptr, bool, void).

Pipeline: lex → parse → AST → IR → orion_emit_llvm → .ll → clang → .exe

Today supports: ints, arith (+ - * / %), comparisons, and/or/not,
branches (if/else via br + phi), function calls, recursion,
typed params (int + Text), strings + interpolation + concat + cmp,
for-range, for-in-list, loop + break/continue, int lists with
at/len iteration.

Roadmap: maps, text lists, struct types.

## Public functions

### `pub fn ir_type_i64() -> Text: "i64"`

--- Value types (Text constants) ---

### `pub fn ir_type_ptr() -> Text: "ptr"`


### `pub fn ir_type_bool() -> Text: "bool"`


### `pub fn ir_type_void() -> Text: "void"`


### `pub fn compile_error(msg: Text)`


### `pub fn compile_errors() -> int`


### `pub fn ir_iconst(value: int) -> Inst`

--- Instruction builders ---

### `pub fn ir_iadd(lhs: int, rhs: int) -> Inst`


### `pub fn ir_isub(lhs: int, rhs: int) -> Inst`


### `pub fn ir_imul(lhs: int, rhs: int) -> Inst`


### `pub fn ir_idiv(lhs: int, rhs: int) -> Inst`


### `pub fn ir_imod(lhs: int, rhs: int) -> Inst`


### `pub fn ir_iand(lhs: int, rhs: int) -> Inst`

Logical and/or: each operand is coerced to 0/1 (any nonzero → 1),
then bitwise AND/OR. Result is 0 or 1.

### `pub fn ir_ior(lhs: int, rhs: int) -> Inst`


### `pub fn ir_inot(value_id: int) -> Inst`

Logical NOT: 0 → 1, non-zero → 0.

### `pub fn ir_icmp_eq(lhs: int, rhs: int) -> Inst`

Comparison ops. Produce i64 with value 0 (false) or 1 (true).

### `pub fn ir_icmp_ne(lhs: int, rhs: int) -> Inst`


### `pub fn ir_icmp_lt(lhs: int, rhs: int) -> Inst`


### `pub fn ir_icmp_le(lhs: int, rhs: int) -> Inst`


### `pub fn ir_icmp_gt(lhs: int, rhs: int) -> Inst`


### `pub fn ir_icmp_ge(lhs: int, rhs: int) -> Inst`


### `pub fn ir_return(value_id: int) -> Inst`


### `pub fn ir_return_void() -> Inst`


### `pub fn ir_print_int(value_id: int) -> Inst`

Print an i64 value as decimal text + newline to stdout.
Produces a void value (the instruction has no SSA-id consumers).

### `pub fn ir_print_float(value_id: int) -> Inst`


### `pub fn ir_select(cond_id: int, then_id: int, else_id: int) -> Inst`

Select: result = if cond != 0 then then_id else else_id.
Branchless via cmov — works for any tree-shaped IR.

### `pub fn ir_fconst(literal: Text) -> Inst`

--- Floats (f64 / LLVM double) ---
Float constant. The literal TEXT is kept in `name`; emit converts it
to an exact hex bit-pattern via orion_f64_literal_hex at compile time
(decimal FP literals like 0.1 are rejected by LLVM unless exact).

### `pub fn ir_fbin(op_name: Text, lhs: int, rhs: int) -> Inst`

Float arithmetic: op_name is fadd/fsub/fmul/fdiv.

### `pub fn ir_fcmp(cc: Text, lhs: int, rhs: int) -> Inst`

Float comparison: cc is oeq/one/olt/ole/ogt/oge. Produces i64 0/1.

### `pub fn ir_sitofp(value_id: int) -> Inst`

int → float / float → int conversions.

### `pub fn ir_fptosi(value_id: int) -> Inst`


### `pub fn ir_call(fn_name: Text, arg_ids: [int], ret_type: Text) -> Inst`

--- Function calls ---
Call user-defined function `fn_name` with arg-value-ids.
ret_type lets later passes (binop type-detection, phi, etc.) see the
call's actual return type without needing a module lookup.

### `pub fn ir_print_str(text: Text) -> Inst`

Print a string literal followed by newline (uses libc puts).
name = the string text (raw, no escapes processed).

### `pub fn ir_const_str(text: Text) -> Inst`

String literal as a value — produces a text-typed SSA value (ptr to global).

### `pub fn ir_text_concat(left_id: int, right_id: int) -> Inst`

Concatenate two text SSA values — calls runtime helper.

### `pub fn ir_int_to_text(value_id: int) -> Inst`

Convert an i64 to text — calls runtime helper.

### `pub fn ir_text_cmp(op_name: Text, left_id: int, right_id: int) -> Inst`

Text equality / inequality / lexicographic compare via strcmp.
Result is i64 0/1.

### `pub fn ir_text_len(value_id: int) -> Inst`

Length of a text string (calls libc strlen).

### `pub fn ir_text_slice(text_id: int, lo_id: int, hi_id: int) -> Inst`

slice(text, lo, hi) — substring from byte index lo (inclusive) to hi (exclusive).
Three SSA inputs encoded as: value=text_id, lhs=lo_id, rhs=hi_id.

### `pub fn ir_list_slice(list_id: int, lo_id: int, hi_id: int, list_type: Text) -> Inst`

slice(list, lo, hi) — half-open, clamped; type_text carries the
source list type so element typing survives the slice.

### `pub fn ir_fmath1(libm: Text, arg_id: int) -> Inst`

Float math — name holds the libm symbol (sqrt/sin/.../log).

### `pub fn ir_fmath2(libm: Text, a_id: int, b_id: int) -> Inst`


### `pub fn ir_text_contains(text_id: int, sub_id: int) -> Inst`

contains(text, sub) — returns i64 1 if sub appears anywhere in text, else 0.

### `pub fn ir_file_read(path_id: int) -> Inst`

--- File I/O (libc fopen/fread/fwrite) ---

### `pub fn ir_file_write(path_id: int, content_id: int) -> Inst`


### `pub fn ir_argc() -> Inst`

CLI args. argc() → count, argv(i) → ith arg as Text.

### `pub fn ir_argv(idx_id: int) -> Inst`


### `pub fn ir_bytes_from_text(text_id: int) -> Inst`

bytes_from_text(t) → [int] of byte values

### `pub fn ir_bytes_to_text(list_id: int) -> Inst`

bytes_to_text(list) → Text from list of byte values

### `pub fn ir_bytes_slice(list_id: int, lo_id: int, hi_id: int) -> Inst`

bytes_slice(list, lo, hi) → new list with items [lo, hi)

### `pub fn ir_bytes_concat(a_id: int, b_id: int) -> Inst`

bytes_concat(a, b) → new list with items of a followed by items of b

### `pub fn ir_bytes_zeros(n_id: int) -> Inst`

bytes_zeros(n) → list of n zeros

### `pub fn ir_slot_get(key_id: int) -> Inst`

Global state slots — key→ptr Map. slot_get's caller decides type by usage.
In our orbs, slots store text values; ir_slot_get defaults to text type.

### `pub fn ir_slot_set(key_id: int, val_id: int) -> Inst`


### `pub fn ir_list_lit(item_ids: [int], elem_type: Text) -> Inst`

--- Lists (int-only for now) ---
A list is a ptr to a heap buffer laid out as [i64 length, i64 item0, ...].
LIMITATION: only int items work — text lists like ["a", "b"] fail at
compile because list_set takes i64, not ptr. Type-aware lists are a
future enhancement.

### `pub fn ir_list_at(list_id: int, index_id: int) -> Inst`


### `pub fn ir_list_len(list_id: int) -> Inst`


### `pub fn ir_list_push(list_id: int, val_id: int) -> Inst`

Push: copy all items + append val, return new list ptr.
Caller pattern: `xs = push(xs, val)`.

### `pub fn ir_list_push_mut(list_id: int, val_id: int) -> Inst`

In-place push — ONLY emitted for the self-rebind statement form
`x = push(x, v)`, where the old list value is dead after the
statement. Amortized O(1) vs list_push's O(n) copy. Callers holding
an alias to x across a self-rebind push observe the mutation — same
caveat as lodge-orion's Arc::get_mut fast path.

### `pub fn ir_vec_add(a_id: int, b_id: int) -> Inst`

SIMD-style elementwise vector ops. Returns a new int list (vec_add/sub/mul)
or i64 (vec_dot).

### `pub fn ir_vec_sub(a_id: int, b_id: int) -> Inst`


### `pub fn ir_vec_mul(a_id: int, b_id: int) -> Inst`


### `pub fn ir_vec_dot(a_id: int, b_id: int) -> Inst`


### `pub fn ir_time_now_ms() -> Inst`

Async runtime primitives.

### `pub fn ir_monotonic_ms() -> Inst`


### `pub fn ir_sleep_ms(ms_id: int) -> Inst`


### `pub fn ir_map_lit(pair_ids: [int], val_type: Text) -> Inst`

--- Maps (text key → i64 value) ---
A map is a ptr to a heap buffer laid out as
  [i64 length, i64 key0_ptr, i64 val0, i64 key1_ptr, i64 val1, ...]
Keys are text pointers stored as i64 (lossless on 64-bit).
args alternates: [key0_id, val0_id, key1_id, val1_id, ...].
`val_type` is the map's homogeneous value type (i64 / text / list:… / map).
It rides in type_text as `map:<val_type>` so get()/[] recover the value type
through mut slots, set-results and copies — a bare `map` lost it and made
`get` guess `text`, concatenating int values as pointers (a crash).

### `pub fn ir_map_get(map_id: int, key_id: int, value_type: Text) -> Inst`


### `pub fn ir_map_has(map_id: int, key_id: int) -> Inst`


### `pub fn ir_map_set_val(map_id: int, key_id: int, val_id: int, map_type: Text) -> Inst`

set(map, key, val) — mutates in place (indirect handle survives
growth) and re-yields the map so `m = set(m, k, v)` value-semantics
call sites keep working. Same aliasing caveat as list_push_mut.

### `pub fn ir_map_remove(map_id: int, key_id: int) -> Inst`


### `pub fn ir_list_set_val(list_id: int, idx_id: int, val_id: int, list_type: Text) -> Inst`

set(list, index, val) — in-place store, re-yields the list.

### `pub fn ir_slot_has(key_id: int) -> Inst`

slot_has(key) → 0/1; slot_get_int(key) → raw i64 (0 when unset).
The typed pair that replaces interp-only `type_of(slot_get(k))`
probing — works identically native and interpreted.

### `pub fn ir_slot_get_int(key_id: int) -> Inst`


### `pub fn ir_map_len(map_id: int) -> Inst`


### `pub fn ir_map_keys(map_id: int) -> Inst`


### `pub fn ir_map_values(map_id: int) -> Inst`


### `pub fn ir_map_get_or(map_id: int, key_id: int, dflt_id: int, value_type: Text) -> Inst`

get_or(map, key, default) — result typed after the default value.

### `pub fn ir_f64_to_text(value_id: int) -> Inst`

f64 → Text ("%g") for interpolation and to_text.

### `pub fn ir_struct_cons(struct_name: Text, n_fields: int, value_ids: [int]) -> Inst`

--- Structs (data decls) ---
A struct value is a ptr to a heap buffer of i64 slots, one per field.
type_text encodes the struct name as "struct:Player".
Field args carry the SSA value ids in declared field order.

### `pub fn ir_field_load(struct_id: int, field_index: int, field_type: Text) -> Inst`

Load a field from a struct by index. field_type tells emit what type to load.

### `pub fn ir_print_text(value_id: int) -> Inst`

Print a dynamically-computed text value (calls puts on the ptr).

### `pub fn ir_alloca(stored_type: Text) -> Inst`

--- Memory ops (for mutable variables and loop counters) ---
alloca produces a slot for `stored_type` ("i64" or "text").
type_text records the STORED type; the SSA result itself is always ptr.

### `pub fn ir_load(ptr_id: int, loaded_type: Text) -> Inst`

Load value of `loaded_type` from ptr SSA id.

### `pub fn ir_store(ptr_id: int, value_id: int) -> Inst`

Store value_id to ptr_id. Void. The stored type is inferred from value's type.

### `pub fn ir_label(label_name: Text) -> Inst`

--- Basic blocks (labels + branches + phi) ---
These let us emit real if/else with side-effects (recursion, calls)
and future loops. Label names are strings — we encode them in `name`.
Mark a basic-block boundary. name = "label_name".

### `pub fn ir_br(target_label: Text) -> Inst`

Unconditional jump to label. name = "target".

### `pub fn ir_br_if(cond_id: int, then_label: Text, else_label: Text) -> Inst`

Conditional jump. value = cond ssa-id (i64 0/1).
name = "then_label|else_label" (pipe-separated).

### `pub fn ir_phi(then_val_id: int, then_label: Text, else_val_id: int, else_label: Text, phi_type: Text) -> Inst`

Phi node merging two predecessors.
lhs = then-value-id, rhs = else-value-id.
name = "then_label|else_label" (pipe-separated).
type_text is set at emit time from the operand types.

### `pub fn ir_param(param_index: int, param_type: Text) -> Inst`

Reference a function parameter by index (0-based). type_text matches
the param's declared type ("i64" or "text").

### `pub fn ir_fn_new(name: Text, return_type: Text) -> IRFn`

--- Function builders ---

### `pub fn ir_fn_add_param(fn_value: IRFn, param_name: Text, param_type: Text) -> IRFn`


### `pub fn ir_fn_push(fn_value: IRFn, inst: Inst) -> PushResult`


### `pub fn ir_fn_set_inst(fn_value: IRFn, idx: int, inst: Inst) -> IRFn`

Overwrite the instruction at `idx` — used to back-patch an alloca's element
type once inference resolves an empty list (`mut x = []` then `push`). Same
in-place caveat as ir_fn_push: the caller drops the old IRFn.

### `pub fn ir_module_new() -> IRModule`

--- Module builders ---

### `pub fn ir_module_add_fn(module: IRModule, fn_value: IRFn) -> IRModule`


### `pub fn ir_dump_value_ref(value_id: int) -> Text`

--- Text dumper (Cranelift CLIF-style) ---

### `pub fn ir_dump_instruction(inst: Inst, my_id: int) -> Text`


### `pub fn ir_perform_int(handler_name: Text, arg_id: int) -> Inst`

Effects: perform with one-shot continuation via setjmp/longjmp.
`perform Effect.op(arg)` lowers to this. emit_llvm wraps the call in
setjmp dance so the handler can `resume_int(value)` to come back.
For now: single i64 arg, i64 return. Generalize later.

### `pub fn ir_perform_text(handler_name: Text, arg_id: int) -> Inst`


### `pub fn ir_fn_ref(fn_name: Text) -> Inst`

First-class fn reference — produces a ptr-typed SSA value holding
the address of the named global fn. Used for higher-order fns.

### `pub fn ir_indirect_call(callee_id: int, arg_ids: [int], ret_type: Text) -> Inst`

Indirect call through a fn-ptr value (not a global fn name).
callee_id is the SSA value holding the ptr; ret_type is what the
fn returns. For now we restrict to all-i64 args / i64 or text ret.

### `pub fn ir_make_closure(fn_name: Text, cap_ids: [int], is_lambda: int) -> Inst`

Closure value = a list [fn_ptr_as_int, is_lambda_flag, cap0, cap1, ...].
`is_lambda` (lhs) is 1 for a lambda (its fn takes the closure as a leading
`env` arg and reads captures out of it), 0 for a plain fn-ref (called with
no env). `name` is the target fn; `args` are the captured SSA value ids.

### `pub fn ir_closure_call(closure_id: int, arg_ids: [int], ret_type: Text) -> Inst`

Call a closure value: load its fn-ptr, and dispatch on the is_lambda flag —
a lambda is invoked as fn(env, args...), a plain fn-ref as fn(args...).

### `pub fn ir_int_to_ptr(src_id: int, type_text: Text) -> Inst`

Reinterpret an i64 (a ptr stored as int — e.g. a text/list/map closure
capture read back from the env) as a typed ptr value. type_text carries
the intended type ("text" / "list:i64" / "map") so downstream ops see it.

### `pub fn ir_dump_fn(fn_value: IRFn) -> Text`


### `pub fn ir_dump_module(module: IRModule) -> Text`


