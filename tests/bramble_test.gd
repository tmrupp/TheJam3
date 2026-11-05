extends TestKit
## The bramble (Bramble, docs/REGIONS_PLAN.md §6), the boss of the garden's way up, in its gate
## gate level: its shaft cut into the rock (BrambleShaft), walled in, with the way on at its head beside
## the knot, ledges a hop apart and a foot open to the caves, the same every build and only in its
## gate levels; in play, the knot walling off the head, its crown asleep until the wizard climbs
## near, then grown out of the rock, the same every visit, quivering when struck, the vines' cadence (warning, out and
## hurting, back), a parried lash recoiling, the bulbs spitting seeds a parry turns back into them
## (even a bulb shut in its bark), one bulb in bloom at a time (the lowest first; a blow glances off
## the rest), bolts and dashes (even ones of no damage) wounding the bulb in bloom, the bloom moving on
## to the bulb furthest from the wizard when its time is up or it bursts, a burst bulb withering its
## vines, quickening the rest (its fury) and drawing the crown back a little from the heart hidden
## in it, a lantern death healing it, the last bulb baring the heart (the crown drawn back from all
## round it), the heart dropping barbs at the wizard's column, a parried barb and a slash wounding
## it, and the heart bursting to open the head, its canes drying from the heart out and drawing
## back into the rock, slaying it, leaving its relic unlock on the landing and opening the way on.
## godot --headless --path . --script res://tests/bramble_test.gd


