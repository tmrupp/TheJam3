extends TestKit
## Stills of a thorn vine on its own in a garden wall near the bramble (GardenVine, VineArt): at
## rest, warning, and out, side by side (boss_signs/vine.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_boss_signs.gd

const SHOT: Vector2i = Vector2i(420, 320)


func run() -> void:
	window()
	await boot(28)
	Health.invincible = true
	var seed: int = info.run.run_seed
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	var row: int = Bosses.row_of(&"bramble") - signi(Bosses.row_of(&"bramble"))
	var col: int = Bosses.column(&"bramble", seed)
	await go(Vector2i(col, row))
	player.set_physics_process(false)
	var vines: Array[Node] = placed("garden_vine.tscn")
	check(not vines.is_empty(), "a vine near the bramble")
	if vines.is_empty():
		finish()
		return
	var vine: GardenVine = vines[0] as GardenVine
	player.global_position = vine.global_position + vine.way * 600.0 + Vector2(0, -200)
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	camera.global_position = vine.global_position + vine.way * 140.0
	camera.reset_smoothing()
	info.loader.wake_around(vine.global_position)
	var sheet: Image = Image.create(SHOT.x * 3, SHOT.y, false, Image.FORMAT_RGBA8)
	var times: Array[float] = [0.2, BrambleVine.REST + BrambleVine.WARN * 0.6, BrambleVine.REST + BrambleVine.WARN + BrambleVine.GROW + 0.4]
	for i: int in range(times.size()):
		vine.t = times[i]
		vine.set_physics_process(false)
		vine.length = vine.full if i == 2 else 0.0
		await frames(20)
		var whole: Image = root.get_texture().get_image()
		whole.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(whole.get_region(Rect2i((whole.get_size() - SHOT) / 2, SHOT)), Rect2i(Vector2i.ZERO, SHOT), Vector2i(SHOT.x * i, 0))
	save_still("boss_signs/vine.png", sheet)
	finish()
