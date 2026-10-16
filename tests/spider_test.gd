extends TestKit
## The spider (Spider, docs/REGIONS_PLAN.md §6), the boss at the top of the crags, in its keep
## (SpiderKeep), built at the top of their gate level: the keep's walls (but for a doorway through
## each at the ground storey, out to the caves), broken floors (a well straight down, a stair hole
## with a ledge under it each), webs and roost, the way on on its top floor, climbed to from its
## ground storey with the wizard's own hops, the gondola and the towers laid round it, the same every
## build and only in the spider's gate levels; in play, the spider asleep under the roof, waking,
## dropping on the wizard and biting, strikes glancing off its back, a bolt cutting its thread and
## dropping it, wounds putting out its eyes while it is down (a slash, a bolt of no damage), it
## climbing back up a new thread, a dash cutting that, a parried bite stunning it, its webs holding
## the wizard, keeping their dash from coming back, torn by a bolt and a dash and spun again; the
## keep's crossbows, one to a floor, set in its walls shooting into the hall, out of reach, their
## arrows piercing the spider's back; the spider spitting a glob of web that sticks to the wizard
## as a splat holding them, torn by a dash, and every third spit an egg sac that lands, hatches
## spiderlings that run at the wizard, die to any blow without stars and wither away; a lantern
## death healing it, and its last eye: dead, its brood gone with it, its relic on the floor where it
## fell, the gate opened, never met again.
## godot --headless --path . --script res://tests/spider_test.gd


