# Somnonaut: the design review plan (November 2026)

The design review of the garden demo and the whole game is in the owner's task list (the Google
Doc, "Design review (November 2026)"): the review itself, the same review checked against the
code, the demo's length measured, and the improvements and star sinks that came out of it. The
owner went through it on 9 November 2026 and wrote a word under most items. This is the plan those
words make: each thing to build with what the code does now (*Now*), the owner's word on it
(*Decided*, quoted), what to do (*To do*), what it moves in the levels, and the tests that cover
it. What was refused, put off or left without a word is listed after, so nobody builds it by
mistake. The order of work is at the end. Nothing here is built yet.

Three rules of the project shape most of it, so they are said once here:

- A level is laid out from its world and row alone (`Rules.level_seed`), the same on every visit
  and in every run. Which column a boss is met in comes from the run's seed (`Bosses.column`). So
  nothing about a boss's column can go into a layout: it is decided as the level is loaded, by
  hashing the seed and the cell, never by a draw from `world.rng`.
- A new pass in the layout goes last, and a meant change to the layouts is said in the report,
  with `layout_fingerprint_test -- update`.
- Traversability is not enforced. The marks of section 3 tell the player something; they move
  nothing, carve nothing, and no test fails a level over them.

## 1. The demo's garden: four rows either way

*Now:* the demo's layout is the `garden` line of `Bands.LAYOUTS` (`scripts/worlds/Bands.gd`), with
`"rows": GARDEN_ROWS`, 7: rows −7 to +7, the worm's gate at +7 and the bramble's at −7. `"rows"` is
rows either side of the start. Each boss's column is dealt within that many columns of the start
(`Bosses.spread`), so a boss is looked for over 15 × 7 = 105 levels.

*Measured* (200 runs, gates sealed, in level crossings; the way home is as long as the way out):

| Garden rows | To the worm | To the bramble | Both, each trophy carried home | Worst run |
|---|---|---|---|---|
| 3 | 6.5 | 7.2 | 27 | 52 |
| 4 | 8.0 | 9.8 | 36 | 66 |
| 5 | 10.2 | 10.6 | 42 | 80 |
| 7 (now) | 13.3 | 14.1 | 55 | 96 |

At 4 rows a boss is looked for over 9 × 4 = 36 levels. Its gate level has about 860 open cells, 46
foes on Hard and a 48-star toll, against about 1,200 cells, 60 to 68 foes and 115 stars at row 7.
The nearest relic is 4.0 levels away.

*Decided:* "yes" (owner, 9 November 2026).

*To do:*
- Give the demo's garden its own length: a constant beside `GARDEN_ROWS` (say `DEMO_GARDEN_ROWS`,
  4) on the `garden` line. The whole game's garden keeps its 7.
- The rows that lean on the gate follow by themselves, as they ask the bands rather than count:
  the wormlets' rise toward the gate (`GardenArchetype.place_worms`), the trophy stands
  (`Bands.bosses`), the atlas.
- A demo save from before has its bosses and records on the old gate rows. Either raise
  `RunState.SAVE_VERSION` so it is dropped, or say in the release note that an old demo save
  should be deleted. To decide when building.
- Neither boss's strength reads its row (nothing in `Worm.gd` or `Bramble.gd` does), so the fights
  are as hard at row 4 as at row 7, with a wizard three rows poorer in shrines. Play both bosses
  on Hard and Normal from a fresh run before calling this done, and note what was found.

*Layouts:* the demo's rows ±4 become gate levels and its rows ±7 ordinary garden levels, so those
four rows change in the demo. The whole game is untouched, and `layout_fingerprint_test` on the
default layout should say so.

*Tests:* `bash tests/run.sh -l garden full`; `bands_test`, `world_atlas_test`, `trophy_test` and
`tutorial_test` are the ones most likely to notice. Any that pinned a row is fixed by asking the
bands (`Bosses.row_of`, `Bands.garden_rows`), not by pinning the new one.

