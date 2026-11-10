# Performance and the test suite: a plan

An analysis of where the game and its regression suite spend their time, made on 9 November 2026
on the owner's machine (16 logical cores, Godot 4.7.2), and a plan to make both faster without
giving up the code's composition or repeating code. Step 1 of the order of work (1.1, 1.3 and
1.4) is built; the rest is not yet.

Every figure below was measured, not guessed, with throwaway probes (the per-pass timings in a
scratch copy of the tree, so the working tree was not touched). Another session was running the
suite during part of the work, so the absolute numbers are a little high; the proportions held
from run to run.

## What was measured

### The suite

- The last full run (`bash tests/run.sh full`) took about 9 minutes of wall-clock time: 109
  headless tests, 8 at a time, adding up to about 3,040 test-seconds, then three windowed tests one
  at a time. `temple_test` timed out at 120 s and was run again, which cost another two minutes.
- No test is tagged `## suite: full`, so the "quick" run is the full run without its three windowed
  tests. The comment at the top of `run.sh` ("about half a minute") is long out of date.
- The slowest tests: `temple_test` (timed out at 120 s), `crossbow_test` 119 s, `bridge_walk_test`
  92 s, `towers_test` 87 s, `sigils_test` and `bramble_test` 79 s, `darkness_test` 73 s,
  `difficulty_test` 70 s, then a dozen between 50 s and 70 s. The fastest take 8 to 10 s.
- Starting the engine is cheap: a bare `--script` run reaches its first line in about 0.15 s and
  exits in 0.4 s. A `boot()` into the garden's start level takes about 1 s. Startup is not where the
  time goes.

### Laying out a level

The terrain collapse (the C++ extension) is cheap. Dressing the collapsed cells (`LevelGen.new`,
all GDScript) is where the time goes, and it grows with the band:

| Band | Level size | Collapse | Dressing (`LevelGen.new`) |
| --- | --- | --- | --- |
| garden | 36 × 30 to 42 × 35 | 55–80 ms | 70–105 ms |
| cemetery | 81 × 54 | 85–95 ms | 810–970 ms |
| institute | 60 × 48 | 30–60 ms | 410–540 ms |
| crags | 48 × 67 to 48 × 79 | 45–60 ms | 405–540 ms |
| sky | 108 × 77 | 65–105 ms | 1,190–1,800 ms |

Within the dressing, per level on average (world 28, five rows of each band):

| Band | Biggest passes |
| --- | --- |
| cemetery | `Crypts.build`'s site search 307 ms, `Chasms.carve` 133 ms, `connect_caves` 75 ms, `place_vaults` 69 ms, `place_secrets` 61 ms, `Chasms.place_bells` 45 ms |
| institute | `connect_caves` 152 ms, `Institute.build`'s hall sites 91 ms, `place_vaults` 58 ms, `place_secrets` 51 ms |
| crags | `connect_caves` 118 ms, `place_vaults` 77 ms, `place_secrets` 55 ms, `cut_gates` (circuit, tiers, towers) 54 ms, `populate` 51 ms |
| sky | `build_temples` 378 ms, `shape` 170 ms, `place_vaults` 148 ms, `place_secrets` 95 ms, `place_switch_gates` 93 ms, `connect_caves` 86 ms, `place_moons` 85 ms, `place_cluster` 75 ms |

What these passes have in common: **exhaustive searches for a site**. For every cell of the level,
a box is tested cell by cell (`SkyArchetype._temple_site`, the chasm shores, the vault and secret
room spots), or a whole-level scan is repeated inside a loop (`connect_caves` counts every open cell
again on every pass of its loop, `_open_count`; `place_lift_switches` and `place_boss` rebuild and
sort `free_floors()` for every lift). The crypts and the institute's halls already use running sums
(summed-area tables) to count cells in a box at once, which is the right idea, but only there.

What it is **not**: the linear `erase`/`has` on `empties`, `grounds` and `objects`. Timed directly,
`_to_rock`, `_to_open` and `add_object_at` together cost 2–4 % of a level (64 ms of a sky level's
1.7 s at most). They are worth tidying, but they are not the problem, and the order of `empties` is
load-bearing (`pop_if_random_empty` draws an index into it), so changing its container shifts every
level.

### Travelling in a test (and in the game)

- `info._load_level()` then `settle()` takes 1.5–3.2 s for a band level: the dressing above when the
  level is not cached, plus 1–1.5 s of building it in the scene (8,000-odd nodes in a cemetery or sky
  level).
