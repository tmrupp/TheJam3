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
- Traversability is not enforced. The barriers of section 3 guard rewards in pockets off the
  level: none stands across a way on, nothing already laid is moved for one, and no test fails
  a level over one.

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

## 3. A barrier for each relic

*Seen:* a spot the wizard cannot reach yet looks the same as one they have simply not worked out,
so "come back with a move" and "try harder" are told apart only by failing.

*Decided:* "This is a great idea and can be introduced generally into the procedural generation",
and then, on this plan's first draft (which marked such spots by working out the wizard's reach):
"we should have bespoke barrier for each relic (a wall with a wall of spikes on the other side for
wall climb for example)" (owner, 9 November 2026). So the generator builds the spots itself: five
barriers, one made for each relic move, each a shape the player learns once and knows again in
every level.

*Now:*
- The relic moves are five (`Relics.MOVES`): double jump, wall climb, blink, levitate and astral
  projection. Tier I of each comes only from a relic. About one level in 15 holds one (`CHANCE` 5%
  rising to `CHANCE_MAX` 8%), in the demo from its first row. Which move a level's relic holds is
  dealt by the place (`Relics.at`), the same in every run.
- Without a relic the wizard has a jump, a dash any way (up as well), a jump from one wall to the
  wall facing it (`Player.do_wall_jump`: the same wall twice gives little, "so a lone wall cannot
  be climbed by jumping repeatedly"), and the pogo, which bounces along a thorn bed.
- Secret rooms are already pockets carved into the rock once everything else is laid
  (`LevelGen.place_secrets`, `_secret_spots`, `_carve_secret`), "placed last of all, so the rest of
  the level lands where it always has". They open to a step, a hex bolt, a projection or a warp:
  no move is needed for them.
- The generator already leaves some chasms to the relic moves (`LevelGen.relic_chasms`, from
  `Rules.RELIC_NEED_FROM`, in the cemetery and the sky), with nothing to say so.
- `RisoGlyph` draws every ability's mark, fitted to a roundel (`RisoGlyph.fit`); `RisoMarks` is
  shared by the level, the map and the HUD.

### 3.1 The five barriers

Each is a pocket carved into the rock off the level, as a secret room is, with a reward at its far
end and the barrier in its mouth. All five are built from rock and thorns, which the game has: no
new prefab, and thorns are pink already, so each reads as danger with no new art.

| Move | Barrier | Why that move |
|---|---|---|
| Wall climb | **The one-wall shaft** (the owner's example). A shaft going up, taller than a jump, one wall bare rock and the wall facing it thorned from bottom to top. | The wizard goes up a shaft by jumping from wall to wall. Thorns on one leave a lone wall, and a lone wall cannot be climbed by jumping. Wall climb goes up the bare one. |
| Double jump | **The high sill.** A ledge higher than a jump and an upward dash reach, under an overhang, with the rock face below it thorned. | The thorned face leaves nothing to kick off or to climb. The height has to be made in the open air. |
| Levitate | **The thorn throat.** A low passage with thorns along its floor and its roof, longer than a dash or a blink carries. | A pogo off the floor bounces into the roof, and so does a jump. Holding height at walking pace goes straight through (a float lasts six seconds, about 1,800 px at the wizard's 300 px a second). |
| Blink | **The thorn curtain.** The mouth filled with thorns from floor to roof, a few cells deep, with open room beyond. | A blink goes to the furthest spot with room for the wizard and touches nothing on the way (`Blink.blink` looks only at where it lands). Thinner than a first-tier blink, 300 px. |
| Astral | **The sealed cell.** A room closed in real rock on every side, with no false wall, thicker than a blink at its top tier carries (500 px). | Only a projection passes rock, and the wizard stays where it ends. |

Each barrier's measures (the shaft's height, the sill's, the throat's and the curtain's length,
the cell's walls) live in one table of constants and are set by playing each in the generation
lab. The bounds above are where to begin.

*Care:* a barrier is made for its move. It is not proved against the other four, or against a
clever player. The projection passes all of them; a blink aimed up may land on a high sill; a
float at its second tier drifts upward. That is left as it is: a second way through is a find,
not a fault. What has to hold is that a wizard with no relic does not get through by ordinary
play, and that is checked by playing each barrier on Normal and Hard with the shrine's boons at
their top tiers (a dash runs longer each tier), not by a test.

### 3.2 Laying them

*To do:*
- A script beside `Chasms.gd` and `Crypts.gd` (say `scripts/level/Barriers.gd`): it finds rock
  that fits a barrier's shape beside open floor, as `_secret_spots` finds a room's, carves the
  pocket, lays its thorns and its reward, and keeps what it laid in `LevelGen.barriers` (the move,
  the mouth, the cells, the reward) for the map and the tests.
- How many: `BARRIERS_PER_K` through `per_area`, to begin with about one level in two holding
  one. None in the tutorial, a side world or a boss's own level.
- Which one: the move of the nearest level holding a relic within `BARRIER_NEAR` levels
  (`Relics.at`, by the rules alone, so the same in every run), else one of the five dealt by the
  level's seed. The levels round a relic are then where its barriers stand, and finding the relic
  pays off close by.
- Where no rock fits the shape, none is laid. Nothing is forced.
- The reward: a star cluster worth more than a secret room's three (`SECRET_STARS`), in the
  reward's ink, and now and then a key.
- The mark: the move's glyph in a small roundel on the rock by the mouth, in the quiet inks (it
  is a note, not a prize; settle the ink with a capture, by `docs/RISO_PRINT.md`), and by the
  barrier on the level's map once its mouth is seen. Once the wizard knows the move, the mark
  goes. With section 4 a mark seen in one run is on the map in the next, which is what lets
  "come back with a move" outlast a death.
- The chasms left to relics get the same mark at each lip, from `relic_chasms`: they are the
  barrier the cemetery and the sky already have.
- It runs after `connect_caves`, which would fill a sealed cell or join it to the cave, and after
  the secrets: last.
- Cracked rock is not part of this in the demo (section 9): it stays as it is, a hint.

*Traversability:* a barrier guards a pocket off the level and the reward in it, and nothing else.
It is never laid across a way on, a door, a shrine or a lantern, and the pass moves nothing that
is already laid. Nothing checks that a barrier's mouth can be reached, or that a level can be
crossed with one in it.

*Layouts:* carving changes the terrain and the pass draws from the world RNG, so every level that
takes a barrier changes, in every band. The pass goes last so nothing laid before it moves; check
it against the start levels' tutorial door, which is laid last of all (`laid_last`).
`layout_fingerprint_test -- update`, said in the report.

*Later:* the first draft's general pass (growing the rough reach of `Reach` as each move would
have it, and marking whatever spot in the collapsed level it misses) is put aside, not refused.
The reach is rough by its own account, and a built barrier says what it wants with certainty.
It is worth coming back to only if the levels' own unreachable spots go on misleading players
once the barriers are in.

*Tests:* a new `barriers_test`, looking over a few worlds and rows with `build` for a level
holding each kind rather than trusting one level: the shaft has one wall thorned for its whole
height and the other bare; the throat has thorns over and under every cell of it; the sealed cell
has no open cell beside it; each holds its reward; the same on two builds; the kind is the
nearest relic's; none stands on a way on. Booted: the mark shows by the mouth and on the map, and
not once the move is known. `revisit_test` for the visit after. No test asks that a level can be
crossed, or that a barrier can or cannot be passed.

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

*Done* (but the kept map, which comes with section 4): the won card stays up until a press made
once it has shown `MapInfo.WIN_HOLD` (1.5 s; `WIN_SECONDS` is gone), a chevron blinking at its
foot once one will take. It shows the run in a line (the time, `RunState.play_time`, saved; the
lanterns burned out; the levels visited, each by a small mark). A demo build's card shows the
bosses past its garden faint beside the two trophies (`RisoHud.beyond`) and says "This is the end
of the demo." and "Thank you for playing!". The win is kept past the run (`Trophy.note_won`, in
the settings file by layout), and the start menu shows its trophies either side of the line
under the title. `trophy_test` checks the card holds 8 s past a press made at once, a later press
brings the menu back, the win is kept, and (under `-l garden`) the demo card's bosses and line;
`capture_menu.gd` takes the demo's card and the won menu. Not yet played.

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

