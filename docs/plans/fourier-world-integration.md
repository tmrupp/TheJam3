# Fourier field integration plan

Status: implementation authorized by the user's follow-up. An opt-in playable slice is implemented; see `docs/FOURIER_INTEGRATION.md` for verified scope and remaining rollout gates.
Branch: `design/fourier-world-integration`, based on `main` at `9d08e5c`.
Date: 2026-09-08.

## Outcome and boundaries

Bring the prototype's four tight contour lines, color-blending unions, and speed-driven distortion into playable levels. Preserve movement, collisions, interaction ranges, world generation, progression, and saves. A visual merge never combines inventory, enemies, keys, or physical bodies.

Recommended first slice: the existing player plus two nearby portal/pickup visuals in a fixed test room. Retain original sprites and interaction markers during evaluation. Prove that the effect works at gameplay scale before replacing player art or decorating every generated object.

The earlier seed/depth, shared-knowledge, local-save design remains a separate gameplay project. This renderer must be compatible with it, not implement it implicitly. It must not consume the world's RNG, infer undiscovered gates, change seed routes, or serialize animation phase as progression.

## Starting evidence

- `project.godot`: Godot 4.2 Mobile, 320 x 180 viewport. Prototype checks used Godot 4.6.2, not the full native-extension gameplay project.
- `prefabs/scenes/main.tscn`: world camera zoom is 0.25; TileMap is scaled 4x. Player prefab is also scaled 4x. Preview pixel-speed and line-spacing values cannot be copied blindly.
- `scripts/Player.gd`: normal speed 300, dash speed 600, jumping/falling, knockback, respawn, and direct Sprite2D hurt/invulnerability modulation.
- `scripts/CameraControl.gd` and `prefabs/scenes/CameraEffects.gd`: camera follow and shake must not count as actor motion.
- `scripts/portal.gd`, `scripts/Upgrades/Blink.gd`, `scripts/AstralProjection.gd`, and `Player.reset_position()` relocate the player directly.
- `scripts/DashTrail.gd` and `scripts/AstralProjection.gd` duplicate `Player/Sprite2D`. Removing that node now would break existing visual behavior.
- `scripts/MapInfo.gd`: generated prefabs enter through `place_cell()`; world transitions pack, free, and reinstate `map_elements` in `clear_terrain()` / `load_world()`.
- Prototype `FourierField.gd` renders at most four direct contour children, hides extra ones, and measures field-local motion. It is a demo renderer, not yet a scalable world renderer.

## Proposed architecture

Keep gameplay nodes in their current hierarchy. Attach a small `FourierVisual` component to participating actors; register it with one presentation controller in Main. The controller owns render proxies, not actors or physics bodies.

`Gameplay actor -> FourierVisual -> visible-object registry -> shared contour renderer`

Each visual supplies:

- Stable runtime identity, shape/profile, local visual transform and bounds.
- Inner/outer palette, opacity, convergence, and distortion strength.
- Merge group and opt-in eligibility, independent of collision layers.
- World-space velocity or measured world displacement, plus an explicit motion-reset hook.
- Visibility/discovery state; the renderer must not expose hidden objects.

The renderer transforms local contour points through the actor's world transform and the camera canvas transform into viewport pixels. Line width and merge softness are viewport-pixel settings. Speed is measured in world units before that projection, so zoom, shake, and camera follow do not change distortion. Cache shape coefficients and reconstructed contours by profile/convergence; movement should transform cached points, not recompute Fourier coefficients.

Initial palettes: player orange/pink; friendly portal/pickup mint/blue. Smooth-union only eligible groups. Keep interaction icons and a small actor identity marker outside the union. Start with enemies, hazards, terrain, and bullets excluded so a merged glow cannot disguise a lethal boundary. Palette and shape remain independently configurable.

## Ordered implementation milestones

### 1. Preserve prototype and establish a runnable baseline

- Review and commit the existing untracked Fourier scripts, shaders, prefabs, and documentation as a separate implementation commit. They are preserved in the working tree but are not part of this plan-only commit.
- Move useful isolated checks from the local `shader-check` harness into a reproducible repo test setup.
- Run the original main scene with a compatible native WFC extension. Record exact Godot version, renderer, baseline gameplay behavior, and frame times; do not silently upgrade project format or native dependencies.
- Add a disabled-by-default visual feature switch and a fixed integration room retaining required Main/Player/TileMap paths.

Exit: baseline gameplay runs, standalone preview runs, and effect-off reproduces baseline. If the native extension blocks gameplay, report it separately; preview success is not full-project validation.

### 2. Integrate one moving player without visual merging

