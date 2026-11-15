# Paired play: the plan

Two players, each on their own machine and in their own run, play paired. Nothing is networked:
**the only thing that passes between them is a code.** One game prints a short code, its player
passes it on however they like (pasted into a chat, read aloud, written down), and the other
player enters it. A code does one of two things in the game that takes it:

- it **updates the map**: a level the sender has charted is inked on the receiver's map, a find
  (a relic, a lodestone, a skeleton key) is marked on it, or a pin says where the sender is or
  where to go;
- it **gives something**: stars, a key, or another thing the sender carried, which leaves the
  sender's game as the code is made.

This was the idea the game began with (the 2023 jam build dealt an arrow code with each key, and
its goal needed a code). An earlier, preliminary version of this file planned it more broadly
(a page showing the partner's whole world, doors opened and the partner moved by code, spells
lent, paired seals). This version is the plan to build: the two things above first, on the game
as it is now, with the rest kept under "Later". Nothing is built yet.

## What the owner has decided

- **Non-networked.** The two games never talk to each other.
- **Codes are the only channel**, made in one game and entered in the other.
- **Codes update the map** and **codes send items and stars.**

Everything else here is proposed. The choices that are the owner's to make are gathered under
"For the owner to decide", each with what this plan assumes until told otherwise.

## What has changed since the preliminary plan

Four things in the game as built change the plan, the first of them a good deal.

- **Every run is in the same world.** A place is (column, row), and a level comes from its place
  alone (`Rules.level_seed`, the labyrinth in `Rules.maze_has`: "laid by the place alone, the
  same in every run"). A run's seed is only the column it starts in. So there is no "partner's
  world" to lay out: the two players are in two copies of one grid of levels, perhaps in the same
  columns, perhaps thousands apart. What differs between the copies is what each run has done
  (its `LevelRecord`s) and the few things dealt by the run's seed (which column each boss is met
  in, `Bosses.column`; the whale's wandering; the beast's souls).
  - What one player learns about a place is true for the other: the level at (30, 4) holds the
    same relic in the same secret room in both copies. And it is still there in the partner's
    copy after the first player has taken it in their own. **Scouting for each other is the
    co-operation**, and a map code is how its result crosses.
  - The preliminary plan's Partner page (the partner's levels shown fully inked, as laid out) is
    dropped. In one grid it would be a free map of any level, the player's own surroundings
    among them. Maps cross only as charts of what a player really has.
  - How far apart the two start now matters, which it did not before (see "Pairing").
- **The collapse is the same on every compiler** (`gdextension/src/portable.hpp`, checked by
  `collapse_xcheck`). The code review's worry (§2.4) that a pair on Windows and Linux could never
  play is answered; a check of the build is still wanted, as two versions of the game may lay
  levels out differently.
- **The map already knows how to learn a place from outside.** `MapInfo.ink_place(at)` inks a
  level never visited (an ink well's neighbours, the gondola's top station), `RunState.relic_hints`
  marks a relic on the worlds page, and `Known` keeps place knowledge from run to run with a stamp
  of each layout. A map code writes to the same places; little of the map's printing is new.
- **The run and its records are typed and scene-free** (`RunState`, `LevelRecord`, `KeyRing`,
  `Coins`), and the start menu already copies a place to the clipboard and reads a pasted seed
  (`menu.copy_location`, `paste_seed`). Giving and taking are small writes to state that is
  already saved.

One snag from the preliminary plan still stands: the difficulty preset is a global
(`Difficulty.preset`) and changes what levels hold, so a cell named by one player is only the
same cell for the other on the same preset. The pair code carries it (below).

## Pairing

- **The pair code.** Each player starts a paired run and is shown a pair code for it: the run's
  seed, a stamp drawn at random when the run starts, the preset, and a check of the build and the
  band layout. They swap pair codes once. From then on every code is checked against both pair
  codes, so a code works only between these two runs and only one way (the sender's own game
  refuses it). A new run draws a new stamp, so codes left over from an old run do nothing.
- **The build check** is a few bits of a `LAYOUTS_STAMP` constant kept beside the rules, which
  `layout_fingerprint_test -- update` writes whenever a level moves (and the test fails if the
  constant and its `GOLDEN` disagree, so it cannot be forgotten). Two builds that lay levels out
  differently are told so when pair codes are swapped, not when a mark lands in rock.
