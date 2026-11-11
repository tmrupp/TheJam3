# Somnonaut: the code and architecture review (November 2026)

A review of the project as it stood on 10 November 2026 (branch `game/deeper`, commit `3d4c296`),
made on Windows with Godot 4.7.2. It has two parts: the state of the tree (what is broken or
fragile now) and its structure (what makes such things likely). Each finding says what was seen
and how it was checked (*Seen*), why it happens (*Cause*) and which way a fix lies (*Direction*).
Nothing here is built, and nothing in the repository was changed to find it: the probes were
throwaway scripts kept outside it, and section 6 says how to make each check again. The design
review is another document, `docs/REVIEW_PLAN.md`.

Line numbers are those of the commit above and will drift; each is given with the function it is
in.

How sure each finding is:

- **run**: seen happening, in the game or in a probe that ran it.
- **measured**: counted or timed, over the code or over many levels.
- **read**: read from the code, not run.

| # | Finding | Kind | How sure |
|---|---|---|---|
| 1.1 | Every shot is made without its hit box when the game starts normally | a bug in play now | run |
| 1.2 | Four tests fail and one is flaky | tests | run |
| 1.3 | Relic barriers build into cells other things use | a bug in the generator | measured |
| 1.4 | Things are dealt into a barrier's pocket | a bug, rare | measured, read |
| 1.5 | A lethal hit while travelling is swallowed | a bug | run |
| 1.6 | Every autosave rewrites the kept map | a cost | measured |
| 1.7 | Neither save file is written safely | a risk | read |
| 1.8 | A shrine's refresh price can jump, or buy nothing | a bug | read |
| 1.9 | Smaller things | mixed | read |
| 2.1 | The code is one knot, and load order decides whether scenes load whole | structure | measured, run |
| 2.2 | A band is spread over four hubs | structure | measured |
| 2.3 | The generator has no single answer to "is this cell spoken for" | structure | measured, read |
| 2.4 | Determinism holds for a build, not for a world | structure | read |
| 2.5 | Saving, and what a layout depends on | structure | read |
| 2.6 | The tests cannot see the order the game loads in | structure | run |
| 2.7 | Smaller notes on structure | structure | read |

## 1. The state of the tree

### 1.1 Every shot is made without its hit box when the game starts normally (run)

*Seen:* starting the game prints this before anything else
(`godot --headless --path . --quit-after 90`):

```
ERROR: res://prefabs/bullet.tscn:14 - Parse Error: [ext_resource] referenced non-existent
resource at: res://prefabs/hit_box.tscn.
```

`hit_box.tscn` is there. With the main scene loaded first, as the game loads it, the scene every
shot is made from has three nodes and no `HitBox`. That is so of each script holding it: a
watcher's `projectile_prefab` (`shooter.gd`), `SeedPod.SHOT`, `Crossbow.ARROW` and
`BrambleBulb.SEED`. A fresh `load` of `bullet.tscn` hands back the same kept scene, so a
scholar's shot, loaded by its path, is the same. A shot made so and put in the level throws
`Cannot call method 'connect' on a null value` in `Bullet._ready` (`scripts/bullet.gd:56`).

By the code, then, a shot can neither hurt the wizard nor be parried. The tutorial's watcher that
only a parry beats, the seed pods (wounded only by their own seed turned back) and the bramble's
bulbs all lean on a shot that can be caught. This was seen in the game booted headless and in a
probe; it was not played in a window.

*Cause:* a cycle of loads. `hit_box.tscn` holds a `Damager`, whose script names `Player`, which
names `MapInfo`, which reads `SeedPod.SHOVE_ARC` and `SeedPod.SHOVE_TIME`
(`MapInfo._spawn_dropped_key`, `scripts/MapInfo.gd:262`). To give its constants, `SeedPod.gd` must
`preload` `bullet.tscn` (`scripts/SeedPod.gd:13`), which holds a `hit_box.tscn`, still being
loaded. The loader hands back nothing for it, and `bullet.tscn` is kept without it for the rest
of the game. `MapInfo`'s reads of `SeedPod` came with commit `b660834` (9 November 2026). It was
not bisected.

