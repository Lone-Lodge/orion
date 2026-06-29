#!/usr/bin/env bash
# Bundle + strip comments and blank lines.
# Use this for AOT-bootstrap to feed less source to lodge-orion's slow interp.
# Output: dist/orion_self_bundled_min.or

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FULL="$ROOT/dist/orion_self_bundled.or"
MIN="$ROOT/dist/orion_self_bundled_min.or"

# Rebuild full bundle first.
bash "$ROOT/tools/bundle_orbs.sh" >/dev/null

# Strip:
#   - Lines that are entirely a comment (# ... or whitespace + # ...)
#   - Blank lines (after comment-stripping)
# Keep:
#   - Code lines
#   - Indentation (matters for blocks!)
#   - String literals (don't touch their content)
#
# NOTE: this is line-based, so a `#` inside a string survives as long as the
# whole line isn't comment-only. Trailing `# foo` comments after code are
# preserved (lodge-orion ignores them anyway).
grep -vE '^\s*#' "$FULL" \
    | grep -vE '^\s*$' \
    > "$MIN"

echo "full:     $(wc -l < "$FULL") lines, $(wc -c < "$FULL") bytes"
echo "minified: $(wc -l < "$MIN") lines, $(wc -c < "$MIN") bytes"
echo ""
echo "Saved: $MIN"
