#!/usr/bin/env bash
# combo_test.sh — compile every PAIR of language features in one program.
#
# Why pairs: the suite tests features one at a time, and that is exactly how a
# real bug survived it. Generic call-site instantiation had a passing test, and
# it was broken by the presence of ANY closure elsewhere in the file — because
# the lambda pass rebuilt every declaration and dropped the field the generics
# depended on. Each feature worked. The pair did not, and nothing looked at
# pairs.
#
# Each feature below contributes a known integer. A generated program is
# feature A's declarations + feature B's, and a main that sums their
# contributions; the expected total is the sum of the two values, so a wrong
# ANSWER fails as loudly as a compile error.
#
#   bash tools/combo_test.sh          # all pairs
#   bash tools/combo_test.sh iter     # only pairs involving a feature
#
# Exit code is the number of failing combinations.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORION="$ROOT/dist/orion.exe"
CLANG="${CLANG:-C:/Program Files/LLVM/bin/clang.exe}"
[ -x "$CLANG" ] || CLANG="$(command -v clang || echo clang)"
RT="$ROOT/runtime/orion_rt.c"
FILTER="${1:-}"
[ -x "$ORION" ] || { echo "no dist/orion.exe — bash tools/bootstrap.sh"; exit 1; }

WORK="$ROOT/dist/.combo"
rm -rf "$WORK"; mkdir -p "$WORK"

# ---- the features -----------------------------------------------------
# feat <name> <uses> <value> <<'ORION' … declarations … ORION
# then the contribution expression on the CONTRIB line.
FEATURES=""
feat() {
    local name="$1" uses="$2" value="$3" contrib="$4"
    printf '%s\n' "$uses" > "$WORK/$name.uses"
    printf '%s\n' "$value" > "$WORK/$name.value"
    printf '%s\n' "$contrib" > "$WORK/$name.contrib"
    cat > "$WORK/$name.decls"
    FEATURES="$FEATURES $name"
}

feat closure "" 15 "cmb_apply(cmb_adder(), 5)" <<'ORION'
define cmb_apply(f: fn, x: int) -> int:
    f(x)

define cmb_adder() -> fn:
    k = 10
    fn(n): n + k
ORION

feat generic "iter" 4 "len(at(keep(cmb_words(), cmb_is_long), 0))" <<'ORION'
define cmb_words() -> [text]:
    ["aa", "bbbb", "cc"]

define cmb_is_long(s: text) -> truth:
    len(s) > 3
ORION

feat iflet "" 10 "cmb_iflet(CmbOpt.Some(4))" <<'ORION'
type CmbOpt: Some(int), None

define cmb_iflet(o: CmbOpt) -> int:
    edit score = 0
    if let Some(v) = o:
        if v == 4:
            score = score + 10
    score
ORION

feat defer_ "" 3 "cmb_defer()" <<'ORION'
define cmb_note(n: int) -> int:
    prev = if slot_has("cmb:trace") then slot_get_int("cmb:trace") else 0
    slot_set("cmb:trace", prev * 10 + n)
    n

define cmb_defer() -> int:
    defer cmb_note(1)
    cmb_note(3)
ORION

feat effect_ "" 7 "perform CmbAsk.n(7)" <<'ORION'
effect CmbAsk:
    n: fn(x: int) -> int

handle CmbAsk.n(x: int) -> int:
    resume(x)
ORION

feat task "async" 12 "await(spawn(cmb_worker, 4))" <<'ORION'
define cmb_worker(n: int) -> int:
    edit total = 0
    loop i in 0..<n:
        total = total + i
        yield_now()
    total + 6
ORION

feat mapt "" 5 "len(get(cmb_map(), \"greeting\"))" <<'ORION'
define cmb_map() -> table<text>:
    {"greeting": "hello"}
ORION

feat bitwise "" 8 "12 & 10" <<'ORION'
ORION

feat tuple "" 7 "cmb_tuple()" <<'ORION'
define cmb_tuple() -> int:
    pair = (7, "seven")
    a, b = pair
    if len(b) == 5 then a else 0
ORION

feat spread "" 9 "cmb_spread()" <<'ORION'
type CmbPoint: x: int, y: int

define cmb_spread() -> int:
    p = CmbPoint{x: 1, y: 2}
    q = CmbPoint{..p, x: 9}
    if q.y == 2 then q.x else 0
ORION

feat guard "" 3 "cmb_guard(500)" <<'ORION'
define cmb_guard(x: int) -> int:
    choose x:
        n if n > 100 -> 3
        n if n > 10 -> 2
        _ -> 1
ORION

feat interp "" 5 "len(cmb_interp())" <<'ORION'
define cmb_interp() -> text:
    a = 1
    b = 2
    "sum={a + b}"
ORION

# ---- generate + run every pair ----------------------------------------

pass=0; fail=0
for a in $FEATURES; do
    for b in $FEATURES; do
        [ "$a" \< "$b" ] || continue
        case "$FILTER" in
            "") ;;
            *) case "$a$b" in *"$FILTER"*) ;; *) continue ;; esac ;;
        esac
        name="${a}__${b}"
        src="$WORK/$name.or"
        want=$(( $(cat "$WORK/$a.value") + $(cat "$WORK/$b.value") ))
        {
            for u in $(cat "$WORK/$a.uses") $(cat "$WORK/$b.uses"); do echo "use $u"; done | sort -u
            echo ""
            cat "$WORK/$a.decls"
            echo ""
            cat "$WORK/$b.decls"
            echo ""
            echo "define main() -> int:"
            echo "    x = $(cat "$WORK/$a.contrib")"
            echo "    y = $(cat "$WORK/$b.contrib")"
            echo "    x + y"
        } > "$src"

        if ! timeout 60 "$ORION" "$src" "$WORK/$name.ll" "$ROOT/orbs" > "$WORK/$name.log" 2>&1; then
            printf "  %-24s COMPILE FAILED: %s\n" "$name" "$(grep -m1 -iE 'error|list index' "$WORK/$name.log" | cut -c1-90)"
            fail=$((fail + 1)); continue
        fi
        if ! "$CLANG" "$WORK/$name.ll" "$RT" -o "$WORK/$name.exe" >> "$WORK/$name.log" 2>&1; then
            printf "  %-24s LINK FAILED\n" "$name"
            fail=$((fail + 1)); continue
        fi
        "$WORK/$name.exe" > /dev/null 2>&1
        got=$?
        if [ "$got" = "$want" ]; then
            pass=$((pass + 1))
        else
            printf "  %-24s WRONG ANSWER: expected %s, got %s\n" "$name" "$want" "$got"
            fail=$((fail + 1))
        fi
    done
done

rm -rf "$WORK"
echo
if [ "$fail" = "0" ]; then
    echo "  combos: all $pass pairs ok"
else
    echo "  combos: $fail of $((pass + fail)) FAILED"
fi
exit "$fail"
