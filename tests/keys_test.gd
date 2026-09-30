extends SceneTree
## Phase 3 of docs/DEEPER_PLAN.md: keys are not used up, the player carries one, grabbing
## another leaves the carried key where the new one was, and keys open doors in any level.
## godot --headless --path . --script res://tests/keys_test.gd

var main: Node
var info: MapInfo
var player: Player
var failed: bool = false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)


func settle(frames: int = 4) -> void:
	await process_frame
	var deadline: int = Time.get_ticks_msec() + 30000
	while (info.world == null or info.travelling) and Time.get_ticks_msec() < deadline:
		await process_frame
	for i: int in range(frames):
		await physics_frame
		await process_frame


func placed(scene: String) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() == scene and not node.is_queued_for_deletion() and (node.get_node_or_null("Sprite2D") == null or node.get_node("Sprite2D").visible):
			found.append(node)
	return found


func colored(scene: String, color: int) -> Array[Node]:
	return placed(scene).filter(func(n: Node) -> bool: return int(n.get_meta(&"key_color", -1)) == color)


func dropped() -> Array[Node]:
	return placed("key.tscn").filter(func(n: Node) -> bool: return n.has_meta(&"dropped_id"))


func carried() -> int:
	return int(player.get_meta(&"carried_key", -1))


func run() -> void:
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	await process_frame
	await process_frame
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	player = main.get_node("Player") as Player
	await settle()
	player.set_physics_process(false)

	print("a key is not used up")
	var first: Node2D = colored("key.tscn", 0)[0] as Node2D
	first.call("touch", player)
	check(carried() == 0, "carrying the colour-0 key")
	var door: Node = colored("door.tscn", 0)[0]
	door.get_node("Unlock").call("try_open")
	await settle(1)
	check(not is_instance_valid(door) or door.is_queued_for_deletion(), "it opens a colour-0 door")
	check(carried() == 0, "and is still carried")
	var second_door: Array[Node] = colored("door.tscn", 0)
	if not second_door.is_empty():
		second_door[0].get_node("Unlock").call("try_open")
		await settle(1)
		check(colored("door.tscn", 0).size() == 0, "and every other colour-0 door too")

	print("grabbing another key leaves the carried one")
	var next: Node2D = colored("key.tscn", 1)[0] as Node2D
	var swap_at: Vector2 = next.position
	# Walk onto it for real: the physics overlap picks it up.
	player.global_position = next.global_position
	await settle(6)
	check(carried() == 1, "now carrying the colour-1 key")
	check(dropped().size() == 1 and int(dropped()[0].get_meta(&"key_color")) == 0, "the colour-0 key is left behind")
	check((dropped()[0] as Node2D).position == swap_at, "exactly where the new one was")
	check(not bool(dropped()[0].get("armed")) and carried() == 1, "standing on it does not grab it back")
	player.global_position += Vector2(0, -600)
	await settle(3)
	check(bool(dropped()[0].get("armed")), "it arms once the player steps off")

	print("revisits keep keys where they were left")
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
	info.travel(MapInfo.Exit.LEFT)
	await settle()
	player.set_physics_process(false)
	check(dropped().size() == 1 and (dropped()[0] as Node2D).position == swap_at and int(dropped()[0].get_meta(&"key_color")) == 0, "the left key is still there")
	check(colored("key.tscn", 1).filter(func(n: Node) -> bool: return not n.has_meta(&"dropped_id")).is_empty() or (colored("key.tscn", 1)[0] as Node2D).position != swap_at, "the grabbed key is still gone")
	await settle(3)
	dropped()[0].call("touch", player)
	await settle(2)
	check(carried() == 0, "grabbing the left key back")
	check(dropped().size() == 1 and int(dropped()[0].get_meta(&"key_color")) == 1, "leaves the colour-1 key in its place")
	check(info.dropped_keys().size() == 1, "the record holds just that one")

	print("keys work in any level")
	var opened: bool = false
	for step: int in range(6):
		info.travel(MapInfo.Exit.RIGHT)
		await settle()
		player.set_physics_process(false)
		var doors: Array[Node] = colored("door.tscn", 0)
		if doors.is_empty():
			continue
		var cell: Vector2i = doors[0].get_meta(&"cell")
		doors[0].get_node("Unlock").call("try_open")
		await settle(1)
		opened = (info.record()["opened"] as Dictionary).has(cell)
		print("  opened a door in ", MapInfo.where(info.coord))
		break
	check(opened and carried() == 0, "the key from world 28 opens a door elsewhere and stays carried")

	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASS: deeper phase 3")
		quit()
