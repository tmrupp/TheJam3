# Cleanup plan: ten follow-ups to the architecture refactor

The architecture refactor (LevelGen / RunState / LevelLoader, Placeables, the ability registry,
the RisoProp split, typed connections) left ten smaller repetitions and loose ends. Each item below
says what repeats, where, what to change, and how to check it. Items are independent unless noted;
the order is a suggested one (generation first, while the layout tests are fresh in mind).

## Ground rules for every item

- **Layouts must not move.** Items 1–3 touch level generation. Keep every `rng` draw in the same
  order and on the same lists. A helper may change how a set is found, but not which cells end up
  in it or the order they are drawn from: keep the `sort()` before every `pick`.
  `layout_fingerprint_test` must pass unchanged (no `GOLDEN` update); if it moves, the change is
  wrong, not the fingerprint.
- Run `bash tests/run.sh` after each item and `bash tests/run.sh full` before calling it done.
  Items 4, 5 and 8 touch art: also take the matching `capture_*.gd` stills and look at them zoomed in.
- Keep `docs/DEEPER_PLAN.md`, `docs/RISO_PRINT.md` and `AGENTS.md` in step with renamed functions.

---

## 1. One flood fill for "what is reachable from here"

**What repeats.** Four hand-written flood fills over open cells:

| Where | Start | Walls | Order matters? |
|---|---|---|---|
| `LevelGen.place_switch_gates` | the way in | rock, and the gate being placed | no (result sorted before `pick`) |
| `Chasms._bell_switch` | the bell | rock, a chasm's air, and cells past `reach_cells` | no (sorted before `pick`) |
| `LevelGen._flood` (used by `connect_caves`, `_open_regions`) | any open cell | rock | no (a set) |
| `LevelGen.connect_caves` (the tunnel search) | the main region | none (walks through rock) | **yes**: breadth-first, nearest first |

**Change.** Add to `LevelGen`:

```gdscript
## Every cell reached from `start` through open air (4-neighbour), where `passable(cell)` also
## holds; a set (cell -> true). The order cells are found in is not kept: sort before drawing.
func reach_from (start: Vector2i, passable: Callable = func(_v: Vector2i) -> bool: return true) -> Dictionary
```

- `place_switch_gates`: `reach_from(start, func(n): return n != gate)`.
- `_bell_switch`: build `blocked` as now, then
  `w.reach_from(bell, func(n): return not blocked.has(n) and (reach_cells < 0 or dist(n, bell) <= reach_cells))`.
- `_flood(from, into)`: keep its signature (it adds into an existing set) but implement it with
  `reach_from`, or give `reach_from` an optional `into: Dictionary`.
- Leave `connect_caves`'s tunnel search alone: it is a different walk (through rock, nearest
  first, with parents) and its order decides which tunnel is carved.
- Leave `Reach.grow` / `Reach.tree` alone: they walk hops between footholds, not open cells.

**Also.** The "floors in `reach` that are free, open, on rock and far enough, sorted, then `pick`"
tail is the same in both switch placements: a helper `_pick_floor_in(reach, from, at_least)`.

**Check.** `layout_fingerprint_test`, `switches_test`, `cemetery_test`, `sky_test`.

## 2. One "best spot by distance" search

**What repeats.** A loop keeping the nearest (or furthest) candidate that passes a test:

- `LevelGen._start_door` (nearest to the start, at least `START_DOOR`, hop-reachable)
- `LevelGen._nearest_free` (nearest to the way back, within 4)
- `LevelGen.place_return` (nearest to the start, at least 4, not crowding an exit)
- `LevelGen.place_side_doors` (furthest from the start, or nearest in a debug run)
- `LevelGen.place_cluster`'s fallback (furthest floor from the way in)
- `LevelGen.place_start_key` (lowest score: distance to start plus to door)
- `Hyperspace._standing_near`, `_spread`, `_lasers` (nearest to a target column)

**Change.** Add to `LevelGen`:

```gdscript
## The first of `spots` (in their order) with the least `score(v)`, among those passing `test`;
## null if none pass. Ties keep the earlier spot, as the loops it replaces did.
static func best_of (spots: Array, score: Callable, test: Callable = func(_v: Variant) -> bool: return true) -> Variant
```

