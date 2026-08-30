#!/usr/bin/env bash
# orb_console_test.sh - a library orb may not print.
#
#   bash tools/orb_console_test.sh
#
# WHY, measured: `print_line` had 347 call sites and `log` had none. The
# shorter thing wins, every time, and the shorter thing is the one with no
# level, no channel and no way to be turned off. A convention loses that race;
# the only fix is that the wrong one is not there to reach for.
#
# So in a LIBRARY orb there is exactly one way to say something, and it is
# `log`. In a program - a tool, a test, a shell - `print_line` is right, and
# the `always` channel exists for output that must never be hushed.
#
# The list below is not "things we allow"; it is the set of orbs that ARE
# program code, plus the logger itself. Each one says why. An orb that prints
# and is not here is the gate's whole purpose.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

allowed() {
    case "$1" in
        log)        echo "it is the logger; something has to write the line" ;;
        app)        echo "the application shell - a program's own scaffolding" ;;
        assert)     echo "a failed assertion IS the test's answer" ;;
        orion_*)    echo "the compiler is a program, not a library" ;;
        *)          echo "" ;;
    esac
}

fail=0
for dir in "$ROOT"/orbs/*/; do
    orb="$(basename "$dir")"
    [ -f "$dir/lib.or" ] || continue
    # Comment lines do not print - `option` and `result` only mention
    # print_line in doc examples, and counting those would make the list lie.
    n="$(grep -vE '^[[:space:]]*#' "$dir/lib.or" | grep -c 'print_line(\|print_raw(' || true)"
    [ "$n" -eq 0 ] && continue
    why="$(allowed "$orb")"
    if [ -n "$why" ]; then
        printf '  console ..  %-18s %s call(s) - %s\n' "$orb" "$n" "$why"
    else
        printf '  console: FAIL - %s prints %s time(s) and is a library.\n' "$orb" "$n"
        printf '           Use `log`: const c = channel("%s"), then info(c, ...).\n' "$orb"
        printf '           If it is program code, say so in tools/orb_console_test.sh.\n'
        fail=1
    fi
done

[ "$fail" -eq 0 ] || exit 1
echo "  console ok  no library orb prints"
