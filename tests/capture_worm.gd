extends TestKit
## Stills of the worm (Worm) in its gate level: about to come up (its hole throbbing), half out of a
## hole, up and crawling after the wizard, half down a hole, then cut in the middle and split in
## two (both halves stunned and pale), then one of the short ends burrowing away, and a burrow
## hole. Written whole (worm_*.png) and as a sheet of close-ups (worm.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_worm.gd

const SIZE: int = 420


func run() -> void:
	window()
	await boot(28)
	info.coord = Vector2i(28, NextWorldDef.GARDEN_ROWS)
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	var worm: Worm = placed("worm.tscn")[0] as Worm
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.health.max_health = 99
	player.health.health = 99
	# Stand the wizard on a floor in the lair, a little way from where the worm was placed.
	var stand: Variant = LevelGen.best_of(info.world.free_floors(), func(v: Vector2i) -> int: return absi(LevelGen.dist(v, worm.home) - 6), func(v: Vector2i) -> bool: return worm.lair.has(v))
	player.global_position = info.cell_position(stand as Vector2i)
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	var shots: Array[Image] = []
	var worm_piece: Worm.Piece = worm.pieces[0]
	# About to come up: the hole throbs and spits dirt.
	await until(func() -> bool: return worm_piece.warn > 0.0 and worm_piece.warn < Worm.EMERGE_WARN * 0.4)
	shots.append(await _shot(camera, (worm.center(worm_piece.cells[0]) + worm.center(worm_piece.next)) * 0.5))
	save_still("worm_warning.png")
	# Half out of its hole.
	await until(func() -> bool: return worm_piece.state == Worm.UP and worm_piece.segments[2].shown and not worm_piece.segments[4].shown)
	shots.append(await _shot(camera, worm_piece.segments[2].global_position))
	save_still("worm_rising.png")
	await until(func() -> bool: return worm_piece.state == Worm.UP and worm_piece.segments.all(func(s: WormSegment) -> bool: return s.shown))
	await frames(40)
	shots.append(await _shot(camera, worm_piece.segments[0].global_position))
	save_still("worm_up.png")
	# Half down a hole: sent to the nearest.
	worm_piece.hole = worm._nearest_hole(worm_piece.cells[0])
	await until(func() -> bool: return worm_piece.state == Worm.DIVING and not worm_piece.segments[3].shown and worm_piece.segments[5].shown, 20000)
	shots.append(await _shot(camera, worm.holes[worm_piece.hole].mouth if worm_piece.hole >= 0 else worm_piece.segments[5].global_position))
	save_still("worm_sinking.png")
	await until(func() -> bool: return worm_piece.state == Worm.UP and worm_piece.segments.all(func(s: WormSegment) -> bool: return s.shown), 20000)
	await frames(20)
	var middle: WormSegment = worm.pieces[0].segments[5]
	var at: Vector2 = middle.global_position
	while is_instance_valid(middle) and not middle.is_queued_for_deletion():
		middle.wound.hit(1, middle.spikes)
	await frames(6)
	shots.append(await _shot(camera, at))
	save_still("worm_split.png")
	# Cut the front half down to two: it burrows away.
	var front: Worm.Piece = worm.pieces[0]
	while front.segments.size() > Worm.SHORTEST:
		var tail: WormSegment = front.segments[front.segments.size() - 1]
		tail.wound.hit(tail.wound.hp, tail.spikes)
	await frames(20)
	shots.append(await _shot(camera, front.segments[0].global_position if not front.segments.is_empty() else at))
	save_still("worm_burrow.png")
	shots.append(await _shot(camera, worm.holes[0].mouth))
	print("holes ", worm.holes.map(func(h: Worm.Hole) -> String: return "%s out %s" % [h.cell, h.out]))
	var sheet: Image = Image.create(SIZE * shots.size(), SIZE, false, shots[0].get_format())
	for k: int in range(shots.size()):
		sheet.blit_rect(shots[k], Rect2i(0, 0, SIZE, SIZE), Vector2i(k * SIZE, 0))
	save_still("worm.png", sheet)
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
