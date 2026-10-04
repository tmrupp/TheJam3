# Deeper: design and implementation plan

The goal of the game becomes getting deeper. The world is a grid of generated levels addressed by **(seed, depth)**. Every seed is a column you can dig down. Moving sideways steps to the neighbouring seed, as if you had started there. Because every level is a pure function of its address, players exploring the same seed see the same places, so sharing coordinates is how people explore together.

No level is guaranteed to be fully reachable. Places you can't reach yet are the point: you come back with new abilities.

## Decisions

| Topic | Decision |
| --- | --- |
| Lateral movement | Infinite. Left and right exits go to `seed − 1` / `seed + 1` at the same depth. Each is locked with a key colour dealt by the level seed. The key is kept, the door stays open, and the side door you arrive through opens behind you. |
| Exit distance | Grows with depth, physically. Deeper levels place their exits further from the arrival point (and may be larger). |
| Going back | Always free. |
| Deeper | Costs stars, paid once per deeper door; the door then stays open. |
| Reachability | Not guaranteed. Exploration of the generated space is the game. |
| Respawn | At the last lantern you lit. It absorbs one death, then burns out. The run's starting lantern is lit. |
| Death | A lit lantern brings you back once; you drop all your stars into a ghost. The used lantern becomes spent for the rest of the run. |
| Restoring protection | Find and light another unspent lantern. Recovering stars or a ghost restores only your currency. |
| End of a run | Dying without a lit lantern ends the run. |
| Keys | Not used up. You carry one; grabbing another leaves your current key where the new one was. Keys work in any level. |
| Abilities | Bought at shrines (no shop), and every ability has upgrade tiers. Cheaper deeper. A shrine offers its ability tier or, instead, healing to full (dearer deeper). |
| Ways to play | Enter a seed and dig its column, or start at a random seed. |

## 1. The world: a grid of (seed, depth)

- `level_seed = hash(seed, depth)` drives everything: WFC terrain, object placement, key and door colours, the shrine offer, and the depth band (WFC sample region and riso realm).
- Four exits per level:
  - **Deeper** leads to `(seed, depth + 1)`. It is placed low in the level, costs `P(d)` stars once, then stays open.
  - **Back** leads to `(seed, depth − 1)`. It is placed high in the level and is free.
  - **Left and right** lead to `(seed ± 1, depth)`. They are placed at the side edges.
  - Each side door is locked with a key colour, `lateral_lock(level, side)`, dealt by the level seed. Carrying that colour opens it and you go through; the key is kept. It then stays open in the level record. The side door you arrive through is marked open, so the way back never needs a key.
  - **A way out of the first level:** at depth 0 one side door (left or right, whichever side of the start it falls on) is placed on the nearest floor at least 5 cells from the start that the wizard can hop to from it, instead of at its side edge. A key in that door's lock colour is laid on a floor hopped to from the start, as near the way to the door as can be (the start key, on top of the level's usual keys). The way from the start to both is kept clear of doors and switch gates (`World.keep_clear`). "Hopped to" is the rough reach shared with hyperspace (`scripts/worlds/Reach.gd`), with hops 3 cells across rather than 4, so it is easy. `tests/start_escape_test.gd` checks 40 first levels.
- You arrive at the matching exit of the next level: going deeper puts you at its Back exit, and so on.
- Exits sit at least `D(d)` cells from the arrival point, with `D` growing with depth. Deeper levels can also grow beyond 64×64.
- Every level spawns an unlit lantern at its arrival point.
- **Connected caves:** after the terrain is generated, open pockets under 6 cells are filled with rock. Every other open region is joined to the largest by carving the shortest tunnel through rock, nearest first, until the level is one cave. So every exit, the shrine, the ink well, keys, lanterns and moons are connected through open space. They are not necessarily reachable: gates (doors, cracked walls, locked or unpaid exits) and abilities (height, gaps) still apply. `tests/connect_test.gd` checks 20 levels across worlds and depths.
- **Size grows with depth:** `level_size(d)` = (36 + 3d) × (30 + 2.5d) cells, capped at 60 × 48 (from depth 8). That is 36 × 30 at depth 0 and 54 × 45 at depth 6. (It was 6d × 5d to 80 × 72, which grew too fast and ran slowly.) Each level is enclosed in solid rock three cells thick, flush against its edges, and the camera stops one cell into that rock.
- **Level record:** each visited level stores only what changed. That is stars taken, doors opened, keys dropped or taken, the deeper door paid, lanterns lit, and the ghost. On a revisit the level regenerates identically and the record is applied on top.
- **Determinism:** a failed WFC collapse currently retries with `randi()`. It must retry with `hash(level_seed, attempt)` instead. Neighbouring levels pre-generate on the background thread so transitions are instant.

