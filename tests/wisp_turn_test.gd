extends TestKit
## The wisp's shape and its turn (WispArt, Mover): its body is a round head with flanks narrowing
## evenly to a point; turning round, its neck leaves its path, runs round a loop out ahead of it,
## most of it one tight circle, and comes back to the very spot it left facing the other way, going
## the way it points all the way round (never slid aside), its head leading and its tail following
## the path its neck has come; then it walks off with its tail straight behind it; walking at a
## wall it turns WALL_ROOM short of it, in the room left; and another wisp ahead on its floor closer
## than Mover.WISP_GAP turns it, looked for only among the wisps near its height.
## godot --headless --path . --script res://tests/wisp_turn_test.gd

## A wisp's collision box reaches this far ahead of its origin.
const BOX_HALF: float = 16.0
## How far the middle of its head leads its neck (px).
const HEAD_LEADS: float = WispArt.HEAD_X - WispArt.NECK_X
## How far a measure may be off (px): its length's spring is never quite still, and its spine is a
## chain of straight steps.
const NEAR: float = 2.0
## How far its tail's point may lie from the path its neck has come (px): it wags (WispArt.WAG),
## and the whole wisp bobs as it goes (WispArt.BOB), so the path's older points were laid at
## another height.
const TRAILS: float = 7.0
## How far off the way it points its neck may go in a frame (radians): its bob moves it a little
## across its way.
const STRAYS: float = 0.3
## How far a wisp walks on before it is turned (px), and how long it gets to walk to a wall, in
## physics frames.
const WALK_ON: float = 20.0
const WALK_FRAMES: int = 600


func run() -> void:
	# It reads what the art does (TestKit.art).
	art(true)
	body_shape()
	turn_shape()
	await boot()
	freeze()
	player.get_node("CameraControl").set_process(false)
	player.global_position = Vector2(-9000, -9000)
	wisps_meet()
	# The test's wisp has the level to itself: no other wisp turns it.
	for other: Node in placed("mover_enemy.tscn").slice(1):
		other.queue_free()
	await process_frame
	await open_turn()
	await wall_turn()
	finish()


## The body's outline (WispArt.drop): as long and as thick as it says, the same above its spine as
## below, its head round, and from its head back its flanks narrowing evenly to a point, as a cone's.
func body_shape() -> void:
	var nose: float = WispArt.NOSE_X
	var tail: float = WispArt.NOSE_X - WispArt.LENGTH
	var head_r: float = WispArt.GIRTH * 0.5
	var body: PackedVector2Array = WispArt.drop(nose, head_r, tail, WispArt.TAIL_GIRTH * 0.5)
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	var mirrored: bool = true
	var head_round: bool = true
	var head_c: Vector2 = Vector2(nose - head_r, 0.0)
	for p: Vector2 in body:
		lo = lo.min(p)
		hi = hi.max(p)
		var twin: bool = false
		for q: Vector2 in body:
			twin = twin or q.distance_to(Vector2(p.x, -p.y)) < 0.01
		mirrored = mirrored and twin
		if p.x >= head_c.x:
			head_round = head_round and absf(p.distance_to(head_c) - head_r) < 0.01
	check(absf(hi.x - nose) < 0.01 and absf(lo.x - tail) < 0.01, "it is %.0f px long, nose to point" % (hi.x - lo.x))
	check(absf(hi.y - head_r) < 0.2 and absf(lo.y + head_r) < 0.2, "and %.0f px thick at its head" % (hi.y - lo.y))
	check(mirrored, "the same above its spine as below")
	check(head_round, "its head is round")
	# Its half width from just ahead of its point to just behind the middle of its head: ever
	# wider toward the head, and by the same amount each step (a straight flank).
	var narrows: bool = true
	var bend: float = 0.0
	var step: float = 5.0
	var x: float = tail + 3.0
	while x + 2.0 * step < head_c.x - 4.0:
		var a: float = half_width(body, x)
		var b: float = half_width(body, x + step)
		var c: float = half_width(body, x + 2.0 * step)
		narrows = narrows and a < b and b < c
		bend = maxf(bend, absf(a - 2.0 * b + c))
		x += step
	check(narrows, "it narrows all the way from its head to its point")
	check(bend < 0.5, "evenly, as a cone does (its flank off straight by %.2f px at most)" % bend)
	check(half_width(body, tail + 0.5) < 2.0, "to a point (%.1f px across by its end)" % (2.0 * half_width(body, tail + 0.5)))
	# Cut into pieces to print, the pieces cover the outline between them: as much area.
	var pieces: float = 0.0
	for piece: PackedVector2Array in WispArt.rungs(body):
		pieces += area(piece)
	check(absf(pieces - area(body)) < 0.5, "printed in pieces (its head, then rungs across its tail), which cover it between them")
	check(absf(WispArt.eased(0.0)) < 0.001 and absf(WispArt.eased(1.0) - 1.0) < 0.001 and absf(WispArt.eased(0.5) - 0.5) < 0.001 and WispArt.eased(0.01) < 0.001, "its moves ease in and out (slow away from rest, slow into it)")


