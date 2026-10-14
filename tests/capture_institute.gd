extends TestKit
## Stills of the institute (world 28, its first level): the exam hall with its master, students and
## the way on; a lecture hall's tiers with its class and its department's portal; the library's
## stacks with its librarian's hush; a breach and an abomination; a row of the people side by side
## close up (a student, a master of each spell, a proctor, a librarian) and one winding up; and a
## lesson left where a master fell.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_institute.gd

var camera: Camera2D


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	await _go(Vector2i(28, NextWorldDef.first_depth(&"institute")))
	for hall: Dictionary in info.world.halls:
		var box: Rect2i = hall["box"]
		var floors: Array = hall["floors"]
		if not floors.is_empty():
			player.global_position = info.cell_position(floors[0])
		await _look(info.cell_position(box.get_center()), "institute_%s.png" % hall["kind"], 0.9)
	for kind: String in ["breach.tscn", "abomination.tscn"]:
		var found: Array[Node] = placed(kind)
		if not found.is_empty():
			var n: Node2D = found[0] as Node2D
			player.global_position = n.global_position + Vector2(-500, 0)
			await _look(n.global_position + Vector2(0, -60), "institute_%s" % kind.replace(".tscn", ".png"), 1.6)
	await _lineup()
	RunState.delete_save()
	finish()


## The people side by side on a floor, close up, frozen: a student, a master of each spell, a
## proctor and a librarian; then a student and a master winding up.
func _lineup() -> void:
	var spot: Variant = _long_floor(11)
	if spot == null:
		print("no floor long enough for the line-up")
		return
	var at: Vector2i = spot
	var people: Array[Node2D] = []
	var kinds: Array = [["student.tscn", &""]]
	for a: StringName in Institute.MASTERIES:
		kinds.append(["master.tscn", a])
	kinds.append(["proctor.tscn", &""])
	kinds.append(["librarian.tscn", &""])
	for i: int in range(kinds.size()):
		var node: Scholar = (load("res://prefabs/" + String(kinds[i][0])) as PackedScene).instantiate() as Scholar
		LevelLoader.arm(node, info.here.depth)
		info.map_elements.add_child(node)
		node.global_position = info.cell_position(at + Vector2i(i + 1, 0))
		node.setup(info, at + Vector2i(i + 1, 0), {"ability": kinds[i][1], "hall": -1})
		people.append(node)
	await physics_frame
	for p: Node2D in people:
		p.set_physics_process(false)
		(p as Scholar).facing = 1.0
	player.global_position = info.cell_position(at + Vector2i(11, 0))
	await _look(info.cell_position(at + Vector2i(5, 0)) + Vector2(0, -40), "institute_people.png", 1.4)
	for p: Node2D in people:
		var s: Scholar = p as Scholar
		s.winding = Scholar.MASTER_WIND * 0.8 if s.kind == &"master" else Scholar.STUDENT_WIND * 0.8
		s.foe = player
	await _look(info.cell_position(at + Vector2i(5, 0)) + Vector2(0, -40), "institute_people_winding.png", 1.4)
	var master: Scholar = people[1] as Scholar
	master.set_physics_process(true)
	(master.get_node("Wound") as Wound).hit(99, Vector2.UP)
	await settle()
	await _look(info.cell_position(at + Vector2i(2, 0)) + Vector2(0, -60), "institute_lesson.png", 1.6)


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
