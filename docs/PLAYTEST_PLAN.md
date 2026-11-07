# Playtest fixes: the tutorial, the guard, the print

A plan for the owner's playtest notes of November 2026, on the garden demo and its tutorial. Each
item says what was seen, what the code does now (where it was found), what to do, and what is still
open. The order of work is at the end. Steps 1 to 4 of it are built (marked *Done*), and 2c and 3d were judged good in play (owner, November 2026).

## 1. The tutorial

### 1a. A shoulder card after the first thorns

*Seen:* the card after the first bed of thorns shows a shoulder button.

*Now:* that card is the dash's (`Tutorial.MAP`, digit `3` before the bed only a jump and a dash
clear). The dash is bound to the right trigger (`Dash` in `project.godot`: pad axis 5), so the pad
card lights the right trigger (`RisoPad.part_of`), drawn small over the bumper (`RisoPad.TRIGGER`
over `BUMPER`). It reads as "a shoulder", and which one is not clear at a glance.

*Decided:* the dash stays on the right trigger (owner, November 2026).

*To do:* make the trigger and the bumper unmistakable from each other on the pad drawing
(`RisoPad`): the trigger taller, thicker and standing clear of the bumper, the bumper flat against
the body, so a lit trigger cannot be read as a bumper. A lit trigger's side arrow (`RisoPad.POINT`)
thicker too, so it reads at the prompt's size. Capture the dash card on a pad and look at it zoomed in.

*Done:* a trigger is a round-topped tab (`RisoShapes.arch`, `RisoPad.TRIGGER`) standing clear of
its bumper (`TRIGGER_GAP`), the bumper a thin strip along the body's top with a hairline of paper
between (`BUMPER_GAP`, so it does not melt into the body), all in the same room over the body as
before, so the pad keeps its size on a card; the side arrow is broader (`POINT`). Checked on the
dash card in `capture_tutorial`, zoomed in. Then, at the owner's word: the trigger as wide as the
bumper (`RisoPad.TRIGGER` 30 by 14, a tab rounded at its top corners, `RisoPad.tab`) and the bumper
a little thicker (6), in the same room over the body.

### 1b. A shooter only a parry beats

*Seen:* the tutorial wants an unreachable shooter, killable only by turning its shots back. The
card after the first spell card makes no sense where it stands.

