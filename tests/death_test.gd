extends SceneTree
## Phase 2 of docs/DEEPER_PLAN.md: dying drops every star into a ghost and leaves the player
## vulnerable; the ghost or enough fresh stars end that; dying while vulnerable ends the run.
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

	print("first death")
	player.collect(5)
	player.position += Vector2(300, 0)
	var died_at: Vector2 = player.position
	player.die()
	await settle()
	check(info.vulnerable, "dying leaves the player vulnerable")
	check(info.has_ghost and info.ghost_stars == 5 and info.ghost_coord == Vector2i(28, 0), "the ghost holds all 5 stars")
	check(player.coins.coins == 0, "the player carries none")
	check(ghosts().size() == 1 and (ghosts()[0] as Node2D).position == died_at, "the ghost stands where they died")
	check(info.recover_need == MapInfo.recover_price(0), "fresh stars needed: %d" % info.recover_need)
	check(player.global_position.distance_to(info.respawn_marker.global_position) < 80.0, "respawned at the lit lantern")

	print("fresh stars")
	for i: int in range(info.recover_need):
		coins()[0].call("touch", player)
	check(not info.vulnerable, "enough fresh stars end the vulnerable state")
	check(info.has_ghost and ghosts().size() == 1, "and the ghost is still waiting")

	print("second death replaces the ghost")
	var carried: int = player.coins.coins
	player.die()
	await settle(8)
	check(info.vulnerable and info.ghost_stars == carried, "the new ghost holds the %d fresh stars" % carried)
	check(ghosts().size() == 1, "the old ghost and its 5 stars are gone")
	check(info.has_ghost and not bool(ghosts()[0].get("armed")), "dying on the lantern: the ghost waits until the player steps off")

	print("the ghost belongs to its level")
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
	check(ghosts().is_empty(), "no ghost at (29, 0)")
	info.travel(MapInfo.Exit.LEFT)
	await settle()
	check(ghosts().size() == 1, "the ghost is back at (28, 0)")

	print("recovering the ghost")
	ghosts()[0].set("armed", true)
	ghosts()[0].call("touch", player)
	await settle(1)
	check(player.coins.coins == carried and not info.vulnerable and not info.has_ghost, "the ghost's stars return and the state clears")
	check(ghosts().is_empty(), "the ghost is gone")

	print("the run ends")
	player.collect(3)
	coins()[0].call("touch", player)
	info.travel(MapInfo.Exit.DEEPER)
	await settle()
	player.die()
	await settle()
	player.set_meta(&"carried_key", 1)
	player.die()
	await process_frame
	check(info.run_ending > 0.0, "dying while vulnerable ends the run")
	var deadline: int = Time.get_ticks_msec() + 10000
	while info.run_ending > 0.0 and Time.get_ticks_msec() < deadline:
		await process_frame
	await settle()
	check(info.coord == Vector2i(28, 0), "a new run starts at (28, 0)")
	check(player.coins.coins == 0 and not player.has_meta(&"carried_key"), "with no stars and no key")
	check(not info.vulnerable and not info.has_ghost and ghosts().is_empty(), "no ghost, not vulnerable")
	check(coins().size() > 0 and info.records.size() == 1, "and fresh level records")
	check(player.visible and player.is_physics_processing(), "the wizard is back in play")

	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASS: deeper phase 2")
		quit()
