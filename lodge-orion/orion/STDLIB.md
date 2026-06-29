# Orion Standard Library — orb-index

> Alla orbs i `lodge-orion/orbs/`. Importera med `use <orbnamn>`.

Varje rad: `fn-namn(params) -> returtyp` — en blicks-koll på vad orben kan.

---

## Kärnan — alltid tillgängligt

Dessa builtins är **inbyggda** — ingen `use`-deklaration behövs.

```orion
# I/O
print_line(text)          # stdout + newline
print(text)               # stdout
eprint(text)              # stderr

# Listor
len(list)                 # length
at(list, index)           # element
push(list, value)         # append (returns new list)

# Maps
get(map, key)             # value or null
has(map, key)             # bool
set(map, key, value)      # mutate

# Bytes / Text
bytes_from_text(text)
bytes_to_text(bytes)
bytes_length(bytes)
byte_at(bytes, index)
bytes_slice(bytes, start, end)
bytes_concat(a, b)
bytes_zeros(count)

# Text
text_concat(a, b)         # alt: a + b
fmt_int(value)
str_to_int(text)
to_text(value)            # polymorph: text passerar, tal fmt:as

# Filsystem (native binär — utan `use`)
read_file_native(path)
write_file_native(path, bytes)
file_size_native(path)

# Tillstånd (slot map)
slot_get(key)
slot_set(key, value)
slot_push(key, value)     # push till lista-i-slot

# Typ-introspektion
type_of(value)            # "Int" | "Text" | "List" | "Map" | ...
```

---

## Standard-orbs

### `base64` — base64 encoding
```orion
base64_encode(text) -> Text
base64_decode(text) -> Text
```

### `bytes` — byte-manipulation
```orion
bytes_from_text(text) -> [int]
bytes_to_text(byte_list) -> Text
bytes_length(byte_list) -> int
byte_at(byte_list, index) -> int
read_f32_le(byte_list, offset) -> f64
read_u32_le(byte_list, offset) -> int
```

### `collections` — list helpers
```orion
list_reverse(items) -> [f64]
list_concat(first, second) -> [f64]
list_take(items, count) -> [f64]
list_skip(items, count) -> [f64]
list_index_of(items, needle) -> int
```

### `color` — färghantering
```orion
hex_to_rgba(hex) -> [int]
rgba_to_hex(rgba) -> Text
```

### `compress` — RLE komprimering
```orion
rle_encode(bytes) -> [int]
rle_decode(bytes) -> [int]
```

### `crypto` — hashing
```orion
sha256(text) -> Text
sha256_short(text) -> Text
```

### `csv` — comma-separated values
```orion
csv_parse(text) -> [[Text]]
csv_serialize(rows) -> Text
```

### `easing` — animations-easing
```orion
ease_linear(t) -> f64
ease_in_quad(t) -> f64
ease_out_quad(t) -> f64
ease_in_out_quad(t) -> f64
ease_in_cubic(t) -> f64
ease_out_cubic(t) -> f64
ease_in_out_cubic(t) -> f64
ease_bounce(t) -> f64
ease_elastic(t) -> f64
```

### `env` — miljövariabler
```orion
env_get(name) -> Text
env_set(name, value)
```

### `format` — formatering
```orion
fmt_float(value, precision) -> Text
fmt_hex(value) -> Text
fmt_hex_pad(value, width) -> Text
fmt_oct(value) -> Text
fmt_bin(value) -> Text
fmt_pad_left(text, width, pad_char) -> Text
fmt_pad_right(text, width, pad_char) -> Text
```

### `fs` — filsystem
```orion
read_file(path) -> Text
write_file(path, content)
mkdir_all(path)
file_exists(path) -> bool
list_dir(path) -> [Text]
current_dir() -> Text
```

### `hash` — hashing (icke-kryptografiskt)
```orion
hash_text(text) -> int
hash_int(value) -> int
hash_combine(left, right) -> int
hash_two(left, right) -> int
```

### `hex` — hex encoding
```orion
hex_encode(bytes) -> Text
hex_decode(text) -> [int]
```

### `io` — I/O utöver print
```orion
read_line() -> Text          # stdin
read_all() -> Text           # all stdin
```

### `json` — JSON parse/stringify
```orion
json_parse(text)             # → Map/List/Text/int
json_stringify(value) -> Text
```

