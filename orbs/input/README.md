# input

What the person is doing, whatever they happen to be holding.

The `window` orb hands out mouse and keyboard EVENTS. This orb answers about
the two things a window cannot - the controllers plugged into the machine, and
touch - plus the one question that decides how a UI should look right now: who
spoke last.

## A pad is a VIRTUAL pad

It has south, east, west and north. Not A/B/X/Y, and not
cross/circle/square/triangle, so a program says what it MEANS and never which
plastic is in the hand. An Xbox pad, a DualSense and a DualShock all arrive
here as the same fourteen buttons and six axes; adding another make is a table
in the runtime, not a branch in your app.

The runtime finds them two ways because Windows has two: XInput for
Xbox-compatible pads across all four slots, and plain HID opened by WHO MADE IT
for everything else. That is how SDL does it, and it is the reason a DualSense
that Windows refuses to call a game controller still works.

## Two hosts, the same eleven questions

A program that reads a pad in a window reads it the same way in a tab.

```
native   link = "../orion/runtime/win32_min.c -luser32"
wasm     the page, out of the browser's Gamepad API
```

`hid.dll` and `setupapi.dll` are loaded by name at run time, so nothing new is
linked and a machine without them still starts.
