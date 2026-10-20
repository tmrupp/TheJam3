# Regions: up and down, and the bosses that guard them

A plan for turning the single dive into two branches out of the garden, up through the crags to
the sky and down through the cemetery to the institute, with a boss at the end of each band that
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
| Where a fight happens | Every boss is in the band's last level itself, its gate level, with whatever it needs built into that level (the bramble's shaft, the spider's keep, the necromancer's crypt). No arenas. |
| How often a boss is beaten | **Once per run.** Until it is slain, every band-end level of its band (in every world column) holds it and is sealed; once slain, all of them open for the rest of the run, and it is never met again. |
| Crags and castle | One band: vertical cliff levels dressed with castle ruins. The spider's keep is built at the top of its gate level. |
| Hyperspace across branches | Yes: a hyperspace may cross the start into the other branch (35 % of them), still leading 4 rows further from the start. |
| The cemetery | Stays the cemetery: its terraces, decor and bell gates, with crypts (mausoleums, catacomb tunnels) added behind bell gates. Light and darkness start to matter here, within a level rather than by band (§7). |
| The last band down | The **institute**, in place of the catacombs (which become the cemetery's crypts): a sunken institute of magic with a library among its wings; students and masters, strong spellcasters, and abominations rising from the deep, all fighting one another as well as the wizard; exams as its gates, sat with papers fetched on field trips; departments with portals to real levels of other bands, in the same column (§7). The eldritch beast stays its boss. |
| The far bands' characters | The institute is **humanity** (people, schooling, rivalry); the sky is **the elements** (wind, storm, beasts of the air). Each speeds travel one way: the institute's portals up and down a column, the sky's balloons along a row, on its winds (§7). |

## 2. The vertical map

Places stay on the grid of (world, row) (§1 of `DEEPER_PLAN.md`), but rows now run both ways from
the start. Row 0 is where a run begins; rows below it are down, rows above it (negative) are up.

```
   sky             rows −10 … −15     whale (its belly is a level)
   crags / castle  rows  −4 …  −9     spider (its keep, in the gate level)
 ─ garden ───────  rows  −3 …  +3     start at 0
        up gate,   row −3:  the bramble (in the level)
        down gate, row +3:  the worm (in the level)
   cemetery        rows  +4 …  +9     necromancer (a crypt, in the gate level)
   institute       rows +10 … +15     eldritch beast (its chamber, in the gate level)
```

- **Bands.** The garden is 7 rows (three either side of the start); every other band is 6. Each
  band is an archetype (`scripts/worlds/archetypes/`), as now; what changes is how a row picks its
  archetype: by a table of bands along the signed row, instead of `(depth / BAND) % 3`.
- **Difficulty is distance from the start.** Everything that now scales with depth (prices, star
  values, enemy health, level size, relic chances, key rarity, lantern counts) scales with the
  distance `|row|` instead. A level's definition keeps a `depth` field for this, set to `|row|`,
  and its row in `coord.y`. Crags at rows −4 to −9 are as hard as the cemetery at +4 to +9.
- **Past the last bands** (below the institute, above the sky): open, see §9. Until decided, the
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
  crossed), so a light helper (`Climb.aid`) laid at most 12 ledges, each a hop on from somewhere
  already reached, toward the way on: hops of the wizard's own in the garden, a relic's (about a
  double jump) beyond it. *Since removed (the owner: traversability is not enforced in any world,
  AGENTS.md); what follows is as it was.* **Nothing is promised**, as nothing is below the start:
  some climbs want wall jumps or a relic and a few may not go at all. With it, about 70 % of the garden's up levels
  can be climbed with the wizard's own hops (as many as its down levels can be crossed), and nearly
  all the crags and sky with a relic's. No ledge goes in a chasm's or gap's kept air, so the
  crossings left to relics stay theirs.
- **Sideways.** Left and right exits still move a world column at the same row, in both branches.
- **Nothing skips a seal.** Every way that crosses rows without walking them must stop at an
  unslain boss's gate: the hyperspace door (it moves `DROP` rows along the branch, never past a
  sealed band end; a door that would is not dealt), far rifts (only to levels already visited, so
  already fine), warp (within a level), the debug picker and the institute's portals (§7)
  excepted.
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
- **In the level.** Every boss is placed in its gate level itself (`LevelGen.place_boss`), which
  is generated with what it needs: the bramble's shaft (`BrambleShaft`) and the spider's keep
  (`SpiderKeep`) are cut into it right after its caves are joined, before anything else is laid,
  so only the gate levels change, and hold the way on. (There were arenas, side worlds behind a
  door in the gate level; they are gone.)
- **Code shape.** A `Boss` base (`scripts/bosses/Boss.gd`): its name, health (shown as pips or
  plates on the boss, not a HUD bar, in keeping with §"hud reduction"), its gate band, `slain()`
  telling `MapInfo` to record it and lift the seals, and the hooks every boss shares (hex, parry,
  dash, stun, shield). Each boss is a script extending it, a prefab, an art script in
  `scripts/riso/props/`, and whatever it needs built into its gate level.
  `Placeables` and `LevelGen.Type` get a `BOSS` type and a `GATE` exit look.

### What every boss must keep

- Procedural: laid out from the level's seed like everything else, never hand-placed rooms.
- Every tool has a role: the hex for reach, the dash to strike, the parry to stun, reflect or
  bounce (the pogo, so standing on a boss is a choice), the ward to forgive one mistake.
- Readable in the riso print: pink means danger, weak points in accent or bare paper, a boss's
  health as countable marks on the boss.

## 6. The bosses

The tuning numbers are first guesses for playtest. They are Normal's: on a harder difficulty preset
(`Difficulty`, §"Difficulty presets" in `DEEPER_PLAN.md`) each boss runs its own clock faster
(`Difficulty.haste`, 1.15 on Hard, the default, and 1.3 on Brutal), so its warnings, bites, rests
and crawling all come that much sooner: the worm's whole step, the spider's whole step (its webs'
regrowth too), the bramble's vines' cadence and its bulbs' seeds. A stun's length is not changed.

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
  way on is reached with the wizard's own hops in ten (the climb helper, `Climb.aid`, since
  removed, saw the shaft's ledges and lent ledges toward its foot, never inside it).

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

