extends TestKit
## Phase 3 of docs/DEEPER_PLAN.md: keys are not used up, the player carries one, grabbing
## another leaves the carried key where the new one was, and keys open doors in any level.
## godot --headless --path . --script res://tests/keys_test.gd

func dropped() -> Array[Node]:
	return placed("key.tscn").filter(func(n: Node) -> bool: return n.has_meta(&"dropped_id"))


func carried() -> int:
	return player.keyring.newest()


func run() -> void:
	await boot(28)
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
	check(info.record().dropped.size() == 1, "the record holds just that one")

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
		opened = (info.record().opened as Dictionary).has(cell)
		print("  opened a door in ", Rules.where(info.coord))
		break
	check(opened and carried() == 0, "the key from world 28 opens a door elsewhere and stays carried")

	print("side doors are locked with a key colour")
	info.start_run(28)
	await settle()
	player.set_physics_process(false)
	var right: Node = placed("level_exit.tscn").filter(func(n: Node) -> bool: return int(n.get("exit")) == MapInfo.Exit.RIGHT)[0]
	var needs: int = Rules.lateral_lock(Vector2i(28, 0), MapInfo.Exit.RIGHT)
	check(int(right.call("lock")) == needs, "world 28's right door needs key colour %d" % needs)
	player.keyring.set_all([(needs + 1) % Rules.KEY_COLOR_COUNT])
	right.call("interacted")
	await process_frame
	check(info.coord == Vector2i(28, 0) and not info.travelling, "the wrong key does not open it")
	player.keyring.set_all([])
	right.call("interacted")
	await process_frame
	check(info.coord == Vector2i(28, 0) and not info.travelling, "nor does no key")
	player.keyring.set_all([needs])
	right.call("interacted")
	await settle()
	player.set_physics_process(false)
	check(info.coord == Vector2i(29, 0) and carried() == needs, "the right key opens it, and is kept")
	var left: Node = placed("level_exit.tscn").filter(func(n: Node) -> bool: return int(n.get("exit")) == MapInfo.Exit.LEFT)[0]
	check(int(left.call("lock")) == -1, "the door just come through is open behind the player")
	player.keyring.set_all([])
	left.call("interacted")
	await settle()
	check(info.coord == Vector2i(28, 0), "so the way back needs no key")
	right = placed("level_exit.tscn").filter(func(n: Node) -> bool: return int(n.get("exit")) == MapInfo.Exit.RIGHT)[0]
	check(int(right.call("lock")) == -1, "and the opened door stays open")
	var colours: Dictionary = {}
	for x: int in range(0, 200):
		var c: int = Rules.lateral_lock(Vector2i(x, 0), MapInfo.Exit.RIGHT)
		colours[c] = int(colours.get(c, 0)) + 1
	check(colours.size() == Rules.KEY_COLOR_COUNT, "lock colours vary from world to world")
	check(int(colours.get(0, 0)) > int(colours.get(1, 0)) and int(colours.get(1, 0)) > int(colours.get(3, 0)), "common colours lock side doors more often than rare ones (%s)" % colours)

	finish("deeper phase 3")
