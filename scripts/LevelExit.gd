extends Area2D
## One of a level's four exits. Deeper leads to (seed, depth + 1) and costs stars once;
## back leads to (seed, depth - 1); left and right lead to the neighbouring seeds and are locked
## with a key colour dealt by the level seed (the key is kept, and the door stays open).

@onready var player: Player = $"/root/Main/Player"

var map_info: MapInfo
var exit: int = MapInfo.Exit.DEEPER

func setup(info: MapInfo, _v: Vector2i, which: int) -> void:
	map_info = info
	exit = which

## Stars still owed before this exit opens (only the deeper exit ever costs anything).
func price() -> int:
	if map_info == null or exit != MapInfo.Exit.DEEPER or bool(map_info.record()["deeper_paid"]):
		return 0
	return MapInfo.deeper_price(map_info.coord.y)

## The key colour this exit still needs, or -1 when it is open (only left and right lock).
func lock() -> int:
	if map_info == null or not (exit == MapInfo.Exit.LEFT or exit == MapInfo.Exit.RIGHT):
		return -1
	if (map_info.record()["lateral_open"] as Dictionary).has(exit):
		return -1
	return MapInfo.lateral_lock(map_info.coord, exit)

func interacted() -> void:
	if map_info == null or map_info.travelling:
		return
	var needs: int = lock()
	if needs >= 0:
		if int(player.get_meta(&"carried_key", -1)) != needs:
			return
		map_info.record()["lateral_open"][exit] = true
	var owed: int = price()
	if owed > 0:
		if player.coins.coins < owed:
			return
		player.collect(-owed)
		map_info.record()["deeper_paid"] = true
	map_info.travel(exit)

func _ready() -> void:
	$Interactable.interacted.connect(interacted)