### The spider (crags / castle, its keep in the gate level)

*A first pass is built* (`Spider`, `SpiderKeep`, `SpiderWeb`, `SpiderWound`,
`prefabs/spider.tscn`). The crags' gate level (row −9, in every world) has the spider's keep built
at its top, part of the crags' castle.

- **The keep** (`SpiderKeep.cut`, hashed from the level seed, no world RNG). Cut right after the
  caves are joined and before the gondola and the towers, which are laid round it (the gondola
  stops below it); where it goes is the columns whose stone walls over the least of the caves and
  of the crags' other buildings. Its stone is kept whole and nothing else is placed inside it, and
  only the spider's gate levels change. 22 × 32 cells
  of masonry: a hall 18 wide, a roost of 8 rows of air under the roof, then 5 broken floors 4 rows
  apart (`STOREY`) and the ground storey. Every floor is broken by the **well**, a hole 3 wide in
  the same columns all the way down, and by a **stair hole** on alternate sides of it, with a
  one-way ledge under it halfway down the storey below, so each floor is climbed in two of the
  wizard's own hops. A doorway through each wall at the ground storey leads out to the caves, and
  the way on stands on the top floor against a wall, so the way up out of the crags is reached
  only up through the keep. What it holds is noted in `LevelGen.keep`.
- **Webs** (`SpiderWeb`): across every hole of the well and half the stair holes. In one the
  wizard moves at most 110 px/s across, rises 90 and sinks 55 (a jump stalls, a fall is slow), and
  the dash does not come back (`Player`). A hex bolt (flying on) or a dash tears one; it is spun
  again 12 s later. The spider passes through its own webs. Not yet: scuttling along them as
  paths. Every web is spun as the decor's cobwebs are, its lines kept evenly spaced as it grows (`docs/RISO_PRINT.md`); one across a hole is two small round webs side by side.
- **Its look** is one look in every world (a black widow: a pink hourglass, pink fangs), its legs
  set in poses rather than worked out step by step (`docs/RISO_PRINT.md`).
- **Spitting.** From the canopy, every 2.8 s (`SPIT_EVERY`, the first 1.5 s after it wakes), while
  it sees the wizard within 12 cells with no rock between and is not about to drop on them, it
  rears 0.4 s and spits a glob of web (`WebShot`, 600 px/s, straight). It sticks where it lands,
  on the wizard or the rock, as a **splat** (`Spider.splat`): a small web 1.4 cells across that
  holds them as a web does (slowed, the dash not coming back) for 6 s, or until a bolt or a dash
  tears it. Every second spit (`EGG_EVERY`) is an **egg sac** instead (`EggSac`), lobbed in an arc
  to come down where the wizard is; landed, it swells 2.5 s and hatches 3 **spiderlings**
  (`Spiderling`), which run along the floors at the wizard (170 px/s), hop steps and at the wizard
  just over them, and bite; any blow kills one or bursts a sac (`BroodWound`, no stars), and a
  spiderling withers after 9 s. No more than 9 of its brood are about at once, and they go when
  it dies.
- **The keep's crossbows** (`SpiderKeep.arm`, placed with the spider, no RNG draws): one to each
  floor, in the row the wizard stands in, on alternate walls, set into the hall's wall and shooting
  into the hall (a `Crossbow` with `inward`), stone behind, so nothing reaches them to break them.
  They shoot dead straight along the storey, as every crossbow does (`docs/DEEPER_PLAN.md`), and
  their arrows **pierce the spider's back** (`Spider.pierce`): an arrow meeting its body puts out an
  eye whatever it is doing, so luring it into a crossbow's line (it drops on the wizard where they
  stand) turns the keep against it. They wound its spiderlings and burst its egg sacs too.
- **Hunting.** Asleep on its canopy under the roof until the wizard comes within 16 cells; then it
  crawls along the roof to be over them (or over the hole nearest them, waiting), rears 0.45 s
  (fangs flashing pink), drops on its thread (1500 px/s) to where they were, holds its bite
  0.9 s, climbs back (400 px/s) and rests 0.9 s. It drops and climbs only through the middle of a
  hole (its body is about 140 px across).
- **Hard back.** A strike glances off unless it is **open**: biting (its face), stunned, or fallen.
  Open, any bolt, dash or parry (even one that only stuns, `Wound.least`) puts out one eye.
- **The thread.** A hex bolt or a dash across it cuts it (`Spider.thread_across`; the bolt ends
  there): it tumbles to the floor below and lies on its back 4 s, then scurries along that floor
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
- `tests/spider_test.gd` covers the keep and the fight (its crossbows, spitting, splats and brood
  too); `tests/capture_spider.gd`, `capture_spider_walk.gd` and `capture_spider_brood.gd` take
  stills.
- **Status / not yet.** First pass, untuned. Not yet: playtested by hand; webs as its paths; a
  cue for where it will drop beyond the rear; the spider's size against the 3-row storeys (it
  fills most of one) wants a look in play.

### The whale (sky, roaming on its top row; inside: its belly)

*A first pass is built* (`WhaleHunt`, `Whale`, `Belly`, `WhaleHeart`; `docs/DEEPER_PLAN.md`
§4c): the hunt, the trap, the open mouth, the belly of ribs and acid pools, and its heart. Not yet:
the belly's valves and rising acid, birds and gusts driven at the wizard by its passes.

The whale is not waiting in the gate level: it roams the sky's levels, and has to be tracked down
and trapped before it can be fought. Slaying it lifts the seal on the sky's gate levels as any boss
does.

- **One whale, one place.** It is in one sky level at a time, and the wizard has to find which.
  Small temples in sky levels reveal where it is, once opened by a sequence of winds (§7).
- **The top row.** It always stays on the sky's top row (its gate row, −15), moving only from
  world to world along it.
