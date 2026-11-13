extends TestKit
## Frames of the institute's four people moving (ScholarArt), for a GIF: a student, a master, a
## proctor and a librarian side by side on a floor of its first level (world 28), each put through
## the same turns by hand (their own minds off, so all four do each thing together): they walk
## right at their own pace, stand, wind up and cast (the proctor shields, the librarian's hush
## comes up), turn on the wizard and walk back left, and are stunned. Frames go to the stills
## folder's scholars_gif/ as frame_NNN.png, a frame every EVERY physics steps (so at 30 frames a
## second it plays at the game's own speed); `python tests/make_gifs.py scholars_gif` makes the GIF.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_scholars_gif.gd

## Physics steps a frame, the middle of the window taken and the size it is scaled to, the camera's
## zoom against the game's own, and px between one figure and the next.
const EVERY: int = 2
const CROP: Vector2i = Vector2i(1200, 400)
const SIZE: Vector2i = Vector2i(840, 280)
const ZOOM: float = 2.7
const APART: float = 150.0
## The turns, in order: what they do and for how many frames.
const TURNS: Array = [[&"stand", 20], [&"walk", 50], [&"stand", 15], [&"wind", 22], [&"cast", 30], [&"back", 50], [&"stand", 15], [&"stun", 40]]

var camera: Camera2D
var base_zoom: Vector2 = Vector2.ONE
var people: Array[Scholar] = []


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	base_zoom = camera.zoom
	await go(Vector2i(28, NextWorldDef.first_depth(&"institute")))
	player.get_node("CameraControl").set_process(false)
	var spot: Variant = _long_floor(7)
	if spot == null:
		print("no floor long enough for the line-up")
		finish()
		return
	var at: Vector2i = spot
	# The level's own people and enemies gone, so nothing wanders into the frame.
	for n: Node in info.map_elements.get_children():
		if n is Scholar or (n.has_meta(&"cell") and Placeables.has_flag(Placeables.type_of(n), &"enemy")):
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
	player.global_position = info.cell_position(at + Vector2i(1, 0)) + Vector2(APART * 6.0, 0)
	var middle: Vector2 = info.cell_position(at + Vector2i(1, 0)) + Vector2(APART * 1.5 + 25.0, -14)
	# Long enough for the region's title card to go.
	for i: int in range(420):
		_hold(middle)
		await process_frame
	var dir: String = ProjectSettings.globalize_path(STILLS).path_join("scholars_gif")
	DirAccess.make_dir_recursive_absolute(dir)
	for old: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(old))
	var frame: int = 0
	var step: float = float(EVERY) / 60.0
	for turn: Array in TURNS:
		var what: StringName = turn[0]
		_begin(what)
		for f: int in range(int(turn[1])):
			for s: Scholar in people:
				_advance(s, what, step)
			for k: int in range(EVERY):
				_hold(middle)
				await physics_frame
			await process_frame
			var image: Image = root.get_texture().get_image()
			var region: Image = image.get_region(Rect2i((image.get_size() - CROP) / 2, CROP))
			region.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
			region.save_png(dir.path_join("frame_%03d.png" % frame))
			frame += 1
	print("CAPTURED %d frames to %s" % [frame, dir])
	RunState.delete_save()
	finish()


## Start the turn `what` for every figure.
func _begin(what: StringName) -> void:
	for s: Scholar in people:
		s.walking = what == &"walk" or what == &"back"
		match what:
			&"wind":
				s.foe = player
				s.roused = true
				s.winding = 0.0
				s.hush_t = Scholar.HUSH_EVERY - Scholar.HUSH_ON
			&"cast":
				s.winding = -1.0
				s.since_cast = 0.0
				s.since_shield = 0.0
			&"back":
				s.facing = -1.0
			&"stun":
				s.facing = 1.0
				Stunner.of(s).stun(30.0)


## A frame of the turn `what` for `s`, `dt` seconds on.
func _advance(s: Scholar, what: StringName, dt: float) -> void:
	s.since_cast += dt
	s.since_shield += dt
	if s.hush_t > 0.0:
		s.hush_t += dt
	match what:
		&"walk", &"back":
			var by: float = float(Scholar.SPEED[s.kind]) * dt
			s.walked += by
			s.global_position.x += by * s.facing
		&"wind":
			var wind: float = Scholar.MASTER_WIND if s.kind == &"master" else Scholar.STUDENT_WIND
			s.winding = minf(s.winding + dt, wind * 0.98)


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


## The camera held on `at`, zoomed in.
func _hold(at: Vector2) -> void:
	camera.global_position = at
	camera.zoom = base_zoom * ZOOM
	camera.reset_smoothing()