- **Which seeds.** Any two seeds can pair, and gifts work at any distance. Maps are only worth
  sending where the two can both walk, so the join screen fills in the partner's seed as the
  joiner's own: the two start in the same level of their two copies, split up, and trade what
  they find. A player who would rather start elsewhere types another seed. (Bosses are dealt by
  the run's seed, so on one seed the pair hunts the same bosses in the same columns; on two
  seeds each has their own.)
- **Where it is done.** A "Paired" row on the start menu beside the world seed: your pair code
  with a copy button, a field for the partner's with a paste button. A run can also be paired
  after it has begun, from the pause menu's Partner page (below). A solo run is a run with no
  partner; nothing in it changes.
- **Kept in the save.** A small typed, scene-free `Pair` (`scripts/level/Pair.gd`, held as
  `RunState.pair`): the two pair codes, the gifts taken and the next gift's number, the codes
  made (so one can be read again after the page is closed), and the pins and finds received.
  Saved under its own name as `InstituteRecord` is; an older save has none and reads as solo.
- **No layout changes.** Pairing draws nothing from the world RNG and lays nothing, so a place is
  the same paired or alone and `layout_fingerprint_test` stays as it is.

## Codes

- **Symbols.** 32 symbols, five bits each: the digits and the letters without I, L, O and U
  (typed in either case; I and L read as 1, O as 0), printed in groups of four or five. A code
  is copied to the clipboard as it is made and can be pasted in, which is how most will cross;
  it is short enough to read aloud. Arrows, as in 2023, would take twenty presses for what eight
  letters carry, and the printed sigils cannot be typed into a chat.
- **Lengths.** A pair code is 10 symbols, typed once a run. Most codes in play are 8; a pin in a
  level, which names a cell, is 10.

| Code | Symbols | Bits |
|---|---|---|
| Pair | 10 | seed 20, run stamp 8, preset 2, build and band layout 8, check 12 |
| Gift | 8 | kind 4, number 8, what 12, check 16 |
| Chart | 8 | kind 4, place 17, how many along the row 3, check 16 |
| Find | 8 | kind 4, place 17, what 4, check 15 |
| Pin | 10 | kind 4, place 17, cell 12, word 3, check 14 |

- **A place** is 17 bits: whose start it is counted from (the sender's or the receiver's), up to
  255 columns either way, and the row (63 either way; the whole game's bands reach 35). Side
  worlds are not sent at first. **A cell** is 6 bits across and 6 down (a level is at most 60 by
  48, `Rules.level_size`). A paired run's seed must fit 20 bits (the menu's random seeds are
  under 100,000).
- **The check** is a hash of the code's fields, the sender's pair code and the receiver's, in
  that order, by a hash of the game's own (as `Rules.level_seed`, not the engine's), salted from
  `Salts` (a new salt at its end). A mistyped gift slips through once in 65,000; a code from
  another pair, another run or the wrong way round is refused, and the game says which.
- **Scene-free.** `scripts/level/Codes.gd` packs and unpacks the bits, turns them to symbols and
  back, and checks them. It names no node, so `unit_test` covers it in a second.
- **Trust.** Nothing stops a player who wants to forge a code; the two are on the same side.
  The checks are against slips, stale codes and mismatched builds, not against cheating.

## Map codes: updating the partner's map

A map code says something about the world, which is as true in the partner's copy as in the
sender's. It costs nothing, and entered twice it only says the same again, so it carries no
number.

- **A chart.** Made on the worlds page with the cursor on a level whose whole map the sender has
  (inked at a well or by a chart, or with at least `CHART_SHARE` of its open cells seen). Entered,
  it inks that level whole on the receiver's map (`MapInfo.ink_place`), where it shows as an
  inked neighbour does now: a tile on the worlds page, its level page to look over. One code can
  carry up to eight levels side by side along a row. A level's seen cells are far too many bits
  for a code, which is why a chart is all or nothing.
