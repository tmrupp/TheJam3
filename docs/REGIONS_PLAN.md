# Regions: up and down, and the bosses that guard them

A plan for turning the single dive into two branches out of the garden, up through the crags to
the sky and down through the cemetery to the library, with a boss at the end of each band that
guards a relic and the way on to the next region. It builds on `docs/DEEPER_PLAN.md` (the grid of
places, archetypes, side worlds, relics) and follows the owner's notes, now the task list linked
from `AGENTS.md` ("can go up or down", "bosses, possibly guarding relics, must be defeated").

Phases 1 (rows both ways), 2 (climbing levels), 3 (the gate, with a stand-in boss) and 4 (the
worm and the bramble) are built, and of phase 5 a first pass of the crags and of the spider in its
keep; the rest is not yet. Each section says what is decided, what
is proposed, and what is still open; the phases at the end give the order of work.

## 1. Decided

| Question | Decision |
|---|---|
| How the branches hang off the start | The garden is the hub. It straddles the surface: a run starts in its middle, and it has a gate at each end. |
| Which bosses guard the garden | Two: the **worm** guards the way down, the **bramble** the way up. |
| Where a fight happens | Each boss says: some fight in the band's last level itself (the worm, the bramble), others in an arena of their own, a side world behind a door in that level. |
| How often a boss is beaten | **Once per run.** Until it is slain, every band-end level of its band (in every world column) holds it and is sealed; once slain, all of them open for the rest of the run, and it is never met again. |
| Crags and castle | One band: vertical cliff levels dressed with castle ruins. The spider's arena is the keep. |
| Hyperspace across branches | Yes: a hyperspace may cross the start into the other branch (35 % of them), still leading 4 rows further from the start. |
| The cemetery | Stays the cemetery: its terraces, decor and bell gates, with crypts (mausoleums, catacomb tunnels) added behind bell gates. Light and darkness start to matter here, within a level rather than by band (§7). |
| The last band down | The **library**, in place of the catacombs (which become the cemetery's crypts). What it is, beyond strong spellcasting enemies, is open (§7). The eldritch beast stays its boss. |

## 2. The vertical map

Places stay on the grid of (world, row) (§1 of `DEEPER_PLAN.md`), but rows now run both ways from
the start. Row 0 is where a run begins; rows below it are down, rows above it (negative) are up.

```
   sky             rows −10 … −15     whale (its belly is a level)
   crags / castle  rows  −4 …  −9     spider (arena: the keep)
 ─ garden ───────  rows  −3 …  +3     start at 0
        up gate,   row −3:  the bramble (in the level)
        down gate, row +3:  the worm (in the level)
   cemetery        rows  +4 …  +9     necromancer (arena: a crypt)
   library         rows +10 … +15     eldritch beast (arena: its chamber)
```

- **Bands.** The garden is 7 rows (three either side of the start); every other band is 6. Each
  band is an archetype (`scripts/worlds/archetypes/`), as now; what changes is how a row picks its
  archetype: by a table of bands along the signed row, instead of `(depth / BAND) % 3`.
- **Difficulty is distance from the start.** Everything that now scales with depth (prices, star
  values, enemy health, level size, relic chances, key rarity, lantern counts) scales with the
  distance `|row|` instead. A level's definition keeps a `depth` field for this, set to `|row|`,
  and its row in `coord.y`. Crags at rows −4 to −9 are as hard as the cemetery at +4 to +9.
- **Past the last bands** (below the library, above the sky): open, see §9. Until decided, the
  outermost band repeats, harder, with no further boss.

## 3. Places and their coordinates

Today side worlds hang off the grid at negative rows: kind `k` entered from level `(x, d)` sits
at `(x, -(k * STRIDE + d) - 1)` (`Worlds.side_at`). The up branch needs those rows.

- **Move the side worlds out.** Side worlds start at `SIDE_BASE` (1,000,000) below zero: kind `k`
  entered from row `r` sits at `(x, -(SIDE_BASE + k * STRIDE + r + STRIDE / 2))`, which also carries
  a signed origin row (a side door in an up level). `Worlds.is_side`, `kind_at`,
  `origin_of`, `side_at` and `valid` change; nothing else should know the encoding.
- **Rows `-SIDE_BASE < y < 0` are up-branch levels**, and `Worlds.valid` admits them.
- **Saves.** Records, the ghost and the respawn lantern are keyed by place. Bump
  `RunState.SAVE_VERSION` and migrate a version-2 save: re-key every side-world record to the new
  encoding (levels at rows ≥ 0 keep their keys). `RunState.deepest` becomes the furthest distance
  reached (`|row|`), and `furthest_row` the row where it got that far (for the end-of-run card).
- **The audit.** About 80 places in the code read `coord.y` or `at.y` as depth (relics, prices,
  the ink well, the sign, rifts, the map, decor seeds). Each either wants the distance
  (`def.depth`), the signed row (`coord.y`), or is a "is this a side world" test (`Worlds.is_side`).
  This is the riskiest step and goes first, on its own, with layouts for rows ≥ 0 unchanged where
  possible (`layout_fingerprint_test`).

## 4. Exits and travel

- **The way on and the way back.** `MapInfo.Exit.DEEPER` and `BACK` keep their numbers but mean
  "away from the start" and "toward the start". In a down level that is down and up, as now; in an
  up level it is up and down. `NextWorldDef.lead` turns them into rows by the branch's sign, and
  the transition sweeps the matching way (`RisoTransition`).
- **Row 0.** The start's way back, a dead end today, becomes the way up: the start level gets both
  a way down and a way up. Every garden level above the start likewise leads up by its way on.
- **Climbing levels.** In an up level the way on is placed near the top of the level and the way
  back near the bottom (`LevelGen.place_exits(…, climbing)`), so the up branch is climbed rather than
  crossed; the way on's chevron points up there. Climbing is harder than falling (by the rough
  reach, about 0 to 7 % of up levels could be climbed without help, against 45 to 70 % of down levels
  crossed), so a light helper (`Climb.aid`) lays at most 12 ledges, each a hop on from somewhere
  already reached, toward the way on: hops of the wizard's own in the garden, a relic's (about a
  double jump) beyond it. **Nothing is promised**, as nothing is below the start: some climbs want
  wall jumps or a relic and a few may not go at all. With it, about 70 % of the garden's up levels
  can be climbed with the wizard's own hops (as many as its down levels can be crossed), and nearly
  all the crags and sky with a relic's. No ledge goes in a chasm's or gap's kept air, so the
  crossings left to relics stay theirs.