## 2. Pointing to the bosses through the world

*Seen:* a boss's column is found by walking gate levels until it is there, or by a shrine's hint.
The header of `Bosses.gd` says so itself: "Nothing marks its column".

*Decided:* "I think stronger rumbles and more wormlets as you get closer to the worm" and "More
vines and shooting plants" toward the bramble (owner, 9 November 2026). The shrine's hint stays as
the short cut, and becomes easier to buy (section 7.1).

*Now:*
- Small worms (`LevelGen.Type.WORMLET`) already grow in number down the rows toward the worm's
  gate: `WORMS_PER_K` 0.8 a thousand cells, up to twice that at the gate row (`WORMS_TOWARD` 1.0).
  Nothing changes from column to column.
- Seed pods (`SeedPod`, the bramble's bulb grown from a garden wall on its own: the "shooting
  plants") lie at `PODS_PER_K` 1.0 in every garden level from depth 1, the same up as down.
- The rumble is in the worm's fight only (`Worm._rumble`: a shake and a spit of dirt as it is
  about to break out of the rock).
- The thorn vines (`BrambleVine`) are in the bramble's shaft only.

### 2.1 How near a boss is

One scene-free rule, used by everything below: `Bosses.near(name, at, run_seed)`, 1.0 in the
boss's own level falling to 0.0 at `SIGN_REACH` levels away (columns and rows added; 4 to begin
with, the demo's whole garden at four rows), and 0.0 once the boss is slain or on the far side of
the start (the worm's signs are below the start, the bramble's above). Checked in `unit_test`.

### 2.2 The worm: rumbles through the levels near it

*To do:* in a garden level with `near(&"worm") > 0`, the ground rumbles now and then: the screen
shakes and dirt falls, harder and more often the nearer the worm (`RUMBLE_FAR` seconds apart and
faint at the edge of its reach, `RUMBLE_NEAR` apart and strong next door). The dirt falls on the
side of the screen the worm's level lies to, so a rumble says which way as well as how near. A
small node of its own that `MapInfo` adds on arriving (say `scripts/bosses/WormSign.gd`), using
the worm's shake and the `impact` burst. It is timed by the game clock, touches no layout and
draws nothing from the world RNG. Windowed test runs are muted and out of sight already.

*Open:* whether it has a sound of its own (a low roll), which the playtest plan's music work
would carry.

*Tests:* a new `worm_sign_test`: none far off or above the start, some near, more next door, none
once the worm is slain.

### 2.3 Wormlets and pods: more of them nearer

Two parts, one cheap and one that changes the layouts.

*By row* (the layout knows its row): give the pods the rise the wormlets have, toward the
bramble's gate (`PODS_TOWARD`), and steepen both if the rise does not read in play. This is a
change to `GardenArchetype`'s counts only.