## 2. Death, the ghost and the end of a run

- **Die with a lit lantern:** all carried stars go into a ghost at the death spot, recorded in that level. Any previous ghost and its stars are lost. The lit lantern absorbs the death, burns out, and brings you back to its location, even if it is in another world.
- **Spent lanterns:** each lantern can absorb only one death per run. Its cell is recorded as spent in its world's record; travelling away, revisiting, or continuing a saved run cannot relight it. Switching to another lantern before dying does not consume the former one.
- **Restore protection:** interact with another unspent lantern. It becomes your protected respawn point. Ghost recovery and star collection never restore protection; you can light another lantern without recovering the ghost first.
- **Die without a lit lantern:** the run ends. The seed's levels are unchanged, since they are generated. Your character and level records reset, and the new run starts with a fresh lit lantern. The ended run's save is deleted immediately.
- **Arming:** a ghost can only be recovered once the player has stepped off it, so dying on the respawn lantern doesn't hand the stars straight back.
- **Presentation:** the HUD's flame (beside the health beads) burns yellow while protected and is a hollow, pulsing pink flame otherwise, including after recovering a ghost. Spent lanterns have empty, dark glass, a charred wick and no light pool. Unspent lanterns keep their low ember. Insects no longer circle lanterns. The ghost uses the printed astral-silhouette style, and the HUD points toward it when it is in another level.
- **Saves:** existing version-1 saves remain readable. An old unprotected save marks its last respawn lantern spent when loaded. `tests/death_test.gd` covers consumption, relighting rejection, cross-world deaths, star and ghost recovery, revisits, save migration, and run reset.

## 3. Keys

- A held key opens every door of its colour in any level. Opened doors stay open.
- You carry one key at a time. Grabbing a new one leaves your current key where the new one was, and the level record keeps it there.
- Door colours are dealt per level. A matching key may be far away, or in another column.
- A dropped key arms only once the player has stepped off it, so the swap does not immediately grab it back.

## 4. Shrines and tiered abilities

- One shrine per level, standing on two floor cells (its three stations packed side by side) 3–14 cells from the deeper exit.
- It offers three things: two different abilities and mending. Taking any one spends the shrine, and the level record keeps it spent: At least one of the two is always a strict upgrade, a gain with nothing given up: a new perk or the next tier of something already known, never a spell that would replace the one in the slot (if both picks would be swaps, the second is traded for the first strict upgrade along).
  - **The boon:** the next tier of an ability. The ability is picked by `level_seed`, or is the next one along that still has a tier to learn.
  - **Mending:** healing to full. It is the alternative to the boon and does nothing at full health.
- **Pay to learn.** There is no menu: interact with the side you want. The shrine prints no text from afar: stepping up to a niche (or the mending bowl) pops up a larger plaque over it with the ability's name, tier and price (or mending's price).
- **Prices:**
  - Learning costs `S(d, tier) = max(3, round(10 × 1.6^(tier−1) × 0.8^d))`: cheaper deeper, dearer per tier.
  - Mending works the other way: `H(d) = round(3 × 1.35^d)`, which is 3 at depth 0 and 13 at depth 5.
