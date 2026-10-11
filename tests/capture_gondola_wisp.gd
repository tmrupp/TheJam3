extends TestKit
## Stills of a wisp riding a crag gondola's car with the wizard (Gondola, Mover, WispArt): standing
## in the car, then eight frames as the car runs on to the next station (gondola_wisp.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_gondola_wisp.gd

const SIZE: int = 420
const FRAMES: int = 8
## Seconds between frames.
const EVERY: float = 0.25


func run() -> void:
	window()
	await boot()
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.health.max_health = 99
	player.health.health = 99
	info.coord = Vector2i(28, NextWorldDef.band_row(&"crags", 0))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	var g: Gondola = placed("gondola.tscn")[0] as Gondola
	player.global_position = g.center() + Vector2(-60, 40)
	player.velocity = Vector2.ZERO
	await until(func() -> bool: return g.has_rider() and player.is_on_floor())
	var wisp: Node2D = Placeables.scene(LevelGen.Type.ENEMY).instantiate() as Node2D
	LevelLoader.arm(wisp, info.here.depth)
	info.map_elements.add_child(wisp)
	wisp.global_position = g.center() + Vector2(60, 20)
	await frames(30)
	g.pull()
	var shots: Array[Image] = []
	for f: int in range(FRAMES):
		var wait: float = EVERY
		while wait > 0.0:
			camera.global_position = g.center()
			camera.reset_smoothing()
			await process_frame
			wait -= 1.0 / 60.0
		var image: Image = get_root().get_texture().get_image()
		@warning_ignore("integer_division")
		var c: Vector2i = image.get_size() / 2
		@warning_ignore("integer_division")
		shots.append(image.get_region(Rect2i(c.x - SIZE / 2, c.y - SIZE / 2, SIZE, SIZE)))
	var sheet: Image = Image.create(SIZE * 4, SIZE * 2, false, shots[0].get_format())
	for k: int in range(FRAMES):
		@warning_ignore("integer_division")
		sheet.blit_rect(shots[k], Rect2i(0, 0, SIZE, SIZE), Vector2i((k % 4) * SIZE, (k / 4) * SIZE))
	save_still("gondola_wisp.png", sheet)
	RunState.delete_save()
	finish()
