extends Area2D
class_name Inkwell
## The level's ink well: pay its price to ink the whole level onto your map at once, or keep
## exploring and the map fills in as you go. Once paid, the record keeps the map inked and the
## well dry.

@onready var player: Player = Stage.player()

var map_info: MapInfo


func setup(info: MapInfo, _v: Vector2i) -> void:
	map_info = info


func used() -> bool:
	return map_info == null or bool(map_info.record().mapped)


func price() -> int:
	return Rules.map_price(map_info.coord.y) if map_info != null else 0


func interaction_hint() -> Dictionary:
	return {"text": "map · %d" % price()} if not used() else {}


func buy() -> void:
	if used() or player.coins.coins < price():
		return
	player.collect(-price())
	map_info.ink_whole_map()
	RisoFx.burst(&"gain", global_position + Vector2(0, -30), Vector2.ZERO, [RisoPrint.BLUE, RisoPrint.NIGHT])


func _ready() -> void:
	$Interactable.interacted.connect(buy)


func _process(_delta: float) -> void:
	$Interactable.available = not used()
