extends Node2D
class_name Spire
## A watchtower's iron spire, standing on its roof (CragsArchetype.place_spires): an empowered strike
## on it (a hex or a seeker from afar, any damage spell from beside it; Empower) flips its tower's
## switch, under the same lock as throwing it by hand (MapInfo.strike_spire). A cold tower's switch
## (TowerSwitch) does nothing until one empowered strike on its spire wakes it, for good; that strike
## only wakes it. A plain hit rings off the iron and does nothing. A seeker cast empowered homes on a
## spire it can see (HexBolt.seek).

## Every spire in the level (an empowered seeker looks among them).
const GROUP: StringName = &"spire"
## How far (px) over its cell's middle the head of the spire stands: where a bolt strikes it.
const HEAD_UP: float = 70.0

var map_info: MapInfo
## Which tower it stands on (LevelGen.towers).
var tower: int = -1
## When it was last struck, empowered (it flashes) and plainly (it rings), on its clock (for the art).
var struck_at: float = -9.0
var rung_at: float = -9.0
var t: float = 0.0


func setup(info: MapInfo, _v: Vector2i, extra: Dictionary) -> void:
	map_info = info
	tower = int(extra.get("tower", -1))


func _ready() -> void:
	add_to_group(&"hex_target")
	add_to_group(GROUP)


func _process(delta: float) -> void:
	t += delta


## Where bolts aim for it: its head.
func head() -> Vector2:
	return global_position + Vector2(0, -HEAD_UP)


## Whether its tower is cold (its switch dead until a strike here wakes it).
func cold() -> bool:
	return map_info != null and map_info.tower_cold(tower)


## A plain hit: it rings, and nothing comes of it.
func hex_hit(_damage: int, dir: Vector2) -> void:
	rung_at = t
	RisoFx.burst(&"hit", head(), dir, [RisoPrint.BLUE, RisoPrint.NIGHT])


## An empowered strike: its tower's switch flips (or a cold tower wakes).
func empowered_hit(dir: Vector2) -> void:
	if map_info == null:
		return
	if map_info.strike_spire(tower):
		struck_at = t
		RisoFx.burst(&"gain", head(), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
		Wound.shake(6.0, 0.15)
	else:
		hex_hit(1, dir)
