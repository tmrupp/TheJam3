extends TestKit
## Stills of the bramble (Bramble) in its gate level: the head of its shaft (the knot beside the
## sealed way on), a bulb and a vine lashing out, a vine's shoots warning, a seed in flight, a
## burst bulb and its withered vine, the knot tearing open, and the relic left on the landing.
## Written whole (bramble_*.png) and as a sheet of close-ups (bramble.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_bramble.gd

const SIZE: int = 420


func run() -> void:
	window()
	await boot(28)
	info.coord = Vector2i(28, -NextWorldDef.GARDEN_ROWS)
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	var bramble: Bramble = placed("bramble.tscn")[0] as Bramble
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.health.max_health = 99
	player.health.health = 99
	player.set_physics_process(false)
	player.global_position = Vector2(-9000, -9000)
	var shots: Array[Image] = []
	# The head: the knot beside the landing and the sealed way on.
	var head: Vector2 = bramble.knot_rect.get_center() + Vector2(0, 60)
	shots.append(await _shot(camera, head))
	save_still("bramble_head.png")
	# A vine lashing out, with a bulb.
	var vine: BrambleVine = bramble.vines[0]
	await until(func() -> bool: return vine.phase()[0] == &"hold")
	shots.append(await _shot(camera, vine.global_position + vine.way * 140.0))
	save_still("bramble_vine.png")
	await until(func() -> bool: return vine.phase()[0] == &"warn" and float(vine.phase()[1]) > 0.5)
	shots.append(await _shot(camera, vine.global_position + vine.way * 60.0))
	var bulb: BrambleBulb = bramble.bulbs[0]
	shots.append(await _shot(camera, bulb.global_position + bulb.way * 120.0))
	save_still("bramble_bulb.png")
	# A seed in flight at the wizard.
	player.global_position = bulb.global_position + bulb.way * bramble.cell * 2.2 + Vector2(0, 80)
	var spat: int = bulb.spat
	await until(func() -> bool: return bulb.spat > spat)
	var seeds: Array[Node] = placed("bullet.tscn", true).filter(func(n: Node) -> bool: return (n as Bullet).seed)
	if not seeds.is_empty():
		var seed: Node2D = seeds[seeds.size() - 1] as Node2D
		await until(func() -> bool: return not is_instance_valid(seed) or seed.global_position.distance_to(bulb.mouth()) > 90.0)
	shots.append(await _shot(camera, bulb.global_position + bulb.way * 150.0))
	save_still("bramble_seed.png")
	player.global_position = Vector2(-9000, -9000)
	# A bulb burst, its vine withered.
	var fed: BrambleVine = vine
	fed.bulb.wound.hit(Bramble.BULB_HP, Vector2.RIGHT)
	await frames(30)
	shots.append(await _shot(camera, (fed.global_position + fed.bulb.global_position) * 0.5))
	save_still("bramble_burst.png")
	# The last bulb: the knot tears open.
	for b: BrambleBulb in bramble.bulbs:
		if b.alive:
			b.wound.hit(Bramble.BULB_HP, Vector2.RIGHT)
	await until(func() -> bool: return not is_instance_valid(bramble) or bramble.open_u > 0.35)
	shots.append(await _shot(camera, head))
	save_still("bramble_open.png")
	if is_instance_valid(bramble):
		await until(gone(bramble))
	await frames(20)
	shots.append(await _shot(camera, head))
	save_still("bramble_relic.png")
	var sheet: Image = Image.create(SIZE * 4, SIZE * 2, false, shots[0].get_format())
	for k: int in range(shots.size()):
		sheet.blit_rect(shots[k], Rect2i(0, 0, SIZE, SIZE), Vector2i((k % 4) * SIZE, (k / 4) * SIZE))
	save_still("bramble.png", sheet)
	RunState.delete_save()
	finish()


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