- Every arrival queues the place's neighbours (up to four) for the loader's worker thread
  (`LevelLoader.prefetch_neighbours`). In a test that jumps about, those are thrown away, but each
  costs 0.5–1.8 s of a core. With 8 tests running, that is up to 8 more busy threads.
- Worse, in a test and in the game: a place that is asked for while the worker is laying out a
  neighbour waits for that neighbour to finish first (`_pump` returns while `gen_busy`). A jump to a
  place that was not prefetched (a rift, a respawn, a debug jump, every `_go` in the tests) can wait
  up to 1.8 s for a level nobody wanted.
- The map asks `LevelLoader.world_at` for places it has not laid out, which lays them out on the main
  thread: up to 1.8 s of frozen frame in the sky band.

### Frames

- Headless, standing still, a frame costs 6 ms in the garden and 10–15 ms in the bands, with one
  physics step a frame. The art (`RisoProp` and its 70 kinds, `RisoLight`, decor) still runs
  headless, where nothing is drawn.
- With `--fixed-fps 60` a headless test runs as fast as its frames allow instead of waiting on the
  clock for each physics step: `whale_test` went from 36.5 s to 28.2 s; `ladder_test`, whose time
  is spent laying levels out, did not change.
- Some game logic reads the wall clock (`Time.get_ticks_*`): `Lodestone` (its clock),
  `Parry.parried_real`, `Player.hit_at`, `SeedPod`'s flashes, `Wound`'s hit-stop and a few art
  scripts. Under load, or with `--fixed-fps`, wall time and game time part.
- In a window (`tests/bench_frame.gd`, RTX 3060 Ti, the machine busy with a suite run, so a little
  high): a steady frame's median is 12.6 ms at the start, 19.5–22.9 ms in the cemetery and crags.
  Of a crags frame, the process pass is 10 ms, redraws 4.5 ms, the plates' CPU 3 ms, physics 2.4 ms;
  the GPU is not the limit (2–3 ms). By script, the costs that recur:

  | Script | Cost a frame | Where |
  | --- | --- | --- |
  | `RisoWizard` | 1.1–1.5 ms | every level |
  | `RisoLight` | 0.7–2.3 ms | every level, most in the cemetery |
  | `WispArt` | 0.17 ms a wisp (2.2 ms for 13) | where wisps are in view |
  | `ThornsArt` | 0.24 ms a run (2.1 ms for 9) | the cemetery |
  | `WatcherArt` | 0.2 ms each | every band |
  | `RisoBackground`, `RisoPrompt`, `RisoDecor` | 0.25–0.45 ms each | every level |

- Arriving at a level, on the main thread (`tests/bench_load.gd`): building its nodes 160–190 ms
  in the cemetery and crags, the print rebuilding for it (`world_built`: terrain, decor, light)
  140–210 ms, freeing the last level 40–60 ms, and then the **first frame, 450–550 ms**, nearly all
  of it the first draws of the terrain and decor queued before it. So a door costs the player close
  to a second of frozen frame there, whether or not the level was prefetched.

### Where the suite's time goes

The suite run once in a scratch copy with `LevelGen.new` timed (on the main thread and the
loader's worker apart), 8 at a time with a 300 s limit so nothing timed out: all 109 passed in
469 s, 3,169 test-seconds.

- **28 % of all test time is laying out levels on the main thread** (1,088 layouts, 892 s), nearly
  all of it `build(at)` in the tests. It is concentrated in the slowest tests, which make the
  run's tail:

  | Test | Time | Layouts | Laying out | Share |
  | --- | --- | --- | --- | --- |
  | `temple_test` | 166 s | 69 | 145 s | 87 % |
  | `crossbow_test` | 127 s | 84 | 96 s | 76 % |
  | `towers_test` | 87 s | 67 | 66 s | 76 % |
  | `sigils_test` | 75 s | 33 | 60 s | 80 % |
  | `darkness_test` | 79 s | 33 | 53 s | 68 % |
  | `balloon_test` | 76 s | 18 | 46 s | 62 % |
  | `relics_needed_test` | 55 s | 45 | 40 s | 74 % |
  | `difficulty_test` | 72 s | 36 | 39 s | 56 % |
  | `bands_test` | 51 s | 37 | 35 s | 70 % |
  | `layout_fingerprint_test` | 33 s | 26 | 22 s | 66 % |

- The loader's worker laid out another 704 levels (271 s of a core) in the 95 tests that boot the
  game, 7.4 a test on average: the place travelled to, and its neighbours, prefetched and mostly
  never visited.
- The other two thirds is the game running: booting, building levels in the scene, and frames
  (6–15 ms each headless, with all the art still printing).

## The plan

Four phases. Each step says what it is, why, how it keeps to composition and DRY, and how it is
checked. Phase 1 is cheap and touches only the tests and the runner; phase 2 is the big win for
both the game and the tests, and must leave every layout as it is; phase 3 is the game's frames and
hitches; phase 4 is structure.

The rule for everything in phases 1 to 3: `layout_fingerprint_test` must pass **without**
`-- update`. A step that changes a fingerprint is wrong and is undone, not re-fingerprinted.

### Phase 1: the runner and the kit

**1.1 Longest first.** `run.sh` starts tests in alphabetical order, so a 120 s test that starts
last stretches the tail. Keep each test's last duration (the runner already writes
`<name>.result` with its seconds; copy them to a `durations` file beside the logs, kept between
runs) and start the slowest first, new tests first of all. The classic longest-processing-time
order brings the wall time close to the total divided by the jobs.

