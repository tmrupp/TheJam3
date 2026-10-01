extends SceneTree
## Phase 5 of docs/DEEPER_PLAN.md: start modes, background pre-generation of neighbouring
## levels, and saving and continuing a run. Uses its own save file.
## godot --headless --path . --script res://tests/interface_test.gd

var main: Node
var info: MapInfo
var player: Player
var menu: Node
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


func boot() -> void:
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	menu = main.get_node("Menu")
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	await process_frame


func placed(scene: String) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() == scene and not node.is_queued_for_deletion():
			found.append(node)
	return found


func run() -> void:
	MapInfo.save_path = "user://test_interface.save"
	MapInfo.delete_save()

	print("start menu")
	await boot()
	check(not menu.continue_button.visible, "no save: no Continue")
	menu.world_seed.text = ""
	menu.start_game()
	player = main.get_node("Player") as Player
	await settle()
	var rolled: int = int(menu.world_seed.text)
	check(menu.world_seed.text.is_valid_int() and info.coord == Vector2i(rolled, 0), "a blank world starts at a random world (%d)" % rolled)
	check(menu.start.text == "Resume" and menu.copy.visible and not menu.continue_button.visible, "the menu becomes the pause menu")
	menu.pause_resume_game()
	await process_frame
	check(menu.visible and paused and menu.where.text == MapInfo.where(info.coord), "pausing shows where you are")
	menu.pause_resume_game()
	await process_frame
	check(not menu.visible and not paused, "and resumes")

	print("pre-generation")
	var s: int = info.coord.x
	var neighbours: Array[Vector2i] = [Vector2i(s, 1), Vector2i(s + 1, 0), Vector2i(s - 1, 0)]
	var deadline: int = Time.get_ticks_msec() + 60000
	while neighbours.any(func(c: Vector2i) -> bool: return not info.cache.has(c)) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(neighbours.all(func(c: Vector2i) -> bool: return info.cache.has(c)), "deeper, left and right are generated in the background")
	while info.gen_busy:
		await process_frame
	var fresh: Array = info.wfc.generate_level(MapInfo.def_for(Vector2i(s + 1, 0)))
	check(fresh == info.cache[Vector2i(s + 1, 0)], "a cached level is exactly the level generated fresh")
	var frames: int = 0
	info.travel(MapInfo.Exit.RIGHT)
	# The printed transition covers the view first; caching should make the rest instant.
	var sheet: RisoTransition = RisoTransition.instance
	while sheet != null and sheet.state == RisoTransition.State.COVERING:
		await process_frame
	while info.travelling and frames < 600:
		await process_frame
		frames += 1
	check(info.coord == Vector2i(s + 1, 0) and frames <= 3, "once the sheet covers the view, the cached level is up in %d frame(s)" % frames)
	var held: int = 0
	while sheet != null and sheet.state == RisoTransition.State.COVERED and held < 120:
		await process_frame
		held += 1
	check(sheet != null and sheet.state == RisoTransition.State.REVEALING and held > 5, "then holds to show where you are, and sweeps away")
	info.travel(MapInfo.Exit.LEFT)
	await settle()

	print("saving")
	player.set_physics_process(false)
	var coin: Node = placed("coin.tscn")[0]
	var coin_cell: Vector2i = coin.get_meta(&"cell")
	coin.call("touch", player)
	var lantern: Node = placed("checkpoint.tscn")[1]
	lantern.call("interacted")
	var lantern_cell: Vector2i = lantern.get_meta(&"cell")
	Abilities.grant(player, &"double_jump")
	player.collect(9)
	player.die()
	await settle()
	player.collect(7)
	player.set_meta(&"carried_key", 2)
	player.health.health = 2
	menu.pause_resume_game()
	await process_frame
	menu.pause_resume_game()
	var saved: Dictionary = MapInfo.read_save()
	check(not saved.is_empty() and int(saved["run_seed"]) == s, "pausing saved the run")
	var ghost_stars: int = info.ghost_stars
	main.queue_free()
	await process_frame
	await process_frame

	print("continuing")
	await boot()
	check(menu.continue_button.visible and menu.where.text.contains(MapInfo.where(Vector2i(s, 0))), "Continue is offered, naming the saved level")
	menu.continue_game()
	player = main.get_node("Player") as Player
	await settle()
	check(info.coord == Vector2i(s, 0) and player.global_position.distance_to(info.cell_position(lantern_cell)) < 80.0, "resumes at the last lit lantern")
	check(player.coins.coins == 7 and int(player.get_meta(&"carried_key", -1)) == 2 and player.health.health == 2, "with its stars, key and health")
	check(Abilities.tier(player, &"double_jump") == 1 and player.MAX_JUMPS == 2, "and its abilities")
	check(info.vulnerable and info.has_ghost and info.ghost_stars == ghost_stars and placed("corpse.tscn").size() == 1, "and its ghost, still vulnerable")
	check(not placed("coin.tscn").any(func(n: Node) -> bool: return n.get_meta(&"cell") == coin_cell), "and its level records")
	check(info.run_seed == s, "on the same world")

	print("debug runs")
	main.queue_free()
	await process_frame
	await process_frame
	MapInfo.delete_save()
	await boot()
	menu.call("set_debug", true)
	menu.world_seed.text = "28"
	menu.start_game()
	player = main.get_node("Player") as Player
	await settle()
	check(player.coins.coins == MapInfo.DEBUG_STARS, "a debug run starts with %d stars" % MapInfo.DEBUG_STARS)
	var back: Vector2i = info.world.exits[MapInfo.Exit.BACK]
	var spread: int = 0
	for which: int in info.world.exits:
		var e: Vector2i = info.world.exits[which]
		spread = maxi(spread, absi(e.x - back.x) + absi(e.y - back.y))
	check(spread <= 10, "every exit is within %d cells of the spawn" % spread)
	check(bool(MapInfo.read_save().get("debug", false)), "the save remembers it is a debug run")
	info.travel(MapInfo.Exit.DEEPER)
	await settle()
	var arrive: Vector2i = info.world.exits[MapInfo.Exit.BACK]
	check(info.world.exits.values().all(func(e: Vector2i) -> bool: return absi(e.x - arrive.x) + absi(e.y - arrive.y) <= 10), "and so in every level")
	MapInfo.debug = false

	MapInfo.delete_save()
	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASS: deeper phase 5")
		quit()
