extends TestKit
## Real dash inputs against the worm's solid body, bite recovery, round head and bite shapes,
## and an awakened worm staying active when its original burrow's chunk goes to sleep.
## godot --headless --path . --script res://tests/worm_combat_test.gd


func run() -> void:
	await boot(28)
	info.coord = Vector2i(28, NextWorldDef.GARDEN_ROWS)
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	var worm: Worm = placed("worm.tscn")[0] as Worm
	var far: Variant = LevelGen.best_of(info.world.free_floors(), func(v: Vector2i) -> int: return -LevelGen.dist(v, worm.home))
	player.global_position = info.cell_position(far as Vector2i)
	info.loader.sleep_far_chunks(true, player.global_position)
	check(not worm.awake and worm.process_mode == Node.PROCESS_MODE_DISABLED, "a dormant worm still sleeps in a distant chunk")
	player.global_position = worm.center(worm.home)
	info.loader.sleep_far_chunks(true, player.global_position)
	check(await until(func() -> bool: return worm.pieces[0].segments[0].live, 15000), "it wakes and comes out")
	var p: Worm.Piece = worm.pieces[0]
	player.global_position = info.cell_position(far as Vector2i)
	info.loader.sleep_far_chunks(true, player.global_position)
	check(not info.loader.is_awake(worm) and worm.visible and worm.process_mode == Node.PROCESS_MODE_INHERIT, "the original burrow sleeps, but the awakened worm stays visible and active")
	var was_u: float = p.u
	check(await until(func() -> bool: return p.u != was_u, 2000), "it keeps crawling while far from its original burrow")
	worm.set_physics_process(false)
	# A real collider outside the terrain: only this head is live, and gravity is off so each dash
	# meets the same solid edge without a floor, other segments or chunk sleeping affecting it.
	worm.remove_meta(&"cell")
	var head: WormSegment = p.segments[0]
	for segment: WormSegment in p.segments:
		segment.set_live(false)
		segment.sync_touch()
	var test_at: Vector2 = Vector2(-10000, -10000)
	head.global_position = test_at
	head.set_live(true)
	head.sync_touch()
	player.gravity = 0.0
	player.health.max_health = 99
	player.health.health = 99
	player.set_collision_mask_value(WormSegment.WORM_LAYER, true)
	var circle: CircleShape2D = head.bite.collision.shape as CircleShape2D
	check(circle != null and is_equal_approx(circle.radius, head.radius) and head.bite.scale == Vector2.ONE, "the bite and the solid head have the same round edge")
	var mouth_flesh: Array[PackedVector2Array] = worm._bite_out([RisoShapes.circle(test_at, head.radius)], worm._jaw(head, head.radius * 2.0, 1.0))
	var rear: Vector2 = test_at - head.heading * head.radius * 0.8
	var nose: Vector2 = test_at + head.heading * head.radius * 0.8
	check(mouth_flesh.any(func(poly: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(rear, poly)) and not mouth_flesh.any(func(poly: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(nose, poly)), "the Pac-Man mouth cuts open the front while keeping the back of the round head")
	check(mouth_flesh.any(func(poly: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(test_at, poly)), "the shallow mouth leaves flesh across the head's middle, clear of its health dots")
	var strike: DashStrike = player.get_node("DashStrike") as DashStrike
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP, Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]:
		head.global_position = test_at
		head.wound.hp = Worm.SEGMENT_HP
		player.global_position = test_at - direction * 150.0
		player.velocity = Vector2.ZERO
		player.knock = Vector2.ZERO
		player.knock_back.end()
		player.dash.end()
		player.dash.refresh()
		player.dash_rest = 0.0
		await frames(3)
		player.set_physics_process(true)
		var blocked: bool = await _dash(direction)
		player.set_physics_process(false)
		check(head.wound.hp == Worm.SEGMENT_HP - 1 and blocked, "a solid edge blocks the dash but takes exactly one hit, heading %s (hp %d, blocked %s)" % [direction, head.wound.hp, blocked])
		check(not head.stunned() and player.health.health == 99, "the dash neither stuns the worm nor hurts the wizard")
		await frames(20)
	# A blink's virtual path also uses the body, without striking a nearby segment it misses.
	head.global_position = test_at
	head.wound.hp = Worm.SEGMENT_HP
	strike.struck.clear()
	var miss_height: float = head.radius + player.collider.shape.get_rect().size.y * player.collider.global_scale.y * 0.5 + 5.0
	strike.sweep(test_at + Vector2(-200, -miss_height), test_at + Vector2(200, -miss_height))
	check(head.wound.hp == Worm.SEGMENT_HP, "a path that misses the solid head does not wound it")
	strike.sweep(test_at + Vector2(-200, 0), test_at + Vector2(200, 0))
	check(head.wound.hp == Worm.SEGMENT_HP - 1, "a blink across the head still cuts it")
	player.dash.end()
	strike.guard_left = 0.0
	player.end_invulnerable()
	p.recovery = 0.0
	head.recovering = false
	head.sync_touch()
	player.global_position = test_at + Vector2(10, 0)
	check(await until(func() -> bool: return p.recovery > 0.0, 2000), "a real bite starts its piece's recovery")
	player.global_position = test_at + Vector2(200, 0)
	await frames(2)
	check(head.bite.collision.disabled and head.live, "its resting head is harmless but stays solid and attackable")
	var resting_hp: int = head.wound.hp
	strike.strike(head, Vector2.RIGHT)
	check(head.wound.hp == resting_hp - 1, "the resting head takes a strike, without a stun's double damage")
	was_u = p.u
	var was_clock: float = p.clock
	worm._step(p, Worm.BITE_RECOVERY * 0.5)
	check(p.u == was_u and p.clock == was_clock, "biting pauses the whole piece, including its crawl timer")
	worm._step(p, Worm.BITE_RECOVERY * 0.5 + 0.01)
	worm._place(p)
	await frames(2)
	check(not head.recovering and not head.bite.collision.disabled, "the head can bite again after recovery")
	worm._step(p, 1.0 / 60.0)
	check(p.u != was_u, "the piece resumes crawling after recovery")
	_chomps(worm, p)
	_thorns(worm)
	_strikes(worm, p)
	RunState.delete_save()
	finish()


## The mouth chomps right at the wizard (snapping shut, springing wide), holds still a little open
## far off, and on a bite springs wide, slams shut within BITE_SNAP and stays shut while it rests.
func _chomps(worm: Worm, p: Worm.Piece) -> void:
	var head: WormSegment = p.segments[0]
	p.recovery = 0.0
	var shut: float = 1.0
	var wide: float = 0.0
	var far_off: Array[float] = []
	for k: int in range(240):
		worm.t = float(k) / 60.0
		var g: float = worm._gape(p, false, head.global_position)
		shut = minf(shut, g)
		wide = maxf(wide, g)
		far_off.append(worm._gape(p, false, Vector2.INF))
	check(shut < 0.05 and wide > 0.9, "right at the wizard its jaws chomp, shut to wide (%.2f to %.2f)" % [shut, wide])
	check(far_off.all(func(g: float) -> bool: return is_equal_approx(g, Worm.MOUTH_CLOSED)), "far off they hold still, a little open")
	p.recovery = Worm.BITE_RECOVERY
	check(worm._gape(p, false, head.global_position) > 0.95, "biting, they spring wide")
	p.recovery = Worm.BITE_RECOVERY - Worm.BITE_SNAP
	check(worm._gape(p, false, head.global_position) < 0.01, "and slam shut")
	p.recovery = Worm.BITE_RECOVERY * 0.5
	check(worm._gape(p, false, head.global_position) < 0.01, "and stay shut while it rests")
	check(is_equal_approx(worm._gape(p, true, head.global_position), Worm.MOUTH_REST), "stunned, they hang nearly shut")
	p.recovery = 0.0


## Thorns grow from fixed places along the body: four a side on a straight cell, the same four
## carried along as it moves on; round a bend those outside stand fully grown and those squeezed on
## the inside not at all.
func _thorns(worm: Worm) -> void:
	var open: Callable = func(v: Vector2i) -> bool: return Worm.passable(info.world, v)
	var bend: Variant = null
	var straight: Variant = null
	for v: Vector2i in worm.lair:
		if bend == null and open.call(v + Vector2i.UP) and open.call(v + Vector2i.LEFT) and open.call(v):
			bend = v
		if straight == null and open.call(v + Vector2i.RIGHT) and open.call(v + Vector2i.LEFT) and open.call(v):
			straight = v
	check(bend != null and straight != null, "the lair has a bend and a straight to try")
	if bend == null or straight == null:
		return
	var width: float = worm.cell * Worm.GIRTH
	var c: Vector2i = bend
	var turn: Array[Vector2i] = [c + Vector2i.UP, c, c + Vector2i.LEFT]
	var spots: Array = worm.thorn_spots(turn, 0.5, 1.5, width)
	var corner: Vector2 = worm.center(c) + Vector2(-1, -1) * worm.cell * 0.5
	var outside: Callable = func(e: Array) -> bool: return (e[0] as Vector2).distance_to(corner) > worm.cell * 0.5
	check(spots.size() == Worm.THORNS_ALONG and spots.all(outside) and spots.all(func(e: Array) -> bool: return float(e[2]) > 0.99), "round a bend the four outside are fully grown, none on the squeezed inside")
	var s: Vector2i = straight
	var line: Array[Vector2i] = [s + Vector2i.RIGHT, s, s + Vector2i.LEFT]
	var here: Array = worm.thorn_spots(line, 0.5, 1.5, width)
	check(here.size() == Worm.THORNS_ALONG * 2 and here.all(func(e: Array) -> bool: return float(e[2]) > 0.99), "on a straight cell, four a side, fully grown")
	# A tenth of a cell on, every thorn has moved a tenth of a cell with the body.
	var on: Array = worm.thorn_spots(line, 0.4, 1.4, width)
	var moved: bool = on.size() == here.size()
	for k: int in range(mini(on.size(), here.size())):
		moved = moved and is_equal_approx(((on[k][0] as Vector2) - (here[k][0] as Vector2)).length(), worm.cell * 0.1)
	check(moved, "they ride along with the body as it moves")
	# Its scales: on the thorny half only.
	var plates: Array[PackedVector2Array] = worm.scale_plates(line, 1.0, 0.5, 1.5, width)
	var across: Vector2 = worm.facing(line, 1.0).orthogonal()
	var middle: Vector2 = worm.point(line, 1.0)
	var thorny_half: bool = not plates.is_empty()
	for plate: PackedVector2Array in plates:
		for q: Vector2 in plate:
			thorny_half = thorny_half and (q - middle).dot(across) > 0.0
	check(thorny_half, "its scales lie on the thorny half of the body, the bare half soft")
	# Into a hole: those down in the rock do not show through it.
	var h: Worm.Hole = worm.holes[0]
	var diving: Array[Vector2i] = [h.cell, h.cell, h.cell, h.cell, h.entry, h.entry + (h.entry - h.cell)]
	var into: Array = worm.thorn_spots(diving, 2.5, 4.5, width)
	check(not into.is_empty() and into.all(func(e: Array) -> bool: return Worm.passable(info.world, info.cell_at((e[0] as Vector2) - (e[1] as Vector2) * width * 0.5))), "going into a hole, only those beside flesh out in the open show")


## A strike: it pauses, draws its head back, lunges out past where it lies and settles back, its
## jaws opening as it draws back and snapping shut at full reach, the piece held still throughout
## and resting after.
func _strikes(worm: Worm, p: Worm.Piece) -> void:
	var total: float = Worm.STRIKE_PAUSE + Worm.STRIKE_PULL + Worm.STRIKE_LUNGE + Worm.STRIKE_HOLD + Worm.STRIKE_RETURN
	var least: float = 0.0
	var most: float = 0.0
	var when_most: float = 0.0
	for k: int in range(int(total * 200.0) + 1):
		var r: float = Worm._strike_reach(float(k) / 200.0)
		least = minf(least, r)
		if r > most:
			most = r
			when_most = float(k) / 200.0
	check(Worm._strike_reach(Worm.STRIKE_PAUSE * 0.5) == 0.0, "it pauses first")
	check(is_equal_approx(least, -Worm.PULL_BACK) and is_equal_approx(most, Worm.LUNGE_REACH), "then draws back and lunges out")
	check(when_most > Worm.STRIKE_PAUSE + Worm.STRIKE_PULL, "the lunge comes after the draw back")
	check(Worm._strike_reach(total) == 0.0, "and settles back where it lies")
	check(Worm._strike_gape(Worm.STRIKE_PAUSE + Worm.STRIKE_PULL) > 0.99 and Worm._strike_gape(Worm.STRIKE_PAUSE + Worm.STRIKE_PULL + Worm.STRIKE_LUNGE + Worm.STRIKE_HOLD) < 0.01, "its jaws open wide drawing back and snap shut at full reach")
	# A live strike, the wizard just ahead of its head.
	p.recovery = 0.0
	p.strike = -1.0
	p.reach = 0.0
	p.strike_wait = 0.0
	p.state = Worm.UP
	worm.hunting = true
	worm._place(p)
	var head: WormSegment = p.segments[0]
	var rest_at: Vector2 = head.global_position
	var side: Vector2 = head.heading.orthogonal()
	player.global_position = rest_at + head.heading * worm.cell * (Worm.STRIKE_RANGE + 0.3)
	check(not worm._can_strike(p), "it does not strike at the wizard beyond its lunge")
	player.global_position = rest_at + head.heading * worm.cell * 0.8 + side * worm.cell * (Worm.STRIKE_ACROSS + 0.3)
	check(not worm._can_strike(p), "nor at the wizard off to one side")
	player.global_position = rest_at + head.heading * worm.cell * 0.9
	if not worm._can_strike(p):
		check(false, "it strikes at the wizard just ahead (no room to lunge here)")
		return
	var was_u: float = p.u
	# Where its head should get to along its path: drawn back, and lunged out.
	var path: Array[Vector2i] = p.path()
	var drawn: Vector2 = worm.point(path, p.at(0) + Worm.PULL_BACK)
	var lunged: Vector2 = worm.point(path, p.at(0) - Worm.LUNGE_REACH)
	var near_drawn: float = INF
	var near_lunged: float = INF
	var steps: int = int(total * 60.0) + 2
	for k: int in range(steps):
		worm._step(p, 1.0 / 60.0)
		worm._place(p)
		near_drawn = minf(near_drawn, head.global_position.distance_to(drawn))
		near_lunged = minf(near_lunged, head.global_position.distance_to(lunged))
	check(p.u == was_u, "it holds still while it strikes")
	check(near_drawn < 4.0 and near_lunged < 4.0 and rest_at.distance_to(lunged) > worm.cell * 0.5, "its head draws back, then lunges out along its way past where it lay")
	check(p.strike < 0.0 and p.strike_wait > 0.0 and is_zero_approx(p.reach), "then settles back and rests before striking again")


## Dash through actual input, holding all components of its direction until it stops.
func _dash(direction: Vector2) -> bool:
	var held: Array[StringName] = []
	if direction.x != 0.0:
		held.append(&"Right" if direction.x > 0.0 else &"Left")
	if direction.y != 0.0:
		held.append(&"Down" if direction.y > 0.0 else &"Up")
	for action: StringName in held:
		Input.action_press(action)
	var press: InputEventAction = InputEventAction.new()
	press.action = &"Dash"
	press.pressed = true
	Input.parse_input_event(press)
	var blocked: bool = false
	for i: int in range(10):
		await frames(1)
		blocked = blocked or player.get_slide_collision_count() > 0
	Input.action_release(&"Dash")
	for action: StringName in held:
		Input.action_release(action)
	return blocked
