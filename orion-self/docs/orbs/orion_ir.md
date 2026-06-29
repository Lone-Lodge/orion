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

### `pub fn ir_select(cond_id: int, then_id: int, else_id: int) -> Inst`

Select: result = if cond != 0 then then_id else else_id.
Branchless via cmov — works for any tree-shaped IR.

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

### `pub fn ir_map_lit(pair_ids: [int]) -> Inst`

--- Maps (text key → i64 value) ---
A map is a ptr to a heap buffer laid out as
  [i64 length, i64 key0_ptr, i64 val0, i64 key1_ptr, i64 val1, ...]
Keys are text pointers stored as i64 (lossless on 64-bit).
args alternates: [key0_id, val0_id, key1_id, val1_id, ...].

### `pub fn ir_map_get(map_id: int, key_id: int, value_type: Text) -> Inst`


### `pub fn ir_map_has(map_id: int, key_id: int) -> Inst`


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


### `pub fn ir_module_new() -> IRModule`

--- Module builders ---

### `pub fn ir_module_add_fn(module: IRModule, fn_value: IRFn) -> IRModule`


### `pub fn ir_dump_value_ref(value_id: int) -> Text`

--- Text dumper (Cranelift CLIF-style) ---

### `pub fn ir_dump_instruction(inst: Inst, my_id: int) -> Text`


### `pub fn ir_dump_fn(fn_value: IRFn) -> Text`


### `pub fn ir_dump_module(module: IRModule) -> Text`