- **Sideways.** Left and right exits still move a world column at the same row, in both branches.
- **Nothing skips a seal.** Every way that crosses rows without walking them must stop at an
  unslain boss's gate: the hyperspace door (it moves `DROP` rows along the branch, never past a
  sealed band end; a door that would is not dealt), far rifts (only to levels already visited, so
  already fine), warp (within a level), the debug picker excepted.
- **The worlds map.** Its grid grows rows above the start. A band end whose boss lives shows a seal
  on its tile, the boss's mark once seen (§5).

## 5. Gates and bosses

### The gate rule

- **Where.** The last level of a band, toward the next one: rows −3 and +3 for the garden, ±9,
  ±15 for the others. That level is the **gate level**.
- **Sealed.** While the band's boss lives, every gate level of that band (every world column)
  holds the boss and its way on is sealed: printed as the deeper door barred by a boss seal (a
  mark per boss, in the style of the padlocks), with no price and no key that opens it.
- **Slain once per run.** The run keeps the bosses slain (`RunState.bosses`, by name, saved). When
  one dies, its seal lifts in every gate level of its band, and the boss is never placed again.
  Death and lanterns work as for any hit: a lantern death sends the wizard back and the boss heals
  to full (it is not slain, so nothing is recorded); an unprotected death ends the run.
- **The relic.** A boss guards a relic: tier I of a move from `Relics.MOVES` the wizard does not
  yet have (dealt from the run seed and the boss when it dies, so a run never gets a duplicate),
  free, on a plinth that rises where the boss falls. This counts as that move's relic (§ "Secret
  rooms and relics" in `DEEPER_PLAN.md`): shrines teach its higher tiers from then on. If every move
  is known, the plinth holds a skeleton key and a star cluster instead.
- **Two kinds of fight.**
  - **In the level:** the boss is placed in the gate level itself, which is generated with room for
    it (an archetype hook `gate_populate`, run last so nothing else moves).
  - **In an arena:** the gate level holds the sealed way on and, beside it, a boss door into the
    boss's arena: a side world (`SideWorld`) of its own kind, small and procedural, from its own WFC
    sample. The arena's way back leads out again. Slaying the boss there lifts the seal on the way
    on out in the gate level (and every other gate level of the band).
- **Code shape.** A `Boss` base (`scripts/bosses/Boss.gd`): its name, health (shown as pips or
  plates on the boss, not a HUD bar, in keeping with §"hud reduction"), its gate band, `slain()`
  telling `MapInfo` to record it and lift the seals, and the hooks every boss shares (hex, parry,
  dash, stun, shield). Each boss is a script extending it, a prefab, an art script in
  `scripts/riso/props/`, and, for arena bosses, a `SideWorld` kind listed in `Worlds.KINDS`.
  `Placeables` and `LevelGen.Type` get a `BOSS` type and a `GATE` exit look.