## How far the outline `poly` reaches from the spine (y = 0) at `x`.
func half_width(poly: PackedVector2Array, x: float) -> float:
	var widest: float = 0.0
	for i: int in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		if (a.x - x) * (b.x - x) <= 0.0 and a.x != b.x:
			widest = maxf(widest, absf(lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))))
	return widest


## The area inside the outline `poly`.
func area(poly: PackedVector2Array) -> float:
	var twice: float = 0.0
	for i: int in range(poly.size()):
		twice += poly[i].cross(poly[(i + 1) % poly.size()])
	return absf(twice) * 0.5


## The turn's loop (WispArt.turn_path), for a wisp facing either way: it leaves its path where the
## turn begins, the way it was going, and comes back to that very spot going the other way; it runs
## smoothly and the way it points all the way round; most of it is one tight circle; and it hangs
## under its path more than it stands over it.
func turn_shape() -> void:
	var r: float = WispArt.TURN_R
	var length: float = WispArt.turn_length()
	check(2.0 * r < WispArt.LENGTH * 0.5, "the turn's circle is tight: %.0f px across, to a body %.0f px long" % [2.0 * r, WispArt.LENGTH])
	for side: float in [1.0, -1.0]:
		var which: String = "facing right" if side > 0.0 else "facing left"
		var before: Vector3 = WispArt.turn_path(-10.0, side)
		var start: Vector3 = WispArt.turn_path(0.0, side)
		var end: Vector3 = WispArt.turn_path(length, side)
		var after: Vector3 = WispArt.turn_path(length + 10.0, side)
		check(absf(before.x + side * 10.0) < 0.001 and absf(before.y) < 0.001 and Vector2(start.x, start.y).length() < 0.001 and absf(cos(start.z) - side) < 0.001, "%s: it leaves its path where the turn begins, the way it was going" % which)
		check(Vector2(end.x, end.y).length() < 0.01 and absf(cos(end.z) + side) < 0.001 and absf(sin(end.z)) < 0.001, "%s: and comes back to that very spot going the other way" % which)
		check(absf(after.x + side * 10.0) < 0.01 and absf(after.y) < 0.01, "%s: and on back along its path" % which)
		var smooth: bool = true
		var pointed: bool = true
		var on_circle: int = 0
		var lowest: float = 0.0
		var highest: float = 0.0
		var furthest: float = 0.0
		var centre: Vector2 = Vector2(side * WispArt._loop_ahead, WispArt.TURN_LOW)
		var last: Vector3 = start
		var steps: int = 400
		for i: int in range(1, steps + 1):
			var at: Vector3 = WispArt.turn_path(length * float(i) / float(steps), side)
			var here: Vector2 = Vector2(at.x, at.y)
			smooth = smooth and absf(at.z - last.z) < 0.05
			# It goes the way it points: each step lies along its heading there.
			var mid: float = (at.z + last.z) * 0.5
			pointed = pointed and (here - Vector2(last.x, last.y)).normalized().dot(Vector2(cos(mid), -sin(mid))) > 0.999
			if absf(here.distance_to(centre) - r) < 0.01:
				on_circle += 1
			lowest = maxf(lowest, at.y)
			highest = minf(highest, at.y)
			furthest = maxf(furthest, at.x * side)
			last = at
		check(smooth, "%s: it runs smoothly all the way round (its heading never jumps)" % which)
		check(pointed, "%s: and goes the way it points all the way round" % which)
		check(on_circle > steps / 2, "%s: most of it one circle %.0f px in radius (%d%% of the way round)" % [which, r, on_circle * 100 / steps])
		check(furthest > 2.0 * r and lowest > -highest and -highest < r, "%s: out ahead of where it turned (%.0f px), hanging %.0f px under its path and standing %.0f over it" % [which, furthest, lowest, -highest])
	check(absf(WispArt.turn_pace(0.0, length)) < 0.001 and absf(WispArt.turn_pace(1.0, length) - 1.0) < 0.001 and WispArt.turn_pace(0.5, length) > 0.49 and WispArt.turn_pace(0.25, length) < 0.25, "it sets out round it slowly and is quickest half way")


