extends TestKit
## Stills of the spider's legs at work (Spider._legs): walking the canopy under its keep's roof
## toward the wizard, its feet planted on the roof and stepping in turn (eight frames,
## spider_walk.png), then dropped to a floor by a cut thread and scurrying off, its feet stepping on
## the floor (eight frames, spider_scurry.png), each a sheet of close-ups.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_spider_walk.gd

const SIZE: int = 420
const FRAMES: int = 8
## Seconds between frames.
const EVERY: float = 0.08


func run() -> void:
	window()
	await boot(28)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.health.max_health = 99
	player.health.health = 99
	info.coord = Vector2i(28, Bosses.row_of(&"spider"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	var spider: Spider = placed("spider.tscn")[0] as Spider
	var keep: Dictionary = info.world.keep
	var inside: Rect2i = keep["inside"]
	var floors: Array[int] = keep["floors"]
	# On the top floor at the far side from it: it wakes and walks the canopy over.
	var far_x: int = inside.position.x + 1 if spider.global_position.x > info.cell_position(inside.get_center()).x else inside.end.x - 2
	player.global_position = info.cell_position(Vector2i(far_x, floors[0] - 1))
	await within(func() -> bool: return spider.state == Spider.State.HUNT, 3.0)
	await frames(10)
	await _sheet(camera, spider, "spider_walk.png")
	# Cut its thread as it drops, and watch it scurry off the floor it lands on.
	await within(func() -> bool: return spider.state == Spider.State.DROP or spider.state == Spider.State.BITE, 10.0)
	player.global_position = Vector2(-9000, -9000)
	spider.cut(spider.global_position + Vector2(0, -Spider.THREAD_TOP - 20.0))
	await within(func() -> bool: return spider.state == Spider.State.SCURRY, Spider.DOWNED + 6.0)
	await frames(6)
	await _sheet(camera, spider, "spider_scurry.png")
	RunState.delete_save()
	finish()


## FRAMES close-ups of `spider`, EVERY seconds apart, the camera on it, as a sheet `file`.
func _sheet(camera: Camera2D, spider: Spider, file: String) -> void:
	var shots: Array[Image] = []
	for f: int in range(FRAMES):
		var wait: float = EVERY
		while wait > 0.0:
			camera.global_position = spider.global_position
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
	save_still(file, sheet)
