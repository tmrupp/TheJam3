extends Area2D
class_name SchoolBell
## A bell's cord in the institute (Timetable; laid by Institute.furnish): a thick cord of spell light
## hanging all the way from the ceiling to a tassel within reach (SchoolBellArt), one in each lecture
## hall and the library, up through the ceiling, and out in the corridors one under each corridor
## bell (`great`), whose yoke marks the period. Pull it (interact, or strike it with a spell from
## across a shaft) and it rings, if it can (MapInfo.pull_cord): a classroom's starts its class, any
## other rings the period out, and the whole institute shakes while it rings out (MapInfo.BELL_TIME).
## The cord rung last cannot be rung again until another has been, and none rings within RING_GAP
## seconds of the last ring.

## The least time between two rings of the great bell (seconds).
const RING_GAP: float = 1.0

var map_info: MapInfo
## Its cell (what the level's record knows it by: LevelRecord.last_bell).
var cell: Vector2i = Vector2i(-1, -1)
## Whether it hangs from a corridor bell itself (out in the corridors).
var great: bool = false
## How many cells up its ceiling is (the first rock over its cell): the cord reaches it.
var reach: int = 1
## Seconds since it was last pulled (the art).
var since_rung: float = 99.0


func setup(info: MapInfo, v: Vector2i, extra: Variant) -> void:
	map_info = info
	cell = v
	great = extra is Dictionary and bool((extra as Dictionary).get("great", false))
	reach = ceiling_over(info.world, v)


## How many cells up from cell `v` of `w` the ceiling is: the first rock over it (or the level's top).
static func ceiling_over(w: LevelGen, v: Vector2i) -> int:
	var k: int = 1
	while w != null and w.is_valid(v + Vector2i(0, -k)) and not w.is_ground(v + Vector2i(0, -k)):
		k += 1
	return k


## Whether it was the cord rung last, which cannot be rung again yet.
func spent() -> bool:
	return map_info != null and map_info.world != null and map_info.record().last_bell == cell


## Pull it: it rings, if it can (MapInfo.pull_cord).
func ring() -> void:
	if map_info == null or not map_info.pull_cord(cell):
		return
	since_rung = 0.0


## A hex bolt rings it (HexBolt strikes everything in the hex_target group).
func hex_hit(_damage: int, _dir: Vector2) -> void:
	ring()


func _process(delta: float) -> void:
	since_rung += delta


func _ready() -> void:
	add_to_group(&"hex_target")
	$Interactable.interacted.connect(ring)
