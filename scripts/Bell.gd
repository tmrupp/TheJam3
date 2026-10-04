extends Area2D
## A grave bell on its post, in cemetery levels, by a chasm (MapInfo.World.carve_chasms): ring it
## (interact, or strike it with a hex bolt) and the chasm's bridge lays itself across, plank by
## plank (Bridge), for good. The level record keeps it rung.

@onready var player: Player = $"/root/Main/Player"

var map_info: MapInfo
## The number of the chasm it bridges.
var chasm: int = -1
## Seconds since it was rung (the art swings it), or -1 if it was rung before this visit.
var since_rung: float = -1.0


func setup(info: MapInfo, _v: Vector2i, id: int) -> void:
	map_info = info
	chasm = id


func rung() -> bool:
	return map_info != null and map_info.bridge_up(chasm)


func ring() -> void:
	if map_info == null or rung():
		return
	since_rung = 0.0
	map_info.ring_bell(chasm)
	RisoFx.burst(&"gain", global_position + Vector2(0, -90), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
	Wound.shake(6.0, 0.25)


## A hex bolt rings it too (HexBolt strikes everything in the hex_target group).
func hex_hit(_damage: int, _dir: Vector2) -> void:
	ring()


func _process(delta: float) -> void:
	if since_rung >= 0.0:
		since_rung += delta
	$Interactable.available = not rung()


func _ready() -> void:
	add_to_group(&"hex_target")
	$Interactable.interacted.connect(ring)
