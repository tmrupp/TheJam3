extends Area2D
class_name TowerSwitch
## A crag tower's switch (CragsArchetype.set_stations; docs/REGIONS_PLAN.md §7, "The tower puzzle"):
## interact with it to flip the gondola stations it works (`mask`, a bit each from the bottom), on
## ones off and off ones on (MapInfo.flip_tower). Its art shows the line straight, each station lit
## or dark as it is now, a ring round each it flips (TowerSwitchArt). Once flipped it is locked until another tower's switch is flipped; tried while locked, it
## only balks. A cold tower's switch (MapInfo.tower_cold) balks too, until an empowered strike on the
## tower's spire wakes it (Spire). A strike on a warm tower's spire flips it as a hand would.

var map_info: MapInfo
## Which tower it stands in, and the stations it flips.
var tower: int = -1
var mask: int = 0
## When it last flipped, and last balked (its clock, for the art).
var flipped_at: float = -9.0
var balked_at: float = -9.0
var t: float = 0.0


func setup(info: MapInfo, _v: Vector2i, extra: Dictionary) -> void:
	map_info = info
	tower = int(extra.get("tower", -1))
	mask = int(extra.get("mask", 0))


## How many stations the level's gondola has (0 for none).
func station_count() -> int:
	if map_info == null or map_info.world == null or map_info.world.circuit.is_empty():
		return 0
	return (map_info.world.circuit["gates"] as Array).size()


## Whether it is locked: the tower flipped last.
func locked() -> bool:
	return map_info != null and map_info.last_tower == tower


## Whether its tower is cold, not yet woken (it does nothing).
func cold() -> bool:
	return map_info != null and map_info.tower_cold(tower)


## Flip the stations it works, or balk if it is locked.
func use() -> void:
	if map_info == null or map_info.travelling:
		return
	if not cold() and map_info.flip_tower(tower, mask):
		flipped_at = t
		RisoFx.burst(&"gain", global_position + Vector2(0, -40), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
	else:
		balked_at = t
		RisoFx.burst(&"hit", global_position + Vector2(0, -40), Vector2.UP, [RisoPrint.PINK, RisoPrint.NIGHT])


func _process(delta: float) -> void:
	t += delta


func _ready() -> void:
	$Interactable.interacted.connect(use)
