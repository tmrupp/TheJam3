# Rounded forms / motion signals

The new direction is intentionally quieter: a peach capsule with short procedural legs and two dot eyes; mint/violet hollow portals. Velocity is communicated by a tapered stack of rings aligned behind the current motion vector, not random undulation or stored silhouette echoes. Adjacent forms retain the shared color-blending union.

## Locomotion pass

`RoundedLocomotion.gd` advances its gait from actual horizontal distance/speed. Feet alternate a planted stance and a raised return swing, blend to rest when stopped, reverse with travel, and tuck while airborne. A small optional body bob follows the gait. These are visual limbs: player collision geometry is unchanged and foot placement is tuned to the test room's flat floor, not slope-aware IK.

Four instantaneous rings use the moving body's actual current contour, translated opposite the full world velocity projected through the camera. They shrink, thin, and fade into a comet-like tail; speed increases their spacing and visibility. The body occludes the front of the tail. They are not elliptical cross-sections, recorded afterimages, or random undulations. Reduced motion removes them. The solid body shader no longer distorts with velocity; separate event pulses remain.

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
