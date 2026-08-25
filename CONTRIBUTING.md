# Contributing

The short version: build it, change it, prove it, and keep the diff small.

## Build

You need `clang`. Nothing else.

```sh
bash tools/bootstrap.sh
```

From a bare checkout: the committed seed builds a first compiler, that compiler
rebuilds itself to a fixpoint, `orbit` is built, and the smoke suite runs.

## Prove it

Every gate is a shell script in `tools/`, and every one of them is meant to be
run from the repo root. The ones a change usually has to answer to:

```sh
bash tools/test.sh              # 228 smoke tests, one feature each
bash tools/negative_test.sh     # 38 programs that must be rejected
bash tools/project_test.sh      # the gates that need a project of their own
bash tools/docs_check.sh        # the guide compiles, and its contrast is AAA
```

A change that adds behaviour adds a test that fails without it. A gate nobody
runs is worse than no gate: `tests/keywords` sat green for a month while the
language moved out from under it, and nothing said a word.

## The shape of a change

- **The simplest thing that works.** Fewer files, fewer concepts.
- **A comment says what the code cannot.** A why, a trap, a measured number. If
  it repeats the line below it, delete it.
- **One subject line, lower case, saying what is now true.** `parser: a rule
  body ends at patch and law`, not `fix parser bug`.
- **No retired spellings.** `tools/orbstat.or` reports them; the corpus is at
  37 orbs of 37 clean and should stay there.

## Sending a change

Two branches, and that is all: **`dev`** is where work lands, **`main`** is what
has been released. Open your pull request against `dev` - it is the default
branch, so a fork targets it without you having to think about it.

You cannot push here, and that is the point: fork, branch off `dev`, and open a
pull request. CI runs the gates on every one, on Linux and Windows, and `dev`
will not take a merge until they are green. Nothing lands unread and unproven.

`main` only moves for a release, and only by the maintainer.

What gets merged: one thing at a time, small enough to read in a sitting, with
the gate that proves it. What does not: a rewrite nobody asked for, a change
with no way to tell whether it works, or a diff that mixes a fix with a
reformat. If you are unsure whether something is wanted, open an issue first
and ask - that costs you nothing and saves you an afternoon.

## Where things live

```
orbs/       the libraries, and the compiler itself
runtime/    the C runtime the emitted code links against
tools/      bootstrap, the gates, benches, the LSP, orbit
tests/      the smoke suite, the negatives, the project gates
examples/   demos, drivers, the wasm gallery
docs/       the Field Guide and the library reference
```
