extends Area2D
## A switch: interact with it, or hit it with a hex bolt, and it throws, lifting its gate
## (SwitchGate) for good. The level record keeps it thrown, and the gate open.

@onready var player: Player = $"/root/Main/Player"

var map_info: MapInfo
## The cell of the gate it opens.
var gate_cell: Vector2i = Vector2i(-1, -1)


func setup(info: MapInfo, _v: Vector2i, gate: Vector2i) -> void:
	map_info = info
	gate_cell = gate


func thrown() -> bool:
	return map_info != null and has_meta(&"cell") and (map_info.record().get("switched", {}) as Dictionary).has(get_meta(&"cell"))


func flip() -> void:
	if map_info == null or thrown():
		return
	var switched: Dictionary = map_info.record().get("switched", {})
	switched[get_meta(&"cell")] = true
	map_info.record()["switched"] = switched
	if is_instance_valid(map_info.map_elements):
		for node: Node in map_info.map_elements.get_children():
			if node.has_meta(&"cell") and node.get_meta(&"cell") == gate_cell and node.has_method("open"):
				node.call("open")
	map_info.save_run()
	RisoFx.burst(&"gain", global_position + Vector2(0, -30), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])


## A hex bolt throws it too (HexBolt strikes everything in the hex_target group).
func hex_hit(_damage: int, _dir: Vector2) -> void:
	flip()


func _process(_delta: float) -> void:
	$Interactable.available = not thrown()


func _ready() -> void:
	add_to_group(&"hex_target")
	$Interactable.interacted.connect(flip)
