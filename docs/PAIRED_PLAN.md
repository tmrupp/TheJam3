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

Its last section, "The larger goal", is not yet a plan: allied characters with errands, and a
true end past the bosses, partly decided (knowledge only, paired, the same for everyone).

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
| Pair | 10 | seed 20, run stamp 8, preset 2, build and band layout 8, side 1, check 11 |
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
  last, guarding rewards and never the way on. "The larger goal" below gives the idea faces.
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

## The larger goal

*A brainstorm, narrowed by the owner's answers of 15 November 2026. Still not a plan to build:
nothing in the phases above depends on it.*

Beating every boss and setting their trophies on the stands wins a run "normally". Over that
there is a larger goal in the manner of an alternate reality game: the wizard meets **allied
characters** who have errands, conditions and other dealings; meeting them, doing things for them
and delivering things to them brings the **true end** nearer: another level and another boss.

### Decided (the owner, 15 November 2026)

- **Knowledge only, as in Outer Wilds.** What carries from run to run is what the players know.
  Nothing done for an ally is kept past the run. (This follows the owner's earlier choice of
  knowledge as the progression between runs, 9 November, `docs/REVIEW_PLAN.md` §4, built as
  `Known`.)
- **Probably paired.** The true end is what paired play is for.
- **The same for everyone.** Allies, errands and the true end are laid by place, as relics are,
  so every player meets the same ones at the same places.
- **No words.** Allies say what they want in marks, as the map and the tutorial do.
- **The true end is procedural, huge and linear:** one long level laid like the others, with
  its boss at the end.
- **The allies are the major arcana** (said after the answers above): the Fool, as the wizard is
  printed, meets the other cards on the way to the World.
- **The theme is otherwise open.** Whose dream this is (or whether it is a dream) is not settled;
  nothing below depends on it.

### What "knowledge only" asks of the design

- **The true end opens within one run.** Everything that opens it is done in that run: the
  things delivered, the conditions met, the codes passed. The test of the design: a pair with
  nothing kept (no save, no `Known`) who know everything can reach the true end in one run.
- **Long to learn, short to do.** The first time takes many runs of finding out; once known, it
  is a handful of places and deeds, as Outer Wilds is minutes for a player who knows it. A run
  here is hours, not 22 minutes, so the doing part must stay short.
- **What a player learns** is of three kinds: *where* (a place in the grid), *how* (a condition:
  come with the flame out, carry darkness, arrive in a named period) and *what a mark means*.
  The map teaches where; allies teach how and what.
- **What the game may keep.** `Known` is this game's ship log: it may keep what was *seen* (a
  place, an ally met there, the marks it showed), never what was *done* (an errand finished, a
  piece won). Nothing in the save or `Known` opens anything.
- **What allies give**, then, is in-run (passage, a token to carry to the end in this run, a
  thing to deliver to another ally) or knowledge (a place marked on the map, a mark explained by
  being shown beside its thing).

### The same for everyone, split between two

- **Laid by place alone,** with a salt from `Salts`, as `Relics.at` and `Rules.lodestone_at`
  deal theirs: the same in every run and for every player. The answers will end up on a wiki;
  Outer Wilds accepted the same.
- **Two sides.** At pairing each run takes a side, A or B (printed as two marks, not letters).
  Every place holds its things for both sides, but each side's copy shows its own half: where A
  sees a lock of marks, B sees what opens it. The same for every A and every B, so the halves are
  shared knowledge too.
- **The pair code carries the side** (one bit, see "Codes"). The joiner takes the side the
  host did not; two players on one seed need it, as nothing else tells them apart.
- **Talking.** Codes stay the game's only channel, but players will talk too. The split halves
  should hold either way: hard to put in words (marks with no names), easy to pass as a code,
  as in Keep Talking and Nobody Explodes. A code becomes the translation between the halves.
- **Alone?** Knowledge only makes a solo pass thinkable: play a run as A to learn A's half, then
  one as B. Steps that need both copies at once (a code made in one while the other stands at a
  door) would need a hot seat. Open (below).

### No words: the labelling problem

Speaking only in marks is the hardest part of the idea. An ally that wants "bring a moss key
here with your flame out, during the second period" has to say it with no words, and a player
has to read it without a manual. Most of that can be made easy, and the rest taught.

