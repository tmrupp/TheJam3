class_name GameClock
extends RefCounted
## The game's own time, apart from the wall clock: game seconds, counted in physics steps (now), so
## a busy machine, or a test run at a fixed step, runs the game slower or faster but the same (the
## hit-stop is timed on it too, Wound.hit_stop: its slowing of the game's time does not slow the
## steps); and the order things happened in within a step (order). Game logic reads this, never
## Time.get_ticks_*. Some art still flashes by the wall clock (RisoPrint's portal and exit flares,
## PortalArt, DepartmentArt, RisoBackground): it only shows, and changes nothing.

## The last stamp handed out by order.
static var _order: int = 0


## Game seconds since the game started: the physics steps run, at the physics rate (the hit-stop's
## slowing aside, as each step still counts as one).
static func now() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


## A stamp larger than every one handed out before: what happened first has the smaller one, even
## within one physics step (a hit and a catch in the same step, Parry and Player).
static func order() -> int:
	_order += 1
	return _order
