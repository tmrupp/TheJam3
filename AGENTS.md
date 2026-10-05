# Somnonaut (TheJam3): notes for coding agents

A Godot 4.7 platformer: a faceless wizard dives through procedurally generated levels, printed in a
risograph style. Every level is a cell grid collapsed by wave function collapse (WFC) from a small
sample image, then dressed with exits, keys, enemies and hazards by `MapInfo.World`.

## Where things live

- `scripts/MapInfo.gd`: the level. The `World` inner class builds a layout from collapsed cells
  (`populate_level`, then a `populate_*` pass per archetype). The rest of the file loads it into
  the scene (`place_cell`), keeps each level's record (taken, opened, slain...) and handles travel.
- `scripts/worlds/NextWorldDef.gd`: what a place is (archetype, sample, size, realm, exits).
  `Worlds.gd`, `SideWorld.gd` and `Hyperspace.gd` cover side worlds.
- `scripts/riso/`: all the art. `RisoPrint` (plates and the print shader), `RisoProp` (one art node
  per prefab, by kind), `RisoTerrain`, `RisoDecor`, `RisoWizard`, `RisoMap`, the HUD and menus.
- `scripts/*.gd`: gameplay (Player, enemies, hazards, spells, pickups). `prefabs/*.tscn` pair
  with them, and `RisoPrint.DRESS` maps each prefab to its art kind.
- `wfc_images/`: WFC samples (white open, black rock, red thorns). Drawn ones come from
  `tests/make_*_sample.gd`, so edit the script and rerun it rather than editing the PNG.
