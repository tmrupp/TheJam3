extends TestKit
## Stills of the worm (Worm) in its gate level: about to come up (its hole throbbing), half out of a
## hole, up and crawling after the wizard, half down a hole, then cut in the middle and split in
## two (both halves stunned and pale), then one of the short ends burrowing away, and a burrow
## hole in a floor, one in a wall or ceiling and one at the end of a space a cell wide. Written whole (worm_*.png) and as a sheet of close-ups (worm.png).
## Also captures the thorns turned to the inside of its bends (worm_thorns_inside.png), the mouth
## near the wizard (worm_mouth.png), a strip of its chomps (worm_chomp.png), a bite slamming shut
## and just after (worm_bite_slam.png, worm_bite.png), shut in its rest (worm_recovery.png), a
## strike beat by beat (worm_strike.png), crawling round a bend, its thorns riding along
## (worm_thorns_crawl.png), and going into a wall, the hole dug as its nose reaches the face
## (worm_dig.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_worm.gd

const SIZE: int = 420
## The chomp strip (worm_chomp.png): frames, and each one's size.
const CHOMP_FRAMES: int = 8
const CHOMP_SIZE: int = 220
## Each frame of the strike, crawl and dig strips (worm_strike, worm_thorns_crawl, worm_dig.png).
const STRIP_SIZE: int = 300


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
	# The same, its thorns turned to the other flank (on the inside of its bends).
	worm.set_physics_process(false)
	worm_piece.side = -worm_piece.side
	worm._place(worm_piece)
	save_still("worm_thorns_inside.png", await _shot(camera, worm_piece.segments[1].global_position))
	worm_piece.side = -worm_piece.side
	worm._place(worm_piece)
	worm.set_physics_process(true)
	# The mouth and its rest, with the wizard close enough to make it gape but outside the bite.
	worm.set_physics_process(false)
	var head: WormSegment = worm_piece.segments[0]
	var wizard_was: Vector2 = player.global_position
	player.global_position = head.global_position + head.heading * (head.radius + 40.0)
	save_still("worm_mouth.png", await _shot(camera, head.global_position))
	# Its chomps: a strip of frames 0.06 s apart, the worm's clock driven by hand. The wizard stays
	# where they are (the mouth works by how near they are) but is hidden, so the mouth shows.
	worm.set_process(false)
	player.visible = false
	var chomps: Image = Image.create(CHOMP_SIZE * CHOMP_FRAMES, CHOMP_SIZE, false, Image.FORMAT_RGBA8)
	for f: int in range(CHOMP_FRAMES):
		worm._process(0.06)
		var still: Image = await _shot(camera, head.global_position)
		still.convert(Image.FORMAT_RGBA8)
		chomps.blit_rect(still, Rect2i((SIZE - CHOMP_SIZE) / 2, (SIZE - CHOMP_SIZE) / 2, CHOMP_SIZE, CHOMP_SIZE), Vector2i(f * CHOMP_SIZE, 0))
	save_still("worm_chomp.png", chomps)
	# A bite: the jaws slamming shut, then shut with the strokes thrown out.
	worm.bit(head)
	worm_piece.recovery = Worm.BITE_RECOVERY - Worm.BITE_SNAP * 0.4
	worm._process(0.0)
	save_still("worm_bite_slam.png", await _shot(camera, head.global_position))
	worm_piece.recovery = Worm.BITE_RECOVERY - 0.1
	worm._process(0.0)
	save_still("worm_bite.png", await _shot(camera, head.global_position))
	worm_piece.recovery = 0.2
	worm._process(0.0)
	save_still("worm_recovery.png", await _shot(camera, head.global_position))
	worm_piece.recovery = 0.0
	# A strike, beat by beat: paused, drawn back, lunging, at full reach, snapped shut, settling.
	worm_piece.strike = -1.0
	worm_piece.reach = 0.0
	worm_piece.strike_wait = 0.0
	worm.hunting = true
	worm._place(worm_piece)
	player.global_position = head.global_position + head.heading * worm.cell * 0.9
	if worm._can_strike(worm_piece):
		worm_piece.strike = 0.0
		var beats: Array[float] = [0.15, 0.45, 0.65, 0.72, 0.77, 0.86, 1.0, 1.2]
		var strike: Array[Image] = []
		var at: Vector2 = head.global_position
		var clock: float = 0.0
		for beat: float in beats:
			worm._step(worm_piece, beat - clock)
			clock = beat
			worm._place(worm_piece)
			worm._process(0.0)
			strike.append(await _shot(camera, at))
		save_still("worm_strike.png", _strip(strike, STRIP_SIZE))
	else:
		print("no room to strike here")
	worm_piece.strike = -1.0
	worm_piece.reach = 0.0
	player.global_position = wizard_was
	worm._place(worm_piece)
	# Crawling round a bend, 0.1 s a frame: its thorns ride along, shrinking on the inside of the bend
	# and growing again past it.
	worm.hunting = false
	var bend_at: Vector2 = worm_piece.segments[1].global_position
	for k: int in range(1, worm_piece.segments.size() - 1):
		if worm_piece.segments[k].heading.dot(worm_piece.segments[k + 1].heading) < 0.5:
			bend_at = worm_piece.segments[k].global_position
			break
	var crawl: Array[Image] = []
	for f: int in range(8):
		for n: int in range(3):
			worm._step(worm_piece, 1.0 / 30.0)
		worm._place(worm_piece)
		worm._process(0.1)
		crawl.append(await _shot(camera, bend_at))
	save_still("worm_thorns_crawl.png", _strip(crawl, STRIP_SIZE))
	# Into a wall, 0.15 s a frame: the hole is dug as its nose reaches the face.
	var dig: Array[Image] = []
	var spot: Array[Vector2i] = []
	var w: LevelGen = info.world
	for c: Vector2i in worm.lair:
		for d: Vector2i in Worm.DIRS:
			if spot.is_empty() and w.is_ground(c + d) and Worm.passable(w, c - d) and Worm.passable(w, c - d * 2) 					and not worm.holes.any(func(h: Worm.Hole) -> bool: return h.cell == c + d):
				spot = [c, d]
	if not spot.is_empty():
		var c: Vector2i = spot[0]
		var d: Vector2i = spot[1]
		for i: int in range(worm_piece.cells.size()):
			worm_piece.cells[i] = c - d * (i + 1)
		worm_piece.next = c
		worm_piece.after = c + d
		worm_piece.u = 0.3
		worm_piece.hole = -1
		worm_piece.clock = 99.0
		worm._place(worm_piece)
		var face: Vector2 = (worm.center(c) + worm.center(c + d)) * 0.5
		for f: int in range(8):
			worm._step(worm_piece, 0.15)
			worm._place(worm_piece)
			worm._process(0.15)
			dig.append(await _shot(camera, face - Vector2(d) * worm.cell * 0.6))
		save_still("worm_dig.png", _strip(dig, STRIP_SIZE))
	worm.set_process(true)
	player.visible = true
	player.global_position = wizard_was
	worm._place(worm_piece)
	worm.set_physics_process(true)
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
	# A hole dug in a wall or a ceiling, if there is one: the ground heaps up there too, without turf.
	var other: Array = worm.holes.filter(func(h: Worm.Hole) -> bool: return h.out.dot(Vector2.UP) < 0.5)
	if not other.is_empty():
		shots.append(await _shot(camera, (other[0] as Worm.Hole).mouth))
	# One dug at the end of a space a cell wide (no way on either side of the cell in front of it),
	# else one with a wall on one side: its earth heaps against the walls rather than over them.
	var narrow: Variant = null
	var walls: int = 0
	for c: Vector2i in worm.lair:
		for d: Vector2i in Worm.DIRS:
			var across: Vector2i = Vector2i(d.y, -d.x)
			var shut: int = (0 if Worm.passable(info.world, c + across) else 1) + (0 if Worm.passable(info.world, c - across) else 1)
			if info.world.is_ground(c + d) and shut > walls:
				walls = shut
				narrow = [c, d]
	print("narrowest hole spot: walls ", walls)
	if narrow != null:
		var tight: Worm.Hole = worm.holes[worm._hole_at(narrow[0] + narrow[1], narrow[0])]
		save_still("worm_hole_narrow.png", await _shot(camera, tight.mouth))
		shots.append(await _shot(camera, tight.mouth))
	print("holes ", worm.holes.map(func(h: Worm.Hole) -> String: return "%s out %s" % [h.cell, h.out]))
	var sheet: Image = Image.create(SIZE * shots.size(), SIZE, false, shots[0].get_format())
	for k: int in range(shots.size()):
		sheet.blit_rect(shots[k], Rect2i(0, 0, SIZE, SIZE), Vector2i(k * SIZE, 0))
	save_still("worm.png", sheet)
	RunState.delete_save()
	finish()


## `frames` side by side, each cropped to `size` round its middle.
func _strip(frames: Array[Image], size: int) -> Image:
	var out: Image = Image.create(size * frames.size(), size, false, Image.FORMAT_RGBA8)
	for f: int in range(frames.size()):
		var still: Image = frames[f]
		still.convert(Image.FORMAT_RGBA8)
		out.blit_rect(still, Rect2i((SIZE - size) / 2, (SIZE - size) / 2, size, size), Vector2i(f * size, 0))
	return out


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
