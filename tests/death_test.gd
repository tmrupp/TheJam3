extends SceneTree
## Lanterns protect one death each; burned lanterns stay spent across levels and saves.
## Ghosts and stars cannot restore protection. An unprotected death ends the run.
## godot --headless --path . --script res://tests/death_test.gd

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


func ghosts() -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() == "corpse.tscn" and not node.is_queued_for_deletion():
			found.append(node)
	return found


func coins() -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() == "coin.tscn" and not node.is_queued_for_deletion():
			found.append(node)
	return found

func lanterns() -> Array[Node]:
	return info.map_elements.get_children().filter(func(n: Node) -> bool: return n is Checkpoint)


func run() -> void:
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://test_run.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	await process_frame
	await process_frame
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	player = main.get_node("Player") as Player
	await settle()
	player.set_physics_process(false)
	var start_coord: Vector2i = info.coord
	var start_cell: Vector2i = info.respawn_cell
	var start_lantern: Node = lanterns().filter(info.is_respawn_lantern)[0]
	check(not info.vulnerable and not info.is_lantern_spent(start_lantern), "the start lantern protects one death")

	print("first death")
	player.collect(5)
	player.position += Vector2(300, 0)
	var died_at: Vector2 = player.position
	player.die()
	# Checked at once: once respawned, the wizard may pick up a star by the lantern.
	check(player.coins.coins == 0, "the player carries none")
	await settle()
	player.set_physics_process(false)
	check(info.vulnerable, "death consumes the lantern's protection")
	check(info.has_ghost and info.ghost_stars == 5 and info.ghost_coord == Vector2i(28, 0), "the ghost holds all 5 stars")
	check(ghosts().size() == 1 and (ghosts()[0] as Node2D).position == died_at, "the ghost stands where they died")
	start_lantern = lanterns().filter(func(n: Node) -> bool: return n.get_meta(&"cell") == start_cell)[0]
	check(info.is_lantern_spent(start_lantern) and not info.is_respawn_lantern(start_lantern), "the used lantern is spent and dark")
	check(not bool(start_lantern.get_node("Interactable").get("available")), "spent lanterns do not offer an interaction prompt")
	check(player.global_position.distance_to(info.respawn_marker.global_position) < 80.0, "respawned at the lantern that absorbed the death")
	start_lantern.call("interacted")
	check(info.vulnerable and info.is_lantern_spent(start_lantern), "the same lantern cannot be relit for a free life")

	print("fresh stars")
	for i: int in range(8):
		coins()[0].call("touch", player)
	check(info.vulnerable, "collecting fresh stars does not restore protection")
	check(info.has_ghost and ghosts().size() == 1, "and the ghost is still waiting")

	print("the ghost belongs to its level")
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
	check(ghosts().is_empty(), "no ghost at (29, 0)")
	info.travel(MapInfo.Exit.LEFT)
	await settle()
	player.set_physics_process(false)
	check(ghosts().size() == 1, "the ghost is back at (28, 0)")
	start_lantern = lanterns().filter(func(n: Node) -> bool: return n.get_meta(&"cell") == start_cell)[0]
	check(info.is_lantern_spent(start_lantern) and not info.light_lantern(start_lantern), "revisiting does not renew a spent lantern")

	print("recovering the ghost")
	ghosts()[0].set("armed", true)
	ghosts()[0].call("touch", player)
	await settle(1)
	check(player.coins.coins == 13 and info.vulnerable and not info.has_ghost, "the ghost returns its stars but leaves the lantern spent")
	check(ghosts().is_empty(), "the ghost is gone")
	await process_frame
	check(main.get_node("RisoHud").get("lantern_lit") == false, "the HUD still shows how to restore protection after ghost recovery")

	print("spent lantern saves")
	info.save_run()
	check(info.continue_run(), "the unprotected run can be continued")
	await settle()
	player.set_physics_process(false)
	start_lantern = lanterns().filter(func(n: Node) -> bool: return n.get_meta(&"cell") == start_cell)[0]
	check(info.vulnerable and info.is_lantern_spent(start_lantern) and not info.light_lantern(start_lantern), "save/reload preserves the spent lantern")
	var legacy: Dictionary = MapInfo.read_save()
	(legacy["records"][start_coord] as Dictionary).erase("spent_lanterns")
	legacy["fresh_stars"] = 1
	legacy["recover_need"] = 4
	var legacy_file: FileAccess = FileAccess.open(MapInfo.save_path, FileAccess.WRITE)
	legacy_file.store_var(legacy)
	legacy_file.close()
	check(info.continue_run(), "an older recovery-system save still loads")
	await settle()
	player.set_physics_process(false)
	check(info.vulnerable and (info.record()["spent_lanterns"] as Dictionary).has(start_cell), "old unprotected saves migrate their respawn lantern to spent")

	print("another lantern")
	var fresh: Node = lanterns().filter(func(n: Node) -> bool: return not info.is_lantern_spent(n))[0]
	fresh.call("interacted")
	check(not info.vulnerable and info.is_respawn_lantern(fresh), "lighting a different lantern restores protection and moves respawn")
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
	player.set_physics_process(false)
	var other_coord: Vector2i = info.coord
	var other: Node = lanterns()[0]
	var other_cell: Vector2i = other.get_meta(&"cell")
	other.call("interacted")
	info.travel(MapInfo.Exit.LEFT)
	await settle()
	player.set_physics_process(false)
	var carried: int = player.coins.coins
	player.die()
	await settle()
	player.set_physics_process(false)
	other = lanterns().filter(func(n: Node) -> bool: return n.get_meta(&"cell") == other_cell)[0]
	check(info.coord == other_coord and info.vulnerable and info.is_lantern_spent(other), "death in another world burns the lit respawn lantern and returns there")
	check(info.has_ghost and info.ghost_coord == start_coord and info.ghost_stars == carried, "its ghost stays in the world where the player died")
	info.travel(MapInfo.Exit.LEFT)
	await settle()
	player.set_physics_process(false)
	fresh = lanterns().filter(func(n: Node) -> bool: return not info.is_lantern_spent(n))[0]
	fresh.call("interacted")
	check(not info.vulnerable and info.has_ghost, "a different lantern protects another death without needing the ghost")
	player.global_position = (fresh as Node2D).global_position
	player.collect(3)
	player.die()
	await settle(8)
	player.set_physics_process(false)
	check(info.vulnerable and info.ghost_stars == 3 and ghosts().size() == 1, "the next protected death replaces the old ghost with the new dropped stars")
	check(not bool(ghosts()[0].get("armed")), "a ghost on the respawn lantern waits for the player to step off")

	print("the run ends")
	player.set_meta(&"carried_key", 1)
	player.die()
	await process_frame
	check(info.run_ending > 0.0, "dying without a lit lantern ends the run")
	check(MapInfo.read_save().is_empty(), "quitting during the end card cannot resurrect the ended run")
	var deadline: int = Time.get_ticks_msec() + 10000
	while info.run_ending > 0.0 and Time.get_ticks_msec() < deadline:
		await process_frame
	await settle()
	check(info.coord == Vector2i(28, 0), "a new run starts at (28, 0)")
	check(player.coins.coins == 0 and not player.has_meta(&"carried_key"), "with no stars and no key")
	check(not info.vulnerable and not info.has_ghost and ghosts().is_empty(), "no ghost, not vulnerable")
	check(lanterns().any(info.is_respawn_lantern) and not info.record().has("spent_lanterns"), "the new run starts with a fresh lit lantern")
	check(coins().size() > 0 and info.records.size() == 1, "and fresh level records")
	check(player.visible and player.is_physics_processing(), "the wizard is back in play")

	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASS: deeper phase 2")
		quit()