- `gdextension/`: the C++ overlapping-WFC extension (SCons). Rarely touched.
- `docs/`: `DEEPER_PLAN.md` (design, by system), `RISO_PRINT.md` (the art pipeline and rules),
  `TOM_THOUGHTS.md` (the owner's notes; see the ground rules).
- `tests/`: `*_test.gd` regressions, `capture_*.gd` stills (written to `../art-captures/`),
  `make_*_sample.gd` sample generators.

Level bands cycle by depth (`NextWorldDef.ARCHETYPES`, `BAND` = 6): garden → cemetery → sky. Tests
that need a band's levels use `NextWorldDef.first_depth(&"cemetery")` rather than a fixed depth.

## Running and testing

Godot: `$GODOT`, else `godot` on the PATH, else
`C:\tools\godot-win\Godot_v4.7.2-stable_win64_console.exe`.

```bash
bash tests/run.sh                 # quick tier: untagged tests, headless, in parallel
bash tests/run.sh full            # also "## suite: full", then "## suite: window" one at a time
bash tests/run.sh sky_test        # just these, headless
```

- A test's tier is a line near its top: `## suite: full` (slow, or known broken) or
  `## suite: window` (needs a rendered window; never run these headless by name).
- A test passes on exit 0 with no `FAIL`, `SCRIPT ERROR` or `Parse Error` in its log. A test that
  fails alongside others but passes alone is reported FLAKY. Logs go to `/tmp/thejam3-tests/`.
- `run.sh` re-imports first. After adding a `class_name` script or an image outside it, run
  `godot --headless --path . --import`.
- Captures: `godot --path . --windowed --resolution 1280x720 --script res://tests/capture_x.gd`.
- Known flaky: `sky_art_test`'s transition-edge check.
- Each test sets its own `MapInfo.save_path` (`user://<test>.save`), so they can run in parallel.
- New tests extend `TestKit` (`tests/kit/TestKit.gd`): override `run()`, end with `finish()`, and
  use its `check`/`check_eq`, `boot(seed)` (starts a run, keeps the save apart), `until(cond)` and
  `settle()` rather than counting frames, and `placed`/`colored`. For the level generator alone,
  `build(at)` lays a place out without the game scene, which is far faster than booting the game.
  Older tests still carry their own copies of these; move them onto the kit when touching them.
- `unit_test` checks the plain rules (seeds, prices by depth, key rarity, side-world places,
  archetype bands, where exits lead, shrine offers, the keyring) without the scene, in a second
  or two. Put a rule there when it needs no level.

## Code conventions

- GDScript with static types everywhere: `var x: int`, typed arrays, typed loop variables. Untyped
  loop variables and inferred types are errors (warnings are treated as errors).
- `##` doc comments on classes, constants, vars and funcs. They are plain, explanatory prose about
  what a thing is and does in the game, not how the code is built. Keep the existing tone: full
  sentences, no marketing, and avoid jargon where a plain word works.
- Constants get a doc comment and a name in `UPPER_SNAKE`. Tuning numbers live in constants, not
  inline.
- Prefer extending an existing system over adding a parallel one: a new hazard is a prefab, a
  script, a `RisoProp` kind and a `MapInfo.Type`, placed in a `populate_*` pass.
- Keep each test focused, deterministic (fixed seeds, usually world 28) and printing `ok` lines.
  Add or extend a test for each behaviour change.

## Level generation: determinism matters

- Everything comes from `level_seed(world, depth)`. A level must be identical on every visit:
  tests compare two builds (`w.objects == again.objects`).
- The world RNG is shared and ordered. Adding, removing or reordering an `rng` draw (or a forced
  `pop_if_random_empty`) shifts every later placement in every level, and that breaks
  layout-sensitive tests. Put new passes last, draw from the RNG only where needed, and expect to
  re-check `cemetery_test`, `deeper_test`, `economy_test` and `sky_test` when a draw is added
  upstream. `layout_fingerprint_test` says so first: it fingerprints the terrain and the dressing
  of a few levels per archetype and a side world, and names which one changed. When a change to
  the layouts is meant, copy the fingerprints it prints into its `GOLDEN` and say so in the report.
- Decor never touches the world RNG: it hashes the seed and cell (`RisoDecor.h`).
- Nor does anything once a level is laid out. Its `World` is kept and reused on later visits, so
  loading it (`MapInfo.place_cell`, a prefab's `setup`) must hash the seed and cell rather than
  draw from `world.rng`, or it differs from one visit to the next (`revisit_test`).
- Key and door colours are dealt by rarity once a level is laid out (`World.deal_colors`, hashing
  the level seed, no RNG) and kept in each cell's `extra_info`; `RisoMap.dealt_colors` reads them.
- Placement helpers live on `World`: `pop_if_random_empty(filter, force)`, `add_object_at`,
  `set_cell`, `_to_rock`, `_to_open`, `per_area(per_k)` (counts scale with level area).

## Art rules (the riso print): see `docs/RISO_PRINT.md`

- Art is ink coverage on plates (night, blue, pink, accent, eye, glow, robe), drawn with
  `InkCanvas.ink`, `knock` (clear to paper) and `lift_ink`. Plates multiply. Within a plate, order
  is `z_index`.
- No outlines of any kind. Use simple procedural shapes (`RisoShapes`). Pink means danger, accent
  or yellow means reward, glow belongs to the wizard. Decor stays in blue, night, moss and paper.
- Keep backgrounds dark and low-contrast, and put saturation and paper-bright knockouts on gameplay
  objects.
- Layers (absolute z): sky −40, terrain −20, hedges −17, fences −16, decor −15, lantern light −12,
  props 2, the wizard's trail 9, the wizard 10, UI 50 and up.
- Check art changes with a capture and look at it zoomed in before calling them done.

## Windows editing pitfalls

- Write files as UTF-8 with LF line endings. When scripting edits in Python, use
  `encoding='utf-8', newline=''`. Bash heredocs with quotes in them break easily, so put longer
  edit scripts in a scratch file.
- GDScript indents with tabs.

## Ground rules

- `docs/TOM_THOUGHTS.md` is the owner's file and begins "DO NOT MODIFY": never edit it. Commit the
  owner's changes to it only when asked.
- Don't commit or push unless asked. Leave untracked files you didn't create alone.
- Several sessions may work in this tree at once. Don't revert changes you didn't make. Build on
  them, and report problems in them rather than silently rewriting them.
- Keep `docs/DEEPER_PLAN.md` and `docs/RISO_PRINT.md` in step with behaviour changes: the numbers,
  the rules and the tests that cover them.
- Work on branch `game/deeper`; remote `origin` is github.com/tmrupp/TheJam3.
