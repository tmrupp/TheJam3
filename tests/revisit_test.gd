extends TestKit
## A level looks the same on every visit, down to where each floating pickup (star, key, moon)
## sits in its cell and where each lift is along its track. A level's layout is kept and reused
## once built, so none of this may be drawn from its RNG as it loads: it is hashed from the level
## seed and the cell (LevelLoader.place_cell, MovingPlatform.setup).
## godot --headless --path . --script res://tests/revisit_test.gd

## The prefabs of the pickups that float anywhere in their cell.
const PICKUPS: Array[String] = ["coin.tscn", "key.tscn", "moon.tscn"]
## A world whose first level has lifts as well as pickups.
const WORLD: int = 99


func run() -> void:
	await boot(WORLD)
	player.set_physics_process(false)
	var first: Dictionary = _looks()
	var lifts: int = (first.keys() as Array).filter(func(k: Variant) -> bool: return (k as String).begins_with("lift")).size()
	check(first.size() - lifts > 10 and lifts > 0, "the level has pickups to compare (%d, and %d lifts)" % [first.size() - lifts, lifts])
	var built: LevelGen = info.world
	# Load the same level again: its kept layout is reused, as on coming back to it.
	info.arrival = -2
	info._load_level()
	await settle()
	check(info.world == built, "the level's kept layout was reused")
	var again: Dictionary = _looks()
	check_eq(again.size(), first.size(), "the same pickups and lifts on the second visit")
	var moved: Array[String] = []
	for k: String in first:
		if not again.has(k) or (again[k] as Vector2).distance_to(first[k] as Vector2) > 0.01:
			moved.append(k)
	check(moved.is_empty(), "each where it was before%s" % ("" if moved.is_empty() else " (moved: %s)" % ", ".join(moved.slice(0, 4))))
	var spread: Dictionary = {}
	for k: String in first:
		spread[snappedf((first[k] as Vector2).x, 0.1)] = true
	check(spread.size() > 5, "pickups do not all sit at the same place in their cells")
	RunState.delete_save()
	finish()


## Each floating pickup's offset from its cell's centre and each lift's phase, by kind and cell.
func _looks() -> Dictionary:
	var out: Dictionary = {}
	for node: Node in info.map_elements.get_children():
		if node.is_queued_for_deletion() or not node.has_meta(&"cell"):
			continue
		var cell: Vector2i = node.get_meta(&"cell")
		var scene: String = node.scene_file_path.get_file()
		if scene in PICKUPS:
			out["%s %s" % [scene, cell]] = (node as Node2D).position - info.cell_position(cell)
		elif scene == "moving_platform.tscn":
			out["lift %s" % cell] = Vector2(float(node.get("phase")), 0.0)
	return out
