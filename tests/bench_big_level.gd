extends SceneTree
## Frame cost on a big level: travels deeper to DEPTH, settles, then times frames with the whole
## game running and with each printed system switched off in turn, to find what scales badly.
## godot --path . --windowed --resolution 1280x720 --script res://tests/bench_big_level.gd

const DEPTH: int = 8
const FRAMES: int = 120


func _initialize() -> void:
	call_deferred("run")


func measure(label: String) -> float:
	for i: int in range(20):
		await process_frame
	var t0: int = Time.get_ticks_usec()
	var proc: float = 0.0
	var phys: float = 0.0
	for i: int in range(FRAMES):
		await process_frame
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / float(FRAMES)
	print("BENCH %-28s frame %6.2f ms  process %6.2f ms  physics %6.2f ms  draws %d  objects %d" % [label, ms, proc / FRAMES * 1000.0, phys / FRAMES * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.OBJECT_COUNT))])
	return ms


func run() -> void:
	root.size = Vector2i(1280, 720)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://bench.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	for i: int in range(5):
		await process_frame
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	await measure("depth 0 %s" % info.world.size)
	while info.coord.y < DEPTH:
		info.travel(MapInfo.Exit.DEEPER)
		await process_frame
		while info.world == null or info.travelling:
			await process_frame
	var riso: RisoPrint = RisoPrint.instance
	var base: float = await measure("depth %d %s all on" % [DEPTH, info.world.size])
	for part: String in ["terrain", "decor"]:
		var node: Node = riso.get(part)
		if node == null:
			continue
		var was: Node.ProcessMode = node.process_mode
		(node as CanvasItem).visible = false
		node.process_mode = Node.PROCESS_MODE_DISABLED
		var ms: float = await measure("without " + part)
		print("BENCH   %s costs %.2f ms" % [part, base - ms])
		(node as CanvasItem).visible = true
		node.process_mode = was
	# Props by kind: how many, and what each kind costs.
	var kinds: Dictionary = {}
	for a: Node in get_nodes_in_group(&"riso_art"):
		if a.name == "RisoArt":
			var k: StringName = a.get("kind")
			if not kinds.has(k):
				kinds[k] = []
			(kinds[k] as Array).append(a)
	for k: StringName in kinds:
		var list: Array = kinds[k]
		if list.size() < 8:
			continue
		for a: Node in list:
			a.process_mode = Node.PROCESS_MODE_DISABLED
		var mk: float = await measure("without %s art (%d)" % [k, list.size()])
		print("BENCH   %s art costs %.2f ms" % [k, base - mk])
		for a: Node in list:
			a.process_mode = Node.PROCESS_MODE_INHERIT
	# Props (every dressed prefab's ink art).
	var arts: Array[Node] = get_nodes_in_group(&"riso_art").filter(func(n: Node) -> bool: return n.name == "RisoArt")
	for a: Node in arts:
		a.process_mode = Node.PROCESS_MODE_DISABLED
	var ms_props: float = await measure("without prop art (%d)" % arts.size())
	print("BENCH   prop art costs %.2f ms" % (base - ms_props))
	for a: Node in arts:
		a.process_mode = Node.PROCESS_MODE_INHERIT
	# Game objects (enemies, pickups) paused.
	info.map_elements.process_mode = Node.PROCESS_MODE_DISABLED
	var ms_game: float = await measure("without level objects")
	print("BENCH   level objects cost %.2f ms" % (base - ms_game))
	info.map_elements.process_mode = Node.PROCESS_MODE_INHERIT
	quit()
