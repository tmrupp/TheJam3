extends SceneTree
## Things you stand at to use them (exits, the shrine, lanterns, the ink well, relics, bells,
## switches, teleporters) always keep something under them: where the rock under one is broken, a
## ledge appears in its place (MapInfo.prop_up), at once and again whenever the level loads.
## godot --headless --path . --script res://tests/floor_test.gd

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


func ledges_at(c: Vector2i) -> int:
	var n: int = 0
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() == "platform.tscn" and node.has_meta(&"prop") and node.get_meta(&"cell") == c and not node.is_queued_for_deletion():
			n += 1
	return n


func run() -> void:
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://floor_test.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	await process_frame
	await process_frame
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	player = main.get_node("Player") as Player
	await settle()
	player.set_physics_process(false)

	var w: MapInfo.World = info.world
	var under_lantern: Variant = null
	var under_shrine: Variant = null
	var bare: Variant = null
	for v: Vector2i in w.objects:
		if w.get_cell(v).type == MapInfo.Type.CHECKPOINT and w.is_ground(v + Vector2i.DOWN) and under_lantern == null:
			under_lantern = v + Vector2i.DOWN
		if w.get_cell(v).type == MapInfo.Type.SHRINE:
			under_shrine = v + Vector2i(1, 1)
	for v: Vector2i in w.grounds:
		if w.is_valid(v + Vector2i.UP) and w.get_cell(v + Vector2i.UP).type == MapInfo.Type.EMPTY:
			bare = v
			break
	check(under_lantern != null and under_shrine != null and bare != null, "a lantern and the shrine on rock, and bare floor")

	print("breaking rock")
	var rock: Node = Node.new()
	rock.set_meta(&"cell", under_lantern)
	info.mark_broken(rock)
	check(ledges_at(under_lantern) == 1, "rock broken under a lantern: a ledge in its place")
	rock.set_meta(&"cell", under_shrine)
	info.mark_broken(rock)
	check(ledges_at(under_shrine) == 1, "under the shrine's mending side too")
	rock.set_meta(&"cell", bare)
	info.mark_broken(rock)
	check(ledges_at(bare) == 0, "bare floor gets none")
	info.mark_broken(rock)
	rock.set_meta(&"cell", under_lantern)
	info.mark_broken(rock)
	check(ledges_at(under_lantern) == 1, "and never two")
	rock.free()

	print("loading the level again")
	info._load_level()
	await settle()
	check(ledges_at(under_lantern) == 1 and ledges_at(under_shrine) == 1 and ledges_at(bare) == 0, "the ledges are back with the level")

	MapInfo.delete_save()
	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASS: floors under things you stand at")
		quit()
