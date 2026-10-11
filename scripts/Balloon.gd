extends Area2D
class_name Balloon
## A balloon moored on an island, one in every sky level (SkyArchetype.place_balloon). Ridden, it
## carries the wizard along the row to another world, by the level's wind (Rules.wind_of): its way
## says which way, and its strength how far, a world for every STEP vanes on that way, at most MOST
## worlds. With the wind too weak (or still) it goes nowhere. Its prompt says where it would go
## before the wizard boards. The wizard comes down by the balloon moored in the level it goes to
## (MapInfo.balloon_travel), ready to ride on by that level's wind. Nothing here draws from any RNG.

## Vanes on the wind's way for each world it carries the wizard, and the most worlds it goes.
const STEP: int = 2
const MOST: int = 3
## How long it rises before the trip begins (seconds), and how high (px).
const RISE_TIME: float = 0.9
const RISE: float = 220.0

var map_info: MapInfo
## Seconds since it began to rise with the wizard (-1 until it does), and the wizard's spot in its
## basket as it rises.
var rising: float = -1.0
var _from: Vector2 = Vector2.ZERO


func setup(info: MapInfo, _v: Vector2i) -> void:
	map_info = info


## How many worlds the level's wind would carry it, signed by the way it blows (0: nowhere).
static func trip(wind: int) -> int:
	@warning_ignore("integer_division")
	return signi(wind) * mini(absi(wind) / STEP, MOST)


## Where it would go now (a place on the same row), or null while the wind is too weak.
func destination() -> Variant:
	if map_info == null:
		return null
	var worlds: int = trip(map_info.level_wind())
	if worlds == 0:
		return null
	return map_info.coord + Vector2i(worlds, 0)


func interaction_hint() -> Dictionary:
	var to: Variant = destination()
	if to == null:
		return {"text": "becalmed"}
	return {"text": "to world %d" % (to as Vector2i).x}


## Board it: with wind enough it rises with the wizard and carries them off; becalmed, nothing.
func use() -> void:
	var to: Variant = destination()
	if to == null or rising >= 0.0 or map_info == null or map_info.travelling:
		return
	var player: Player = Stage.player()
	if player == null:
		return
	rising = 0.0
	_from = player.global_position
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO


func _process(delta: float) -> void:
	if rising < 0.0:
		return
	rising += delta
	var player: Player = Stage.player()
	var u: float = clampf(rising / RISE_TIME, 0.0, 1.0)
	if player != null:
		player.global_position = _from + Vector2(0.0, -RISE * u * u)
	if rising >= RISE_TIME and map_info != null and not map_info.travelling:
		var to: Variant = destination()
		if to != null:
			map_info.balloon_travel(to as Vector2i)


func _ready() -> void:
	$Interactable.interacted.connect(use)