func run() -> void:
	MapInfo.debug = false
	var gate: Vector2i = Vector2i(28, Bosses.row_of(&"spider"))
	print("the keep")
	var w: LevelGen = build(gate)
	var keep: Dictionary = w.keep
	check(not keep.is_empty() and (keep["box"] as Rect2i).size == SpiderKeep.SIZE and (keep["box"] as Rect2i).position.y == SpiderKeep.TOP, "the spider's gate level has its keep at the top, %d by %d cells" % [SpiderKeep.SIZE.x, SpiderKeep.SIZE.y])
	var box: Rect2i = keep["box"]
	var inside: Rect2i = keep["inside"]
	var floors: Array[int] = keep["floors"]
	var doors: Array[Vector2i] = keep["doors"]
	var walls_ok: bool = true
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var v: Vector2i = Vector2i(x, y)
			if not inside.has_point(v) and not doors.has(v):
				walls_ok = walls_ok and w.is_ground(v) and w.masonry.has(v) and w.kept(v)
	check(walls_ok and floors.size() == SpiderKeep.FLOORS, "walled, roofed and floored in masonry kept whole, with %d floors" % floors.size())
	check(doors.size() == 2 * SpiderKeep.WALL * SpiderKeep.DOOR_ROWS and doors.all(func(v: Vector2i) -> bool: return not w.is_ground(v) and v.y >= inside.end.y - SpiderKeep.DOOR_ROWS), "a doorway through each wall at the ground storey")
	var well: int = keep["well"]
	var holes: Array[Rect2i] = keep["holes"]
	var stairs: Array[Rect2i] = keep["stairs"]
	var floors_ok: bool = true
	for row: int in floors:
		for x: int in range(inside.position.x, inside.end.x):
			var hole: bool = holes.any(func(h: Rect2i) -> bool: return h.has_point(Vector2i(x, row)))
			floors_ok = floors_ok and w.is_ground(Vector2i(x, row)) != hole
		floors_ok = floors_ok and holes.any(func(h: Rect2i) -> bool: return h.position == Vector2i(well, row))
	check(floors_ok, "every floor broken by the well (columns %d to %d) and the rest of it whole" % [well, well + SpiderKeep.HOLE - 1])
	var ledges_ok: bool = stairs.size() == SpiderKeep.FLOORS
	for stair: Rect2i in stairs:
		for x: int in range(stair.position.x, stair.end.x):
			@warning_ignore("integer_division")
			ledges_ok = ledges_ok and w.get_cell(Vector2i(x, stair.position.y + SpiderKeep.STOREY / 2)).type == LevelGen.Type.PLATFORM
	check(ledges_ok, "and by a stair hole each, with a ledge under it")
	var webs: Array[Rect2i] = keep["webs"]
	check(holes.filter(func(h: Rect2i) -> bool: return h.position.x == well).all(func(h: Rect2i) -> bool: return webs.has(h)) and webs.size() > SpiderKeep.FLOORS, "%d webs: across every hole of the well, and some stair holes" % webs.size())
	var on: Vector2i = w.exits.get(MapInfo.Exit.DEEPER, Vector2i(-1, -1))
	check(on == keep["on"] and on.y == floors[0] - 1 and inside.has_point(on) and w.get_cell(on).type == LevelGen.Type.EXIT, "the way on on its top floor")
	var ground: Vector2i = Vector2i(inside.position.x + 1, inside.end.y - 1)
	var parent: Dictionary = Reach.tree(w, ground)
	var top: bool = parent.keys().any(func(v: Vector2i) -> bool: return v.y == floors[0] - 1)
	var out: bool = parent.keys().any(func(v: Vector2i) -> bool: return not box.has_point(v))
	check(top and out, "the top floor climbed to from the ground storey with the wizard's own hops, and out through its doorways")
	var bosses: Array[Vector2i] = w.objects_of(LevelGen.Type.BOSS)
	check(bosses.size() == 1 and StringName(w.get_cell(bosses[0]).extra_info) == &"spider" and bosses[0] == keep["roost"] and bosses[0].y == inside.position.y, "the spider under the roof")
	var path: Array = w.circuit.get("path", [])
	check(not path.is_empty() and path.all(func(v: Vector2i) -> bool: return v.y > box.end.y), "the gondola runs below it")
	check(w.towers.all(func(t: Dictionary) -> bool: return not (t["box"] as Rect2i).intersects(box)), "and no tower stands in it")
	var bows: Array[Vector2i] = keep["crossbows"]
	var bows_ok: bool = bows.size() == SpiderKeep.FLOORS
	for v: Vector2i in bows:
		var how: Dictionary = w.get_cell(v).extra_info
		var facing: int = int(how["facing"])
		bows_ok = bows_ok and w.get_cell(v).type == LevelGen.Type.CROSSBOW and bool(how["inward"]) and floors.has(v.y + 1)
		bows_ok = bows_ok and w.is_ground(v - Vector2i(facing, 0)) and w.is_ground(v - Vector2i(facing * 2, 0)) and not w.is_ground(v + Vector2i(facing, 0))
	check(bows_ok, "a crossbow to each floor, in the hall's wall, shooting into the hall (%d)" % bows.size())
	var stray: bool = w.objects.any(func(v: Vector2i) -> bool: return box.has_point(v) and not w.get_cell(v).type in [LevelGen.Type.PLATFORM, LevelGen.Type.EXIT, LevelGen.Type.BOSS] and not bows.has(v))
	check(not stray, "nothing else is placed in it")
	var again: LevelGen = build(gate)
	check(again.objects == w.objects and again.keep == w.keep, "the same every build")
	check(build(Vector2i(29, gate.y)).keep.size() > 0 and build(Vector2i(28, gate.y + 1)).keep.is_empty(), "in every world's gate level, and only there")

	await boot(28)
	player.set_physics_process(false)
	player.health.max_health = 99
	player.health.health = 99
	await _go(gate)
	print("in play")
	var spider: Spider = placed("spider.tscn")[0] as Spider
	check(spider != null and spider.boss == &"spider" and placed("boss.tscn").is_empty(), "the spider itself is there, no stand-in")
	check(spider.wound.hp == Spider.EYES and spider.webs.size() == webs.size() and info.here.realm() == &"crags", "%d eyes, its webs strung, printed as the crags" % Spider.EYES)
	await frames(10)
	check(spider.state == Spider.State.SLEEP and absf(spider.global_position.y - spider.canopy_y()) < 1.0, "asleep under the roof while the wizard is far below")
	# It holds its spit until its own part below, so nothing it spits gets in the way before then.
	spider.spit_wait = INF

	print("the keep's crossbows")
	var cell: float = float(info.tile_map.tile_set.tile_size.y) * info.tile_map.global_scale.y
	var keep_bows: Array[Crossbow] = []
	for n: Node in placed("crossbow.tscn"):
		if bows.has(n.get_meta(&"cell")):
			keep_bows.append(n as Crossbow)
	check(keep_bows.size() == bows.size(), "they are there")
	var bow: Crossbow = keep_bows[0]
	var f: float = float(bow.facing)
	check(info.solid_at(bow.global_position) and info.solid_at(bow.global_position - Vector2(f * cell, 0.0)) and not info.solid_at(bow.muzzle()), "set in the wall, stone behind, the slit open on the hall")
	player.global_position = info.cell_position(bow.cell) + Vector2(f * cell * 3.0, 0.0)
	var loosed: bool = await within(func() -> bool: return _arrows().any(func(a: Bullet) -> bool: return Damager.attacker_of(a.get_node("HitBox/Damager")) == bow), Crossbow.DRAW + 2.0)
	check(loosed, "it shoots at the wizard in the hall")
	var bow_hp: int = (bow.get_node("Wound") as Wound).hp
	_bolt(bow.muzzle() + Vector2(f * 200.0, 0.0), Vector2(-f, 0.0), 2)
	await frames(30)
	check(is_instance_valid(bow) and (bow.get_node("Wound") as Wound).hp == bow_hp, "and a bolt from the hall stops at the wall, short of it")
	# Held still from here, so only the blows below put its eyes out.
	for b: Crossbow in keep_bows:
		b.set_physics_process(false)
	for a: Bullet in _arrows():
		a.queue_free()
	player.global_position = Vector2(-9000, -9000)

	print("it hunts")
	# The wizard on the top floor, clear of the holes: under the roost.
	var stand: Vector2i = _clear_spot(w, floors[0] - 1, holes)
	player.global_position = info.cell_position(stand)
	var woke: bool = await within(func() -> bool: return spider.state != Spider.State.SLEEP, 2.0)
	check(woke, "it wakes as the wizard comes near")
	var dropped: bool = await within(func() -> bool: return spider.state == Spider.State.DROP, 8.0)
	check(dropped and absf(spider.global_position.x - player.global_position.x) <= Spider.DROP_SLACK, "it crawls over the wizard and drops")
	player.end_invulnerable()
	var bit: bool = await within(func() -> bool: return player.health.health < 99, 2.0)
	check(bit and spider.state in [Spider.State.DROP, Spider.State.BITE], "and bites")
	await within(func() -> bool: return spider.state == Spider.State.HUNT, 6.0)
	player.global_position = Vector2(-9000, -9000)
	var dash: DashStrike = player.get_node("DashStrike") as DashStrike
	_slash(spider.global_position, 90.0)
	check(spider.wound.hp == Spider.EYES and not spider.stunned(), "a slash glances off its back up there")

	print("its thread cut")
	player.global_position = info.cell_position(stand)
	await within(func() -> bool: return spider.state == Spider.State.BITE, 10.0)
	player.global_position = Vector2(-9000, -9000)
	var line: PackedVector2Array = spider.thread()
	check(line.size() == 2 and line[1].y - line[0].y > 150.0, "it hangs on a thread from the roof")
	_bolt(_beside(spider, -Spider.THREAD_TOP - 30.0), -_toward(spider), 0)
	var fell: bool = await within(func() -> bool: return spider.state == Spider.State.FALL, 1.0)
	check(fell and spider.anchor == null and spider.wound.hp == Spider.EYES, "a bolt across it (one of no damage) cuts it, and it falls")
	var down: bool = await within(func() -> bool: return spider.state == Spider.State.DOWN, 3.0)
	var under: Vector2i = info.cell_at(spider.global_position + Vector2(0, Spider.LIE + 4.0))
	check(down and spider.open() and info.world.is_ground(under), "on its back on the floor below, open")
	_slash(spider.global_position, -90.0 * _toward(spider).x)
	check(spider.wound.hp == Spider.EYES - 1, "a slash puts out an eye")
	_bolt(_beside(spider, 0.0), -_toward(spider), 0)
	var hexed: bool = await within(func() -> bool: return spider.wound.hp == Spider.EYES - 2, 1.0)
	check(hexed, "so does a bolt of no damage")
	var climbing: bool = await within(func() -> bool: return spider.state == Spider.State.RECLIMB, Spider.DOWNED + 8.0)
	check(climbing and spider.threaded() and not spider.open(), "up again, it climbs a new thread, its back to the wizard")
	await within(func() -> bool: return spider.thread().size() == 2 and spider.thread()[1].y - spider.thread()[0].y > 120.0, 2.0)
	var mid: Vector2 = (spider.thread()[0] + spider.thread()[1]) * 0.5
	dash.sweep(mid + Vector2(-120, 0), mid + Vector2(120, 0))
	check(spider.state == Spider.State.FALL, "a dash across that thread drops it again")
	await within(func() -> bool: return spider.state == Spider.State.DOWN, 3.0)

	print("parried")
	await within(func() -> bool: return spider.state == Spider.State.HUNT, Spider.DOWNED + 15.0)
	player.global_position = info.cell_position(stand)
	await within(func() -> bool: return spider.state == Spider.State.BITE, 10.0)
	var eyes: int = spider.wound.hp
	var parry: Parry = player.get_node("Parry") as Parry
	parry.parry(1, Vector2.ZERO, spider.bite.get_node("Damager"))
	await frames(2)
	check(spider.stunned() and spider.wound.hp == eyes - 1 and spider.open(), "a parried bite puts out an eye and stuns it on the spot, open")
	player.global_position = Vector2(-9000, -9000)
	var hp: int = spider.wound.hp
	spider.wound.hit(1, Vector2.RIGHT)
	check(spider.wound.hp == hp - 1, "stunned, it is struck")
	var back_up: bool = await within(func() -> bool: return spider.state == Spider.State.CLIMB and not spider.stunned(), Parry.STUN + 1.0)
	check(back_up, "and when the stun passes it climbs back up")

	print("its webs")
	var web: SpiderWeb = spider.webs[0]
	check(SpiderWeb.holding(self, web.rect.get_center()) and not SpiderWeb.holding(self, web.rect.get_center() + Vector2(0, -web.rect.size.y)), "a web holds what is in it")
	player.global_position = web.rect.get_center()
	player.velocity = Vector2(300, 600)
	player.dash.acted = true
	player.set_physics_process(true)
	await physics_frame
	await physics_frame
	var held: bool = absf(player.velocity.x) <= SpiderWeb.WEB_SPEED and player.velocity.y <= SpiderWeb.WEB_SINK
	player.set_physics_process(false)
	check(held and player.dash.acted, "the wizard in it is slowed, and their dash does not come back")
	player.global_position = Vector2(-9000, -9000)
	_bolt(web.rect.get_center() + Vector2(0, -260), Vector2.DOWN, 1)
	var torn: bool = await within(func() -> bool: return web.torn, 1.0)
	check(torn and not SpiderWeb.holding(self, web.rect.get_center()), "a bolt tears it")
	var other_web: SpiderWeb = spider.webs[1]
	dash.sweep(other_web.rect.get_center() + Vector2(0, 120), other_web.rect.get_center() + Vector2(0, -120))
	check(other_web.torn, "and so does a dash")
	var spun: bool = await within(func() -> bool: return SpiderWeb.holding(self, web.rect.get_center()), SpiderWeb.REGROW + SpiderWeb.SPIN_TIME + 1.0)
	check(spun, "and it spins it again")

	print("arrows pierce it")
	await within(func() -> bool: return spider.state == Spider.State.HUNT and not spider.open(), 10.0)
	var before: int = spider.wound.hp
	var arrow: Bullet = Crossbow.ARROW.instantiate() as Bullet
	arrow.arrow = true
	info.map_elements.add_child(arrow)
	arrow.global_position = _beside(spider, 0.0)
	arrow.setup(-_toward(spider) * Crossbow.ARROW_SPEED, [bow], bow)
	var pierced: bool = await within(func() -> bool: return spider.wound.hp == before - 1, 2.0)
	check(pierced and not is_instance_valid(arrow), "a crossbow's arrow puts out an eye, through its back")

	print("it spits")
	player.global_position = info.cell_position(_off_to_side(w, Vector2i(info.cell_at(spider.global_position).x, floors[0] - 1), 6))
	spider.state = Spider.State.HUNT
	spider.timer = 0.0
	spider.spits = 0
	spider.spit_wait = 0.0
	var spat: bool = await within(func() -> bool: return spider.brood.any(func(b: Node2D) -> bool: return b is WebShot), 3.0)
	check(spat, "it spits a glob of web at the wizard in sight")
	var stuck: bool = await within(func() -> bool: return SpiderWeb.holding(self, player.global_position), WebShot.LIFE + 1.0)
	var splat: SpiderWeb = null
	for x: SpiderWeb in spider.webs:
		if x.splat():
			splat = x
	check(stuck and splat != null and splat.rect.has_point(player.global_position), "which sticks to them, a splat that holds them")
	dash.sweep(player.global_position + Vector2(-100, 0), player.global_position + Vector2(100, 0))
	await physics_frame
	await physics_frame
	check(not SpiderWeb.holding(self, player.global_position) and (not is_instance_valid(splat) or not spider.webs.has(splat)), "a dash tears it away")

	print("its brood")
	player.global_position = info.cell_position(_off_to_side(w, Vector2i(info.cell_at(spider.global_position).x, floors[0] - 1), 6))
	await within(func() -> bool: return spider.state == Spider.State.HUNT, 10.0)
	spider.timer = 0.0
	spider.spits = Spider.EGG_EVERY - 1
	spider.spit_wait = 0.0
	var lobbed: bool = await within(func() -> bool: return spider.brood.any(func(b: Node2D) -> bool: return b is EggSac), 3.0)
	check(lobbed, "every %dth spit is an egg sac" % Spider.EGG_EVERY)
	# Held still on its canopy, so its thread is not in the way of the blows at its brood.
	spider.set_physics_process(false)
	var sac: EggSac = null
	for b: Node2D in spider.brood:
		if b is EggSac:
			sac = b as EggSac
	var landed: bool = await within(func() -> bool: return sac.landed, 3.0)
	check(landed and info.world.is_ground(info.cell_at(sac.global_position + Vector2(0, EggSac.RADIUS + 4.0))), "it lands on a floor")
	var hatched: bool = await within(func() -> bool: return get_nodes_in_group(&"spiderling").size() == Spider.BROOD, EggSac.HATCH + 2.0)
	check(hatched and not is_instance_valid(sac), "and hatches %d spiderlings" % Spider.BROOD)
	var first: Spiderling = get_nodes_in_group(&"spiderling")[0] as Spiderling
	await within(func() -> bool: return first.on_floor, 2.0)
	var gap: float = absf(first.global_position.x - player.global_position.x)
	await frames(30)
	check(absf(first.global_position.x - player.global_position.x) < gap, "they run at the wizard")
	var stars: int = placed("coin.tscn").size()
	_bolt(first.global_position + Vector2(0, -150), Vector2.DOWN, 0)
	var killed: bool = await within(func() -> bool: return get_nodes_in_group(&"spiderling").size() == Spider.BROOD - 1, 1.0)
	check(killed and placed("coin.tscn").size() == stars, "any blow kills one, and it leaves no stars")
	var withered: bool = await within(func() -> bool: return get_nodes_in_group(&"spiderling").is_empty(), Spiderling.LIFE + 1.0)
	check(withered, "and the rest wither away")
	spider.spit_wait = INF
	spider.set_physics_process(true)

	print("a death heals it")
	info.run.vulnerable = false
	player.die()
	await settle()
	await _go(gate)
	spider = placed("spider.tscn")[0] as Spider
	check(spider.wound.hp == Spider.EYES and spider.state == Spider.State.SLEEP and not spider.webs.any(func(x: SpiderWeb) -> bool: return x.torn), "after a lantern death it is whole again, and so are its webs")

	print("slain")
	spider.stunner.stun(30.0, true)
	var young: Spiderling = Spiderling.new()
	young.spider = spider
	info.map_elements.add_child(young)
	spider.brood.append(young)
	young.global_position = spider.global_position
	for i: int in range(Spider.EYES):
		if spider.wound.hp > 0:
			spider.wound.hit(1, Vector2.RIGHT)
	check(spider.dying() and not spider.is_in_group(&"hex_target"), "its last eye out, it dies")
	var withered_too: bool = await within(gone(young), 1.0)
	check(withered_too, "and its brood goes with it")
	var dead: bool = await within(gone(spider), Spider.DIE_TIME + 5.0)
	await settle()
	check(dead and info.run.bosses.has(&"spider") and placed("spider.tscn").is_empty(), "it is slain for the run")
	var relics: Array[Node] = placed("relic.tscn").filter(func(n: Node) -> bool: return n.get_meta(&"boss", &"") == &"spider")
	check(relics.size() == 1 and info.world.is_ground(info.cell_at((relics[0] as Node2D).global_position) + Vector2i.DOWN) and (relics[0] as Relic).price() == 0, "its relic waits on the floor where it fell, free")
	check(_exit(MapInfo.Exit.DEEPER).sealed() == &"", "and the way up out of the crags is open")
	await _go(gate)
	check(placed("spider.tscn").is_empty(), "it is never met again")
	RunState.delete_save()
	finish()


