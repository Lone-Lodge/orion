# orb `os`

os — CLI / OS primitives for self-hosted tools (orbit), under the names
orbit already uses. Splits into three sources:
  - C externs (orion_cli.c): sys_run, fs ops, exit, eprint.
  - orion-self builtins re-exposed: read_file=file_read, arg=argv, ...
  - run_command(cmd, [args]) joins to one line and calls sys_run.

With this orb, orbit_main.or compiles under orion-self with zero changes
to its call sites — the last piece before a native, lodge-orion-free orbit.

## Public functions

### `pub fn elapsed(start: int) -> int = now() - start`

Milliseconds between now() and an earlier now() — timing metric.

### `pub fn read_file(p: Text) -> Text = file_read(p)`

orion-self builtins under orbit's names (file_read/argv/argc live in the
compiler, not an orb — callable directly).

### `pub fn arg(i: int) -> Text = argv(i)`


### `pub fn arg_count() -> int = argc()`


### `pub fn write_file(p: Text, c: Text) -> int`


### `pub fn os_kind() -> int = host_os()`

Public wrapper so other orbs can branch on the host without re-declaring the
extern (a second `declare` in the bundle is an LLVM redefinition error).
0 = Windows, 1 = Linux, 2 = macOS.

### `pub fn run_command(cmd: Text, args: [Text]) -> int = sys_run(os_join(os_quote(win_path(cmd)), args, 0))`


### `pub fn capture_stdout(cmd: Text, args: [Text]) -> Text = capture(os_join(os_quote(cmd), args, 0))`


### `pub fn str_starts_with(t: Text, p: Text) -> bool`

---- string helpers (orion-self has no shared str lib; roll them over
bytes, matching the driver's idioms) ----

### `pub fn str_ends_with(t: Text, p: Text) -> bool`


### `pub fn str_contains(t: Text, sub: Text) -> bool`


### `pub fn str_trim(t: Text) -> Text`


### `pub fn str_split(t: Text, sep: Text) -> [Text]`


### `pub fn str_join(parts: [Text], sep: Text) -> Text`


### `pub fn str_replace(t: Text, pat: Text, rep: Text) -> Text = str_join(str_split(t, pat), rep)`


### `pub fn path_join(a: Text, b: Text) -> Text = "{a}/{b}"`

---- paths ----

### `pub fn path_parent(p: Text) -> Text`


### `pub fn list_dir(dir: Text) -> [Text] = str_split(orion_dir_list(dir), "\n")`


