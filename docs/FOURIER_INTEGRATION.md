# Playable Fourier integration

## Try it

Open `prefabs/scenes/fourier_room.tscn` and press F6. This fixed room uses the real Player and portal prefabs, normal collisions, and existing movement controls. E uses a nearby portal; F1 toggles contours, F2 toggles reduced motion, and R respawns. The original sprite cores remain visible intentionally: they preserve identity, hitbox readability, dash trails, and astral projection.

For generated gameplay, enable `Main/FourierWorld.enabled` in the Inspector or launch with `godot --path . -- --fourier`. It is off by default. The new components are on the player and portal prefabs only; enemies, terrain, bullets, and pickups retain their existing visuals. No seed/progression/save redesign is included.

## Components

- `FourierVisual.gd`: actor-local shape, size, palette, merge group, and visibility/tint source. Physics-tick displacement measures actual world movement, not camera motion. Call `reset_motion()` after a discontinuous relocation.
- `FourierWorld.gd`: shared screen-space rendering, cached reconstructed outlines, bounded cropped passes, color blending, world-speed distortion, and reduced motion. Camera transforms affect coordinates/direction but not speed magnitude.
- `FourierContours.gd` / `fourier_field.gdshader`: reused shape reconstruction and signed-distance union. Four lines with 1.25 viewport-pixel spacing are the integration defaults.

Add a FourierVisual child to another actor to opt it in. `source_visual` is relative to the provider and supplies visibility and sprite modulation; configure a distinct `merge_group` to prevent inappropriate merges (empty means independent). The component must not replace an actor's collision geometry or participate in world RNG. Runtime registry entries and render proxies are not packed into world scenes. The renderer does not retain actor references between frames.

Player respawn, portal travel, Blink relocation, and astral-projection return now reset motion history. The original Sprite2D remains available, and its hurt/invulnerability/projection modulation passes through to the contour palette. Fields stop advancing and are hidden while paused or while the main menus are visible.

## Capacity and remaining rollout gates

The current world adapter supports four merged objects per visible merge group. Groups larger than four fall back as a whole to independent contour passes, avoiding incorrectly split unions. At the default 16-pass budget, excess objects retain original sprites; `fallback_count` exposes that degradation. No physics objects or original sprites are hidden by the world adapter. The standalone preview also keeps fifth-and-later objects independently visible now.

This is a playable opt-in slice, not completion of the entire art rollout. Proximity clustering with hysteresis, texture-field rendering for large connected groups, authored shape/palette resources, migrated contour dash trails, and replacement of sprite cores remain follow-up work. Group membership changes can visibly switch between merging and independent rendering. All contours currently overlay world geometry; authored occlusion is also a rollout gate before decorating objects that must be hidden behind terrain. Hidden source visuals do suppress their contours.

The fixed room deliberately does not exercise WFC generation, upgrades, or the seed progression loop. Use the normal main scene for those. Blink's reset hook is implemented but its full upgrade/interactability flow still needs manual playtesting. Godot 4.2 itself and low-end/mobile hardware have not been verified.

## Verification

The Fourier tests (`fourier_world_test`, `fourier_generated_test`, `fourier_benchmark`) were removed; nothing in the regression suite covers this integration now.

## Results recorded 2026-09-08

Godot 4.6.2, Windows, NVIDIA RTX 4090, 320 x 180 viewport. The native extension loads; the original main scene and generated worlds run. The baseline main-scene shutdown reported an existing ObjectDB/resource leak; the generated test still reports an ObjectDB leak. That pre-existing cleanup issue was not changed as part of this visual integration.

Mobile-renderer benchmark: 30 warm-up frames followed by 60 measured frames per case. GPU numbers cover viewport rendering; CPU numbers time the adapter update directly, excluding physics and the rest of gameplay. They are not total game frame times or minimum-hardware guarantees.

| Visible objects | GPU off / on (ms) | Adapter CPU on (ms) | Rendering mode |
| --- | --- | --- | --- |
| 0 | 0.004 / 0.004 | 0.010 | No contours |
| 1 | 0.004 / 0.015 | 0.062 | Shared pass |
| 4 | 0.005 / 0.132 | 0.142 | Shared pass |
| 8 | 0.006 / 0.055 | 0.278 | Independent fallback |
| 16 | 0.008 / 0.075 | 0.526 | Independent fallback |

Higher counts use cropped independent passes, so their timings are not evidence that a larger merged field would be cheaper. Agree on target hardware and pass the readability/performance gates in `docs/plans/fourier-world-integration.md` before enabling this broadly.
