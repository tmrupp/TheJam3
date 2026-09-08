# Fourier contours

Open `prefabs/scenes/fourier_preview.tscn` in Godot 4.2+ and run the current scene (F6). The preview uses the game's 320 x 180 viewport and now shows two differently colored humanoids with four tightly spaced lines. Motion moves them together/apart automatically; drag either shape to turn automatic motion off and test speed distortion. Converge animates Fourier reconstruction; the slider controls it manually. The outline menu changes both shapes. Rendering has been checked with Godot 4.6.2.

## Merging objects

Instance `prefabs/fourier_field.tscn`, then add up to four `fourier_contours.tscn` instances as direct children. Resize the field to cover their entire travel area, including halos. The field hides the individual draws and combines signed distances before drawing lines: overlapping shapes form a single outline, blend their individual inner/outer colors at the join, and separate again as they move apart. This is visual only, not a collision or gameplay merge. Extra contour children beyond four remain independently rendered instead of disappearing.

Set each child's outline, convergence and colors independently. Set line count, spacing/width in viewport pixels, merge radius, maximum distortion, and speed threshold on the shared field. Child line/glow/spacing/turbulence settings apply only to standalone rendering. Field velocity is measured in field-local pixels per second and smoothed; greater speed increases directional stretch and ripples even at full convergence. Distortion settles after movement stops. Call `reset_motion()` after teleports or layout changes to avoid interpreting them as speed. Moving the entire field does not distort its children.

This prototype checks 128 contour segments per object per covered pixel (up to four objects), so keep the field's rendered area modest. Profile before using many fields or increasing resolution. It currently supports one closed contour per object; holes are not authored separately.

Instance `prefabs/fourier_contours.tscn` beneath a portal, pickup, or UI parent. Its transparent ColorRect is centered at the parent's origin by default. Resize/reposition the rectangle to fit; aspect correction keeps the contour undistorted. Each instance gets its own ShaderMaterial. This does not replace existing portal visuals or change the main scene.

Inspector controls: `inner_color` / `outer_color` (orange to pink), `line_count`, `spacing`, `line_width` (viewport pixels), `turbulence`, `glow`, `cycle_seconds`, and `convergence`. Disable `animate` to drive convergence from gameplay. At convergence 1, all residual distortion disappears; the nested outlines retain their spacing. Animation approaches the shape, holds briefly, then dissolves continuously. Its clock respects the node's processing/pause behavior.

The three geometric presets use twelve radial Fourier harmonics. The shader progressively includes those coefficients while unresolved harmonics wobble; outer contours lag behind inner ones. Customize `_target_radius(angle)` for another radial silhouette.

Humanoid instead samples a closed polygon by arc length and computes 32 vector Fourier harmonics, preserving neck and underarm indentations. During convergence the script reconstructs 128 contour points; the shader draws nested signed-distance lines around that contour. Outer lines have lagging residual wobble, but share the reconstructed base contour. Edit `HUMANOID_POINTS` to change the pose. This is more expensive than the radial presets: 128 segment-distance checks per covered pixel plus CPU reconstruction when convergence changes. It is a prototype effect, not automatic tracing of sprite alpha or an FFT of the screen.

Cost scales with covered pixels, line count, and harmonics. Standalone effects now default to four lines; keep effect rectangles tight. Very high line counts or turbulence/spacing can overlap or clip at the rectangle boundary. Glow is a local translucent halo and requires no post-processing.