- **Match, don't mean.** The surest wordless ask is a match: the ally shows a mark, and what it
  wants wears the same mark somewhere in the world. Matching needs nothing learned. The game
  already does this: a switch and its gate, a bell and its lock, share a sigil
  (`RisoMarks.sigil`, `switch_plate`, `sigil_plate`). Make every ask a match where it can be.
- **The nouns are the map's.** The marks for keys, seeds, papers, lanterns, ghosts, boss seals,
  trophies, the bands' emblems and places as numbers are one set, shared by the map, the HUD and
  the world (`RisoMarks`). A player who has used the map can already read them, so an ally draws
  its ask in those marks, never new ones for old things.
- **Show the deed, as a card.** For what a match cannot say (a condition, an order), the ally
  holds up a card: a small printed picture of the Fool doing it (the flame out by this ally; a
  seed carried to a plot; the bell rung before the door). The control cards teach the controls
  this way already (`ControlHint`), and a tarot card is a picture by nature.
- **Label the world.** Whatever an ask names wears its label where it stands: an arcanum's
  numeral over the things it cares about (on the plot, the font, the tower), its emblem stamped
  where it can be seen from the way. A place is named as the map names one (`place_marks`:
  world, row and side world as numbers, no words).
- **Numbers are not words.** Roman numerals on the cards and the places' numbers are allowed,
  as the map prints numbers now. They do most of the labelling.
- **The few relations are taught once.** "Bring", "without", "before", "when" have no thing to
  match. Keep them to a handful, and teach them early and wordlessly, as the tutorial teaches the
  controls: each shown with its deed done in front of the player (the Magician's part, below).
  Or do without them: an ask as two pictures, before and after.
- **The tarot helps.** Its pictures are known outside the game and can be looked up (the Hermit's
  lantern, the Tower struck by lightning, the Star pouring water), which suits an ARG: a player
  who knows them reads faster. The game must still be solvable without knowing any tarot, by
  matching and by the cards' pictures.
- **Words as a last resort** (for the owner): real tarot cards print their names at their foot.
  Printing them would be the only words in the game.
- **Tested on strangers.** Whether an ask is read is only learned by watching someone new try
  it, as `docs/PLAYTEST_PLAN.md`'s notes on the tutorial were.

### The allies: the major arcana

The allies are the major arcana (the owner, 15 November 2026). The game is a tarot print
already (`RisoPrint`: "tarot-print presentation"), and the wizard is printed as the Fool
(`RisoCostume`), so the allies complete a deck that is half there. The Fool's journey through
the other twenty-one cards, from the Magician (I) to the World (XXI), is the old story of the
major arcana and the shape of the larger goal: twenty allies to meet, the Fool as the player, the
World at the true end.

**Five bands of four.** The twenty between the Fool and the World fall four to a band, each
where the game already has their picture:

| Band | Arcanum | What of theirs the band already has |
|---|---|---|
| Garden | I The Magician | The four tools on his table: the four key colours (as the four suits); stands near the start and teaches the marks |
| Garden | III The Empress | Plots, seeds and what grows from them |
| Garden | VI The Lovers | Two figures: the pair itself; an ask only both sides together can answer |
| Garden | VIII Strength | Taming the beast: the worm or the bramble |
| Cemetery | XIII Death | The graves, the crypts |
| Cemetery | XVIII The Moon | Night, the moons that give the dash back |
| Cemetery | XIX The Sun | The sun and shade blocks; light that wakes the dead |
| Cemetery | XX Judgement | The dead rising (skeletons rise in light) |
| Institute | II The High Priestess | The librarian's book and hush |
| Institute | V The Hierophant | The timetable, the classes, the institute's rule |
| Institute | XI Justice | The proctor's staff; stolen papers |
| Institute | XV The Devil | The eldritch beast and its souls |
| Crags | IV The Emperor | Stone, mountains, the castle ruins |
| Crags | X The Wheel of Fortune | The gondola's wheel and its stations |
| Crags | XIV Temperance | Tempered spells at the lodestones |
| Crags | XVI The Tower | The watchtowers, their spires struck awake |
| Sky | VII The Chariot | The balloon, carried by the wind |
| Sky | IX The Hermit | His lantern, on a high island |
| Sky | XII The Hanged Man | Hanging under an island: falling, waiting |
| Sky | XVII The Star | The stars, the open sky |

The demo's garden holds four of them, the Lovers among them, so the first step can be the
garden's alone. The bosses (worm, bramble, necromancer, beast, golem, whale) stay bosses; the
Devil and Strength name what is already there rather than replacing it.

**Where each stands.** "The same for everyone" and a random start conflict if an arcanum stands
at one place in the whole grid: a run starting thousands of columns away could never reach it.
So each is laid as the lodestones are (`Rules.lodestone_at`): once in every stretch of so many
worlds along its band's rows, at a place hashed from the stretch. Every player meets the same
Hermit at the same places, and one is always within reach.

**What each asks,** from a small table of kinds: *bring* a thing (a rare key, a seed, a named
paper, a count of stars, darkness); *carry* a sealed thing from one arcanum to another, perhaps
only openable in the other copy; *come as asked* (flame out, unhurt, nothing slain here, in a
named period, the wind one way); a *chain of swaps*; a *riddle in marks* answered elsewhere.
Deliveries are new "colours" on the ring (`Keys`), so they are carried, dropped, saved and sent
with nothing new. An arcanum's ask fits its card where it can: the Hermit wants the flame
brought up to him lit, Death wants it out, Temperance a tempered spell.

**Met in any order, proven in order.** The arcana in the grid can be met and learned from in
any order, as Outer Wilds' planets are. The true end's level is the journey in order (below).

### The true end: a huge, linear level

- **Laid like any level,** from a fixed seed, so the same for everyone: a side world of its own
  kind (`Worlds.KINDS`), as the belly and hyperspace are, so it moves no other level.
- **Hyperspace is the model:** one long strip whose way on is always one way. Hyperspace is 64 by
  16 cells; this would be many times that, a string of strips joined end to end with lanterns
  between, or one strip that the loader's chunk sleeping already makes affordable (see
  `bench_big_level`).