- Add `FourierVisual.gd`, a reusable shape/palette resource, and the presentation controller.
- Attach a contour overlay to `prefabs/player.tscn`; keep Sprite2D intact and independently togglable. Match silhouette scale to the actual actor and collider, not the large preview rectangle.
- Supply measured post-collision world motion (or verified real velocity) instead of requested velocity; pushing into a wall must not look like dashing.
- Start tuning around 300 world units/s for a moderate run distortion and 600 for stronger dash distortion. Cap deformation and smooth its decay. Test vertical velocity and knockback too.
- Mirror hurt, invulnerability opacity, and projection state through an explicit presentation API while retaining their current gameplay effects.
- Add a reduced-motion option that removes waves/stretch while retaining static contour colors.

Exit: idle, run, jump, fall, wall interaction, dash, damage, and pause are readable at 320 x 180; camera-only motion produces no added distortion.

### 3. Integrate the shared field in a playable room

- Add two opted-in portal/pickup visuals using different palettes and existing interactions.
- Project all participating contours into one shared coordinate system; apply smooth union before line extraction, with matching color weights.
- Keep four lines as the maximum default. Tune roughly 1-2 viewport pixels between lines at gameplay scale; allow fewer lines if tiny silhouettes become unreadable.
- Keep collider silhouettes/interaction markers legible when fills connect. Tune merge radius to a short visual proximity rather than an entire tile.
- Test merges with different shapes, scales, facing, and palettes, not only two identical humanoids.

Exit: approach joins contours, overlap removes internal outlines, retreat restores separate outlines, and collecting/using either object still invokes only its own existing gameplay action.

### 4. Handle object lifetime, teleports, and visual dependencies

- Register/unregister components on tree entry/exit so generated, collected, freed, packed, and reinstated objects cannot leave stale render entries. Runtime proxies must not be packed into saved world scenes.
- Reset velocity history after portal travel, Blink relocation, respawn, projection return, and world transitions. Blink may receive an explicit bounded pulse; never interpret its teleport distance as physical speed.
- Audit DashTrail and AstralProjection before hiding Sprite2D. Initially retain their sprite visuals; migrate to contour snapshots only in a separate, tested step.
- Ensure render updates respect pause, discovery, and actor visibility; clear retired world references before rendering a new world.

Exit: repeated death/backtrack/load/collect cycles leave no ghost outlines, stale colors, or velocity spikes. Sprite-dependent abilities still work with the feature toggled both ways.

### 5. Budget dense scenes before broader rollout

- Do not ship the current silent four-object cutoff. Reserve player visibility and keep unsupported/excess participants visible through an independent nonmerging fallback.
- For the first slice, keep at most four merge participants. For larger scenes, cull by expanded screen bounds, cluster by merge proximity and group, and use a deterministic selection policy with hysteresis.
- Never arbitrarily split a connected merge cluster across draw batches: independent unions cannot reproduce the shared boundary. An oversized cluster must visibly degrade to independent contours, or use a subsequently profiled texture-field implementation.
- Profile the current segment-distance shader before replacing it. Consider cached distance textures / field composition only if the measured budget requires it; keep the provider API renderer-independent.
- Record effect-off/on CPU and GPU timings at 0, 1, 4, 8, and 16 visible actors, including fully overlapping objects. Initial target: <=2 ms added GPU time at 320 x 180 on an agreed target device, and total frame time <=16.7 ms. These are acceptance targets, not current measurements; an RTX 4090 is not a minimum-spec benchmark.

Exit: no disappearance at capacity, no popping selection, and a documented performance/quality fallback. Broad prefab rollout waits for this gate.

## Validation checklist

- Unit/integration: registry removal, cached contour reuse, transform correctness, speed saturation/decay, reset hooks, group filtering, visibility, and capacity fallback.
- Visual: separate / touching / merged / separating; same/different palettes; camera pan/shake/zoom; player facing; very small silhouettes; behind/in front of terrain and HUD.
- Gameplay: run, wall push, dash, damage, pickup, portal, Blink, projection return, death, world change, backtrack, and pause/resume with effects on/off.
- Determinism: same seed and gameplay input produce the same generated objects, gate/key data, and gameplay results with rendering on/off. No frame-time-based visual randomness may enter game RNG.
- Compatibility: run the full project on its agreed Godot/native-extension version and target renderer; separately exercise Compatibility mode if it is a supported distribution target.
- Manual UX: can a player locate their body, distinguish threats, and identify the usable object during the strongest merge? If not, lower distortion/merge radius or retain the sprite core.

## Branch and rollout strategy

The branch began with the plan-only commit and now includes the prototype and playable integration. Continue in reviewable commits; do not mix the seeded-progression redesign or engine upgrades into them. The opt-in integration reaches the first playable checkpoint below with lifecycle hooks and a conservative capacity fallback; dense-scene/art rollout remains gated.

Keep the visual feature opt-in until the playable slice and performance gates pass. Turning it off restores original sprites and disables field processing; collisions, generation, and saves require no migration. No push or pull request is part of this planning task.

First approval/demo checkpoint: milestone 3, before converting enemy art or expanding beyond four simultaneous merge participants.