- **Only the dash is known at the start.** Everything else is found at shrines. A shrine offers an ability not yet known before any upgrade: it starts from the seed's pick and goes round. Until learned, parry and astral projection do nothing, and there is no hex, so no killing enemies or breaking cracked walls.
- **One spell slot.** Hex, astral projection, parry, levitate, awareness and rift are spells, and all use the Spell button (Q, or the pad's X; the old Parry binding renamed). You carry one at a time: learning a different spell at a shrine replaces it, and the pop-up over that niche is topped by a "swap" tag. Perks (dash, double jump, wall climb, blink, vigor) stack. The spell given up is not lost: it stays in that shrine's niche at its tier (the level record keeps it), and interacting there takes it back free, leaving the spell you hold in its place, even after the shrine is spent. `tests/capture_shrine_left.gd` shows it.
- **Levitate:** press Spell in the air to stop falling and float. You drift slowly up and down with the stick and sideways at walking pace, until it runs out or you press Spell again. You get one float per landing, and a moon brings it back.
- **Awareness:** press Spell to sense the level. While it lasts, pointers at the edge of the view show where things are, like the ghost's arrow. A short cooldown follows.
- **Astral projection** uses the Spell button. Tap it to leave your body and go out as an untouchable projection. Tap again, or get hurt, to snap back to the body. Let it run out and you stay where the projection is. There are no astral orbs any more.
- **Rift:** learn it at a shrine, then press Spell to place an end at your position. A second cast places its partner; interact to travel between them. Casting again deletes both old ends in the current world and starts a new pair. Each world (seed, depth) keeps one spell-created pair in its saved level record: pairs in other worlds remain untouched and return when you revisit. Swapping spells preserves placed pairs; starting a new run clears them. Travelling always needs the interact key. Tier I requires standing on a surface; tier II allows placement in midair. At tier III, casting builds the run's one cross-world link instead (`MapInfo.rift_link`, saved with the run): place one end, travel to another level, place the other, and interacting with either end travels to the other's level and comes out of it. A third cast closes both old ends wherever they are; per-world pairs made at lower tiers stay.
- **Switch gates:** every level has at least one (0.6 per 1000 cells): a gate across a corridor, like a door but with no lock, and its switch on a floor elsewhere, at least 8 cells away and reachable from the way in with that gate shut. Interact with the switch, or hit it with a hex bolt, and the gate lifts for good (the level record keeps the switch thrown and the gate open). The map marks gates and switches.
- **Kinds of world** (`scripts/worlds/`): every place a run can be in has a definition, `NextWorldDef` (from `MapInfo.def_for(at)`; `MapInfo.here` for the place being played), and the rest of the game asks it rather than knowing which kind of place it is in. The definition says how the terrain is collapsed (`region`, `size`, `fallback`) and dressed (`populate`), where each exit leads (`lead`: the place, the way the transition sweeps, the exit arrived at; `neighbours` for prefetch), what each exit costs (`price`, `pay`), and how the place prints (`realm`, `grows`, `title`, `exit_dir`, `exit_grand`, `grid_at` on the worlds map). The base class is the ordinary cave level. Every other kind is a **side world** (`SideWorld`), reached through a door that some levels deal (`deals`, `entry_price`). You arrive at its way back (`Exit.BACK`, which returns you out of that door); its way on (`Exit.DEEPER`) leads to its `destination`, and from then on that level's way back leads in again (`arriving`). A dead end, whose destination is the level it was entered from, just returns there. Side worlds are listed in `Worlds.KINDS`. Kind k entered from level (seed, depth) sits at `(seed, -(k * 100000 + depth) - 1)` (`Worlds.side_at`, `origin_of`, `kind_at`), so each has its own record, save entry, prefetch and tile on the worlds map. A door into kind k is exit number `Worlds.door(k)` (16 + k), kept in the level's `exits`. Its price is paid once (`doors_paid` in the record). The exits taken are kept as `ways_taken`. **To add a world:** extend `SideWorld`, set its name, crossing direction (`way`), realm, size, sample and price in `_init`, override `deals` and `populate` (and `destination_for` with `arriving`, `depth_for` and `fallback` as needed), then list it in `Worlds.KINDS`. Its door, exits, prices, travel, prefetch, save entry, map ribbon and legend rows come for free.
- **The hyperspace door:** a rare second way down, dealt by the level seed in 18 % of levels from depth 1 (`Hyperspace.CHANCE`), on the floor furthest from the way in. It costs 5 times the deeper exit's price (`Hyperspace.PRICE`), paid once, and leads into **hyperspace** rather than straight down. It prints as a double arch (accent round pink) under a falling cascade of chevrons. `tests/switches_test.gd` covers switches, the hyperspace door and the parry; `tests/capture_switches.gd` takes stills.
- **Hyperspace** (`scripts/worlds/Hyperspace.gd`, a side world): a short, linear, hazard-packed crossing, 64 × 16 cells, between the level the door is paid in and the one `Hyperspace.DROP` (4) below it. It has no ink well, shrine, keys or side doors. You come in at its way back on the left; its way back returns to the level, out of the hyperspace door, free. Its gate on the right (printed like the hyperspace door, and free: it was paid on the way in) drops you at the way back of the level 4 below, and by a draw of the entry level's seed (`Hyperspace.drift`) a world to the left, straight down, or a world to the right. The levels in between are skipped, not visited. On screen it is "world N · hyperspace".
  - **Landing level:** a level hyperspace drops into (`Hyperspace.arriving`; where two would, the one from straight above wins, then the one from the left) has its way back lead into that hyperspace, arriving at its gate, and also an ordinary way up (`Exit.RETURN`, placed a few cells from the way back) to the level above it, arriving at that level's deeper exit. Using it joins the two on the worlds map.
  - **Address:** `(seed, -depth - 1)` (kind 0), the depth being the level the jump was paid in. Its `depth` is the middle of the drop, for enemy health.
  - **Terrain:** collapsed by the same WFC as any level, but from its own, more dangerous 32 × 32 sample, `wfc_images/chasm_gauntlet.png` (thorn-capped floors, thorn-bottomed pits, toothed ceilings, thorned islands; about 10 % thorns; `tests/make_hyperspace_sample.gd` draws it), as a 64 × 16 strip. The collapse alone is often not passable; the dressing makes it so (below).
  - **Dressing** (`Hyperspace.populate`): both ends (8 cells) are laid flat and safe, with the way back and a lantern at the left, the gate and a lantern at the right, and a rest lantern halfway along. Then the gaps are filled (`Hyperspace._lifts`): a gliding ledge every 4 cells across every wide open stretch, a stack of rising and falling ledges every 3 cells up every tall wall, with moons beside them (at least 4 cells apart). Last, a crossing is made sure of (`Hyperspace._bridge`): the cheapest way through the open air from the way back to the gate is found (keeping to floors, crossing air only where it must, and through thorns only where nothing else gets through: those thorns are cleared), and a rough reach (2 cells up and 4 across a hop, a cell further across per two fallen; a moon caught on the way gives another hop) is followed along it from the way back. Wherever the reach stops, the lift (or, failing that, a floating ledge or a moon) that carries a rider furthest on along the way is laid, until the gate is reached (at most 96). `Hyperspace.crossable` checks the result. Seven watching eyes and five wisps are spread along the floor (one every few cells), with four more moons and 14 stars. Five lasers (`Laser.gd`, `Hyperspace._lasers`) are set in its rock, spread along the way and at least 5 cells apart, each in a ceiling, wall or floor with at least 3 cells of open air in front: on a cadence (0.9 s warming up behind a faint flickering sight line, 0.7 s firing, 1.6 s resting, each out of step with the others) it fires a beam straight out until the first rock (or ledge or lift), which hurts only while it fires. Lasers are only in hyperspace for now.
  - **Theme:** hyperspace prints in a realm of its own (its `print_realm`, `RisoPrint.REALMS.hyperspace`: violet rock, aqua stars, a cold paper), switched to on the way in and back to the realm you came from on the way out. Its sky has no skyline and no still stars: a glow lies ahead and streaks of light rush back past the view, the near ones bare paper (`RisoBackground._warp`). Nothing grows there (no decor or fireflies).
  - **Tests:** `tests/hyperspace_test.gd` covers the addresses, generation (determinism, ends, lanterns, thorns, every one crossable), travel in and out, the landing level's two ways up, and the worlds map. `tests/capture_hyperspace.gd` takes stills.
  - **Worlds map:** hyperspace, like every side world, is a narrow accent ribbon on a smooth curve out of the middle of the bottom of the level it is entered from and into the middle of the top of the one it drops to. It leaves and arrives straight down and widens into a mouth where it meets each level (`MOUTH`), so it reads as poured from one into the other; in between it bows through a point in the gutter between columns, so it runs past the levels it skips rather than over them (away from the landing's column when it drifts a world sideways). The cursor's frame round it is open at the ends. It stands in for the link bar between them, is cut off at the page's edge rather than left out when it runs past it, and the cursor follows its curve; legend rows are named after the kind ("hyperspace", "hyperspace door"). `tests/capture_hyperspace.gd` takes stills.
- **Secret rooms and relics:** every level has secret rooms (0.6 per 1000 cells, at least one; `World.place_secrets`, placed last): a pocket of rock, 4, 3 or 2 cells across and 2 high, with rock under it (wholly in rock where there is room), entered at floor height from a floor beside it through a false wall. The room and its false wall are cracked cells holding the room's number, drawn and mapped as plain rock, even on an inked map. The false wall can be walked and shot straight through; stepping into it, a hex bolt striking the rock behind it, an astral projection drifting into it or a warp landing in it opens the whole room for good (`MapInfo.open_secret`; the record keeps it open), and its rewards appear: up to 3 stars, and the level's relic if it has one. **Relics** (`Relics.gd`, `Relic.gd`): tier I of the four big moves (double jump, wall climb, blink, levitate) only comes from a relic; shrines offer their higher tiers once the move is known. From depth 1, 22 % of levels hold one (every level in a debug run), a move dealt by the seed, in a secret room (on an open floor if no room fits). Interact and pay to take it, a lot: 4 times the deeper exit's price in its level (`Relics.price`; 44 stars at depth 1). It teaches the move's next tier; a relic bringing a spell leaves the spell it replaces there to take back free, as at a shrine. It prints as a medallion (an accent ring round a paper disc with the move's mark) over a small plinth. At full health, when there is nothing to mend, a **shrine's** third station sells the whereabouts of the nearest relic neither found nor already marked (searching 8 levels across and down; 1.5 times the deeper price, `Relics.hint_price`; buying it spends the shrine, like mending). It shows that relic's move on a small medallion, and the relic is marked on the worlds map: on an unvisited level, a faint tile you can pick and open, whose page shows where the relic waits; one off the page is pinned to its edge with a chevron pointing the way. `tests/secrets_test.gd` and `tests/phasing_test.gd` cover them; `tests/capture_secrets.gd` takes stills.
- **Moons** are dash resets, with a target of 3 per 1000 level cells, placed only in open air: clear on every side and below, and at least 6 cells apart. They reject platforms in the fall below, including the full width and travel of moving platforms, until intervening rock or spikes block the fall. Suitable spots above spikes have triple the selection weight. Touching one spends it at once (it shows as a sliver), whether or not you have used your dash. While you stay inside it gives your dash back, even mid-dash, as often as you use it. Once you leave it waxes back over 2.5 s. Moons are never used up.
- Tiers live on the player (`Abilities.gd`) and reset when a run ends. The upgrade menu and the old `Upgrade`, `UpgradeManager`, double-jump and wall-climb nodes are gone.

| Ability | Start | Max | Each tier |
| --- | --- | --- | --- |
| Dash | I | IV | dashes 0.07 s longer |
| Double jump | – (a relic) | III | one more air jump |
| Wall climb | – (a relic) | III | I lets you climb (1 s); each further tier adds 0.5 s |
| Blink | – (a relic) | III | replaces the dash; reach 300 px, +100 per tier |
| Parry | – | IV | I: a 0.3 s guard; a hit caught is turned aside: a touching enemy takes 1 damage and is stunned 3 s, a shot is reflected at its shooter as a bolt; the dash comes back, the guard is ready again, a moment of invulnerability and a hit-stop; 1.2 s cooldown on a miss. II 0.45 s guard, 0.9 s cooldown; III 2 damage; IV each parry heals 1 |
| Astral projection | – | IV | I: 5 s floating out of the body, steered on both axes through rock and anything else solid (kept inside the level); drifting into a secret room opens it; ending it inside rock costs a heart and puts you back in your body. Each tier lasts 2 s longer |
| Hex | I (the starting spell) | IV | I stuns only (3 s); II wounds (1 damage) and stuns; III +1 charge; IV 2 damage and pierces. One charge back every 6 s; cracked walls break at any tier |
| Levitate | – (a relic) | III | I holds your height until you press Spell again; II the stick drifts you up and down; III recasts without landing |
| Awareness | – | III | I exits; II also the ink well and shrine; III also the nearest key of each colour; senses longer each tier |
| Rift | – | III | I place a pair while grounded; II also midair; III the pair becomes the run's one cross-world link (its ends may be in different levels) |
| Vigor | – | III | +1 max health (and heals 1) |
| Speed | – | III | runs 15% faster per tier |
| Warp | – | III | I sends you to a random floor in the level (12 s to recharge); II to one you have not seen while there is one (9 s); III into a secret room not yet opened while there is one, opening it |

Spawn budgets follow level area: keys 2, corridor gates 3, extra lanterns 1.5, moons 3, and cracked walls 2.5 per 1000 cells, and from depth 1 hoppers 2 per 1000 cells (placed last, on floors, so the rest of a level is laid out as before). A hopper (`Hopper.gd`) squats until it sees the wizard within 700 × 400 px with a clear line, crouches for 0.45 s, then leaps (about two cells high) at where the wizard is, resting 1.1 s after each landing; the hex wounds and stuns it like the other nightmares, and the parry catches it. `tests/hazards_test.gd` covers hoppers and lasers. Keys include at least one of each colour; exits, their lanterns, the shrine and ink well are reserved first. Natural teleporters use 0.75 pairs per 1000 cells, rounded with a minimum of one pair and no fixed cap: one pair at depth 0, two at depth 5 and in the largest levels. Coins, platforms and enemies use a fraction of available space. Terrain and spacing constraints can leave budgets unfilled.

Watching eyes detect within 1400 pixels (previously 1150, and 520 before that); only rock and the wizard block their line of sight, not stars or other areas. `tests/spawn_balance_test.gd` checks 20 levels across five seeds and both terrain families, plus platform rejection and spike weighting. `tests/rift_test.gd` checks placed-pair lifecycle, spell tiers and actual watcher sight physics.

## 5. Economy

- Going deeper costs `P(d) = round(8 × 1.4^d)`: 8, 11, 16, 22, 43 at depth 5, 118 at depth 8.
- Stars per level grow at about 1.3^d.
- Shrines follow `S(d, tier)` above.
- The tension: diving makes stars and abilities cheaper to get, but each death deep down risks more.

## 6. Interface

- **Start menu:**
  - **Continue** appears when a run is saved and names where it will resume.
  - **Begin** starts at the world typed in; a blank field picks a random world.
  - **Random world** rolls a new world and starts it.
  - **Roll** puts a random number in the field, and **Paste** takes a bare number or a copied location.
- **Pause menu:** Resume, Copy location (`world 28 · depth 3`, for sharing), and Save and exit. Pausing also saves.
- **Printed HUD:**
  - stars, health, the carried key, and the level (`world · depth`)
  - the ghost label, while there is a ghost
  - a strip of the abilities you own, each drawn as its shrine mark with a pip per tier
- **Save** (`user://deeper_run.save`, versioned): the run seed, the deepest depth, level records, abilities and tiers, stars, health, the carried key, the respawn lantern, the ghost and the vulnerable state.
  - **Autosave:** on arriving in a level, lighting a lantern, dying, recovering the ghost, taking a key, using a shrine, pausing and quitting. Stars picked up since the last save can be lost.
  - **Continue** resumes at the last lit lantern. When a run ends, the new run overwrites the save.
  - Tests use their own save path.
- **Debug mode:** a toggle on the start menu.
  - Every exit (deeper, both sides, and the shrine near deeper) is generated on the floor spots nearest the spawn, in every level, along with a hyperspace door (so nearly every level four down is a landing level too).
  - The run starts with 9,999 stars, and again whenever the run restarts.
  - The flag goes into `NextWorldDef` (terrain is unchanged, only placement), is saved with the run, and shows as "· debug" in the HUD's world tag.
- **Pre-generation:** one worker thread runs the WFC, one level at a time.
  - The level being travelled to always goes first. Otherwise the worker generates the current level's neighbours (deeper, right, left, back) into a 12-level cache.
  - A transition into a cached level takes a frame. Cached terrain is identical to fresh terrain, and the test checks this.
- **Map screen:** see §7.

## What changes in the code

- **Remove:** world and map codes (`codes`, `all_map_codes`, `next_code`), the second map WFC per world, `goal.gd` code travel, `respawn.gd` backtracking, `world_scenes` packing, the code menu, and the upgrade menu with its start-of-game use.
- **Rework:**
  - `MapInfo` becomes a level loader keyed by `(seed, depth)`, with level records.
  - `WaveFunctionCollapse.gd` gets deterministic retries.
  - `corpse.gd` becomes the ghost: all stars, persistent, printed.
  - `key.gd` and `Unlock.gd` implement keys that aren't used up and are left where you grab the next one.
  - `checkpoint.gd` gets opt-in lighting and records the last lantern you lit.
  - `Upgrade` gets tiers.
- **New:** an exit prefab (deeper / back / lateral), a shrine prefab, a level record store, a save file, a start menu, the map screen, and riso art for the exits, shrine and ghost.

## 7. Map screen

`scripts/riso/RisoMap.gd` replaces MapInfo's pixel overlay. `ShowMap` (M, or the pad's Y) opens the map on the level page and closes it. A/D (or the arrow keys) turn between the level and worlds pages, shown as tabs. The map pauses the game while open, and Menu closes it. It is printed on the ink plates like the HUD, in the 320×180 UI space, so it needs the print on.

- **Level view:** the current level on paper, as far as it has been seen.
  - **Seen:** each level's record holds `seen`, a byte per cell (`MapInfo.reveal`, `is_seen`).
  - **Reveal:** cells within 5 of the wizard reveal as they move. Each level also has one ink well on a floor. Paying it `round(4 × 1.3^depth)` stars inks the whole level onto the map at once, and the well is then dry for good.
  - **Persistence:** seen cells are kept across revisits and in the save.
  - **Ink:** rock prints as solid blue ink and explored open ground as a light blue screen. They are two one-texel-per-cell textures, rebuilt only when something new is seen.
  - **Marks, where seen:**
    - exits: a chevron on a paper disc, plus a key-colour dot while locked or a star while unpaid
    - the shrine: an arch, dim once spent
    - lanterns: yellow dots, with a halo on your respawn
    - doors: key-colour bars
    - keys: key-colour dots
  - **Always marked:** the ghost, and the wizard (a pink hat).
- **World view:** each visited level is a tile labelled `world · depth` on the grid, centred on the current one, which is highlighted.
  - **Links:** opened side doors and paid deeper doors are drawn as bars between tiles.
  - **Marks:** the respawn lantern's level, spent shrines, and the ghost.
- **Legend:** each page has a legend down its right edge, drawn with the same mark functions as the map, so it always matches.
  - **Level page:** you, way out, deeper, locked, unpaid, shrine, lantern, respawn, door, key, ink well, ghost.
  - **Worlds page:** you are here, visited, way opened, respawn, shrine used, ghost.
- `tests/map_test.gd` covers the reveal radius, shard chunks, reveal persisting across a revisit, the open, cycle and close states with pausing, and the world tiles and links. `tests/capture_map.gd` takes stills of both views.

## 8. The hex bolt, enemy health and cracked walls

- **Hex** (`Hex.gd`, `HexBolt.gd`): `Cast` (F, or the pad's X; the action is added at runtime if the project doesn't define it).
  - It throws a comet of glow ink from the hat, aimed like the dash: the held direction, else facing.
  - It flies up to 8 cells. It passes through one-way ledges and moving platforms, and stops at rock and portcullises.
  - It wounds the first enemy near its path, or breaks a cracked wall.
  - Charges come back one per 1.5 s, and lighting a lantern refills them. They show as glow sparks after the HUD's health beads.
- **Tiers:** hex is learned at a shrine (not known at the start). II adds a charge, III adds damage, IV pierces its first enemy.
- **Enemies** get a `Wound`:
  - **Health:** 1 HP at depths 0–2, 2 at 3–5, 3 from 6. A stunned (parried) enemy takes double.
  - **Hits:** a hit bursts pink and knocks the enemy back.
  - **Death:** the enemy drops 1–2 stars. Stars buy upgrades and travel; lanterns restore death protection.
- **Slain until you die:** the level record keeps slain enemies. Dying clears them in every level and reloads the respawn level, so everything is back.
- **Cracked walls** (`CrackedWall.gd`): up to 10 per level, placed last, so they can block anything.
  - **Shape:** thin walls, one or two cells thick with open space on both sides. Half are picked within 3 cells of a key, lantern, exit, shrine or ink well.
  - **Solid:** a cracked cell is not a rock tile but a solid block on the same collision layer.
  - **Printing:** the terrain prints it as rock (body, shading, grass), and its prop adds a few fine night-ink cracks, quiet but visible up close.
  - **Breaking:** a bolt crumbles it in blue dust, and the rock reprints without it. The record keeps it broken, even across deaths.
- **Arming** (the ghost and dropped keys): they now arm once the wizard has been more than about a cell away. An overlap test armed them too early while a level reloaded, because the wizard's collision is off then.
- **Fixed:** `hit_box.gd`'s `stunned` setter never stored the value.
- `tests/hex_test.gd` covers the hex, charges and lantern refill, wounding, double damage when stunned, star drops, slain until death, rock stopping the bolt, cracked walls (deterministic, not tiles, broken for good) and tiers. `tests/capture_hex.gd` takes stills.

## Phases

Status: phases 1–7 are implemented (`tests/deeper_test.gd`, `tests/death_test.gd`, `tests/keys_test.gd`, `tests/shrine_test.gd`, `tests/interface_test.gd`, `tests/map_test.gd`, `tests/hex_test.gd`). The HUD already shows the current world and depth (`world 28 · depth 1`), and names the ghost's world when it is elsewhere.

1. **The grid:** `Level(seed, depth)`, deterministic generation, the four exits with transitions, arrival lanterns, and level records. Remove codes, goals, backtracking, the map WFC and packing.
   - Test: the same `(seed, depth)` always gives the same level fingerprint.
   - Test: revisits keep their record.
2. **Death and end state:** the persistent ghost with all stars, lanterns that each absorb one death, finding another lantern to restore protection, and an unprotected death ending the run.
3. **Keys:** not used up, left where you grab the next one, and working across levels.
4. **Shrines and tiers:** shrine placement, pay-to-learn, tiered abilities, and removing the upgrade menu.
5. **Interface:** start modes, HUD additions (owned tiers), save and load, and background pre-generation.
6. **Map screen:** see §7.
7. **Hex, enemy health and cracked walls:** see §8.
8. **Tuning:** the `P`, `S` and `D` curves, lantern and star density, depth bands for region and realm, and a playtest.

## Open for tuning

- Lantern density and distance between unspent lanterns.
- `D(d)` and level size growth with depth.
- Tier counts and the per-tier effect sizes.
- Whether lateral travel between seeds should ever cost anything at great depths.

## Tom's Thoughts:

### Hazards
- Crumbling ledges: shake for about 0.5 s once you stand on them, then fall and grow back later. They use the cracked-wall hairlines, so they'd read as "breakable". They'd punish standing still on bridged routes and reward the dash.
- Ink pools: dark puddles in pit floors that slow the wizard and stop the dash from coming back on landing. They'd make the moons more valuable, without being instant death like thorns.
- Sleep fog: a slowly drifting cloud that greys out the robe and turns off spells while you're inside it. It suits the dream setting and makes your spell timing matter.
- Thorn vines: thorns that grow out of the rock along a wall and pull back on a cadence, like the lasers but in close quarters. They'd turn wall climbs and vertical lift stacks into timing puzzles.
- Falling spikes

### Enemies:
- Moths: small swarms drawn to lit lanterns and the spell orb that drift toward your light. They'd make a lit lantern both protection and a danger, and you could scatter them with a hex.
- Shielded enemies
- enemies that shoot things that rebound (this was very cool in hollowknight)

### Ideas:
- There should be secrets, breakable walls/gates to get to areas that are hidden until opened
- significantly fewer lanterns
- larger star/cluster that gives like 10 stars or something
- key rarities
- a lateral door with an easily accessible key should be spawned close to initial spawn in depth 0 (found some spawns are impossible)
- an ability that makes key management easier
- an ability to heal
- an ability to teleport to a random place in the level
- balancing certain abilities/spells by giving them a cost
- the option to "kill yourself" if you're stuck in a pit and have a lantern lit
- astral should allow you to phase through walls
- certain abilities represent significant area unlocks (double jump, levitate, wall climb, blink) and should be gated, I think these should be rare, but potentially discoverable through things like the inkwell (this would mark a world that isn't your current one) 
- wisp needs to still have the animation improved (draws a circle by dipping underneath its normal path and creating an arc)
- Where hyperspace links to normal worlds in map view should be better (more seamless visually)
- clarifying world archetypes:
  1. initial world: garden (fences and mushrooms)
  2. cemetery
  3. hyperspace
  4. sky world
  5. ???
- Bosses/difficult platforming areas. Might need to be bespoke but I'd really like to keep everything procedural

### MORE IDEAS:
- the wizard looks generic, we should look into this
- the portal needs a visual overhaul
- fewer white specks

### Grouped for implementation
The thoughts above, grouped by the code they would share. Suggested order: 1, then 2, then 3 together with 4 to 6 as each archetype's content, then 7 and 8 as a tuning pass. 9 can slot in anywhere.

1. **Fix first, on its own: a way out at the start.** *Done (see "A way out of the first level" above).* At depth 0, put a side door near the spawn with a key that's easy to reach, since some spawns currently can't be escaped. This is a bug fix in the level generator's exit and key placement (`place_exits`, key placement).
2. **Exploration and gating** (the core of the genre, and the biggest gap). *Done (see "Secret rooms and relics" above, and astral projection and warp in the abilities table).*
   - Rare movement abilities that open up large areas: double jump, levitate, wall climb, blink.
   - An ink well can reveal where one of them is, even in another world.
   - Secret areas behind breakable walls or gates.
   - Astral projection passing through walls.
   - Teleporting to a random place in the level.

   These are one feature. Secret rooms need something that opens them, and rare abilities need places worth reaching; astral phasing and the random teleport are more ways in. Build the secret room first, then the gates, then the rewards.
3. **World archetypes, bosses and hard stretches.**
   - The archetypes: garden (fences and mushrooms), cemetery, hyperspace, sky world, and a fifth still open.
   - Bosses and hard platforming stretches, kept procedural.

   Both fit the world kinds (`scripts/worlds/`). A boss or a hard stretch can be a side world, as hyperspace is: a procedural strip with an arena at the end. Archetypes need the ordinary level definition (`NextWorldDef`) to vary its sample, its look, its realm and what it holds. Groups 4 to 6 supply each archetype's own hazards and enemies.
4. **Hazards that fall or move on a timer** (shared trigger, fall and regrow code).
   - Crumbling ledges and falling spikes both shake when you come near, then fall. The ledges also grow back later.
   - Thorn vines can reuse the lasers' timing (`Laser.gd`), at close range.
   - These fit the sky world and the cemetery.
5. **Zones that take something away** (a shared "standing in it" effect on the wizard).
   - Ink pools slow you and stop the dash coming back on landing.
   - Sleep fog turns your spells off.
   - Both need the same feedback on the robe and the spell orb.
   - These fit the cemetery and hyperspace.
6. **Enemies built around parry and hex.**
   - Shielded enemies, which hex can't get through head-on.
   - Enemies whose shots rebound, which works well with the parry now reflecting shots.
   - Do both together so each spell has a clear role.
7. **Light, lanterns and death** (one balance change).
   - Significantly fewer lanterns.
   - Moths drawn to lit lanterns and the orb, which make a lit lantern both protection and a danger (a hex scatters them).
   - A "give up" option when stuck in a pit with a lantern lit.
   - A healing ability, which matters more once lanterns are scarce.
8. **Economy pass** (best done last, once there's content to balance).
   - A large star cluster worth about 10.
   - Key rarities, and an ability that makes keys easier to manage.
   - Costs on certain abilities and spells. Per cast
9. **Small standalone polish.** *Done.*
   - The wisp's arc as it turns: it now turns round in one arc that dips under its path (forward, down, back under and up onto its line facing the other way), as deep as the room over the floor allows (`RisoProp._fit_loop`).
   - Where hyperspace meets the levels on the worlds map: it now pours out of one tile and into the other.

