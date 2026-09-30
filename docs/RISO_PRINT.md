# Riso print presentation

The main game is presented as a risograph "tarot print": flat ink shapes drawn in code, printed by a shader with misregistration, wobbling edges, dot gain, a grainy halftone and uneven laydown. It is on by default and switches off live, so the original sprites come back untouched.

## Controls

| Key | Action |
| --- | --- |
| F6 | Print on/off (off restores the original sprites, stretch mode and cull mask) |
| F7 | Print controls: print detail, sheet rate, zoom, registration (new sheet / locked / drift), reprint on clock or motion, cut or blend between sheets, realm |
| F8 | Cycle realm (deep night, twilight, aurora) |

Launch with `godot --path . -- --no-riso` to start with the print off.

Defaults: twilight realm, fine detail, new sheet registration at 8 sheets/s, reprint on motion (landings, take-offs, dashes, hits and portals print a fresh sheet), blending between sheets, and the camera zoomed out to 0.72× of the scene zoom (restored when the print is off).

## How it works

- `scripts/riso/RisoPrint.gd` is added as the first child of `Main`. It creates six plate `SubViewport`s (night, blue, pink, accent, eye yellow, hat glow) plus an overlay viewport. All of them share the game `World2D`, and each one culls to its own canvas visibility layer (bits 12–17; 18 is the overlay). A full-screen `ColorRect` on canvas layer 1 runs `shaders/riso_print.gdshader` over the plates. The HUD and menus draw above it.
- Art nodes lay ink *coverage* on a plate: alpha is coverage, so a solid is 1 and a "25" tint is 0.25. By default each ink also lifts the same coverage off the night plate. `knock()` clears plates to bare paper (multiply blend), which is how the eyes, lantern and hat bead read as light. `InkCanvas` keeps these operations ordered; plate order across nodes comes from `z_index`.
- A viewport only renders an item whose ancestors all share its layer, so every `InkCanvas` ORs the ink bits into its ancestors (`RisoPrint.share_layers`). Ancestors draw nothing themselves, and legacy sprites keep only layer 1, so they never reach the plates. The main viewport's cull mask hides the ink bits, and the opaque print covers the legacy art.
- The print is pinned to the world. `RisoPrint` passes the camera's pixel offset (`pin`), and every imperfection is evaluated at screen pixel + `pin`. That covers the halftone screen, grain, edge wobble, laydown, specks and paper texture. So as the camera moves, they stay on the paper instead of sliding over it. Only a new sheet reprints them. The noise uses an exact integer hash (PCG) with its domains turned off the pixel axes. The earlier `fract()` hash lost float precision at screen-sized coordinates, which lined specks up in columns. `tests/riso_pin_test.gd` (windowed) checks that a camera move shifts the printed rock by exactly the camera's pixel shift.
- While printing, the window uses `canvas_items` stretch, so the world renders at full resolution while UI keeps its 320×180 layout. Plates are capped at 1080 lines; the shader samples them by UV.
- The night plate is registered to the blue plate (same offset, rotation and wobble), so rock and robe meet the night without paper rims that would read as outlines.

## Art