- **The Fool's journey, in order.** Twenty stretches, I to XX in the cards' order (the Magician's
  first, Judgement's last), each printed in its arcanum's band and asking what that arcanum taught. What was
  learned in any order in the grid is proven in order here: the linear level is a test of
  knowledge, card by card.
- **Paired,** in two copies split by side: a door in one copy opened by a code from the other, a
  crossing only the other copy shows, the two players going through side by side.
- **Its boss, and the World.** The World (XXI) waits at the end. Whether the World is the boss,
  or what the boss keeps the Fool from, is the theme's to say. The fight is in both copies at
  once: its tells or its weak point printed only in the other copy, so each player guards for the
  other.
- **The way in** opens by deeds in this run: the seventh stand in the trophy room, marked XXI
  (one more stand, with no boss's seal, already asks the question from the tutorial's end), or a
  place in the grid that is only found by learning.

### What these answers rule out

Pieces kept from run to run; errands dealt by the run's seed or the pair; a few words for the
allies; a hand-made last level; the dream as a settled theme. The "three sizes" of the first
brainstorm fold into one: the seventh stand's allies, with letters between the two copies, and
everything solved by knowledge.

### Still to settle

1. **Alone:** can a solo player reach the true end (one side after the other, or a hot seat), or
   only a pair?
2. **What `Known` keeps of an ally:** its marks as seen (a log), or nothing.
3. **The bosses:** must they be beaten on the way (their gates sealed while they live), or can a
   pair who knows go straight to the true end?
4. **Traversability in the last level.** The owner's rule is that no level is made crossable. A
   huge linear level that cannot be crossed stops the true end. Whether the rule holds there
   (hyperspace's own dressing lays ledges where a rough reach cannot get on, `Hyperspace._bridge`,
   which may want a look under the rule too).
5. **How long the doing part is** once known: one sitting?
6. **The theme:** whose story the Fool's journey tells here, and what waits with the World.
7. **The cards' names:** printed at their foot as on real cards (the game's only words), or not.
8. **The arcana in the bands:** the table above is a first fit; which card goes where, and what
   each asks, is the owner's.

### A first step

The smallest thing that tries the idea, after code phases 1 to 3: in the demo's garden, two
arcana laid by place (the Magician, teaching the few relation marks, and the Lovers, whose ask
is split between the sides), asks made as matches and cards, and a short linear side world opened
by them, two stretches long, without its boss. A paired playtest of that says whether
the split halves and the wordless asks work before anything is laid across the bands.

Keep this file in step as phases land, with `DEEPER_PLAN.md` (a section for paired play, its
numbers and its tests) and the "Where things live" notes in `AGENTS.md`.
