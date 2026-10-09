class_name Stalactite
extends Area2D
## A falling stalactite, in crag levels (CragsArchetype.place_stalactites): a spike of rock hanging
## from a ceiling. When the wizard passes under it (within REACH either side of it, no further than
## WATCH cells down, with nothing solid between), it shakes for SHAKE seconds, then lets go and
## falls, and its touch hurts while it falls (its Damager, as thorns do; a parry catches it, and a
## pogo off it is a bounce like any). A hex bolt knocks it loose at once while it hangs or shakes
## (hex_hit; it is struck as an enemy is, near its root). Falling, it crushes an enemy it lands on
## (CRUSH damage and a stun, or a plate off a shield). It shatters on the rock it lands on, on the
## wizard or on an enemy, and grows back over REGROW seconds, harmless (and no target) until it
## hangs again. Nothing about it is kept, and nothing here draws from the world RNG.

## How far either side of it (pixels) and how far down (cells) it feels the wizard pass under it.
const REACH: float = 72.0
const WATCH: int = 7
## How long it shakes before it falls (seconds), how fast it falls (pixels a second more each
## second, at most MAX_FALL), and how long it takes to grow back (seconds).
const SHAKE: float = 0.45
const GRAVITY: float = 2200.0
const MAX_FALL: float = 1500.0
const REGROW: float = 6.0
## What a falling one does to an enemy it lands on: wounds it by CRUSH and stuns it for CRUSH_STUN
## seconds. It lands on one within CRUSH_REACH pixels of its lower half.
const CRUSH: int = 2
const CRUSH_STUN: float = 3.0
const CRUSH_REACH: float = 28.0
## How long it hangs from the ceiling to its tip, and how wide it is at the ceiling (pixels).
const LENGTH: float = 92.0
const WIDE: float = 34.0

enum State { HANGING, SHAKING, FALLING, REGROWING }

var map_info: MapInfo
var state: State = State.HANGING
## Where it hangs from (the middle of its cell's ceiling, world pixels), how far it has fallen from
## there (pixels) and how fast; how long it has shaken or regrown (seconds).
var home: Vector2 = Vector2.ZERO
var drop: float = 0.0
var fall_speed: float = 0.0
var timer: float = 0.0

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _damager: Damager = $Damager


## Hung from the ceiling of cell `v`.
func setup(info: MapInfo, v: Vector2i) -> void:
	map_info = info
	var tm: TileMap = info.tile_map
	var half: float = float(tm.tile_set.tile_size.y) * tm.global_scale.y * 0.5
	home = info.cell_position(v) + Vector2(0.0, -half)
	position = home


func _ready() -> void:
	_damager.touched_player.connect(_shatter)
	_set_harmful(false)
	add_to_group(&"hex_target")


## A hex bolt knocks it loose: while it hangs or shakes, it falls at once (HexBolt strikes
## everything in the hex_target group).
func hex_hit(_damage: int, _dir: Vector2) -> void:
	if state == State.HANGING or state == State.SHAKING:
		_fall()


## How far it has grown back (0 gone, 1 whole), for the art.
func grown() -> float:
	return clampf(timer / REGROW, 0.0, 1.0) if state == State.REGROWING else 1.0


## Its tip, in world pixels.
func tip() -> Vector2:
	return global_position + Vector2(0.0, LENGTH)


func _physics_process(delta: float) -> void:
	if map_info == null or map_info.world == null:
		return
	match state:
		State.HANGING:
			if _wizard_under():
				state = State.SHAKING
				timer = 0.0
		State.SHAKING:
			timer += delta
			if timer >= SHAKE:
				_fall()
		State.FALLING:
			fall_speed = minf(fall_speed + GRAVITY * delta, MAX_FALL)
			drop += fall_speed * delta
			position = home + Vector2(0.0, drop)
			if map_info.solid_at(tip()) or drop > float(map_info.world.size.y) * _cell():
				_shatter()
			else:
				_crush()
		State.REGROWING:
			timer += delta
			if timer >= REGROW:
				state = State.HANGING
				add_to_group(&"hex_target")


## Let go of the ceiling: from now its touch hurts.
func _fall() -> void:
	state = State.FALLING
	fall_speed = 0.0
	_set_harmful(true)


func _cell() -> float:
	var tm: TileMap = map_info.tile_map
	return float(tm.tile_set.tile_size.y) * tm.global_scale.y


## Whether the wizard is under it: within REACH either side, at most WATCH cells down, and nothing
## solid between.
func _wizard_under() -> bool:
	var player: Player = map_info.player
	if player == null or not is_instance_valid(player):
		return false
	var gap: Vector2 = player.global_position - home
	if absf(gap.x) > REACH or gap.y <= 0.0 or gap.y > float(WATCH) * _cell():
		return false
	var top: Vector2i = map_info.cell_at(home + Vector2(0.0, 1.0))
	var bottom: Vector2i = map_info.cell_at(Vector2(home.x, player.global_position.y))
	for y: int in range(top.y, bottom.y + 1):
		if map_info.solid_at(map_info.cell_position(Vector2i(top.x, y))):
			return false
	return true


## Land on the first enemy under its lower half, if any (see CRUSH): wound and stun it (or take a
## plate off its shield), and shatter on it.
func _crush() -> void:
	var from: Vector2 = tip() + Vector2(0.0, -LENGTH * 0.5)
	for e: Node in get_tree().get_nodes_in_group(&"hex_target"):
		if e == self or not is_instance_valid(e) or e.is_queued_for_deletion() or not e is Node2D:
			continue
		var wound: Wound = e.get_node_or_null("Wound") as Wound
		var at: Vector2 = (e as Node2D).global_position
		if wound == null or Geometry2D.get_closest_point_to_segment(at, from, tip()).distance_to(at) > CRUSH_REACH:
			continue
		var shield: Shield = Shield.of(e)
		if shield == null or not shield.absorb(false, Vector2.DOWN):
			wound.hit(CRUSH, Vector2.DOWN)
			var stunner: Stunner = Stunner.of(e)
			if stunner != null and is_instance_valid(e) and not e.is_queued_for_deletion():
				stunner.stun(CRUSH_STUN)
		_shatter()
		return


## Break where it is (on the rock it landed on, the wizard or an enemy), and start growing back.
func _shatter() -> void:
	if state != State.FALLING:
		return
	RisoFx.burst(&"rubble", tip(), Vector2.UP, [RisoPrint.BLUE, RisoPrint.BLUE, RisoPrint.PINK])
	remove_from_group(&"hex_target")
	state = State.REGROWING
	timer = 0.0
	drop = 0.0
	position = home
	_set_harmful(false)


## Its touch hurts only while it falls.
func _set_harmful(on: bool) -> void:
	_shape.set_deferred(&"disabled", not on)
	_damager.touching_player = false
