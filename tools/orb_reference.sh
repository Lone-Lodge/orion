#!/usr/bin/env bash
# orb_reference.sh - generate docs/reference.html from the orbs.
#
# WHY: the Field Guide names the libraries but shows no signatures. A reader
# who wants to build something has to read the source to learn what `net` or
# `json` exports. This turns every `pub fn` and type in orbs/ into one
# reference page, generated from the code itself, so it can never drift the
# way hand-written API docs do. docs_check.sh regenerates it and fails if the
# committed page is stale, the same promise the guide's samples get.
#
#   bash tools/orb_reference.sh            # writes docs/reference.html
#   bash tools/orb_reference.sh --stdout   # prints to stdout (for the check)
#
# The compiler orbs (orion_*) are the self-hosted compiler, not a library a
# program uses, so they are left out.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/reference.html"
MODE="file"
[ "${1:-}" = "--stdout" ] && MODE="stdout"

# User-facing orbs, curated order first so `text` is not buried under `assert`.
# Any non-orion_ orb not listed here is appended alphabetically, so a new orb
# still shows up without editing this file.
PREFERRED="text list num iter dict json sqlite time http net os file async rand encoding store watch timer result option assert log ori_display ori_geometry"

all=""
for d in "$ROOT"/orbs/*/; do
    n="$(basename "$d")"
    case "$n" in orion_*) continue;; esac
    [ -f "$d/lib.or" ] || continue
    all="$all $n"
done

ordered=""
for p in $PREFERRED; do
    case " $all " in *" $p "*) ordered="$ordered $p";; esac
done
for n in $all; do
    case " $ordered " in *" $n "*) ;; *) ordered="$ordered $n";; esac
done

# The four escapes and the `backtick`->code conversion, shared by every pass.
AWK_LIB='
    function esc(s){ gsub(/&/,"\\&amp;",s); gsub(/</,"\\&lt;",s); gsub(/>/,"\\&gt;",s); return s }
    function firstsentence(s){ if (match(s, /\. /)) return substr(s, 1, RSTART); return s }
    function codetags(s,  pre, mid, post){
        while (match(s, /`[^`]*`/)) {
            pre = substr(s, 1, RSTART - 1)
            mid = substr(s, RSTART + 1, RLENGTH - 2)
            post = substr(s, RSTART + RLENGTH)
            s = pre "<code>" mid "</code>" post
        }
        return s
    }
'

# The orb's one-line summary: first sentence of its file-header comment, with
# the leading "name - " stripped off.
blurb() {
    awk -v name="$1" "$AWK_LIB"'
        function stripname(s){ sub("^" name " ", "", s); sub(/^[ ]*[^A-Za-z0-9(]+[ ]*/, "", s); return s }
        /^[ \t]*#/ { l = $0; sub(/^[ \t]*#[ ]?/, "", l); if (!incmt) { allcmt = l; incmt = 1 } else { allcmt = allcmt " " l } next }
        { if (allcmt != "") print codetags(esc(stripname(firstsentence(allcmt)))); exit }
    ' "$ROOT/orbs/$1/lib.or"
}