## A wisp turned round on a floor with open air ahead: its neck goes round the loop the way it
## points, back to where it began, its tail following the path its neck has come; and it walks off
## the other way with its tail straight behind it.
func open_turn() -> void:
	var spot: Vector2i = floor_spot(func(v: Vector2i) -> bool: return floor_at(v + Vector2i.LEFT) and open_at(v + Vector2i.RIGHT))
	check(spot != Vector2i(-1, -1), "a floor with open air ahead")
	if spot == Vector2i(-1, -1):
		return
	var w: Node2D = await settle_wisp(spot + Vector2i.LEFT, 1)
	var mover: Mover = w.get_node("Mover") as Mover
	var art: WispArt = art_of(w)
	var from: float = w.global_position.x
	await until(func() -> bool: return w.global_position.x > from + WispArt.TAIL_BACK + WALK_ON)
	var side: float = float(mover.direction)
	var leads: Vector2 = art.head_at() - art.neck_at()
	var trails: Vector2 = art.tip_at() - art.neck_at()
	check(absf(leads.x - side * HEAD_LEADS) < NEAR and absf(leads.y) < NEAR, "walking, its head leads its neck, level")
	check(absf(trails.x + side * WispArt.TAIL_BACK) < NEAR and absf(trails.y) < TRAILS, "and its tail trails straight behind (%.0f px)" % (-trails.x * side))
	mover.turn()
	await until(func() -> bool: return art._facing == mover.direction)
	var stood: float = w.global_position.x
	# The path its neck has come: the straight run in (as long as its tail), then where it is seen.
	var start: Vector2 = art.neck_at()
	var path: PackedVector2Array = PackedVector2Array([start - Vector2(side * (WispArt.TAIL_BACK + 8.0), 0.0), start])
	var held: bool = true
	var pointed: bool = true
	var tail_on: bool = true
	var deepest: float = 0.0
	var highest: float = 0.0
	var furthest: float = 0.0
	var last_neck: Vector2 = start
	var last_nose: float = art._nose
	# Not on the turn's last frame: then the mover, which times the turn in physics steps, may have
	# ended it and stepped off, while the art, which adds up its frames' times, draws its last bit.
	var last_frame: float = 1.0 / float(Engine.physics_ticks_per_second)
	while art.t - art._turn_t0 < Mover.TURN_TIME - last_frame:
		var neck: Vector2 = art.neck_at()
		held = held and absf(w.global_position.x - stood) < 0.5
		var step: Vector2 = neck - last_neck
		if step.length() > 0.5:
			var mid: float = (art._nose + last_nose) * 0.5
			pointed = pointed and absf(step.angle_to(Vector2(cos(mid), -sin(mid)))) < STRAYS
			path.append(neck)
		tail_on = tail_on and off_path(art.tip_at(), path) < TRAILS
		deepest = maxf(deepest, neck.y - start.y)
		highest = minf(highest, neck.y - start.y)
		furthest = maxf(furthest, (neck.x - start.x) * side)
		last_neck = neck
		last_nose = art._nose
		await process_frame
	check(held, "its Mover holds it where it stood through the turn")
	check(pointed, "its neck goes the way it points all the way round, never slid aside")
	check(tail_on, "and its tail's point follows the path its neck has come")
	var reach: float = WispArt._loop_ahead + WispArt.TURN_R
	var slack: float = 2.0 * WispArt.BOB + NEAR
	check(absf(furthest - reach) < NEAR and absf(deepest - (WispArt.TURN_LOW + WispArt.TURN_R)) < slack and absf(-highest - (WispArt.TURN_R - WispArt.TURN_LOW)) < slack, "round its loop: %.0f px ahead, %.0f under its path and %.0f over it" % [furthest, deepest, -highest])
	check(absf(last_neck.x - start.x) < 2.0 * NEAR and absf(last_neck.y - start.y) < slack, "back to where it began (%.1f px off)" % last_neck.distance_to(start))
	# Walking off: once it has gone its tail's length, its tail is straight behind it again.
	await until(func() -> bool: return mover.turn_left <= 0.0)
	await until(func() -> bool: return side * (stood - w.global_position.x) > WispArt.TAIL_BACK + WALK_ON)
	leads = art.head_at() - art.neck_at()
	trails = art.tip_at() - art.neck_at()
	check(mover.direction == -int(side) and absf(leads.x + side * HEAD_LEADS) < NEAR and absf(leads.y) < NEAR, "it walks off the other way, its head leading")
	check(absf(trails.x - side * WispArt.TAIL_BACK) < NEAR and absf(trails.y) < TRAILS, "its tail straight behind it again")


