extends StaticBody2D
class_name TollGate
## A toll gate: a portcullis across a gondola's station (CragsArchetype.shut_stations), lifted for
## good by paying its price in stars, from either side (from the landing, or from the car standing
## at the station: its Pay area, TollPay, reaches both). The level record keeps it open.

var map_info: MapInfo
## Stars to lift it (Rules.toll_price).
var price: int = 0


func setup(info: MapInfo, _v: Vector2i, cost: Variant) -> void:
	map_info = info
	price = int(cost)


## Pay and lift it, if the wizard has the stars.
func pay() -> void:
	var player: Player = Stage.player()
	if player == null or is_queued_for_deletion():
		return
	if player.coins.coins < price:
		RisoFx.burst(&"hit", global_position + Vector2(0, -40), Vector2.UP, [RisoPrint.PINK, RisoPrint.NIGHT])
		return
	player.collect(-price)
	RisoPrint.door_opened(self)
	if map_info != null:
		map_info.mark_opened(self)
		map_info.save_run()
	queue_free()


func _ready() -> void:
	# The printed portcullis carries no lock: its price shows on it instead (GateArt).
	set_meta(&"key_color", -1)