func run() -> void:
	MapInfo.debug = false
	var g: int = Bands.garden_rows()
	print("the shaft")
	var w: LevelGen = build(Vector2i(28, -g))
	var shaft: Dictionary = w.shaft
	check(not shaft.is_empty(), "the bramble's gate level has its shaft")
	var inside: Rect2i = shaft["inside"]
	var top: int = inside.position.y
	var bottom: int = inside.end.y - 1
	check(inside.size.x == BrambleShaft.WIDTH and inside.size.y >= BrambleShaft.HEIGHT_MIN and inside.position.y <= BrambleShaft.ROOF + 1, "%d cells wide and %d tall, at the top of the level" % [inside.size.x, inside.size.y])
	var walls_ok: bool = true
	for x: int in range(inside.position.x - 1, inside.end.x + 1):
		walls_ok = walls_ok and w.is_ground(Vector2i(x, top - 1)) and w.is_ground(Vector2i(x, bottom + 1))
	for y: int in range(top, bottom - BrambleShaft.FOOT_ROWS + 1):
		walls_ok = walls_ok and w.is_ground(Vector2i(inside.position.x - 1, y)) and w.is_ground(Vector2i(inside.end.x, y))
	var foot_ok: bool = true
	for y: int in range(bottom - BrambleShaft.FOOT_ROWS + 1, bottom + 1):
		foot_ok = foot_ok and w._open(Vector2i(inside.position.x - 1, y)) and w._open(Vector2i(inside.end.x, y))
	var built: Array[Vector2i] = w.objects.filter(func(v: Vector2i) -> bool: return inside.grow(1).has_point(v) and w.get_cell(v).type == LevelGen.Type.CRACKED)
	check(walls_ok and foot_ok and built.is_empty(), "walled in by rock, roof and floor (no cracked wall in them), but for a passage through both walls at its foot")
	var on: Vector2i = shaft["on"]
	var knot: Rect2i = shaft["knot"]
	check(w.exits[MapInfo.Exit.DEEPER] == on and w.is_ground(on + Vector2i.DOWN) and w.is_ground(shaft["relic"] + Vector2i.DOWN) and inside.has_point(on), "the way on stands on a landing at its head")
	var bosses: Array[Vector2i] = w.objects_of(LevelGen.Type.BOSS)
	check(bosses.size() == 1 and knot.has_point(bosses[0]) and StringName(w.get_cell(bosses[0]).extra_info) == &"bramble" and knot.size.x == BrambleShaft.WIDTH - BrambleShaft.LANDING and knot.position.y == top, "the bramble rooted in the knot beside it, filling the rest of the head")
	var strays: Array[Vector2i] = w.objects.filter(func(v: Vector2i) -> bool: return inside.has_point(v) and not w.get_cell(v).type in [LevelGen.Type.EXIT, LevelGen.Type.PLATFORM, LevelGen.Type.BOSS])
	var open_ok: bool = true
	for x: int in range(inside.position.x, inside.end.x):
		for y: int in range(top, bottom + 1):
			var v: Vector2i = Vector2i(x, y)
			if y != top + 2 or knot.has_point(v):
				open_ok = open_ok and w._open(v) and not w.empties.has(v)
	check(strays.is_empty() and open_ok, "open inside, with nothing else placed in it (%d strays)" % strays.size())
	var ledges: Array[Vector2i] = shaft["ledges"]
	var ledges_ok: bool = not ledges.is_empty() and ledges[0].y == knot.end.y + 1 and knot.has_point(Vector2i(ledges[0].x, knot.position.y))
	for i: int in range(ledges.size()):
		ledges_ok = ledges_ok and w.get_cell(ledges[i]).type == LevelGen.Type.PLATFORM
		if i > 0:
			ledges_ok = ledges_ok and ledges[i].y - ledges[i - 1].y <= Reach.UP and ledges[i].x != ledges[i - 1].x
	ledges_ok = ledges_ok and (bottom - (ledges[ledges.size() - 1].y - 1)) <= Reach.UP and (ledges[0].y - 1) - (on.y) <= Reach.UP
	check(ledges_ok, "%d ledges up it from side to side, each a hop on from the last, from its floor to the landing" % ledges.size())
	var bulbs: Array = shaft["bulbs"]
	var vines: Array = shaft["vines"]
	var sides: Dictionary = {}
	var set_ok: bool = true
	for b: Array in bulbs + vines:
		var wall: Vector2i = b[0]
		set_ok = set_ok and w.is_ground(wall) and inside.has_point(wall + (b[1] as Vector2i)) and wall.y > knot.end.y - 1
	for b: Array in bulbs:
		sides[(b[1] as Vector2i).x] = true
	check(bulbs.size() >= BrambleShaft.BULBS.x and bulbs.size() <= BrambleShaft.BULBS.y and sides.size() == 2 and set_ok, "%d bulbs set in both its walls, and %d vines rooted in them" % [bulbs.size(), vines.size()])
	var back: Vector2i = w.exits[MapInfo.Exit.BACK]
	check(w.reach_from(back).has(on), "the caves lead from the way back to its foot, and up it to the way on")
	var again: LevelGen = build(Vector2i(28, -g))
	check(again.objects == w.objects and again.shaft == w.shaft, "the same every build")
	var others: bool = true
	for at: Vector2i in [Vector2i(28, -g + 1), Vector2i(28, g), Vector2i(28, -g - 1)]:
		others = others and build(at).shaft.is_empty()
	check(others, "and only in the bramble's gate levels")
	var columns: int = 0
	var climbed: int = 0
	for x: int in range(1, 13):
		var lw: LevelGen = build(Vector2i(x, -g))
		if lw == null or lw.shaft.is_empty():
			continue
		columns += 1
		var nodes: Dictionary = Climb.footholds(lw)
		var reach: Dictionary = {lw.exits[MapInfo.Exit.BACK]: true}
		Reach.grow(lw, nodes, reach, [lw.exits[MapInfo.Exit.BACK]], {}, {}, Reach.ACROSS, Climb.hop_up(Rules.def_for(Vector2i(x, -g))), Climb.FALL)
		if reach.has(lw.shaft["on"]):
			climbed += 1
	check(columns == 12, "every world column's gate level has one (%d of 12)" % columns)
	print("  (the way on climbed to with the wizard's own hops in %d of %d)" % [climbed, columns])

	await boot(28)
	player.set_physics_process(false)
	await _go(Vector2i(28, -g))
	print("in play")
	var bramble: Bramble = placed("bramble.tscn")[0] as Bramble
	check(bramble != null and bramble.boss == &"bramble" and placed("boss.tscn").is_empty(), "the bramble itself is there, no stand-in")
	check(_exit(MapInfo.Exit.DEEPER).sealed() == &"bramble", "its way on is sealed")
	check(bramble.bulbs.size() == bulbs.size() and bramble.bulbs.all(func(b: BrambleBulb) -> bool: return b.alive and b.wound.hp == Bramble.BULB_HP and b.is_in_group(&"hex_target")), "%d bulbs, %d hits each, struck as enemies are" % [bramble.bulbs.size(), Bramble.BULB_HP])
	check(bramble.vines.size() == vines.size() and bramble.vines.all(func(v: BrambleVine) -> bool: return v.bulb != null), "%d vines, each fed by a bulb" % bramble.vines.size())
	var space: PhysicsDirectSpaceState2D = bramble.get_world_2d().direct_space_state
	var probe: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	probe.position = bramble.knot_rect.get_center()
	probe.collision_mask = 4
	check(space.intersect_point(probe).any(func(hit: Dictionary) -> bool: return hit["collider"] == bramble.knot), "the knot walls off the head of the shaft")
	var tangle: BrambleTangle = bramble.tangle
	var crown: Array[BrambleTangle.Cane] = []
	crown.assign(tangle.canes.filter(func(c: BrambleTangle.Cane) -> bool: return c.kind == &"crown"))
	var asleep: PackedFloat32Array = tangle.reaches()
	var bare_crown: bool = true
	for i: int in range(tangle.canes.size()):
		if tangle.canes[i].kind == &"crown":
			bare_crown = bare_crown and asleep[i] == 0.0
	check(not tangle.awake() and bare_crown and bramble.knot_box.collision.disabled, "asleep, its crown is not grown and its thorns do not hurt")
	player.global_position = bramble.center(Vector2i(bramble.inside.get_center().x, (shaft["ledges"][0] as Vector2i).y - 1))
	var woke: bool = await within(func() -> bool: return tangle.awake(), 1.0)
	player.global_position = Vector2(-9000, -9000)
	var grew: bool = await within(func() -> bool: return tangle.grown() >= 1.0, tangle.crown_reach / BrambleTangle.GROW_SPEED + 1.0)
	await frames(3)
	check(woke and grew and not bramble.knot_box.collision.disabled, "the wizard climbing near, it wakes: its crown grows out of the rock, and its thorns hurt to touch")
	var from_rock: int = crown.filter(func(c: BrambleTangle.Cane) -> bool: return c.gen == 0).size()
	check(from_rock == BrambleTangle.FROM_ROOF + BrambleTangle.FROM_WALL + BrambleTangle.FROM_LANDING and crown.size() > from_rock and crown.size() <= BrambleTangle.CANES_MAX, "%d canes out of the rock round the head, %d sprouted off them" % [from_rock, crown.size() - from_rock])
	check(tangle.cover() >= BrambleTangle.COVER or crown.size() == BrambleTangle.CANES_MAX, "filling the head (%d%%)" % roundi(tangle.cover() * 100.0))
	var thorns: int = crown.reduce(func(n: int, c: BrambleTangle.Cane) -> int: return n + c.thorns.size(), 0)
	var thinnest: float = crown.reduce(func(w: float, c: BrambleTangle.Cane) -> float: return minf(w, c.widths[0]), INF)
	check(thorns >= crown.size() * 2 and thinnest >= BrambleTangle.WIDE_SPROUT.x * 0.8, "thick (%.0f px at the foot at the least) and thorned (%d thorns)" % [thinnest, thorns])
	await frames(2)
	check(tangle.stalk != null and tangle.holds_bud() and tangle.stalk_tip().distance_to(bramble._bud_top()) < BrambleTangle.SWAY * 2.0 + 1.0, "the hidden bud hangs from a stalk of its own, out of the roof")
	var lowest: BrambleBulb = LevelGen.best_of(bramble.bulbs, func(b: BrambleBulb) -> float: return -b.global_position.y) as BrambleBulb
	check(bramble.bloom == lowest and lowest.open() and bramble.bulbs.filter(func(b: BrambleBulb) -> bool: return b.open()).size() == 1, "one bulb in bloom, the lowest; the rest shut in their bark")
	check(bramble.fury == 0 and bramble.heart == null, "no fury yet, and its heart hidden")

	print("the vines")
	var vine: BrambleVine = bramble.vines[0]
	var seen: Dictionary = {}
	var hurt_out: bool = true
	var hurt_in: bool = true
	var longest: float = 0.0
	for f: int in range(int(BrambleVine.PERIOD * 60.0) + 30):
		await physics_frame
		var state: StringName = vine.phase()[0]
		seen[state] = true
		longest = maxf(longest, vine.length)
		if state == &"hold":
			hurt_out = hurt_out and vine.hurts()
		if state in [&"rest", &"warn"]:
			hurt_in = hurt_in and not vine.hurts() and vine.length == 0.0
	check(seen.size() == 5, "it rests, warns, grows, holds and pulls back on a cadence")
	check(hurt_in and hurt_out and absf(longest - BrambleVine.REACH * bramble.cell) < 1.0, "hurting only while it is out, %.0f px across the shaft" % longest)
	player.health.max_health = 99
	player.health.health = 99
	await until(func() -> bool: return vine.phase()[0] == &"hold", 10000)
	player.end_invulnerable()
	player.global_position = vine.global_position + vine.way * bramble.cell * 1.5
	var stung: bool = await until(func() -> bool: return player.health.health < 99, 3000)
	check(stung, "it stings the wizard in its way")
	await until(func() -> bool: return vine.phase()[0] == &"hold", 10000)
	var parry: Parry = player.get_node("Parry") as Parry
	parry.parry(1, Vector2.ZERO, vine.hit_box.get_node("Damager"))
	await frames(20)
	check(vine.recoiled() and vine.length == 0.0 and not vine.hurts(), "a parried lash recoils into the rock")
	var back_out: bool = await until(func() -> bool: return vine.hurts(), 15000)
	check(back_out and not vine.recoiled(), "and lashes out again once the stun has passed")
	player.global_position = Vector2(-9000, -9000)

	print("the bulbs")
	var bulb: BrambleBulb = bramble.bulbs[0]
	# Its seeds are tried on a bulb shut in its bark.
	bramble.bloom_on(bramble.bulbs[1])
	var near: Vector2 = bulb.global_position + bulb.way * bramble.cell * 1.6 + Vector2(0, -6)
	player.global_position = near
	var spat_before: int = bulb.spat
	var spat: bool = await until(func() -> bool: return bulb.spat > spat_before, 10000)
	var seeds: Array[Node] = placed("bullet.tscn", true).filter(func(n: Node) -> bool: return (n as Bullet).seed)
	check(spat and not seeds.is_empty(), "a bulb spits seeds at the wizard in sight")
	if not seeds.is_empty():
		var seed: Bullet = seeds[0] as Bullet
		check(Damager.attacker_of(seed.get_node("HitBox/Damager")) == bulb, "each its own")
		var before: int = bulb.wound.hp
		parry.parry(1, Vector2.ZERO, seed.get_node("HitBox/Damager"))
		var back_in: bool = await until(func() -> bool: return bulb.wound.hp < before, 3000)
		check(back_in and not bulb.open(), "a parried seed flies back into its bulb and wounds it, even shut in its bark")
	player.global_position = Vector2(-9000, -9000)
	var other: BrambleBulb = bramble.bulbs[1]
	bramble.bloom_on(bulb)
	var hp: int = other.wound.hp
	_slash(other.global_position + other.way * 80.0, -other.way)
	check(other.wound.hp == hp and other.warded_t > -INF, "a slash glances off a bulb shut in its bark")
	bramble.bloom_on(other)
	_slash(other.global_position + other.way * 80.0, -other.way)
	check(other.wound.hp == hp - 1 and not other.stunner.stunned(), "in bloom, a slash wounds it, and it is never stunned")
	var near_bulb: float = await _shaken(tangle, &"root", other.global_position)
	bramble.struck_knot(Vector2.UP)
	var crown_shook: float = await _shaken(tangle, &"crown", Vector2.INF)
	check(tangle.quivering() and near_bulb > BrambleTangle.SWAY * BrambleTangle.ROOT_FLEX * 2.0 and crown_shook > BrambleTangle.SWAY * 1.5, "struck, the bramble quivers: its root by a struck bulb (%.0f px), its crown from a bolt into it (%.0f px)" % [near_bulb, crown_shook])
	var bolt: HexBolt = HexBolt.new()
	bolt.damage = 0
	info.map_elements.add_child(bolt)
	bolt.global_position = other.global_position + other.way * 200.0
	bolt.dir = -other.way
	# Fired from 200 px off: wait for it to arrive rather than a fixed number of frames.
	await until(func() -> bool: return other.wound.hp <= hp - 2, 3000)
	check(other.wound.hp == hp - 2, "so does a hex bolt of no damage")
	var fed: Array[BrambleVine] = bramble.vines.filter(func(v: BrambleVine) -> bool: return v.bulb == other)
	other.wound.hit(other.wound.hp, Vector2.RIGHT)
	await frames(10)
	check(not other.alive and not other.is_in_group(&"hex_target") and bramble.bulbs_left() == bramble.bulbs.size() - 1, "burst, it is gone (%d bulbs left)" % bramble.bulbs_left())
	check(fed.all(func(v: BrambleVine) -> bool: return v.withered and not v.hurts()) and bramble.vines.any(func(v: BrambleVine) -> bool: return not v.withered), "the %d vines it fed wither, the rest grow on" % fed.size())
	check(not bramble.dying and not info.run.bosses.has(&"bramble"), "and the bramble lives while a bulb is left")
	var drawn: bool = await within(func() -> bool: return is_equal_approx(bramble.bare, bramble.bare_to()), Bramble.BARE_TIME + 0.5)
	await frames(2)
	check(drawn and bramble.bare > 0.0 and bramble.bare < 1.0 and _cut(tangle) > 0 and bramble.heart == null, "its crown draws back a little from the heart hidden in it (%d canes short of it), still whole" % _cut(tangle))
	var living: Array = bramble.bulbs.filter(func(b: BrambleBulb) -> bool: return b.alive)
	var far: Callable = func(b: BrambleBulb) -> float: return b.global_position.distance_to(player.global_position)
	var to: BrambleBulb = bramble.sap_to
	check(bramble.bloom == null and to != null and to.alive and living.all(func(b: BrambleBulb) -> bool: return far.call(b) <= far.call(to)), "its sap runs on to the living bulb furthest from the wizard")
	var bloomed: bool = await within(func() -> bool: return bramble.bloom == to, 3.0)
	check(bloomed and to.open(), "which blooms when it arrives")
	check(bramble.fury == 1 and bramble.vines.all(func(v: BrambleVine) -> bool: return v.rest_rate() > 1.0) and to.seed_every() < BrambleBulb.SEED_EVERY, "its fury rises: the vines left rest the shorter, the bulbs left spit sooner")
	var waited: BrambleBulb = bramble.bloom
	await frames(30)
	check(bramble.bloom == waited and bramble.bloom_left == Bramble.BLOOM_TIME, "the bloom waits while the wizard is out of the shaft")
	player.global_position = bramble.center(Vector2i(bramble.inside.get_center().x, bramble.inside.end.y - 2))
	var moved: bool = await within(func() -> bool: return bramble.bloom != waited, Bramble.BLOOM_TIME / Difficulty.haste() + 0.5)
	var next: BrambleBulb = bramble.sap_to
	living = bramble.bulbs.filter(func(b: BrambleBulb) -> bool: return b.alive and b != waited)
	check(moved and next != null and next != waited and living.all(func(b: BrambleBulb) -> bool: return far.call(b) <= far.call(next)), "with the wizard in it, the bloom moves on in time, to the bulb furthest from them")
	player.global_position = Vector2(-9000, -9000)

	var roots: Array[BrambleTangle.Cane] = []
	roots.assign(tangle.canes.filter(func(c: BrambleTangle.Cane) -> bool: return c.kind == &"root"))
	check(roots.filter(func(c: BrambleTangle.Cane) -> bool: return c.gen == 0).size() == 2 and roots.size() > 2, "its roots run down both walls, rootlets curling off them")
	var grown: PackedVector2Array = crown[crown.size() - 1].pts

	print("a death heals it")
	info.run.vulnerable = false
	player.die()
	await settle()
	await _go(Vector2i(28, -g))
	bramble = placed("bramble.tscn")[0] as Bramble
	check(bramble.bulbs_left() == bulbs.size() and bramble.bulbs.all(func(b: BrambleBulb) -> bool: return b.wound.hp == Bramble.BULB_HP) and not bramble.vines.any(func(v: BrambleVine) -> bool: return v.withered), "after a lantern death it is whole again")
	lowest = LevelGen.best_of(bramble.bulbs, func(b: BrambleBulb) -> float: return -b.global_position.y) as BrambleBulb
	check(bramble.fury == 0 and bramble.bloom == lowest and bramble.heart == null, "its fury gone, the lowest bulb in bloom again")
	var again_crown: Array = bramble.tangle.canes.filter(func(c: BrambleTangle.Cane) -> bool: return c.kind == &"crown")
	check(not bramble.tangle.awake() and (again_crown[again_crown.size() - 1] as BrambleTangle.Cane).pts == grown, "asleep again, and its crown grows the same way every visit")
	tangle = bramble.tangle
	crown.assign(again_crown)
	roots.assign(tangle.canes.filter(func(c: BrambleTangle.Cane) -> bool: return c.kind == &"root"))

	print("the heart")
	player.health.max_health = 99
	player.health.health = 99
	for b: BrambleBulb in bramble.bulbs:
		if b.alive:
			bramble.bloom_on(b)
			b.wound.hit(Bramble.BULB_HP, Vector2.RIGHT)
	await frames(2)
	var heart: BrambleHeart = bramble.heart
	check(heart != null and heart.alive and heart.open() and heart.is_in_group(&"hex_target") and bramble.vines.all(func(v: BrambleVine) -> bool: return v.withered), "the last bulb burst, every vine withers and the heart is bared")
	check(tangle.awake() and not bramble.dying and not (bramble.knot.get_child(0) as CollisionShape2D).disabled, "the crown awake, and the knot still walls off the head")
	var bared: bool = await within(func() -> bool: return bramble.bare >= 1.0, Bramble.BARE_TIME + 0.5)
	await frames(2)
	check(bared and _clear(tangle) and _cut(tangle) > 0, "its crown draws right back from round the heart: no cane in the hollow (%d short of it)" % _cut(tangle))
	check(tangle.holds_bud() and tangle.stalk_tip().distance_to(bramble._bud_top()) < 30.0, "the bud dropped out of it, still on its stalk (the hollow does not cut it)")
	var top_ledge: Vector2i = shaft["ledges"][0]
	player.global_position = info.cell_position(top_ledge + Vector2i.UP)
	var dropped: bool = await within(func() -> bool: return heart.dropped > 0, Bramble.BARE_TIME + BrambleHeart.BARB_EVERY + 0.5)
	var barbs: Array[Node] = placed("bullet.tscn", true).filter(func(n: Node) -> bool: return (n as Bullet).barb)
	check(dropped and not barbs.is_empty(), "with the wizard in the shaft, it drops barbs")
	if not barbs.is_empty():
		var barb: Bullet = barbs[0] as Bullet
		var aim: float = clampf(player.global_position.x, bramble.knot_rect.position.x + BrambleHeart.BARB_EDGE, bramble.knot_rect.end.x - BrambleHeart.BARB_EDGE)
		check(absf(barb.global_position.x - aim) < 1.0 and barb.velocity.y > 0.0 and Damager.attacker_of(barb.get_node("HitBox/Damager")) == heart, "down the wizard's column")
		var before: int = heart.wound.hp
		parry.parry(1, Vector2.ZERO, barb.get_node("HitBox/Damager"))
		var back_in: bool = await until(func() -> bool: return heart.wound.hp < before, 3000)
		check(back_in, "a parried barb flies back into the heart and wounds it")
	var heart_hp: int = heart.wound.hp
	_slash(heart.global_position + Vector2.DOWN * 80.0, Vector2.UP)
	check(heart.wound.hp == heart_hp - 1, "so does a slash from below")
	player.global_position = Vector2(-9000, -9000)

	print("slain")
	heart.wound.hit(heart.wound.hp, Vector2.UP)
	await frames(2)
	check(bramble.dying, "the heart burst, the bramble dies")
	await frames(3)
	check((bramble.knot.get_child(0) as CollisionShape2D).disabled and bramble.knot_box.collision.disabled, "the head of the shaft is open at once")
	check(tangle.dying() and bramble.dying_end == tangle.end_time and tangle.end_time > 0.0, "its canes die with it, over %.1f s" % tangle.end_time)
	var out_then: PackedFloat32Array = tangle.reaches()
	var standing: Array = crown.filter(func(c: BrambleTangle.Cane) -> bool: return c.gen == 0 and out_then[tangle.canes.find(c)] > 0.0)
	var first: BrambleTangle.Cane = LevelGen.best_of(standing, func(c: BrambleTangle.Cane) -> float: return c.pts[0].distance_to(tangle.dry_from)) as BrambleTangle.Cane
	var root: BrambleTangle.Cane = roots.filter(func(c: BrambleTangle.Cane) -> bool: return c.gen == 0)[0]
	var root_tip: Vector2 = root.pts[root.pts.size() - 1]
	check(tangle.dry_at(first.pts[0], first) < tangle.dry_at(root_tip, root) and float(tangle.back_at[root.tree]) > float(tangle.back_at[first.tree]), "a dry front runs out from the heart: through the crown before the roots' tips, and the crown draws back first")
	var dried: bool = await within(func() -> bool: return not is_instance_valid(bramble) or tangle.dryness(first.pts[0], first) >= 1.0, bramble.dying_end)
	var still_out: bool = is_instance_valid(bramble) and tangle.reaches()[tangle.canes.find(first)] > 0.0
	check(dried and still_out and not bramble.slain, "a cane of the crown dries before it draws back")
	var drew_back: bool = await within(func() -> bool: return not is_instance_valid(bramble) or tangle.drawn_back(first) >= 1.0, bramble.dying_end)
	var crown_in: bool = true
	if is_instance_valid(bramble):
		var now_out: PackedFloat32Array = tangle.reaches()
		for i: int in range(tangle.canes.size()):
			if tangle.canes[i].tree == first.tree:
				crown_in = crown_in and now_out[i] == 0.0
	check(drew_back and crown_in, "then draws back into the rock, all of it, before the bramble is slain")
	var stalk_in: bool = await within(func() -> bool: return not is_instance_valid(bramble) or tangle.drawn_back(tangle.stalk) >= 1.0, bramble.dying_end)
	check(stalk_in and (not is_instance_valid(bramble) or tangle.reaches()[tangle.canes.find(tangle.stalk)] == 0.0), "and the stalk draws the bud's husk up into the rock")
	var dead: bool = await within(gone(bramble), bramble.dying_end + 1.0 if is_instance_valid(bramble) else 1.0)
	await settle()
	check(dead and info.run.bosses.has(&"bramble") and placed("bramble.tscn").is_empty(), "it is slain for the run")
	var unlocks: Array[Node] = unlocks_lying()
	check(left_unlock() and (unlocks.is_empty() or info.cell_at((unlocks[0] as Node2D).global_position) == shaft["relic"]), "its relic unlock waits on the landing beside the way on")
	check(_exit(MapInfo.Exit.DEEPER).sealed() == &"", "and the way on is open")
	await _go(Vector2i(28, -g))
	check(placed("bramble.tscn").is_empty() and info.world.shaft["on"] == on, "it is never met again: the shaft stands open")
	RunState.delete_save()
	finish()


