extends TestKit
## Stills of the spider (Spider) in its keep (SpiderKeep): the roost (the spider asleep under the
## roof on its canopy), the hall's broken floors and webs, the spider dropping on the wizard and
## biting, its thread cut and the spider fallen on its back (its eyes open to strikes), stunned, a
## torn web, eyes put out, and the relic it leaves. Written whole (spider_*.png) and as a sheet of
## close-ups (spider.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_spider.gd

const SIZE: int = 420


func run() -> void:
	window()
	await boot(28)
	var arena_at: Vector2i = Worlds.side_at(Worlds.kind_of(Arena), Vector2i(28, Bosses.row_of(&"spider")))
	info.coord = arena_at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	var spider: Spider = placed("spider.tscn")[0] as Spider
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.health.max_health = 99
	player.health.health = 99
	player.set_physics_process(false)
	var keep: Dictionary = info.world.keep
	var floors: Array[int] = keep["floors"]
	var shots: Array[Image] = []
	# The roost: the spider asleep on its canopy, the wizard on the top floor below, too far to wake it.
	var top: Vector2 = info.cell_position(Vector2i(spider.map_info.cell_at(spider.global_position).x, floors[0] - 1))
	player.global_position = Vector2(-9000, -9000)
	await frames(10)
	shots.append(await _shot(camera, spider.global_position + Vector2(0, 90)))
	save_still("spider_roost.png")
	# The hall: broken floors, the well, webs and ledges.
	camera.global_position = info.cell_position(Vector2i(SpiderKeep.SIZE.x / 2, floors[2]))
	player.global_position = info.cell_position(Vector2i(SpiderKeep.SIZE.x / 2, floors[2] - 1))
	await frames(6)
	save_still("spider_hall.png")
	shots.append(await _shot(camera, info.cell_position(Vector2i(int(keep["well"]) + 1, floors[1]))))
	# Dropping on the wizard on the top floor.
	player.global_position = _spot(floors[0] - 1)
	await within(func() -> bool: return spider.state == Spider.State.WARN, 10.0)
	shots.append(await _shot(camera, spider.global_position + Vector2(0, 120)))
	save_still("spider_warn.png")
	await within(func() -> bool: return spider.state == Spider.State.BITE, 3.0)
	shots.append(await _shot(camera, spider.global_position + Vector2(0, -60)))
	save_still("spider_bite.png")
	# Its thread cut: fallen on its back, open (accent eyes); an eye put out.
	spider.cut(spider.global_position + Vector2(0, -120))
	await within(func() -> bool: return spider.state == Spider.State.DOWN, 3.0)
	spider.wound.hit(1, Vector2.RIGHT)
	spider.wound.hit(1, Vector2.RIGHT)
	await frames(30)
	shots.append(await _shot(camera, spider.global_position + Vector2(0, -40)))
	save_still("spider_down.png")
	# Scurrying, then climbing a new thread.
	await within(func() -> bool: return spider.state == Spider.State.RECLIMB, 8.0)
	await frames(8)
	shots.append(await _shot(camera, spider.global_position + Vector2(0, -80)))
	save_still("spider_climb.png")
	# Stunned on its thread.
	spider.stunner.stun(4.0, true)
	spider.wound.hit(1, Vector2.RIGHT)
	await frames(20)
	shots.append(await _shot(camera, spider.global_position + Vector2(0, -40)))
	save_still("spider_stunned.png")
	# A torn web.
	var web: SpiderWeb = spider.webs[0]
	web.tear()
	player.global_position = web.rect.get_center() + Vector2(0, -90)
	await frames(10)
	shots.append(await _shot(camera, web.rect.get_center()))
	save_still("spider_torn.png")
	var sheet: Image = Image.create(SIZE * 4, SIZE * 2, false, shots[0].get_format())
	for k: int in range(shots.size()):
		sheet.blit_rect(shots[k], Rect2i(0, 0, SIZE, SIZE), Vector2i((k % 4) * SIZE, (k / 4) * SIZE))
	save_still("spider.png", sheet)
	# Its death: the relic where it falls.
	for i: int in range(Spider.EYES):
		if is_instance_valid(spider) and spider.wound.hp > 0:
			spider.wound.hit(1, Vector2.RIGHT)
	await within(func() -> bool: return not is_instance_valid(spider) or spider.dead_t > Spider.DIE_TIME * 0.4, 4.0)
	if is_instance_valid(spider):
		camera.global_position = spider.global_position
		camera.reset_smoothing()
		await frames(2)
		save_still("spider_dying.png")
		await until(gone(spider))
	await frames(20)
	var relics: Array[Node] = placed("relic.tscn")
	if not relics.is_empty():
		camera.global_position = (relics[0] as Node2D).global_position
		camera.reset_smoothing()
		await frames(4)
		save_still("spider_relic.png")
	RunState.delete_save()
	finish()


## The middle of the open cell on row `row` farthest from any hole under it.
func _spot(row: int) -> Vector2:
	var w: LevelGen = info.world
	var inside: Rect2i = w.keep["inside"]
	var best: Vector2i = Vector2i(inside.position.x, row)
	var best_d: int = -1
	for x: int in range(inside.position.x, inside.end.x):
		if not w.is_ground(Vector2i(x, row + 1)):
			continue
		var d: int = 999
		for h: Rect2i in w.keep["holes"]:
			if h.position.y == row + 1:
				d = mini(d, mini(absi(x - h.position.x), absi(x - (h.end.x - 1))))
		if d > best_d:
			best_d = d
			best = Vector2i(x, row)
	return info.cell_position(best)


## A close-up round `at`, with the camera on it.
func _shot(camera: Camera2D, at: Vector2) -> Image:
	for i: int in range(3):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	var sp: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * at)
	var x: int = clampi(int(sp.x) - SIZE / 2, 0, 1280 - SIZE)
	var y: int = clampi(int(sp.y) - SIZE / 2, 0, 720 - SIZE)
	return root.get_texture().get_image().get_region(Rect2i(x, y, SIZE, SIZE))