- **Driven by the winds.** It moves quickly, from level to level along that row, by the levels'
  winds (§7: still to begin with, set by their vanes): a level's wind carries it on the way it
  blows; in a still level it wanders. However it moves, it never goes far from the wizard (in
  worlds across).
- **Trapped by opposing winds.** Where strong winds blow against one another round it (the levels
  either side blowing into its level), it cannot leave, and the fight begins. Setting the winds of
  a stretch of the row to hem it in is the hunt.
- **Outside**, it cannot be wounded: hex bolts glance off, and its passes drive birds and gusts at
  the wizard. Its open mouth, on its slow turns, is a door.
- **Inside**, the belly is a side world of its own (a small dark level of ribs and stomach pools,
  Tom's "digestive system that is another level"): its heart (accent) hangs at the far end behind
  valves that open and close, and acid pools rise and fall (the "flooded / drain and fill" places
  idea, in small). Bursting the heart slays it, and the wizard is spat out at the gate.
- **Leaving** the belly without killing it puts the wizard back outside, the heart healed.

### The necromancer (cemetery, a crypt in the gate level)

*Built* (`Necromancer.gd`, `NecromancerWound.gd`, `necromancer.tscn`; `necromancer_test`,
`capture_crypt.gd`): it waits at the deepest floor of the gate level's first crypt (§7), dark
inside, its graves the crypt's floors (`LevelGen.place_boss`), and wakes as the wizard comes into
the crypt or within `WAKE_RANGE` (520 px).

- **Skeletons.** It raises skeletons from its graves, the same skeletons that sleep in every
  crypt's niches (§7), awake and walking at the wizard: one every `RAISE_EVERY` (4 s, sooner on a
  harder preset) while fewer than `RAISE_MOST` (3) of its own walk, out of the grave nearest the
  wizard but at least 3 cells from them. They drop no stars. A skeleton cannot be killed: a blow
  or a stun knocks it to pieces for a few seconds, and then it pulls itself together again.
- **Light.** It cannot be wounded in the dark: only while light falls on it (the wizard's lit
  flame, a lantern's light) does a strike land. In the dark a strike passes through it. So the
  fight wants the flame lit and close, the opposite of slipping past the sleeping dead.
- **The necromancer** blinks between its graves (`BLINK_EVERY`, 6 s, and at once when wounded),
  to the one furthest from every light, fading out and in, and its health is the candles on its
  staff (`CANDLES`, 7): a strike in light puts one out, whatever struck. Its touch hurts and a
  parry stuns it a moment. In the dark it is a shadow, and only its eyes and candle flames print
  over the darkness; in light it stands out in a pale robe. With the last candle out it crumbles,
  its skeletons with it, and its relic waits where it stood.

### The eldritch beast (institute, its chamber in the gate level)

*A first pass is built* (`Beast.gd`, `BeastWound.gd`, `BeastTentacle.gd`, `BeastSouls.gd`,
`BeastSoul.gd`, `beast.tscn`, `beast_soul.tscn`; `beast_test`, `capture_beast.gd`):
- **Its chamber.** In the beast's gate levels alone, `Institute.build` raises a chamber first of all
  (`CHAMBER_INSIDE`, 18 × 6 inside, in the lower half where it fits): a hall of marble with a flat
  floor and a doorway each side where a passage finds air. It holds the beast in the middle of its
  floor (`LevelGen.place_boss`) and nothing else. The exam hall still holds the (sealed) way on.
  Only the institute's gate levels changed.
- **Its souls.** It sleeps until the wizard comes into its chamber, within `WAKE_RANGE` (700 px),
  or strikes it. The first time it wakes in a run it sends its souls out (`BeastSouls.send`):
  `SOULS` (8) of them, and exploring is rewarded: for every `VISITS_PER_SOUL` (5) levels visited,
  one soul goes into a level the wizard has been to (in any band and column, mapped and known),
  and the rest are flung far (`far_flung`): into levels not yet visited, 3 to 12 worlds off the
  beast's to either side (`FAR_COLUMNS`), each in a band of its own in turn (`FAR_BANDS`: the
  garden, the cemetery, the crags, the institute, the sky). So a wizard who dived straight down
  (a dozen levels) keeps two souls near and hunts six across the world, while one who explored
  forty levels finds all eight in places they know. Never into a side world, a gate level or its
  own level. The order is hashed from the run seed. A soul's spot is chosen the first time its level is laid out (a free floor at least
  `SOUL_CLEAR`, 8, cells from the way in, dealt by the run seed) and kept (`RunState.souls`, saved).
