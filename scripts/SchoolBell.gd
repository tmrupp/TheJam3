extends Area2D
class_name SchoolBell
## A cord of the institute's great bell (Timetable; laid by Institute.furnish): a thick cord of spell
## light hanging all the way from the ceiling to a tassel within reach (SchoolBellArt), one in each
## lecture hall and the library, up through the ceiling to the bell, and one out in the corridors near
## the way in hanging from the great bell itself, with the timetable on a board beside it (`board`).
## Pull it (interact, or strike it with a spell from across a shaft) and the great bell rings: the
## period ends, the level moves on to the next, passing time begins, every scholar calms down, and the
## whole institute shakes while it rings out (MapInfo.ring_period, MapInfo.BELL_TIME). The bell rings
## again only RING_GAP seconds after it last rang, whichever cord is pulled.

## The least time between two rings of the great bell (seconds).
const RING_GAP: float = 1.0

var map_info: MapInfo
## Whether it hangs from the great bell itself, with the timetable's board (the corridor's cord).
var board: bool = false
## How many cells up its ceiling is (the first rock over its cell): the cord reaches it.
var reach: int = 1
## Seconds since it was last pulled (the art).
var since_rung: float = 99.0


func setup(info: MapInfo, v: Vector2i, extra: Variant) -> void:
	map_info = info
	board = extra is Dictionary and bool((extra as Dictionary).get("board", false))
	reach = ceiling_over(info.world, v)


## How many cells up from cell `v` of `w` the ceiling is: the first rock over it (or the level's top).
static func ceiling_over(w: LevelGen, v: Vector2i) -> int:
	var k: int = 1
	while w != null and w.is_valid(v + Vector2i(0, -k)) and not w.is_ground(v + Vector2i(0, -k)):
		k += 1
	return k


## Pull it: the great bell rings (the next period, and passing time).
func ring() -> void:
	if map_info == null or map_info.since_bell < RING_GAP:
		return
	since_rung = 0.0
	map_info.ring_period()


## A hex bolt rings it (HexBolt strikes everything in the hex_target group).
func hex_hit(_damage: int, _dir: Vector2) -> void:
	ring()


func _process(delta: float) -> void:
	since_rung += delta


func _ready() -> void:
	add_to_group(&"hex_target")
	$Interactable.interacted.connect(ring)
