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
| Respawn | At the last lantern you lit. Every level spawns a lantern at its arrival point; lighting it is optional. The run's starting lantern is lit. |
| Death | You drop all your stars into a ghost and become **vulnerable**. |
| Leaving vulnerability | Recover the ghost, or collect enough fresh stars. |
| End of a run | Dying while vulnerable ends the run. |
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
- You arrive at the matching exit of the next level: going deeper puts you at its Back exit, and so on.
- Exits sit at least `D(d)` cells from the arrival point, with `D` growing with depth. Deeper levels can also grow beyond 64×64.
- Every level spawns an unlit lantern at its arrival point.
- **Level record:** each visited level stores only what changed. That is stars taken, doors opened, keys dropped or taken, the deeper door paid, lanterns lit, and the ghost. On a revisit the level regenerates identically and the record is applied on top.
- **Determinism:** a failed WFC collapse currently retries with `randi()`. It must retry with `hash(level_seed, attempt)` instead. Neighbouring levels pre-generate on the background thread so transitions are instant.

## 2. Death, the ghost and the end of a run

- **Die (not vulnerable):** all carried stars go into a ghost at the death spot, recorded in that level. Any previous ghost and its stars are lost. You respawn at your last lit lantern and become vulnerable.
- **While vulnerable:** you can leave the state in two ways. Recover the ghost to get all its stars back, or collect `R(d)` fresh stars, which is suggested as half the current deeper price. The second way leaves the ghost waiting where it is.
- **Die while vulnerable:** the run ends. The seed's levels are unchanged, since they are generated. Your character and level records reset.
- **Arming:** a ghost can only be recovered once the player has stepped off it, so dying on the respawn lantern doesn't hand the stars straight back.
- **Presentation:** the vulnerable state shows on the wizard (for example a dimmed or cracked hat glow) and in the HUD. The ghost uses the printed astral-silhouette style, and the HUD points toward it when it is in another level.

## 3. Keys

- A held key opens every door of its colour in any level. Opened doors stay open.
- You carry one key at a time. Grabbing a new one leaves your current key where the new one was, and the level record keeps it there.
- Door colours are dealt per level. A matching key may be far away, or in another column.
- A dropped key arms only once the player has stepped off it, so the swap does not immediately grab it back.

## 4. Shrines and tiered abilities

- One shrine per level, standing on two floor cells 3–14 cells from the deeper exit.
- It offers two things. Taking either one spends the shrine, and the level record keeps it spent:
  - **The boon:** the next tier of an ability. The ability is picked by `level_seed`, or is the next one along that still has a tier to learn.
  - **Mending:** healing to full. It is the alternative to the boon and does nothing at full health.
- **Pay to learn.** There is no menu: interact with the side you want. The plinth prints the ability's name and tier, and the price sits on a tag in the niche. Mending shows its price on its own plaque.
- **Prices:**
  - Learning costs `S(d, tier) = max(3, round(10 × 1.6^(tier−1) × 0.8^d))`: cheaper deeper, dearer per tier.
  - Mending works the other way: `H(d) = round(3 × 1.35^d)`, which is 3 at depth 0 and 13 at depth 5.
- **Only the dash is known at the start.** Everything else is found at shrines. A shrine offers an ability not yet known before any upgrade: it starts from the seed's pick and goes round. Until learned, parry and astral projection do nothing, and there is no hex, so no killing enemies or breaking cracked walls.
- **One spell slot.** Hex, astral projection, parry, levitate and awareness are spells, and all use the Spell button (Q, or the pad's X; the old Parry binding renamed). You carry one at a time: learning a different spell at a shrine replaces it, and the shrine's plaque says "· swap". Perks (dash, double jump, wall climb, blink, vigor) stack.
- **Levitate:** press Spell in the air to stop falling and float. You drift slowly up and down with the stick and sideways at walking pace, until it runs out or you press Spell again. You get one float per landing, and a moon brings it back.
- **Awareness:** press Spell to sense the level. While it lasts, pointers at the edge of the view show where things are, like the ghost's arrow. A short cooldown follows.
- **Astral projection** uses the Spell button. Tap it to leave your body and go out as an untouchable projection. Tap again, or get hurt, to snap back to the body. Let it run out and you stay where the projection is. There are no astral orbs any more.
- **Moons** are dash resets, about 12 per level, placed only in open air: clear on every side and below, and at least 6 cells apart. Touching one gives your dash back if you have used it. It then wanes for 2.5 s and returns. Moons are never used up.
- Tiers live on the player (`Abilities.gd`) and reset when a run ends. The upgrade menu and the old `Upgrade`, `UpgradeManager`, double-jump and wall-climb nodes are gone.

| Ability | Start | Max | Each tier |
| --- | --- | --- | --- |
| Dash | I | IV | dashes 0.07 s longer |
| Double jump | – | III | one more air jump |
| Wall climb | – | III | I lets you climb (1 s); each further tier adds 0.5 s |
| Blink | – | III | replaces the dash; reach 300 px, +100 per tier |
| Parry | – | IV | window +0.1 s, cooldown −0.4 s |
| Astral projection | – | IV | lasts 2 s longer |
| Hex | – | IV | II +1 charge, III +1 damage, IV pierces |
| Levitate | – | III | float 1.5 s, +0.75 s per tier |
| Awareness | – | III | I exits; II also the ink well and shrine; III also the nearest key of each colour; senses longer each tier |
| Vigor | – | III | +1 max health (and heals 1) |

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
  - Every exit (deeper, both sides, and the shrine near deeper) is generated on the floor spots nearest the spawn, in every level.
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
  - **Death:** the enemy drops 1–2 stars, which count as fresh stars.
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
2. **Death and end state:** the persistent ghost with all stars, the vulnerable state, leaving it by the ghost or by fresh stars, and the run ending.
3. **Keys:** not used up, left where you grab the next one, and working across levels.
4. **Shrines and tiers:** shrine placement, pay-to-learn, tiered abilities, and removing the upgrade menu.
5. **Interface:** start modes, HUD additions (owned tiers), save and load, and background pre-generation.
6. **Map screen:** see §7.
7. **Hex, enemy health and cracked walls:** see §8.
8. **Tuning:** the `P`, `S`, `R` and `D` curves, star density, depth bands for region and realm, and a playtest.

## Open for tuning

- `R(d)`: how many fresh stars end the vulnerable state (start at half the deeper price).
- `D(d)` and level size growth with depth.
- Tier counts and the per-tier effect sizes.
- Whether lateral travel between seeds should ever cost anything at great depths.