- **A find.** Also made on the worlds page, from what the sender's map shows in that level: its
  relic (the receiver's `relic_hints`, as a shrine's hint), its lodestone, a skeleton key, a bone
  vault, a shrine, an ink well, a lantern, a hyperspace door. The receiving game asks its own
  rules and layout whether the place holds such a thing (`Relics.at`, `Rules.lodestone_at`,
  `skeleton_at`, `bone_vault_at`) and refuses a find that is not there, then marks it on the
  worlds page with the mark it would have if found there.
- **A pin.** A cell in a level and one of eight words: here I am, come here, look here, danger,
  and four to be chosen in play. "Here I am" is made from the pause menu in one press; the others
  are made on the level page with a cursor (the page has none now; `Warp.pick` picks cells in the
  level itself and is the model). A pin prints on the receiver's worlds page and level page as
  the ghost's mark does, in accent ink (pink for danger), each kind replacing the last of its
  kind. Pins do not print in the level itself at first.
- **What does not cross.** What a player has done in their own copy (doors opened, keys taken,
  bosses slain) is theirs alone and is not sent; the partner's copy still has all of it.
- **Told apart.** What came by code prints with a small mark of the partner on its tile, so a
  player can tell what they found from what they were told. `Known` keeps a charted place for
  later runs as it keeps a visited one.

## Gift codes: sending items and stars

A gift leaves the sender as its code is made and arrives when the code is entered.

- **Stars.** An amount from the sender's purse (`Coins`) to the receiver's, up to 4,095 a code.
- **Keys.** A coloured key off the ring onto the partner's (`KeyRing`; a full ring drops its
  oldest key at the receiver's feet, as picking one up does, `MapInfo.key_taken`). Colours mean
  the same in both copies, so a plum key found by one opens the other's plum doors.
- **The things kept apart on the ring.** A skeleton key, a relic unlock, a garden seed; a count
  of each. A seed arriving with the pocket full, or anything that cannot be carried, is laid at
  the receiver's feet as a dropped key is (`LevelRecord.drop_key`).
- **Exam papers.** A paper (a spell known but not held) is carried on the ring as a key is and is
  sent the same way, its spell and tier in the code. One attends the class, the other learns the
  spell. A stolen paper arrives stolen.
- **Not at first:** spells in their slots, the relic moves, health, lanterns, the darkness
  carried. See "Later".
- **Numbered, so taken once.** Each side numbers its gifts from 1 in the run. The receiving game
  keeps which numbers it has taken (in `Pair`), so a code entered twice, or typed again an hour
  later, does nothing and says so. Gifts can be entered in any order.
- **A code never entered is lost,** as a thing dropped down a well is. The sender's Partner page
  keeps every code made this run, so one can be found and sent again; there is no taking a gift
  back, since the sender's game cannot know it was not taken.
- **No world RNG.** Giving and taking write to the purse, the ring and the record only.

## Where the player does it

- **The pause menu's Partner page** (a page beside Settings and Controls, in `menu.gd`'s own
  controls): the two pair codes; a field to enter a code, with a paste button and a line saying
  what the code did or why it was refused; Send (stars with an amount, then each thing carried
  that can be sent); "Here I am"; and the codes made this run. A made code is shown large and is
  already on the clipboard.
- **The map.** On the worlds page, with the cursor on a level: Chart and Find, each showing the
  code on the sheet. On the level page: a cursor for pins. The map prints what came by code
  (above).
- **On a pad.** Pasting needs a keyboard. A pad enters a code on a printed grid of the 32
  symbols (8 by 4), picked with the stick, built last (phase 4); until then a paired run wants a
  keyboard for entering.
- **In the scene.** `MapInfo` gains `make_gift`, `make_chart`, `make_find`, `make_pin` and
  `take_code(text)`, which do in the scene what `Pair` and `Codes` decide (the purse, the ring, a
  key laid at the feet, the map's version bumped, `save_now`, as a gift must not be lost to a
  crash after its code is shown).

## For the owner to decide

Each has what the plan assumes until told otherwise.

1. **How far apart the pair starts.** Assumed: any seeds may pair, and joining fills in the
   partner's seed, so by default the two play the same columns in two copies. The other choices
   are neighbours a few columns apart, or wherever each likes (gifts only, in effect).
2. **What may be charted.** Assumed: only a level whose whole map the sender has, free to send.
   The other choices: any visited level (which makes the ink wells worth half as much to a pair),
   or a price in stars to make a chart.
