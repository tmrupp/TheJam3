extends Node
class_name Rift
## Rift, a spell: press Spell to open a teleporter where you stand; press it again somewhere else
## to open its partner, and the two are linked (interact with one to step out of the other). A
## third cast closes both old ends and starts a new pair in this world. Each world keeps its
## own pair in its level record, so visiting or recasting elsewhere leaves that pair intact.
## - tier I: only while standing on something
## - tier II: also in mid air
## - tier III: stepping into a rift takes you through, no interact needed

const PORTAL: PackedScene = preload("res://prefabs/portal.tscn")

var level: int = 1
var ends: Array[Node2D] = []

@onready var player: Player = get_parent() as Player


## Open a rift at the wizard. Returns it, or null when it can't be opened here.
func cast() -> Node2D:
	var info: MapInfo = MapInfo.instance
	if player == null or info == null or info.travelling or info.map_elements == null or not is_instance_valid(info.map_elements):
		return null
	if level < 2 and not player.is_on_floor():
		return null
	sync_ends()
	if ends.size() >= 2:
		for end: Node2D in ends:
			end.call("unlink")
			end.queue_free()
		ends.clear()
	# Standing, the rift opens at its cell's middle, the height a level's own teleporters stand at;
	# in mid air (tier II), where the wizard is.
	var at: Vector2 = player.global_position
	if player.is_on_floor():
		at.y = info.tile_map.to_global(info.tile_map.map_to_local(info.cell_at(player.global_position))).y
	var rift: Node2D = _spawn_end(info, at, level, true)
	ends.append(rift)
	if ends.size() == 2:
		ends[0].call("link", ends[1])
		ends[1].call("link", ends[0])
	var positions: Array[Vector2] = []
	for end: Node2D in ends:
		positions.append(end.global_position)
	info.record()["rifts"] = positions
	info.record()["rift_tier"] = level
	info.save_run()
	RisoFx.burst(&"gain", rift.global_position, Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
	if RisoPrint.instance != null:
		RisoPrint.instance.flare(&"rift")
	return rift


## Adopt only this world's placed ends, including a pair restored after a revisit.
func sync_ends() -> void:
	ends = current_ends(MapInfo.instance)


static func current_ends(info: MapInfo) -> Array[Node2D]:
	var out: Array[Node2D] = []
	if info != null and is_instance_valid(info.map_elements):
		for node: Node in info.map_elements.get_children():
			if node.has_meta(&"rift") and not node.is_queued_for_deletion():
				out.append(node as Node2D)
	return out


static func _spawn_end(info: MapInfo, at: Vector2, tier: int, resting: bool) -> Node2D:
	var end: Node2D = PORTAL.instantiate()
	end.set_meta(&"rift", true)
	end.set("resting", resting)
	end.set("auto", tier >= 3)
	info.map_elements.add_child(end)
	end.global_position = at
	return end


## Positions live in MapInfo's per-world records, which are also saved with the run.
static func restore(info: MapInfo) -> void:
	var positions: Array = info.record().get("rifts", [])
	var tier: int = int(info.record().get("rift_tier", 1))
	if info.player != null:
		tier = maxi(tier, Abilities.tier(info.player, &"rift"))
	var restored: Array[Node2D] = []
	for at: Vector2 in positions.slice(0, 2):
		restored.append(_spawn_end(info, at, tier, false))
	if restored.size() == 2:
		restored[0].call("link", restored[1])
		restored[1].call("link", restored[0])
	if info.player != null and info.player.has_node("Rift"):
		(info.player.get_node("Rift") as Rift).sync_ends()


func _exit_tree() -> void:
	# The pair belongs to the world, rather than to the currently equipped spell.
	ends.clear()
