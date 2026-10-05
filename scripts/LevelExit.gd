extends Area2D
## One of a place's exits. Where it leads and what it costs are up to the place's definition
## (MapInfo.here, see NextWorldDef.lead and price): in a level, the deeper exit costs stars once,
## a side world's door its entry price once, and left and right are locked with a key colour dealt
## by the level seed (the key is kept, and the door stays open; a skeleton key opens it too, and is
## used up).

@onready var player: Player = $"/root/Main/Player"

var map_info: MapInfo
var exit: int = MapInfo.Exit.DEEPER

func setup(info: MapInfo, _v: Vector2i, which: int) -> void:
	map_info = info
	exit = which

## Stars still owed before this exit opens.
func price() -> int:
	if map_info == null:
		return 0
	return map_info.here.price(exit, map_info.record())

## The key colour this exit still needs, or -1 when it is open (only left and right lock).
func lock() -> int:
	if map_info == null or not (exit == MapInfo.Exit.LEFT or exit == MapInfo.Exit.RIGHT):
		return -1
	if (map_info.record()["lateral_open"] as Dictionary).has(exit):
		return -1
	return MapInfo.lateral_lock(map_info.coord, exit)

func interaction_hint() -> Dictionary:
	var needs: int = lock()
	return {"key_color": needs} if needs >= 0 else {}

func interacted() -> void:
	if map_info == null or map_info.travelling:
		return
	var needs: int = lock()
	if needs >= 0:
		# A key of its colour, else a skeleton key (used up), opens it for good.
		if not KeyRing.has(player, needs) and not KeyRing.spend_skeleton(player):
			return
		map_info.record()["lateral_open"][exit] = true
	var owed: int = price()
	if owed > 0:
		if player.coins.coins < owed:
			return
		player.collect(-owed)
		map_info.here.pay(exit, map_info.record())
	map_info.travel(exit)

func _ready() -> void:
	$Interactable.interacted.connect(interacted)
