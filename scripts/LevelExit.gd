extends Area2D
## One of a level's four exits. Deeper leads to (seed, depth + 1) and costs stars once;
## back leads to (seed, depth - 1); left and right lead to the neighbouring seeds.

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

func interacted() -> void:
	if map_info == null or map_info.travelling:
		return
	var owed: int = price()
	if owed > 0:
		if player.coins.coins < owed:
			return
		player.collect(-owed)
		map_info.record()["deeper_paid"] = true
	map_info.travel(exit)

func _ready() -> void:
	$Interactable.interacted.connect(interacted)
