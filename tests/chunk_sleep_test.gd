extends TestKit
## Chunk sleeping (LevelLoader.sleep_far_chunks): each placed thing is awake (processing and shown)
## exactly while its chunk is, as the view moves about the level, though a sweep only looks at what
## is awake, what sleeps in a chunk that has just woken, and what was added since: things added
## after the level was built sleep and wake with their chunks too; things freed while asleep are
## passed over; and a thing that no longer keeps its cell is left as it is.
## godot --headless --path . --script res://tests/chunk_sleep_test.gd


func run() -> void:
	await boot(28)
	info.coord = Vector2i(28, NextWorldDef.band_row(&"cemetery", 2))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	var loader: LevelLoader = info.loader
	var near: Vector2 = player.global_position
	var corner: Vector2 = info.cell_position(info.world.size - Vector2i.ONE)
	if corner.distance_to(near) < info.cell_position(Vector2i.ZERO).distance_to(near):
		corner = info.cell_position(Vector2i.ZERO)
	# Away from the wizard too, or the chunks round them stay awake wherever the view is.
	player.global_position = corner
	loader.wake_around(near)
	check_eq(mismatches(), [], "around the start, each thing is awake exactly while its chunk is")
	var asleep: int = info.map_elements.get_children().filter(func(n: Node) -> bool: return n.has_meta(&"cell") and n.process_mode == Node.PROCESS_MODE_DISABLED).size()
	check(asleep > 0, "the far things sleep (%d of %d)" % [asleep, info.map_elements.get_child_count()])
	loader.sleep_far_chunks(true, corner)
	check_eq(mismatches(), [], "with the view in the far corner, the chunks there wake and those at the start sleep")
	var middle: Vector2 = (near + corner) * 0.5
	loader.sleep_far_chunks(true, middle)
	check_eq(mismatches(), [], "and again with it in the middle")

	# Things added after the level was built: one far off sleeps, one in view stays awake.
	var far_thing: Node2D = thing_at(near)
	var near_thing: Node2D = thing_at(middle)
	loader.sleep_far_chunks(true, middle)
	check(far_thing.process_mode == Node.PROCESS_MODE_DISABLED and not far_thing.visible, "a thing added far off sleeps")
	check(near_thing.process_mode == Node.PROCESS_MODE_INHERIT and near_thing.visible, "a thing added in view stays awake")
	loader.sleep_far_chunks(true, near)
	check(far_thing.process_mode == Node.PROCESS_MODE_INHERIT and far_thing.visible, "and wakes with its chunk")
	check_eq(mismatches(), [], "everything still follows its chunk")

	# Things freed while asleep are passed over when their chunk wakes.
	var doomed: Array[Node2D] = []
	for k: int in range(5):
		doomed.append(thing_at(near + Vector2(k * 40.0, 0)))
	loader.sleep_far_chunks(true, corner)
	var slept: bool = doomed.all(func(n: Node2D) -> bool: return n.process_mode == Node.PROCESS_MODE_DISABLED)
	for n: Node2D in doomed:
		n.free()
	loader.sleep_far_chunks(true, near)
	check(slept and mismatches().is_empty(), "things freed while asleep are passed over when their chunk wakes")

	# A thing kept awake by taking its cell away (as tests do) is left alone.
	loader.sleep_far_chunks(true, corner)
	far_thing.remove_meta(&"cell")
	far_thing.process_mode = Node.PROCESS_MODE_INHERIT
	loader.sleep_far_chunks(true, corner)
	check(far_thing.process_mode == Node.PROCESS_MODE_INHERIT, "a thing that no longer keeps its cell is left as it is")
	finish()


## A plain thing placed with the level at `at`, added now.
func thing_at(at: Vector2) -> Node2D:
	var node: Node2D = Node2D.new()
	node.set_meta(&"cell", info.cell_at(at))
	info.map_elements.add_child(node)
	node.global_position = at
	return node


## The placed things whose waking does not follow their chunk (as a sweep over every one of them
## would decide it), by name; things that wake from afar or spread over several chunks aside.
func mismatches() -> Array[String]:
	var out: Array[String] = []
	for n: Node in info.map_elements.get_children():
		var n2: Node2D = n as Node2D
		if n2 == null or not n.has_meta(&"cell") or n.is_queued_for_deletion() or n is Worm or n is Wind or n is Gondola:
			continue
		var awake: bool = bool(info.loader._chunk_awake.get(info.loader.chunk_of(n2.global_position), false))
		var is_awake: bool = n.process_mode == Node.PROCESS_MODE_INHERIT
		if awake != is_awake or (not awake and n2.visible):
			out.append(String(n.name))
	return out
