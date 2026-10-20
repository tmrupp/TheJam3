extends TestKit
## Stills of the institute's timetable (world 28, the institute's first level): the great bell and
## its cord, floor to ceiling, at rest and ringing; the period marks on its yoke, in a period and in
## passing time; a
## classroom shut, then in session but shut to a wizard without its prerequisite (the paper it
## wants beside its plate), then open to them carrying it, wide and with the class in; scholars calm
## and turned on the wizard, close up; a classroom's lectern holding a paper left on it;
## exam papers lying on a floor, a stolen one among them; the library's timetable board and its
## desk ready to teach in class time; the way on in its classroom, with the paper
## it takes hung beside it; and an instructor teaching ferry turned on the wizard on its raft, its
## class with it, and the stolen top-tier paper it leaves once felled. (The hall's doors shut and
## open, close up.)
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_timetable.gd

var camera: Camera2D


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	await _go(Vector2i(28, NextWorldDef.first_depth(&"institute")))
	# The level's title card fades first.
	for i: int in range(540):
		await process_frame
	var rec: LevelRecord = info.record()
	var bell: SchoolBell = placed("school_bell.tscn").filter(func(n: Node) -> bool: return (n as SchoolBell).great)[0] as SchoolBell
	player.global_position = bell.global_position + Vector2(-260, 0)
	# The great bell and its cord, floor to ceiling, then its yoke's period marks close up; then rung.
	var tall: float = float(bell.reach) * 128.0 * 0.5
	var yoke: Vector2 = bell.global_position + Vector2(0, 64.0 - tall * 2.0 + 50.0)
	await _look(bell.global_position + Vector2(0, 64.0 - tall), "timetable_great_bell.png", clampf(560.0 / (tall * 2.0), 0.7, 1.4))
	await _look(yoke, "timetable_bell.png", 2.2)
	_ring(bell)
	await _look(bell.global_position + Vector2(0, 64.0 - tall), "timetable_great_bell_ringing.png", clampf(560.0 / (tall * 2.0), 0.7, 1.4), 18)
	# Rung last, its cord hangs dim until another is rung.
	await _look(bell.global_position + Vector2(0, -60), "timetable_cord_spent.png", 1.6, 60)
	await _look(yoke, "timetable_bell_passing.png", 2.2)
	# A classroom of a department with a break in its day (botany's), shut and then in session.
	var hall: int = -1
	for i: int in range(info.world.halls.size()):
		if info.world.halls[i]["kind"] == &"lecture" and info.world.halls[i]["dept"] == &"botany":
			hall = i
			break
	if hall >= 0:
		var box: Rect2i = info.world.halls[hall]["box"]
		var door: Vector2 = info.cell_position(info.world.halls[hall]["doors"][0])
		player.global_position = info.cell_position(info.world.halls[hall]["steps"][0])
		while Timetable.in_session(info.world, hall, rec.rings):
			_ring(bell)
			await frames(2)
		await _look(door + Vector2(0, -60), "timetable_door_shut.png", 1.8)
		# In session at tier III, asking for a necrology II paper the wizard lacks: shut to them, the
		# department it wants by its plate.
		for k: int in range(Timetable.PERIODS * 2):
			if Timetable.in_session(info.world, hall, rec.rings):
				break
			_ring(bell)
			await frames(2)
		rec.dept_tiers[&"botany"] = 3
		var need: Array = Timetable.needs(&"botany", info.tier_of(hall))
		for b: StringName in Timetable.LADDERS[need[0]]:
			Abilities.set_tier(player, b, 0)
		await frames(20)
		await _look(door + Vector2(0, -90), "timetable_door_prereq.png", 2.2)
		# Carrying a paper of that department, enrolled: the doors open.
		var key: int = KeyRing.paper(Timetable.LADDERS[need[0]][0], need[1])
		player.keyring.take(key)
		await frames(30)
		await _look(door + Vector2(0, -60), "timetable_door_open.png", 1.8)
		await _look(info.cell_position(box.get_center()), "timetable_hall_open.png", 1.1)
		# In: the period begins.
		var inside: Rect2i = info.world.halls[hall]["inside"]
		var front: int = info.world.halls[hall]["front"]
		var wall: int = inside.position.x if front > 0 else inside.end.x - 1
		player.global_position = info.cell_position(Vector2i(wall + front * 6, inside.end.y - 1))
		await frames(10)
		await _look(info.cell_position(box.get_center()), "timetable_class.png", 1.1)
		# A pigeonhole: the paper left on the classroom's lectern.
		var lecterns: Array[Node] = placed("lectern.tscn").filter(func(n: Node) -> bool: return (n as Lectern).hall == hall)
		if not lecterns.is_empty() and key != 0:
			var lectern: Lectern = lecterns[0] as Lectern
			lectern.take()
			await frames(4)
			await _look(lectern.global_position + Vector2(0, -90), "timetable_lectern_paper.png", 2.0)
			lectern.take()
		for code: int in player.keyring.papers():
			player.keyring.spend(code)
	# Exam papers lying on a floor, of a few subjects and tiers, the last stolen.
	var lie: Variant = _long_floor(5)
	if lie != null:
		var at: Vector2i = lie
		var codes: Array[int] = [KeyRing.paper(&"hex", 1), KeyRing.paper(&"warp", 2), KeyRing.paper(&"nova", 4), KeyRing.stolen(KeyRing.paper(&"seeker", 3))]
		for k: int in range(codes.size()):
			var pos: Vector2 = info.cell_position(at + Vector2i(k + 1, 0))
			info._spawn_dropped_key(info.record().drop_key(pos, codes[k]), pos, codes[k])
		player.global_position = info.cell_position(at + Vector2i(5, 0))
		await _look(info.cell_position(at + Vector2i(2, 0)) + Vector2(0, -40), "timetable_papers.png", 2.0)
	# The library: its timetable board, and its desk ready to teach a paper in class time.
	var boards: Array[Node] = placed("timetable_board.tscn")
	var desks: Array[Node] = placed("study_desk.tscn")
	if not boards.is_empty() and not desks.is_empty():
		var board: Node2D = boards[0] as Node2D
		player.keyring.take(KeyRing.paper(&"seeker", 2))
		player.global_position = (desks[0] as Node2D).global_position + Vector2(-90, 0)
		await frames(4)
		_ring(bell)
		if info.record().passing:
			info.record().last_bell = Vector2i(-1, -1)
			info.since_bell = SchoolBell.RING_GAP
			bell.ring()
		player.global_position = (desks[0] as Node2D).global_position + Vector2(-90, 0)
		await frames(20)
		await _look(board.global_position + Vector2(0, -240), "timetable_library.png", 0.95, 60)
		player.keyring.clear()
		player.global_position = bell.global_position
		await frames(2)
		_ring(bell)
		await frames(2)
	# The way on in its classroom, with the paper it takes hung beside it.
	var way: int = Timetable.way_on_hall(info.world)
	if way >= 0:
		var exit_at: Vector2 = info.cell_position(info.world.exits[MapInfo.Exit.DEEPER])
		info.class_hall = way
		player.global_position = exit_at + Vector2(-200, 0)
		await frames(10)
		await _look(exit_at + Vector2(30, -60), "timetable_way_on.png", 1.8)
		player.global_position = bell.global_position
		await frames(2)
	# An instructor teaching ferry, turned on the wizard with its whole class; then felled, the paper
	# it leaves (stolen).
	var room: int = -1
	for k: int in range(Timetable.PERIODS * 3):
		for i: int in range(info.world.halls.size()):
			if info.subject_of(i) == &"ferry" and info.master_in(i) != null:
				room = i
		if room >= 0:
			break
		_ring(bell)
		await frames(2)
	if room >= 0:
		Abilities.set_tier(player, &"levitate", 1)
		var inside: Rect2i = info.world.halls[room]["inside"]
		var box: Rect2i = info.world.halls[room]["box"]
		player.global_position = info.cell_position(Vector2i(inside.position.x + 1, inside.end.y - 1))
		player.phasing = true
		var m: Scholar = info.master_in(room)
		m.rouse()
		await frames(50)
		await _look(info.cell_position(box.get_center()) + Vector2(0, 40), "timetable_instructor.png", 1.1)
		var at: Vector2 = m.global_position
		m.wizard_blow = true
		(m.get_node("Wound") as Wound).hit(999, Vector2.UP)
		await frames(30)
		await _look(at + Vector2(0, -60), "timetable_prize.png", 2.0)
		player.phasing = false
		Abilities.set_tier(player, &"levitate", 0)
	await _lineups(bell)
	RunState.delete_save()
	finish()


## Close up on a long floor: students calm and then turned on the wizard.
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


## Ring `bell`, as soon as it can be rung again.
func _ring(bell: SchoolBell) -> void:
	# A period rung round: class time in (in passing time) and out again.
	for k: int in range(2 if info.record().passing else 1):
		info.record().last_bell = Vector2i(-1, -1)
		info.since_bell = SchoolBell.RING_GAP
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
func _look(at: Vector2, file: String, zoom: float = 1.0, hold: int = 40) -> void:
	var was: Vector2 = camera.zoom
	for i: int in range(hold):
		camera.global_position = at
		camera.zoom = was * zoom
		camera.reset_smoothing()
		await process_frame
	save_still(file)
	camera.zoom = was
