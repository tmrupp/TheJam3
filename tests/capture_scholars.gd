extends TestKit
## Stills of the institute's four people (ScholarArt), side by side on a floor of its first level
## (world 28): a student, a master, a proctor and a librarian, as the game shows them and close
## up; then close up walking, winding up (the proctor shielding), scattering or turned on the
## wizard, and stunned.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_scholars.gd

## Px between one figure and the next, and how much closer the close stills are.
const APART: float = 170.0
const CLOSE: float = 2.3

var camera: Camera2D
var people: Array[Scholar] = []


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	await go(Vector2i(28, NextWorldDef.first_depth(&"institute")))
	player.get_node("CameraControl").set_process(false)
	var spot: Variant = _long_floor(7)
	if spot == null:
		print("no floor long enough for the line-up")
		finish()
		return
	var at: Vector2i = spot
	# Where the level's librarian stands, among its library's bookcases, for the last still.
	var library: Variant = null
	for n: Node in get_nodes_in_group(&"scholar"):
		if (n as Scholar).kind == &"librarian" and library == null:
			library = (n as Scholar).global_position
		n.queue_free()
	var kinds: Array = [["student.tscn", &""], ["master.tscn", &"hex"], ["proctor.tscn", &""], ["librarian.tscn", &""]]
	for i: int in range(kinds.size()):
		var node: Scholar = (load("res://prefabs/" + String(kinds[i][0])) as PackedScene).instantiate() as Scholar
		var cell: Vector2i = at + Vector2i(1, 0)
		LevelLoader.arm(node, info.here.depth)
		info.map_elements.add_child(node)
		node.global_position = info.cell_position(cell) + Vector2(float(i) * APART, 0)
		node.setup(info, cell, {"ability": kinds[i][1], "hall": -1})
		people.append(node)
	await until(func() -> bool: return people.all(func(s: Scholar) -> bool: return s.grounded))
	for s: Scholar in people:
		s.set_physics_process(false)
		s.facing = 1.0
		s.hush_t = 0.0
	player.global_position = info.cell_position(at + Vector2i(14, 0))
	var middle: Vector2 = info.cell_position(at + Vector2i(1, 0)) + Vector2(APART * 1.5, -20)
	await _look(middle, "scholars_game.png", 1.0)
	await _look(middle, "scholars_close.png", CLOSE)
	for s: Scholar in people:
		s.walking = true
	for step: int in range(3):
		for s: Scholar in people:
			s.walked += float(ScholarArt.GAIT[s.kind]["stride"]) * (0.3 if step > 0 else 0.25)
		await _look(middle, "scholars_walk_%d.png" % step, CLOSE, 14)
	for s: Scholar in people:
		s.walking = false
		s.winding = Scholar.MASTER_WIND * 0.85 if s.kind == &"master" else Scholar.STUDENT_WIND * 0.85
		s.foe = player
		s.since_shield = 0.1
		s.roused = true
		s.hush_t = Scholar.HUSH_EVERY - 1.0
	await _look(middle, "scholars_winding.png", CLOSE)
	for s: Scholar in people:
		s.winding = -1.0
		s.since_shield = 9.0
		s.scatter = 3.0
		s.facing = -1.0
	await _look(middle, "scholars_left.png", CLOSE)
	for s: Scholar in people:
		s.scatter = 0.0
		s.facing = 1.0
		Stunner.of(s).stun(30.0)
	await _look(middle, "scholars_stunned.png", CLOSE)
	if library != null:
		# The four before the library's bookcases, to see each reads on them (held where the librarian
		# stood, on its gallery, so those beside it hang in the air).
		for i: int in range(people.size()):
			var s: Scholar = people[i]
			Stunner.of(s).left = 0.0
			s.global_position = (library as Vector2) + Vector2((float(i) - 1.5) * 120.0, 0)
		player.phasing = true
		player.global_position = (library as Vector2) + Vector2(900, 0)
		await _look((people[1].global_position + people[2].global_position) * 0.5 + Vector2(0, -30), "scholars_library.png", CLOSE)
	RunState.delete_save()
	finish()


## The first stretch of open floor at least `long` cells long with headroom, as its left cell, or
## null.
func _long_floor(long: int) -> Variant:
	var w: LevelGen = info.world
	for v: Vector2i in w.free_floors():
		var ok: bool = true
		for k: int in range(-1, long + 1):
			var c: Vector2i = v + Vector2i(k, 0)
			if not w.is_valid(c) or w.is_ground(c) or not w.is_ground(c + Vector2i.DOWN) or w.is_ground(c + Vector2i.UP):
				ok = false
				break
		if ok:
			return v
	return null


## Hold the camera on `at` at `zoom` for `hold` frames, then save the still.
func _look(at: Vector2, file: String, zoom: float, hold: int = 40) -> void:
	var was: Vector2 = camera.zoom
	for i: int in range(hold):
		camera.global_position = at
		camera.zoom = was * zoom
		camera.reset_smoothing()
		await process_frame
	save_still(file)
	camera.zoom = was