## How far any point of `tangle`'s canes of kind `kind` is pushed across it (px), at the most over
## the next few frames; only within 60 px of `near`, if given (not INF).
func _shaken(tangle: BrambleTangle, kind: StringName, near: Vector2) -> float:
	var most: float = 0.0
	for f: int in range(12):
		await physics_frame
		for c: BrambleTangle.Cane in tangle.canes:
			if c.kind != kind:
				continue
			for k: int in range(c.pts.size()):
				if near.is_finite() and c.pts[k].distance_to(near) > 60.0:
					continue
				most = maxf(most, absf(tangle.shake_at(c, k)))
	return most


## How many canes of `tangle`'s crown end short of their full length, cut by the hollow round the
## heart.
func _cut(tangle: BrambleTangle) -> int:
	var out: PackedFloat32Array = tangle.reaches()
	var n: int = 0
	for i: int in range(tangle.canes.size()):
		var c: BrambleTangle.Cane = tangle.canes[i]
		if c.kind == &"crown" and out[i] > 0.0 and out[i] < c.length - 1.0:
			n += 1
	return n


## Whether no cane of `tangle`'s crown, as far as it is out, lies in the hollow round the heart.
func _clear(tangle: BrambleTangle) -> bool:
	var out: PackedFloat32Array = tangle.reaches()
	for i: int in range(tangle.canes.size()):
		var c: BrambleTangle.Cane = tangle.canes[i]
		if c.kind != &"crown":
			continue
		for j: int in range(c.pts.size()):
			if c.arc[j] < out[i] - 2.0 and tangle.in_hollow(c.pts[j]):
				return false
	return true


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


## A slash (Slash, tier I, ready at once) from `from` heading `dir`, the wizard there just for it;
## then the wizard back where they were.
func _slash(from: Vector2, dir: Vector2) -> void:
	var was: Vector2 = player.global_position
	Abilities.set_tier(player, &"slash", 1)
	player.global_position = from - (SpellStrike.origin(player) - player.global_position)
	var slash: Slash = player.get_node("Slash") as Slash
	slash.wait = 0.0
	slash.cast(dir)
	player.global_position = was