- **A soul** (`BeastSoul`, a breach of its own) is a knot of pink flesh rooted in the floor with
  one of the beast's eyes in it, 8 blows (any bolt, dash or parry; `Wound.least`), no stars. Each
  time its level is entered, `GUARDS` (2) abominations are laid on the free floors nearest it, and
  while the wizard is near it lets more out, as a breach does. So abominations reach every band.
  Destroyed, it is gone for the run, deaths included. Souls are marked pink on the level page (at
  their spot) and on the worlds map (on the tile's top left corner, a faint pink tile for a level
  not yet visited, a chevron on the page's edge for one off it).
- **The beast** has one small eye for each soul sent, open while its soul lives, shut once it is
  destroyed (all shut while it sleeps). While any soul lives a strike glances off, its open eyes
  flaring. With every eye shut its great eye opens (paper, an accent iris): then any hex bolt, dash
  or parry wounds it, `CORE_HP` (9) blows, shown as pips over it.
- **Its tentacles.** Awake, it strikes every `ATTACK_EVERY` (2.4 s, sooner on a harder preset): a
  tentacle bursts up out of the floor under the wizard (`SLAM_REACH`, 2.6 cells), and every
  `SWEEP_EVERY` (3rd) strike one lashes along the floor from its flank to the chamber's wall, low
  enough to jump. Each shows where it will come first (a pink swelling, `BeastTentacle.WARN`,
  0.75 s), then shoots out, holds and pulls back. Its body's touch hurts too. Their touch is the
  beast's, so a parry stuns it and whips the tentacle back (and, once its eyes are shut, wounds it).
- **Its death.** With the last blow it sinks into the floor, is slain, and whatever souls are left
  go with it (`MapInfo.boss_slain`). Its relic waits where it lay. A lantern death heals it.
  The F7 panel's **Slay boss** works on it.
- Not yet: the souls placed with more thought (spread over the bands, or out where the
  institute's portals lead), a fight that changes as its eyes shut, and tuning.

Tom's idea: it spawns souls (tentacles, horcruxes) in levels already visited, which must be
destroyed. It stays the boss of the last band down, now the institute (§7); the abominations
rising into the institute's halls are its.

- **Souls.** When the wizard first enters its chamber, it sends out one soul per a few levels into
  levels the wizard has visited, in any band and any column (kept in those levels' records, so they are there on the
  next visit). Each soul is a pulsing thing (pink, on the map once sensed, and with awareness) that
  takes a few hits.
- **The beast** cannot be wounded while any soul lives; with each soul destroyed, one of its eyes
  closes. When all are gone it is vulnerable in its chamber, a short fight of tentacle sweeps to
  jump and parry.
- This fight sends the wizard back through the run, the institute's portals (§7) taking them to
  the far bands.

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
when it stops), stalactites that fall on whoever passes under (the falling rocks), rock-bug nests out
on the cliff, and crossbows built into the towers' and keeps' walls,
shooting out through arrow slits at the wizard and stopped only from inside (`Crossbow`). The spider has a first pass (§6).

- **Terrain.** Vertical: tall cliff faces with narrow ledges, chimneys and overhangs, collapsed
  from a sample drawn for it (`tests/make_crags_sample.gd`, symmetry 1 so up stays up), taller
  than wide (an archetype `scale` such as 0.8 × 1.6).
- **Castle ruins.** Some of the cliff is built: battlements along ledges, tower stubs, stair runs,
  arrow slits, broken arches. These come from the decor (`RisoDecor`, a `crags` plan) and from a
  structure pass that squares off some rock into walls and floors.
- **Gates.** Doors and switch gates fit its built corridors; climbing is its natural gate (wall
  climb and double jump matter here, so the relic from the bramble is often one of them).
- **Life.** Falling rocks (stalactites), rock-bugs and their nests, crossbows in the towers' and keeps'
  walls.
- **Realm.** Pale stone and dawn colours; wind-torn clouds below the cliffs.
- **The tower puzzle (owner's design; a first pass is built, docs/DEEPER_PLAN.md §4d).** The crags' own puzzle, as light is the cemetery's
  and wind the sky's: the gondola is the quick way up the cliff, and its stations are worked from
  the towers.
  - *Tiers.* Each station stands on a tier of the cliff of its own, reckoned for the puzzle (which
    station a tower answers to); no wall divides them (owner: no literal wall), and the cliff may
    well be climbed between them on foot.
  - *Stations.* No tolls or switch gates: each station is on or off, set by the towers. Its gate
    is the old toll gate's portcullis with a lamp, lit while it is on, and its board shows the line
    as a chain with this station marked, so it is plain whether it is powered and where it is. An off
    station is shut as a toll gate was (the car runs from an on station to an off one and back,
    never between two off ones, and no one steps out at an off one). On the first visit only the
    station nearest the way the wizard came in is on. The level record keeps them as left.
  - *Stops.* Five on the band's first row, rising to nine on its last, the levels as tall as they
    want; the towers smaller (two storeys) to fit the tiers.
  - *Towers.* Three to six a level, standing on the tiers (the bottom and top tiers have one at
    least; not every tier needs one, only enough to turn the whole line on in the end), some built into the level's left or right edge (half in the wall: their outer
    wall the level's edge, no doorway out that side). Each holds a switch in its top room that
    flips a set of stations (dealt by the level seed), shown on it as the line drawn straight,
    bottom to top, each station lit while on and dark while off, a ring round each it flips. Once flipped, a tower is locked until
    another tower is flipped (no undoing a flip at once).
  - *Spires and cold towers (a first pass is built).* Each watchtower carries an iron spire on its
    roof; an empowered strike on it (below) flips its switch under the same lock as by hand. A few
    watchtowers above the bottom tier are cold: their switch does nothing until one empowered
    strike on the spire wakes it for good. So a crags level reads differently once a spell is
    tempered.
  - *What is checked as a level is laid out.* Only the switches' logic, not whether a tower or a
    station's landing is reached on foot (owner: no reachability guarantee): taking each tower as
    reached from its own tier's station, there is a way up from the bottom tier and a way down
    from the top one, the two need different tower sequences, and some sequence leaves the whole
    line on for easy travel after. The sets are dealt again (hashing the seed, no draws) until
    they pass.

- **Lodestones and empowered spells (owner's design; a first pass is built, docs/DEEPER_PLAN.md
  §4d).** Every other band leans on lanterns, the dash, the meta spells or jumping; the damage
  spells are the slot the crags give a puzzle to.
  - *A move, not a stock.* Holding the Spell button 0.4 s casts the damage spell empowered; a quick
    press casts as ever, and the guard still goes up on the press. Empowerment comes back on its
    own: 60 s after the first lodestone, each further stone (any spell, once each) cutting a
    quarter off for every spell, down to 10 s from the seventh.
  - *Learned per spell.* A lodestone, a standing stone of dark iron ore, is dealt one damage spell;
    touching it tempers that spell for the run. A spell not tempered casts as ever when held.
  - *Rare and spread out.* One crags level in four: along each crags row, every stretch of 24 worlds
    holds each spell's stone once, hashed from the row and the stretch, so none is more than 23
    worlds along a row. High on the cliff, in sight of the gondola's track, never behind cracked
    rock.
  - *Found from the gondola.* Riding the car up inks the map round it; bringing it to the top station
    inks every level round whole, and a lodestone there shows on the worlds map. Shrines do not
    point to lodestones.
  - *All cracked rock, unified.* In every band cracked rock breaks only to an empowered spell (a plain
    bolt chips it, the dash does nothing), each spell its own way (the hex bores, the seeker homes on
    a spire, the slash cleaves, the nova shatters a ring, the push breaks the cell before it, the
    lunge rams), and cracked walls never stand at a door, though a key may be behind one. Secret
    rooms still open to walking in.
  - *Not built yet:* loose boulders for the push to shove.

### The cemetery: crypts, light and darkness (rows +4 … +9)

The cemetery stays as built (`docs/DEEPER_PLAN.md` §4b): its terraces, realm, decor, moths, fog,
wraiths, and its chasms gated by bells. What it gains are crypts, and light that matters.

Decided (October 2026):

- **Crypts.** One or two a level. They act as the crags' towers do (a building of masonry with
  doorways, something worth having deep inside), but bigger, and their insides are collapsed by
  WFC from a sample of their own (passages, burial niches, ossuary rooms), not built by hand.
  Inside it is completely dark: nothing shows but what a light lights.
- **Light by place, not by band.** The terraces stay moonlit (the shade every band has, no gloom);
  a crypt's inside is fully dark. The darkness is a property of where in the level, not of the
  whole level.
- **Snuffing.** Stations (snuffing fonts) stand near the crypts' doorways: at one, the wizard puts
  out the lantern's flame they carry, until they dash (or light a lantern). Their lantern still
  protects them. (Changed October 13: at first a snuffed flame was lit again only at a lantern and
  left the wizard unprotected.)
- **Light gates.** A crypt's doorway may be a sun gate, up only while light falls on it, or a shade
  gate, up only while none does: the crypt is entered lit, waking its sleepers, or snuffed.
  (Changed October 20: no longer laid; the crypts' sun and shade blocks do this work.)
- **Light and dark each have their uses.**
  - *Lit*, the wizard sees in the crypts, the wraiths freeze in the flame's light (they are
    light-shy), and the necromancer can be wounded.
  - *Snuffed*, the wizard slips past the skeletons sleeping in the crypts' niches (light falling on
    one wakes it) and hides from the moths, but the wraiths hunt them, and in a crypt they see
    almost nothing.
