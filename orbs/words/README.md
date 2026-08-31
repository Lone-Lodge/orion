# words

What a program says, in the language of whoever is reading it.

A program full of `"Spara"` cannot be read in Arabic, and a program full of
`get_string(423)` cannot be read by anyone writing it. So the source says a KEY
and a table says what that key sounds like here.

```orion
book = words_of(read_file("sv.words"))
n("button", [p("text", say(book, "save"))], [])
```

The file is one saying per line, `key = what it says`. Blank lines and lines
starting with `#` are ignored, so a translator can leave notes.

```
save = Spara
files.one = {0} fil
files.many = {0} filer
```

A key with no saying answers with the KEY, not with nothing. A screen with
`files.many` printed on a button tells you what is missing; a screen with an
empty button tells you nothing at all, and that is how missing translations
ship.

## Watch out for

`{0}` in orion SOURCE is interpolation and becomes the number zero. In a file
read from disk it is just two characters - which is where sayings belong
anyway - but a saying written inline in orion has to escape it as `\{0\}`.

Deliberately not here: gender, case, and the fourteen plural forms some
languages have. Two forms cover the languages this is for, and the day one
needs more, `say_of` is where it goes - not spread through every app.

## Status

No consumer in the workspace. Nothing ships in two languages yet.
