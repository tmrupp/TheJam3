extends Area2D
class_name SchoolBell
## A bell of the institute's timetable (Timetable; laid by Institute.furnish): a hand bell hung from a
## bracket on its post, one in each lecture hall and the library, and one out in the corridors near
## the way in that bears the timetable on a board under it. Ring it (interact, or strike it with a
## hex bolt from across a shaft) and the period ends: the level moves on to the next, passing time
## begins, and every scholar calms down (MapInfo.ring_period). It rings again only after RING_GAP
## seconds.

## The least time between two rings (seconds).
const RING_GAP: float = 1.0

var map_info: MapInfo
## Whether it bears the timetable's board (the corridor bell).
var board: bool = false
## Seconds since it was last rung (the art swings it).
var since_rung: float = 99.0


func setup(info: MapInfo, _v: Vector2i, extra: Variant) -> void:
	map_info = info
	board = extra is Dictionary and bool((extra as Dictionary).get("board", false))


## Ring it: the next period, and passing time.
func ring() -> void:
	if map_info == null or since_rung < RING_GAP:
		return
	since_rung = 0.0
	map_info.ring_period()
	RisoFx.burst(&"gain", global_position + Vector2(0, -100), Vector2.ZERO, [RisoPrint.BLUE, RisoPrint.NIGHT])
	Wound.shake(5.0, 0.2)


## A hex bolt rings it (HexBolt strikes everything in the hex_target group).
func hex_hit(_damage: int, _dir: Vector2) -> void:
	ring()


func _process(delta: float) -> void:
	since_rung += delta


func _ready() -> void:
	add_to_group(&"hex_target")
	$Interactable.interacted.connect(ring)
