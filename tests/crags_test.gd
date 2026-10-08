extends TestKit
## The crags (CragsArchetype, docs/REGIONS_PLAN.md §7): their own sample (collapsed unturned),
## taller than wide, a structure pass (shafts, keeps and towers, kept as masonry), the same every
## build; their realm and decor (battlements and dressed stone on the masonry only); doors in their
## passages; and the gondola: a line carved and kept clear between two stations with rock under
## them, counted as somewhere to stand all along it, and in play shutting its bars on the wizard,
## riding up the line, calling up wraiths, holding at the top until they are put down, then letting
## the wizard out, and coming back empty when called from the station it is not at.
## godot --headless --path . --script res://tests/crags_test.gd


func run() -> void:
	generation()
	await ride()
	RunState.delete_save()
	finish()


func generation() -> void:
	print("laid out")
	var gondolas: int = 0
	for k: int in [0, 2, 5]:
		var at: Vector2i = Vector2i(28, NextWorldDef.band_row(&"crags", k))
		var def: NextWorldDef = Rules.def_for(at)
		check(def.archetype == &"crags" and def.symmetry == 1 and def.region == CragsArchetype.SAMPLE and def.realm() == &"crags", "row %d is a crag level, collapsed unturned from its own sample, in its own realm" % at.y)
		check(def.size.y > def.size.x, "row %d is taller than wide (%s)" % [at.y, def.size])
		var w: LevelGen = build(at)
		var again: LevelGen = build(at)
		check(w.objects == again.objects and w.masonry == again.masonry, "row %d lays out the same every time" % at.y)
		check(not w.masonry.is_empty() and w.masonry.keys().all(func(v: Vector2i) -> bool: return w.is_ground(v)), "row %d has castle masonry, all of it rock" % at.y)
		check(count_of(w, LevelGen.Type.DOOR) + count_of(w, LevelGen.Type.SWITCH_GATE) > 0, "row %d has doors or switch gates in its passages" % at.y)
		for v: Vector2i in w.objects_of(LevelGen.Type.GONDOLA):
			gondolas += 1
			var up: Vector2i = w.get_cell(v).extra_info
			var rise: int = v.y - up.y
			check(rise >= CragsArchetype.GONDOLA_RISE.x and rise <= CragsArchetype.GONDOLA_RISE.y, "its gondola climbs %d rows" % rise)
			check(w.is_ground(v + Vector2i.DOWN) and w.is_ground(v + Vector2i(1, 1)), "its lower station has rock under the car")
			check(w.is_ground(up + Vector2i(-1, 1)) or w.is_ground(up + Vector2i(2, 1)), "its upper station has a floor beside it to step out on")
			var line: Array[Vector2i] = CragsArchetype.line_cells(v, up)
			check(line.all(func(c: Vector2i) -> bool: return c == v or w.get_cell(c).type == LevelGen.Type.EMPTY), "its line is open air, nothing laid in it")
			check(line.all(func(c: Vector2i) -> bool: return w.keep_clear.has(c) and not w.empties.has(c)), "and kept clear of what is laid after")
			var nodes: Dictionary = Reach.footholds(w)
			check(nodes.has(v) and nodes.has(up), "both ends count as somewhere to stand (riding it)")
		# The decor: battlements and dressed stone only on the castle's masonry.
		var solid: Dictionary = {}
		for x: int in range(w.size.x):
			for y: int in range(w.size.y):
				if w.is_ground(Vector2i(x, y)):
					solid[Vector2i(x, y)] = true
		var items: Array[Dictionary] = RisoDecor.plan(solid, {}, def.gen_seed, Rect2i(Vector2i.ZERO, w.size), def.decor(), &"roots", w.masonry)
		var kinds: Dictionary = {}
		var astray: int = 0
		for item: Dictionary in items:
			kinds[item["kind"]] = true
			if (item.has("battlement") or item["kind"] in [&"ashlar", &"slit"]) and not w.masonry.has(item["base"]):
				astray += 1
		check(kinds.has(&"ashlar") and not kinds.has(&"headstone"), "row %d wears the crags' decor (%s)" % [at.y, ", ".join(kinds.keys())])
		check(astray == 0, "its battlements, dressed stone and arrow slits are all on masonry (%d astray)" % astray)
	check(gondolas >= 3, "every crag level has a gondola (%d)" % gondolas)


func ride() -> void:
	await boot()
	info.coord = Vector2i(28, NextWorldDef.band_row(&"crags", 1))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	print("a gondola")
	if RisoPrint.instance != null:
		check(RisoPrint.instance.realm == &"crags", "printed in the crags' realm")
	player.health.max_health = 99
	player.health.health = 99
	var all: Array[Node] = placed("gondola.tscn")
	check(not all.is_empty(), "the level has a gondola")
	if all.is_empty():
		return
	var g: Gondola = all[0] as Gondola
	var bottom: Vector2 = g.stations[0]
	check(g.global_position.distance_to(bottom) < 1.0 and g.state == Gondola.State.WAITING, "it waits at its lower station")
	# In: its bars come down and it rides up the line.
	player.global_position = g.global_position + Vector2(0, -60)
	player.velocity = Vector2.ZERO
	check(await until(func() -> bool: return g.state == Gondola.State.RIDING), "standing in it sets it off")
	check(g.sealed and g.ridden, "with its bars down on the wizard")
	check(await until(func() -> bool: return g.progress > 0.3), "it rides the line")
	check(g.global_position.y < bottom.y - 100.0 and g.has_rider(), "up the cliff, carrying the wizard")
	check(await until(func() -> bool: return g.state == Gondola.State.HELD, 40000), "it reaches the top")
	check(g.global_position.distance_to(g.stations[1]) < 1.0 and g.has_rider(), "at its upper station, the wizard still in it")
	check(g.foes.size() == g.foe_count and g.foes.all(func(f: Node2D) -> bool: return f is RigidBody2D and f.is_in_group(&"hex_target")), "it called up its wraiths on the way (%d)" % g.foe_count)
	await frames(10)
	check(g.sealed and g.state == Gondola.State.HELD, "its bars stay down while they are about")
	# Put them down: the bars lift.
	for f: Node2D in g.foes:
		var wound: Wound = f.get_node("Wound") as Wound
		wound.hit(wound.hp, Vector2.RIGHT)
	check(await until(func() -> bool: return g.state == Gondola.State.WAITING and not g.sealed), "once they are put down, its bars lift")
	await frames(30)
	check(g.state == Gondola.State.WAITING and g.at == 1, "and it does not carry the wizard again before they step out")
	# Out, and down to the lower station: called, it comes back empty.
	player.global_position = bottom + Vector2(-g.cell_px * 1.5, -60)
	player.velocity = Vector2.ZERO
	check(await until(func() -> bool: return g.state == Gondola.State.RIDING), "called from the lower station, it sets off")
	check(not g.sealed and not g.ridden, "empty, its bars up")
	check(await until(func() -> bool: return g.state == Gondola.State.WAITING and g.at == 0, 30000), "it comes down to the wizard")
	# Held too long, it lets the wizard out anyway.
	g.state = Gondola.State.HELD
	g.sealed = true
	var stand_in: Array[Node2D] = [Node2D.new()]
	g.foes = stand_in
	g.held = Gondola.HOLD_MOST
	await physics_frame
	await physics_frame
	check(g.state == Gondola.State.WAITING and not g.sealed, "it never holds its bars down longer than HOLD_MOST")
	for f: Node2D in g.foes:
		f.free()