## A slash (Slash, tier I, ready at once) at `at` from `side` px to one side of it, the wizard there
## just for it; then the wizard back where they were.
func _slash(at: Vector2, side: float) -> void:
	var was: Vector2 = player.global_position
	Abilities.set_tier(player, &"slash", 1)
	player.global_position = at + Vector2(side, 24.0)
	var slash: Slash = player.get_node("Slash") as Slash
	slash.wait = 0.0
	slash.cast(Vector2(-signf(side), 0.0))
	player.global_position = was


## A cell on row `row` of the keep's air with floor under it, as far from every hole as can be.
func _clear_spot(w: LevelGen, row: int, holes: Array[Rect2i]) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: int = -1
	var inside: Rect2i = w.keep["inside"]
	for x: int in range(inside.position.x, inside.end.x):
		var v: Vector2i = Vector2i(x, row)
		if not w.is_ground(v + Vector2i.DOWN):
			continue
		var d: int = 999
		for h: Rect2i in holes:
			if h.position.y == row + 1:
				d = mini(d, mini(absi(x - h.position.x), absi(x - (h.end.x - 1))))
		if d > best_d:
			best_d = d
			best = v
	return best


## The cell `cells` across from `from` toward the wider side of the keep's hall, on its row.
func _off_to_side(w: LevelGen, from: Vector2i, cells: int) -> Vector2i:
	var inside: Rect2i = w.keep["inside"]
	var right: bool = inside.end.x - 1 - from.x >= from.x - inside.position.x
	return Vector2i(clampi(from.x + (cells if right else -cells), inside.position.x, inside.end.x - 1), from.y)


