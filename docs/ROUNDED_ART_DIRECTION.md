# Rounded forms / motion signals

The new direction is intentionally quieter: solid rounded shapes carry identity; Fourier contours communicate speed and transient events rather than permanently decorating everything. Player: peach lozenge with two dot eyes. Portals: mint/violet circles with a simple ring. Adjacent forms retain the shared color-blending union.

Run `prefabs/scenes/rounded_art_room.tscn` with F6. This uses the actual player and portals from the integration room, at 960 x 540 without transform/vertex pixel snapping. Existing movement controls and E interactions still work. F1/F2 toggle reduced motion; R resets. Jump, damage, and teleport reset now emit a short presentation pulse. No physics or seed logic changes.

The art room masks the old player/portal sprites, pixel particles, parry sprite, interaction prompt, and pixel HUD instead of deleting their source assets or changing their gameplay visibility. Crisp eyes and rings are drawn separately from the deforming body. Shape shaders produce the base fill and motion-triggered contours. The old main game and earlier previews remain available for comparison; this is not yet a full terrain/menu/enemy art replacement.

## Rounded gameplay feedback

`RoundedFeedback.gd` listens to actual Player presentation events. Dash leaves brief cached-outline echoes. Projection uses a cyan palette and a persistent outline at the return location; returning restores the original palette. Hurt produces a short contour flash. Death disperses the silhouette into three fading harmonic traces and replaces the old corpse icon with a small amber recovery marker; the original collectible, coin value, and collision remain intact. The feedback snapshots never enter the merging field or world RNG. They respect pause, and reduced motion suppresses dash echoes and expanding/distorting traces while retaining static state information.

In the art room, P projects/returns, H applies a test hit, K triggers death, and R resets. These shortcuts are local to the study scene. Repeated projection activation is guarded against orphaning return origins. Masked legacy sprite trails no longer spawn invisible copies. Parry and jump-particle redesigns, terrain, menus, and enemy conversion remain follow-ups.

`tests/rounded_feedback_test.gd` verifies dash/projection/impact/death events, repeated projection, coin recovery, and reduced motion. `tests/capture_rounded_feedback.gd` records an eight-second scripted-motion reel using real ability methods; it holds the recovery marker in place for the shot (collection is tested separately). Encode it with:

```
godot --path . --rendering-method mobile --fixed-fps 30 --script res://tests/capture_rounded_feedback.gd
python tests/encode_art_gif.py ../art-captures/feedback-frames ../art-captures/rounded-feedback.gif
```

## Animated review

`tests/capture_rounded_art.gd` renders a deterministic eight-second reel: rest, acceleration through a portal, separation, a jump-like return, a stationary effect pulse, then rest. The motion is scripted for art review, not a claim of recorded player input. It produces 240 PNG frames at 30 fps in the workspace's `art-captures/rounded-frames` directory.

```
godot --path . --rendering-method mobile --fixed-fps 30 --script res://tests/capture_rounded_art.gd
python tests/encode_art_gif.py ../art-captures/rounded-frames ../art-captures/rounded-motion.gif
godot --headless --path . --script res://tests/rounded_art_test.gd
```

Encoding requires Pillow. The GIF uses a shared palette, loops forever, and preserves eight seconds even when duplicate still frames are coalesced. Review motion using the GIF, not a still frame. Generated captures stay outside the repository.