### What every boss must keep

- Procedural: laid out from the level's seed like everything else, never hand-placed rooms.
- Every tool has a role: the hex for reach, the dash to strike, the parry to stun, reflect or
  bounce (the pogo, so standing on a boss is a choice), the ward to forgive one mistake.
- Readable in the riso print: pink means danger, weak points in accent or bare paper, a boss's
  health as countable marks on the boss.

## 6. The bosses

The tuning numbers are first guesses for playtest.

### The bramble (garden, up gate, in the level)

*Built* (`Bramble`, `BrambleBulb`, `BrambleVine`, `BrambleWound`, `BrambleShaft`,
`prefabs/bramble.tscn`). The way up out of the garden is a tall shaft of thorns. The bramble is
rooted at its head: a knot of thorn and bark beside the way on, with a few **bulbs** (its weak
points, accent) set in the walls of the shaft.

- **The shaft.** Cut into the gate level's rock near its top (`BrambleShaft.cut`), right after the
  caves are joined and before anything else is placed, so the rest of the level lands round it
  (only the bramble's gate levels change). 4 cells wide inside (`WIDTH`), half the level tall
  (`HEIGHT_SHARE`, at least 12), walled in by rock: roof, walls and floor, with whatever the new
  walls cut off joined up again round the shaft, never through it (`LevelGen.connect_caves`'s
  `walled`). At its foot a passage 2 high runs out through both walls to the caves. Ledges climb it
  from side to side, a hop apart (`LEDGE_EVERY`, as `Reach.UP`). Its head is walled in: the way on
  stands on a landing against one wall (`LevelGen.place_exits` takes it from the shaft), and the
  knot fills the rest of the head beside it, 3 rows (`KNOT_ROWS`), so the way on is reached only
  up the shaft and only once the knot is gone. Nothing else is placed inside it, and no secret room,
  vault, cracked wall or climbing ledge is built into it (`LevelGen.in_shaft`). Where it goes is the
  columns whose walls wall over the least of the caves, ties dealt by the level seed; nothing draws
  from the world RNG.
- **Vines.** Thorn vines are rooted in the walls every 4 rows (`VINE_APART`), clear of the bulbs,
  and lash out across the shaft on a cadence like a laser's (`BrambleVine`: rest 1.4 s, the shoots
  warn pink for 0.8 s, grow out 2.5 cells in 0.25 s, hold 1.1 s, pull back in 0.45 s, each out of
  step by the seed), so the climb is a timing puzzle on its ledges and walls. Only a vine that is
  out hurts. Vines in pink; their shoots warn before they grow.
- **Bulbs.** 3 to 5 bulbs (`BULBS`) up the shaft, one in each of as many bands down the walls,
  from wall to wall. Each takes 3 hits (`Bramble.BULB_HP`) from hex bolts or a dash, even ones that
  only stun at their tier (`Wound.least`), and is never stunned. Each vine feeds from the bulb
  nearest it, and a burst bulb withers its vines for good. Its health shows as accent pips on the
  knot, one per bulb. When the last bulb bursts, every vine withers, the knot tears open and
  shrivels away (1.4 s) and the bramble dies; the seal on the way up lifts, and its relic waits on
  the landing beside the way on.
