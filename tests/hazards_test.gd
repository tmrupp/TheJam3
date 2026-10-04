extends SceneTree
## Hoppers (from depth 1: they crouch and leap at the wizard, and a hex wounds them) and lasers
## (in hyperspace only: set in rock, firing on a cadence a beam that stops at the first wall,
## hurting only while it fires).
## godot --headless --path . --script res://tests/hazards_test.gd

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


func settle(frames: int = 6) -> void:
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
		if node.scene_file_path.get_file() == scene and not node.is_queued_for_deletion():
			found.append(node)
	return found


func count(w: MapInfo.World, type: int) -> int:
	var n: int = 0
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			if int(w.get_cell(Vector2i(x, y)).type) == type:
				n += 1
	return n


func run() -> void:
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://hazards_test.save"
	await process_frame
	var wfc: Node = main.get_node("WaveFunctionCollapse")

	print("generation")
	var shallow: MapInfo.NextWorldDef = MapInfo.def_for(Vector2i(28, 0))
	var deep: MapInfo.NextWorldDef = MapInfo.def_for(Vector2i(28, 2))
	var w0: MapInfo.World = MapInfo.World.new(wfc.call("generate_level", shallow), shallow)
	var w2: MapInfo.World = MapInfo.World.new(wfc.call("generate_level", deep), deep)
	check(count(w0, MapInfo.Type.HOPPER) == 0 and count(w2, MapInfo.Type.HOPPER) >= 2, "no hoppers at depth 0, %d at depth 2" % count(w2, MapInfo.Type.HOPPER))
	check(count(w0, MapInfo.Type.LASER) == 0 and count(w2, MapInfo.Type.LASER) == 0, "no lasers in ordinary levels")
	var lasers_ok: bool = true
	for world_seed: int in [1, 7, 28, 99]:
		var def: MapInfo.NextWorldDef = MapInfo.def_for(MapInfo.chasm_coord(Vector2i(world_seed, 3)))
		var w: MapInfo.World = MapInfo.World.new(wfc.call("generate_level", def), def)
		var n: int = count(w, MapInfo.Type.LASER)
		lasers_ok = lasers_ok and n >= 3
		for x: int in range(w.size.x):
			for y: int in range(w.size.y):
				var cell: MapInfo.Cell = w.get_cell(Vector2i(x, y))
				if cell.type == MapInfo.Type.LASER:
					var d: Vector2i = cell.extra_info
					lasers_ok = lasers_ok and w.is_ground(Vector2i(x, y) - d)
	check(lasers_ok, "every hyperspace has at least 3 lasers, each set in rock")

	print("the hopper")
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	player = main.get_node("Player") as Player
	await settle()
	info.travel(MapInfo.Exit.DEEPER)
	await settle()
	info.travel(MapInfo.Exit.DEEPER)
	await settle(30)
	var hoppers: Array[Node] = placed("hopper_enemy.tscn")
	check(hoppers.size() >= 2 and hoppers.all(func(h: Node) -> bool: return h.has_node("Wound") and h.is_in_group(&"hex_target")), "%d hoppers in the level, each one woundable" % hoppers.size())
	# A hopper with open floor-level air beside it, and the wizard held there.
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var hopper: RigidBody2D = null
	var aim: Vector2 = Vector2.ZERO
	for h: Node in hoppers:
		for side: float in [1.0, -1.0]:
			var from: Vector2 = (h as Node2D).global_position
			var to: Vector2 = from + Vector2(side * 320.0, -8.0)
			if space.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, 4)).is_empty():
				hopper = h as RigidBody2D
				aim = to
				break
		if hopper != null:
			break
	check(hopper != null, "a hopper with room beside it")
	if hopper != null:
		player.set_physics_process(false)
		player.invulnerable.enable()
		player.global_position = aim
		var hop: Node = hopper.get_node("Hopper")
		hop.set("rest", 0.0)
		var start: Vector2 = hopper.global_position
		var crouched: bool = false
		var leapt: bool = false
		var closest: float = absf(start.x - aim.x)
		# It may wake asleep at its cell's centre and settle (and rest) before it notices.
		for i: int in range(200):
			await physics_frame
			crouched = crouched or float(hop.get("crouch")) >= 0.0
			leapt = leapt or hopper.global_position.y < start.y - 40.0
			closest = minf(closest, absf(hopper.global_position.x - aim.x))
		check(crouched and leapt, "it crouches, then leaps")
		check(closest < absf(start.x - aim.x) - 100.0, "toward the wizard (%d px closer)" % int(absf(start.x - aim.x) - closest))
		(hopper.get_node("Stunner") as Stunner).stun(3.0)
		await physics_frame
		check(bool(hop.get("stunned")) and float(hop.get("crouch")) < 0.0, "a stun stops it")

	print("lasers")
	var plunge_seed: int = -1
	for world_seed: int in range(1, 120):
		if MapInfo.level_seed(MapInfo.def_for(Vector2i(world_seed, 1)).gen_seed, 777) % 100 < MapInfo.PLUNGE_CHANCE:
			plunge_seed = world_seed
			break
	menu.world_seed.text = str(plunge_seed)
	menu.start_game()
	await settle()
	info.travel(MapInfo.Exit.DEEPER)
	await settle()
	info.record()["plunge_paid"] = true
	info.travel(MapInfo.Exit.PLUNGE)
	await settle(10)
	player.set_physics_process(false)
	var lasers: Array[Node] = placed("laser.tscn")
	check(lasers.size() >= 3, "%d lasers in hyperspace" % lasers.size())
	if not lasers.is_empty():
		var laser: Node2D = lasers[0] as Node2D
		var dir: Vector2 = laser.get("dir")
		var beam: Area2D = laser.get_node("Beam") as Area2D
		var reach: float = float(laser.get("reach"))
		var end: Vector2 = beam.global_position + dir * (reach + 8.0)
		check(reach > 200.0 and info.world.is_ground(info.cell_at(end)), "its beam reaches %d px, to the first rock" % int(reach))
		var shape: CollisionShape2D = beam.get_node("CollisionShape2D") as CollisionShape2D
		var fired: int = 0
		var rested: int = 0
		var live: int = 0
		var was_hot: bool = false
		for i: int in range(int(60.0 * 3.4)):
			await physics_frame
			var hot: bool = bool(laser.call("firing"))
			if hot and was_hot:
				fired += 1
				live += 0 if shape.disabled else 1
			elif not hot and not was_hot:
				rested += 1
				live -= 0 if shape.disabled else 1
			was_hot = hot
		check(fired > 10 and rested > 10 and live == fired, "it fires on a cadence, the beam live only while it fires")
		# Into the beam while it fires.
		var hurt: Array[bool] = [false]
		player.visual_event.connect(func(kind: StringName, _at: Vector2) -> void: hurt[0] = hurt[0] or kind == &"hurt")
		while not bool(laser.call("firing")):
			await physics_frame
		player.invulnerable.end()
		player.global_position = beam.global_position + dir * minf(reach * 0.5, 200.0)
		for i: int in range(6):
			await physics_frame
		check(hurt[0], "the beam hurts")
	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASSED")
		quit()