- **Wizard** (`RisoWizard.gd`, on the Player): drawn at 1.3x around the feet so the body is about a tile tall as in the prototype (level cells are 128 px, the collider ~62 px; collision is unchanged). It uses the spring rig from the HTML prototype, driven by the real velocity, floor, dash, climb and invulnerability state. It has planted feet in boots, a cloth hem with folds, a lagging head, a two-spring hat, eased turns, breathing and blinks. The face sits behind the brim and a raised collar, with yellow eyes that have paper-white centres.
- **Hat glow** follows the ability used last: dash (fluorescent pink), blink (violet), astral projection (aqua), parry (yellow), wall climb (green) and double jump (orange). It flares when the ability fires and dims while the dash is spent.
- **Dash** leaves a continuous smear that fades from the tail. **Hits** flash the whole figure pink. **Astral projection** holds a glowing silhouette at the return point.
- **Terrain** (`RisoTerrain.gd`) is rebuilt from the TileMap's ground layer when `MapInfo` finishes a world. It is one contiguous mass with rounded outer corners, concave fillets and a thin cap strip per walkable run. Shading is two screened night bands inset 22 px and 58 px from every exposed edge, cleared around inside corners, so it follows the outline rather than the cell grid. Floating platforms print with the terrain as bars that join neighbouring platforms and rock and share the cap strip. It knocks the sky out beneath itself.
- **Background** (`RisoBackground.gd`) follows the camera: a night flood, parallax stars and a few abstract shapes per realm.
- **Keys and doors**: each key and door is dealt one of four key colours, printed as ink overprints (sun, ember, moss, plum). The carried key trails the wizard and shows in the HUD, Doors are portcullises filling their corridor cell. Each has a header beam, four spiked iron bars, and one cross-rail carrying a paper lock plate in the key colour it needs. Unlocking plays a short printed opening (`RisoDoorOpen.gd`): the grate winches up into the header with a shudder and a puff of dust, then fades.
- **Prompts** (`RisoPrompt.gd`): a printed paper disc with the interact key pops up above anything in reach. On doors it shows the key colour needed instead.
- **Props** (`RisoProp.gd`) are attached by a dresser keyed on prefab path: star motes, moon shard, crescent key, portals, portcullis doors, lantern checkpoint (an ember when unclaimed, fully lit when it is your respawn), level exits (a lit doorway under a chevron pointing where it leads; an unpaid deeper exit has a pink frame, stays dark, and prints its price on a paper plaque), the shrine (a plinth across two cells: a niche where the offered ability's mark floats over its tier pips and a price tag, and a bowl holding an ember bead for mending, with name plaques in thickened night ink; it dims once spent), astral orb, floating ledge, straight thorns (rotated with the spikes), the death ghost (the wizard's astral silhouette in glow ink, with a dark hood and lit eyes, and the stars it holds circling it), Wisp nightmare (stunned eyes close), the watching eye shooter, and shard bullets. Interaction prompts and cooldown rings move to the overlay so they stay readable. Only on-screen props animate.

## Interface

- **Printed map** (`RisoMap.gd`): a paper sheet over the view, opened with M. The level view prints seen rock in blue ink and explored ground as a light blue screen, from one-texel-per-cell textures on the blue plate. It marks exits, the shrine, lanterns, doors, keys, the ghost and the wizard. The world view prints visited levels as labelled tiles joined by opened doors. See `docs/DEEPER_PLAN.md` §7.
- **Printed HUD** (`RisoHud.gd`): a bare-paper label in the top-left corner, printed with the art. It shows a coin mote and count in night-ink serif, health as ember beads (spent ones become a faint screen), and the carried key. A tag in the top-right corner names the level being played (`world 28 · depth 1`). Under it, a strip shows each ability you know as its shrine mark, with a pip per tier. While a ghost exists, a second label shows the ghost, its stars and an arrow toward it and, when it is in another level, that level's world and depth. While vulnerable, that label turns pink and adds a cracked star with the fresh stars still needed, and the hat bead splits into two pink halves. A run's end prints a card with the seed and the deepest depth reached. It lives on the ink plates and follows the camera, laid out in the 320×180 UI space. The pixel HUD hides while printing, but its data and scripts still run.
- **Menus** (`RisoTheme.gd`): the shared `main_menu_theme.tres` is restyled at runtime in the realm's inks: blue ink buttons that turn to the accent on hover and focus, paper input fields, night panels, a serif face and no borders. It is restored exactly when the print is off. The title image hides so the printed sky shows behind the main menu.

## Tests and captures

```
godot --headless --path . --script res://tests/riso_print_test.gd
godot --path . --script res://tests/capture_riso.gd
```

The headless test boots seed 28 and checks plates, stretch mode, cull mask, dressing of every spawned prefab, the dash smear, hat glow for dash and parry, the hurt state, the astral ghost, sheet advance, realm cycling and a clean off/on toggle. The capture script walks, jumps and dashes through the generated world in a 1280×720 window and writes frames to `../art-captures/riso-frames`.

## Limits

- Presentation only: no collision, physics or generation changes. The only gameplay-file edit is one notify call at the end of `MapInfo.next_world()`.
- Menus keep their Godot controls, restyled by `RisoTheme`.
- Prop art is sized to the current prefab scales (cells are 128 world px). Standing props measure their own ground each redraw, because checkpoints shift themselves after spawning; spikes stand on the surface they are rotated toward. A prefab added later needs an entry in `RisoPrint.DRESS` and a drawing in `RisoProp.gd`, or it stays invisible under the print.
