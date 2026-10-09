extends TestKit
## The wisp's turn (WispArt, Mover): it turns round along a teardrop that its path cuts in half,
## the point where the wisp turns and the round end ahead, dipping under its path first and coming
## back over the top; its head stays on the drop and its tail follows it; and walking at a wall it
## turns WALL_ROOM short of it, its drop fitted to the room left.
## godot --headless --path . --script res://tests/wisp_turn_test.gd

## A wisp's collision box reaches this far ahead of its origin.
const BOX_HALF: float = 16.0
## A point this close to the drop (or to the path walked before it) is on it, in pixels.
const ON_PATH: float = 1.0
## The body's reach behind its head (WispArt._wisp_sample), in pixels.
const BODY_REACH: float = 22.0 * 3.6 * 1.1
## How long a wisp gets to walk to a wall, in physics frames.
const WALK_FRAMES: int = 600


func run() -> void:
	drop_shape()
	await boot()
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	player.global_position = Vector2(-9000, -9000)
	# The test's wisp has the level to itself: no other wisp turns it or shrinks its drop.
	for other: Node in placed("mover_enemy.tscn").slice(1):
		other.queue_free()
	await process_frame
	await open_turn()
	await wall_turn()
	finish()


## The drop itself, in drop lengths.
func drop_shape() -> void:
	var start: Array = WispArt.wisp_loop(0.0)
	var end: Array = WispArt.wisp_loop(1.0)
	check((start[0] as Vector2).length() < 0.001 and absf(float(start[1])) < 0.001, "the drop starts at its point, heading on along the path")
	check((end[0] as Vector2).length() < 0.001 and absf(float(end[1]) + PI) < 0.001, "it ends back at its point heading the other way, half a turn round")
	var front: Array = WispArt.wisp_loop(0.5)
	check((front[0] as Vector2).distance_to(Vector2(1, 0)) < 0.001 and absf(float(front[1]) + PI * 0.5) < 0.001, "it crosses its path once, at the round end, heading straight up")
	var halves: bool = true
	var sides: bool = true
	var sharpest: float = 0.0
	var widest: Vector2 = Vector2.ZERO
	var at_point: float = 0.0
	var steps: int = 200
	for i: int in range(1, steps):
		var e: float = float(i) / float(steps)
		var here: Array = WispArt.wisp_loop(e)
		var p: Vector2 = here[0]
		var back: Vector2 = WispArt.wisp_loop(1.0 - e)[0]
		halves = halves and p.distance_to(Vector2(back.x, -back.y)) < 0.001
		if i != steps / 2:
			sides = sides and (p.y > 0.0) == (e < 0.5)
		sharpest = maxf(sharpest, absf(float(here[1]) - float(WispArt.wisp_loop(float(i - 1) / float(steps))[1])))
		if absf(p.y) > absf(widest.y):
			widest = p
		if p.x < 0.15:
			at_point = maxf(at_point, absf(p.y))
	check(halves, "its path cuts it in half: the half back is the half out mirrored across it")
	check(sides, "it dips under its path, then comes back over the top")
	check(sharpest < 0.15, "its heading turns smoothly all the way round (at most %.3f a step)" % sharpest)
	check(widest.x > 0.5 and at_point < absf(widest.y) * 0.4, "a drop: narrow by its point (%.2f), widest toward its round end (%.2f at %.2f along)" % [at_point, absf(widest.y), widest.x])
	check(absf(absf(widest.y) - WispArt.wisp_drop_half()) < 0.002, "its half height is the one the art fits to the room")


## A wisp turned round on a floor with open air ahead: the full drop, its head on it all the way
## round, and its tail following the drop and, behind that, the path it walked before.
func open_turn() -> void:
	var spot: Vector2i = floor_spot(func(v: Vector2i) -> bool: return floor_at(v + Vector2i.LEFT) and open_at(v + Vector2i.RIGHT))
	check(spot != Vector2i(-1, -1), "a floor with open air ahead")
	if spot == Vector2i(-1, -1):
		return
	# Settled a cell back and walked on a body's length, so all its tail lies along the floor walk.
	var w: Node2D = await settle_wisp(spot + Vector2i.LEFT, 1)
	var mover: Mover = w.get_node("Mover") as Mover
	var art: WispArt = art_of(w)
	var from: float = w.global_position.x
	await until(func() -> bool: return w.global_position.x > from + BODY_REACH + 8.0)
	mover.turn()
	await until(func() -> bool: return art.wisp_to == float(mover.direction))
	var side: float = art.wisp_from
	check_eq(art.wisp_drop_len, WispArt.WISP_DROP_LEN, "in the open the drop is full size")
	var point: Vector2 = Vector2.INF
	var head_on: bool = true
	var tail_on: bool = true
	var drop: PackedVector2Array = PackedVector2Array()
	var round_px: float = WispArt.wisp_drop_round() * art.wisp_drop_len
	while art.t - art.wisp_turn_t0 < Mover.TURN_TIME:
		# Where the drop's point is, from where the head is on it now: the same every frame while
		# the head stays on the drop.
		var at: Vector2 = art._trail[0] - art._drop_at(art._drop_e, side)
		if point == Vector2.INF:
			point = at
			for i: int in range(257):
				drop.append(point + art._drop_at(float(i) / 256.0, side))
		head_on = head_on and at.distance_to(point) < ON_PATH
		# Behind the head: the drop as far as the head has come round it, then the path walked
		# to its point.
		var behind: float = 0.0
		for n: int in range(art._trail.size()):
			if n > 0:
				behind += art._trail[n].distance_to(art._trail[n - 1])
			if behind > BODY_REACH:
				break
			var p: Vector2 = art._trail[n]
			if behind < art._drop_e * round_px - ON_PATH:
				tail_on = tail_on and off_path(p, drop) < ON_PATH
			elif behind > art._drop_e * round_px + ON_PATH:
				tail_on = tail_on and absf(p.y - point.y) < ON_PATH and side * (p.x - point.x) < ON_PATH
		await process_frame
	check(head_on, "the head stays on the drop all the way round")
	check(tail_on, "the tail follows the drop, and behind it the path walked before the turn")
	var ahead: float = 0.0
	var below: float = 0.0
	var above: float = 0.0
	for p: Vector2 in drop:
		ahead = maxf(ahead, side * (p.x - point.x))
		below = maxf(below, p.y - point.y)
		above = maxf(above, point.y - p.y)
	var half: float = WispArt.wisp_drop_half() * art.wisp_drop_len
	check(absf(ahead - art.wisp_drop_len) < 0.5 and absf(below - half) < 0.5 and absf(above - half) < 0.5, "it reaches %.0f px ahead, and %.0f px under and over its path" % [ahead, half])
	await until(func() -> bool: return mover.turn_left <= 0.0)
	await frames(10)
	check(mover.direction == -int(side) and absf(art._trail[0].y - point.y) < ON_PATH and side * (art._trail[0].x - point.x) < -1.0, "it walks off the other way along its path")


