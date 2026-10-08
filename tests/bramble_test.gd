extends TestKit
## The bramble (Bramble, docs/REGIONS_PLAN.md §6), the boss of the garden's way up, in its gate
## level: its shaft cut into the rock (BrambleShaft), walled in, with the way on at its head beside
## the knot, ledges a hop apart and a foot open to the caves, the same every build and only in its
## gate levels; in play, the knot walling off the head, the vines' cadence (warning, out and
## hurting, back), a parried lash recoiling, the bulbs spitting seeds a parry turns back into them,
## bolts and dashes (even ones that only stun) wounding them, a burst bulb withering its vines, a
## lantern death healing it, and the last bulb tearing the knot open, slaying it, leaving its relic
## on the landing and opening the way on.
## godot --headless --path . --script res://tests/bramble_test.gd


func run() -> void:
	MapInfo.debug = false
	var g: int = NextWorldDef.GARDEN_ROWS
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
	check(not bramble.knot_box.collision.disabled, "and its thorns hurt to touch")

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
		check(back_in, "a parried seed flies back into its bulb and wounds it")
	player.global_position = Vector2(-9000, -9000)
	var other: BrambleBulb = bramble.bulbs[1]
	var dash: DashStrike = player.get_node("DashStrike") as DashStrike
	dash.damage = 0
	dash.struck.clear()
	var hp: int = other.wound.hp
	dash.sweep(other.global_position + other.way * 120.0, other.global_position - other.way * 10.0)
	check(other.wound.hp == hp - 1 and not other.stunner.stunned(), "a dash that only stuns wounds it, and it is never stunned")
	var bolt: HexBolt = HexBolt.new()
	bolt.damage = 0
	info.map_elements.add_child(bolt)
	bolt.global_position = other.global_position + other.way * 200.0
	bolt.dir = -other.way
	await frames(10)
	check(other.wound.hp == hp - 2, "so does a hex bolt that only stuns")
	var fed: Array[BrambleVine] = bramble.vines.filter(func(v: BrambleVine) -> bool: return v.bulb == other)
	other.wound.hit(other.wound.hp, Vector2.RIGHT)
	await frames(10)
	check(not other.alive and not other.is_in_group(&"hex_target") and bramble.bulbs_left() == bramble.bulbs.size() - 1, "burst, it is gone (%d bulbs left)" % bramble.bulbs_left())
	check(fed.all(func(v: BrambleVine) -> bool: return v.withered and not v.hurts()) and bramble.vines.any(func(v: BrambleVine) -> bool: return not v.withered), "the %d vines it fed wither, the rest grow on" % fed.size())
	check(not bramble.opening and not info.run.bosses.has(&"bramble"), "and the bramble lives while a bulb is left")

	print("a death heals it")
	info.run.vulnerable = false
	player.die()
	await settle()
	await _go(Vector2i(28, -g))
	bramble = placed("bramble.tscn")[0] as Bramble
	check(bramble.bulbs_left() == bulbs.size() and bramble.bulbs.all(func(b: BrambleBulb) -> bool: return b.wound.hp == Bramble.BULB_HP) and not bramble.vines.any(func(v: BrambleVine) -> bool: return v.withered), "after a lantern death it is whole again")

	print("slain")
	for b: BrambleBulb in bramble.bulbs:
		if b.alive:
			b.wound.hit(Bramble.BULB_HP, Vector2.RIGHT)
	await frames(2)
	check(bramble.opening and bramble.vines.all(func(v: BrambleVine) -> bool: return v.withered), "the last bulb burst, every vine withers and the knot tears open")
	await frames(3)
	check((bramble.knot.get_child(0) as CollisionShape2D).disabled and bramble.knot_box.collision.disabled, "the head of the shaft is open")
	var dead: bool = await until(gone(bramble), 5000)
	await settle()
	check(dead and info.run.bosses.has(&"bramble") and placed("bramble.tscn").is_empty(), "it is slain for the run")
	var relics: Array[Node] = placed("relic.tscn").filter(func(n: Node) -> bool: return n.get_meta(&"boss", &"") == &"bramble")
	check(relics.size() == 1 and info.cell_at((relics[0] as Node2D).global_position) == shaft["relic"] and (relics[0] as Relic).price() == 0, "its relic waits on the landing beside the way on, free")
	check(_exit(MapInfo.Exit.DEEPER).sealed() == &"", "and the way on is open")
	await _go(Vector2i(28, -g))
	check(placed("bramble.tscn").is_empty() and info.world.shaft["on"] == on, "it is never met again: the shaft stands open")
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
