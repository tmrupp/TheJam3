extends TestKit
## Stills of the hopper (HopperArt) through a real leap at the wizard: a blob at rest, leaning to
## leap, a drop rising with its tail following, falling, and spread out again as it lands (its
## splash). Written as one sheet (hopper.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_hopper.gd

const SIZE: int = 360


func run() -> void:
	window()
	await boot()
	info.debug = true
	RisoTransition.instance.title_age = -1.0
	var at: Vector2i = Vector2i(28, NextWorldDef.band_row(&"garden", 2))
	info.debug_travel(at)
	await process_frame
	await until(func() -> bool: return info.world != null and not info.travelling and info.coord == at, 20000)
	await frames(10)
	RisoTransition.instance.title_age = -1.0
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var body: Node2D = null
	var aim: Vector2 = Vector2.ZERO
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	player.invulnerable.enable()
	# A hopper with open air beside it at its height, woken and settled with the view on it.
	for h: Node in placed("hopper_enemy.tscn", true):
		await _look(camera, (h as Node2D).global_position)
		for side: float in [1.0, -1.0]:
			var from: Vector2 = (h as Node2D).global_position
			var to: Vector2 = from + Vector2(side * 260.0, -8.0)
			if body == null and space.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, 4)).is_empty():
				body = h as Node2D
				aim = to
		if body != null:
			break
	check(body != null, "a hopper with room to leap")
	if body == null:
		finish()
		return
	var hop: Hopper = body.get_node("Hopper") as Hopper
	var middle: Vector2 = (body.global_position + aim) * 0.5 + Vector2(0, -50)
	var shots: Array[Image] = []
	hop.rest = 0.0
	player.global_position = Vector2(-9000, -9000)
	await _look(camera, middle)
	shots.append(await _shot(middle))
	player.global_position = aim
	var wants: Array[Callable] = [
		func() -> bool: return hop.crouch > 0.6,
		func() -> bool: return not hop.grounded and hop.velocity.y < -250.0,
		func() -> bool: return not hop.grounded and hop.velocity.y > 250.0,
		func() -> bool: return hop.grounded and hop.since_landing > 0.04 and hop.since_landing < 0.2]
	for want: Callable in wants:
		var got: bool = false
		for i: int in range(400):
			camera.global_position = middle
			camera.reset_smoothing()
			await process_frame
			if bool(want.call()):
				got = true
				break
		check(got, "a pose caught")
		shots.append(await _shot(middle))
	var sheet: Image = Image.create(SIZE * shots.size(), SIZE, false, Image.FORMAT_RGBA8)
	for k: int in range(shots.size()):
		shots[k].convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shots[k], Rect2i(0, 0, SIZE, SIZE), Vector2i(k * SIZE, 0))
	save_still("hopper.png", sheet)
	RunState.delete_save()
	finish()


## Hold the camera on `at` a moment, so what is there is awake and printed.
func _look(camera: Camera2D, at: Vector2) -> void:
	for i: int in range(30):
		camera.global_position = at
		camera.reset_smoothing()
		info.loader.wake_around(at)
		await process_frame


## The view's middle, SIZE square (the camera is on `_at`).
func _shot(_at: Vector2) -> Image:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var c: Vector2i = image.get_size() / 2
	return image.get_region(Rect2i(c - Vector2i(SIZE, SIZE) / 2, Vector2i(SIZE, SIZE)))
