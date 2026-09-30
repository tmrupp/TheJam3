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
- Tiers live on the player (`Abilities.gd`) and reset when a run ends. The upgrade menu and the old `Upgrade`, `UpgradeManager`, double-jump and wall-climb nodes are gone.

| Ability | Start | Max | Each tier |
| --- | --- | --- | --- |
| Dash | I | IV | dashes 0.07 s longer |
| Double jump | – | III | one more air jump |
| Wall climb | – | III | I lets you climb (3 s); each further tier adds 1.5 s |
| Blink | – | III | replaces the dash; reach 300 px, +100 per tier |
| Parry | I | IV | window +0.1 s, cooldown −0.4 s |
| Astral projection | I | IV | lasts 2 s longer |
| Vigor | – | III | +1 max health (and heals 1) |

## 5. Economy

- Going deeper costs `P(d) = round(8 × 1.4^d)`: 8, 11, 16, 22, 43 at depth 5, 118 at depth 8.
- Stars per level grow at about 1.3^d.
- Shrines follow `S(d, tier)` above.
- The tension: diving makes stars and abilities cheaper to get, but each death deep down risks more.

## 6. Interface

- **Printed HUD:** coordinates (`seed · depth`, shareable), stars, the current deeper price, the carried key, a ghost hint and the vulnerable state.
- **Start menu:** a seed field, Random seed, and Continue.
- **Map screen:** replaces the pixel map overlay; see §7.
- **Save** (`user://`): seed, level records, abilities and tiers, stars, the ghost, the carried key and the last lantern.

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

## 7. Map screen (planned)

Today the map is MapInfo's pixel overlay: the current level's cells, revealed a chunk at a time by moon shards. It is replaced by a printed map with two views, toggled by `ShowMap` and switched with a second press or a shoulder button.

- **Level view:** the current level on paper, in the same inks as the world.
  - **Reveal:** cells within a few cells of the player reveal as you move, and a moon shard reveals a whole chunk.
  - **Persistence:** what's revealed is stored in the level record, so a revisit keeps its map.
  - **Marks:**
    - exits: their direction, and a price or lock colour until open
    - the shrine: offered or spent
    - lanterns: lit, and which one is your respawn
    - doors by colour, and dropped keys
    - the ghost, and the player
- **World view:** visited levels as tiles on the (world, depth) grid, with the current one highlighted.
  - **Links:** open side doors and paid deeper doors are drawn as links between tiles.
  - **Marks:** the respawn lantern's level, the ghost's level, and spent shrines.
  - **Shareable:** each tile is labelled `world · depth`, so coordinates can be shared.
- **Build:** a `RisoMap.gd` node printed like the HUD (UI space, on the plates), fed by the level records. The old `MapSprite` and `MapContents` nodes and the pixel `_draw` go.
- **Tests:**
  - reveal radius and shard chunks
  - reveal persists across a revisit
  - world-view tiles and links match the records
  - a still of each view
- **Pausing:** opening the map pauses the game, as the pause menu does.

## 8. A damaging spell (planned)

Enemies can only be stunned today (parry). A spell gives the wizard a way to destroy them.

- **Hex bolt:** a new `Cast` action that fires a comet of glow ink from the hat tip. It aims like the dash (input direction, or facing), flies about 8 cells, and stops at rock.
- **Enemies get health:** wisps and watchers get a small `Wound` component with 1–3 HP, rising with depth. A hit flashes them pink and knocks them back. At 0 HP they burst in a RisoFx splash and drop 1–2 stars, which count as fresh stars toward leaving the vulnerable state. A stunned (parried) enemy takes double damage, so parry and hex combine.
- **Cost:** a cooldown plus charges. It starts with one charge on a 1.5 s cooldown, and lighting a lantern refills the charges. It does not cost stars, which stay the currency for depth and shrines.
- **Tiers:** Hex becomes a shrine ability, in `Abilities`. Tier I is known from the start (it's the only way to kill).
  - II: +1 charge
  - III: +1 damage
  - IV: pierces through its first enemy
- **Death and records:** slain enemies stay slain in the level record until the player dies, then everything respawns. This is the soulslike reset, and it keeps levels dangerous without farming.
- **Cracked walls:** the bolt also breaks cracked rock, a metroidvania gate you come back to once you can cast far or often enough.
  - **Generation:** a few ground cells per level become cracked, chosen by the level seed. They are thin walls, one or two cells thick, with open space on both sides. Some of them seal off a pocket that holds something worth reaching (a key, a lantern, a cluster of stars). No path is guaranteed, as elsewhere.
  - **Breaking:** a cracked cell is solid until a bolt hits it. It then crumbles in a RisoFx burst of blue ink. The level record keeps it broken; it does not respawn on death, unlike enemies.
  - **Look:** rock like the rest, crossed by paper-white crack lines knocked out of the blue, so it reads as breakable up close.
  - **Tests:** cracked cells are deterministic per level; a bolt breaks one and stops there; broken cells stay broken on a revisit and after a death.
- **Look:**
  - The bolt is a glow-ink comet with a tapering smear, like the dash.
  - The hat bead dims while the bolt recharges.
  - Charges show as small glow pips in the HUD.
- **Tests:**
  - cast direction and range
  - stops at rock
  - damage, and double damage when stunned
  - death drops stars that count toward recovery
  - slain enemies stay slain on a revisit
  - everything respawns after a death
  - charges refill at lanterns
  - tiers apply
  - cracked walls (above)
- **Open:** should cracked walls gate the side and deeper exits too, or only pockets inside a level?

## Phases

Status: phases 1–4 are implemented (`tests/deeper_test.gd`, `tests/death_test.gd`, `tests/keys_test.gd`, `tests/shrine_test.gd`). The HUD already shows the current world and depth (`world 28 · depth 1`), and names the ghost's world when it is elsewhere.

1. **The grid:** `Level(seed, depth)`, deterministic generation, the four exits with transitions, arrival lanterns, and level records. Remove codes, goals, backtracking, the map WFC and packing.
   - Test: the same `(seed, depth)` always gives the same level fingerprint.
   - Test: revisits keep their record.
2. **Death and end state:** the persistent ghost with all stars, the vulnerable state, leaving it by the ghost or by fresh stars, and the run ending.
3. **Keys:** not used up, left where you grab the next one, and working across levels.
4. **Shrines and tiers:** shrine placement, pay-to-learn, tiered abilities, and removing the upgrade menu.
5. **Interface:** start modes, HUD additions (owned tiers), save and load, and background pre-generation.
6. **Map screen:** see §7.
7. **Hex and enemy health:** see §8.
8. **Tuning:** the `P`, `S`, `R` and `D` curves, star density, depth bands for region and realm, and a playtest.

## Open for tuning

- `R(d)`: how many fresh stars end the vulnerable state (start at half the deeper price).
- `D(d)` and level size growth with depth.
- Tier counts and the per-tier effect sizes.
- Whether lateral travel between seeds should ever cost anything at great depths.