- **Parry.** A vine's lash can be parried: it recoils into the rock and stays there for the stun
  (`Parry.STUN`, 3 s), then rests before it grows again, opening the wall beside it. The bulbs spit
  seeds at the wizard in sight within 900 px (`BrambleBulb`, every 3 s); a parried seed flies back
  into the bulb that spat it (the shot's attacker) and wounds it.
- **The knot.** Solid, on the environment's layer: nothing gets past it to the way on. Its thorns
  hurt to touch; a parry against them only catches the hit and pushes off.
- **Procedural.** All of it comes from the level's layout and seed; the bramble's own timing
  (its vines' phases, its bulbs' first swell) is hashed from the seed and cell.
- A lantern death brings it back whole, as the level reloads. `tests/bramble_test.gd` covers it,
  `tests/capture_bramble.gd` takes stills. Of the twelve garden gate levels the test lays out, the
  way on is reached with the wizard's own hops in ten (the climb helper, `Climb.aid`, sees the
  shaft's ledges and lends ledges toward its foot, never inside it).

### The worm (garden, down gate, in the level)

*Built* (`Worm`, `WormSegment`, `WormWound`, `prefabs/worm.tscn`). A segmented worm that weaves
through the gate level's tunnels, as Tom described.

- **Segments.** 10 segments (`Worm.SEGMENTS`), each as big as a cell of the level. It crawls cell
  by cell, the body following the head through the cells it has been, and bends there like a pipe:
  straight through a cell it crosses, round a quarter circle in a cell where it turns, sliding
  smoothly between steps, and slides cleanly into and out of the rock at a hole's face. It knows
  the cell after the one its head is going into, so the head bends the way it will turn rather
  than nosing into the rock, and its rounded front stops at the rock. Each segment takes 3 hits
  (`SEGMENT_HP`), its hits left printed on it as dark dots. The head bites (pink); its mouth is
  a shallow Pac-Man wedge ahead of the health dots, cut out of a round nose, whose visible front,
  solid collider and bite share the
  same radius. It strikes: only with the wizard where its lunge will reach, less than 1.1 cells
  ahead of its head (`STRIKE_RANGE`) and 0.45 cells to either side (`STRIKE_ACROSS`),
  it stops, pauses 0.18 s, draws its head back 0.3 cells into its neck as its jaws open wide
  (0.22 s), lunges 0.8 cells on along its path in 0.08 s (`LUNGE_REACH`; the head's body and bite
  go with it), snaps its jaws shut at full reach and settles back, then waits 0.6 s
  (`STRIKE_REST`) before it strikes again. Only where it has open air to lunge into; a stun cuts a
  strike short. After a bite meets the wizard (even a guarded bite), its piece rests for 0.65 s
  (`BITE_RECOVERY`): the head closes its mouth and is harmless but solid and open to strikes;
  its body thorns still hurt. The body, pale flesh, is solid, so it
  walls off tunnels as it passes (a wizard it moves into is let through it, not wedged in the
  rock).
- **Thorns.** Every segment but the head has thorns along one flank of the body, left or right of
  the way it heads, alternating from one segment to the next (`WormSegment.flank`), so each
  segment's bare side is the other way from its neighbours'. They print as pink spikes along the
  body's edge on that side, growing from fixed places along the body so they ride along as it
  crawls (fanned round the outside of a bend, shrinking away on its squeezed inside). Each shows
  wherever the flesh it grows from is out in the open, so they go into and come out of a hole with
  the flesh, one by one; standing out over a wall it crawls along, they print over the rock. Down
  in the rock nothing shows through. That half of each segment is speckled with small pink plates
  (a rough hide; `Worm.scale_plates`), the bare half plain soft flesh, so the side to cut reads. Each time a
  worm comes out of the rock (from a burrow, or out of a wall) the segment behind its head takes
  the flank facing the wizard (`Worm.side_toward`, `Worm.Piece.side`) and the rest alternate from
  it, bending with the body, until it goes into the rock again; each segment keeps its own
  alternation for good, so a split leaves every thorn where it was. They hurt to touch, and a bolt,
  dash or parry striking a segment from its thorny side glances off (`WormSegment.guarded`): the
  wizard has to pick a segment whose bare side faces them, every other one, to cut it. A parry against the thorns only catches
  the hit and pushes off, as off any thorns (they have no health or stun of their own); while the
  worm is stunned they do not hurt.
- **No dashing through.** Its body is on a physics layer of its own (`WormSegment.WORM_LAYER`,
  "Worm"), which the dash does not pass through as it does the enemy layer: a dash stops at the
  worm, unless it cuts the segment it meets and goes through the gap. Damage checks the wizard's
  swept body against the segment's circle, so a stopped dash lands from any direction.
- **Soft flesh, one cut a move.** Any hex bolt or dash cuts a segment, even at a tier that only
  stuns (`Wound.least`, 1 for a segment), and a parry too; so the worm can be fought with the
  moves a run starts with. Each bolt (even a piercing one), dash or parry cuts only one segment,
  the first it meets (`Wound.whole`: the worm is struck once a move).
- **Splitting.** A cut head or tail shortens the worm; cutting a middle segment splits it into two
  shorter worms, the back one growing a head at the cut. Worms of two segments or fewer
  (`SHORTEST`) burrow away and die. The boss is slain when no worm is left, and its relic waits on
  the free floor nearest where the last one went down.
- **Stun.** Only a parried bite, to its face, stuns it (`Stunner.parry_only`; bolts and dashes cut
  but do not stun), and then the whole worm: its segments go still and pale and take double, and
  its head does not bite: a moment to cut it cleanly.
- **Walls and burrows.** It crawls along the walls, floors and ceilings: its lair is every open
  cell of the level touching rock. Burrow holes are dug all through the level (9 per 1000 cells,
  at least 6, floors first, dealt by the level seed, 6 cells apart, clear of the exits), printed as
  the ground pushed up round a dark pit as wide as the worm, in the rock's own ink (and the floor's
  turf), with a few crumbs of freshly dug earth.
