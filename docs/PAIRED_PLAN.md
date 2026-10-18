# Paired play: a preliminary plan

Two players, each on their own machine and in their own run, play paired. Nothing is networked,
and the game counts on no other channel: **the only way the two communicate is by coded message.**
One game prints a code, its player passes it on (however the players like: aloud, by text, on
paper), and the other player types it in. Each enters their own seed and their partner's, and
from then on each game can lay out the other's world, so each player can look at the partner's
map. Everything else crosses as a code: where a player is, an instruction marked on the partner's
map, and help (stars, a key, a spell, a move to another spot, a door opened).

This was the idea the game began with (the 2023 jam build dealt an arrow code with each key, and
its goal needed a code). This plan brings it back on top of the game as it is now. It is
preliminary: each section says what the owner has decided, what is proposed, and what is open.
The phases at the end give an order of work.

## Decided (the owner)

- **Non-networked.** The two games never talk to each other. Everything passes through the
  players: seeds at the start, codes during play.
- **Coded messages are the only channel.** Nothing is assumed to pass between the players but
  codes, so anything one needs to tell the other (where they are, where to go) is a code too.
- **Two seeds.** A paired run is started with the player's own seed and the partner's.
- **The partner's map.** Each player can look at the partner's map, to give instructions (sent as
  codes).
- **Codes for help.** Things are sent by codes, made in one game and entered in the other:
  stars, keys, spells, moving the partner (teleporting them) and opening doors are the first ideas.

## Why it fits the game as built

- **A world is its seed.** Every level comes from `Rules.level_seed(run_seed, depth)` and the
  difficulty preset, and must be identical on every visit (see AGENTS.md, "Level generation").
  So either game can lay out any level of the partner's world without being told anything more.
  The generator already builds levels off the scene (`LevelLoader`'s worker, `TestKit.build`).
- **The map draws from layout and record.** `RisoMap._other_level` marks any level from its
  layout and its `LevelRecord` (cleanup item 4). A partner's level is a layout with an empty
  record: everything as it was laid out, nothing taken or opened.
- **Records already hold what changes.** A door opened, a key taken or a key dropped
  (`LevelRecord.opened`, `dropped`) and stars and keys carried (`Coins`, `KeyRing`) are all
  plain state. Applying a code is writing to them, with no world RNG and so no change to any
  layout.
- **Code entry exists.** `CodeMenu` (`scripts/code_menu.gd`, `prefabs/code_menu.tscn`) still
  takes an arrow code (`<`, `>`, `^`, `v`) with the d-pad and checks it against a list. Nothing
  opens it now. It is the 2023 jam's, not yet printed in the riso.

## Pairing

*Proposed.*

- **The pair code, not the bare seed.** What a player sends the partner at the start is a
  short code holding their seed, their difficulty preset and a check of the build. The preset
  matters because it changes layouts (`Difficulty.foes`, through `LevelGen.foes_per_area`): the
  same seed on Normal and on Hard gives different levels. The build check (say, a few bits
  hashed from the layout fingerprints) catches two players on builds whose generators differ,
  which would otherwise show a map that does not match the partner's world.
- **The start menu** gets a "paired" start beside the seed field: your pair code shown, the
  partner's typed in. A solo run is a paired run with no partner. The pair is kept in the save
  (`RunState`).
- **Who is who.** The lower seed is side A and the higher is side B, so each side numbers its
  codes apart from the other's. Two players on one seed (racing the same world) would need a side
  picked by hand.
- **No layout changes.** Pairing draws nothing from the world RNG and lays nothing new, so a seed
  is the same world paired or alone, and `layout_fingerprint_test` stays as it is. Paired seals
  (below) are the exception, if the owner wants them.

*Snag found while planning.* The preset is a global (`Difficulty.preset`, set with F7) and is not
saved with the run. Laying out the partner's levels with their preset means passing the preset
into each build rather than reading the global. It also means a solo run's layouts change if F7 is
switched mid-run. Whether that is meant is worth deciding separately.

## The partner's map

*Proposed.*

- A third map page, **Partner**, after the worlds page: their worlds grid and, picked on it, any
  of their levels on the level page, drawn with the same marks and legend.
- **Fully inked, as laid out.** The helper sees every cell of the partner's levels (their ink is
  the partner's to buy, not the helper's), but sees each level as it was laid out: doors shut,
  keys and stars in place, bosses alive. The page says so. Nothing the partner does reaches it
  except by code: their place from a "where I am" message (below), and whatever the helper's own
  codes changed for them (a door the helper opened shows open, as the helper's game made that code
  and remembers it).