*Done* (the roof): the bed is eleven thorns wide (once ten: at twelve, the third bounce of a
steady rhythm came down on the far edge's corner and slid down its side onto the thorns), with
its card at its edge. A roof of rock three rows over it (row 7, the bed's thorns in row 11) runs
from the edge before it to the edge past it, so the jump into the bed and each bounce clear it (a
jump rises about 1.5 cells, a bounce about 0.4 over standing height). At either end three steps a
cell high lead up to it: the first on the floor, the other two ledges with a gap before each, so
the floor runs on under them to the bed's edge. The reward is two star clusters (20 stars) in the
bed's middle two cells, just over the thorns, where a bounce takes them and a jump and a dash from
either edge (which come down on the bed's fifth cell) do not. Without them the hall holds 23
stars, enough for the shrine's first boon (20). The hall is 169 cells long (once 153). The roof's
height was set by measuring the jump and the bounce in the game, not by playing it: play it.

*Tests:* `tutorial_test`: the way out, the shrine and the trophy stands are reached without
touching the bed; the pogo card still stands and is cleared by a pogo; the reward is there and
is the same on every visit. `trophy_test` for the stands' places if the hall's length changes.
The door into the tutorial is laid last in every start level (`laid_last`), so nothing in the
start levels moves.

## 7. Star sinks

The review offered six. The owner kept two (and removed the other four: section 9).

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
does not want. The third station's sales each take stars and one carried key (`KEY_COST`): the
shrine deals which of the keys carried it takes (`taken_key`, by `pick_key`, hashing the level's
seed with `KEY_DEAL`), and nothing is paid unless both can be (`_pay`).

*Decided:* kept as written, "Draw a shrine's offers again for stars, the price doubling each
time at that shrine", and then: "this should actually also cost a key" (owner, 9 November 2026).

*To do:*
- `LevelRecord.redraws`, saved with the rest (`FIELDS`). The boons are dealt from the level seed
  hashed with the count (`Rules.level_seed(seed, REDRAW_DEAL + redraws)`), so a shrine drawn
  twice shows the same pair on every visit and in every run that draws it twice. No world RNG.
- A draw that would show the same pair again is passed over for the next, within a few tries.
- The price in stars: `REDRAW_PRICE` times the level's way on, doubled for each draw already made
  there. A constant to tune; begin at a half.
- The price in keys: one carried key a draw (`KEY_COST`), as the third station takes one. Which
  key is dealt as the station's is. `taken_key` answers only while the station has something to
  sell, so the deal is lifted out of it into one rule both use (which of the keys carried, by
  `pick_key` and a salt), the redraw with a salt of its own hashed with the count
  (`REDRAW_KEY_DEAL + redraws`), so each draw's key is the same on every visit. It is paid
  through `_pay`, so with no key carried, or too few stars, nothing is taken and nothing is drawn.
- The place shows what it asks, the stars and the key it would take, the way the third station
  shows its own (`keys_asked`), and reads as out of reach when no key is carried.
- Where it is asked: a third place to interact between the two niches. No menu, as now.
- Not in the tutorial (its boons are set, `Tutorial.BOONS`) and not once the shrine is spent.

With 7.1 taking the key off the boss's way, a carried key at a shrine now weighs four things
against each other and against the door it opens: a redraw, a door where the labyrinth left none,
a skeleton key, and a relic's whereabouts.

*Open:* whether the stars still want to double now that every draw takes a key as well. The key
may be brake enough; tune it in play.

*Tests:* `shrine_test`: a draw changes the pair, costs the stars it says and one key, doubles its
stars, is the same after leaving and coming back, and keeps one strict upgrade; with no key
carried nothing is spent and the pair stays; the key taken is the same on every visit.
`unit_test` for the price rule and the key's deal.

*Done* (7.1 and 7.2): the shrine has five places across its two cells now: the two niches
(narrower), the redraw dial between them, the third station's bowl, and a post at the far end
for the boss's way. Its two cells, and so every layout, are as they were. The boss's way is
`Shrine.buy_way` (stars alone, any health, once a column, not spending the shrine; `BOSS_SALE`
and its deal are gone). The redraw is `Shrine.buy_redraw` (`REDRAW_PRICE` a half, doubling;
one key dealt with `REDRAW_KEY_DEAL` and the count; `LevelRecord.redraws`), and like the way it
does not spend the shrine. The deal of which carried key is taken is shared (`carried_keys`,
`pick_key`). Only the station the wizard would use pops up its price. `shrine_test` covers both,
and `capture_shrine_station.gd` takes stills of the post, told and not, and of the dial with a
key and without. The price rule and the key's deal are checked in `shrine_test` rather than
`unit_test`, as both read the shrine's level. Not yet played.

## 8. Telegraphs: a warning before every attack

*Seen:* the review's item: "every attack gets a pink wind-up timed for the guard, and hits get
weight (hit-stop, flash, knock-back). The parry design depends on it." The guard catches a blow
within `Parry.WINDOW`, 0.2 seconds, of being raised; a catch stuns the attacker and refills the
spell. It can only be timed off something seen.

*Decided:* "we should actually do this. Wisps and watchers have it but we should plan for the
rest that don't" (owner, 9 November 2026).

### 8.1 What a telegraph is

The wisp and the watcher are the model. A wisp that sees the wizard rears its head and flares for
`WIND_UP`, 0.55 seconds, then strikes (`Mover`, `WispArt`). A watcher's lid opens as its shot
charges and shuts when it loses sight (`Shooter`, `WatcherArt`). From those two, the rule every
attack is held to:

- **A wait.** At least `TELL_MIN` seconds from the first sign to the blow, on every difficulty
  preset. The presets run tells faster (`Difficulty.attack`: 1.2 on Hard, the default, and 1.4 on
  Brutal), so a tell of 0.45 seconds is 0.375 on Hard. One rule for it, `Difficulty.tell(seconds)`:
  the time at the preset's pace, never under the floor. Begin `TELL_MIN` at 0.4 seconds and tune.
- **Pink that grows.** A change of pose alone is not enough. Pink builds through the wind-up and
  is fullest the moment before the blow, printed over the darkness where the foe is met in the
  dark (as a skeleton's sockets are, on its glow canvas).
- **A last beat.** The final fifth of a second, the guard's window, looks different from the
  rest of the wait (a flash to paper), so the guard is raised on a frame that can be seen.
- **The same every time.** A foe's tell has one length, so it can be learned.
- **A sound**, when the playtest plan's sound work reaches the foes.

A touch is not an attack: what hurts only by being walked into (a rock-bug, a breach, an
abomination's body and its slime) needs no tell.

### 8.2 Foe by foe

Read through for this plan, nearly every attack already waits before it lands. The gaps are
fewer than the review supposed and are mostly in how the wait reads. Times are at Normal.

The garden (the demo), first:

| Foe | Now | To do |
|---|---|---|
| Wisp | Rears and flares for 0.55 s before a lurch. | The model. Give it the last beat. |
| Watcher | Its lid opens as the shot charges. | The model. Give it the last beat. |
| Hopper | Crouches for `CROUCH_TIME`, 0.45 s (0.375 on Hard, 0.32 on Brutal): it leans forward and its eyes narrow. Its body is pink at all times, so no ink changes. | **A gap.** Hold it to the floor, and give the crouch a flare that grows (it cannot turn pink, so it brightens: a paper gleam swelling in it) and the last beat. |
| Seed pod | Its bulb swells over the whole 2.4 s between seeds, in gold, its leaves parting. | **A gap.** The wait is long but has no moment that says "now", and gold is the reward's ink. The bulb turns pink over its last `POD_TELL` seconds and flashes before it spits. |
| Wormlet | The rock throbs pink for `WARN_TIME`, 0.7 s, before it comes out. | Has it. Check the last beat. |
| Timed thorns | Their tips peek and flicker for `WARN` seconds. | Has it. |
| The worm, the bramble | The worm's rumble and `EMERGE_WARN`; a vine's pink shoots for 0.8 s; the bulbs' swell. All run faster on Hard (`Difficulty.haste`, 1.15). | Go through each attack of both against 8.1. The vines on their own and the spare pods of section 2 take the same tells and the same floor. |

The other bands, as each is worked on:

| Foe | Now | To do |
|---|---|---|
| Skeleton | Winds up 0.5 s: its arm raised, a rattle, its sockets burning hotter; a pink smear on the swipe. | Has it. Check the last beat. |
| Wraith | Swells for 0.65 s, shivering, its eyes glowing pink, before a dart. | Has it. |
| Bird | Rears and screeches for 0.65 s before a dive. | Has it. |
| Stalactite | Shakes before it falls. | Has it. |
| Laser | A faint flickering sight line for 0.9 s. | Has it. |
| Crossbow | Winds its string for 0.8 s with a pink bolt laid on it, but its first arrow at a wizard just come into sight is drawn in `FIRST_DRAW`, 0.2 s (0.17 on Hard). | **A gap.** The first arrow's wait is the guard's whole window. Hold it to the floor, or show where it looks before the wizard is in its sight (a sight line, as the laser's). See *Open*. |
| Student | Its orb swells and brightens for 0.5 s. | Has it. |
| Master, instructor | Raises its hand and the orb goes to it for 0.7 s, the same whichever of its six spells it casts. | **A gap.** The spells that strike near it (a slash 190 px in front, a nova 240 px all round, a push in a cone to 360 px, a lunge to 520 px) show no reach before they land. Print the reach in pink through the wind-up: a ring, a cone, a line, as the librarian's ring already does. |
| Librarian | The ring of its hush swells for 0.8 s before it rises. | Has it. |
| Abomination | Braces for 1.4 s, its top blob swelling, before it launches. | Has it. |
| Bug nest | Hatches a rock-bug every so often while the wizard is near. | To look at: whether a hatch shows before the bug is out. |
| The golem, the whale, the beast, the necromancer | Each has warnings of its own. | Gone through as the garden's bosses are, when their bands are worked on. |

*Open:* the crossbow's quick first arrow reads as meant (a tower that punishes walking into its
sight). If it is, it keeps its speed and gets the sight line instead of the wait; the owner to say.

### 8.3 Hits

The other half of the review's item, weight on hits, is partly there already and is not planned
again here: a blow that wounds a foe freezes the action for a moment (`Wound.hit_stop`, 0.05
seconds, longer for a kill), and a catch on the guard longer (`Parry.HIT_STOP`, 0.08). What the
wizard's own hurt has was not gone through for this plan. Look at it while building 8.2, and
write down what is missing rather than adding it unasked.

### 8.4 Building it

*To do, in order:*
1. `TELL_MIN` and `Difficulty.tell`, and every wind-up in 8.2 read through it in place of
   dividing by `Difficulty.attack` itself.
2. A capture that prints each foe at the start, the middle and the last beat of its tell, in the
   light and in the dark (say `tests/capture_tells.gd`), looked at zoomed in. It is the audit for
   every "has it" above, and where the last beat is settled.
3. The hopper and the seed pod.
4. The worm's and the bramble's attacks, before section 2's vines and spare pods go in.
5. The other bands' gaps (the crossbow, the masters' reach) with their bands.

*Done* (steps 1 to 4, the garden): `Difficulty.TELL_MIN` (0.4 s), `Difficulty.tell` and
`boss_tell`, and `Difficulty.LAST_BEAT` (the guard's window) with `last_beat`. Read through them:
the wisp's wind-up, the hopper's crouch, the watcher's charge, the pod's new tell, the small worm's
warning, the skeleton's wind-up, the wraith's swell, the bird's tell and the crossbow's draws but
its first (left quick, see *Open*); the worm's strike (its pause and draw back, `Worm.STRIKE_WIND`,
were 0.35 s on Hard and 0.31 on Brutal, under the floor: now 0.4), a bramble vine's warning and a
bulb's new tell. The floor moves the hopper's crouch on Hard (0.375 to 0.4 s) and Brutal, the
wisp's and skeleton's on Brutal, and the worm's strike on Hard and Brutal; nothing at Normal. The
scholars wind up in plain seconds, over the floor already, and were left as they are.
The print (`RisoMarks.tell`, `RisoProp.tell_mark`): a bloom of pink round the foe that builds as
the square of its wind-up, and in the last beat a paper star cut out over it, on a canvas over the
darkness. The pod and a bramble bulb now end each swell in a tell (`SeedPod.POD_TELL`, 0.6 s): the
full bulb turns pink (gold through orange to red), then flashes. The hopper's gleam swells through
its crouch. `tests/capture_tells.gd` prints the garden's five foes at the start, middle and last
beat of their tells, lit and snuffed, and was looked at: the star first sat on the foe's middle
and hid the wisp and the pod in their last beat, so it shines over them now. The bosses' tells
are not in that capture yet. `tests/tells_test.gd` times each garden foe on every preset, the
bosses through their clocks, and catches a wisp's lurch with a guard raised in its last beat.
Found while building it: a hopper's blow, a watcher's shot and a seed land after a flight (a
hopper's leap is about a second in the air), so their last beat marks the leap or the shot, not
the blow, and a guard raised in it is down again before the blow lands. 8.1 says the last beat
is the guard's window; for these it is a "now" to watch for, not when to guard. The owner to say
whether that is enough or the flight wants its own mark. 8.3 (the wizard's own hurt) was not
looked at. Not yet played on Normal and Hard.

*Layouts:* none. A tell is timing and print: no draw, no fingerprint. It does change every fight
it touches, so play the garden on Normal and Hard after steps 1 and 3 and note what was found.

*Tests:* `unit_test`: `Difficulty.tell` is never under the floor on any preset. A new
`tells_test`: for each foe above, from the first frame its wind-up shows to the first frame it
can hurt is at least `TELL_MIN` of the game's own seconds on every preset (`within`, which counts
physics frames), and a guard raised in the last 0.2 seconds catches the blow. Each foe's own test
keeps its attack as it was but for the times.

## 9. Decided against, or left as it is

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

## 10. Later

- **Simplifying the institute and the shrine's third station:** "Out of scope for demo." The one
  piece of it that goes ahead now is 7.1, which takes the boss's way out of the third station.
- **Logging each playtest run:** "future".

## 11. Not yet decided

No word was written under these, so they wait:

- Thinning the foes and setting them where the ground makes them matter.
- The whole game: finishing one band before widening the next.

Telegraphs stood here in the first draft. They are decided now: section 8.

## 12. Order of work

1. **Four rows** (section 1). One line and a suite run; every later measurement of the demo is
   taken on it.
2. **The tutorial's reward** (section 6). By hand, on its own, and it removes the one hard stop a
   new player meets.
3. **Telegraphs in the garden** (section 8, steps 1 to 4): the floor, the capture, the hopper and
   the pod, the two bosses. Every fight after is judged on them, and section 2's vines and spare
   pods are fair only as far as their warnings read.
4. **The shrine's two sinks** (section 7). Small, one script and one record field, and 7.1 is the
   short cut the signs of section 2 lean on.
5. **The ending** (section 5). The card first; the clock field with it.
6. **Signs of the bosses** (section 2): the nearness rule and the worm's rumble first (no layout
   change), then the pods' rise by row, the spares, and the vines, with one update of the
   fingerprints for all three.
7. **The map kept from run to run** (section 4).
8. **A barrier for each relic** (section 3). The largest, and the one that most wants captures
   and playing between steps: one barrier first (the one-wall shaft), its mark and its place on
   the map, then the other four. After the kept map, so a barrier seen is a barrier remembered.
   Its change to the layouts is a second update of the fingerprints, in every band.

`docs/DEEPER_PLAN.md` (the shrine, the garden's dressing, the bosses' signs, the barriers, the
tells and their floor, the economy's sinks) and `docs/RISO_PRINT.md` (the barriers' marks, the
tells' pink and last beat, the won card) are brought into step as each is built, and this plan
gets a *Done* line under the item, as `docs/PLAYTEST_PLAN.md` does.