## A wisp walking at a wall turns round WALL_ROOM short of it, and its head stays clear of the wall
## as it comes round.
func wall_turn() -> void:
	# Any floor running up to a wall, with floor before it, that the wisp can walk along: something
	# standing there (a star, a switch, the ink well) does not stop it; a door, a gate or thorns would.
	var walkable: Callable = func(c: Vector2i) -> bool: return open_at(c) and info.world.ground_below(c) \
			and info.world.get_cell(c).type not in [LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.SPIKES, LevelGen.Type.PLATFORM]
	var spot: Vector2i = Vector2i(-1, -1)
	for x: int in range(info.world.size.x):
		for y: int in range(info.world.size.y):
			var v: Vector2i = Vector2i(x, y)
			if spot == Vector2i(-1, -1) and walkable.call(v) and info.world.is_ground(v + Vector2i.RIGHT) and walkable.call(v + Vector2i.LEFT):
				spot = v
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
	var nearest: float = INF
	while mover.turn_left > 0.0:
		nearest = minf(nearest, face - (art.head_at().x + WispArt.GIRTH * 0.5))
		await process_frame
	check(nearest > 0.0, "and turns in the room left (its head %.0f px short of the wall at the nearest)" % nearest)


## Another wisp ahead on the same floor, closer than WISP_GAP, turns a wisp round; one on another
## floor, further off or behind does not; one moved since the wisps were sorted by height this
## step is seen where it is now; and every wisp of the level decides as looking at every other
## wisp would.
func wisps_meet() -> void:
	var wisps: Array[Node] = placed("mover_enemy.tscn", true)
	check(wisps.size() >= 3, "wisps to meet (%d)" % wisps.size())
	if wisps.size() < 3:
		return
	var same: bool = true
	for w: Node in wisps:
		var m: Mover = w.get_node("Mover") as Mover
		same = same and m._wisp_ahead() == every_wisp_ahead(m)
	check(same, "each wisp finds a wisp ahead exactly as looking at every wisp of the level would")
	var a: Node2D = wisps[0] as Node2D
	var b: Node2D = wisps[1] as Node2D
	var ma: Mover = a.get_node("Mover") as Mover
	var mb: Mover = b.get_node("Mover") as Mover
	ma.set_physics_process(false)
	mb.set_physics_process(false)
	var at: Vector2 = a.global_position
	var was_b: Vector2 = b.global_position
	var was_dir: int = ma.direction
	ma.direction = 1
	# Each placement is looked at with the wisps sorted afresh, as in a later physics step.
	var ahead: Callable = func(offset: Vector2) -> bool:
		b.global_position = at + offset
		Mover._bands_step = -1
		return ma._wisp_ahead()
	check(ahead.call(Vector2(Mover.WISP_GAP - 10.0, 0)), "a wisp ahead on the same floor, closer than WISP_GAP, turns it")
	check(not ahead.call(Vector2(Mover.WISP_GAP - 10.0, -Mover.SAME_FLOOR - 6.0)), "one on another floor does not")
	check(not ahead.call(Vector2(Mover.WISP_GAP + 10.0, 0)), "nor one further off")
	check(not ahead.call(Vector2(-(Mover.WISP_GAP - 10.0), 0)), "nor one behind it")
	b.global_position = at + Vector2(Mover.WISP_GAP - 10.0, Mover.SAME_FLOOR - 6.0)
	check(ma._wisp_ahead(), "one moved since the wisps were sorted this step is seen where it is now")
	b.global_position = was_b
	ma.direction = was_dir
	ma.set_physics_process(true)
	mb.set_physics_process(true)


## Whether another wisp is ahead of `m`'s on its floor closer than WISP_GAP, looking at every wisp.
func every_wisp_ahead(m: Mover) -> bool:
	for other: Node in m.get_tree().get_nodes_in_group(&"wisps"):
		if other == m.rb:
			continue
		var d: Vector2 = (other as Node2D).global_position - m.rb.global_position
		if absf(d.y) < Mover.SAME_FLOOR and d.x * float(m.direction) > 0.0 and absf(d.x) < Mover.WISP_GAP:
			return true
	return false


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
	await until(func() -> bool: return mover.grounded and mover.turn_left <= 0.0 and art.t - art._turn_t0 > Mover.TURN_TIME)
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