**1.2 Fix the tiers.** Tag the tests that sweep many worlds `## suite: full` once phase 2 has
shrunk them, so `bash tests/run.sh` is a real quick check again, and correct the comment in
`run.sh`. Agree with the owner which tests are the quick check (suggestion: everything under 15 s
after phase 2, plus `layout_fingerprint_test` and `unit_test`).

*Built:* `run.sh` keeps `durations` (a file a band layout) in `/tmp/thejam3-tests/`, starts the
headless tests slowest first (a test never timed first of all) and names the slowest five in its
summary.

**1.3 One way to jump to a place: `TestKit.go(at, freeze)`.** Fourteen tests carry the same private
`_go(at)` (coord, arrival, `_load_level()`, `settle()`, and in ten of them
`player.set_physics_process(false)`), and 48 tests call the private `MapInfo._load_level()` 60
times between them. Add a public `MapInfo.jump_to(at, arrival)` (what `_load_level` does, under a
name the tests may call) and `TestKit.go(at, freeze = true)` over it; delete the copies. Tests then
depend on one entry point, which phase 1.4 can change for all of them at once.

*Built:* `MapInfo.jump_to(at, arrival = Exit.BACK)` (travel and respawns end there too) and
`TestKit.go(at, freeze = true)`. The fourteen copies are gone (five captures keep a `_go` of their
own over `go`, as they also stop the camera or wait), and no test calls `_load_level` any more.
`deeper_test`'s own `go(exit)` became `through(exit)`.