*By column* (the layout cannot know the run's seed): the level lays spare wormlets and spare pods
as well as its own, in a pass of their own after everything else, each marked as a spare with its
order (`extra_info`). The loader leaves out the spares this run's nearness does not call for, as
it already leaves the boss itself out of the gate levels it is not in
(`LevelLoader.place_cell`, by `Bosses.column`): none at `near` 0, all of them in the boss's own
column. A spare slain is recorded by its cell like any foe. Spare counts go through
`foes_per_area`, so the difficulty presets scale them.

*Layouts:* the spares are new draws, so every garden level's dressing changes from the spares'
pass on. Put the pass last so nothing laid before it moves. `layout_fingerprint_test -- update`,
said in the report. In the whole game this touches the garden band only.

*Tests:* extend `worm_test` and `bramble_test` (or a new `boss_signs_test`): the same level built
twice is the same; loaded in the boss's column it holds more wormlets (or pods) than loaded
`SIGN_REACH` columns away; a revisit holds the same ones (`revisit_test`).

### 2.4 The bramble: vines in the levels near it

*To do:* a thorn vine rooted in a garden wall on its own, as the seed pod is the bulb on its own.
`BrambleVine` nearly stands alone already (its haste allows for no bramble), but its starting
phase reads the bramble's level seed, so it wants a `setup` that takes the level's. Then the
usual road for a new hazard: a `LevelGen.Type` (say `VINE`), its `Placeables` entry, its art kind
in `RisoProp.KINDS` (the vine prints itself now), and a place in `GardenArchetype` in the rows
above the start, more toward the bramble's gate, with spares by column as in 2.3. A vine lashes
`REACH` 2.5 cells out of its wall on a steady cadence and a parry stuns it, so it asks for timing
or the guard, not for a move the wizard may lack.

*Open:* whether vines lie only within the bramble's reach (a sign, and nothing else) or thinly
through the whole upper garden (a hazard that thickens). The first keeps them a clear signal.

*Layouts:* with 2.3, one update of the fingerprints for both.

*Tests:* in `bramble_test` or the new signs test: a vine on its own lashes, hurts only while out,
is stunned by a parry, and is the same on a revisit.

## 3. What a spot wants: marks for "not yet"

*Seen:* a spot the wizard cannot reach yet looks the same as one they have simply not worked out,
so "come back with a move" and "try harder" are told apart only by failing.

*Decided:* "This is a great idea and can be introduced generally into the procedural generation"
(owner, 9 November 2026).

*Now:* the pieces exist apart.
- `Reach` (`scripts/worlds/Reach.gd`) is a rough reach for the wizard over a level's cells:
  footholds, and hops of up to `UP` 2 cells up and `ACROSS` 4 across. Hyperspace already asks it
  twice, once as the wizard is and once with a relic's longer hop (`Hyperspace.RELIC_ACROSS` 7).
- The generator already knows some spots are left to the relic moves: `LevelGen.relic_chasms`
  (chasms with no bell or vane, from `Rules.RELIC_NEED_FROM`, in the cemetery and the sky).
- `RisoGlyph` draws every ability's mark, fitted to a roundel (`RisoGlyph.fit`); `RisoMarks` is
  shared by the level, the map and the HUD.

*To do:*
- A scene-free pass, run once a level is laid out, on the worker thread with the rest (say
  `scripts/level/Wants.gd`): grow the rough reach from the level's ways in; for each thing worth
  reaching that it misses (a way on or side door, the shrine, a lantern, a key, a star cluster, a
  relic's room, a plot, an ink well), grow it again as each relic move would have it and note the
  least move that gets there. The result is kept beside the layout, `LevelGen.wants` (cell to
  move), not in `objects`: no RNG draw, no change to any layout or fingerprint.
- One table of what each move adds to the reach. A first pass covers what `Reach` can already
  say: higher (double jump) and further (levitate). Climbing a wall and blinking through thin
  rock want hop rules of their own and come second. Where more than one move would do, or the
  reach cannot say which, the mark is the relic's own, not a move's.
- The chasms left to relics get the mark at each lip, from `relic_chasms`, with no reach needed.
- In the level: the move's glyph in a small roundel by the spot, in the quiet inks (it is a
  note, not a prize; settle the ink with a capture, by `docs/RISO_PRINT.md`). On the level's map:
  the same glyph by the thing's mark once that cell is seen. Once the wizard knows the move, the
  mark goes.
- Cracked rock is not part of this in the demo (section 8): it stays as it is, a hint.

*Care:* the reach is rough, by its own account. A mark will sometimes stand by a spot a moon, a
pogo or a lift does reach, and miss one that is out of reach. That is a reason to begin with few,
sure marks (the relic chasms, clear ledges too high) and widen by looking at captures
(`capture_overview.gd`), and it is why the marks are only ever information. It also costs a few
grows of the reach per level: measure it against `docs/PERF_PLAN.md`'s numbers before it goes in.

*Tests:* a new `wants_test` on small hand-laid levels: a ledge two cells up wants nothing, one
four up wants the double jump, a relic chasm is marked at both lips, the same on every build, and
`objects` is the same with the pass as without it. No test asks that a level can be crossed.

## 4. The map kept from run to run

*Seen:* a death with no lantern left ends the run and starts it again on the same seed
(`MapInfo.end_run`, which deletes the save and calls `start_run(run.run_seed)`), with everything
learned about that world gone: `RunState.start` clears the records, the relics found and pointed
to, and the boss hints. The player's own memory is the only thing carried.

*Decided:* "yes" to knowledge as the progression between runs (owner, 9 November 2026).

*Now:* what the map knows lives in the run. `LevelRecord.seen` (a byte a cell) and `mapped` (the
ink well paid) per level; `ways_taken` per level, for the worlds map; `RunState.relics_found`,
`relic_hints` and `boss_hints`; `RunState.bosses`.

*To do:*
- A file apart from the run's save and kept when the save is deleted (say `user://known.save`,
  one per band layout as the saves are), read and written by a small class of its own (say
  `scripts/level/Known.gd`).