*Now:* a watcher (`s`) stands on a three-cell slab (`###`, row 6) over the hall, and the parry card
(`8`, `ControlHint.PARRY`) stands at the end of the stretch after the wisp's spell card (`4`). The
watcher may be reachable (a jump and a dash to its slab, or a slash's reach), and the parry card
rises before the watcher is in view, so it reads as a second "attack" card.

*To do:*
- Raise the watcher out of all reach: a niche high in the hall's wall, or a slab with no floor
  within a jump, dash and air jump (check with the tutorial test's own controls, `_leap`).
- Make sure nothing but its own shot turned back can kill it there: no spell reaches it (slash,
  hex, nova), and contact never happens.
- Move the parry card to where the watcher's first shot reaches the wizard, so the card rises
  with the shot coming.
- `tutorial_test`: the watcher cannot be reached on foot, a spell cast at it from below does not
  wound it, and a reflected shot does.

*Found:* a watcher standing on a ledge cannot see down past the ledge's edge (its eye is low), so
the old one on its slab hardly ever saw the wizard on the floor; and the view shows only about
three cells over the floor, while a jump, a dash up and a slash reach about four, so a watcher
cannot be both in view and out of reach.

*Done:* the watcher hovers over the hall, in view near the top of it (the `hovers` mod, `Shooter`;
its shots fly straight, unlike a sky watcher's), and is warded so that only a parried shot wounds
it (the `parried_only` mod, `Wound.parried_only`): a slash, a bolt or a touch glances off it, so
turning its shots back is the one way to beat it, though it can be touched. A parried shot now
steers home to its shooter however far (`HexBolt.home`, everywhere, not only here), so it lands
on a watcher that drifts. Its card stands where its first shot comes at the wizard. `tutorial_test`:
it hovers, a slash and a hex bolt glance off, the card rises where it sees the wizard, a press
alone leaves the card, and a real shot met with the guard flies home, wounds it and puts the card
away.

### 1c. No title cards

*Seen:* title cards are not wanted.

*Now:* coming into a region shows its emblem on a banner (`RisoTransition.title`, called from
`MapInfo._title_region`).

*Done:* the title card is gone (`_title_region`, `RisoTransition.title`, `_draw_title` and their
constants), with `region_title_test` and the captures' waits for it.

## 2. The guard (parry) and the pogo

### 2a. Parry shares the spell's cooldown

*Seen:* the parry should be used at the same time as the ability, with its cooldown.

*Now:* every damage spell raises the guard as it is cast, but the guard has a cooldown of its own
(`Parry.COOLDOWN`, 1.2 s on a miss) and goes up "whether or not the spell itself is ready"
(`Parry.execute`, `Player` on the Spell press).

*To do:* one cooldown: the guard goes up only when the spell is cast, and is ready when the spell
is. A catch gives the spell back at once (as it gives the guard back now). Remove `Parry.COOLDOWN`
and its timer; the spell orb's readiness is the spell's alone. Rework `parry_landing_test`,
`switches_test` (its guard checks) and `docs/DEEPER_PLAN.md`'s Parry row.

*Decided:* a catch gives the spell straight back, whatever its cooldown (owner, November 2026), so
a slow spell (hex, nova) still parries again after a catch.

*Done:* the guard goes up with the cast, only when the spell is ready (`Parry.execute`,
`Abilities.readiness`); `Parry.COOLDOWN` is gone; a catch refills the spell (`Abilities.refill`,
each damage spell's `refill`, checked by `unit_test`); `switches_test`, `damage_spells_test`,
`parry_landing_test` and `ward_test` reworked.

### 2b. Parry and bounce while untouchable

*Seen:* while untouchable (after a hit, or arriving somewhere), the wizard can neither parry nor
bounce off thorns.

*Now:* no guard goes up while untouchable from a hit taken (`Parry.hurt_guarded`; the spell orb
reads not ready). A guard that is up catches every hit handed to the wizard, untouchable or not
(`Player.hurt` passes it to `hurt_ability`, the guard's `parry` while it is up), so the block is
`hurt_guarded` alone. Whether the grace on arriving (`Player.grace`) also gets in the way is to be
checked in play.

*Done:* `hurt_guarded` is gone; the guard rises whenever the spell is ready, untouchable or not,
and thorns still reach a guard while the wizard is untouchable (`switches_test`: after a hit, a
guard raised over thorns bounces).

### 2c. Bouncing off thorns feels off; no attack right after

*Seen:* spike jumping is weird and seems to have a cooldown; an attack right after a bounce does
nothing.

*Now:* the guard is raised by the Spell press, which casts the slash too, so the slash is on its
own cooldown (`Slash.COOLDOWN`) just as the wizard bounces; the catch also starts a hit-stop
(`Parry.HIT_STOP`) and 0.8 s untouchable (`SAFE`).

*Done:* with 2a and 2b a catch gives the spell back, so the next press after a bounce casts (and
guards) again. Played and judged good as it is (owner, November 2026): the bounce (`Parry.POGO`),
the hit-stop and `SAFE` stay.

### 2d. The dash comes back faster

*Seen:* the dash should reset much faster.

*Now:* on the ground the dash comes back `Player.DASH_GROUND_COOLDOWN` (1.0 s) after the last one
began.

*Done:* 0.35 s (`DASH_GROUND_COOLDOWN`); `dash_strike_test` and the tutorial's beds still hold.

## 3. The print

### 3a. The worm's mark off the edge

*Seen:* the worm's maw should run off its disc, as the worm comes partly out of the ground.

*Now:* every boss mark sits inside its disc (`RisoMarks.boss_mark`, `BOSS_MARK` 0.62 of the
radius).

*To do:* draw the worm's maw bigger, from off one side of the disc, cut to the disc's outline
(`Geometry2D.intersect_polygons` with the disc), so only its front and open jaws show. The same on
the map, the stands and the won card. Capture and look at it zoomed in.

*Done:* the maw is bigger and comes up off the disc's lower left (`RisoMarks.WORM_HEAD`, `WORM_R`),
each piece cut to the disc (`Geometry2D.intersect_polygons`), so only its front and open jaws show,
on the seal, the trophy and the won card; on the map it is cut to where its disc would be.
`tests/capture_boss_marks.gd` prints every boss's seal, trophy and bare mark side by side.
Then, at the owner's word: the other marks drawn bigger on their discs (`RisoMarks.MARK_GROW`, 1.3)
but for the worm's; the bramble's vine running its disc from end to end, cut to it, with three big
hooked rose thorns that read at the seal's size, its leaf gone.

### 3b. No A / D on the map

*Now:* the map prints "A / D" by its page tabs (`RisoMap._tabs`).

*Done:* removed; the tabs stay (icons).

### 3c. A simpler pad outside the tutorial

*Seen:* the pad drawing may be too busy; outside the tutorial a simpler one is wanted.

*Now:* the interact prompt over everything draws the whole pad (`RisoPrompt._interact`,
`RisoPad.draw`), the same as the tutorial's cards.

*To do:* a small form of the pad for the prompt (and anything outside the tutorial): only the part
the control is on, as the player sees it on the pad. The face buttons as a diamond with the one
asked for solid, a shoulder as the two shoulders of one side, the stick alone. The tutorial cards
keep the whole pad, so it is learned there. `RisoPad.draw_small(ink, at, s, action)`, captured in
`capture_prompt_control.gd`.

*Done:* `RisoPad.draw_small` and `small_size`, as above (back and start side by side too); the
interact prompt uses it (`RisoPrompt.PAD_SCALE` 0.65, about a key cap's size), on a card fitted to
it. Captured in `capture_prompt_control.gd`.

### 3d. The light: soft, not sharp

*Seen:* the light is still too sharp; line of sight should not light anything, and where it cuts
it should fade.

*Now:* the shade over what the wizard cannot see is cut exactly to the sight polygon
(`RisoLight._darkness`, `RisoSight.polygon`, `RisoSight.outside`), so the edge between seen and
unseen is a hard line, and what is seen reads as lit.

*To do:* sight only takes shade away, never adds light: make sure no ink is lifted for being seen
(only lanterns and the carried flame light). And feather the shade's edge: print the shade in a
few coats cut to the sight polygon grown by steps (or as a graded mesh, `ink_graded`, falling off
over `SHADE_FEATHER` px), so it fades in over the edge. Watch the cost (`RisoSight.outside` per
coat) and the flash fix (`RisoSight.SEAM`). Capture in the cemetery and the garden.

*Found:* no ink is lifted for being seen; the seen area is only left unshaded.

*Decided:* the wizard's own sight lights and shades nothing; the lanterns' light is a gradient,
without costing frames (owner, November 2026).

*Done:* the shade by the wizard's sight is gone, with `Archetype.shade` (a feathered shade was
built first and dropped with it). A lantern's light, standing or carried, is a gradient from its
flame to nothing at its reach (`RisoLight.graded`, `GRADIENT_POWER`), a mesh worked out once with
the light and printed whole (`lift_ink_mesh`); the other things that shine keep their two-step
pools. `bench_walk`, mean of the medians, before and after: standing 4.72 and 4.79 ms, walking 4.87
and 4.54 ms (no sight to work out); the light 0.20 ms a frame in the garden (0.21 before).
`sight_test` checks the gradient and that nothing is shaded. Judged good in play (owner, November
2026). *Decided:* the crypts' deep dark keeps
its two steps round each light; it looks good there (owner, November 2026), but it is much dimmer
round an unlit flame: an unprotected or snuffed wizard's light only lifts `UNLIT_DARK_LIFT` (0.4)
of the dark at the flame, fading out to its reach (`RisoLight.Fade.dim`), where it cleared it
before.

### 3e. The slash's arc to the left

*Seen:* slashing to the left, the arc is the wrong way round; its point should be on top.

*Now:* the crescent always sweeps the same way round (`SpellMark`, `&"slash"`: from `base - half`
to `base + half`), so to the left it is the right-hand slash turned over, its point at the bottom.

*Done:* the sweep mirrors when the slash heads left (`SpellMark`, `turn`), its trailing point on
top either way; captured both ways.

### 3f. The boss's door

*Seen:* the sealed door (the boss's blocker) is too distracting.

*Decided:* it is not to be calmer, only laid out so that its parts do not run into each other
(owner, November 2026). The bars, the pink and the seal's pulse stay.

*Now:* a sealed way on is dark, barred across by three pink bars, with the boss's seal pulsing on
them (`ExitArt`, `door.sealed()`). The bars lie at 74, 51 and 28 px over the door's foot, 8 px
thick; the seal, a pink disc of radius 20 (up to about 21.6 with its pulse), is centred at 52, so
it lies over the middle bar and touches the top one, and its pink runs into theirs, the boss's mark
in paper on top. Over them the crown's chevron clears the top bar by about 8 px; a grand door's
falling chevrons (`exit_grand`) drop to about 74, onto the top bar and the seal's rim.

*To do:* lay the parts out apart, each with dark showing round it: the seal in a clear space of its
own (the bars stopping short either side of it, or moved above and below it), its whole pulse
clear of the bars, and the crown's chevrons, a grand door's included, clear of the top bar and the
seal. Keep the arch's size. Capture at both garden gates and zoom in.

*Done:* the bars stop short of the seal, with dark kept clear round it at its biggest pulse
(`ExitArt.SEAL_AT`, `SEAL_CLEAR`, the bars cut with `Geometry2D.clip_polygons`); the bars sit at
70, 49 and 28 px, the seal at 45, under the chevron; a grand door's chevrons fall `GRAND_FALL`
(16 px) and stay above the top bar. The capture showed one more collision: the way on's price
printed over the seal; a sealed door no longer prints its price (it cannot be paid until the boss
is slain), and shows it again once open. `tests/capture_sealed_door.gd` photographs both garden
gates.

## 4. Sound

### 4a. Music stops on the map

*Now:* the map pauses the game (`RisoMap`: `get_tree().paused`), and the music (`Music` in
`main.tscn`, `MusicPlayer.gd`) pauses with it, as it inherits the pause.

*Done:* the music always processes (`MusicPlayer._ready`), so it plays on under the map and the
pause menu (whether the pause menu should hush it is still open). The settings page now has a
volume for the music of its own (`Settings`, on the `Music` bus).

## 5. Teleporters

### 5a. No grace after a teleporter

*Seen:* the invulnerability on arriving through a teleporter does not seem to work.

*Now:* a portal trip calls `player.grace()` only at its very end (`portal.gd`, after `ARRIVE`): the
wizard is placed at the far end and shown (`REVEAL`) before the grace starts, so for a moment
they can be hit there.

*Done:* the wizard is untouchable from the moment they are placed at the far end
(`player.graced` in `portal.gd`), the grace proper still starting once they can move;
`rift_test` checks it.

## Order of work

1. Quick and self-contained: 4a (music), 3b (A / D), 1c (title cards), 2d (dash), 5a (grace), 3e
   (slash arc).
2. The guard: 2a, 2b, then 2c by playing it.
3. The tutorial: 1b (the shooter), 1a (the trigger told from the bumper).
4. The print: 3a (worm), 3f (the door's parts apart), 3c (small pad), 3d (soft light; the biggest).

Each step: its tests, a capture where it is art, and `docs/DEEPER_PLAN.md` and
`docs/RISO_PRINT.md` kept in step.
