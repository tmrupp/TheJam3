# Somnonaut (TheJam3): notes for coding agents

A Godot 4.7 platformer: a faceless wizard dives through procedurally generated levels, printed in a
risograph style. Every level is a cell grid collapsed by wave function collapse (WFC) from a small
sample image, then dressed with exits, keys, enemies and hazards by `LevelGen`.

## Where things live

- `scripts/level/`: a level, apart from how it looks.
  - `LevelGen.gd`: a level laid out from its collapsed cells (`populate_level`, the `Type` of
    each cell, `Cell`, and the placement helpers). `Chasms.gd`: chasms and gaps, cut and crossed.
    `Crypts.gd`: the cemetery's crypts, their insides and their trials (pits, crawls, wells
    worked with sun and shade blocks) collapsed from samples of their own (`Archetype.patches`,
    handed to the layout as `LevelGen.patches`), and their prizes. `Institute.gd`: the
    institute's halls of marble (`LevelGen.halls`) and who is in them. `Timetable.gd`: its
    timetable's rules (periods, when each hall is in session, where the wizard belongs, which
    spell a glyph seal asks for); `MapInfo` plays it out.
  - `Placeables.gd`: one table, by `LevelGen.Type`, of each thing's prefab, art kind, box size and
    flags (enemy, stander, floats, colored). Loading, the art dresser and the map read it.
  - `RunState.gd`: the run (records, the lantern to come back to, the ghost, relics) and saving it.
    `LevelRecord.gd`: what changed in one place (taken, opened, slain, bridges...), typed.
  - `LevelLoader.gd`: the generator cache and worker thread, building a level in the scene
    (`place_cell`), the rock and camera, and chunk sleeping.
  - `Rules.gd`: the run-wide rules, static and scene-free (`level_seed`, prices and values by
    depth, key rarity, what a level holds by its seed, `level_size`, `def_for`, `where`).
  - `Difficulty.gd`: the difficulty presets (the F7 or `` ` `` panel; Hard by default): how many foes a level holds
    (`foes`, via `LevelGen.foes_per_area`), how fast the bosses act (`haste`), and how often the
    other enemies attack (`attack`) and how fast they move (`speed`).
- `scripts/MapInfo.gd`: the place being played (`coord`, `here`, `world`), travel, and what a
  change in the record means in the scene (doors, bells, secret rooms, death). It keeps a
  `RunState` (`run`) and a `LevelLoader` (`loader`).
- `scripts/worlds/`: what a place is. `Bands.gd` (the band layout: which archetype holds which
  rows, each band's boss and tuning, and the demo's garden-only layout), `NextWorldDef.gd` (exits,
  prices, realm), `Archetype.gd` and `archetypes/` (one per band: sample, size, gates, how thickly
  it is dressed and its own placement pass), and side
  worlds (`Worlds.gd`, `SideWorld.gd`, `Hyperspace.gd`, and `PracticeRange.gd`, the debug runs' range
  for weighing the damage spells, with its tally `scripts/PracticeTally.gd`).
- `scripts/riso/`: all the art. `RisoPrint` (plates and the print shader), `RisoProp` (the base of
  one art node per prefab) with a script per kind in `props/`, `RisoMarks` (keys, locks, gates,
  chevrons shared with the map and HUD), `RisoGlyph` (ability marks), `RisoTerrain`, `RisoDecor`,
  `RisoWizard`, `RisoMap`, `RisoLight` (light and darkness, cut by line of sight over the cells in
  `RisoSight`), the HUD and menus.
- `scripts/*.gd`: gameplay (Player, enemies, hazards, spells, pickups). `prefabs/*.tscn` pair
  with them. `Abilities.gd` lists every ability in one table (`ABILITIES`); an ability's node says
  what its tier does (`set_tier`) and, for a spell, casts (`cast_spell`) and tells the spell orb
  how ready it is (`readiness`) and how long it has left (`running`). `Lamplight.gd` is light as
  the game reads it (what wakes, freezes or can be wounded), apart from `RisoLight`, which prints
  it. `Stage.gd` finds the main
  scene's wizard, TileMap, camera and menu (no `/root/Main/...` paths elsewhere).
- `wfc_images/`: WFC samples (white open, black rock, red thorns). Drawn ones come from
  `tests/make_*_sample.gd`, so edit the script and rerun it rather than editing the PNG.
- `gdextension/`: the C++ overlapping-WFC extension (SCons). Rarely touched.
- `docs/`: `DEEPER_PLAN.md` (design, by system), `REGIONS_PLAN.md` (the plan for going up and
  down from the garden, the new bands and the bosses at band ends; phases 1 to 4 built (the worm
  and the bramble), a first pass of the crags and their lodestone golem of phase 5 (with the lodestones, empowered spells and spires), phase 6, the cemetery's
  crypts, light and the necromancer, and a first pass of phase 7, the institute, its beast and its timetable),
  `RISO_PRINT.md` (the art pipeline and rules), `CLEANUP_PLAN.md` (the ten follow-ups to the
  architecture refactor, all done; kept for why the shared helpers are shaped as they are),
  `PAIRED_PLAN.md` (paired play, preliminary: two players on two machines, each seeing the
  other's map, coded messages their only channel; nothing built yet).
- The owner's task list and notes are a Google Doc, not a file here:
  [Somnonaut: Tom's Tasks](https://docs.google.com/document/d/11vPYlA0G-_dZY2sdV8aK6qM06c1RAE2r05uHSngRHa8/edit)
  (see the ground rules). Open tasks are checklists under topic headings; a ticked or struck-through
  item is done, and finished items are moved to "Done" at the bottom.
- `tests/`: `*_test.gd` regressions, `capture_*.gd` stills (written to `../art-captures/`),
  `make_*_sample.gd` sample generators.

Places are (seed, row): row 0 is the start, positive rows go down, negative rows go up, and a
level's `depth` is its distance `|row|` (side worlds sit below `-Worlds.SIDE_BASE`). Bands come from
one table, `Bands.LAYOUTS`: in the whole game (`full`) the garden spans rows −3…+3; down, the
cemetery then the institute; up, the crags then the sky, 6 rows each, each band's boss at its far
end. Each band's line gives its archetype, its rows, its boss and optionally a `"tune"` of its
archetype's settings (`star_share`, `wisp_share`, `watcher_share`, `hoppers_per_k`...), so a band
is tuned, lengthened, reordered or left out there and nowhere else. The `garden` layout is the
demo: the garden alone, the worm and the bramble at its ends, garden levels going on past them. A
game plays `-- layout=<name>`, else `garden` in a build with the `demo` feature (an export preset's
custom feature), else `full`; a layout other than `full` keeps its own save. A new band is one
script extending `Archetype`, listed in a layout.

Tests must hold however the bands are tuned. Ask the bands for rows rather than counting them:
`NextWorldDef.band_row(&"cemetery", k)` (row k of the band, counting away from the start),
`Bands.rows_of(kind)`, `Bands.garden_rows()`, `Bosses.row_of(boss)`; never a fixed row, `6` or
`first_depth + k`; `band_rows(kind, ks, gate)` (TestKit) holds each k to the band, a negative k
counting back from its gate. A test of a band starts with
`if not needs([&"cemetery"]): finish(); return` (TestKit), so it skips when that band is left out.
A test that needs a level with something in it (two watchtowers, a student with a walk) looks for
one over a few worlds and rows with `build`, rather than trusting one level to have it.
`bands_test` checks the band rules under every layout and a few made-up ones;
`bash tests/run.sh -l garden full` runs the suite on the demo's, and `-l retuned` on the tests' own
`TestKit.RETUNED` (every band retuned), which shows a test leaning on how the bands are tuned now.

## Running and testing

Godot: `$GODOT`, else `godot` on the PATH, else
`C:\tools\godot-win\Godot_v4.7.2-stable_win64_console.exe`.

```bash
bash tests/run.sh                 # quick tier: untagged tests, headless, in parallel
bash tests/run.sh full            # also "## suite: full", then "## suite: window" one at a time
bash tests/run.sh sky_test        # just these, headless
bash tests/run.sh -l garden full  # the suite on another band layout (the demo's)
```

- A test's tier is a line near its top: `## suite: full` (slow, or known broken) or
  `## suite: window` (needs a rendered window; never run these headless by name).
- A test passes on exit 0 with no `FAIL`, `SCRIPT ERROR` or `Parse Error` in its log. A test that
  fails alongside others but passes alone is reported FLAKY. Logs go to `/tmp/thejam3-tests/`.
- `run.sh` re-imports first. After adding a `class_name` script or an image outside it, run
  `godot --headless --path . --import`.
- Captures: `godot --path . --windowed --resolution 1280x720 --script res://tests/capture_x.gd`.
  `capture_overview.gd` photographs whole levels, every band and a few worlds each, to look over
  many layouts at once (options after `--`, e.g. `-- bands=crags worlds=6`).
- A test that freezes the wizard (physics off) and moves them calls `still()` (TestKit) before
  their physics runs again, or a dash or knock-back under way carries on from the new place.
- Windowed runs on the kit stay out of the owner's way: muted, the window off every screen
  (`TestKit.out_of_sight`; minimized, Windows stops it drawing). Add `-- watch` to see and hear one.
- Garden probes: `tests/dump_garden.gd` prints what every garden row holds over many worlds (foes,
  stars against the way on's price, keys and doors, whether the way on is in hop reach);
  `tests/capture_garden_play.gd` has a rough bot play garden levels (hops, drops through ledges,
  wall jumps up chimneys) and print how far it got and the blows it took.
- Each test sets its own `RunState.save_path` (`user://<test>.save`), so they can run in parallel.
- New tests extend `TestKit` (`tests/kit/TestKit.gd`): override `run()`, end with `finish()`, and
  use its `check`/`check_eq`, `boot(seed)` (starts a run, keeps the save apart), `until(cond)` and
  `settle()` rather than counting frames (`until(gone(node))` for something being freed; a lambda
  holding the node itself errors once it is), and `placed`/`colored` (`placed(scene, true)` counts
  hidden things too: the ghost, a bridge's planks before its bell rings). For the level generator
  alone, `build(at)` and `collapse(at)` lay a place out without the game scene, which is far faster
  than booting the game. `until` polls on process frames: a step timed in physics frames (a dash, a
  jump) wants an `await physics_frame` after it. `until`'s timeout is wall-clock time; for
  something the game times itself (a cooldown, a regrowth) use `within(cond, game_seconds)`, which
  counts physics frames, as a busy machine runs the game slower than the clock. The kit runs one
  physics step a frame, so a press made with `Input.parse_input_event` always reaches the game
  before the next physics step, however loaded the machine. `bash tests/run.sh -j 16 full` loads
  the machine harder, to shake out tests that depend on timing. A few small tests still carry their own `check`;
  move them onto the kit when touching them.
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
  script, a `LevelGen.Type` with its `Placeables` entry (with `"setup": 2` or `3` if its prefab
  has a `setup`), an art script in `scripts/riso/props/` (listed in `RisoProp.KINDS`), placed in a
  `populate_*` pass or an archetype's `populate`. Something a hex bolt strikes that answers it
  itself has `hex_hit(damage, dir)` and is listed in `HexBolt.ANSWERS`.
- Reach other nodes through types, not names: `Stage` for the main scene's nodes, `as SomeClass`
  casts and typed calls rather than `get("x")`, `call("x")` or `has_method("x")`, which fail
  silently when misspelled. The few calls by name left, across scripts with no shared base class
  (a prefab's `setup`, `hex_hit`, an ability node's `set_tier`, `cast_spell`, `readiness` and
  `running`), are declared in a table and checked by `unit_test`.
- Keep each test focused, deterministic (fixed seeds, usually world 28) and printing `ok` lines.
  Add or extend a test for each behaviour change.

## Level generation: determinism matters

- Everything comes from `level_seed(world, depth)` and the difficulty preset (`Difficulty`). A
  level must be identical on every visit: tests compare two builds (`w.objects == again.objects`).
  The fingerprints are of the default preset (Hard); Normal lays levels out as they were before
  the presets.
- The world RNG is shared and ordered. Adding, removing or reordering an `rng` draw (or a forced
  `pop_if_random_empty`) shifts every later placement in every level, and that breaks
  layout-sensitive tests. Put new passes last, draw from the RNG only where needed, and expect to
  re-check `cemetery_test`, `deeper_test`, `economy_test` and `sky_test` when a draw is added
  upstream. `layout_fingerprint_test` says so first: it fingerprints the terrain and the dressing
  of a few levels per archetype and a side world, and names which one changed. When a change to
  the layouts is meant (retuning a band's dressing is one), run it with `-- update` to write the
  new fingerprints into its `GOLDEN`, and say so in the report.
- Decor never touches the world RNG: it hashes the seed and cell (`RisoDecor.h`).
- Nor does anything once a level is laid out. Its `LevelGen` is kept and reused on later visits, so
  loading it (`LevelLoader.place_cell`, a prefab's `setup`) must hash the seed and cell rather than
  draw from `world.rng`, or it differs from one visit to the next (`revisit_test`).
- Key and door colours are dealt by rarity once a level is laid out (`LevelGen.deal_colors`, hashing
  the level seed, no RNG) and kept in each cell's `extra_info`; `RisoMap.dealt_colors` reads them.
- Placement helpers live on `LevelGen`: `put(v, type, extra)`, `put_random(type, test, force)`,
  `pop_if_random_empty(filter, force)`, `empties_where(test)` and `free_floors()` (sorted),
  `pick(items)` and `pop_pick(items)` (one draw each), `pick_apart` and `spread_out` (spots kept
  apart), `dist(a, b)`, `_to_rock`, `_to_open`, `per_area(per_k)` (counts scale with level area),
  `reach_from(start, passable)` (the open cells reached from a cell, a set: sort before drawing)
  and `best_of(spots, score, test)` (the nearest or, with the score negated, furthest spot; no
  draw, ties keep the earlier spot).

## Traversability: not enforced, in any world

- The owner's rule, for every world and band: do not make sure a level can be traversed. Add no
  pass that lays ledges, carves passages, moves things or re-deals a layout so the way on (or a
  tower, a station, a reward) is reached on foot, and no check or test that fails a level for
  being hard or impossible to get through. A level that cannot be crossed without a relic, a
  move found later or the gondola is fine.
- Logic that is not about walking is still checked where it was asked for: the crags' tower puzzle
  deals its switches so there is a way up and a way down through the switches themselves
  (`Stations.deal`), taking each tower as reached from its own tier.
- `connect_caves` (every open space joined into one cave, tiny pockets filled) stays: the owner
  is fine with it. The climbing aid that laid ledges toward an up level's way on (`Climb.aid`) is
  gone; do not bring it or anything like it back.

## Art rules (the riso print): see `docs/RISO_PRINT.md`

- Art is ink coverage on plates (night, blue, pink, accent, eye, glow, robe), drawn with
  `InkCanvas.ink`, `knock` (clear to paper) and `lift_ink`. Plates multiply. Within a plate, order
  is `z_index`.
- No outlines of any kind (one exception, the owner's: a passable sun or shade block is drawn as an
  outline round its group, `PhaseBlockArt`). Use simple procedural shapes (`RisoShapes`). Pink
  means danger, accent or yellow means reward, glow belongs to the wizard. Decor stays in blue,
  night, moss and paper.
- Keep backgrounds dark and low-contrast, and put saturation and paper-bright knockouts on gameplay
  objects. A figure's colour made by overprinting inks goes through `RisoPrint.legible`, which screens
  it back until it reads on the realm's ground. Every canvas lifts the ground from under what it
  prints and holds its rock ink to what reads (`InkCanvas.punches_wall`, `figure_rock`); only the
  ground's own canvases turn the first off, and art that is the rock itself sets `of_the_rock`.
- Layers (absolute z): sky −40, the whale cruising −30 (over the wizard, 11, while it swallows them), acid −21
  (its surface over the wizard, 11), terrain −20, hedges −17, fences −16, decor −15, lantern light −12,
  props 2, the darkness out of sight 8, the wizard's trail 9, the wizard 10, the exam papers they carry 11,
  UI 50 and up.
- Check art changes with a capture and look at it zoomed in before calling them done.

## Windows editing pitfalls

- Write files as UTF-8 with LF line endings. When scripting edits in Python, use
  `encoding='utf-8', newline=''`. Bash heredocs with quotes in them break easily, so put longer
  edit scripts in a scratch file.
- GDScript indents with tabs.

## Ground rules

- The owner's task list is the Google Doc linked under "Where things live". Read it for direction
  (with a Google Docs or Drive tool; if you can't open it, ask for the tasks you need). It is the
  owner's document: never edit it, tick its boxes or comment on it unless asked.
- Don't commit or push unless asked. Leave untracked files you didn't create alone.
- Several sessions may work in this tree at once. Don't revert changes you didn't make. Build on
  them, and report problems in them rather than silently rewriting them.
- Keep `docs/DEEPER_PLAN.md` and `docs/RISO_PRINT.md` in step with behaviour changes: the numbers,
  the rules and the tests that cover them.
- Work on branch `game/deeper`; remote `origin` is github.com/tmrupp/TheJam3.