*Why nothing caught it:* `TestKit` names `MapInfo` and `Player` in its own fields, so in a test
the scripts load in another order, in which the cycle closes without harm. Only `gate_test`
happens to trip it (1.2). No test starts the game the way the game starts (2.6).

*Direction:* `SeedPod` loads its shot by its path the first time it spits, as `Scholar` holds its
shot as a path (`Scholar.SHOT`), or the two fling numbers move out of `SeedPod`. Either mends
this one. Section 2.1 is about the kind.

### 1.2 Four tests fail and one is flaky (run)

`bash tests/run.sh full` on the commit above: 114 of 118 passed in 415 s. The three that are not
the fingerprints fail again when run alone.

| Test | Why it fails | What it is |
|---|---|---|
| `gate_test` | The cycle of 1.1: the runner stops a test whose log holds a parse error | A real bug |
| `garden_growth_test` | In (99, −6) a relic barrier carved away the wall a spare seed pod, at (13, 32), grows from | A real bug (1.3) |
| `beast_test` | Its soul in (29, 2) now lies on a floor with no free floor near it for its guards, since that level took a barrier | The test trusts one level |
| `layout_fingerprint_test` | The dressing of the garden above, (7, −2) and (28, −3), changed | The fingerprints were never written again after the pods' rise (`docs/REVIEW_PLAN.md` §2 leaves it to the owner) |
| `interface_test` | An index out of bounds at `interface_test.gd:75` beside the others; it passes alone | Flaky |

Of the fingerprints: the terrain of every place matches, and every other place's dressing
matches, so `layout_fingerprint_test -- update` writes only what was meant. It is better run
after 1.3 is mended, as that will move the garden's levels once more.

*Direction for `beast_test`:* look over a few worlds for a level whose soul has room for guards
(as `AGENTS.md` asks of tests), or let it pass a soul that has none: a soul alone on a ledge is
a fair thing for the game to deal.

### 1.3 Relic barriers build into cells other things use (measured)

*Seen:* over 480 garden levels (worlds 1 to 40, every row but the start and the gates), 72 took
a barrier, and in 8 of those it built into a cell something else was using:

| Level | Barrier | What it left |
|---|---|---|
| (8, −6) | blink | Rock in two cells of the way of the lift at (36, 40) |
| (24, 1) | double jump | Rock and thorns in the way of the lift at (14, 13) |
| (31, 3) | blink | Rock in the cell over the ink well at (21, 18) |
| (32, 1) | blink | Its mark in the second cell of the shrine at (26, 25) |
| (13, −6), (32, 5), (38, −4) | blink | Its mark on a lift's track |
| (40, −6) | double jump | Its mark on a lift's track |

And in (99, −6) it carved open the rock beside a spare seed pod, which then hangs on no wall
(`garden_growth_test`, 1.2).

*Cause:* `Barriers._solid` (`scripts/level/Barriers.gd:245`) takes a cell as free when it is rock,
or air whose own type is `EMPTY`, and it is not `kept`, a secret room's step or a way out. But a
cell can be in use while its type is `EMPTY`:

- the cells a lift's body and track sweep (`LevelGen.make_moving` only takes them out of
  `empties`);
- the second and upper cells of a thing more than a cell big (`Placeables.size`, carved open by
  `make_room`): a shrine, a lantern, a way out, an ink well;
- rock that something leans on: the wall a seed pod grows from.

`_mouths` picks the floor its mark stands on the same way.

