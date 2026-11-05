# Playtest fixes: the tutorial, the guard, the print

A plan for the owner's playtest notes of November 2026, on the garden demo and its tutorial. Each
item says what was seen, what the code does now (where it was found), what to do, and what is still
open. The order of work is at the end. Steps 1 and 2 of it are built (marked *Done*); the rest is not yet.

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

*Done in part:* with 2a and 2b a catch gives the spell back, so the next press after a bounce
casts (and guards) again. *To do:* play it, and tune the bounce (`Parry.POGO`), the hit-stop and
`SAFE` if it still feels off.

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

### 3e. The slash's arc to the left

*Seen:* slashing to the left, the arc is the wrong way round; its point should be on top.

*Now:* the crescent always sweeps the same way round (`SpellMark`, `&"slash"`: from `base - half`
to `base + half`), so to the left it is the right-hand slash turned over, its point at the bottom.

*Done:* the sweep mirrors when the slash heads left (`SpellMark`, `turn`), its trailing point on
top either way; captured both ways.

### 3f. The boss's door

*Seen:* the sealed door (the boss's blocker) is too distracting.

*Now:* a sealed way on is dark, barred across by three pink bars, with the boss's seal pulsing on
them (`ExitArt`, `door.sealed()`).

*To do:* calm it: thinner bars in night or blue with a little pink, the seal still and smaller,
no pulse. Keep it readable as shut. Capture at both garden gates.

## 4. Sound

### 4a. Music stops on the map

*Now:* the map pauses the game (`RisoMap`: `get_tree().paused`), and the music (`Music` in
`main.tscn`, `MusicPlayer.gd`) pauses with it, as it inherits the pause.

*Done:* the music always processes (`MusicPlayer._ready`), so it plays on under the map and the
pause menu (whether the pause menu should hush it is still open).

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
4. The print: 3a (worm), 3f (door), 3c (small pad), 3d (soft light; the biggest).

Each step: its tests, a capture where it is art, and `docs/DEEPER_PLAN.md` and
`docs/RISO_PRINT.md` kept in step.