- **Skeletons** sleep in the crypts' niches and wake when light falls on them, then walk at the
  wizard. They cannot be killed: a blow or a stun knocks one to pieces for a few seconds, and
  then it pulls itself together again. The necromancer raises the same skeletons (§6).
- **Wraiths** hunt only a wizard whose flame is out, and are light-shy: in light they freeze.
  Nothing hurts them.
- **No ghost planks.** The chasms stay gated by bells.

### The institute (rows +10 … +15)

The last band down, in place of the catacombs: a sunken institute of magic, with a library among
its wings. Its students and masters are strong spellcasters; abominations rise into it from the
deep, where the beast lies.

*A first pass is built* (`docs/DEEPER_PLAN.md` §4e, `InstituteArchetype`, `Institute`): its sample
of rooms and corridors, its halls (an exam hall holding the way on, the library's stacks, lecture
halls with tiers), its realm, backdrop and decor (marble slabs, great columns, bookcases
everywhere); students, masters (each teaching its spell by a lesson once beaten), proctors and
librarians, all printed after the original wizard (students bareheaded); abominations that bud
copies of themselves until 32 are about, and breaches that spawn them and must be closed; the
departments' portals with their ways back; the beast in its chamber, its souls
sent out across the run (§6); and a first pass of the timetable (§9): periods moved on by bells,
hall doors kept by them, scholars calm where the wizard belongs, exam papers from the classes
attended (fetched from the departments' field levels, or lifted from an empty hall's lectern),
learned at lanterns, instructors who leave a top-tier paper. Not yet: tuning in play.

- **Terrain.** Halls of different kinds, built by a structure pass (as the crags build their
  keeps) into a sample of rooms and corridors: lecture halls whose tiered seats climb like stairs,
  the library's stacks (long galleries one over another, joined by ladders, giving casters long
  sight lines and shelves to break them), laboratories, cloisters and a bell tower.
- **The gate is the timetable.** There is no exam hall: the way on stands in the classroom the
  most classrooms in from the way in, which asks besides for another department's exam paper, and
  the way through runs through classrooms that open only to a wizard carrying the right exam
  paper, each costing a ring. Papers come from the classes the wizard attends, each sent to the level a department's
  portal leads to and fetched from there (a field trip), and are learned at lanterns. See the
  timetable (§9).
- **Students and masters.**
  - *Students* come in numbers, casting weaker spells that now and then misfire; they scatter
    when their master falls.
  - *Masters* are few and strong. Each has mastered one of the wizard's own abilities (`Abilities`),
    shown by its glyph (`RisoGlyph`), and casts it. A master beaten teaches the wizard a tier of
    that ability, as a shrine would.
  - *Staff*: proctors shield the students near them (`Shield`); in the library, librarians cast
    silence, an aura in which the wizard's spells do nothing (as sleep fog does).
- **Abominations.** Things of the beast's rise up out of the deep into the institute's halls. They,
  the students and the masters fight one another as well as the wizard, so a fight has three sides
  and the wizard can set one against another (lead abominations into a class, or let a master
  spend itself on them).
- **Departments and their portals.** Each department studies a region, and its portal leads to a
  real level there, a place on the grid with its own record: botany to the garden, necrology to
  the cemetery, geology to the crags, astronomy to the sky. A portal never leaves its column: it
  leads to a level of that band in the same world (the same `x`), so the institute is the quick way
  up and down a column, as the sky is the quick way along a row (below). Which of the band's rows
  it leads to is dealt from the level seed, and is told to the wizard (on the portal and on the
  map) before they step through. A way back opens where they arrive and lasts until they use it.
  Portals pay no heed to seals: a geology portal reaches the crags with the bramble alive. (The
  exception to "nothing skips a seal", §4.)
