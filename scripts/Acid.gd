class_name Acid
extends Node2D
## A pool of acid, in the whale's belly (Belly): it lies in a basin of open cells (`basin`), over and
## over drained to `low_y` for HOLD_LOW seconds, warning for WARN seconds (it seethes and the belly
## rumbles), flooding up to `high_y` over RISE seconds, holding there HOLD_HIGH seconds and draining
## back over DRAIN seconds. Its clock starts drained as the place is entered, so a visit always
## begins with time to cross it.
## In it the wizard wades (Player asks depth_at): slowed across to WADE, sinking no faster than
## SINK, and each jump off the bottom of it a stroke up (STROKE). It burns them slowly: a burn
## BURN_FIRST seconds after they go in, then one every BURN_EVERY seconds while they stay (just over
## the untouchable spell after a blow), cooling off as fast again while they are out. A burn is no
## blow: no guard catches it and it pushes no one. Wreckage floats on it (Wreck). Printed by its own
## art (AcidArt). Nothing here draws from any RNG.

## Its cycle (seconds): drained, warning, flooding, flooded, draining.
const HOLD_LOW: float = 7.0
const WARN: float = 2.0
const RISE: float = 4.0
const HOLD_HIGH: float = 6.0
const DRAIN: float = 5.0
## The wizard in it: how fast they wade across and sink (px/s), how fast a fall into it is checked
## to that (px/s²), how hard a stroke sends them up (px/s), and the seconds between strokes.
const WADE: float = 150.0
const SINK: float = 110.0
const DRAG: float = 2600.0
const STROKE: float = 430.0
const STROKE_REST: float = 0.3
## How far above their soles (px) the wizard's feet are taken to be in it (wading), how deep (px)
## they must be to burn, the seconds to the first burn and between
## burns, and the blow a burn is.
const FEET: float = 4.0
const BURN_DEPTH: float = 10.0
const BURN_FIRST: float = 0.6
const BURN_EVERY: float = 2.2
const BURN: int = 1
## How hard the belly rumbles as it warns, and how much its surface heaves (px) as it lies.
const RUMBLE: float = 5.0
const HEAVE: float = 6.0

var map_info: MapInfo
## The cells it may fill, the world's rectangle round them, and how high its surface lies drained and
## flooded (world y).
var basin: Rect2i = Rect2i()
var rect: Rect2 = Rect2()
var low_y: float = 0.0
var high_y: float = 0.0
## Seconds into its cycle, and the wizard's burn: seconds toward the next one while they are in it.
var t: float = 0.0
var heat: float = 0.0
## The size of a cell (px).
var cell: Vector2 = Vector2(128, 128)
var _warned: bool = false


## `extra` holds the basin (cells) and its surface drained and flooded, as rows (a fraction is that
## share of a row down from its top).
func setup(info: MapInfo, _v: Vector2i, extra: Dictionary) -> void:
	map_info = info
	cell = info.cell_position(Vector2i(1, 1)) - info.cell_position(Vector2i.ZERO)
	basin = extra["basin"]
	var corner: Vector2 = info.cell_position(basin.position) - cell * 0.5
	rect = Rect2(corner, Vector2(basin.size) * cell)
	var top: float = info.cell_position(Vector2i(basin.position.x, 0)).y - cell.y * 0.5
	low_y = top + float(extra["low"]) * cell.y
	high_y = top + float(extra["high"]) * cell.y
	# Sit in the middle of its basin, so its art is drawn whenever any of it is in view.
	global_position = rect.get_center()


func _ready() -> void:
	add_to_group(&"acid")


## The basin (world space). Things that wake and print by what is in view go by all of it.
func extent() -> Rect2:
	return rect


## Seconds in one cycle.
static func period() -> float:
	return HOLD_LOW + WARN + RISE + HOLD_HIGH + DRAIN


## How flooded it is at `time` into its cycle: 0 drained, 1 flooded.
static func level_at(time: float) -> float:
	var c: float = fposmod(time, period())
	if c < HOLD_LOW + WARN:
		return 0.0
	c -= HOLD_LOW + WARN
	if c < RISE:
		return smoothstep(0.0, 1.0, c / RISE)
	c -= RISE
	if c < HOLD_HIGH:
		return 1.0
	c -= HOLD_HIGH
	return 1.0 - smoothstep(0.0, 1.0, c / DRAIN)


## How flooded it is now (see level_at).
func level() -> float:
	return level_at(t)


## How far through its warning it is (0..1), or 0 when it is not warning.
func warning() -> float:
	var c: float = fposmod(t, period())
	return clampf((c - HOLD_LOW) / WARN, 0.0, 1.0) if c >= HOLD_LOW and c < HOLD_LOW + WARN else 0.0


## Whether it is rising or flooded (from its warning to the end of its draining).
func flooding() -> bool:
	return fposmod(t, period()) >= HOLD_LOW


## Its surface now (world y): level between drained and flooded, heaving a little.
func surface() -> float:
	return lerpf(low_y, high_y, level()) + sin(t * 1.3) * HEAVE * 0.5


## Whether cell `c` is one it fills (open, inside its basin).
func fills(c: Vector2i) -> bool:
	return basin.has_point(c) and map_info != null and map_info.world != null and not map_info.world.is_ground(c)


## How deep (px) world point `at` is in it now; 0 out of it.
func depth(at: Vector2) -> float:
	if not rect.has_point(at) or not fills(map_info.cell_at(at)):
		return 0.0
	return maxf(0.0, at.y - surface())


## How deep `at` is in any acid (the deepest).
static func depth_at(tree: SceneTree, at: Vector2) -> float:
	var deepest: float = 0.0
	for node: Node in tree.get_nodes_in_group(&"acid"):
		var acid: Acid = node as Acid
		if acid != null and not acid.is_queued_for_deletion() and acid.map_info != null:
			deepest = maxf(deepest, acid.depth(at))
	return deepest


## How deep the wizard's feet are in any acid: a point a little above their soles (FEET), so feet
## on the floor of a pit count as in what lies over it.
static func wading(player: Player) -> float:
	return depth_at(player.get_tree(), Vector2(player.global_position.x, player.feet_y() - FEET))


## The acid under `x` (world), the first whose basin spans it, or null.
static func under(tree: SceneTree, x: float) -> Acid:
	for node: Node in tree.get_nodes_in_group(&"acid"):
		var acid: Acid = node as Acid
		if acid != null and acid.map_info != null and x >= acid.rect.position.x and x <= acid.rect.end.x:
			return acid
	return null


func _physics_process(delta: float) -> void:
	if map_info == null:
		return
	t += delta
	# The belly rumbles once as it begins to warn.
	var warn: float = warning()
	if warn > 0.0 and not _warned:
		_warned = true
		Wound.shake(RUMBLE, WARN)
	elif warn <= 0.0:
		_warned = false
	var player: Player = Stage.player()
	if player == null or not is_instance_valid(player) or map_info.travelling:
		return
	if depth(Vector2(player.global_position.x, player.feet_y() - FEET)) > BURN_DEPTH:
		heat += delta
		if heat >= BURN_FIRST:
			heat -= BURN_EVERY
			burn(player)
	else:
		heat = move_toward(heat, 0.0, delta)


## A burn: a blow, but none a guard catches (Parry), and no push. A projection (AstralProjection)
## passes through unburnt.
func burn(player: Player) -> void:
	if player.phasing:
		return
	player.normal_hurt(-BURN, Vector2.ZERO, self)
