# Character selection checkpoint

F7 → Look → Character offers the original Wizard, Arcane cosmonaut, Mask shaman and The Fool. The original wizard is the default; the choice lasts through travel and new runs in the current scene. These are playable procedural versions of the concept sheets, using the existing riso print and movement rig.

Implemented:

- Cosmonaut: simple suit, back cape, glass helmet, corked backpack flask containing the spell, pink dash antenna, chest health beads and a separate protection flame.
- Shaman: a different mask silhouette for every spell, floating gloves, crooked staff, a dangling chain of glowing health beads and a protection flame at the staff's crook.
- Fool: broad poncho, curved beret feather indicating dash readiness, floating gloves, a carried lantern and a knotted cloth bindle. Every spell changes the whole bag's shape, folds, color and arcane mark.
- All three: current/max health (including six hearts with vigor), independent dash and spawn protection cues, spell recharge and running time, Mend draughts, astral translucency and matching dash, ghost and portal silhouettes. Unlit lanterns leave a world-positioned pink smoke trail, fading over 1.4 seconds. Collision and level generation are unchanged.
- Fixed blue cloth uses an eighth ink plate, keeping the characters blue in the garden's green palette. The selected spell colors its accessory independently of F7's original-wizard Robe setting.

Visual tuning to review next:

- Readability at the default camera zoom: the health beads, flask glyph and tiny Mend draughts may need larger shapes or more spacing after playtesting. Close captures are much more legible than the actual gameplay view.
- The cape and ponchos currently use the wizard's existing cloth springs. Check their silhouette while running, climbing, dashing and turning; their back edges and glove positions may need character-specific adjustments.
- Pink smoke can overlap the cosmonaut's helmet/cape because it prints behind the body. Its sideways drift has been increased to let it escape; check moving footage before settling its width, opacity and direction.
- The masked face and spell bag use the game's existing ability marks. More character-specific spell art could bring them closer to the painted sheets, especially the astral and awareness designs.
- Character choice is a session preference. Saving it across app launches would need a separate persistent presentation setting; it is not part of the run save.

Validation: all 44 quick tests passed, including `tests/character_styles_test.gd`, and the rendered `tests/riso_pin_test.gd` passed. `tests/capture_characters.gd` renders the protected, unprotected, moving smoke, spent dash, astral and awareness comparisons, gameplay views and F7 selector into `game-captures/`. These were inspected close up and at gameplay scale. Concept sheets and their prompts are retained here; `.gdignore` excludes these review images from Godot imports.

An intermittent Godot shutdown warning (two ObjectDB objects and one resource still in use) appeared during a character-test run; the subsequent verbose run exited cleanly. If it recurs, inspect test teardown and the background level loader before treating it as a costume leak.