- **Digging.** Chasing the wizard it digs straight through a wall when going round is more than
  three times as far (a cell of rock counts 3, `ROCK_COST`), cutting a hole in each face it goes in
  and out by (the way in dug as its nose reaches the face, so it never slides into unbroken rock),
  out of sight and out of reach while in the rock. It never turns back on itself:
  boxed in, it digs into the rock beside its head and burrows away there.
- **Waking and stalking.** It lies under the rock by the way on until the wizard comes within 12
  cells of it (`WAKE_RANGE`), even if its burrow's chunk is asleep (`tests/worm_wake_test.gd`),
  then stalks them through the whole level, staying awake even when
  its original burrow's chunk sleeps: it comes up out of a
  burrow near them (not on them), crawls after them for 8 to 12 s (170 px/s, 280 once after them;
  the wizard runs at 300), sinks into the nearest burrow and comes up again 1.2 to 2.4 s later.
- **Warning.** Every time it is about to come out of the rock (from a burrow, or digging out of a
  wall) it waits 1.2 s (`EMERGE_WARN`): the ground there bulges pink round a dark slit, throbbing
  faster and swelling, clods of dirt jump, and the screen rumbles every 0.15 s, harder as the
  moment nears and the nearer the wizard is (felt within 1100 px); then it bursts out with a
  harder shake.
- **Procedural.** Its choices come from an RNG of its own, seeded by the level; nothing draws
  from the world RNG, so layouts are unchanged.

### The spider (crags / castle, arena: the keep)

*A first pass is built* (`Spider`, `SpiderKeep`, `SpiderWeb`, `SpiderWound`,
`prefabs/spider.tscn`). The spider's arena (`Arena`, the side world behind the boss door in the
crags' gate level, row −9) lays out its keep instead of the plain hall, printed as the crags' castle
(their realm and decor).