### `log` — loggning
```orion
set_log_level(level)
log_error(message)
log_warn(message)
log_info(message)
log_debug(message)
```

### `math` — vektor- och matris-matte
```orion
v2(x, y) -> Vec2
v2_add(a, b) -> Vec2
v2_sub(a, b) -> Vec2
v2_scale(a, s) -> Vec2
v2_dot(a, b) -> f64
v2_length(a) -> f64
v2_normalize(a) -> Vec2

v3(x, y, z) -> Vec3
v3_add/sub/scale/dot/cross/length/normalize

quat(x, y, z, w) -> Quat
quat_mul(a, b) -> Quat
quat_normalize(q) -> Quat

mat4_identity() -> Mat4
mat4_translate/rotate/scale/multiply
```

### `noise` — perlin/value noise
```orion
noise_hash(x, y, seed) -> f64
value_noise_1d(x, seed) -> f64
value_noise_2d(x, y, seed) -> f64
fbm_2d(x, y, octaves, seed) -> f64
```

### `path` — path-manipulation
```orion
path_join(parts) -> Text
path_basename(path) -> Text
path_dirname(path) -> Text
path_extension(path) -> Text
path_change_extension(path, new_ext) -> Text
```

### `process` — child processes
```orion
process_run(command, args) -> int
process_capture(command, args) -> Text
```

### `random` — slumptal
```orion
seed(seed_value)
random_int(lower, upper) -> int
random_float() -> f64
random_range(lower, upper) -> f64
random_bool() -> bool
random_choice(items) -> any
```

### `regex` — regex matching
```orion
match_glob(subject, pattern) -> bool       # * och ?
match_regex(subject, pattern) -> bool
regex_find(subject, pattern) -> Text
```

### `stats` — statistik
```orion
mean(values) -> f64
median(values) -> f64
stddev(values) -> f64
variance(values) -> f64
```

### `string` — text-manipulation
```orion
str_upper(text) -> Text
str_lower(text) -> Text
str_starts_with(text, prefix) -> bool
str_ends_with(text, suffix) -> bool
str_contains(text, needle) -> bool
str_split(text, sep) -> [Text]
str_replace(text, from, to) -> Text
str_trim(text) -> Text
```

### `sysinfo` — systeminfo
```orion
os_name() -> Text
cpu_count() -> int
mem_total() -> int
```

### `test` — testing helpers
```orion
assert(condition, message)
assert_eq(a, b)
```

### `time` — tid
```orion
now() -> f64                  # epoch seconds
elapsed(start) -> f64
sleep(seconds)
```

### `time_format` — tidsformatering
```orion
fmt_time(epoch_seconds) -> Text   # "YYYY-MM-DD HH:MM:SS"
fmt_duration(seconds) -> Text     # "1h 23m 45s"
```

### `url` — URL encoding
```orion
url_encode(text) -> Text
url_decode(text) -> Text
url_parse(text)                  # → Map med scheme/host/path/query
```

### `uuid` — UUIDs
```orion
uuid_v4() -> Text                # "xxxxxxxx-xxxx-..."
uuid_v4_compact() -> Text        # utan bindestreck
```

### `xml` — XML parse/serialize
```orion
xml_parse(text)                  # → tree
xml_serialize(tree) -> Text
```

---

## Compiler-orbs (för att bygga själv)

> Bara behövs om du skriver ny native code eller egna verktyg.

### `orion_lex` — Orion-lexer
```orion
self_lex(source) -> [Token]
```

### `orion_parse` — Orion-parser
```orion
self_parse(tokens) -> AST
```

### `orion_emit_x64` — x86-64 codegen
```orion
x64_compile_program(source) -> CompileResult
```

### `orion_emit_pe` / `orion_emit_pe_imports` — PE-wrappers
```orion
pe_build_with_full_compile(compile_result) -> [int]
pei_build_large(compile_result) -> [int]
```

### `orion_native` — högnivå-API för native build
```orion
compile_to_exe(source, output_path)        # 5.6KB PE
compile_to_exe_large(source, output_path)  # 282KB PE (för stora program)
```

---

## Hur du hittar mer

- `lodge-orion/orbs/<orbnamn>/lib.or` — full källkod
- `lodge-orion/orbs/<orbnamn>/LEARN.md` — om orben har en guide
- `orbit docs <orbnamn>` — kommandot för att titta in i en orb

Är något odokumenterat? Det är en bugg — öppna en issue.
