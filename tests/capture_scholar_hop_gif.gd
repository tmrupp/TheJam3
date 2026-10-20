extends TestKit
## Frames of the institute's scholars hopping up a step (Scholar, ScholarArt), for a GIF: in the
## institute's first level (world 28), a master and a student walk up a step a cell high, one after
## the other (the student setting off once its master is on its way), each jumping it, its figure
## rising and falling with its body. The wizard is projected far off, so nothing goes for them, and
## the level's own enemies are cleared. Frames go to the
## stills folder's hop_gif/ as frame_NNN.png, a frame every EVERY physics steps (so at 30 frames a
## second it plays at the game's own speed), CROP of the window round the step scaled to SIZE; turn
## them into a GIF with ffmpeg (see docs/RISO_PRINT.md).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_scholar_hop_gif.gd

## Frames taken, how many physics steps apart, the middle of the window taken, its size scaled to,
## and the camera's zoom against the game's own.
const FRAMES: int = 150
const EVERY: int = 2
const CROP: Vector2i = Vector2i(960, 540)
const SIZE: Vector2i = Vector2i(640, 360)
const ZOOM: float = 1.6
## The frame the student sets off at, after its master.
const STUDENT_AFTER: int = 45

var camera: Camera2D
## The game's own zoom, before the capture's.
var base_zoom: Vector2 = Vector2.ONE


func run() -> void:
	window()
	await boot(28)
	camera = main.get_node("Camera2D") as Camera2D
	base_zoom = camera.zoom
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"institute"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.get_node("CameraControl").set_process(false)
	player.set_physics_process(false)
	player.phasing = true
	var step: Variant = _step()
	if step == null:
		print("no step to hop here")
		finish()
		return
	var at: Vector2i = step
	player.global_position = info.cell_position(at) + Vector2(0, -2000)
	var look: Vector2 = info.cell_position(at) + Vector2(-40, -70)
	# Long enough for the region's title card to go.
	for i: int in range(420):
		_hold(look)
		await process_frame
	for node: Node in info.map_elements.get_children():
		if node.has_meta(&"cell") and Placeables.has_flag(Placeables.type_of(node), &"enemy"):
			node.queue_free()
	await frames(2)
	# A master a cell back from the step, heading past it; its student follows (STUDENT_AFTER).
	_send("master.tscn", at)
	var dir: String = ProjectSettings.globalize_path(STILLS).path_join("hop_gif")
	DirAccess.make_dir_recursive_absolute(dir)
	for old: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(old))
	for f: int in range(FRAMES):
		if f == STUDENT_AFTER:
			_send("student.tscn", at)
		for k: int in range(EVERY):
			_hold(look)
			await physics_frame
		await process_frame
		var image: Image = root.get_texture().get_image()
		var corner: Vector2i = (image.get_size() - CROP) / 2
		var region: Image = image.get_region(Rect2i(corner, CROP))
		region.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
		region.save_png(dir.path_join("frame_%03d.png" % f))
	print("CAPTURED %d frames to %s" % [FRAMES, dir])
	RunState.delete_save()
	finish()


## A scholar from `scene` a cell back from the step at `at`, heading past it.
func _send(scene: String, at: Vector2i) -> void:
	var s: Scholar = (load("res://prefabs/" + scene) as PackedScene).instantiate() as Scholar
	LevelLoader.arm(s, info.here.depth)
	info.map_elements.add_child(s)
	var from: Vector2i = at + Vector2i.LEFT
	s.global_position = info.cell_position(from)
	s.setup(info, from, {"ability": &"hex" if scene == "master.tscn" else &"", "hall": -1})
	s.home_x = info.cell_position(at + Vector2i(4, -1)).x
	s.look_in = 999.0


## The camera held on `at`, zoomed in.
func _hold(at: Vector2) -> void:
	camera.global_position = at
	camera.zoom = base_zoom * ZOOM
	camera.reset_smoothing()


## An open floor cell with a step a cell high on its right, open air two cells high over both and
## a cell of open floor behind it, out of the halls: the step's foot, or null.
func _step() -> Variant:
	var w: LevelGen = info.world
	for v: Vector2i in w.free_floors():
		var r: Vector2i = v + Vector2i.RIGHT
		var open: bool = true
		for c: Vector2i in [v + Vector2i.UP, v + Vector2i(0, -2), r + Vector2i.UP, r + Vector2i(0, -2), v + Vector2i.LEFT]:
			open = open and w.is_valid(c) and not w.is_ground(c)
		if w.is_ground(r) and open and w.is_ground(v + Vector2i(-1, 1)) and Institute.hall_at(w, v) < 0:
			return v
	return null
