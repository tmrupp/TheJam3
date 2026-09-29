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
- While printing, the window uses `canvas_items` stretch, so the world renders at full resolution while UI keeps its 320×180 layout. Plates are capped at 1080 lines; the shader samples them by UV.
- The night plate is registered to the blue plate (same offset, rotation and wobble), so rock and robe meet the night without paper rims that would read as outlines.

## Art

- **Wizard** (`RisoWizard.gd`, on the Player): the spring rig from the HTML prototype, driven by the real velocity, floor, dash, climb and invulnerability state. It has planted feet in boots, a cloth hem with folds, a lagging head, a two-spring hat, eased turns, breathing and blinks. The face sits behind the brim and a raised collar, with yellow eyes that have paper-white centres.
- **Hat glow** follows the ability used last: dash (fluorescent pink), blink (violet), astral projection (aqua), parry (yellow), wall climb (green) and double jump (orange). It flares when the ability fires and dims while the dash is spent.
- **Dash** leaves a continuous smear that fades from the tail. **Hits** flash the whole figure pink. **Astral projection** holds a glowing silhouette at the return point.
- **Terrain** (`RisoTerrain.gd`) is rebuilt from the TileMap's ground layer when `MapInfo` finishes a world. It is one contiguous mass with rounded outer corners, concave fillets, a cap strip per walkable run, and a light band of night ink deeper in. It knocks the sky out beneath itself.
- **Background** (`RisoBackground.gd`) follows the camera: a night flood, parallax stars and a few abstract shapes per realm.
- **Props** (`RisoProp.gd`) are attached by a dresser keyed on prefab path: star motes, moon shard, crescent key, portals, door, lantern checkpoint (an ember when unclaimed, fully lit when it is your respawn), moon gate goal, altar, astral orb, floating ledge, straight thorns (rotated with the spikes), recovery relic, Wisp nightmare (stunned eyes close), the watching eye shooter, and shard bullets. Interaction prompts and cooldown rings move to the overlay so they stay readable. Only on-screen props animate.

## Tests and captures

```
godot --headless --path . --script res://tests/riso_print_test.gd
godot --path . --script res://tests/capture_riso.gd
```

The headless test boots seed 28 and checks plates, stretch mode, cull mask, dressing of every spawned prefab, the dash smear, hat glow for dash and parry, the hurt state, the astral ghost, sheet advance, realm cycling and a clean off/on toggle. The capture script walks, jumps and dashes through the generated world in a 1280×720 window and writes frames to `../art-captures/riso-frames`.

## Limits

- Presentation only: no collision, physics or generation changes. The only gameplay-file edit is one notify call at the end of `MapInfo.next_world()`.
- The HUD, menus and the map overlay keep their pixel art.
- Prop art is sized to the current prefab scales (cells are 128 world px). Standing props measure their own ground each redraw, because checkpoints shift themselves after spawning; spikes stand on the surface they are rotated toward. A prefab added later needs an entry in `RisoPrint.DRESS` and a drawing in `RisoProp.gd`, or it stays invisible under the print.
