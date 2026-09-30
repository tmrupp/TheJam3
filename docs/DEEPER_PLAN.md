# Deeper: design and implementation plan

The goal of the game becomes getting deeper. The world is a grid of generated levels addressed by **(seed, depth)**. Every seed is a column you can dig down. Moving sideways steps to the neighbouring seed, as if you had started there. Because every level is a pure function of its address, players exploring the same seed see the same places, so sharing coordinates is how people explore together.

No level is guaranteed to be fully reachable. Places you can't reach yet are the point: you come back with new abilities.

## Decisions

| Topic | Decision |
| --- | --- |
| Lateral movement | Infinite. Left and right exits go to `seed − 1` / `seed + 1` at the same depth. |
| Exit distance | Grows with depth, physically. Deeper levels place their exits further from the arrival point (and may be larger). |
| Going back | Always free. |
| Deeper | Costs stars, paid once per deeper door; the door then stays open. |
| Reachability | Not guaranteed. Exploration of the generated space is the game. |
| Respawn | At the last lantern you lit. Every level spawns a lantern at its arrival point; lighting it is optional. The run's starting lantern is lit. |
| Death | You drop all your stars into a ghost and become **vulnerable**. |
| Leaving vulnerability | Recover the ghost, or collect enough fresh stars. |
| End of a run | Dying while vulnerable ends the run. |
| Keys | Not used up. You carry one; grabbing another leaves your current key where the new one was. Keys work in any level. |
| Abilities | Bought at shrines (no shop), and every ability has upgrade tiers. Cheaper deeper. |
| Ways to play | Enter a seed and dig its column, or start at a random seed. |

## 1. The world: a grid of (seed, depth)

- `level_seed = hash(seed, depth)` drives everything: WFC terrain, object placement, key and door colours, the shrine offer, and the depth band (WFC sample region and riso realm).
- Four exits per level:
  - **Deeper** leads to `(seed, depth + 1)`. It is placed low in the level, costs `P(d)` stars once, then stays open.
  - **Back** leads to `(seed, depth − 1)`. It is placed high in the level and is free.
  - **Left and right** lead to `(seed ± 1, depth)`. They are placed at the side edges and are free.
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

## 4. Shrines and tiered abilities

- One shrine per level, near the deeper exit. Its offer comes from `level_seed`: a new ability, or the next tier of one you own.
- Interact to buy. The printed prompt shows the ability, tier and price. No menu.
- Price: `S(d, tier) = max(floor, round(base × 1.6^tier × 0.8^d))`, which is cheaper deeper and dearer per tier.
- Built on `Upgrade.attach()`, extended with tiers.

| Ability | Tiers improve |
| --- | --- |
| Dash (base) | distance, cooldown |
| Double jump | extra jumps, height |
| Wall climb | climb time (3 s base) |
| Blink | distance (300 px base) |
| Parry (base) | window (0.3 s base), cooldown |
| Astral projection | duration (5 s base), range |

## 5. Economy

- Going deeper costs `P(d) = round(8 × 1.4^d)`: 8, 11, 16, 22, 43 at depth 5, 118 at depth 8.
- Stars per level grow at about 1.3^d.
- Shrines follow `S(d, tier)` above.
- The tension: diving makes stars and abilities cheaper to get, but each death deep down risks more.

## 6. Interface

- **Printed HUD:** coordinates (`seed · depth`, shareable), stars, the current deeper price, the carried key, a ghost hint and the vulnerable state.
- **Start menu:** a seed field, Random seed, and Continue.
- **Map screen:** replaces the pixel map overlay. It shows the grid of visited levels, with lanterns, paid deeper doors, your ghost and dropped keys.
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

## Phases

Status: phases 1 and 2 are implemented (`tests/deeper_test.gd`, `tests/death_test.gd`).

1. **The grid:** `Level(seed, depth)`, deterministic generation, the four exits with transitions, arrival lanterns, and level records. Remove codes, goals, backtracking, the map WFC and packing.
   - Test: the same `(seed, depth)` always gives the same level fingerprint.
   - Test: revisits keep their record.
2. **Death and end state:** the persistent ghost with all stars, the vulnerable state, leaving it by the ghost or by fresh stars, and the run ending.
3. **Keys:** not used up, left where you grab the next one, and working across levels.
4. **Shrines and tiers:** shrine placement, pay-to-learn, tiered abilities, and removing the upgrade menu.
5. **Interface:** start modes, HUD additions, the map screen, save and load, and background pre-generation.
6. **Tuning:** the `P`, `S`, `R` and `D` curves, star density, depth bands for region and realm, and a playtest.

## Open for tuning

- `R(d)`: how many fresh stars end the vulnerable state (start at half the deeper price).
- `D(d)` and level size growth with depth.
- Tier counts and the per-tier effect sizes.
- Whether lateral travel between seeds should ever cost anything at great depths.