*Direction:* at the least, ask `empties` (the generator's own list of free cells) of any air it
builds on, keep out of every placed thing's box, and leave the rock beside a thing set in a wall.
The lasting fix is one map of what each cell is spoken for (2.3). The class's header still says a
barrier is laid "only into solid rock", which is no longer so: `_solid` and `_carve` build its
walls of rock where they meet air.

### 1.4 Things are dealt into a barrier's pocket (measured, read)

A barrier's pocket is open floor like any other to whatever picks a floor once the level is laid
out.

- **A sold skeleton key (read).** `MapInfo.lay_sold_skeleton` (`scripts/MapInfo.gd:154`) deals a
  floor among `free_floors()`, leaving out the vaults only. So a key bought for twice the way
  on's price and a carried key can lie behind a barrier that asks for a move the wizard lacks.
- **A soul of the beast (measured).** `BeastSouls.spot` deals among `free_floors()` too. Over the
  52 garden levels with a barrier in worlds 1 to 30, with a soul dealt for each of 40 run seeds,
  70 of 2,080 lay inside the barrier's pocket. While any soul lives, a strike glances off the
  beast.

*Direction:* one helper for "the floors of the level proper", leaving out the vaults and the
barriers' pockets (`LevelGen.barriers` keeps their cells), used by everything that deals a spot
after the level is laid out.

### 1.5 A lethal hit while travelling is swallowed (run)

*Seen:* a wizard past the grace of arriving sets off by `MapInfo.balloon_travel` (the same
`_pass` and `_arrive` every way out uses) and, while the transition sweeps, takes a hit worth
all their hearts. After it: no hearts, no ghost, no lantern burned, the run not ending. They
arrive in the next level alive with no hearts, free to move. The death's sound and the `died`
signal fire all the same (`Player.die`). The next hit kills them as usual.

*Cause:* `MapInfo.player_died` returns at once `if run_ending > 0.0 or travelling`
(`scripts/MapInfo.gd:2008`), and `Health.modify_health` asks whether the wizard is dead only as
the hit lands. The wizard's physics is off from `_pass` on, but their body is still there for a
shot in flight or a lurching wisp.

*Direction:* make the wizard untouchable from `_pass` until `_arrived` gives them their grace
(the simpler way, and what arriving gives already), or keep a death met on the way and play it
out on arriving.

### 1.6 Every autosave rewrites the kept map (measured)

*Seen:* one `MapInfo.save_run`, timed headless on this machine, three runs:

| The run | One autosave |
|---|---|
| 2 levels on record | about 2 ms |
| 12 levels | 11 to 12 ms |
| 32 levels | 15 to 18 ms |
| 62 levels | 41 to 43 ms |

A frame is 16.7 ms. The work in script is small (`Known.merged` 0.06 ms a level, `Known.stamp`
0.7 ms); the two file writes are the cost, and they are uneven here (a kept map of 84 KB took
27 ms to write in one sample, one of 410 KB under 10). Read the table as the size of the cost,
not as a curve.

*Cause:* `save_run` (`scripts/MapInfo.gd:2116`) writes the run's save, then calls `Known.note`,
which goes over every record of the run and writes the whole kept map. `save_run` is called from
63 places: each star cluster taken (`scripts/Coin.gd:18`), each key, bell, switch and the like.

*Direction:* note the kept map on arriving in a level and as the run ends or is won, not with
every save. For the saves themselves, see 2.5.

### 1.7 Neither save file is written safely (read)

`RunState.write_save` (`scripts/level/RunState.gd:301`) and `Known._write`
(`scripts/level/Known.gd:42`) open the file itself for writing. A crash or a power cut during a
write leaves it cut short. `get_var` then gives nothing, which is read as no save (`read_save`)
or as an empty kept map (`kept`), and the next write goes over it. The kept map is what the game
carries from run to run. With saves as frequent as 1.6 says, the moment is not a rare one.

*Direction:* write to a file beside it and rename it over the old one, keeping the last good
file until the new one is whole.

### 1.8 A shrine's refresh price can jump, or buy nothing (read)

`Shrine.redraw_price` is `REDRAW_PRICE` times the way on, times two to the power of
`LevelRecord.redraws` (`scripts/Shrine.gd:98`). But `buy_redraw` (`scripts/Shrine.gd:113`) adds
one to `redraws` for every count it tries, up to `REDRAW_TRIES` (6), passing over a count that
deals the pair just shown. So:

- each count passed over doubles the next price again: a refresh that passed over one costs four
  times as much next time, not twice;
- when no other pair can be dealt (few abilities left to offer), all six counts are passed over:
  the stars and the key are taken, the same pair is shown, and the next refresh costs 64 times
  as much.

The same pair comes up easily: `Abilities._picks` (`scripts/Abilities.gd:205`) walks the
abilities from `level_seed % n`, new ones first, so two seeds that start near each other deal
the same two.

*Direction:* keep how many refreshes were bought apart from the count the boons are dealt by,
and sell no refresh where no other pair can be dealt.

### 1.9 Smaller things (read)

- **A preset changed while a worker lays a level out.** `LevelLoader._generated` keeps the level
  under `_world_key(at)` as it is when the worker finishes (`scripts/level/LevelLoader.gd:165`,
  `:204`), so a level laid out under the old preset (or debug flag) is kept as the new one's.
  `_cache_put` also drops only the key of the preset in play, so layouts kept under another
  preset are never dropped. Developer's tools only (the F7 panel).
- **The F7 panel's preset row.** It sets `Difficulty.preset` and then calls
  `MapInfo.lay_out_again`, which does nothing while travelling: the preset has changed and the
  place has not.
- **`Player.gd`.** `show_hurt` and `show_invulnerable` flicker a sprite the print took the place
  of (`RisoCostume.gd:317` asks `is_invulnerable` itself), on scene-tree timers. Two old TODOs
  stand at lines 281 and 286, and its comments are not yet the `##` kind.
- **Hashes of the engine's own.** `Bosses.column` salts with `String(name).hash()`
  (`scripts/bosses/Bosses.gd:57`) and `Known.stamp` uses `hash()`, where `Rules.level_seed` was
  made not to lean on the engine's hashing. A change in either would move the bosses' columns,
  or drop the kept maps.
- **The kept map's seeds.** `Known.note` keeps an entry for every run seed played, empty ones
  too (`scripts/level/Known.gd:164`), with no bound. Each is a few bytes.
- **`Barriers._solid`** asks `w.exits.values()` afresh for every cell of every shape it tries.
- **`AGENTS.md`.** It calls `docs/PLAYTEST_PLAN.md` "a plan, not yet built", though all fifteen
  of its items are marked done. It lists neither `docs/REVIEW_PLAN.md`, `Known.gd` nor
  `Barriers.gd`. The Godot path it gives (`C:\tools\godot-win\...`) is not on this machine.
- **The task list.** "Teleporter invuln doesn't seem to work" is built by
  `docs/PLAYTEST_PLAN.md` 5a (`portal.gd` gives the grace at the far end). It was not played.
- **The repository.** Twelve `claude/*` worktrees stand under `.claude/worktrees`, their
  branches all merged into `game/deeper`. `project.godot` has an uncommitted change that only
  moves the `config/icon` line.

## 2. The structure

### 2.1 The code is one knot, and load order decides whether scenes load whole (measured, run)

*Seen, the knot:* take every script in `scripts/` and `tools/` as a point (299 of them), and
draw a line from one to another where its code, comments left out, names the other's class. Then
186 of the 299, holding 51,706 of 64,177 lines, are one cycle: each can be reached from each.
There is no other cycle; the rest hang off this one.

| Class | Named by | Names |
|---|---|---|
| `RisoPrint` | 157 | 40 |
| `MapInfo` | 147 | 61 |
| `Player` | 112 | 24 |
| `Stage` | 78 | few |
| `LevelGen` | 60 | 19 |
| `Rules` | 47 | few |

*Seen, what it costs:* each of 329 scenes and scripts (every prefab, the main scene, the two
tools' scenes, and the scripts of `scripts/`, `bosses/`, `level/`, `worlds/` and `riso/`) was
loaded first in a process of its own. 254 of them left some scene loaded without a part of
itself.

| Scene left broken | How many first loads break it | An example of what it lacks |
|---|---|---|
| `bullet.tscn` | 249 | its `hit_box.tscn` |
| `portal.tscn` | 7 | its `interactable.tscn` |
| `player.tscn` | 5 | `Player.gd`, `Health.gd`, `parry.tscn`, one each |
| `gondola_station.tscn` | 2 | its `interactable.tscn` |
| `trophy.tscn`, `parry.tscn`, `interactable.tscn` | 1 each | its own script |
| `hit_box.tscn`, `damager.tscn`, `corpse.tscn` | 1 each | |

The main scene, the generation lab and the world atlas each break `bullet.tscn` (1.1). The
others are broken only by orders the game does not load in today. Any change that moves the
order (a new `preload`, a constant read from another class, a scene's resources listed
otherwise) can bring one of them in, `player.tscn` among them.

*Cause:* three habits, each small.

- **The scene-free layers read constants off the scene's hubs.** `scripts/level` and
  `scripts/worlds` (the loader aside) name `MapInfo` 135 times: 125 are the enum `MapInfo.Exit`
  and 7 are `MapInfo.debug`. `Difficulty.LAST_BEAT` is `Parry.WINDOW`; others read
  `KeyRing.SKELETON`, `Spikes.CYCLE`, `Snuffer.CHARGES`, `Temple.LENGTH`, `Shield.HP`,
  `Trophy.SET`. `Difficulty`'s own comment notes that `MapInfo` "may not be set up yet" when its
  preset is: the order has been felt before.
- **Gameplay names `RisoPrint` for eight numbers.** Of the 575 times the scripts of `scripts/`
  and `scripts/bosses/` name it, 548 are a plate (`RisoPrint.NIGHT`, `BLUE`, `PINK`, `ACCENT`,
  `EYE`, `GLOW`, `ROBE`, `CLOTH`).
- **Scripts in the knot `preload` scenes in the knot.** Thirty `preload`s of 13 prefab scenes:
  `hit_box.tscn` by ten of the bosses' scripts, `stunner.tscn` by six, `bullet.tscn` by four,
  `player.tscn` by the menu, and others.

*Direction:*

- `Exit` and `debug` move to a small class of their own with no scene in it, and the plates to
  another. `MapInfo.Exit` and `RisoPrint.NIGHT` can stay as other names for them, so the 247
  uses of `MapInfo.Exit` in the tests need not change.
- The rules read their numbers from rules: a constant a rule needs lives with the rules, and the
  scene script reads it from there, not the other way.
- Prefabs are loaded the first time they are wanted, through one keeper, as `Placeables.scene`
  already does for everything laid in a cell. No gameplay script `preload`s a scene.
- A rule in `unit_test`, beside the tables it checks already: no script of `scripts/level` or
  `scripts/worlds` (the loader aside) names a class that is a node.
- The checks of 2.6.

### 2.2 A band is spread over four hubs (measured)

*Seen:* `AGENTS.md` says a new band is one script extending `Archetype`. `Archetype` has eight
hooks (`patches`, `realm`, `shape`, `cut_gates`, `room`, `size_for`, `populate`, `finish`), all
of them for how a level is laid out and looks. What a band does in play, and what it remembers,
is in four classes every band shares:

| Hub | What is one band's or one boss's |
|---|---|
| `MapInfo` | About 1,250 of its 2,270 lines, 102 of its 183 functions (sorted by their names, roughly): the institute about 680, the bosses 210, the cemetery 110, the sky 110, the garden 85, the crags 70 |
| `LevelGen` | About 20 of its 56 fields (`crypts`, `halls`, `belfry`, `towers`, `temples`, `circuit`, `tiers`, `shaft`, `keep`, `isles`, `lanes` and others), and 78 kinds of cell |
| `LevelRecord` | 20 of its 43 fields: the institute's 12, the sky's 4, the crags' 2, the cemetery's 2 |
| `RunState` | 10 of its 34 fields (`whale_x`, `souls`, `fed`, `papers_out`, `tempered`, `lodestones`, `plants` and others) |

Few places ask a band by its name (five outside the archetypes). The spread is not in checks: it
is in the hubs carrying each band's verbs (`pull_cord`, `switch_vane`, `douse_font`,
`flip_tower`), each called from one or two prefabs.

*What it costs:* every band's next pass edits the same four files, with several sessions in the
tree at once, and `MapInfo` comes to name 61 classes. The task list says to work band by band;
the code does not yet let a band be worked on alone.

*Direction:* the precedents are in the tree. `Timetable`, `BeastSouls`, `WhaleHunt` and
`Stations` hold a band's rules as scene-free functions over the record, and `MapInfo` plays them
out. Carry it through:

- a band's play as an object of its own, got from its archetype, that `MapInfo` hands the moments
  to (arriving, a step of time, leaving) and that prefabs of the band call;
- a band's own part of the record and of the run, kept by the band (a typed record of its own,
  saved under its name), in place of fields on the shared ones.

