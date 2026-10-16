extends TestKit
## Stills of the institute's timetable (world 28, the institute's first level): the corridor's bell
## and its board, in a period and in passing time; a lecture hall shut and in session; scholars calm
## and turned on the wizard, close up; a trial in a lecture hall with its mock seal; the exam hall's
## glyph seals; a seal of each spell side by side, with the two mock seals; and a lectern giving back
## a spell taught. (The hall's doors shut and open, close up.)
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_timetable.gd

var camera: Camera2D


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	await _go(Vector2i(28, NextWorldDef.first_depth(&"institute")))
	# The level's title card fades first.
	for i: int in range(360):
		await process_frame
	var rec: LevelRecord = info.record()
	var bell: SchoolBell = placed("school_bell.tscn").filter(func(n: Node) -> bool: return (n as SchoolBell).board)[0] as SchoolBell
	player.global_position = bell.global_position + Vector2(-260, 0)
	await _look(bell.global_position + Vector2(0, -70), "timetable_bell.png", 2.2)
	_ring(bell)
	await _look(bell.global_position + Vector2(0, -70), "timetable_bell_passing.png", 2.2)
	# A lecture hall, shut and then in session.
	var hall: int = -1
	for i: int in range(info.world.halls.size()):
		if info.world.halls[i]["kind"] == &"lecture":
			hall = i
			break
	if hall >= 0:
		var box: Rect2i = info.world.halls[hall]["box"]
		var door: Vector2 = info.cell_position(info.world.halls[hall]["doors"][0])
		player.global_position = info.cell_position(info.world.halls[hall]["steps"][0])
		while Timetable.in_session(info.world, hall, rec.period):
			_ring(bell)
			await frames(2)
		await _look(door + Vector2(0, -60), "timetable_door_shut.png", 1.8)
		while not Timetable.in_session(info.world, hall, rec.period):
			_ring(bell)
			await frames(2)
		await _look(door + Vector2(0, -60), "timetable_door_open.png", 1.8)
		await _look(info.cell_position(box.get_center()), "timetable_hall_open.png", 0.95)
		# In: the period begins, and its trial.
		var inside: Rect2i = info.world.halls[hall]["inside"]
		var rise: int = info.world.halls[hall]["rise"]
		var wall: int = inside.position.x if rise > 0 else inside.end.x - 1
		player.global_position = info.cell_position(Vector2i(wall + rise * 5, inside.end.y - 1))
		await frames(10)
		await _look(info.cell_position(box.get_center()), "timetable_trial.png", 0.95)
		await _look(info.cell_position(Vector2i(wall + rise * 2, inside.end.y - 1)) + Vector2(0, -60), "timetable_trial_close.png", 2.0)
		if not info.trial_seals.is_empty():
			info.trial_seals[0].struck(info.trial_spell, info.trial_seals[0].global_position + Vector2(GlyphSeal.HEX_FAR + 20.0, 0), 9.0)
		await frames(30)
		var lecterns: Array[Node] = placed("lectern.tscn").filter(func(n: Node) -> bool: return (n as Lectern).hall == hall)
		if not lecterns.is_empty():
			await _look((lecterns[0] as Node2D).global_position + Vector2(0, -60), "timetable_lectern.png", 2.2)
	# The exam hall's seals.
	var exam: Dictionary = Institute.exam_hall(info.world)
	var seals: Array[Node] = placed("glyph_seal.tscn").filter(func(n: Node) -> bool: return Institute.hall_at(info.world, n.get_meta(&"cell")) == info.world.halls.find(exam))
	if not seals.is_empty():
		var s: Node2D = seals[0] as Node2D
		player.global_position = info.cell_position(info.world.halls[info.world.halls.find(exam)]["steps"][0])
		await _look(s.global_position + Vector2(0, -40), "timetable_exam_seal.png", 1.6)
	await _lineups(bell)
	RunState.delete_save()
	finish()


