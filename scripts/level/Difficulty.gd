class_name Difficulty
extends RefCounted
## How hard the game is: one of a few presets, picked on the F7 panel (Hard unless changed; Normal
## in a demo build). A
## preset sets two things:
## - foes: how many enemies and hazards a level is dressed with, against Normal (LevelGen.foes_per_area
##   and the other counts that use foes()). It changes what levels hold, so a level's layout depends
##   on the preset as well as its seed (LevelLoader keeps layouts per preset).
## - haste: how fast the bosses act, against Normal. Each boss runs its own clock this much faster:
##   its warnings, bites, rests and crawling all come sooner (Worm, Golem, BrambleVine, BrambleBulb,
##   the bramble's bloom and sap, BrambleHeart).
## - attack: how often the other enemies attack, against Normal: their cooldowns, rests and tells run
##   this much faster (a watcher's shot, a hopper's crouch and rest, a bird's tell and rest between
##   swoops, a wisp's wind-up and rest around a lurch, a skeleton's before and after a swipe, a
##   wraith's swell and rest around a dart, a nest's hatching).
## - speed: how fast the other enemies move, against Normal, a little faster on a harder preset (a
##   wisp's walk, a wraith's drift, a bird's patrol, a moth swarm, a rock-bug's crawl).
## Every attack's tell, its wait from the first sign to the blow, runs at the preset's pace but never
## under TELL_MIN (tell, boss_tell; docs/REVIEW_PLAN.md §8), so the guard can always be timed off it.
## Static and scene-free, like Rules.

enum Preset { NORMAL, HARD, BRUTAL }

## Each preset's name on the F7 panel, by Preset.
const NAMES: Array[String] = ["Normal", "Hard", "Brutal"]
## Each preset's share of foes against Normal, by Preset.
const FOES: Array[float] = [1.0, 1.4, 1.8]
## Each preset's boss haste against Normal, by Preset.
const HASTE: Array[float] = [1.0, 1.15, 1.3]
## Each preset's enemy attack rate against Normal, by Preset.
const ATTACK: Array[float] = [1.0, 1.2, 1.4]
## Each preset's enemy speed against Normal, by Preset.
const SPEED: Array[float] = [1.0, 1.08, 1.15]
## The least time (seconds) any attack waits from its first sign to its blow, on every preset: a
## harder preset runs a foe's tell faster, but never under this (tell, boss_tell).
const TELL_MIN: float = 0.4
## The last beat of every tell (seconds): the guard's window (Parry.WINDOW), the moment a guard raised
## catches the blow, which the foes' art prints apart from the rest of the wait (a flash to paper,
## CreatureArt.tell_mark).
const LAST_BEAT: float = Rules.GUARD_WINDOW
## The preset a game starts on.
const DEFAULT: Preset = Preset.HARD
## The preset a demo build starts on (Dev.demo_build): a demo is played by one new player
## after another, with no F7 panel to make it easier.
const DEMO_DEFAULT: Preset = Preset.NORMAL

## The preset in play (F7 changes it; it lasts while the game runs). It starts as start_preset
## does, asking the build's features itself, as Dev.demo_build does: MapInfo may not be set
## up yet when this is.
static var preset: Preset = DEMO_DEFAULT if OS.has_feature("demo") else DEFAULT


## The preset a game starts on: Normal in a demo build (DEMO_DEFAULT), else Hard (DEFAULT).
static func start_preset() -> Preset:
	return DEMO_DEFAULT if Dev.demo_build else DEFAULT


## How many foes a level is dressed with, against Normal.
static func foes() -> float:
	return FOES[preset]


## How fast the bosses act, against Normal.
static func haste() -> float:
	return HASTE[preset]


## How often the other enemies attack, against Normal.
static func attack() -> float:
	return ATTACK[preset]


## How fast the other enemies move, against Normal.
static func speed() -> float:
	return SPEED[preset]


## How long a tell `seconds` long at Normal lasts on the preset in play: at the foes' attack pace,
## never under TELL_MIN.
static func tell(seconds: float) -> float:
	return maxf(TELL_MIN, seconds / attack())


## How long a boss's tell `seconds` long at Normal lasts on the preset in play: at its haste, never
## under TELL_MIN.
static func boss_tell(seconds: float) -> float:
	return maxf(TELL_MIN, seconds / haste())


## Whether a tell `seconds` long (as it runs now: tell, boss_tell), `u` (0 to 1) of the way through,
## is in its last beat (LAST_BEAT); never while it is not under way (`u` below 0).
static func last_beat(u: float, seconds: float) -> bool:
	return u >= 0.0 and (1.0 - u) * seconds <= LAST_BEAT
