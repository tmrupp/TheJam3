extends TestKit
## Frames of the light at work (RisoLight), for a GIF: the wizard walking and jumping through the
## garden's first level with the camera following, their carried lantern's warm pool cut by the
## rock and what they cannot see shaded, then unprotected (the short, dim, faintly pink light), then
## inside a cemetery crypt, where the dark lifts only inside the lights. Frames go to the stills
## folder's light_gif/ as frame_NNN.png, a frame every EVERY physics steps (so at 30 frames a second
## it plays at the game's own speed), CROP of the window round the wizard scaled to SIZE; turn them into
## a GIF with ffmpeg (see docs/RISO_PRINT.md).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_light_gif.gd

## Frames taken in each part (protected, unprotected, in the crypt), how many physics steps apart,
## the middle of the window taken and the size it is scaled to.
const PARTS: Array[int] = [150, 90, 120]
const EVERY: int = 2
const CROP: Vector2i = Vector2i(1040, 585)
const SIZE: Vector2i = Vector2i(640, 360)
## How often (physics steps) the wizard jumps as they walk, and for how long the jump is held.
const JUMP_EVERY: int = 70
const JUMP_HOLD: int = 14

var frame_index: int = 0
var dir: String = ""
var camera: Camera2D


## No enemies about (a hit would flash the wizard).
func _clear() -> void:
	for node: Node in info.map_elements.get_children():
		if node.has_meta(&"cell") and Placeables.has_flag(Placeables.type_of(node), &"enemy"):
			node.queue_free()


## The open floor with the longest run of open floor to its right (open over it too), away from the
## level's top and bottom, so the camera can centre on the wizard there.
func _long_floor() -> Vector2i:
	var w: LevelGen = info.world
	var best: Vector2i = w.free_floors()[0]
	var most: int = 0
	for v: Vector2i in w.free_floors():
		if v.y < 4 or v.y > w.size.y - 4:
			continue
		var n: int = 0
		while w.is_valid(v + Vector2i(n + 1, 0)) and not w.is_ground(v + Vector2i(n + 1, 0)) and w.is_ground(v + Vector2i(n + 1, 1)):
			n += 1
		if n > most:
			most = n
			best = v
	return best


## The camera on the wizard.
func _follow() -> void:
	camera.global_position = player.global_position + Vector2(0, -40)
	camera.reset_smoothing()


func run() -> void:
	window()
	await boot(28)
	dir = ProjectSettings.globalize_path(STILLS).path_join("light_gif")
	DirAccess.make_dir_recursive_absolute(dir)
	for old: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(old))
	# Never hurt for long (a hit would flash them): healed every frame. The camera follows them
	# exactly, so the clip stays on them.
	process_frame.connect(func() -> void: player.health.health = player.health.max_health)
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	# Long enough for the region's title card to go.
	_clear()
	var start: Vector2i = _long_floor()
	player.global_position = info.cell_position(start)
	player.velocity = Vector2.ZERO
	for i: int in range(420):
		_follow()
		await process_frame
	info.run.vulnerable = false
	await _walk(PARTS[0])
	info.run.vulnerable = true
	await _walk(PARTS[1])
	info.run.vulnerable = false
	# Into a crypt: the first of the cemetery's first level, from a floor inside it.
	Input.action_release(&"Right")
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"cemetery"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	_clear()
	var spot: Vector2i = Vector2i(-1, -1)
	if not info.world.crypts.is_empty():
		var floors: Array[Vector2i] = info.world.crypts[0]["floors"]
		if not floors.is_empty():
			spot = floors[floors.size() / 2]
	check(spot.x >= 0, "a floor inside a crypt")
	if spot.x >= 0:
		player.global_position = info.cell_position(spot)
		player.velocity = Vector2.ZERO
		for i: int in range(420):
			_follow()
			await process_frame
		await _walk(PARTS[2])
	Input.action_release(&"Right")
	RunState.delete_save()
	print("CAPTURED %d frames to %s" % [frame_index, dir])
	finish()


## `frames` frames of the wizard walking right, jumping now and then (turning back at a wall).
func _walk(frames: int) -> void:
	var step: int = 0
	var facing: String = "Right"
	Input.action_press(facing)
	var stuck: int = 0
	var last_x: float = player.global_position.x
	for k: int in range(frames):
		for i: int in range(EVERY):
			step += 1
			if step % JUMP_EVERY == 0:
				Input.action_press(&"Jump")
			elif step % JUMP_EVERY == JUMP_HOLD:
				Input.action_release(&"Jump")
			await physics_frame
		# Turn round at a wall it cannot jump.
		stuck = stuck + 1 if absf(player.global_position.x - last_x) < 0.5 else 0
		last_x = player.global_position.x
		if stuck > 20:
			Input.action_release(facing)
			facing = "Left" if facing == "Right" else "Right"
			Input.action_press(facing)
			stuck = 0
		_follow()
		await process_frame
		var image: Image = root.get_texture().get_image()
		# Round the wizard, kept inside the window.
		var on_screen: Vector2 = root.get_final_transform() * root.canvas_transform * (player.global_position + Vector2(0, -40))
		var corner: Vector2i = (Vector2i(on_screen) - CROP / 2).clamp(Vector2i.ZERO, image.get_size() - CROP)
		var region: Image = image.get_region(Rect2i(corner, CROP))
		region.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
		region.save_png(dir.path_join("frame_%03d.png" % frame_index))
		frame_index += 1
	Input.action_release(facing)
	Input.action_release(&"Jump")
