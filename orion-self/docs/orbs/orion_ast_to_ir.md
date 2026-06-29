# orb `orion_ast_to_ir`


## Public functions

### `pub fn get_int(m: Map, k: Text) -> int: get(m, k)`

Typed map-get aliases — orion-self dispatches their callers to typed
runtime helpers, but lodge-orion needs an actual definition to interpret.

### `pub fn get_map(m: Map, k: Text) -> Map: get(m, k)`


### `pub fn get_list(m: Map, k: Text) -> [Map]: get(m, k)`


### `pub fn ast_expr_to_ir(fn_value: IRFn, scope: Scope, node: Map) -> ConvResult`


### `pub fn ast_fn_to_ir(ast_fn: Map, initial_scope: Scope) -> IRFn`


### `pub fn ast_program_to_ir(program: Map) -> IRModule`


