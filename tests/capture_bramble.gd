extends TestKit
## Stills of the bramble (Bramble) in its gate level: the head of its shaft asleep (the sealed way on,
## no crown yet), its crown growing out of the rock and grown, quivering from a blow, a vine lashing
## out, a vine's shoots warning, a bulb in bloom and one shut in its bark, a seed in flight, the sap
## running on to the next bulb, a burst bulb and its withered vine, the crown drawn back a little to
## show the bud, the heart bared, a bulb opened again, wild, for its last stand, the heart shut after
## a wound, its death (its canes drying from the heart out, drawing back into the rock, then the
## roots), and the relic left on the landing. Written
## whole (bramble_*.png) and as a sheet of close-ups (bramble.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_bramble.gd

const SIZE: int = 420


func run() -> void:
	window()
	await boot(28)
	await go(lair(&"bramble"), false)
	var bramble: Bramble = placed("bramble.tscn")[0] as Bramble
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	sturdy()
	freeze()
	player.global_position = Vector2(-9000, -9000)
	var shots: Array[Image] = []
	# The head asleep: no crown yet beside the sealed way on.
	var head: Vector2 = bramble.knot_rect.get_center() + Vector2(0, 60)
	shots.append(await _shot(camera, head))
	save_still("bramble_asleep.png")
	# Its crown growing out of the rock, and grown.
	bramble.wake()
	await until(func() -> bool: return bramble.tangle.grown() > 0.45)
	shots.append(await _shot(camera, head))
	save_still("bramble_growing.png")
	await until(func() -> bool: return bramble.tangle.grown() >= 1.0)
	await frames(10)
	shots.append(await _shot(camera, head))
	save_still("bramble_head.png")
	# Struck: it quivers from the blow.
	bramble.quiver(bramble.knot_rect.get_center() + Vector2(0, bramble.knot_rect.size.y * 0.4), Bramble.QUIVER_BURST)
	var struck_at: float = bramble.t
	await until(func() -> bool: return bramble.t - struck_at > 0.12)
	shots.append(await _shot(camera, head))
	save_still("bramble_quiver.png")
	# A vine lashing out, and its shoots warning.
	var vine: BrambleVine = bramble.vines[0]
	await until(func() -> bool: return vine.phase()[0] == &"hold")
	shots.append(await _shot(camera, vine.global_position + vine.way * 140.0))
	save_still("bramble_vine.png")
	await until(func() -> bool: return vine.phase()[0] == &"warn" and float(vine.phase()[1]) > 0.5)
	shots.append(await _shot(camera, vine.global_position + vine.way * 60.0))
	# A bulb in bloom, and one shut in its bark.
	var bulb: BrambleBulb = bramble.bulbs[0]
	bramble.bloom_on(bulb)
	await frames(30)
	shots.append(await _shot(camera, bulb.global_position + bulb.way * 120.0))
	save_still("bramble_bulb.png")
	var shut: BrambleBulb = bramble.bulbs[1]
	shots.append(await _shot(camera, shut.global_position + shut.way * 120.0))
	save_still("bramble_shut.png")
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
	# Wounded, the bloom's sap runs on to the next bulb.
	bulb.wound.hit(1, -bulb.way)
	await until(func() -> bool: return bramble.sap_to != null and bramble.sap_u > 0.3)
	shots.append(await _shot(camera, bramble.sap_at()))
	save_still("bramble_sap.png")
	player.global_position = Vector2(-9000, -9000)
	# A bulb burst, its vine withered.
	var fed: BrambleVine = vine
	bramble.bloom_on(fed.bulb)
	fed.bulb.wound.hit(Bramble.BULB_HP, Vector2.RIGHT)
	await frames(30)
	shots.append(await _shot(camera, (fed.global_position + fed.bulb.global_position) * 0.5))
	save_still("bramble_burst.png")
	# A bulb burst, the crown draws back a little from the bud hidden in it.
	await until(func() -> bool: return is_equal_approx(bramble.bare, bramble.bare_to()))
	await frames(10)
	shots.append(await _shot(camera, head))
	save_still("bramble_peek.png")
	# The last bulb: the crown draws back to bare its heart, for its last stand.
	for b: BrambleBulb in bramble.bulbs:
		if b.alive:
			bramble.bloom_on(b)
			b.wound.hit(Bramble.BULB_HP, Vector2.RIGHT)
	var ledge: Vector2i = info.world.shaft["ledges"][0]
	player.global_position = info.cell_position(ledge + Vector2i.UP)
	await until(func() -> bool: return bramble.bare >= 1.0)
	await frames(20)
	shots.append(await _shot(camera, head + Vector2(0, 40)))
	save_still("bramble_heart.png")
	var heart: BrambleHeart = bramble.heart
	# A bulb opened again, wild, spitting at the wizard.
	var wild: BrambleBulb = bramble.bulbs[0]
	player.global_position = wild.global_position + wild.way * bramble.cell * 2.2 + Vector2(0, 80)
	var wild_spat: int = wild.spat
	await until(func() -> bool: return wild.spat > wild_spat)
	await frames(12)
	shots.append(await _shot(camera, wild.global_position + wild.way * 150.0))
	save_still("bramble_wild.png")
	# The heart wounded, its sepals shut over it.
	player.global_position = info.cell_position(ledge + Vector2i.UP)
	heart.wound.hit(1, Vector2.UP)
	await frames(20)
	shots.append(await _shot(camera, head + Vector2(0, 40)))
	save_still("bramble_closed.png")
	player.global_position = Vector2(-9000, -9000)
	await until(func() -> bool: return heart.open())
	# The heart burst: its canes dry from the heart out, then draw back into the rock, the crown's
	# first, then the roots down the walls.
	heart.wound.hit(heart.wound.hp, Vector2.UP)
	await until(func() -> bool: return not is_instance_valid(bramble) or bramble.dying_t > 0.3)
	shots.append(await _shot(camera, head))
	save_still("bramble_dry.png")
	await until(func() -> bool: return not is_instance_valid(bramble) or bramble.dying_t > 0.95)
	shots.append(await _shot(camera, head))
	save_still("bramble_open.png")
	await until(func() -> bool: return not is_instance_valid(bramble) or bramble.dying_t > bramble.dying_end * 0.6)
	if is_instance_valid(bramble):
		shots.append(await _shot(camera, bramble.center(Vector2i(bramble.inside.get_center().x, bramble.inside.position.y + 6))))
		save_still("bramble_roots.png")
	if is_instance_valid(bramble):
		await until(gone(bramble))
	await frames(20)
	shots.append(await _shot(camera, head))
	save_still("bramble_relic.png")
	@warning_ignore("integer_division")
	var sheet: Image = Image.create(SIZE * 4, SIZE * ((shots.size() + 3) / 4), false, shots[0].get_format())
	for k: int in range(shots.size()):
		@warning_ignore("integer_division")
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
	@warning_ignore("integer_division")
	var x: int = clampi(int(sp.x) - SIZE / 2, 0, 1280 - SIZE)
	@warning_ignore("integer_division")
	var y: int = clampi(int(sp.y) - SIZE / 2, 0, 720 - SIZE)
	return root.get_texture().get_image().get_region(Rect2i(x, y, SIZE, SIZE))
