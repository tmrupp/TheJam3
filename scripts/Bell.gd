extends Area2D
## A grave bell on its post, in cemetery levels, by a chasm (MapInfo.World.carve_chasms); each
## chasm has one on either side, and either lays its bridge. It hangs chained up: by a padlock in
## a key colour, or to a switch on its side of the chasm. Interact while carrying a key of the
## padlock's colour (or a skeleton key, which is used up) and the chain comes off; throw its switch
## (Switch, which calls `open`) and it comes off too. Free, ring it (interact,
## or strike it with a hex bolt) and the chasm's bridge lays itself across, plank by plank
## (Bridge), for good. Chained, it only rattles. The level record keeps it freed and rung.

## `lock` for a bell chained to a switch.
const SWITCH_LOCK: int = -1

@onready var player: Player = $"/root/Main/Player"

var map_info: MapInfo
## The number of the chasm it bridges.
var chasm: int = -1
## The padlock's key colour, or SWITCH_LOCK.
var lock: int = SWITCH_LOCK
## Seconds since it was rung (the art swings it), or -1 if it was rung before this visit.
var since_rung: float = -1.0
## Seconds since it rattled in its chain, and since the chain came off (the art).
var since_rattle: float = 99.0
var since_freed: float = 99.0


func setup(info: MapInfo, _v: Vector2i, extra: Variant) -> void:
	map_info = info
	var e: Array = extra if extra is Array else [extra, SWITCH_LOCK]
	chasm = int(e[0])
	lock = int(e[1])


func rung() -> bool:
	return map_info != null and map_info.bridge_up(chasm)


func unchained() -> bool:
	return map_info != null and has_meta(&"cell") and (map_info.bell_free(get_meta(&"cell")) or rung())


## For the map: the padlock's colour, SWITCH_LOCK, or -2 once free.
func lock_state() -> int:
	return -2 if unchained() else lock


func interaction_hint() -> Dictionary:
	if unchained():
		return {}
	return {"switch": true} if lock == SWITCH_LOCK else {"key_color": lock}


## Interact: unlock the padlock with a key if it has one, then ring.
func use() -> void:
	if map_info == null or rung():
		return
	if not unchained():
		if lock >= 0 and (KeyRing.has(player, lock) or KeyRing.spend_skeleton(player)):
			open()
		else:
			rattle()
			return
	ring()


## The chain comes off (its key, or its switch).
func open() -> void:
	if map_info == null or unchained():
		return
	map_info.free_bell(get_meta(&"cell"))
	since_freed = 0.0
	RisoFx.burst(&"hit", global_position + Vector2(30, -110), Vector2.DOWN, [RisoPrint.NIGHT, RisoPrint.BLUE])


func rattle() -> void:
	since_rattle = 0.0
	Wound.shake(3.0, 0.12)


func ring() -> void:
	if map_info == null or rung() or not unchained():
		return
	since_rung = 0.0
	map_info.ring_bell(chasm, get_meta(&"cell"))
	RisoFx.burst(&"gain", global_position + Vector2(0, -90), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
	Wound.shake(6.0, 0.25)


## A hex bolt rings it once it is free (HexBolt strikes everything in the hex_target group);
## chained, it only rattles.
func hex_hit(_damage: int, _dir: Vector2) -> void:
	if unchained():
		ring()
	else:
		rattle()


func _process(delta: float) -> void:
	if since_rung >= 0.0:
		since_rung += delta
	since_rattle += delta
	since_freed += delta
	$Interactable.available = not rung()


func _ready() -> void:
	add_to_group(&"hex_target")
	$Interactable.interacted.connect(use)
