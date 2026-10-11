extends TestKit
## Stills of the webs in the spider's keep, as they print, beside the decor's cobwebs they are
## spun like (Spider.plain_web; RisoDecor.WEB_RING_GAP and the rest): a web across a hole of its well,
## the quarter web in a top corner of the hall, a splat, and one of the keep's decor cobwebs (shown
## twice as big); and splats tied on to what is near them: against a wall, a pair near each other,
## one above a hole's web, and one alone in the open. Written as a sheet (spider_webs.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_spider_webs.gd

const SIZE: int = 420


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
	player.global_position = Vector2(-9000, -9000)
	var spider: Spider = placed("spider.tscn")[0] as Spider
	spider.set_physics_process(false)
	var keep: Dictionary = info.world.keep
	var inside: Rect2i = keep["inside"]
	var floors: Array[int] = keep["floors"]
	var cell: float = spider.cell
	var web: SpiderWeb = spider.webs[1]
	var stand: Vector2i = _clear_spot(info.world, floors[1] - 1)
	spider.splat(info.cell_position(stand))
	var real: Vector2i = _decor_cobweb(inside)
	var shots: Array[Image] = []
	shots.append(await _shot(camera, web.rect.get_center(), 1))
	shots.append(await _shot(camera, Vector2(spider.hall_left, spider.roof_y) + Vector2(cell * 1.3, cell * 1.3), 1))
	shots.append(await _shot(camera, info.cell_position(stand), 1))
	shots.append(await _shot(camera, info.cell_position(real) - Vector2(0.0, cell * 0.3), 2))
	# Splats tied on to what is near them: against a wall, a pair near each other, one above a hole's
	# web; and one alone in the open, tied to nothing.
	var mid_x: float = (spider.hall_left + spider.hall_right) * 0.5
	var by_wall: Vector2 = Vector2(spider.hall_left + cell * 0.45, info.cell_position(Vector2i(0, floors[1] - 2)).y)
	var pair: Vector2 = Vector2(mid_x - cell * 0.9, info.cell_position(Vector2i(0, floors[2] - 2)).y)
	# Touching: the pair a few pixels apart, edge to edge; one just over the left of a hole's two webs.
	var r: float = Spider.SPLAT * cell * 0.5
	var over_hole: Vector2 = web.rect.position + Vector2(web.rect.size.x * 0.25, web.rect.size.y * 0.5 - 2.0 * r - 6.0)
	var alone: Vector2 = Vector2(mid_x + cell * 3.0, info.cell_position(Vector2i(0, inside.position.y + 4)).y)
	for at: Vector2 in [by_wall, pair, pair + Vector2(2.0 * r + 8.0, 0.0), over_hole, alone]:
		spider.splat(at)
	shots.append(await _shot(camera, by_wall + Vector2(cell * 0.9, 0.0), 1))
	shots.append(await _shot(camera, pair + Vector2(r + 4.0, 0.0), 1))
	shots.append(await _shot(camera, over_hole + Vector2(0.0, r), 1))
	shots.append(await _shot(camera, alone, 1))
	var sheet: Image = Image.create(SIZE * 4, SIZE * 2, false, shots[0].get_format())
	for k: int in range(shots.size()):
		@warning_ignore("integer_division")
		sheet.blit_rect(shots[k], Rect2i(0, 0, SIZE, SIZE), Vector2i((k % 4) * SIZE, (k / 4) * SIZE))
	save_still("spider_webs.png", sheet)
	RunState.delete_save()
	finish()


## The cell of one of the decor's cobwebs in the keep's hall `inside` (the first planned).
func _decor_cobweb(inside: Rect2i) -> Vector2i:
	for item: Dictionary in RisoPrint.instance.decor.items:
		var v: Vector2i = item["cell"]
		if item["kind"] == &"cobweb" and inside.has_point(v):
			return v
	return inside.position


## A cell on row `row` of the keep's hall with floor under it, as far from every hole as can be.
func _clear_spot(w: LevelGen, row: int) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: int = -1
	var inside: Rect2i = w.keep["inside"]
	for x: int in range(inside.position.x + 2, inside.end.x - 2):
		var v: Vector2i = Vector2i(x, row)
		if not w.is_ground(v + Vector2i.DOWN):
			continue
		var d: int = 999
		for h: Rect2i in w.keep["holes"]:
			if h.position.y == row + 1:
				d = mini(d, mini(absi(x - h.position.x), absi(x - (h.end.x - 1))))
		if d > best_d:
			best_d = d
			best = v
	return best


## A close-up round `at`, the camera on it, `zoom` times as big (a smaller crop scaled up).
func _shot(camera: Camera2D, at: Vector2, zoom: int) -> Image:
	for i: int in range(10):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	var sp: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * at)
	@warning_ignore("integer_division")
	var crop: int = SIZE / zoom
	@warning_ignore("integer_division")
	var x: int = clampi(int(sp.x) - crop / 2, 0, 1280 - crop)
	@warning_ignore("integer_division")
	var y: int = clampi(int(sp.y) - crop / 2, 0, 720 - crop)
	var image: Image = root.get_texture().get_image().get_region(Rect2i(x, y, crop, crop))
	if zoom > 1:
		image.resize(SIZE, SIZE, Image.INTERPOLATE_NEAREST)
	return image
