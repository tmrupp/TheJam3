extends TestKit
## Stills of thorns that come and go (Spikes, ThornsArt): a timed run out, down, and peeking before
## it rises; a switched run with its sigil, out and dropped; and a key and stars in their own light
## (RisoProp.light). Written as one sheet (thorns.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_thorns.gd

const SIZE: int = 420


func run() -> void:
	window()
	await boot()
	info.debug = true
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	# No title card over the stills.
	RisoTransition.instance.title_age = -1.0
	var timed: Spikes = null
	var switched: Spikes = null
	for k: int in range(1, 4):
		var at: Vector2i = Vector2i(28, NextWorldDef.band_row(&"garden", k))
		info.debug_travel(at)
		await process_frame
		await until(func() -> bool: return info.world != null and not info.travelling and info.coord == at, 20000)
		await frames(10)
		RisoTransition.instance.title_age = -1.0
		for n: Node in placed("spikes.tscn", true):
			var s: Spikes = n as Spikes
			if s.mode == Spikes.Mode.TIMED and timed == null:
				timed = s
			elif s.mode == Spikes.Mode.SWITCHED and switched == null and Sigils.of(s) >= 0:
				switched = s
		if timed != null and switched != null:
			break
		timed = null
		switched = null
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	player.global_position = Vector2(-9000, -9000)
	var shots: Array[Image] = []
	if timed != null:
		for want: StringName in [&"out", &"down", &"warn"]:
			var ready: Callable = func() -> bool:
				match want:
					&"out":
						return timed.out and timed.rise >= 1.0
					&"down":
						return not timed.out and timed.rise <= 0.0 and timed.warning() <= 0.0
				return timed.warning() > 0.5
			await _look(camera, timed.global_position)
			await within(ready, Spikes.CYCLE * 2.0)
			shots.append(await _shot(camera, timed.global_position))
	if switched != null:
		var lever_cell: Vector2i = switched.lever
		var lever: Switch = null
		for n: Node in placed("switch.tscn", true):
			if n.get_meta(&"cell") == lever_cell:
				lever = n as Switch
		for on: bool in [false, true]:
			if lever != null and lever.is_on() != on:
				lever.flip()
			await _look(camera, switched.global_position)
			await within(func() -> bool: return switched.rise == (0.0 if on else 1.0), 1.0)
			shots.append(await _shot(camera, switched.global_position))
	var keys: Array[Node] = placed("key.tscn")
	if not keys.is_empty():
		await _look(camera, (keys[0] as Node2D).global_position)
		shots.append(await _shot(camera, (keys[0] as Node2D).global_position))
	print("thorns: timed ", timed != null, " switched ", switched != null, " shots ", shots.size())
	var sheet: Image = Image.create(SIZE * maxi(1, shots.size()), SIZE, false, Image.FORMAT_RGBA8)
	for k: int in range(shots.size()):
		shots[k].convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shots[k], Rect2i(0, 0, SIZE, SIZE), Vector2i(k * SIZE, 0))
	save_still("thorns.png", sheet)
	RunState.delete_save()
	finish()


## Hold the camera on `at` for a moment, so what is there is awake and printed.
func _look(camera: Camera2D, at: Vector2) -> void:
	for i: int in range(20):
		camera.global_position = at
		camera.reset_smoothing()
		info.loader.wake_around(at)
		await process_frame


## The view's middle, SIZE square, round `at`.
func _shot(camera: Camera2D, at: Vector2) -> Image:
	camera.global_position = at
	camera.reset_smoothing()
	await frames(2)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var c: Vector2i = image.get_size() / 2
	return image.get_region(Rect2i(c - Vector2i(SIZE, SIZE) / 2, Vector2i(SIZE, SIZE)))