Each site becomes one call, e.g. `place_return`:
`best_of(floors, func(v): return dist(v, start), func(v): return dist(v, start) >= 4 and not _crowds_exit(v))`.
"Furthest" is the score negated. `_lasers` scores `[v, d]` pairs, which is why `spots` is `Array`.

**Watch.** Tie-breaking: every loop above uses strict `<` (or `>`), so the first best wins. `best_of`
must do the same, and callers must pass the spots in the same order they iterate now (several use
`empties_where`, which sorts). `place_side_doors` debug vs normal is the only one that flips
direction; keep it as two scores.

**Also.** "Not within 3 of another exit" appears in `place_return` and `place_side_doors`:
`_crowds_exit(v)`.

**Check.** `layout_fingerprint_test`, `start_escape_test`, `hyperspace_test`, `deeper_test`.

## 3. One room-fit search for secret rooms, vaults and strongboxes

**What repeats.** `_secret_spots(room, enclosed)` and `_strongbox_spots(inside)` both:
walk `free_floors()`, try each `side` in `[-1, 1]`, put a `door` beside the floor, compute
`x0` and the room `Rect2i` the same way, then test the cells round it. `place_vaults` and
`place_bone_vault` both filter `_secret_spots` with the same "walled in the level's own rock"
test, and both repeat "pick a spot, rock its walls, carve the vault".

**Change.**

- `_room_beside(o: Vector2i, side: int, inside: Vector2i) -> Array` returning `[rect, door]`:
  the shared geometry. Both spot searches loop over it.
- `_vault_spots(room)`: `_secret_spots(room, true)` filtered to rooms whose grown rect is inside
  the level (the filter `place_vaults` and `place_bone_vault` both write).
- `_build_vault(choice, color)`: `_to_rock` each wall cell in `choice[2]` (when there is one),
  then `_carve_vault(choice[0], choice[1], color)`.
- `near_chasm` in `_strongbox_spots` is "is `c` in a chasm's kept air, two cells wider": move it to
  `Chasms.near(w, c)` next to the other chasm geometry.

**Watch.** `place_vaults` draws `rng.randi_range(0, KEY_COLOR_COUNT - 1)` *after* `pick`: keep that
order inside `_build_vault`'s callers (draw the colour after picking, as now).

**Check.** `layout_fingerprint_test`, `vaults_test`, `bones_test`, `secrets_test`, `room_test`.

## 4. RisoMap: one way to mark a level

**What repeats.** `RisoMap._level` marks the level being played from its live nodes
(`map_elements`, matched by `Placeables.type_of`); `_other_level` and `_other_things` mark any other
level from its layout and record. Most kinds are handled twice: lanterns (lit, spent), bells and
vanes (rung, lock state), bridges, inkwells, switches, keys, doors, relics, clusters, portals.

**Change.** Mark both from layout plus record (the record is current for the level being played
too), keeping only what nodes alone know: dropped keys and rifts placed this visit, a key in its
pickup animation, the ghost. One `_mark_cell(v, cell, rec, spot)` with the per-type match; the
live path adds the few node-only marks after it.

**Watch.** A thing taken this visit disappears from the live path at once; from the record it
disappears once `mark_taken` runs, which is the same moment. Check keys mid-pickup.

**Check.** `map_test`, `map_worlds_test`, `secrets_test`; stills from `capture_map.gd`,
`capture_map_over.gd`.

## 5. Spell readiness through the registry

**What repeats.** `RisoWizard._spell_ready` and `RisoWizard._spell_running` each `match` on the
spell's name to ask its node how ready it is or how long it has left. `Hex`, `Mend` and `Warp`
already have `readiness()`; parry, levitate, astral, awareness and rift answer through ad hoc reads.

**Change.** Every spell node gets `readiness() -> float` (0..1, 1 when castable) and
`running() -> Vector2` (fraction left, seconds left; x < 0 when not running), next to
`set_tier` and `cast_spell`. Add `Abilities.spell_node(player)`. `RisoWizard` asks it; the HUD's
spell orb does the same. Extend `unit_test`'s node check to require both methods on spells.

**Check.** `spells_test`, `shrine_test`, `unit_test`; `capture_spells.gd`, `capture_orb.gd`.

## 6. Make the last two duck-typed protocols checked

**What remains.**

- Prefab `setup(info, v)` / `setup(info, v, extra)`: called by name from `LevelLoader.place_cell`
  on about 20 scripts.