- By place, since a level is the same in every run: the cells seen, whether it was inked whole,
  the ways taken out of it, and whether a relic was seen or taken there (it lies there again in
  the next run). By run seed, since these change with it: the column each boss was met in or
  told to lie toward.
- A new run reads it: the worlds map and each level's map start with what was known. This run's
  own ink is laid over it. Whether the old knowledge prints as this run's or paler is a question
  for a capture; paler says "you were here before" without a word.
- Each kept level carries a stamp of its layout (a hash of its terrain as loaded). A kept level
  whose stamp no longer matches is dropped, so a meant change to the layouts cannot leave a wrong
  map behind.
- A bound on its size (say the 300 places most lately visited), and a way to clear it in the
  start menu's options.
- Tests point it elsewhere, as they do the save (`RunState.save_path`), so they never read a
  player's.

*Open:* whether the tutorial, side worlds and hyperspace are kept (the tutorial has `done` of its
own; a first pass can keep ordinary levels only), and whether debug runs write to it (they should
not).

*Tests:* a new `known_test`: see part of a level, end the run, start again on the seed, and the
level's map and the worlds map hold what was seen; a boss's column met in one run is marked in
the next on that seed and not on another; a stamp that does not match drops the level; nothing is
kept from a debug run. `map_test` and `map_worlds_test` stay as they are, on a clean file.

## 5. A firm ending for the demo

*Now:* with every boss's trophy on its stand in the tutorial's trophy room, the run is won
(`MapInfo.win_run`): the wizard stops, the won card shows the trophies and the place (`RisoHud`),
a demo build adds "Thank you for playing the demo!" (`DEMO_THANKS`), and after `WIN_SECONDS`, 6,
the start menu comes back with the save gone. The card leaves by itself, and the menu it leaves
for looks the same as the one a new player sees.

*Decided:* "yes" (owner, 9 November 2026).

*To do:*
- The won card stays until a press, after a short hold so a press made in the fight's last
  moment does not skip it.
- In a demo build it says plainly that this is the end of the demo, and shows what lies past the
  garden: the other bands' boss seals (`RisoMarks`), unprinted, beside the two won.
- The run in a line or two: how long it took, the lanterns burned, the levels visited. The run
  keeps no clock yet; one field in `RunState`, saved.
- After a win the start menu shows the two trophies, so the menu itself says the demo has been
  finished.
- With section 4, a won seed keeps its map.

*Open:* a credits walk (a last hall to walk through, as the tutorial is a first) is the fuller
version. The card is the first pass; the walk is worth it only if the card reads as too little
in a playtest.