- **The keep** (`SpiderKeep.build`, from the arena's own RNG, the same every visit). 22 × 32 cells
  of masonry: a hall 18 wide, a roost of 8 rows of air under the roof, then 5 broken floors 4 rows
  apart (`STOREY`) and the ground storey. Every floor is broken by the **well**, a hole 3 wide in
  the same columns all the way down, and by a **stair hole** on alternate sides of it, with a
  one-way ledge under it halfway down the storey below, so each floor is climbed in two of the
  wizard's own hops. The way back and a lantern stand on the ground at the left. What it holds is
  noted in `LevelGen.keep`.
- **Webs** (`SpiderWeb`): across every hole of the well and half the stair holes. In one the
  wizard moves at most 110 px/s across, rises 90 and sinks 55 (a jump stalls, a fall is slow), and
  the dash does not come back (`Player`). A hex bolt (flying on) or a dash tears one; it is spun
  again 12 s later. The spider passes through its own webs. Not yet: scuttling along them as
  paths.
- **Hunting.** Asleep on its canopy under the roof until the wizard comes within 16 cells; then it
  crawls along the roof to be over them (or over the hole nearest them, waiting), rears 0.45 s
  (fangs flashing pink), drops on its thread (1500 px/s) to where they were, holds its bite
  0.55 s, climbs back (400 px/s) and rests 0.9 s. It drops and climbs only through the middle of a
  hole (its body is about 140 px across).
- **Hard back.** A strike glances off unless it is **open**: biting (its face), stunned, or fallen.
  Open, any bolt, dash or parry (even one that only stuns, `Wound.least`) puts out one eye.
- **The thread.** A hex bolt or a dash across it cuts it (`Spider.thread_across`; the bolt ends
  there): it tumbles to the floor below and lies on its back 2.8 s, then scurries along that floor
  to the nearest spot with a clear line up to the roof (or off into a hole, falling on down) and
  climbs a new thread, which can be cut again. Its body is a capsule that turns with it
  (`struck_by`); the thread leaves its abdomen's tip clear of that, so a way over its back cuts
  the thread rather than glancing off.
- **Parry.** A parried bite puts out an eye and stuns it on the spot (`Parry.STUN`; nothing else
  stuns it, `Stunner.parry_only`); when the stun passes it climbs back up.
- **Health** as eyes: 8 (`EYES`), bare paper, accent while it is open, dark once put out (the small
  ones at the back first). With the last it curls up, falls, shrivels (1.3 s), and its relic waits
  on the floor where it lies. A lantern death brings it back whole, webs and all.
- **Size.** Every size of it follows `Spider.ART` (2.6: its abdomen's tip 156 px behind its middle).
- `tests/spider_test.gd` covers the keep and the fight; `tests/capture_spider.gd` takes stills.
- **Status / not yet.** First pass, untuned. Not yet: playtested by hand; webs as its paths; a
  cue for where it will drop beyond the rear; the spider's size against the 3-row storeys (it
  fills most of one) wants a look in play.

### The whale (sky, arena: its belly)

A great slow whale drifts across an open sky arena.

- **Outside**, it cannot be wounded: hex bolts glance off, and its passes drive birds and gusts at
  the wizard. Its open mouth, on its slow turns, is a door.
- **Inside**, the belly is a side world of its own (a small dark level of ribs and stomach pools,
  Tom's "digestive system that is another level"): its heart (accent) hangs at the far end behind
  valves that open and close, and acid pools rise and fall (the "flooded / drain and fill" places
  idea, in small). Bursting the heart slays it, and the wizard is spat out at the gate.
- **Leaving** the belly without killing it puts the wizard back outside, the heart healed.

### The necromancer (cemetery, arena: a crypt)

Its crypt is one of the cemetery's (§7): behind a bell gate, dark inside, its graves the burial
niches of the crypt's tunnels.

- **Skeletons.** It raises skeletons from graves round the crypt that walk at the wizard. A stun
  kills a skeleton (they "die on stun", as Tom noted), so the parry clears them, and the hex's stun
  does too.
- **The necromancer** blinks between graves and is shielded (`Shield`) while any skeleton walks;
  when the last falls, it is open for a moment. Its health as candles on its staff.

### The eldritch beast (library, arena: its chamber)

Tom's idea: it spawns souls (tentacles, horcruxes) in levels already visited, which must be
destroyed. It stays the boss of the last band down now that the band is the library; how its
souls fit the library depends on what the library becomes (§7).

- **Souls.** When the wizard first enters its chamber, it sends out one soul per a few levels into
  library levels the wizard has visited (kept in those levels' records, so they are there on the
  next visit). Each soul is a pulsing thing (pink, on the map once sensed, and with awareness) that
  takes a few hits.
- **The beast** cannot be wounded while any soul lives; with each soul destroyed, one of its eyes
  closes. When all are gone it is vulnerable in its chamber, a short fight of tentacle sweeps to
  jump and parry.
- This fight sends the wizard back up the band they just came down, a journey of its own.

## 7. The new bands

### Crags with castle ruins (rows −4 … −9)

*A first pass is built* (`docs/DEEPER_PLAN.md` §4d): the sample, the structure pass (shafts, keeps,
towers, caverns), the realm and backdrop, the decor, doors in its passages, rock-bugs (crawlers
that walk along rock like a wisp, turning back only where they must, and fall off when stunned),
and the gondola, a cable car climbing a line of stations from the bottom of the level to its top,
straight up and up 45° diagonals, all but one station shut by a toll gate (paid from the landing
or from inside the car) or now and then a switch gate, never a door (it runs from an open station
to a shut one, never between two shut ones), worked by a lever
inside and called from a post at each open station, its sides down only while it runs, a
rock-bug coming along its cable and in through its roof on each stretch (stunned off, or let off
when it stops). Not yet: updrafts, falling rocks, watchers in the slits, and
the spider.

- **Terrain.** Vertical: tall cliff faces with narrow ledges, chimneys and overhangs, collapsed
  from a sample drawn for it (`tests/make_crags_sample.gd`, symmetry 1 so up stays up), taller
  than wide (an archetype `scale` such as 0.8 × 1.6).
- **Castle ruins.** Some of the cliff is built: battlements along ledges, tower stubs, stair runs,
  arrow slits, broken arches. These come from the decor (`RisoDecor`, a `crags` plan) and from a
  structure pass that squares off some rock into walls and floors.
- **Gates.** Doors and switch gates fit its built corridors; climbing is its natural gate (wall
  climb and double jump matter here, so the relic from the bramble is often one of them).
- **Life.** Updrafts in its chimneys (the sky's `Wind`), falling rocks (the "falling spikes" idea),
  watchers in the arrow slits.
- **Realm.** Pale stone and dawn colours; wind-torn clouds below the cliffs.

### The cemetery: crypts, light and darkness (rows +4 … +9)

The cemetery stays as built (`docs/DEEPER_PLAN.md` §4b): its terraces, realm, decor, moths, fog,
wraiths, and its chasms gated by bells. What it gains are crypts, and light that matters.

- **Crypts.** Mausoleum fronts stand on the terraces, each barred by a bell gate: ringing its bell
  (freed as any bell is, by key or switch) opens the crypt. Behind it, catacomb tunnels are cut
  into the rock by a structure pass (as the crags build their keeps): narrow passages, burial
  niches, the odd ossuary room. Some crypts hold loot (a vault, a relic, a lantern), some are part
  of the way through. The decor goes inside too: headstones and urns set in niches, cobwebs and
  roots; the necromancer's arena is a crypt (§6).
- **Light by place, not by band.** The terraces stay moonlit (the shade every band has, no gloom);
  inside a crypt it is deep dark (`Archetype.gloom`, so far only on the band below). The darkness
  is a property of where the wizard is in the level, not of the whole level.
- **Light and dark each have their uses.** The carried lantern's flame can be snuffed and lit
  again, and the cemetery asks for both at different times:
  - *Lit*, the wizard sees in the crypts, and light-shy things (a crypt-dweller that moves only in
    the dark) freeze in the flame's light, a lantern's pool or a lit candle.
  - *Snuffed*, the wizard is hidden from what hunts the flame (wraiths, moths), slips past the
    sleeping dead in their niches (who wake when light falls on them), and sees what shows only in
    the dark: ghost planks over a chasm, glowing grave runes, will-o'-wisps marking a hidden crypt.
- **Places to snuff and to light.** Fonts or draughts that put the flame out; candles, braziers and
  lit lanterns that light it again (a hex bolt lights a candle, which stays lit in the record).
- **Snuffing is a risk.** Proposed: while the flame is out the wizard is unprotected (a death ends
  the run) until it is lit again. Open: whether it should be softer, such as only losing sight.

### The library (rows +10 … +15)

The last band down, in place of the catacombs. The beast stays its boss, and it should have strong
spellcasting enemies; the rest is being worked out. Until it is built, the band is the stand-in
(`CatacombsArchetype`: the cemetery's terrain and dressing in deep darkness).

### The garden widens

The garden now spans rows −3 to +3. Its existing look and dressing stay; the bands that used to
follow it by depth (cemetery from 6, sky from 12) move to their new rows, which changes layouts
from row 4 down (expected: `layout_fingerprint_test` is re-pinned in that phase).

## 8. Phases

Each phase ends with the full suite green and its own tests.

1. **Rows both ways.** *Done.* Side worlds moved to `SIDE_BASE` (`Worlds`), version-2 saves
   migrated (`RunState.from_v2`), distance (`def.depth`) separated from the row everywhere, rows
   above the start are levels, the start's way back is a paid way up, bands come from a table
   (`NextWorldDef.GARDEN`, `DOWN`, `UP`) with the crags and catacombs as stand-in archetypes
   (`CragsArchetype`, `CatacombsArchetype`), hyperspace may cross into the other branch, and the
   map, place marks (an up arrow for heights), the travel card and the F7 travel picker know
   heights. Tests: `unit_test` (bands, encoding, migration, the start's way up, hyperspace
   crossing), `branches_test` (going up and home in play, the crags past the garden, saving above
   the start), `capture_branches.gd` (stills). Levels from row 4 down, and the start level's
   dressing (its new door up), changed; `layout_fingerprint_test` was re-pinned.
2. **Climbing levels.** *Done.* Exits mirrored for the up branch, the chevron turned, the arrival
   at the bottom, and the climb helper (`Climb`, no promise of a way through; the owner asked for
   traversability to be relaxed, especially beyond the garden). Tests: `climb_test` (the way on above
   the way back and in the top part, ledges only in up levels and where they may go, the same every
   build, and they help); `layout_fingerprint_test` re-pinned for the up levels (their dressing
   changed; their terrain and every level below the start did not).
3. **The gate.** *Done.* `Bosses` (which row each boss guards, in the level or in an arena, what a
   way crosses), `RunState.bosses` and `boss_relics` (saved), `NextWorldDef.gate` and `seal`: a gate
   level's way on, and a side door whose world leads out past a living boss's gate (a hyperspace),
   are sealed (pink bars and the boss's eye on the door, the eye on the prompt, a seal mark on the
   level map). The stand-in (`Boss`: a wisp twice the size, 10 hits shown as pips over it) stands in
   the worm's and bramble's gate levels (`LevelGen.place_boss`, nearest the way on) and in the arena
   (`Arena`, a side world: a plain hall, its door free, a dead end) for the rest. Its death
   (`MapInfo.boss_slain`) opens every gate level of its band for the run and leaves a free relic
   where it fell (a move not yet known, `Bosses.relic_for`; with every move known, a skeleton key
   and a star cluster). Gate levels hold no relic of their own. Tests: `gate_test` (the rows and
   crossings, the seal, a lantern death healing it, the kill, the relic, the other columns, the way
   up still sealed, the arena, hyperspace sealed then opened, saved); `capture_gate.gd` (stills).
   Every hyperspace from the garden now waits on a garden boss, since its trip crosses a gate. Not
   yet: a seal mark on the worlds map's tiles.
4. **The bramble and the worm** (the garden's gates, in the level). *The worm is done* (§6): its
   lair and holes, cell-sized segments bending like a pipe, the bite, soft flesh (`Wound.least`, so
   the starting moves can cut it), stuns holding the whole worm, cuts shortening or splitting it,
   short worms burrowing away, and its death; one cut a move, only a parried bite stunning it, its
   body blocking the dash; thorns on the flank facing the wizard as it comes out; crawling the walls of the whole level, burrows all
   through it, digging through walls, and a warning (a pink bulge, dirt and a rumble) before it
   comes out of the rock. A built boss is its own prefab (`Bosses.SCENES`,
   `Bosses.scene`); the rest still fight as the stand-in. Tests: `worm_test` (holes and lair, lying
   under, the warning and rumble, waking and hunting, the head never in the rock, digging through a
   wall, its thorns (one flank, picked facing the wizard as it comes out and kept, glancing
   strikes off), one segment cut a move, only a
   parry stunning it, its layer, the bite, struck by a dash and a bolt that only stun, cuts, splits,
   burrowing away, a lantern death healing it, slain, its relic on a floor, never met again);
   `capture_worm.gd` (stills). The F7 panel's Travel section has **Slay boss**
   (`MapInfo.slay_boss`): the boss here (the worm, the bramble, or a stand-in) dies at once as by
   any blow, leaving its relic; in a gate level whose boss fights elsewhere, that boss is slain
   where the wizard stands (`gate_test`). *The bramble is done* (§6): its shaft cut near the top of
   its gate level, walled in, with ledges, a foot open to the caves, and the way on on a landing at
   its head; the knot walling off the head; vines lashing out on a cadence, a parried lash
   recoiling; bulbs spitting seeds a parry turns back into them, wounded by any bolt or dash, each
   feeding the vines nearest it; the knot tearing open with the last. Tests: `bramble_test` (the
   shaft's walls, foot, landing, knot and ledges, nothing else in it, the same every build and only
   in its gate levels, reached from the way back; in play the knot, the vines' cadence and sting, a
   parry recoiling one, seeds spat and parried back, bolts and dashes wounding bulbs, a burst bulb
   withering its vines, a lantern death healing it, slain, its relic on the landing, never met
   again); `capture_bramble.gd` (stills). The bramble's gate levels changed (layout); every other
   level did not. `gate_test` and `capture_gate.gd` now show the stand-in in the necromancer's
   arena.
5. **Crags and castle**: *a first pass is done*: sample, structure pass, decor, realm, and the
   gondola (`CragsArchetype`, `Gondola`; `crags_test`, `capture_crags.gd`; the crags' layouts
   changed and `layout_fingerprint_test` was re-pinned for them alone). *The spider and its keep:
   a first pass is done* (§6; `spider_test`, `capture_spider.gd`; no level's layout changed, only
   the spider's arena). Then its life (updrafts, falling rocks, watchers in the slits), and tuning
   the spider in play.
6. **Cemetery crypts and light**: crypts behind bell gates, darkness by place, the flame snuffed
   and lit; then **the necromancer** in its crypt.
7. **The library**: once decided (§7); then **the eldritch beast**.
8. **The whale** and its belly.
9. **Tuning pass** with playtests: boss health and timing, relic odds now that bosses give one,
   prices by distance.

## 9. Open

- **Past the last bands.** Below the library and above the sky: a final place where the branches
  meet (hyperspace?), the outer bands repeating harder, or the run won at the bottom or the top.
- **What a boss's relic is.** A move not yet known (proposed), or always the same move per boss
  (the bramble wall climb, the worm double jump...), which would make each branch's order of
  abilities designed rather than dealt.
- **Gate level size.** Whether gate levels are the band's ordinary size or larger. The worm and
  the bramble fit in the ordinary size (the bramble's shaft is half the level tall).
- **The ward and bosses.** Whether boss hits break a ward charge like any hit, or several.