- **The partner's marks.** Where the partner was last reported, and the marks the partner has
  sent (below), print on this page as the ghost does on yours, each noting how many codes ago it
  came, since nothing says how stale it is.
- **Cost.** Laying out a partner's level costs what any level costs, on the worker thread, and
  only when looked at. The cache can keep the partner's levels apart from the player's.

*Open.* Whether the helper sees the partner's levels fully inked from the start, or only the
levels the partner has said they reached, or must pay to ink them. Fully inked is the simplest and
closest to "view their map to give instructions".

## Messages: telling, not giving

*Proposed.* With codes the only channel, instructions are codes too. A message carries
information and costs nothing to send. Entered twice it only says the same thing again, so it needs
no number (no replay guard), only the check.

- **Where I am.** The sender's place: world column, row and cell. It marks them on the receiver's
  partner page.
- **A mark on your map.** Picked on the partner page: a cell in one of the partner's levels and a
  word from a short fixed list (go here, look here, danger, a key, a door, a secret, wait). It
  prints on the receiver's own map at that cell, and in the level itself as a small printed sign
  where the receiver will come across it (accent ink, as a reward mark; pink for danger). This is
  how "view their map to give instructions" works without talking: the helper studies the
  partner's level and leaves them signs.
- **A route.** Perhaps later: a few marks in one code, numbered 1, 2, 3, so the way through a
  level fits in one message.
- **What I did.** Perhaps later: "I opened the door at...", "I took the key at...", one thing a
  code, so the helper's page can catch up with the partner's level. Without it the helper sees the
  level as laid out and has to ask.
- **Asking.** A message can also be a request: "send stars", "open this door" (picked on your own
  map), "where are you?". The receiver's game shows it as a note on the map, and the partner
  answers with a code of their own or not at all.

*Open.* How long the word list is (each extra bit is part of a longer code), and whether a mark
in the level prints for good or fades after a while.

## Codes

*Proposed.*

- **What a code holds.** Its kind (a message, or a gift: stars, key, spell, move, door...), what it carries (an amount,
  a key colour, a spell and tier, a place and cell), the sender's side and the code's number, and
  a check. The check is a hash of all of that and both seeds, so a code works only in its own
  pair, only from its sender, and a mistyped symbol is caught rather than doing something else.
- **Once only, for gifts.** A code that gives something (stars, a key, a spell, a move, a door) is
  numbered; a message is not (above). Each side numbers its gifts from 1. The receiving game keeps which numbers it has
  taken (a high-water mark and a small window behind it, in the save), so a code read twice, or
  typed again later, does nothing. Codes can be entered out of order.
- **Sending costs the sender.** Making a code spends what it sends: the stars leave your purse,
  the key leaves your ring, the spell leaves your slot. Help is a trade, not a copy. The receiving
  game cannot check that the sender paid; with two players working together, that is fine.
- **Length.** About 48 bits: 4 for the kind, 8 for the number, up to 24 for what it carries (a
  place and cell is the largest: world column, row, and x and y in the level), and 12 for the
  check (a typo slips through about once in 4,000). That is 12 symbols from an alphabet of 16, or
  24 arrows.
- **The alphabet** (*open*): arrows, as in 2023 (easy on a pad, long to pass on); 16 printed
  shapes, such as the 12 `RisoMarks.SIGILS` and four more (short, readable, entered from a 4×4
  grid with the stick); or letters and digits (quickest with a keyboard, plain).
- **Making and entering codes.** Both on the map: making one from the partner page (pick a door
  on their level, pick "open it", get a code) or from a send menu (stars, a key, a spell), and
  entering one from a field on any page. `CodeMenu` is reworked and printed in the riso like
  the other menus (`RisoMenu`).

## Gifts: what can be sent

*Proposed, in rough order of how simple they are.*