3. **The alphabet.** Assumed: letters and digits, pasted or typed. The other choices are arrows
   or printed sigils, both far longer to pass on.
4. **What can be given.** Assumed: stars, the four keys, skeleton keys, relic unlocks, seeds and
   exam papers. Spells and relic moves wait.
5. **The preset.** Assumed: the two must be on the same preset to pair (a release build has one
   anyway; only the developer's F7 panel changes it).
6. **Stars as a bank.** A death leaves the stars with the ghost; stars sent to the partner first
   are safe. Assumed: allowed, and looked at in the playtest. A toll on stars sent (a share lost
   on the way) is the lever if it wants one.

## Phases

1. **Codes, pairing, and stars end to end.** `Codes` and `Pair`; the pair code and
   `LAYOUTS_STAMP`; the pair in the save; the start menu's Paired row and the pause menu's
   Partner page (pair codes, enter a code, send stars, the codes made). Tests: in `unit_test`,
   every code's round trip, each single mistyped symbol of a sample of codes refused, a code from
   another pair, another run and the wrong way round refused, I, L and O read as digits; a new
   `pair_test` on the kit, two runs on two saves taking turns: stars leave one purse and arrive
   in the other, a gift entered twice does nothing, a paired run saved and continued still takes
   its partner's codes; `layout_fingerprint_test` unchanged.
2. **The other gifts.** Keys, skeleton keys, relic unlocks, seeds, papers. Tests in `pair_test`
   (a key onto a full ring drops the oldest at the feet and it is there on a revisit; a sent
   paper is learned at a lantern), with the keyring's rules in `unit_test`.
3. **Map codes.** Charts and finds from the worlds page, "here I am", pins from the level page
   with its new cursor, and the partner's marks on both pages. Tests: a chart inks the place and
   up to eight along the row; a find of something that is not there is refused; a pin shows at
   its cell; `known_test` (or its like) for a charted place kept to the next run. A capture
   (`tests/capture_pair.gd`) of both pages with the partner's marks, looked at zoomed in.
4. **Entry on a pad, and the print.** The symbol grid; the Partner page and the codes printed in
   the riso like the other menus (`RisoMenu`), rather than plain controls.
5. **A paired playtest,** then tuning: the stars bank, how useful charts are against the ink
   wells' prices, whether keys crossing makes the rare colours too easy.

Phase 1 is useful to play on its own; each later phase adds kinds of code without changing
those already made (a kind is four bits, and seven of the sixteen are spoken for).

## Later

Kept from the preliminary plan, each a new kind of code on the same system, none needed for the
above.

- **A door opened in the partner's copy** (the sender pays its key or its price; the code writes
  `LevelRecord.opened` there), and **the partner moved** to a floor the sender picks, for stars
  by distance as `Warp` costs.
- **A spell lent** out of a slot and given back by a return code, or taught for a high price.
- **A route:** a few numbered pins in one code.
- **Pins printed in the level** as small signs (`Signpost` and its art are kept and unused).
- **Charts of side worlds,** and a boss's column told (on two seeds the partner's game can work
  it out, `Bosses.column`, so it would be sold at a shrine as the player's own hint is).
- **Paired seals,** the 2023 idea: a seal in one copy whose answer is printed on a stone that
  only stands in the partner's, laid by hashing both pair codes and the cell (no world RNG), laid
  last, guarding rewards and never the way on.
- **Hot seat:** two runs on one machine taking turns. `pair_test` does this already with two
  save paths; offering it to players is a menu and a second save.

## Open questions for the playtest

- **Balance.** Two purses and two rings make a pair richer than one player, and prices rise
  with the square of the depth (`Rules.grown`), so the deeper player can pay the other's way with
  small change. Whether prices or foes should rise in a paired run, or sending should cost.
- **Pace.** The two drift apart in depth. Whether anything should pull them together.
- **A run that ends.** A new run draws a new stamp, so the partner must be given the new pair
  code and gifts on the way are lost. Whether a pair should outlast a run (the stamp kept, the
  gift numbers carried on).

Keep this file in step as phases land, with `DEEPER_PLAN.md` (a section for paired play, its
numbers and its tests) and the "Where things live" notes in `AGENTS.md`.
