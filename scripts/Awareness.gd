extends Node
class_name Awareness
## Awareness, a spell: press Spell to sense the level for a while. Pointers at the edge of the
## view (RisoHud) show where things are, like the ghost's arrow:
## - tier I: the exits
## - tier II: also the ink well and the shrine
## - tier III: also the nearest key of each colour
## Each tier also senses for longer. A short cooldown between pings.

const COOLDOWN: float = 3.0
## Seconds a ping senses for at tier I, and more for each tier after.
const SENSE_TIME: float = 5.0
const SENSE_PER_TIER: float = 2.5

var level: int = 1
## Seconds of sensing left (0 when not sensing).
var sensing: float = 0.0
var cooldown: float = 0.0

@onready var player: Player = get_parent() as Player


## Its tier (Abilities): what it senses, and for how long.
func set_tier(n: int) -> void:
	level = n


## The Spell button, with awareness in the slot: sense the level.
func cast_spell() -> bool:
	ping()
	return true


## Ready unless in the short cooldown after sensing: 0..1 as it runs out (the spell orb shows it).
func readiness() -> float:
	if not active() and cooldown > 0.0:
		return 1.0 - clampf(cooldown / COOLDOWN, 0.0, 1.0)
	return 1.0


## While sensing: (the fraction of its time left, seconds left); x < 0 when not.
func running() -> Vector2:
	if not active():
		return Vector2(-1.0, 0.0)
	return Vector2(clampf(sensing / sense_time(), 0.0, 1.0), sensing)


## How long a ping senses for, at its tier.
func sense_time() -> float:
	return SENSE_TIME + SENSE_PER_TIER * float(level - 1)


func ping() -> void:
	if cooldown > 0.0:
		return
	sensing = sense_time()
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
		var type: int = Placeables.type_of(node)
		var kind: StringName = &""
		if type == LevelGen.Type.EXIT:
			kind = &"exit"
		elif level >= 2 and type == LevelGen.Type.INKWELL and not (node as Inkwell).used():
			kind = &"inkwell"
		elif level >= 2 and type == LevelGen.Type.SHRINE and not (node as Shrine).used():
			kind = &"shrine"
		elif level >= 3 and type == LevelGen.Type.KEY:
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