## Close up on a long floor: students calm and then turned on the wizard; then a seal of each spell
## and the two mock seals.
func _lineups(bell: SchoolBell) -> void:
	var spot: Variant = _long_floor(9)
	if spot == null:
		print("no floor long enough for the line-ups")
		return
	var at: Vector2i = spot
	var rec: LevelRecord = info.record()
	for n: Node in info.map_elements.get_children():
		if (n is Scholar or n is Abomination or n is Coin) and (n as Node2D).global_position.distance_to(info.cell_position(at + Vector2i(4, 0))) < 900.0:
			n.queue_free()
	if not rec.passing:
		_ring(bell)
	var people: Array[Scholar] = []
	var kinds: Array[String] = ["student.tscn", "master.tscn", "student.tscn", "proctor.tscn"]
	for i: int in range(kinds.size()):
		var node: Scholar = (load("res://prefabs/" + kinds[i]) as PackedScene).instantiate() as Scholar
		LevelLoader.arm(node, info.here.depth)
		info.map_elements.add_child(node)
		node.global_position = info.cell_position(at + Vector2i(i + 1, 0))
		node.setup(info, at + Vector2i(i + 1, 0), {"ability": &"hex", "hall": -1})
		people.append(node)
	await physics_frame
	for p: Scholar in people:
		p.set_physics_process(false)
		p.facing = 1.0
		p.calm()
	player.global_position = info.cell_position(at + Vector2i(7, 0))
	await _look(info.cell_position(at + Vector2i(3, 0)) + Vector2(0, -40), "timetable_calm.png", 1.8)
	for p: Scholar in people:
		p.roused = true
	await _look(info.cell_position(at + Vector2i(3, 0)) + Vector2(0, -40), "timetable_roused.png", 1.8)
	for p: Scholar in people:
		p.queue_free()
	await frames(2)
	var row: Array[Node2D] = []
	for i: int in range(Institute.MASTERIES.size()):
		var seal: GlyphSeal = (load("res://prefabs/glyph_seal.tscn") as PackedScene).instantiate() as GlyphSeal
		seal.setup(info, at + Vector2i(i, 0), Institute.MASTERIES[i])
		info.map_elements.add_child(seal)
		seal.global_position = info.cell_position(at + Vector2i(i, 0))
		row.append(seal)
	for k: int in range(2):
		var mock: GlyphSeal = (load("res://prefabs/glyph_seal.tscn") as PackedScene).instantiate() as GlyphSeal
		mock.make_mock(info, Institute.MASTERIES[k * 2], k == 1)
		info.map_elements.add_child(mock)
		mock.global_position = info.cell_position(at + Vector2i(6 + k, -k))
		row.append(mock)
	player.global_position = info.cell_position(at + Vector2i(9, 0))
	await _look(info.cell_position(at + Vector2i(4, 0)) + Vector2(0, -60), "timetable_seals.png", 1.25)


## Ring `bell`, as soon as it can be rung again.
func _ring(bell: SchoolBell) -> void:
	bell.since_rung = SchoolBell.RING_GAP
	bell.ring()


## The first stretch of open floor at least `long` cells long with headroom, out of the halls, as
## its left cell, or null.
func _long_floor(long: int) -> Variant:
	var w: LevelGen = info.world
	for y: int in range(w.size.y):
		for x: int in range(w.size.x):
			var ok: bool = true
			for k: int in range(-1, long + 1):
				var c: Vector2i = Vector2i(x + k, y)
				if not w.is_valid(c) or w.is_ground(c) or not w.is_ground(c + Vector2i.DOWN) or w.is_ground(c + Vector2i.UP) or Institute.hall_at(w, c) >= 0 or not _clear_for_lineup(w.get_cell(c).type) or not _clear_for_lineup(w.get_cell(c + Vector2i.UP).type):
					ok = false
					break
			if ok:
				return Vector2i(x, y)
	return null


## Whether a line-up may stand on a cell holding `type`: open air, a star, or a foe (cleared away
## before the stills), not a ledge, a door or anything stood at.
func _clear_for_lineup(type: LevelGen.Type) -> bool:
	return type == LevelGen.Type.EMPTY or type == LevelGen.Type.COIN or Placeables.has_flag(type, &"enemy")


func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)


## Hold the camera on `at` at `zoom` for a while, then save the still.
func _look(at: Vector2, file: String, zoom: float = 1.0) -> void:
	var was: Vector2 = camera.zoom
	for i: int in range(40):
		camera.global_position = at
		camera.zoom = was * zoom
		camera.reset_smoothing()
		await process_frame
	save_still(file)
	camera.zoom = was
