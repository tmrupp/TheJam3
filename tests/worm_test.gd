extends TestKit
## The worm (Worm, docs/REGIONS_PLAN.md §6), the boss of the garden's way down, in its gate level:
## its lair along the walls of the whole level and its burrow holes all through it, lying under
## until the wizard comes near, waiting and rumbling before it comes up, hunting them, the head's
## bite and its solid body, never turning back on itself, its head never in the rock, digging
## through walls, thorns along one flank of every segment but the head, the flank facing the
## wizard as it comes out of the rock and kept until it goes in again (hurting to touch, and
## turning strikes from that side), the soft flesh any strike cuts (even a tool that
## only stuns) one segment a move, only a parried bite stunning it and then the whole worm, a cut
## head or tail shortening it, a middle cut splitting it, short worms burrowing away, a lantern
## death healing it, and its death opening the way on and leaving its relic on a floor.
## godot --headless --path . --script res://tests/worm_test.gd


func run() -> void:
	MapInfo.debug = false
	var g: int = NextWorldDef.GARDEN_ROWS
	await boot(28)
	player.set_physics_process(false)
	await _go(Vector2i(28, g))
	var worm: Worm = placed("worm.tscn")[0] as Worm

	print("the lair and its holes")
	var w: LevelGen = info.world
	var hugs: Callable = func(v: Vector2i) -> bool:
		for dx: int in range(-1, 2):
			for dy: int in range(-1, 2):
				if not w.is_valid(v + Vector2i(dx, dy)) or w.is_ground(v + Vector2i(dx, dy)):
					return true
		return false
	var span: Vector2i = Vector2i(w.size.x, 0)
	for v: Vector2i in worm.lair:
		span = Vector2i(mini(span.x, v.x), maxi(span.y, v.x))
	check(worm.boss == &"worm" and worm.lair.keys().all(hugs) and span.y - span.x > w.size.x / 2, "it crawls the walls, floors and ceilings of the whole level (%d cells)" % worm.lair.size())
	var holes_ok: bool = worm.holes.size() >= Worm.HOLES_MIN
	var hole_x: Vector2i = Vector2i(w.size.x, 0)
	for i: int in range(worm.holes.size()):
		var hole: Worm.Hole = worm.holes[i]
		holes_ok = holes_ok and info.world.is_ground(hole.cell) and worm.lair.has(hole.entry) and LevelGen.dist(hole.cell, hole.entry) == 1
		hole_x = Vector2i(mini(hole_x.x, hole.cell.x), maxi(hole_x.y, hole.cell.x))
		for j: int in range(i):
			holes_ok = holes_ok and LevelGen.dist(hole.cell, worm.holes[j].cell) >= Worm.HOLE_APART
	check(holes_ok and hole_x.y - hole_x.x > w.size.x / 2, "%d burrow holes all through the level, each dug into rock beside the lair, kept apart" % worm.holes.size())
	var holes: Array = worm.holes.map(func(h: Worm.Hole) -> Vector2i: return h.cell)
	await _go(Vector2i(28, g))
	worm = placed("worm.tscn")[0] as Worm
	check(worm.holes.map(func(h: Worm.Hole) -> Vector2i: return h.cell) == holes, "the same holes on every visit")
	check(worm.segments_left() == Worm.SEGMENTS and worm.pieces[0].segments.all(func(s: WormSegment) -> bool: return s.wound.hp == Worm.SEGMENT_HP), "%d segments, %d hits each" % [Worm.SEGMENTS, Worm.SEGMENT_HP])
	await frames(30)
	check(not worm.awake and worm.pieces[0].segments.all(func(s: WormSegment) -> bool: return not s.shown and not s.live), "with the wizard far off, it lies under the rock, out of reach")

	print("it comes up and hunts")
	player.health.max_health = 99
	player.health.health = 99
	var stand: Variant = LevelGen.best_of(info.world.free_floors(), func(v: Vector2i) -> int: return absi(LevelGen.dist(v, worm.home) - 6), func(v: Vector2i) -> bool: return worm.lair.has(v))
	player.global_position = info.cell_position(stand as Vector2i)
	# Standing there for real: the arrival's grace runs out only as the wizard's physics runs.
	player.set_physics_process(true)
	var warned: bool = await until(func() -> bool: return worm.pieces[0].warn > 0.0, 10000)
	check(warned and worm.awake and worm.pieces[0].segments.all(func(s: WormSegment) -> bool: return not s.shown), "the wizard coming near wakes it, and before it comes up it waits in its hole")
	var up: bool = await until(func() -> bool: return worm.pieces[0].state == Worm.UP and worm.pieces[0].segments[0].shown, 10000)
	check(up and worm.rumbles >= 3, "rumbling (%d times) before it bursts out" % worm.rumbles)
	var head: WormSegment = worm.pieces[0].segments[0]
	var bit: bool = await until(func() -> bool: return player.health.health < 99, 20000)
	check(bit, "it hunts the wizard down and bites")
	var turned_back: bool = false
	var side_was: float = worm.pieces[0].side
	var came_out: int = worm.emergences
	var switched: bool = false
	for f: int in range(360):
		await physics_frame
		var crawling: Worm.Piece = worm.pieces[0]
		turned_back = turned_back or (crawling.state == Worm.UP and crawling.next == crawling.cells[1])
		# Its thorns change sides only as it comes out of the rock.
		switched = switched or (crawling.side != side_was and worm.emergences == came_out)
		side_was = crawling.side
		came_out = worm.emergences
	check(not turned_back, "it never turns back on itself")
	check(not switched, "its thorns keep to one side until it comes out of the rock again")
	# Its head's rounded front, and so its mouth, never pushes into the rock.
	var poked: int = 0
	var beyond_hitbox: int = 0
	for f: int in range(240):
		await physics_frame
		for crawler: Worm.Piece in worm.pieces:
			var path: Array[Vector2i] = crawler.path()
			var front: float = crawler.at(0)
			for nose: PackedVector2Array in worm._cap(path, front, worm.cell * Worm.GIRTH, true):
				var base: Vector2 = worm.point(path, front)
				for pt: Vector2 in nose:
					if pt.distance_to(crawler.segments[0].global_position) > crawler.segments[0].radius + 0.01:
						beyond_hitbox += 1
					if not Worm.passable(w, info.cell_at(pt.move_toward(base, 2.0))):
						poked += 1
	check(poked == 0, "its head never noses into the rock (%d points in it)" % poked)
	check(beyond_hitbox == 0, "the head's visible front stays inside its round hitbox")

	print("it digs through walls")
	var q: Worm.Piece = worm.pieces[0]
	var face: Array[Vector2i] = []
	for c: Vector2i in worm.lair:
		for d: Vector2i in Worm.DIRS:
			if face.is_empty() and w.is_ground(c + d) and not worm.holes.any(func(h: Worm.Hole) -> bool: return h.cell == c + d):
				face = [c, c + d]
	for i: int in range(q.cells.size()):
		q.cells[i] = face[0]
	q.next = face[1]
	q.u = 0.95
	q.hole = -1
	q.clock = 99.0
	await frames(3)
	check(q.cells[0] == face[1] and worm.holes.any(func(h: Worm.Hole) -> bool: return h.cell == face[1] and h.entry == face[0]) and not q.segments[0].shown, "into a wall it digs a hole, and goes on through the rock out of sight")
	var breaking: bool = await until(func() -> bool: return q.warn > 0.0, 15000)
	check(breaking and not Worm.passable(w, q.cells[0]) and Worm.passable(w, q.next) and worm.holes.any(func(h: Worm.Hole) -> bool: return h.cell == q.cells[0] and h.entry == q.next), "about to break out of the rock, it waits at a hole of its own digging")
	var out: bool = await until(func() -> bool: return q.warn <= 0.0 and q.segments[0].shown, 5000)
	check(out, "and then bursts out")
	check(head.bite != null and worm.pieces[0].segments.slice(1).all(func(s: WormSegment) -> bool: return s.bite == null), "only the head bites")
	# Wait until most of it is out of the rock, then hold it there (it does not move while its own
	# physics is off) to strike it.
	var out_count: Callable = func() -> int: return worm.pieces[0].segments.filter(func(s: WormSegment) -> bool: return s.live).size()
	await until(func() -> bool: return worm.pieces[0].state == Worm.UP and out_count.call() >= 7, 30000)
	worm.set_physics_process(false)
	var segs: Array[WormSegment] = worm.pieces[0].segments
	var lit: Array[WormSegment] = segs.filter(func(s: WormSegment) -> bool: return s.live)
	var body: WormSegment = lit[1]
	var dash: DashStrike = player.get_node("DashStrike") as DashStrike
	var clear: Variant = LevelGen.best_of(w.free_floors(), func(v: Vector2i) -> int: return -LevelGen.dist(v, info.cell_at(body.global_position)))
	player.global_position = info.cell_position(clear as Vector2i)
	worm._unwedge(player)
	check(body.collision_layer == WormSegment.WORM_BIT and player.get_collision_mask_value(WormSegment.WORM_LAYER) and WormSegment.WORM_LAYER != DashStrike.ENEMY_LAYER, "its body is solid to the wizard, on a layer the dash does not pass through")
	check(body.is_in_group(&"hex_target"), "and struck as an enemy is")
	player.global_position = info.cell_position(stand as Vector2i)

	print("thorns")
	check(head.thorns == null and segs.slice(1).all(func(s: WormSegment) -> bool: return s.thorns != null), "every segment but the head has thorns")
	var thorny: WormSegment = lit[2]
	var flank: float = worm.pieces[0].side
	check(segs.slice(1).all(func(s: WormSegment) -> bool: return s.spikes.is_equal_approx(s.heading.orthogonal() * flank) and absf(angle_difference(s.thorns.rotation, s.spikes.angle())) < 0.01), "all along one flank of its body")
	check(Worm.side_toward(Vector2.UP, Vector2.ZERO, Vector2(200, -50)) == Vector2.UP.orthogonal().dot(Vector2.RIGHT) and Worm.side_toward(Vector2.UP, Vector2.ZERO, Vector2(-200, -50)) == -Vector2.UP.orthogonal().dot(Vector2.RIGHT), "coming out of the rock, it picks the flank facing the wizard")
	check(not thorny.thorn_box.collision.disabled, "and hurt to touch on that side")
	var thorny_hp: int = thorny.wound.hp
	thorny.wound.hit(1, -thorny.spikes)
	check(thorny.wound.hp == thorny_hp, "a strike from the thorny side glances off")
	thorny.wound.hit(1, thorny.spikes)
	check(thorny.wound.hp == thorny_hp - 1, "one from its bare side cuts")

	print("struck")
	var whole_hp: Callable = func() -> Array: return segs.map(func(s: WormSegment) -> int: return s.wound.hp)
	var before: Array = whole_hp.call()
	dash.damage = 0
	dash.struck.clear()
	# From its bare side (thorns facing on, the way the dash goes).
	lit[0].spikes = (lit[4].global_position - lit[0].global_position).normalized()
	dash.sweep(lit[0].global_position, lit[4].global_position)
	await frames(1)
	var after: Array = whole_hp.call()
	var cut_count: int = range(segs.size()).filter(func(k: int) -> bool: return int(after[k]) < int(before[k])).size()
	check(cut_count == 1 and lit[0].wound.hp == Worm.SEGMENT_HP - 1, "a dash along it (one that only stuns) cuts only the first segment it meets")
	check(not segs.any(func(s: WormSegment) -> bool: return s.stunned()), "and stuns nothing")
	var bolt: HexBolt = HexBolt.new()
	bolt.damage = 0
	bolt.pierce = true
	var target: WormSegment = lit[lit.size() - 1]
	info.map_elements.add_child(bolt)
	bolt.global_position = target.global_position - target.heading * 6.0
	bolt.dir = target.heading
	for seg: WormSegment in segs:
		seg.spikes = target.heading
	before = whole_hp.call()
	await frames(3)
	after = whole_hp.call()
	cut_count = range(segs.size()).filter(func(k: int) -> bool: return int(after[k]) < int(before[k])).size()
	check(cut_count == 1 and not segs.any(func(s: WormSegment) -> bool: return s.stunned()), "so does a hex bolt, even a piercing one (one segment), and it stuns nothing")
	worm.set_physics_process(true)
	var parry: Parry = player.get_node("Parry") as Parry
	var head_hp: int = head.wound.hp
	parry.parry(1, Vector2.ZERO, head.bite.get_node("Damager"))
	await frames(3)
	check(head.wound.hp == head_hp - 1 and segs.all(func(s: WormSegment) -> bool: return s.stunned()), "a parried bite to its face wounds the head and stuns the whole worm")
	check(head.bite.collision.disabled, "and a stunned head does not bite")
	var whole_one: WormSegment = segs.filter(func(s: WormSegment) -> bool: return s.live and s.wound.hp == Worm.SEGMENT_HP)[0]
	whole_one.spikes = Vector2.RIGHT
	dash.strike(whole_one, Vector2.RIGHT)
	check(whole_one.wound.hp == Worm.SEGMENT_HP - 2, "stunned, it takes double")

	print("cut")
	var tail: WormSegment = worm.pieces[0].segments[Worm.SEGMENTS - 1]
	tail.wound.hit(Worm.SEGMENT_HP, tail.spikes)
	await frames(2)
	check(worm.pieces.size() == 1 and worm.segments_left() == Worm.SEGMENTS - 1, "a tail cut off shortens it")
	head = worm.pieces[0].segments[0]
	var second: WormSegment = worm.pieces[0].segments[1]
	head.wound.hit(Worm.SEGMENT_HP, Vector2.RIGHT)
	await frames(2)
	check(worm.pieces.size() == 1 and worm.pieces[0].segments[0] == second and second.bite != null, "a head cut off: the next segment is the head, and bites")
	var n: int = worm.pieces[0].segments.size()
	var cut_at: int = 4
	var back_head: WormSegment = worm.pieces[0].segments[cut_at + 1]
	var middle: WormSegment = worm.pieces[0].segments[cut_at]
	middle.wound.hit(Worm.SEGMENT_HP, middle.spikes)
	await frames(2)
	check(worm.pieces.size() == 2 and worm.pieces[0].segments.size() == cut_at and worm.pieces[1].segments.size() == n - cut_at - 1, "a middle cut splits it in two (%d and %d)" % [worm.pieces[0].segments.size(), worm.pieces[1].segments.size()])
	check(worm.pieces[1].segments[0] == back_head and back_head.bite != null, "the back half grows a head at the cut")

	print("short worms burrow away")
	var front: Worm.Piece = worm.pieces[0]
	var mid: WormSegment = front.segments[1]
	mid.wound.hit(Worm.SEGMENT_HP, mid.spikes)
	await frames(2)
	check(worm.pieces.filter(func(p: Worm.Piece) -> bool: return p.state == Worm.DYING).size() == 2, "a worm of %d or fewer burrows away" % Worm.SHORTEST)
	check(worm.pieces.filter(func(p: Worm.Piece) -> bool: return p.state == Worm.DYING).all(func(p: Worm.Piece) -> bool: return p.segments.all(func(s: WormSegment) -> bool: return not s.live)), "out of reach as it goes")
	await until(func() -> bool: return worm.pieces.size() == 1, 5000)
	check(worm.pieces.size() == 1 and not info.run.bosses.has(&"worm"), "and is gone, while a worm is left")

	print("a death heals it")
	info.run.vulnerable = false
	player.die()
	await settle()
	await _go(Vector2i(28, g))
	worm = placed("worm.tscn")[0] as Worm
	check(worm.segments_left() == Worm.SEGMENTS and worm.pieces.size() == 1 and not info.run.bosses.has(&"worm"), "after a lantern death it is whole again")

	print("slain")
	player.global_position = info.cell_position(stand as Vector2i)
	await until(func() -> bool: return worm.pieces[0].segments.all(func(s: WormSegment) -> bool: return s.shown), 15000)
	while is_instance_valid(worm) and not worm.is_queued_for_deletion() and not worm.slain:
		var any: bool = false
		for p: Worm.Piece in worm.pieces:
			if p.state != Worm.DYING and not p.segments.is_empty() and p.segments[0].live:
				p.segments[0].wound.hit(Worm.SEGMENT_HP * 2, Vector2.RIGHT)
				any = true
				break
		if not any:
			await frames(1)
	await settle()
	check(info.run.bosses.has(&"worm") and placed("worm.tscn").is_empty(), "cut down to nothing, it is slain for the run")
	var relics: Array[Node] = placed("relic.tscn").filter(func(n: Node) -> bool: return n.get_meta(&"boss", &"") == &"worm")
	var on_floor: bool = relics.size() == 1 and info.world.free_floors().has(info.cell_at((relics[0] as Node2D).global_position))
	check(on_floor and (relics[0] as Relic).price() == 0, "its relic waits on a floor, free")
	check(_exit(MapInfo.Exit.DEEPER).sealed() == &"", "and the way on is open")
	await _go(Vector2i(28, g))
	check(placed("worm.tscn").is_empty(), "it is never met again")
	RunState.delete_save()
	finish()


## Load level `at` (arriving at its way back) and wait for it.
func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)


## The level's exit `which`.
func _exit(which: int) -> LevelExit:
	for n: Node in placed("level_exit.tscn"):
		if (n as LevelExit).exit == which:
			return n as LevelExit
	return null