The institute is the place to begin: it is the largest, and its simplifying is already put off
until after the demo (`docs/REVIEW_PLAN.md` §10), so moving it disturbs nothing being tuned.

### 2.3 The generator has no single answer to "is this cell spoken for" (measured, read)

*Seen:* what a cell holds is its `type`. What a cell is kept for is said in about ten other
places, each known to the passes that made it: `empties` (the free list), `keep_clear`,
`kept_whole`, `structures`, `lanes`, `secret_steps`, `vault_walls`, `masonry` and `interiors`,
the boxes `make_room` carves, a lift's track. A pass that comes late must know them all. The
barriers (the newest pass) knew three and missed the rest: that is 1.3 and 1.4.

*Direction:* the crags have the start of it: `LevelGen.structures` is "the cells an archetype's
structure pass has spoken for, each with what holds it". Make that the one map for every pass:
each cell free, held (by what), kept clear, or rock that something stands on or grows from.
`put`, `make_moving` and `make_room` write it as they work, and a late pass asks one question.

Two more things of the same layer:

- **The structures are untyped.** Crypts, halls, towers, shafts, vaults, secrets and barriers are
  `Dictionary`s (`crypts[0]["floors"]`, `shaft["knot"]`, `shape["mouth"]`): 477 lookups by a
  string, over 143 different keys, 268 of them in `scripts/level` and `scripts/worlds`. A key
  mistyped fails as the level is laid out, in a codebase where a type mistyped fails as it is
  parsed. `LevelRecord` was made a typed class for this reason; the structures can follow, one
  at a time.