- **The beast's souls** can lie in visited levels of any band and any column (§6). The
  departments' portals shorten the hunt up and down the institute's own column; the rest is walked,
  or ridden on the sky's balloons.
- **Look and realm.** Roman-esque architecture (colonnades, round arches, porticoes, coffered
  vaults, statues in niches) beside stuffy wooden libraries (dark panelling, tall shelves, ladders,
  reading desks). Deep brown and marble: the rock printed as deep brown wood and earth, the built
  parts as pale veined marble, gold kept for rewards.

### The sky reworked: the elements (rows −10 … −15)

*A first pass is built* (`docs/DEEPER_PLAN.md` §4c): the level's wind set by its vanes, in gusts
(a spell of stillness, then a strong sustained gust); balloons riding it along the row; temples
opened by a sequence of winds; the white realm under a stormy sky; and the whale, roaming the top
row, trapped by opposing winds, fought at its heart in its belly. Not yet: lightning that strikes
(the storm only flashes far off), the wind pushing birds and shots.

The sky is built (`docs/DEEPER_PLAN.md` §4c): islands, gaps crossed on a crosswind its vanes set
blowing, pads, clouds that give way, updrafts, birds, shields and rebounding shots. Its gate is the
cemetery's in another coat (a vane is a bell, a crosswind a bridge), and it has no hook of its own.
The rework makes it the band of the elements, where the institute is the band of people.

- **The level's wind, set by its vanes.** Decided: every sky level has one wind, steady, blowing
  across the whole level, left or right. It starts still (most levels begin with no vane on).
  - Each vane points one way, left or right, dealt with the level and never changed; it is
    either off or on, and can be switched back off.
  - The wind blows one way at a time, the way of the vane last switched on. Its strength is the
    number of vanes that are on and point that way; vanes on that point the other way do nothing
    until the wind is turned their way again (by switching one of them on), when the strength
    becomes their count instead. Switching off a vane that points the wind's way weakens it by
    one; with none of its way left on, the wind is still.
  - The level record keeps which vanes are on and which way the wind blows.
  - This replaces the still crosswind over each gap: a crossing the wind helps, strongly enough,
    is open; one it fights is shut until the vanes say otherwise. The vanes keep their chains (a
    key colour, or a switch).
  - Proposed: the wind pushes the wizard (and birds, rebounding shots, moths) in the open air,
    harder the stronger it is; the lee of an island (the air its rock shelters downwind) is calm,
    so the islands are harbours between crossings.
- **The storm.** Proposed: lightning strikes the highest points now and then (warned pink a moment
  before), so a vane on a peak is risky to reach; rods on some islands draw it (a strike led to a
  rod powers a gate or a lift).
- **Balloons: quick travel along the row.** Decided: balloons moored in sky levels can be ridden,
  and carry the wizard to another world (another column, the same row) by the level's wind: its way
  says which way along the row, its strength how far, in coarse steps that are hard to build up
  (proposed: a world over for every few vanes on, so a strong wind of many vanes carries two or
  three worlds and a weak one only a little or not at all; tuned so most levels hold enough vanes
  for one step). In a still level a balloon goes nowhere. The counterpart of the institute's portals
  up and down a column. Proposed: where a balloon would go is shown before boarding (as a
  portal's is), and it stays moored where it lands, ready to ride on by that level's wind.
- **The whale** (§6) roams these levels, driven by their winds: trapping it between opposing
  winds is how its fight begins. It keeps to the sky's top row.
- **Temples.** Small temples, built on some islands, reveal where the whale is and hold a hoard
  of star clusters. Each is locked by a sequence of 5 to 9 winds (repeats and all), shown on its
  frieze, entered by switching on the vanes of its level in that order of ways: the right way lights
  the next step, the wrong way resets it (a repeat is two of the same way in a row). (An earlier
  idea, a sequence set across the levels of its row, was replaced by this.)
- **Realm.** White first: the islands and clouds printed white, the sky's main colour, with the
  gold of its stars and the pink of its dangers on it, against a dark, stormy sky behind (in
  keeping with dark, low-contrast backgrounds, `docs/RISO_PRINT.md`), so the islands stand out
  and the gameplay's knockouts still read.
- **Drifting islands** were liked but are parked: the terrain is a fixed grid of cells, and
  islands that move would need it to change as you play (§9).

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
   traversability to be relaxed, especially beyond the garden; since removed, with `climb_test`, as
   traversability is not enforced in any world). `layout_fingerprint_test` re-pinned for the up levels (their dressing
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
   level did not. `gate_test` and `capture_gate.gd` show the stand-in in the necromancer's gate
   level (arenas are gone).
5. **Crags and castle**: *a first pass is done*: sample, structure pass, decor, realm, and the
   gondola (`CragsArchetype`, `Gondola`; `crags_test`, `capture_crags.gd`; the crags' layouts
   changed and `layout_fingerprint_test` was re-pinned for them alone). *The spider and its keep:
   a first pass is done* (§6; `spider_test`, `capture_spider.gd`), now built into the top of its
   gate level (only the spider's gate levels changed; `Arena` is gone and every boss fights in its
   gate level). *Its life is done*: stalactites (the falling rocks), nests out on the cliff,
   and crossbows built into the towers' and keeps' walls (`crossbow_test`; the crags' dressing changed and
   `layout_fingerprint_test` was re-pinned for them alone). Then tuning
   the spider in play.
6. **Cemetery crypts and light**: *done*: crypts (collapsed by WFC, one or two a level), darkness
   by place, snuffing fonts, light-shy wraiths and sleeping skeletons (`Crypts`, `Lamplight`,
   `Snuffer`, `Skeleton`; `crypt_test`, `capture_crypt.gd`), the wraith's dart and the skeleton's
   swipe each with a tell (`crypt_attacks_test`); and **the necromancer** in its crypt,
   wounded only in light (`Necromancer`; `necromancer_test`). The cemetery's and catacombs' layouts
   changed and `layout_fingerprint_test` was re-pinned for them alone. Then tuning in play.
7. **The institute**: *a first pass is done*: halls and stacks, the exam as a battle, students,
   masters (teaching tiers by lessons) and staff, abominations that multiply and the breaches they
   come from, the departments' portals (`Institute`, `Scholar`, `Abomination`, `Breach`, `ExamDoor`,
   `Lesson`, `Department`, `WayBack`; `institute_test`, `capture_institute.gd`). The catacombs'
   stand-in is gone; the sight test's deep dark moved to the crypts. Only the institute's layouts
   are new; every other level is laid out as before. *The eldritch beast: a first pass is done*
   (§6): its chamber in its gate levels (only they changed), its souls sent across the run with
   abominations round them, its eyes, tentacles and great eye (`beast_test`, `capture_beast.gd`).
   *The timetable is built* (§9; settled in five passes on 2026-10-17): the great bell and its
   cords, departments with their own rhythms and tier rules,
   prerequisites, passing time and belonging, exam papers sent on field trips and learned at
   lanterns, instructors, classroom lecterns as pigeonholes, glyph seals (since taken out), abominations quiet in
   class and surging in passing time, and the beast fed by rings (`Timetable`, `SchoolBell`,
   `Lectern`, `KeyRing.paper`, `MapInfo._attend`, `study`, `instructor_fell`;
   `timetable_test`, `papers_test`, `capture_timetable.gd`). Only the institute's dressing changed
   (its halls: classrooms in place of lecture halls and the exam hall; `layout_fingerprint_test`
   re-pinned for it alone); the collapsed terrain did not. On 2026-10-18 the way on moved into a
   classroom and the great bell into the corridors the way in opens on (the institute's dressing
   re-pinned again, the terrain the same). Then tuning.
