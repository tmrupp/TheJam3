extends Area2D
class_name Spikes
## Thorns: they hurt the wizard who touches them, pointing out of the rock they grow from. Most are
## always out. Some come and go (LevelGen.place_thorn_modes, kept in the cell's extra_info):
## - on a timer: out for UP seconds (or as long as the cell says: a crypt's alternating thorns,
##   Crypts), then down for the rest of CYCLE, from a phase of their own (so neighbouring runs are
##   not in step), shared by the whole run; for WARN seconds before they rise their tips peek and
##   flicker;
## - on a switch: down while the switch is on (Switch), out while it is off.
## Down, they do not hurt and can be walked through; rising under the wizard, they hurt at once.
## Out, the wizard's spells strike them (SpellStrike.thorns_caught, HexBolt): nothing comes of it to
## the thorns, but a blow that lands throws the wizard back off them, as off an enemy, so a slash
## down onto thorns bounces the wizard up.

const UP: float = 1.6
const CYCLE: float = 3.0
const WARN: float = 0.45
## How fast (of the way, a second) the thorns slide out and in, for the art.
const SLIDE: float = 9.0
## The group every run of thorns is in, for the spells that strike them.
const GROUP: StringName = &"thorns"
## Where the thorns' body lies (its own measures, before the prefab's scale): its middle, out from
## the node toward the rock they grow from, and half its length along the rock and its thickness.
const BODY: Vector2 = Vector2(0.0, 12.0)
const BODY_HALF: Vector2 = Vector2(15.75, 4.0)

enum Mode { ALWAYS, TIMED, SWITCHED }

var offset_rotation: Dictionary = {
	Vector2i(-1,0) : -90,
	Vector2i(1,0) : 90,
	Vector2i(0,1) : 180,
	Vector2i(0,-1) : 0,
}

var mode: Mode = Mode.ALWAYS
## A timed run's phase (seconds) and how long it is out of each CYCLE; a switched run's switch.
var phase: float = 0.0
var up: float = UP
var lever: Vector2i = Vector2i(-1, -1)
var map_info: MapInfo
## Whether they are out (and hurt), and how far out they are drawn (0 down, 1 out).
var out: bool = true
var rise: float = 1.0


func _ready() -> void:
	add_to_group(GROUP)


## Where the thorns' body runs along the rock (world): its two ends.
func body_ends() -> Array[Vector2]:
	return [to_global(BODY - Vector2(BODY_HALF.x, 0.0)), to_global(BODY + Vector2(BODY_HALF.x, 0.0))]


## Half how thick the thorns' body is (world pixels).
func body_thick() -> float:
	return BODY_HALF.y * global_scale.y


## Whether the way from `a` to `b` passes within `reach` of the thorns' body, while they are out.
func struck_by(a: Vector2, b: Vector2, reach: float) -> bool:
	if not out:
		return false
	var ends: Array[Vector2] = body_ends()
	var near: PackedVector2Array = Geometry2D.get_closest_points_between_segments(a, b, ends[0], ends[1])
	return near[0].distance_to(near[1]) <= reach + body_thick()


func setup(_map_info: MapInfo, v: Vector2i) -> void:
	map_info = _map_info
	var world: LevelGen = _map_info.world
	var extra: Variant = world.get_cell(v).extra_info
	if extra is Dictionary:
		var how: Dictionary = extra
		if how.has("timed"):
			mode = Mode.TIMED
			phase = float(how["timed"])
			up = float(how.get("up", UP))
		elif how.has("switch"):
			mode = Mode.SWITCHED
			lever = how["switch"]
	set_physics_process(mode != Mode.ALWAYS)
	out = wanted()
	rise = 1.0 if out else 0.0
	_arm(out)
	var ns: Array[Vector2i] = world.get_neighbors(v)
	if len(ns) == 0:
		queue_free()
	else:
		for n: Vector2i in ns:
			if world.is_ground(n):
				rotation_degrees = offset_rotation[v - n]
				return
	queue_free()


## The game's clock all thorns keep time by (seconds), so a run moves together.
static func clock() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


## Whether they should be out now.
func wanted() -> bool:
	match mode:
		Mode.TIMED:
			return fposmod(clock() + phase, CYCLE) < up
		Mode.SWITCHED:
			return map_info == null or not map_info.switch_on(lever)
	return true


## For a timed run that is down: 0 until WARN before they rise, then up to 1 as they do (the art
## peeks the tips); 0 otherwise.
func warning() -> float:
	if mode != Mode.TIMED or out:
		return 0.0
	var until: float = CYCLE - fposmod(clock() + phase, CYCLE)
	return clampf(1.0 - until / WARN, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	var want: bool = wanted()
	if want != out:
		out = want
		_arm(out)
	rise = move_toward(rise, 1.0 if out else 0.0, delta * SLIDE)


## Out (hurting) or down: the body that touches the wizard is on or off.
func _arm(on: bool) -> void:
	var shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.set_deferred("disabled", not on)