- `hex_hit(damage, dir)`: called by name from `HexBolt` on `Bell`, `CrackedWall`, `MothSwarm`
  and `Switch`.

**Change.** Not a base class (the prefabs extend different engine types). Instead:

- In `Placeables.TABLE`, mark each entry whose prefab is set up (`"setup": 2` or `3`, the
  argument count). `place_cell` uses the entry rather than `has_method`.
- Add to `unit_test` (as for abilities): for every `Placeables` scene, its script defines `setup`
  with the declared argument count when the entry says so; every script defining `hex_hit` takes
  two arguments; and `HexBolt`'s targets are the scripts listed in one const
  (`HexBolt.ANSWERS`), so a new one is added in one place.

**Check.** `unit_test`, `hex_test`, `switches_test`.

## 7. Move the run-wide rules out of MapInfo

**What.** `MapInfo` still holds 14 static rules (`level_seed`, `deeper_price`, `cluster_value`,
`skeleton_at`, `exit_distance`, `relic_need`, `bone_vault_at`, `relic_gated_at`, `lateral_lock`,
`rarity_color`, `level_size`, `map_price`, `where`, `def_for`) and the key and relic constants,
next to scene glue. Generation (on the worker thread) calls them through a scene class.

**Change.** A `Rules` class (`scripts/level/Rules.gd`, static, RefCounted) with those functions
and constants. Leave `MapInfo` forwarding nothing: update callers (a mechanical rename, about 150
sites; `MapInfo.Exit` stays). `MapInfo` becomes the place being played and its scene effects only.

**Watch.** `level_seed` is the most-called function in the project; check nothing still reaches
it through `MapInfo.` after the rename (grep), and that `unit_test`'s seed checks still pass
(they pin its values).

**Check.** Full suite; `unit_test` first.

## 8. Archetype art by hook, not by name

**What.** `RisoDecor.plan` chooses its plan with `if archetype == &"cemetery"` / `&"sky"`, and
`RisoBackground` its backdrop with `realm == ...`. A new band falls back to the garden's decor and
the night backdrop: it works, but its art needs edits in those two files.

**Change.**

- `Archetype.decor` (StringName, default `&"garden"`) naming the plan; `RisoDecor` keeps a table
  `PLANS = {&"garden": ..., &"cemetery": ..., &"sky": ...}` of plan functions and looks it up.
  Cemetery and sky set theirs in `_init`.
- `RisoBackground`: a table of backdrop functions by realm, as `RisoPrint.REALMS` holds colours by
  realm; the `if/elif` chain becomes a lookup with the night backdrop as the fallback.

**Check.** `decor_test`, `cemetery_test`, `sky_art_test`; `capture_cemetery.gd`, `capture_sky.gd`,
`capture_riso.gd`.

## 9. Drop the unused cell types

**What.** `LevelGen.Type.GOAL`, `RESPAWN` and `ASTRAL_PROJECTION_POINT` are never placed or read.

**Change.** Remove them from the enum.

**Watch.** Removing entries from the middle shifts the numbers of every type after them. Nothing
saved holds a type (records are kept by cell, see `LevelRecord.FIELDS`; layouts are rebuilt from
the seed), but tests and the fingerprint do (below).

**Check.** Full suite. `layout_fingerprint_test` hashes each cell's type *number*, so removing
entries before the end of the enum changes every fingerprint even though no level moved. Either
move the three entries to the end first and remove them there (numbers of the others unchanged,
fingerprints unchanged), or update `GOLDEN` and say in the report that only the numbering moved.
The first is safer.

## 10. Move old tests onto TestKit

**What.** 24 tests still carry their own copies of `placed`, `boot`, `until` or `settle` instead of
extending `TestKit`: astral_moon, bones, cemetery, dash_strike, death, decor, deeper, floor,
hazards, hex, hyperspace, interaction_hints, interface, map, map_worlds, phasing, rift, secrets,
shrine, sky, spells, switches, vaults, wall.

**Change.** One test at a time: `extends TestKit`, delete the local copies, replace frame-counting
waits with `until(cond)` and `settle()`. Several of the flaky checks seen in parallel runs (the sky
ricochet, for one) wait a fixed number of frames; `until` fixes that class of flake.

**Check.** Each converted test alone, then the full suite. Do these in small batches so a failure
points at one test.
