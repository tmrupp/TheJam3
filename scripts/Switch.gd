extends Area2D
class_name Switch
## A switch: interact with it, or hit it with a hex bolt, and it throws for good, lifting its gate
## (SwitchGate) or starting its parked lift (MovingPlatform). The level record keeps it thrown.

@onready var player: Player = Stage.player()

var map_info: MapInfo
## The cell of the gate it opens or the lift it starts.
var gate_cell: Vector2i = Vector2i(-1, -1)


func setup(info: MapInfo, _v: Vector2i, gate: Vector2i) -> void:
	map_info = info
	gate_cell = gate


func thrown() -> bool:
	return map_info != null and has_meta(&"cell") and map_info.record().switched.has(get_meta(&"cell"))


func flip() -> void:
	if map_info == null or thrown():
		return
	map_info.record().switched[get_meta(&"cell")] = true
	if is_instance_valid(map_info.map_elements):
		for node: Node in map_info.map_elements.get_children():
			if node.get_meta(&"cell", null) != gate_cell:
				continue
			if node is SwitchGate:
				(node as SwitchGate).open()
			elif node is MovingPlatform:
				(node as MovingPlatform).run()
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
