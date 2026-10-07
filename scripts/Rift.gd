extends Node
class_name Rift
## Rift, a spell: press Spell to open a teleporter where you stand; press it again somewhere else
## to open its partner, and the two are linked (interact with one to step out of the other).
## - tier I: only while standing on something. Each world keeps its own pair in its level record;
##   a third cast closes both old ends and starts a new pair in this world.
## - tier II: also in mid air.
## - tier III: the pair is the run's one cross-world link (MapInfo.rift_link): its two ends may be
##   in different levels, and using one travels to the other's level. A third cast closes both
##   old ends, wherever they are, and starts a new link. Per-world pairs made at lower tiers stay.

const PORTAL: PackedScene = preload("res://prefabs/portal.tscn")

var level: int = 1
var ends: Array[Portal] = []

@onready var player: Player = get_parent() as Player


## Open a rift at the wizard. Returns it, or null when it can't be opened here.
## Its tier (Abilities): II opens in midair; III links two levels.
func set_tier(n: int) -> void:
	level = n
	sync_ends()


## The Spell button, with rift in the slot: open an end. Whether it opened (stars are paid only then).
func cast_spell() -> bool:
	return cast() != null


func cast() -> Portal:
	var info: MapInfo = MapInfo.instance
	if player == null or info == null or info.travelling or info.map_elements == null or not is_instance_valid(info.map_elements):
		return null
	if level < 2 and not player.is_on_floor():
		return null
	# Standing, the rift opens at its cell's middle, the height a level's own teleporters stand at;
	# in mid air, where the wizard is.
	var at: Vector2 = player.global_position
	if player.is_on_floor():
		at.y = info.tile_map.to_global(info.tile_map.map_to_local(info.cell_at(player.global_position))).y
	var rift: Portal = _cast_link(info, at) if level >= 3 else _cast_pair(info, at)
	info.save_run()
	RisoFx.burst(&"gain", rift.global_position, Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
	if RisoPrint.instance != null:
		RisoPrint.instance.flare(&"rift")
	return rift


## Tiers I and II: this world's pair.
func _cast_pair(info: MapInfo, at: Vector2) -> Portal:
	sync_ends()
	if ends.size() >= 2:
		for end: Portal in ends:
			end.unlink()
			end.queue_free()
		ends.clear()
	var rift: Portal = _spawn_end(info, at)
	ends.append(rift)
	if ends.size() == 2:
		ends[0].link(ends[1])
		ends[1].link(ends[0])
	var positions: Array[Vector2] = []
	for end: Portal in ends:
		positions.append(end.global_position)
	info.record().rifts = positions
	return rift


## Tier III: the run's cross-world link.
func _cast_link(info: MapInfo, at: Vector2) -> Portal:
	if info.run.rift_link.size() >= 2:
		info.run.rift_link.clear()
		for end: Portal in link_ends(info):
			end.unlink()
			end.queue_free()
	info.run.rift_link.append([info.coord, at])
	var rift: Portal = _spawn_end(info, at)
	rift.set_meta(&"rift_link", info.run.rift_link.size() - 1)
	_wire_link(info)
	return rift


## Link the cross-world ends present in this level: to each other when both are here, else to
## the far end's level and position.
static func _wire_link(info: MapInfo) -> void:
	var here: Array[Portal] = link_ends(info)
	if info.run.rift_link.size() < 2:
		return
	for end: Portal in here:
		var i: int = int(end.get_meta(&"rift_link"))
		var other: Array = info.run.rift_link[1 - i]
		if other[0] == info.coord:
			for mate: Portal in here:
				if mate != end:
					end.link(mate)
		else:
			end.link_far(other[0], other[1])


## Adopt only this world's own pair (not the cross-world link's ends).
func sync_ends() -> void:
	ends = current_ends(MapInfo.instance)


static func current_ends(info: MapInfo) -> Array[Portal]:
	var out: Array[Portal] = []
	if info != null and is_instance_valid(info.map_elements):
		for node: Node in info.map_elements.get_children():
			if node.has_meta(&"rift") and not node.has_meta(&"rift_link") and not node.is_queued_for_deletion():
				out.append(node as Portal)
	return out


## The cross-world link's ends in this level.
static func link_ends(info: MapInfo) -> Array[Portal]:
	var out: Array[Portal] = []
	if info != null and is_instance_valid(info.map_elements):
		for node: Node in info.map_elements.get_children():
			if node.has_meta(&"rift_link") and not node.is_queued_for_deletion():
				out.append(node as Portal)
	return out


static func _spawn_end(info: MapInfo, at: Vector2) -> Portal:
	var end: Portal = PORTAL.instantiate()
	end.set_meta(&"rift", true)
	info.map_elements.add_child(end)
	end.global_position = at
	return end


## This world's pair from its record, and any cross-world link ends that are in this level.
static func restore(info: MapInfo) -> void:
	var positions: Array = info.record().rifts
	var restored: Array[Portal] = []
	for at: Vector2 in positions.slice(0, 2):
		restored.append(_spawn_end(info, at))
	if restored.size() == 2:
		restored[0].link(restored[1])
		restored[1].link(restored[0])
	for i: int in range(info.run.rift_link.size()):
		var entry: Array = info.run.rift_link[i]
		if entry[0] == info.coord:
			var end: Portal = _spawn_end(info, entry[1])
			end.set_meta(&"rift_link", i)
	_wire_link(info)
	if info.player != null and info.player.has_node("Rift"):
		(info.player.get_node("Rift") as Rift).sync_ends()


func _exit_tree() -> void:
	# The pair belongs to the world, rather than to the currently equipped spell.
	ends.clear()