**1.4 No prefetching in tests unless asked for.** Give `LevelLoader` a `prefetching` switch (on in
the game) and have `TestKit.boot` turn it off. The few tests of the cache and the worker (`revisit_test`, the gen lab's round trip) turn it back on. This frees a core per running
test and removes the wait behind an unwanted neighbour (1.6 fixes that wait in the game too).

*Built:* the static `LevelLoader.prefetching`, turned off as the kit starts (`TestKit._initialize`,
so a test may turn it on again before `boot`). `revisit_test` checks it off, then on (every
neighbour laid out); `interface_test`, which checks the background pre-generation, turns it on.

**1.5 Run headless tests at a fixed step.** Pass `--fixed-fps 60` to headless runs in `run.sh`,
so a test's game runs as fast as the machine allows rather than at most in real time. First move
game logic off the wall clock (3.4), or a hit-stop or a lodestone would read differently. `until`'s
wall-clock timeout stays as it is (it guards against hangs); `within` already counts game time.

**1.6 Find levels by the rules first.** Twenty-odd tests sweep worlds and rows, building every
level, to find one that holds something: `temple_test` builds all 56 sky levels of four worlds
(about 95 s) for a few temples, though whether a level gets a temple is decided by one hash of its
seed before any searching (`build_temples`' first line). Two parts:

- Expose such decisions as rules, beside the others in `Rules` or on the archetype
  (`SkyArchetype.temple_dealt(seed)` and the like), and have the pass call the same function, so the
  rule lives in one place. The world atlas already reads the run from the rules alone in the same
  way.
- `TestKit.find_level(kind, holds, dealt = null, worlds = START_SEEDS)`: the first place in the
  band `kind`, over `worlds` and its rows, whose seed passes `dealt` (cheap, no build) and whose
  layout passes `holds`. It replaces the hand-written sweeps (`crossbow_test`, `temple_test`,
  `towers_test`, `tower_pieces_test`, `students_test`, `ladder_test`, `secrets_test`,
  `master_relic_test`, `balloon_test`, `lode_hall_test`, `garden_growth_test`, `wizard_carry_test`,
  `room_test`, `crypt_test`, ...).

**1.7 One determinism check, not twenty-three.** Twenty-three tests build a level a second time to
check it comes out the same (`again = build(at)`), each comparing a few fields of its own. That
doubles their generation time, and each checks less than it could. Replace them with one
`determinism_test` that builds a broad sample (every band, several worlds, side worlds, both
presets) twice and compares every property of the two `LevelGen`s (walking `get_property_list()`,
so a new field is covered without anyone remembering to). `revisit_test` keeps checking that a
level loaded twice in the scene is the same. **This changes a convention written in AGENTS.md
("tests compare two builds"), so it needs the owner's agreement**; the AGENTS.md line changes with
it.

**1.8 Build a place once per test.** Many tests call `build(at)` on the same place more than once for
different checks. `TestKit.built(at)` keeps the layouts it has made for the length of the test (a
level is read-only once built, as `LevelLoader` already relies on); `build(at)` stays for a fresh
one. With 1.7, nothing in a test needs a second build of the same place.

**1.9 Split the longest tests.** After phases 1 and 2, a test still over a minute is split along its
seams (`crossbow_test`'s sweep of the band's layouts and its play in one level are two tests), so
the parts run side by side.

Expected: the ten tests in the table above lose most of their layouts to 1.6 to 1.8 (temple_test
needs a handful of sky levels, not 69), the tail goes with 1.1, and 1.4 frees a core per booting
test. Together, before phase 2, roughly a third off the wall time; with phase 2 making a layout
about three times faster, the 28 % spent laying out falls under 10 %, and 1.5 and 3.6 then work on
the two thirds spent running the game.

### Phase 2: lay levels out faster (the game and the tests)

Target: a sky level under 0.6 s and a cemetery level under 0.4 s, from 1.7 s and 0.95 s. Every step
leaves the layouts exactly as they are: the same cells, the same draws from the world RNG in the
same order, and the same ties broken the same way.

**2.1 One shared grid of what each cell is.** Today a cell is a `Cell` object in an array of arrays,
and asking whether a cell is rock is two array look-ups and an object read. Several passes then
build their own flat copies to search quickly (`Chasms.carve`'s `floors`, `_isle_map`, `_held_up`).
Add one `PackedByteArray` of cell types to `LevelGen`, kept in step by `set_cell`, with `is_ground`,
`_open` and `get_cell(v).type == ...` reading it. First, route every write through `set_cell` (eight
places assign `cells[v.x][v.y]` directly, `_to_rock` and `_to_open` among them), so the copy can
never fall out of step. The passes' private copies then go.

**2.2 One `CellSums` for counting in boxes.** The crypts' running sums (`Crypts._sums`, `_count`)
are borrowed, private as they are, by `Institute._site`. Lift them into a small class of their own
(`scripts/level/CellSums.gd`): built from the grid in 2.1 (a packed array per kind, not a `Callable`
called for each cell), answering "how many cells of this kind in this box" in four look-ups. Use it
for every box test: the temples' site (378 ms of a sky level, a box tested cell by cell at every
cell), the chasm shores, the vault and secret room spots, the crags' towers and keeps, the bramble's
shaft. A pass that changes the cells rebuilds the sums once after it, not once per candidate.

**2.3 One site search.** `Crypts._site` and `Institute._site` are the same search (every box
position; skip those that touch what is blocked; score by open cells and passage length; break
ties by a hash of the seed and position), written twice. Make it one function taking the box size,
the blocked set, the doors finder and the tie salt, used by both, and by the temples and towers
where they fit. A box's footing ("how far down to rock under each column", `_temple_site`) is a
column table worked out once per pass.

**2.4 `connect_caves` without rescanning.** It recounts every open cell on every pass of its loop
(`_open_count`), and runs up to three times a level (after `shape`, and again in the crags' and
sky's `cut_gates`). Keep the count as it carves (each carve adds one open cell; each region taken in
adds its size). The breadth-first search and its order stay as they are, so the tunnels are the
same.

**2.5 Small, safe fixes in the helpers.** `pop_if_random_empty` makes a new `Callable` for every
draw (`f.bind(v).call()`, up to 200 draws when forced): call `f.call(v)`. Hoist `free_floors()` out
of the per-lift loop in `place_lift_switches`. `_crowds_exit` builds `exits.values()` on every call:
keep the exits' cells in an array. `_holds_up` builds small arrays per call (`[Type.DOOR, ...]`):
make them constants.

**2.6 Then measure again and take the next pass.** After 2.1 to 2.5, run the per-pass timing again
(`bench_gen`, extended as in 4.6) and work down the list:
`place_vaults`, `place_secrets`, `SkyArchetype.shape`, `place_switch_gates`, `place_moons`,
`place_cluster`, `Chasms.place_bells`.

**2.7 Last, and only if still needed: the lists of cells.** `empties`, `grounds` and `objects` are
arrays searched linearly, 2–4 % of a level now and a larger share once the rest is fast. The order
of `empties` must be kept exactly, so the replacement keeps an array for its order and a dictionary
from cell to index beside it, removing lazily (marking, compacting before the next draw). Do it only
if the timings after 2.6 call for it.

Check for each step: `layout_fingerprint_test` without `-- update`, `revisit_test`,
`determinism_test` (1.7), and the band tests.

### Phase 3: the game's frames and hitches

**3.1 The arrival's first frame.** The biggest hitch in the game: 450–550 ms of first draws of the
terrain and decor when a cemetery or crags level arrives (`bench_load`), on top of 300–400 ms of
building and rebuilding the print. Draw the terrain and decor by chunk, nearest the way in first,
spread over the frames of the arrival's fade (the chunks `LevelLoader` already keeps are the
natural unit), or prepare them on the worker beside the layout where they need no scene. Check
with `bench_load` (target: no arrival frame over 100 ms) and the captures, as it is art.

**3.1a The steady frame.** Work down `bench_frame`'s table on an idle machine: `RisoWizard`
(1.1–1.5 ms in every level, the largest fixed cost), `RisoLight` (up to 2.3 ms), then the kinds
that cost per thing in view (`WispArt`, `ThornsArt`, `WatcherArt`). Several kinds already print
through a rig (`InkCanvas.rig`, `bench_rig`); `bench_crowd` says which others are worth one. Use the
benches already in `tests/` (`bench_frame`, `bench_walk`, `bench_profile` with `-d` for the script
profiler, `bench_chunks`, `bench_big_level`) rather than writing new probes.

**3.2 The wanted place goes first.** The loader runs one job at a time, so a wanted place waits
behind a neighbour being prefetched. Give the wanted place its own worker (or use
`WorkerThreadPool` with two jobs), so a rift, a respawn or a jump is laid out at once; prefetching
carries on beside it.

**3.3 The map never lays out on the main thread.** `LevelLoader.world_at` builds a level in the
frame when the map asks for one not yet laid out. Queue it to the worker instead and let the map
draw that place when it arrives (it already copes with `null` while the worker is busy).

**3.4 One clock for the game.** Game logic that reads `Time.get_ticks_*` (`Lodestone`,
`Parry.parried_real`, `Player.hit_at`, `SeedPod`) moves to the game's own time, from one small
`GameClock` (game seconds, counted from physics frames, and real seconds where real time is meant:
the hit-stop, which freezes the game's time). Art that flashes may stay on real time; say so where
it does. This makes the game behave the same under load and makes 1.5 safe.

**3.5 Building a level in the scene.** After 3.1, the next share of an arrival is building its
nodes (160–190 ms, `bench_load`'s "build") and freeing the last level's (40–60 ms). Place things
nearest the way in first and the rest over the next frames behind the arrival's fade; make an art
node only when its chunk first wakes (`LevelLoader` already sleeps and wakes things by chunk); or
keep the commonest prefabs (cracked rock, stars, ledges) in a pool. `bench_load` says which.

**3.6 Art that does nothing headless.** In a headless run, nothing an art node prints is seen, yet
every `RisoProp` still processes and prints. Have `RisoProp` and `RisoLight` stop printing headless
unless a test asks for it (`TestKit.art(true)`), through one switch on `RisoPrint` rather than a
test of the display in every script. The art tests (`riso_print_test`, `ink_test`, the captures)
turn it on.

### Phase 4: structure (DRY and composition)

These change no behaviour. Do them where they meet the work above, not as a sweep of their own.

**4.1 A boss's death, once.** Beast, Necromancer, Golem, Bramble, Worm and Whale each write their
own death: a once-only guard (`dying_t`, `slain`, `dead_t`), leaving the `hex_target` group,
shaking the screen, a burst of ink, telling `MapInfo.boss_slain` with the cell its relic falls in.
Make it a component, `BossDeath` (a child node, as `Stunner` and `Wound` are), that a boss holds and
calls; each boss keeps only what is its own (the necromancer's skeletons falling back, the beast's
slam and sweep stopping).

**4.2 Wounds that ask the stunner.** Three `Wound` subclasses (`BeastWound`, `GolemWound`,
`NecromancerWound`) repeat the same `stunned()` (ask `Stunner.of(get_parent())`), while `Wound`
itself asks the host's `HitBox`. Let `Wound.stunned()` ask the host's `Stunner` when it has one and
its `HitBox` otherwise, and drop the three copies; the bramble's, never stunned, keeps its override.

**4.3 `LevelGen` holds the level, its passes live apart.** At 1,933 lines, `LevelGen` is both the
grid with its placement helpers and a dozen passes (secret rooms, vaults, cracks, portals, moons,
switch gates, the shrine, lift switches). The chasms, crypts and institute already live in their own
scripts, called with the level. Move the rest out the same way (`Secrets.gd`, `Vaults.gd`, and so
on), keeping the order of calls in `populate_level` exactly, so the layouts do not change. Do it
with phase 2, pass by pass, so each pass's speed-up lands in its own file.

**4.4 `MapInfo` in parts.** At 2,216 lines it is the place, travel, the record's meaning in the
scene, the timetable's watching, the secrets, the bosses' relics and more. Split along the seams it
already has (a `Travel` part, a `RecordInScene` part), each a plain object `MapInfo` holds, as it
holds `run` and `loader`. Lower priority than the rest; worth it when a change touches it anyway.

**4.5 The tests' own helpers in the kit.** Beside 1.3 and 1.6: holding an action for some frames
(`bridge_walk_test.walk`, `_press` in five tests, `press` in another), freezing the wizard
(`player.set_physics_process(false)`, in 81 tests), and full health for a fight (`max_health = 99`).
One helper each in `TestKit`, and the copies go.

**4.6 The benches, extended and written down.** `tests/` already holds a dozen benches
(`bench_gen`, `bench_load`, `bench_frame`, `bench_walk`, `bench_profile`, `bench_chunks`,
`bench_crowd`, `bench_rig`, `bench_print`, `bench_gpu`, `bench_big_level`), but AGENTS.md does not
mention them, which is how this analysis nearly wrote its own. List them there in a line each.
Extend `bench_gen` to time each pass of a level's dressing (the table above), through a small hook
on `LevelGen` that is empty in the game (a `Callable` the bench sets, called between the passes of
`populate_level`), rather than a copy of the passes. Add a `bench_suite` mode to `run.sh` (or a
line in its summary) that prints the slowest tests and the share of the run spent laying out levels
(the tally below), so the suite's cost stays visible.

## Order of work

1. Phase 1.1 and 1.3 to 1.4 (an afternoon; no layouts touched). Measure the suite again.
   *Done, 10 November 2026.* Measured in a Linux container (4 cores, Godot 4.7.2 for Linux, the
   extension built there with GCC; its levels differ from the MSVC build's, so
   `layout_fingerprint_test` and `decor_test` failed there before and after alike), the quick run
   before and after, 4 tests at a time: 436 s → 410 s of wall time, 1,620 → 1,565 test-seconds,
   the same 107 of 109 passing. At 2 at a time, where each test's worker had a spare core, the
   test-seconds did not change (1,583 → 1,581): the saving from 1.4 shows only on a loaded machine,
   as the owner's 8 at a time is. With 4 jobs the run already ends within 5 % of its test-seconds
   divided by the jobs, so 1.1 matters most where the tail is long (8 jobs, a 120 s test). Still to
   measure on the owner's machine.
2. Phase 2.1 to 2.5, with 4.3 for each pass touched, then 2.6. Measure the levels again.
3. Phase 1.6 to 1.8 (with the owner's word on 1.7), then 1.2 and 1.9.
4. Phase 3.4, then 1.5.
5. Phase 3.1 (the arrival's first frame), then 3.2, 3.3, 3.5, 3.1a and 3.6 as the benches say.
6. Phase 4.1, 4.2 and 4.5 alongside, 4.4 when convenient.

## Decisions for the owner

- **1.7**: one determinism test in place of the twenty-three second builds (changes an AGENTS.md
  convention).
- **1.2**: which tests make up the quick check.
- **1.5**: headless tests run at a fixed step rather than in real time.
- **2.7**: only if phase 2 falls short, and still without changing a layout. If a faster layout
  that *does* change the levels is ever wanted, it is a separate decision, with new fingerprints.
