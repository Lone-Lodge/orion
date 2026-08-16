# APP.md - the workbench and the shape of a room

BLOCKS.md says how Orion software composes (orbs, seams, extraction rules).
This says what the `app` orb promises and what a well-shaped app - a "room" -
looks like on screen. Proven by folio and scribe; everything here fell out of
building them, nothing was designed in advance.

## What the workbench (the `app` orb) provides

- `app_start(title, port, routes)` - the whole serve-and-run dance: port
  taken when free (stable origin = surviving browser storage), the window,
  the loop. `app_run(...)` is the full-control form (folio serves an image
  folder instead of ui/).
- `app_bar()` - one line of configuration: the standard window bar (pin on
  top, min/max/close, drag, dblclick-maximize) injected into every html the
  server sends. Colors follow `--bar-ink/--bar-bg/--bar-btn/--bar-accent`;
  app buttons append into `#bar-tools`. The server side (`/api/window`)
  registers itself.
- `on_get(path, handler)` / `on_post(path, handler)` - the route record,
  spelled short.
- `page(html)`, `json_of(body)`, `text_of(body)` - answers. Prose goes
  through `text_of`, NOT `page`: the bar script is injected into text/html,
  and injected script tags do not belong in a chapter.
- Static serving of `ui/` with correct mime types; `ui/index.html` serves
  "/" by itself, bar included - an app needs no route for its own page.
- `orbit new <name> --app` scaffolds this whole shape (planned - until it
  exists, copy scribe's).

## The room shape: rail, panel, main, foot bar

    [rail]        [panel]              [main]
    lens picker   the lens's list      the selection, rendered
    [foot bar: the server's understanding - words, scene, saved, sync]

The foot bar is Obsidian's: a thin, near-invisible strip. Left corner is
identity (project name, settings/help); right corner is contract 3 made
visible - derived state only (word count, "saved 2s ago", current scene,
later sync status). No middle section, never buttons that change meaning.

The look is Obsidian's: a thin icon ribbon (the rail), a collapsible panel
with its own small header actions (new, sort), the main area, the thin foot
strip. The ONE difference in kind: Obsidian's core is pages - our core is
EMPTY. The workbench ships with no content type at all; each lens brings
its own (Author brings chapters, Notes brings pages, Plan brings cards,
Code brings files). No lenses added = nothing but the gallery.

- There is ONE selection (which chapter/scene/card you are on). Views are
  LENSES over the same content, and the selection survives lens switches:
  pick a scene on the board, switch to writing, the caret is in that scene.
- A lens changes what you SEE, never what input MEANS. No modes.
- The panel is the lens's list (chapters, search hits, codex entries) and
  is collapsible - creators often want zero chrome.
- The main area has a slim header: back/forward over recent selections,
  the selection's title, and the lens's view actions on the right (sort,
  filter, new). The panel-collapse toggle NEVER disappears: it sits in the
  panel's header when open and moves to the main header's left edge when
  collapsed. (The window bar from app_bar is a separate hover overlay
  above all of this - window chrome, not room chrome.)
- The main area is a list of PANES; v1 has exactly one. A pane = one
  selection rendered through one lens, with its own slim header. A later
  split-in-two (writing + research) is additive because of this shape.
  Free-form docking is out until a real workflow proves the need.
- Tabs are not workbench furniture. The workbench way is Ctrl+Tab jumping
  between recent selections (MRU) plus pinning in the panel. A lens whose
  real working set is many small files (a code lens) may draw its own tabs
  inside its main area.

## Lenses are added, not built in

The rail is data-driven: a registry of lenses, each on or off per project.
"Adding an app" in the gallery = enabling a lens. The contract, in one
sentence: *adding a lens adds one section to the rail - nothing else moves.*

Onboarding IS the gallery: first start shows an empty rail and the app grid
("Your space") in the main area: a "start with these" row, then all apps,
Added badges on what you have. Each Add puts an icon in the rail; an app's
landing page in the main area carries its Remove button - add and remove
are the same motion in the same place. The grid never goes away: its
button sits at the TOP of the rail (home lives at the top), search below
it, then the added apps. Tab cycles between added apps; the command
palette ("open anything") opens apps and content by name - its input is
also the future say-what-you-want hook.

- All lenses ship compiled in the exe (they are orbs); the gallery chooses
  what shows, not what downloads.
- A "dressed" distribution (scribe.exe for authors) is the same workbench
  with some lenses pre-enabled. Ordinary users never meet the gallery
  unless they go looking.
- Show the effect before enabling, on the user's own content ("on chapter 3
  this would show: 9 min read"), and say what sharing means before anything
  is shared.

## The start: a shelf, not a dialog

A room with several projects opens on a shelf: one big resume card (cover,
title, *where you were* - "chapter 12, scene 3, 48 210 words, yesterday")
and a row of other projects as covers. One click resumes. The cover is a
file in the project folder (`omslag.png`) - the folder stays the truth.
Resume-first beats browse-first: a creator opens the same project 200 times.

## The three contracts under everything

1. **The folder is the truth.** Plain files (md), no database, honest in
   any other editor, git-friendly. Scene/section markers live IN the text
   (`---` on its own line) so structure survives outside the app.
2. **The page talks to a store, never fetch directly.** One js `store`
   object owns all server contact. v2 offline (local copy + sync queue +
   three-way merge against the home node) replaces the store's insides;
   no other line changes.
3. **The server answers with what it understood.** A save returns derived
   metadata (`{words, scenes: [...], ranges: [...]}`), never just ok:true.
   Derived beats hand-filled - it is never stale. This named, stable shape
   is also the hook future add-ons (`appliesTo(item)` / `render(item)`)
   will stand on. Decorations reach the text as character ranges via the
   CSS Custom Highlight API - styling on top, never markup inside.

## What NOT to build

- No plugin architecture before two real lenses strain the seam.
- No generic "content engine". Rooms drive; the workbench grows by
  extraction (the two-consumer rule, BLOCKS.md) - never by speculation.
- No cloud. Sync is device-to-device against the user's own home node.
