#!/usr/bin/env bash
# migrate_v2.sh — rewrite the corpus from v1 to v2 spellings (Runda B).
#
# ALIASES ARE ACTIVE in the parser, so this migration is safe: a site the sed
# misses keeps its old spelling and still compiles. Retirement of the old
# words is a LATER, separate step once every project is migrated and green.
#
# Line-anchored on purpose (the for->loop precedent): the compiler's own
# source compares keyword STRINGS (`value == "match"`) and its comments talk
# about keywords — neither may be rewritten. Anchors:
#   decls start at column 0; statements start at indentation; `= match`/`: yield`
#   are the expression positions. Quoted strings never match these anchors.
#
#   bash tools/migrate_v2.sh <dir>...
set -eu

for root in "$@"; do
    find "$root" -name "*.or" -not -path "*/_archive/*" -not -path "*/target/*" -not -path "*/dist/*" | while read -r f; do
        sed -i \
            -e 's/^pub extern fn /public external define /' \
            -e 's/^pub fn /public define /' \
            -e 's/^extern fn /external define /' \
            -e 's/^fn /define /' \
            -e 's/^pub type /public type /' \
            -e 's/^pub const /public const /' \
            -e 's/^\(\s*\)mut /\1edit /' \
            -e 's/^\(\s*\)match\b/\1choose/' \
            -e 's/= match\b/= choose/g' \
            -e 's/^\(\s*\)yield /\1collect /' \
            -e 's/: yield /: collect /g' \
            -e 's/: Text\b/: text/g' \
            -e 's/-> Text\b/-> text/g' \
            -e 's/\[Text\]/[text]/g' \
            -e 's/(Text\b/(text/g' \
            -e 's/, Text\b/, text/g' \
            -e 's/<Text\b/<text/g' \
            -e 's/: Map\b/: table/g' \
            -e 's/-> Map\b/-> table/g' \
            -e 's/\[Map\]/[table]/g' \
            -e 's/(Map\b/(table/g' \
            -e 's/, Map\b/, table/g' \
            -e 's/: bool\b/: truth/g' \
            -e 's/-> bool\b/-> truth/g' \
            -e 's/\[bool\]/[truth]/g' \
            "$f"
    done
    echo "migrated: $root"
done