8. **The sky reworked**: *a first pass is done*: the level's wind set by its vanes, in gusts;
   balloons riding it along the row; temples opened by sequences of winds; the white realm and its
   storm; and **the whale**, roaming the top row on the winds, trapped, its belly and heart
   (`balloon_test`, `temple_test`, `whale_test`, `unit_test`; `capture_sky_rework.gd`; the sky's
   dressing changed and `layout_fingerprint_test` was re-pinned for it). Then lightning strikes and
   the wind on birds and shots, and tuning.
9. **Tuning pass** with playtests: boss health and timing, relic odds now that bosses give one,
   prices by distance.

## 9. Open

- **Drifting islands** (the sky): islands moving on currents, gaps opening and closing. Liked, but
  the terrain is a fixed grid of cells laid out once (WFC, then the passes), and the rock, sight
  and the map all read it as still; moving islands would need them as bodies of their own.
- **Past the last bands.** Below the institute and above the sky: a final place where the branches
  meet (hyperspace?), the outer bands repeating harder, or the run won at the bottom or the top.
- **What a boss's relic is.** A move not yet known (proposed), or always the same move per boss
  (the bramble wall climb, the worm double jump...), which would make each branch's order of
  abilities designed rather than dealt.
- **Gate level size.** Whether gate levels are the band's ordinary size or larger. The worm and
  the bramble fit in the ordinary size (the bramble's shaft is half the level tall).
- **The ward and bosses.** Whether boss hits break a ward charge like any hit, or several.
- **The institute's timetable** (liked; built, `docs/DEEPER_PLAN.md` §4e, `timetable_test`,
  `papers_test`): the institute's band-wide puzzle, as light is the cemetery's and the tower
  switches are the crags'. Nothing in it happens unless a bell is rung or the wizard goes
  somewhere: there is no clock anywhere. It was settled in five passes on 2026-10-17, its
  departments given their own rhythms and tier rules on 2026-10-18, and that day made the puzzle
  one that has to be done (the way on, stolen papers) and, at the owner's word, simpler (each
  classroom's own cycle, a class started and ended by bells, bells never twice running); this is
  how it stands.
  - *The bells are the switch.* Bells hang out in the corridors (at least two, spread apart, one in
    the corridors the way in opens on), and a cord hangs in each classroom and the library. A level
    is first met in passing time, and the bells go passing time, class time, passing time, class
    time. Any bell rung in passing time begins class time: a wizard in a classroom (enrolled, its
    class in session) attends it, one anywhere else is truant. Walking out of the class ends it, no
    bell needed; a wizard truant in the halls ends it by ringing another bell. Either way the period
    is over: the level moves on to the next of three in its day, passing time begins, every class is
    seated afresh, every scholar calms and each department that met climbs or drops (below). One who
    gets into a class in session in class time (a warp) is late: not truant, attending nothing.
    Classroom doors stay shut until the wizard walks up to them, open from inside always, and from
    outside only in passing time; in class time every classroom is shut to those outside. No cord
    rings twice running, as a crags tower cannot be flipped twice running. Every ring feeds the beast
    for the run.
  - *Abominations and the beast by the bells.* Abominations keep still during a class and act up in
    passing time, slowly at first and faster with every period rung out in the level (their growth
    and launches, and how often a breach lets one out); fewer are laid with a level. The beast is weak
    unfed (3 blows, 1 soul, slow strikes) and grows with every ring of the run, up to 15 blows and
    12 souls. Proctors walk the corridors in a period.
  - *Departments, cycles and tiers* (rules decided 2026-10-18, after modelling six variants; the
    cycles made simple that day). A level has up to five classrooms, each a floor and a gallery with
    doorways at both ends, every department given one. Each department has three subjects
    (astronomy hex, seeker, warp; geology slash, lunge, rift; botany push, levitate, ferry;
    necrology nova, astral, awareness). Each classroom is in session two periods of the day's
    three and closed for one, from a place in that cycle dealt by the seed and shown over its doors;
    in session it teaches its department's subjects one a session (geology's held two). Each
    department has a tier, the tier its classes teach, and when a period is rung out each one that
    met climbs or falls back to I: botany rises when you attended it; astronomy when you attended
    another class; geology when the class you attended was another department's standing at
    geology's own tier (strata); necrology when another department crashed back to I from II or higher. Out of session, a
    department neither moves nor counts. No ring raises a tier by itself, and the tiers you want
    cost others: harvesting astronomy's paper crashes it, feeding botany starves necrology, and
    geology climbs only in step with another department, a class at its own level each rung.
    The timetable model (`tools/timetable_model.py`) found two faults, both fixed: a botany class
    the wizard cannot be taught (levitate, without the relic) broke botany's streak (now any class
    sat counts as attended, taught or not, so there is no special case for botany), and the bell
    rings in passing time when no class is open to the wizard, so they are never stuck (with
    corridor bells that ring any time, that rule is gone). With the simpler cycles geology's old rule
    (rising when strictly below every other department meeting) gave geology III in only 14 of 40
    real levels and geology IV in none, so twelve rules were modelled and strata chosen
    (2026-10-18): geology III in 38 of the 40, IV in 31, astronomy IV in 34, and it holds up best
    with a key ring of one. Levitate and astral are taught only to a wizard who already has them (relics stay
    how the big moves are found). Doors show the subject taught now, its tier and the prerequisite;
    the rotation is learned by play.
  - *Where the wizard belongs.* Scholars are calm while the wizard is where they belong (the
    corridors in passing time, the library, a class in session they are enrolled in) and turn on
    them, and those near with them, when they see them truant (real line of sight, so slipping past
    one facing away works): a local fuss, calmed by the next bell. Casting a spell or striking
    anyone where scholars see it turns them anywhere, and so does carrying a stolen paper. The abominations care for none of it, and
    leading them into a class still works.
  - *Prerequisites.* A class of tier II or higher asks for a paper of one other department (any of
    its subjects), a tier lower, held or carried; tier I asks for nothing. The four ask round in a
    ring: astronomy geology's, geology botany's, botany necrology's, necrology astronomy's.
    A classroom's doors open only to a wizard enrolled so, so the way through a level runs through
    classes and depends on the papers carried and the rings rung. A wizard who gets in another way
    (a warp, a rift, a projection) is put back out. The prerequisite is a department and a tier,
    never one spell.
  - *The way on* stands in the classroom the most classrooms in from the way in, and asks besides
    for an exam paper (not a spell held) of any other department at II or higher, which it takes as
    the wizard goes through (the classroom opens on its class's prerequisite like any other). Each department has its colour, on its papers, doors and portal. On 40 real levels
    the timetable model gets a wizard with nothing on their ring through in 2 to 6 rings, 3 at the
    median, in 36; the rest are left as dealt (the owner's call): their way runs through papers from
    other levels, a feature meant for the cemetery and the crags too.
  - *Exam papers.* Attending a class is being in its classroom as a bell begins class time and
    walking out of it when done (field trip or not), its master there and not turned on the wizard; a class of a move the
    wizard lacks counts as attended, with no paper. Its paper (the subject at the tier
    taught) is sent to the level its department's portal leads to, to be fetched: a field trip.
    Resitting a class with its paper in hand grades the paper up instead. Sneaking: an empty
    classroom's lectern holds the next class's paper, lifted without the field trip, and stolen:
    while the wizard carries a stolen paper (a lectern's, or an instructor's prize), the scholars
    turn on them. Each
    classroom's lectern is a pigeonhole for one paper, swapped with the one picked up last. Papers
    are keys: carried on the key ring, a slot each, kept through a death.
  - *Papers are spells.* A paper is a spell known but not held, of any ability that takes a slot.
    At a lit lantern the wizard studies: the oldest paper carried that teaches something takes its
    slot, and the spell it puts out comes back as a paper. Shrines, lessons and relics hand back
    what they put out the same way. So the key ring is the wizard's spell book, anywhere in the run.
  - *Instructors.* A classroom's master is the institute at its strongest: far tougher, quicker,
    its whole class turning with it, and, turned on the wizard, moving as its subject does
    (warping, rifting, ferrying, projecting itself, levitating, seeing through rock). Beaten by
    the wizard it leaves a stolen paper of its subject at the spell's top tier, once a room: the
    taste of an exam.
  - *The library* (reworked 2026-10-19; its glyph seals taken out): a safe place in class time,
    where a bell rung by the wizard ends it without truancy; a big timetable board on its ground
    floor's back wall, every classroom's day at a glance, now's column with its tiers and tags; and a
    reading desk that teaches a paper free in class time, once a period. Learning a paper at a
    lantern burns the lantern out.
  - *Tried and dropped.* A lesson as a trial: the master's spell lent for it and used for what it
    does on mock seals, passed for a tier, with exam prizes and an exam made tougher by rings. Each
    spell needed a special case kept up as spells changed, so exam papers replaced them. Seals
    asking for a spell's literal use (a hex bolt from far off, a seeker's bolt round a corner, a
    lunge across a gap) went with them. Then the exam itself: an exam hall holding the way on, open
    in the last period to a wizard carrying papers, an examiner rising for each and the papers
    learned once all were beaten. The field trip already did the learning's work, so the exam went,
    its examiners' moves given to the instructors, and with it the run-long list of spells taught
    and the library's lectern that gave them back: papers are the record now. The day of four
    periods went with the exam period, for the cycle of blocks.
  - *Planned, not built: more ways to work papers.* Merging, at a lectern: two papers of the same
    subject and tier made one a tier higher, freeing a slot for the price of a paper. Stapling, at a
    lectern: two papers of one department pinned into a bundle taking one slot and serving as
    either prerequisite; held back, as it eases the key-ring pressure that makes cycling papers a
    puzzle.
  - *Not yet:* classes moving from hall to hall and students pouring into the corridors in passing
    time; the library's ladders sliding to the bay a period uses; a timetable board, and the
    timetable on the map. Checking that
    some order of rings leads through will not be built: a level is left as dealt.
  - *Relics won from masters* (decided 2026-10-18, the institute only): an institute level's relic is
    carried by a master out in the level and left where it falls to the wizard, and an instructor
    teaching levitate or astral leaves that relic to a wizard who has not found it. The other bands
    keep their relic rooms.