*Tests:* extend `trophy_test`: the card holds past `WIN_SECONDS` until a press; the demo's card
carries its lines (under `-l garden` with the demo feature's flag set by the test); the save is
gone and the trophies show in the menu after.

## 6. The tutorial's pogo bed: a reward past it

*Now:* `Tutorial.MAP` is one hall on one floor. The pogo bed is ten thorns wide (its card, `9`,
at its edge), and everything after it lies beyond: two stars, the utility and burn lessons, their
lanterns, the shrine, the trophy room, the map card and the way out. A player who cannot yet pogo
cannot leave the tutorial, buy at its shrine, or later set a trophy.

*Decided:* "Do the reward" (owner, 9 November 2026): a reward beyond the bed, with the shrine and
the way out no longer behind it.

*To do:* two ways to lay it, both by hand in `MAP`, neither drawing from anything.
- **A roof over the bed (recommended).** The hall carries on over the bed along a run of rock two
  or three cells up, with steps at each end. Under it, low over the thorns, the reward. The roof
  keeps the reward from being dropped onto from above, so it is reached only by bouncing along
  the bed from either end. The lesson stays in its place in the hall, before the shrine, so its
  stars can go toward the first boon. The roof's height has to clear a pogo's bounce: set it by
  playing it.
- **A spur past the way out.** The bed moves to the far right, beyond the way out, with the
  reward at the dead end. Simpler to lay, but the reward comes after the shrine, and the wizard
  has to bounce back over the bed to leave.

The reward: star clusters, enough to be felt (a shrine's first boon is 20 stars at the start,
`Abilities.price`; the way on from the start is 16). Check that the stars before the bed still
buy a boon without it, so the shrine's lesson in choosing does not depend on the pogo.

*Open:* whether the reward is stars alone or something that says more (an exam paper to learn at
a lantern).

*Tests:* `tutorial_test`: the way out, the shrine and the trophy stands are reached without
touching the bed; the pogo card still stands and is cleared by a pogo; the reward is there and
is the same on every visit. `trophy_test` for the stands' places if the hall's length changes.
The door into the tutorial is laid last in every start level (`laid_last`), so nothing in the
start levels moves.

## 7. Star sinks

The review offered six. The owner kept two (and removed the other four: section 8).

### 7.1 Which way the boss lies, for stars alone

*Now:* a shrine's third station mends while the wizard is hurt, free. Only at full health does it
sell anything, and then one thing in a fixed order: a door where the labyrinth left none (60% of
such shrines), else which way the boss ahead lies (40% of shrines, `Shrine.BOSS_SALE`), else a
skeleton key or a relic's whereabouts. Every sale costs stars and one carried key (`KEY_COST`).
Buying anything at a shrine spends the shrine. The hint itself is left, right or this column
(`MapInfo.hint_boss`), kept in `RunState.boss_hints` and shown on the worlds map.

*Decided:* kept as written in the review: "Sell the boss hint for stars alone, at any shrine and
at any health: the key and the wait for full health go."

*To do:*
- The boss's way becomes an offer of its own at every shrine in an ordinary level while the boss
  ahead lives (`Shrine.boss`), apart from the third station: a fourth place to interact on the
  shrine, printed with the boss's seal. `BOSS_SALE` and its deal go.
- Stars alone: `boss_price`, as now one times the level's way on. No key.
- Sold whether the wizard is hurt or not, and whether or not the shrine's boon has been taken.
  Once told in a column (`told_way`), it shows the way and sells nothing more there.
- The third station is left with mending, the door, the skeleton key and the relic, in that
  order, with their keys.

*Open:* whether buying the way spends the shrine as a boon does. The plan says no: it is a sink,
and it should not cost the player their upgrade.

*Tests:* `shrine_test`: sold hurt and whole, with no key carried, at a shrine that would not have
dealt it before; not sold with the boss slain, in a side world, or twice in a column; the worlds
map shows it. `unit_test` for the price.

### 7.2 Drawing a shrine's offers again

*Now:* a shrine's two boons are dealt by its level's seed (`Shrine.offers`, through
`Abilities.offers`): two different abilities, new ones before upgrades, one always a strict
upgrade. They are the same on every visit, and there is nothing to do about a pair the wizard
does not want.

*Decided:* kept as written: "Draw a shrine's offers again for stars, the price doubling each
time at that shrine."

*To do:*
- `LevelRecord.redraws`, saved with the rest (`FIELDS`). The boons are dealt from the level seed
  hashed with the count (`Rules.level_seed(seed, REDRAW_DEAL + redraws)`), so a shrine drawn
  twice shows the same pair on every visit and in every run that draws it twice. No world RNG.
- A draw that would show the same pair again is passed over for the next, within a few tries.
- The price: `REDRAW_PRICE` times the level's way on, doubled for each draw already made there.
  A constant to tune; begin at a half.
- Where it is asked: a third place to interact between the two niches. No menu, as now.
- Not in the tutorial (its boons are set, `Tutorial.BOONS`) and not once the shrine is spent.

*Tests:* `shrine_test`: a draw changes the pair, costs what it says, doubles, is the same after
leaving and coming back, and keeps one strict upgrade; `unit_test` for the price rule.

## 8. Decided against, or left as it is

So that nobody builds them:

- **Fixed boss relics.** "No." A boss goes on leaving the first of the moves not yet known
  (`Bosses.relic_for`).
- **Opening relics sooner**, as the review put it, leaned on fixed boss relics, so it falls with
  them. The demo already lets relics lie from its first row (`"relics_from": 1`).
- **Cracked walls in the demo.** "This should stay, as a hint for the future." Nothing in the
  garden breaks them, and that is meant.
- **Holding back what the garden cannot pay off.** "No."
- **The guard on a slow spell.** "A parry resets the spell cooldown." It does already: a catch
  refills the spell whatever its cooldown (`Parry`, by `Abilities.refill`), so the guard is ready
  again at once. No change. If the note meant something more (a guard that can be raised while
  the spell is still coming back), it wants saying.
- **The four other star sinks** (laying fewer stars, relighting a spent lantern for stars, a paid
  way home from a boss, banking stars past a run): removed from the list by the owner.

## 9. Later

- **Simplifying the institute and the shrine's third station:** "Out of scope for demo." The one
  piece of it that goes ahead now is 7.1, which takes the boss's way out of the third station.
- **Logging each playtest run:** "future".

## 10. Not yet decided

No word was written under these, so they wait:

- Telegraphs and hit feedback before any new enemies (a pink wind-up timed for the guard on every
  attack; weight on hits).
- Thinning the foes and setting them where the ground makes them matter.
- The whole game: finishing one band before widening the next.

The first of these touches section 2: the vines and the spare pods are new things to parry, and
they are fair only as far as their warnings read.

## 11. Order of work

1. **Four rows** (section 1). One line and a suite run; every later measurement of the demo is
   taken on it.
2. **The tutorial's reward** (section 6). By hand, on its own, and it removes the one hard stop a
   new player meets.
3. **The shrine's two sinks** (section 7). Small, one script and one record field, and 7.1 is the
   short cut the signs of section 2 lean on.
4. **The ending** (section 5). The card first; the clock field with it.
5. **Signs of the bosses** (section 2): the nearness rule and the worm's rumble first (no layout
   change), then the pods' rise by row, the spares, and the vines, with one update of the
   fingerprints for all three.
6. **The map kept from run to run** (section 4).
7. **What a spot wants** (section 3). The largest, and the one that most wants captures and a
   playtest between steps: the relic chasms' marks first, then the reach.

`docs/DEEPER_PLAN.md` (the shrine, the garden's dressing, the bosses' signs, the economy's sinks)
and `docs/RISO_PRINT.md` (the marks, the won card) are brought into step as each is built, and
this plan gets a *Done* line under the item, as `docs/PLAYTEST_PLAN.md` does.