- **Stars.** An amount from your purse to theirs.
- **A key.** A coloured key, the skeleton key, or an exam paper, off your ring onto theirs (a full
  ring drops the oldest at their feet, as now). Key colours mean the same in both worlds, so a red
  key from one opens a red door in the other. Papers sent across make the institute a two-player
  puzzle: one attends, the other sits the exam.
- **Open a door.** Picked on the partner page: a locked door, a paid deeper door, a toll gate or a
  shut gate in their level. The helper pays its price (the key or the stars) and the code opens it
  in the partner's record (`LevelRecord.opened`). It opens whether or not the partner is there.
- **Move them** (teleport). Picked on the partner page: a floor in one of their levels. The code
  moves the partner there, as a warp does, for stars by distance (as `Warp` costs stars).
  *Open:* any level, or only levels the partner has visited (the receiving game can refuse a level
  it has never seen, before taking the code's number, so the code is not wasted).
- **A spell.** Lent: the spell leaves the sender's slot and goes into the partner's, at the
  sender's tier, until a return code gives it back. *Open:* lent with a return, or given for good,
  or taught (the sender keeps it, as the institute's teaching does, at a high price).
- **Later ideas.** Relighting the partner's lantern; ringing an institute bell or throwing a crag
  tower switch in their level (both are level puzzles that a second pair of eyes could solve
  together); a boss's relic passed on.

## Paired seals: the original idea

*Proposed, optional.* In the 2023 build the goal needed a code. The game could again have things
that only the partner can open: a **paired seal** in your level whose code is printed on a stone in
a level of the partner's world. The partner finds the stone and sends you its code. This is
information only one side has, which makes the messages the game, not just the help.

- They would appear only in paired runs, laid by hashing both seeds and the cell (no world RNG),
  and laid last, so solo layouts do not move. Each game lays out both its own seals and the
  partner's stones, so neither needs telling.
- What they guard: optional rewards (a vault, a relic hint), not the way on, so that a pair
  playing apart is never stuck. That fits the owner's traversability rule (no pass makes a level
  crossable, and none makes one uncrossable for want of a partner either).

## Open questions

- **Balance.** Two purses and two key rings make a pair richer than one player. Whether prices,
  key rarity or foes should rise in a paired run, or whether the costs of sending are enough.
- **Pace.** The two runs drift apart in depth. Whether anything should pull them together (help
  costing more across a big gap in depth, or paired seals at matching depths).
- **Deaths and the ghost.** Whether codes can be entered while a run is over, and whether a
  partner can do anything about the other's ghost.
- **Replays and codes.** Whether a code's number should run per run (reset on a new run) or per
  pair (kept across runs), and what happens to codes made but never entered.
- **Hot seat.** Whether two runs on one machine (two saves, taking turns) should be supported. Now
  there is one save (`RunState.save_path`).

## Phases

1. **Pairing and the partner's map.** The pair code (seed, preset, build check), the paired
   start, the pair in the save, the preset passed into builds, and the Partner map page fully
   inked as laid out. Tests: a pair code round trip in `unit_test`; a level laid out for the
   partner's seed and preset matching a build of that seed alone; the partner page's marks
   matching the partner's layout; `layout_fingerprint_test` unchanged.
2. **The code system and messages.** Encoding, decoding and the check; the entry and making
   screens printed in the riso. Messages come first, as the pair cannot help each other without
   them: where I am, and marks picked on the partner page that print on the receiver's map and in
   their level. Tests in `unit_test` (round trip, a typo caught, a code from the wrong pair or side
   refused) and a scene test of a mark arriving on the map and in the level.
3. **Gifts: stars and keys.** Numbering and the replay window in the save; the sender paying.
   Tests: a gift taken twice doing nothing; a key and stars leaving one ring and purse and arriving
   on the other.
4. **Doors and moves.** Gifts made by picking on the partner page. Tests: a door opened by a code
   staying open on a revisit, and showing open on the sender's partner page; a move landing on a
   floor.
5. **Spells and papers.** Lending and returning; papers across. Tests with the shrine and
   institute tests.
6. **Paired seals**, if wanted.
7. **A paired playtest**, and tuning from it.

Keep this file in step as phases land, as for `DEEPER_PLAN.md` and `REGIONS_PLAN.md`.
