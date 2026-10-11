extends TestKit
## Stills of the spider (Spider) in four worlds' crag gate levels, each with its own look dealt from
## its level seed (Spider._deal_look: its abdomen, head, legs, bristles, marking and fangs), and the
## web across its keep's well under it, spun its own way (Spider._web_pattern): written as one sheet
## of close-ups (spider_looks.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_spider_looks.gd

const SIZE: int = 420
const WORLDS: Array[int] = [28, 29, 30, 31]


func run() -> void:
	window()
	await boot(28)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.health.max_health = 99
	player.health.health = 99
	var shots: Array[Image] = []
	for world: int in WORLDS:
		info.coord = Vector2i(world, Bosses.row_of(&"spider"))
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		await settle()
		player.set_physics_process(false)
		var spider: Spider = placed("spider.tscn")[0] as Spider
		player.global_position = Vector2(-9000, -9000)
		for i: int in range(20):
			camera.global_position = spider.global_position + Vector2(0, 60)
			camera.reset_smoothing()
			await process_frame
		var image: Image = get_root().get_texture().get_image()
		var c: Vector2i = image.get_size() / 2
		shots.append(image.get_region(Rect2i(c.x - SIZE / 2, c.y - SIZE / 2, SIZE, SIZE)))
		var holes: Array = info.world.keep["holes"]
		var well: Rect2i = holes[0]
		for i: int in range(20):
			camera.global_position = info.cell_position(well.position + Vector2i(1, 0))
			camera.reset_smoothing()
			await process_frame
		image = get_root().get_texture().get_image()
		shots.append(image.get_region(Rect2i(c.x - SIZE / 2, c.y - SIZE / 2, SIZE, SIZE)))
	var sheet: Image = Image.create(SIZE * 4, SIZE * 2, false, shots[0].get_format())
	for k: int in range(WORLDS.size()):
		sheet.blit_rect(shots[k * 2], Rect2i(0, 0, SIZE, SIZE), Vector2i(k * SIZE, 0))
		sheet.blit_rect(shots[k * 2 + 1], Rect2i(0, 0, SIZE, SIZE), Vector2i(k * SIZE, SIZE))
	save_still("spider_looks.png", sheet)
	RunState.delete_save()
	finish()
