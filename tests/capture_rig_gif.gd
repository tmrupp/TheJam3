extends TestKit
## Frames comparing art placed by its rig in script (every shape moved point by point as it is
## printed, as all art was before rigs) with the same rig on the GPU (InkCanvas.rig_on_gpu), for a
## GIF: close up on the wizard walking, jumping and landing in the garden's first level, or on a
## piece of art of one kind (`-- art=WispArt`, `art=ScholarArt band=institute`: the one nearest the
## middle of the band's first level, the wizard standing off to one side as its quarry). Each frame
## is printed both ways with the game held still (left: script, right: GPU), and how far apart the
## two prints are is printed. Frames go to the stills folder's rig_gif/ (rig_gif_<art>/) as
## frame_NNN.png, a frame every EVERY physics steps.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_rig_gif.gd [-- art=WispArt band=garden]

## Frames taken, how many physics steps apart, the window round the subject each side shows, the
## size each side is scaled to, and the camera's zoom against the game's own.
const FRAMES: int = 150
const EVERY: int = 2
const CROP: Vector2i = Vector2i(640, 360)
const SIDE: Vector2i = Vector2i(480, 270)
const ZOOM: float = 2.4
## How often (physics steps) the wizard jumps as they walk, and for how long the jump is held.
const JUMP_EVERY: int = 60
const JUMP_HOLD: int = 12

var camera: Camera2D
var base_zoom: Vector2 = Vector2.ONE
var subject: Node2D


func run() -> void:
	window()
	await boot(28)
	var art: String = ""
	var band: StringName = &""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("art="):
			art = arg.substr(4)
		elif arg.begins_with("band="):
			band = StringName(arg.substr(5))
	var wisp: bool = art != ""
	if band != &"":
		info.coord = Vector2i(28, NextWorldDef.band_row(band, 0))
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		await settle()
	var dir: String = ProjectSettings.globalize_path(STILLS).path_join("rig_gif_" + art.to_lower() if wisp else "rig_gif")
	DirAccess.make_dir_recursive_absolute(dir)
	for old: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(old))
	process_frame.connect(func() -> void: player.health.health = player.health.max_health)
	camera = main.get_node("Camera2D") as Camera2D
	base_zoom = camera.zoom
	player.get_node("CameraControl").set_process(false)
	subject = player
	if wisp:
		subject = _a_prop(art)
		player.set_physics_process(false)
		if art == "WispArt":
			player.phasing = true
			player.global_position = subject.global_position + Vector2(0, -900)
		else:
			# Off to one side, as its quarry.
			player.global_position = subject.global_position + Vector2(-420, -20)
	else:
		for node: Node in info.map_elements.get_children():
			if node.has_meta(&"cell") and Placeables.has_flag(Placeables.type_of(node), &"enemy"):
				node.queue_free()
	for i: int in range(420):
		_follow()
		await process_frame
	var worst: float = 0.0
	var mean: float = 0.0
	var step: int = 0
	var facing: String = "Right"
	if not wisp:
		Input.action_press(facing)
	var stuck: int = 0
	var last_x: float = player.global_position.x
	for k: int in range(FRAMES):
		for i: int in range(EVERY):
			step += 1
			if not wisp:
				if step % JUMP_EVERY == 0:
					Input.action_press(&"Jump")
				elif step % JUMP_EVERY == JUMP_HOLD:
					Input.action_release(&"Jump")
			await physics_frame
		if not wisp:
			stuck = stuck + 1 if absf(player.global_position.x - last_x) < 0.5 else 0
			last_x = player.global_position.x
			if stuck > 40:
				Input.action_release(facing)
				facing = "Left" if facing == "Right" else "Right"
				Input.action_press(facing)
				stuck = 0
		_follow()
		await process_frame
		paused = true
		var shots: Array[Image] = []
		for gpu: bool in [false, true]:
			InkCanvas.rig_on_gpu = gpu
			_reprint_all()
			for i: int in range(3):
				await process_frame
			shots.append(_region())
		InkCanvas.rig_on_gpu = true
		_reprint_all()
		paused = false
		var d: Vector2 = _difference(shots[0], shots[1])
		worst = maxf(worst, d.x)
		mean += d.y / FRAMES
		var sheet: Image = Image.create(SIDE.x * 2, SIDE.y, false, shots[0].get_format())
		for s: int in range(2):
			var side: Image = shots[s].duplicate() as Image
			side.resize(SIDE.x, SIDE.y, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(side, Rect2i(Vector2i.ZERO, SIDE), Vector2i(s * SIDE.x, 0))
		sheet.save_png(dir.path_join("frame_%03d.png" % k))
	Input.action_release(facing)
	Input.action_release(&"Jump")
	print("RIG script against GPU over %d frames: the most any pixel differs %.0f/255, mean %.3f/255" % [FRAMES, worst * 255.0, mean * 255.0])
	RunState.delete_save()
	finish()


## The host of the art of kind `art` (its script's name) nearest the level's middle.
func _a_prop(art: String) -> Node2D:
	var best: Node2D = null
	var middle: Vector2 = info.cell_position(info.world.size / 2)
	var stack: Array[Node] = [info.map_elements]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var prop: RisoProp = n as RisoProp
		if prop == null or prop.host == null or (prop.get_script() as Script).resource_path.get_file() != art + ".gd":
			continue
		if best == null or prop.host.global_position.distance_to(middle) < best.global_position.distance_to(middle):
			best = prop.host
	return best if best != null else player


## Print every rigged canvas again, its rig now on the GPU or in script (held still, nothing else
## would print it).
func _reprint_all() -> void:
	var stack: Array[Node] = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var w: RisoWizard = n as RisoWizard
		if w != null:
			w._process(0.0)
		var prop: RisoProp = n as RisoProp
		if prop != null and prop.ink != null and prop.ink.rigged:
			prop._redraw()


## The window round the subject, as printed now.
func _region() -> Image:
	var image: Image = root.get_texture().get_image()
	var on_screen: Vector2 = root.get_final_transform() * root.canvas_transform * (subject.global_position + Vector2(0, -24))
	var corner: Vector2i = (Vector2i(on_screen) - CROP / 2).clamp(Vector2i.ZERO, image.get_size() - CROP)
	return image.get_region(Rect2i(corner, CROP))


## How far apart two prints are: the most any pixel differs, and the mean.
func _difference(a: Image, b: Image) -> Vector2:
	var most: float = 0.0
	var sum: float = 0.0
	for y: int in range(0, a.get_height(), 2):
		for x: int in range(0, a.get_width(), 2):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			var d: float = maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b)))
			most = maxf(most, d)
			sum += d
	return Vector2(most, sum / float((a.get_width() / 2) * (a.get_height() / 2)))


func _follow() -> void:
	camera.zoom = base_zoom * ZOOM
	camera.global_position = subject.global_position + Vector2(0, -24)
	camera.reset_smoothing()