## The crossbows' arrows in flight.
func _arrows() -> Array[Bullet]:
	var out: Array[Bullet] = []
	for n: Node in info.map_elements.get_children():
		var b: Bullet = n as Bullet
		if b != null and b.arrow and not b.is_queued_for_deletion():
			out.append(b)
	return out


## The way across the keep from `spider` toward the middle of the hall, and a spot 300 px back
## from it that way (`rise` px above it), to shoot back across it from.
func _toward(spider: Spider) -> Vector2:
	return Vector2.RIGHT if spider.global_position.x < (spider.hall_left + spider.hall_right) * 0.5 else Vector2.LEFT


func _beside(spider: Spider, rise: float) -> Vector2:
	return spider.global_position + Vector2(0.0, rise) + _toward(spider) * 300.0


## A hex bolt dealing `damage` fired from `at` heading `dir`.
func _bolt(at: Vector2, dir: Vector2, damage: int) -> void:
	var bolt: HexBolt = HexBolt.new()
	bolt.damage = damage
	bolt.dir = dir
	info.map_elements.add_child(bolt)
	bolt.global_position = at


## Load place `at` (arriving at its way back) and wait for it.
func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)


## The place's exit `which`.
func _exit(which: int) -> LevelExit:
	for n: Node in placed("level_exit.tscn"):
		if (n as LevelExit).exit == which:
			return n as LevelExit
	return null
