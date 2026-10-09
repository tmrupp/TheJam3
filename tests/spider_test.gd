extends TestKit
## The spider (Spider, docs/REGIONS_PLAN.md §6), the boss at the top of the crags, in its keep
## (SpiderKeep), the arena behind the boss door in their gate level: the keep's walls, broken
## floors (a well straight down, a stair hole with a ledge under it each), webs and roost, climbed
## from the way back with the wizard's own hops, the same every build and only in the spider's
## arena; in play, the spider asleep under the roof, waking, dropping on the wizard and biting,
## strikes glancing off its back, a bolt cutting its thread and dropping it, wounds putting out its
## eyes while it is down (even a dash that only stuns), it climbing back up a new thread, a dash
## cutting that, a parried bite stunning it, its webs holding the wizard, keeping their dash from
## coming back, torn by a bolt and a dash and spun again, a lantern death healing it, and its last
## eye: dead, its relic on the floor where it fell, the gate opened, never met again.
## godot --headless --path . --script res://tests/spider_test.gd


func run() -> void:
	MapInfo.debug = false
	var gate: Vector2i = Vector2i(28, Bosses.row_of(&"spider"))
	var arena_at: Vector2i = Worlds.side_at(Worlds.kind_of(Arena), gate)
	print("the keep")
	var w: LevelGen = build(arena_at)
	var keep: Dictionary = w.keep
	check(not keep.is_empty() and w.size == SpiderKeep.SIZE, "the spider's arena is its keep, %d by %d cells" % [w.size.x, w.size.y])
	var inside: Rect2i = keep["inside"]
	var floors: Array[int] = keep["floors"]
	var walls_ok: bool = true
	for y: int in range(w.size.y):
		for x: int in range(w.size.x):
			var v: Vector2i = Vector2i(x, y)
			if not inside.has_point(v):
				walls_ok = walls_ok and w.is_ground(v) and w.masonry.has(v)
	check(walls_ok and floors.size() == SpiderKeep.FLOORS, "walled, roofed and floored in masonry, with %d floors" % floors.size())
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
	var back: Vector2i = w.exits[MapInfo.Exit.BACK]
	var parent: Dictionary = Reach.tree(w, back)
	var top: bool = parent.keys().any(func(v: Vector2i) -> bool: return v.y == floors[0] - 1)
	check(back.y == inside.end.y - 1 and top, "the way back on the ground, and the top floor climbed to with the wizard's own hops")
	var bosses: Array[Vector2i] = w.objects_of(LevelGen.Type.BOSS)
	check(bosses.size() == 1 and StringName(w.get_cell(bosses[0]).extra_info) == &"spider" and bosses[0].y == inside.position.y, "the spider under the roof")
	var again: LevelGen = build(arena_at)
	check(again.objects == w.objects and again.keep == w.keep, "the same every build")
	var other: LevelGen = build(Worlds.side_at(Worlds.kind_of(Arena), Vector2i(28, Bosses.row_of(&"necromancer"))))
	check(other.keep.is_empty() and other.size == Vector2i(Arena.WIDTH, Arena.HEIGHT), "and only there: the other arenas are the plain hall")

	await boot(28)
	player.set_physics_process(false)
	player.health.max_health = 99
	player.health.health = 99
	await _go(arena_at)
	print("in play")
	var spider: Spider = placed("spider.tscn")[0] as Spider
	check(spider != null and spider.boss == &"spider" and placed("boss.tscn").is_empty(), "the spider itself is there, no stand-in")
	check(spider.wound.hp == Spider.EYES and spider.webs.size() == webs.size() and info.here.realm() == &"crags", "%d eyes, its webs strung, printed as the crags" % Spider.EYES)
	await frames(10)
	check(spider.state == Spider.State.SLEEP and absf(spider.global_position.y - spider.canopy_y()) < 1.0, "asleep under the roof while the wizard is far below")

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
	dash.damage = 0
	dash.struck.clear()
	dash.sweep(spider.global_position + Vector2(-150, 0), spider.global_position + Vector2(150, 0))
	check(spider.wound.hp == Spider.EYES and not spider.stunned(), "a dash glances off its back up there")

	print("its thread cut")
	player.global_position = info.cell_position(stand)
	await within(func() -> bool: return spider.state == Spider.State.BITE, 10.0)
	player.global_position = Vector2(-9000, -9000)
	var line: PackedVector2Array = spider.thread()
	check(line.size() == 2 and line[1].y - line[0].y > 150.0, "it hangs on a thread from the roof")
	_bolt(_beside(spider, -Spider.THREAD_TOP - 30.0), -_toward(spider), 0)
	var fell: bool = await within(func() -> bool: return spider.state == Spider.State.FALL, 1.0)
	check(fell and spider.anchor == null and spider.wound.hp == Spider.EYES, "a bolt across it (one that only stuns) cuts it, and it falls")
	var down: bool = await within(func() -> bool: return spider.state == Spider.State.DOWN, 3.0)
	var under: Vector2i = info.cell_at(spider.global_position + Vector2(0, Spider.LIE + 4.0))
	check(down and spider.open() and info.world.is_ground(under), "on its back on the floor below, open")
	dash.struck.clear()
	dash.sweep(spider.global_position + Vector2(-150, 0), spider.global_position + Vector2(150, 0))
	check(spider.wound.hp == Spider.EYES - 1, "a dash that only stuns puts out an eye")
	_bolt(_beside(spider, 0.0), -_toward(spider), 0)
	var hexed: bool = await within(func() -> bool: return spider.wound.hp == Spider.EYES - 2, 1.0)
	check(hexed, "so does a bolt that only stuns")
	var climbing: bool = await within(func() -> bool: return spider.state == Spider.State.RECLIMB, Spider.DOWNED + 8.0)
	check(climbing and spider.threaded() and not spider.open(), "up again, it climbs a new thread, its back to the wizard")
	await within(func() -> bool: return spider.thread().size() == 2 and spider.thread()[1].y - spider.thread()[0].y > 120.0, 2.0)
	var mid: Vector2 = (spider.thread()[0] + spider.thread()[1]) * 0.5
	dash.struck.clear()
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

	print("a death heals it")
	info.run.vulnerable = false
	player.die()
	await settle()
	await _go(arena_at)
	spider = placed("spider.tscn")[0] as Spider
	check(spider.wound.hp == Spider.EYES and spider.state == Spider.State.SLEEP and not spider.webs.any(func(x: SpiderWeb) -> bool: return x.torn), "after a lantern death it is whole again, and so are its webs")

	print("slain")
	spider.stunner.stun(30.0, true)
	for i: int in range(Spider.EYES):
		if spider.wound.hp > 0:
			spider.wound.hit(1, Vector2.RIGHT)
	check(spider.dying() and not spider.is_in_group(&"hex_target"), "its last eye out, it dies")
	var dead: bool = await within(gone(spider), Spider.DIE_TIME + 5.0)
	await settle()
	check(dead and info.run.bosses.has(&"spider") and placed("spider.tscn").is_empty(), "it is slain for the run")
	var relics: Array[Node] = placed("relic.tscn").filter(func(n: Node) -> bool: return n.get_meta(&"boss", &"") == &"spider")
	check(relics.size() == 1 and info.world.is_ground(info.cell_at((relics[0] as Node2D).global_position) + Vector2i.DOWN) and (relics[0] as Relic).price() == 0, "its relic waits on the floor where it fell, free")
	await _go(gate)
	check(_exit(MapInfo.Exit.DEEPER).sealed() == &"", "and the way up out of the crags is open")
	await _go(arena_at)
	check(placed("spider.tscn").is_empty(), "it is never met again")
	RunState.delete_save()
	finish()


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
