# regex

A small regex engine, written for searching - dots grep, tooling - and not to
compete. The pattern is INTERPRETED during the match: no compilation, no
instruction set.

```orion
regex_test("gr(ay|ey)", "50 shades of grey")   # true
regex_first("\d+", "rad 42 kol 7")            # 4
regex_valid("a[b")                             # false, unclosed class
```

## The one idea

"Which end positions in the text can the pattern slice `[ps..pe)` reach from
position `ti`?" - a SET, not a position.

With sets, a quantifier is a closure (repeat until no new positions appear), a
group is a union over its alternatives, and backtracking does not exist as a
concept: every path is carried forward at once. It is total and finite, because
there are at most `length + 1` positions.

## Supported

Letters, `.` (anything but a line break), classes `[a-z0-9_]` and `[^...]`,
`\d` `\w` `\s` and `\x` literals, quantifiers `* + ?`, groups `(..)`,
alternation `a|b` in groups and at top level, anchors `^` and `$`.

## Watch out for

The engine sees BYTES. A multi-byte character - å, ä, ö - matches as a literal
run of its bytes, but inside a class or against `.` it becomes its individual
bytes.