## A wisp walking at a wall turns round WALL_ROOM short of it, and its drop fits the room left.
func wall_turn() -> void:
	var spot: Vector2i = floor_spot(func(v: Vector2i) -> bool: return info.world.is_ground(v + Vector2i.RIGHT) and floor_at(v + Vector2i.LEFT))
	check(spot != Vector2i(-1, -1), "a floor running up to a wall")
	if spot == Vector2i(-1, -1):
		return
	var w: Node2D = await settle_wisp(spot + Vector2i.LEFT, 1)
	var mover: Mover = w.get_node("Mover") as Mover
	var art: WispArt = art_of(w)
	var face: float = info.cell_position(spot + Vector2i.RIGHT).x - art.half
	var closest: float = INF
	for f: int in range(WALK_FRAMES):
		if mover.direction != 1:
			break
		closest = minf(closest, face - (w.global_position.x + BOX_HALF))
		await physics_frame
	check(mover.direction == -1, "it turns before the wall")
	check(absf(closest - Mover.WALL_ROOM) < 2.0, "it turns %.0f px short of the wall (WALL_ROOM %.0f)" % [closest, Mover.WALL_ROOM])
	await until(func() -> bool: return art.wisp_to == -1.0)
	var room: float = face - w.global_position.x - WispArt.WISP_NOSE
	check(art.wisp_drop_len <= room + 0.01 and art.wisp_drop_len >= WispArt.WISP_DROP_MIN, "its drop fits the room before the wall (%.0f px of %.0f)" % [art.wisp_drop_len, room])


## The first free floor cell passing `test`; (-1, -1) if there is none.
func floor_spot(test: Callable) -> Vector2i:
	for v: Vector2i in info.world.free_floors():
		if test.call(v):
			return v
	return Vector2i(-1, -1)


## A cell nothing solid fills.
func open_at(v: Vector2i) -> bool:
	return info.world.is_valid(v) and info.world.get_cell(v).type not in [LevelGen.Type.GROUND, LevelGen.Type.CRACKED]


## An open cell with rock under it.
func floor_at(v: Vector2i) -> bool:
	return info.world.is_valid(v) and info.world.get_cell(v).type == LevelGen.Type.EMPTY and info.world.ground_below(v)


## The wisp, moved to the middle of `cell`, settled on its floor facing `dir` with any turn done,
## and the camera on it (so its chunk is awake and its art draws). It is woken where it is before
## it is moved (a sleeping chunk's bodies are out of the physics world), and moved with its Mover
## paused, so the physics world takes the new place before the Mover moves the body on from it.
func settle_wisp(cell: Vector2i, dir: int) -> Node2D:
	var w: Node2D = placed("mover_enemy.tscn")[0] as Node2D
	var mover: Mover = w.get_node("Mover") as Mover
	var art: WispArt = art_of(w)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	camera.global_position = w.global_position
	camera.reset_smoothing()
	await until(func() -> bool: return info.loader.is_awake(w))
	mover.set_physics_process(false)
	w.global_position = info.cell_position(cell)
	camera.global_position = w.global_position
	camera.reset_smoothing()
	await frames(2)
	mover.set_physics_process(true)
	if mover.direction != dir:
		mover.turn()
	await until(func() -> bool: return mover.grounded and mover.turn_left <= 0.0 and art.t - art.wisp_turn_t0 > Mover.TURN_TIME)
	await frames(4)
	return w


func art_of(w: Node2D) -> WispArt:
	for c: Node in w.get_children():
		if c is WispArt:
			return c as WispArt
	return null


## How far `p` is from the line through `points`.
func off_path(p: Vector2, points: PackedVector2Array) -> float:
	var best: float = INF
	for i: int in range(points.size() - 1):
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1]).distance_to(p))
	return best
