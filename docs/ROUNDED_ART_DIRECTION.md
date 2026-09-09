# Rounded forms / motion signals

The new direction is intentionally quieter: a peach capsule with short procedural legs and two dot eyes; mint/violet hollow portals. Velocity is communicated by a tapered stack of rings aligned behind the current motion vector, not random undulation or stored silhouette echoes. Adjacent forms retain the shared color-blending union.

## Locomotion pass

`RoundedLocomotion.gd` advances its gait from actual horizontal distance/speed. Feet alternate a planted stance and a raised return swing, blend to rest when stopped, reverse with travel, and tuck while airborne. A small optional body bob follows the gait. These are visual limbs: player collision geometry is unchanged and foot placement is tuned to the test room's flat floor, not slope-aware IK.

Three concentric contours surround the body's current deformed silhouette. They share one radial center/profile with constant radial gaps; a narrow rear lobe forms a comet taper, rather than independently translating each ring. Leading edges stay close-fitting, and the far tip fades. Direction changes are smoothed; reversals shorten the envelope before redirecting it rather than sweeping a long tail through the body. This stores a filtered direction/strength, not a history of silhouette echoes. Reduced motion removes the envelope.

The legs now use curved, tapered shapes extending beneath the capsule, with rounded soles and palette-matched roots hidden behind the body. Hip attachments follow body deformation while stance feet remain independent. The study enables 4x 2D MSAA and restores the previous setting on exit.

Squash/stretch is continuously procedural: filtered acceleration, motion-aligned load, stance support, vertical speed, and landing impulse feed the area-preserving spring. There are no authored scale clips. Limits keep the silhouette readable, and reduced motion bypasses the deformation.

The capsule now has a bounded damped spring for acceleration lean and area-preserving stretch, anchored near the hips. Horizontal motion stretches it slightly along travel; airborne vertical speed elongates it vertically, relaxing near the apex. Landing adds a short squash impulse. Braking/reversing lets the body settle naturally into the new target. Body and eye positions use the same deformation transform as the envelope. Teleports clear spring and indicator state. Reduced motion disables deformation/bob as well as the indicator, while preserving the procedural walk. These are art-directed affine deformations, not a soft-body physics simulation; collisions remain unchanged.

`tests/rounded_dynamics_test.gd` checks 30/120 fps spring agreement, area preservation, the hip anchor, contour closure/count, reversal compression, teleport reset, landing squash, idle settling, and reduced motion. The latest GIF is `art-captures/rounded-soft-envelope.gif` in the workspace; the older comet-tail study is retained for comparison.

Portals use a real signed-distance subtraction for transparent centers (`opening_ratio`), so moving shapes can be seen through them. The current opening assumes circular, uniformly scaled portals as authored in this room.

Review the eight-second scripted walk/run/reverse/air reel:

```
godot --path . --rendering-method mobile --fixed-fps 30 --script res://tests/capture_rounded_walk.gd
python tests/encode_art_gif.py ../art-captures/walk-frames ../art-captures/rounded-walk.gif
godot --headless --path . --script res://tests/rounded_walk_test.gd
```

This supersedes the earlier dash-echo study. Legacy radial previews remain available, but the rounded art room uses directional rings only.

Run `prefabs/scenes/rounded_art_room.tscn` with F6. This uses the actual player and portals from the integration room, at 960 x 540 without transform/vertex pixel snapping. Existing movement controls and E interactions still work. F1/F2 toggle reduced motion; R resets. Jump, damage, and teleport reset now emit a short presentation pulse. No physics or seed logic changes.

The art room masks the old player/portal sprites, pixel particles, parry sprite, interaction prompt, and pixel HUD instead of deleting their source assets or changing their gameplay visibility. Crisp eyes and rings are drawn separately from the deforming body. Shape shaders produce the base fill and motion-triggered contours. The old main game and earlier previews remain available for comparison; this is not yet a full terrain/menu/enemy art replacement.

## Rounded gameplay feedback

`RoundedFeedback.gd` listens to actual Player presentation events. Dash now uses the locomotion velocity rings instead of echoes. Projection uses a cyan palette and a persistent outline at the return location; returning restores the original palette. Hurt produces a short contour flash. Death disperses the silhouette into three fading harmonic traces and replaces the old corpse icon with a small amber recovery marker; the original collectible, coin value, and collision remain intact. The feedback snapshots never enter the merging field or world RNG. They respect pause, and reduced motion suppresses expanding/distorting traces while retaining static state information.

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
