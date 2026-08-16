#!/usr/bin/env bash
# setup_test.sh - the setup-exe seam, end to end, without a window. Proves:
# stitch_setup sews stub+zip+manifest+html into one exe; that exe reads its
# own manifest and ui page back and unpacks its zip byte-for-byte; a bare
# (unstitched) exe knows it is bare; and the per-user registry trio writes,
# survives a reg query, and removes cleanly. What this cannot prove headless
# - the window itself - the stitched folio setup exe proves by hand.
#
#   bash tools/setup_test.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORBIT="$ROOT/dist/orbit.exe"
[ -x "$ORBIT" ] || { echo "build orbit first: bash tools/build_orbit.sh"; exit 1; }
WORK="$ROOT/dist/.setuptest"
rm -rf "$WORK"; mkdir -p "$WORK/payload/demo"
fail() { echo "setup_test: FAIL - $1"; exit 1; }

cat > "$WORK/probe.or" <<'EOF'
use os
use text
define main() -> int:
    mode = if arg_count() > 1 then arg(1) else ""
    if mode is "stitch":
        stitch_setup(arg(2), arg(3), replace(arg(4), ";", "\n"), arg(5), arg(6))
    else if mode is "reg":
        a = registry_write_text("Software\\orion-setup-test", "Name", "åäö-test")
        b = registry_write_number("Software\\orion-setup-test", "Size", 42)
        a + b
    else if mode is "unreg":
        registry_remove("Software\\orion-setup-test")
    else:
        m = setup_manifest()
        if m is "":
            print_line("bare")
            return 0
        print_line(m)
        print_line("PAGE " + setup_page())
        print_line("unpack {unpack_setup(arg(2))}")
        0
EOF

echo "hello from the payload" > "$WORK/payload/demo/hello.txt"
printf '<html>UI_MARK' > "$WORK/ui.html"
cd "$WORK"
"C:/Windows/System32/tar.exe" -a -c -f pay.zip -C payload demo || fail "no zip"

# bare: the probe carries nothing and must say so
"$ORBIT" build probe.or >/dev/null 2>&1 || fail "probe build errored"
[ -x probe.exe ] || fail "no probe.exe"
[ "$(./probe.exe)" = "bare" ] || fail "a bare exe did not answer bare"

# stitched: the probe sews a payload onto a COPY of itself, then reads it back
cp probe.exe base.exe
./probe.exe stitch base.exe pay.zip "name=demo;version=1.2.3;publisher=Prov AB;exe=demo.exe" ui.html sewn.exe
[ -s sewn.exe ] || fail "stitch wrote nothing"
OUT="$(./sewn.exe read out.zip)"
echo "$OUT" | grep -q "^name=demo$"        || fail "manifest name did not come back"
echo "$OUT" | grep -q "^publisher=Prov AB$" || fail "manifest publisher did not come back"
echo "$OUT" | grep -q "PAGE <html>UI_MARK" || fail "ui page did not come back"
echo "$OUT" | grep -q "unpack 0"           || fail "unpack answered non-zero"
"C:/Windows/System32/tar.exe" -x -f out.zip -C . || fail "unpacked zip does not extract"
[ "$(cat demo/hello.txt)" = "hello from the payload" ] || fail "payload bytes changed in transit"

# the registry trio: write, see it from outside, remove, see it gone.
# (reg query re-encodes output to the console's OEM codepage, so the åäö
# assertion goes through PowerShell told to answer in UTF-8.)
./probe.exe reg; [ "$?" = "0" ] || fail "registry write errored"
NAME="$(powershell -NoProfile -Command "[Console]::OutputEncoding=[Text.Encoding]::UTF8; (Get-ItemProperty 'HKCU:\Software\orion-setup-test').Name")"
[ "$(printf %s "$NAME" | tr -d '\r')" = "åäö-test" ] || fail "registry value not visible from outside (got: $NAME)"
./probe.exe unreg; [ "$?" = "0" ] || fail "registry remove errored"
reg query 'HKCU\Software\orion-setup-test' >/dev/null 2>&1 && fail "registry key survived remove"

echo "  setup seam: stitch/read-back/unpack byte-true, registry write+remove hold"
