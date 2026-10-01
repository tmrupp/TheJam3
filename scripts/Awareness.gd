extends Node
class_name Awareness
## Awareness, a spell: press Spell to sense the level for a while. Pointers at the edge of the
## view (RisoHud) show where things are, like the ghost's arrow:
## - tier I: the exits
## - tier II: also the ink well and the shrine
## - tier III: also the nearest key of each colour
## Each tier also senses for longer. A short cooldown between pings.

const COOLDOWN: float = 3.0

var level: int = 1
## Seconds of sensing left (0 when not sensing).
var sensing: float = 0.0
var cooldown: float = 0.0

@onready var player: Player = get_parent() as Player


func ping() -> void:
	if cooldown > 0.0:
		return
	sensing = 5.0 + 2.5 * float(level - 1)
	cooldown = sensing + COOLDOWN
	player.visual_event.emit(&"awareness", player.global_position)
	if RisoPrint.instance != null:
		RisoPrint.instance.flare(&"awareness")


func active() -> bool:
	return sensing > 0.0


## What awareness senses in the level: [{kind, at (world), color}].
func targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var info: MapInfo = MapInfo.instance
	if info == null or info.map_elements == null or not is_instance_valid(info.map_elements):
		return out
	var nearest_key: Dictionary = {}
	for node: Node in info.map_elements.get_children():
		if not (node is Node2D) or node.is_queued_for_deletion():
			continue
		var file: String = node.scene_file_path.get_file()
		var kind: StringName = &""
		if file == "level_exit.tscn":
			kind = &"exit"
		elif level >= 2 and file == "inkwell.tscn" and not bool(node.call("used")):
			kind = &"inkwell"
		elif level >= 2 and file == "shrine.tscn" and not bool(node.call("used")):
			kind = &"shrine"
		elif level >= 3 and file == "key.tscn":
			var sprite: CanvasItem = node.get_node_or_null("Sprite2D") as CanvasItem
			if sprite == null or sprite.visible:
				var color: int = int(node.get_meta(&"key_color", 0))
				var d: float = (node as Node2D).global_position.distance_squared_to(player.global_position)
				if not nearest_key.has(color) or d < float(nearest_key[color][0]):
					nearest_key[color] = [d, node]
			continue
		if kind != &"":
			out.append({"kind": kind, "at": (node as Node2D).global_position, "node": node})
	for color: int in nearest_key:
		var key: Node2D = nearest_key[color][1]
		out.append({"kind": &"key", "at": key.global_position, "node": key})
	return out


func _physics_process(delta: float) -> void:
	sensing = maxf(0.0, sensing - delta)
	cooldown = maxf(0.0, cooldown - delta)
