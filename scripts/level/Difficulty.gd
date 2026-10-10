class_name Difficulty
extends RefCounted
## How hard the game is: one of a few presets, picked on the F7 panel (Hard unless changed). A
## preset sets two things:
## - foes: how many enemies and hazards a level is dressed with, against Normal (LevelGen.foes_per_area
##   and the other counts that use foes()). It changes what levels hold, so a level's layout depends
##   on the preset as well as its seed (LevelLoader keeps layouts per preset).
## - haste: how fast the bosses act, against Normal. Each boss runs its own clock this much faster:
##   its warnings, bites, rests and crawling all come sooner (Worm, Spider, BrambleVine, BrambleBulb).
## - attack: how often the other enemies attack, against Normal: their cooldowns, rests and tells run
##   this much faster (a watcher's shot, a hopper's crouch and rest, a bird's tell and rest between
##   swoops, a nest's hatching).
## - speed: how fast the other enemies move, against Normal, a little faster on a harder preset (a
##   wisp's walk, a wraith's drift, a bird's patrol, a moth swarm, a rock-bug's crawl).
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
## The preset a game starts on.
const DEFAULT: Preset = Preset.HARD

## The preset in play (F7 changes it; it lasts while the game runs).
static var preset: Preset = DEFAULT


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