# Every exported type: one-line records printed whole, multi-line sum types
# rendered as `Name = Variant(..) | Variant(..)`. A pending block is flushed
# when the next type, the first function, or any un-indented line arrives.
types() {
    awk "$AWK_LIB"'
        function emit(shape){ printf "<div class=\"fn\"><code class=\"sig\">%s</code></div>\n", shape }
        function flush(){ if (intype) { emit(esc(curname) " = " variants); intype = 0 } }
        /^(pub |public )?type / {
            flush()
            line = $0; sub(/^(pub |public )?type /, "", line)
            nm = line; sub(/[: ].*/, "", nm)
            # Strip the name AND any <T> params, so a generic sum type
            # (`type Result<T>:`) is recognised as multi-line, not printed raw.
            rest = line; sub(/^[A-Za-z0-9_]+/, "", rest); sub(/^<[^>]*>/, "", rest); sub(/^:[ ]*/, "", rest)
            if (rest != "") { emit(esc(line)) } else { curname = nm; variants = ""; intype = 1 }
            next
        }
        /^pub fn / { flush(); next }
        /^public define / { flush(); next }
        intype && /^[ \t]*#/ { next }
        intype && /^[ \t]+[A-Za-z0-9_(]/ { v = $0; sub(/^[ \t]+/, "", v); variants = (variants == "") ? esc(v) : variants " | " esc(v); next }
        /^[^ \t]/ { flush() }
        END { flush() }
    ' "$ROOT/orbs/$1/lib.or"
}

# Every exported function: signature, the WHOLE comment above it (the code
# comment IS the documentation - there is no second prose to drift), and its
# `example` lines as proven usage: the build runs every one of them, so what
# this page shows can never lie.
funcs() {
    awk "$AWK_LIB"'
        function flush() {
            if (sig == "") return
            printf "<div class=\"fn\"><code class=\"sig\">%s</code>", esc(sig)
            if (doc != "" && doc !~ /^no example:/) printf "<p>%s</p>", codetags(esc(doc))
            if (exs != "") printf "<pre class=\"ex\">%s</pre>", exs
            print "</div>"
            sig = ""
        }
        /^[ \t]*#/ { l = $0; sub(/^[ \t]*#[ ]?/, "", l); if (!incmt) { allcmt = l; incmt = 1 } else { allcmt = allcmt " " l } next }
        /^pub fn |^public define / {
            flush()
            s = $0; sub(/^pub fn /, "", s); sub(/^public define /, "", s); sub(/:[ \t]*$/, "", s)
            sig = s; doc = allcmt; exs = ""
            allcmt = ""; incmt = 0; next
        }
        /^[ \t]+example / { l = $0; sub(/^[ \t]+/, "", l); exs = (exs == "") ? esc(l) : exs "\n" esc(l); next }
        /^[ \t]+# no example:/ { next }
        { allcmt = ""; incmt = 0 }
        END { flush() }
    ' "$ROOT/orbs/$1/lib.or"
}

section() {
    local orb="$1" b t
    echo "<h2 id=\"$orb\"><code>$orb</code></h2>"
    b="$(blurb "$orb")"
    [ -n "$b" ] && echo "<p class=\"orb-blurb\">$b</p>"
    t="$(types "$orb")"
    if [ -n "$t" ]; then
        echo '<h3 class="sub">Types</h3>'
        echo "$t"
        echo '<h3 class="sub">Functions</h3>'
    fi
    funcs "$orb"
}

emit() {
    cat <<'HEAD'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Orion Library Reference</title>
<meta name="description" content="Every orb that ships with Orion and the functions it exports, generated from the source.">
<link rel="stylesheet" href="style.css">
</head>
<body>

<a class="skip" href="#ref">Skip to the reference</a>

<header>
<h1>Orion Library Reference</h1>
<p class="lede">Every orb that ships with Orion, and what it exports. Generated from the <code>pub fn</code> signatures in <code>orbs/</code>, so it cannot drift from the code.</p>
<ul class="langs">
<li><a href="index.html">&larr; Field Guide</a></li>
</ul>
</header>
HEAD

    echo '<nav class="toc" aria-labelledby="toc-h">'
    echo '<h2 class="toc-h" id="toc-h">The orbs</h2>'
    echo '<ol>'
    for orb in $ordered; do
        echo "<li><a href=\"#$orb\"><code>$orb</code></a></li>"
    done
    echo '</ol>'
    echo '</nav>'

    echo '<main id="ref">'
    echo '<p>Bring an orb in with <code>use text</code>. Any function is also callable method-style, so <code>trim(s)</code> and <code>s.trim()</code> are the same call. The built-ins the guide uses (<code>print_line</code>, <code>len</code>, <code>push</code>, <code>get</code>, file and CLI functions) need no <code>use</code> at all.</p>'
    for orb in $ordered; do
        section "$orb"
    done
    echo '</main>'
    echo ''
    echo '</body>'
    echo '</html>'
}

# em/en dashes come from source comments; the project writes plain hyphens.
if [ "$MODE" = "stdout" ]; then
    emit | sed 's/\xe2\x80\x94/-/g; s/\xe2\x80\x93/-/g'
else
    emit | sed 's/\xe2\x80\x94/-/g; s/\xe2\x80\x93/-/g' > "$OUT"
    echo "wrote docs/reference.html ($(grep -c 'class="fn"' "$OUT") entries across $(echo $ordered | wc -w) orbs)"
fi