- **The collapse is a sprite.** `WaveFunctionCollapse` extends `Sprite2D`
  (`gdextension/src/wave_function_collapse.h:32`) and reads its sample from the sprite's texture
  (`get_texture()->get_image()`). That is why each worker thread keeps a copy of the node, why
  joining a worker must keep serving the renderer (`LevelLoader.Worker.join`), and why
  `TestKit._make_wfc` reads the node's settings out of the main scene. It hands back columns of
  colours with a dictionary of the patches added as the last element, which `LevelGen._init`
  tells apart by asking `_cells.back() is Dictionary`. A plain function from a picture and a
  seed to bytes would need none of it. It is the same rebuild as 2.4 asks for.

### 2.4 Determinism holds for a build, not for a world (read)

The game's first rule is that a level is the same on every visit. As built, that is true of one
build, in three ways.

- **By compiler.** The collapse weighs its cells with the maths library's `log`
  (`gdextension/src/wave.cpp:14`, `:47`, `:68`) and breaks ties with
  `std::uniform_real_distribution` (`wave.cpp:86`). Neither gives the same numbers from one
  compiler's library to another's. `AGENTS.md` says so of MinGW, and `docs/REVIEW_PLAN.md` §2
  records a Linux build laying out different terrain. What follows:
  - a session on Linux cannot run the fingerprints, nor any test that leans on a layout. That is
    how the fingerprints came to be left unwritten (1.2);
  - `docs/PAIRED_PLAN.md` rests on "either game can lay out any level of the partner's world".
    That holds between two builds by one compiler. Its build check would turn away a pair on
    Windows and Linux, rightly, and they could never play;
  - a world's number names different levels on different systems.
