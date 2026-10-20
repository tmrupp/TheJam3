extends TestKit
## Stills of what the spider (Spider) spits and strings, in its keep: a plain web across the well's
## hole, a glob of web in flight (WebShot), the splat it leaves stuck on the wizard, an egg sac
## (EggSac) in flight and swelling on a floor, the spiderlings (Spiderling) it hatches running at
## the wizard, and a crossbow in the keep's wall shooting into the hall. Written as one sheet of
## close-ups (spider_brood.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_spider_brood.gd

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
	var spider: Spider = placed("spider.tscn")[0] as Spider
	var keep: Dictionary = info.world.keep
	var inside: Rect2i = keep["inside"]
	var floors: Array[int] = keep["floors"]
	var shots: Array[Image] = []
	# A web across the well.
	player.global_position = Vector2(-9000, -9000)
	var web: SpiderWeb = spider.webs[1]
	shots.append(await _shot(camera, web.rect.get_center()))
	# A glob in flight at the wizard on the top floor, off to the side.
	var c: int = info.cell_at(spider.global_position).x
	var off: int = 6 if inside.end.x - 1 - c >= c - inside.position.x else -6
	player.global_position = info.cell_position(Vector2i(c + off, floors[0] - 1))
	spider.state = Spider.State.HUNT
	spider.spit_wait = 0.0
	await within(func() -> bool: return spider.brood.any(func(b: Node2D) -> bool: return b is WebShot), 4.0)
	var glob: Node2D = spider.brood.filter(func(b: Node2D) -> bool: return b is WebShot)[0]
	await frames(12)
	if is_instance_valid(glob):
		shots.append(await _shot(camera, glob.global_position))
	# The splat stuck on the wizard.
	await within(func() -> bool: return SpiderWeb.holding(self, player.global_position), 4.0)
	shots.append(await _shot(camera, player.global_position))
	# An egg sac, in flight and then swelling on a floor.
	await within(func() -> bool: return spider.state == Spider.State.HUNT, 10.0)
	c = info.cell_at(spider.global_position).x
	off = 6 if inside.end.x - 1 - c >= c - inside.position.x else -6
	player.global_position = info.cell_position(Vector2i(c + off, floors[0] - 1))
	spider.timer = 0.0
	spider.spits = Spider.EGG_EVERY - 1
	spider.spit_wait = 0.0
	await within(func() -> bool: return spider.brood.any(func(b: Node2D) -> bool: return b is EggSac), 4.0)
	spider.set_physics_process(false)
	var sac: EggSac = spider.brood.filter(func(b: Node2D) -> bool: return b is EggSac)[0] as EggSac
	await frames(10)
	shots.append(await _shot(camera, sac.global_position))
	await within(func() -> bool: return sac.landed and sac.hatching > EggSac.HATCH * 0.8, EggSac.HATCH + 3.0)
	shots.append(await _shot(camera, sac.global_position))
	# Its spiderlings, running at the wizard.
	await within(func() -> bool: return not get_nodes_in_group(&"spiderling").is_empty(), 3.0)
	await frames(40)
	var young: Node2D = get_nodes_in_group(&"spiderling")[0] as Node2D
	shots.append(await _shot(camera, young.global_position + Vector2(0, -30)))
	# A crossbow in the keep's wall, shooting into the hall.
	var bow: Crossbow = null
	for n: Node in placed("crossbow.tscn"):
		if (keep["crossbows"] as Array).has(n.get_meta(&"cell")):
			bow = n as Crossbow
	player.global_position = info.cell_position(bow.cell) + Vector2(float(bow.facing) * spider.cell * 3.0, 0.0)
	await within(func() -> bool: return bow.drawn > 0.7, 4.0)
	shots.append(await _shot(camera, bow.muzzle() + Vector2(float(bow.facing) * 60.0, 0.0)))
	var sheet: Image = Image.create(SIZE * 4, SIZE * 2, false, shots[0].get_format())
	for k: int in range(shots.size()):
		@warning_ignore("integer_division")
		sheet.blit_rect(shots[k], Rect2i(0, 0, SIZE, SIZE), Vector2i((k % 4) * SIZE, (k / 4) * SIZE))
	save_still("spider_brood.png", sheet)
	RunState.delete_save()
	finish()


## A close-up round `at`, with the camera on it.
func _shot(camera: Camera2D, at: Vector2) -> Image:
	for i: int in range(3):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	var sp: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * at)
	@warning_ignore("integer_division")
	var x: int = clampi(int(sp.x) - SIZE / 2, 0, 1280 - SIZE)
	@warning_ignore("integer_division")
	var y: int = clampi(int(sp.y) - SIZE / 2, 0, 720 - SIZE)
	return root.get_texture().get_image().get_region(Rect2i(x, y, SIZE, SIZE))