- **By order.** One stream of random numbers runs through every pass: about a hundred places
  draw from it (46 in `scripts/level`, 59 in the archetypes). A draw added, dropped or moved
  shifts everything after it, which is why new passes go last and why the fingerprints exist. A
  stream for each pass, seeded from the level's seed and a salt of the pass, would keep a change
  inside its pass: retuning one band's dressing would not move what is laid after it.
- **By salt.** What is dealt by hashing the seed is salted by 87 constants numbered by hand
  across the scripts. Sixteen numbers are used by two or more of them:

  | Salt | Used by |
  |---|---|
  | 6200 | `BOSS_SALE_DEAL`, `SOLD_KEY_DEAL`, `FONT_DEAL`, `MIND_DEAL`, `PATCH_DEAL` |
  | 6600 | `KEY_DEAL`, `PAPER_DEAL`, `PLACE_DEAL` |
  | 6100 | `COUNT_DEAL`, `HOLE_DEAL` (and the skeleton sale's bare 6100) |
  | 7300 | `MAZE_RUN_DEAL`, the barriers' `SHARE_DEAL` |
  | 7100 | `MAZE_SIDE_DEAL`, the worm sign's `PHASE_DEAL` |
  | 6400, 6410, 6420, 6430, 6490, 6500, 6620, 6650, 6800, 9300, 9400 | two each |

  Two rules that salt the same seed with the same number are not two deals but one: a shrine's
  boss sale and where its sold key lies come from one number. Some salts are also added to (a
  cell's `x * 977 + y`, a try's count), which walks them over their neighbours' numbers. No harm
  was found from any of these. The fix is cheap: one list of the salts, each given its number
  by its place in it, a hash that takes the seed, the salt and the cell apart (`RisoDecor.h`
  does), and a line in `unit_test` that no two are alike.

*Direction:* all three change every level once, and the fingerprints with them. Do them together
as one planned break, with the collapse of 2.3, and before the demo is out: after it, a world's
number is something players hold.

### 2.5 Saving, and what a layout depends on (read)

- **Sixty-three calls to save.** Whatever changes the record calls `save_run` itself, and each
  call writes the whole of both files (1.6). A change with no call beside it is not saved (a
  single star is not, by intent). One mark that the run has changed, and one place that writes
  it (as the frame ends, or a little after), would bound the cost, save everything alike and
  give one place to make the write safe (1.7).
- **A layout depends on more than its place.** It depends on the preset
  (`Difficulty.foes`), the debug flag and the doors the run has dug, which are static variables
  read as it is laid out, on a worker thread, while the game may change them
  (`NextWorldDef.dug` is the run's own dictionary). The key it is kept under is worked out as
  the worker finishes (1.9). Carrying these on the place's definition (it carries `debug`
  already), read once as the work is handed over, makes a layout a function of what it is given
  and its key something known at the start.

### 2.6 The tests cannot see the order the game loads in (run)

*Seen:* 101 of the 118 tests start the whole game through `TestKit.boot`. `TestKit` is a script
with fields of type `MapInfo` and `Player`, so those classes load before the main scene does,
and every test loads the game's scripts in the kit's order. The game's own order is never run.
That is how 1.1 came to pass every test but one.

*Direction:*

- **A boot check in `tests/run.sh`:** start the game itself for a few frames
  (`--headless --quit-after`), and fail on a parse error or a script error in what it prints.
  It costs a few seconds.
- **A sweep, in the full tier:** load each prefab first in a process of its own and fail if any
  scene is left without a part (section 6 has the script). It says which orders are fragile
  before the game comes to load in one of them.

### 2.7 Smaller notes on structure (read)

- **`MapInfo`'s headers have fallen behind.** The part headed "the garden's seeds and plants" is
  546 lines of bells, wind, bosses, trophies, switches and towers. It is a `Control` under a
  `CanvasLayer`, named for a part of the screen, though it is the game's session.
- **The developer's panel lives in the print.** `RisoPrint` holds the F7 panel and its travel
  (parts of 184 and 292 lines): changing the preset, going to a boss, giving keys. That is part
  of why the print names 40 classes.
- **A side world is a place hidden in a row.** `Worlds` packs the kind and the level it hangs
  off into `y` (below `-SIDE_BASE`). Making room for the rows above the start already cost one
  move of every save (`RunState.from_v2`). It works; it is a thing to know before the grid is
  changed again.
- **State that outlives the scene.** Going back to the menu frees the main scene and makes it
  anew, but 80 static variables stay as they were, a few of them the session's
  (`Difficulty.preset`, `MapInfo.debug`, `Health.invincible`).

## 3. What holds up

- **A place is (seed, row).** It is laid out once and never changed, and what the run did there
  is a record laid over it as it loads. Saves stay small and levels can be laid out anywhere:
  on a worker, in a test, in the tools.
- **The record has one writer.** All but a handful of changes to it go through `MapInfo`.
- **The art leans on the game, not the game on the art.** The props' art scripts name gameplay
  classes 107 times; gameplay names a prop's art once.
- **One table each** for what is laid in a cell (`Placeables`), the abilities (`Abilities`) and
  the bands (`Bands.LAYOUTS`).
- **The conventions are kept.** No `/root` paths; the few calls by name are in the table
  `unit_test` checks; nothing in the generator draws from an unseeded source; the wall clock is
  read only by art.
- **The tests' kit and the fingerprints.** Waiting on the game and not on frames, levels laid
  out without the scene, a guard that names which level changed.

## 4. An order of work

1. **The shots** (1.1), with the boot check (2.6): small, and the game is not playable as meant
   without it. *Done:* every shot is made by `Bullet.make()`, which loads `bullet.tscn` by its
   path the first time (no script `preload`s it now: not the watcher, the seed pod, the bramble's
   bulb, the crossbow or the scholar), and `tests/run.sh` starts every run of the suite with
   `game_boot`, the game itself started headless for 120 frames, failing on a parse or script
   error. The sweep of 2.6 is left to item 5.
2. **The barriers** (1.3, 1.4), then `beast_test` (1.2), then the fingerprints written once
   (`layout_fingerprint_test -- update`), said in the report.
3. **The swallowed death** (1.5) and **the refresh's price** (1.8).
4. **Saving** (1.6, 1.7, 2.5): the kept map noted on arriving, one place that writes, a safe
   write.
5. **Load order as a kind** (2.1): the small classes of constants, prefabs loaded when wanted,
   the rule in `unit_test`, the sweep.
6. **One map of what cells are spoken for** (2.3), before the barriers go to the other bands.
7. **The planned break of the layouts** (2.4, with the collapse of 2.3), before the demo is out.
8. **The institute out of `MapInfo`** (2.2), when that band is next worked on.

## 5. Not looked at

The art as printed (no captures were taken), the print's shaders, performance beyond the saves,
the bosses' scripts in depth, the suite under the `garden` and `retuned` layouts, and anything
that needs the game played in a window.

## 6. Making each check again

Godot here is the console build named in `AGENTS.md` (or `$GODOT`). The probes were scripts
extending `TestKit`, run from outside the project by their full path
(`godot --headless --path . --script C:/full/path/probe.gd`): the kit takes its name, and so its
save's, from the script's.

- **1.1, the boot:** `godot --headless --path . --quit-after 90`, and look for `Parse Error`.
- **1.1, the shot:** a script extending `SceneTree` that names none of the project's classes:
  load `res://prefabs/scenes/main.tscn`, then `load("res://prefabs/bullet.tscn").instantiate()`
  and ask it for `HitBox`.
- **1.2:** `bash tests/run.sh full`.
- **1.3:** `build` each garden level; for its barrier (`LevelGen.barriers[0]`), go over the
  cells of each lift's body and track and of each placed thing's box (`Placeables.size`), and
  report any within the barrier's `rock` cells or at its `mouth` whose type is no longer
  `EMPTY`.
- **1.4:** for each level with a barrier, a `RunState` with `run_seed` set and
  `souls[at] = BeastSouls.NO_SPOT`; ask `BeastSouls.spot` and see whether it is among the
  barrier's `open` cells.
- **1.5:** `boot`, `player.end_invulnerable()`, `info.balloon_travel(...)` not awaited, one
  frame, `player.hurt(-player.health.health, Vector2.ZERO, a_node)`, `settle`, and read the
  hearts, the ghost and `run.vulnerable`.
- **1.6:** `boot`, a level seen whole, its record copied to more places, and `info.save_run()`
  timed over ten calls.
- **2.1, the knot:** for each script, strip its comments, and note every other script's
  `class_name` it holds as a word; then the strongly connected parts of that graph.
- **2.1 and 2.6, the sweep:** this script, run once for each resource in a process of its own,
  the resource's path given after `--`; any `Parse Error` in what it prints is a scene left
  broken.

  ```gdscript
  extends SceneTree


  func _initialize() -> void:
  	var path: String = OS.get_cmdline_user_args()[0]
  	var r: Resource = load(path)
  	print("LOADED ", path, " ", r != null)
  	quit()
  ```
