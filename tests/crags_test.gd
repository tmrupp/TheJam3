extends TestKit
## The crags (CragsArchetype, docs/REGIONS_PLAN.md §7): their own sample (collapsed unturned),
## taller than wide, open (caverns), a structure pass (shafts, keeps and towers, kept as masonry),
## the same every build; their realm and decor (battlements and dressed stone on the masonry only);
## doors in their passages; and the gondola's circuit: carved and kept clear all the way round,
## counted as somewhere to stand, with at least four stations, each a doorway onto a landing, all
## shut but one (by a door, a switch gate with its switch, or a toll gate). In play: the lever sets
## it off, it runs along the circuit with its rider barred in, calls up wraiths, stops at the next
## station and holds until they are put down; it may run from an open station to a shut one and
## back, never on from one shut station to the next; the lever stops it on the way and sends it back;
## a toll gate lifts for its price; and called from an opened station, it comes over empty.
## godot --headless --path . --script res://tests/crags_test.gd


func run() -> void:
	generation()
	await ride()
	RunState.delete_save()
	finish()


func generation() -> void:
	print("laid out")
	for k: int in [0, 2, 5]:
		var at: Vector2i = Vector2i(28, NextWorldDef.band_row(&"crags", k))
		var def: NextWorldDef = Rules.def_for(at)
		check(def.archetype == &"crags" and def.symmetry == 1 and def.region == CragsArchetype.SAMPLE and def.realm() == &"crags", "row %d is a crag level, collapsed unturned from its own sample, in its own realm" % at.y)
		check(def.size.y > def.size.x, "row %d is taller than wide (%s)" % [at.y, def.size])
		var w: LevelGen = build(at)
		var again: LevelGen = build(at)
		check(w.objects == again.objects and w.masonry == again.masonry, "row %d lays out the same every time" % at.y)
		var rock: int = 0
		for x: int in range(w.size.x):
			for y: int in range(w.size.y):
				rock += 1 if w.is_ground(Vector2i(x, y)) else 0
		check(float(rock) < 0.45 * float(w.size.x * w.size.y), "row %d is open: %d%% rock" % [at.y, rock * 100 / (w.size.x * w.size.y)])
		check(not w.masonry.is_empty() and w.masonry.keys().all(func(v: Vector2i) -> bool: return w.is_ground(v) or w.get_cell(v).type == LevelGen.Type.CRACKED), "row %d has castle masonry, all of it rock (or cracked rock)" % at.y)
		check(count_of(w, LevelGen.Type.DOOR) + count_of(w, LevelGen.Type.SWITCH_GATE) > 0, "row %d has doors or switch gates" % at.y)
		_circuit(w, at)
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
		check(kinds.has(&"ashlar") and not kinds.has(&"headstone"), "row %d wears the crags' decor" % at.y)
		check(astray == 0, "its battlements, dressed stone and arrow slits are all on masonry (%d astray)" % astray)


## Row `at`'s gondola and its circuit, laid out as `w`.
func _circuit(w: LevelGen, at: Vector2i) -> void:
	var gondolas: Array[Vector2i] = w.objects_of(LevelGen.Type.GONDOLA)
	check(gondolas.size() == 1, "row %d has a gondola" % at.y)
	if gondolas.size() != 1:
		return
	var info: Dictionary = w.get_cell(gondolas[0]).extra_info
	var loop: Rect2i = info["loop"]
	var stops: Array[Vector2i] = info["stops"]
	var gates: Array[Vector2i] = info["gates"]
	check(stops.size() >= CragsArchetype.STATIONS_MIN, "its circuit has %d stations" % stops.size())
	check(gondolas[0] == stops[int(info["start"])], "its car waits at its open station")
	var ring: Array[Vector2i] = CragsArchetype.loop_cells(loop)
	check(ring.size() == CragsArchetype.perimeter(loop) and ring.all(func(p: Vector2i) -> bool: return p.x == loop.position.x or p.x == loop.end.x or p.y == loop.position.y or p.y == loop.end.y), "it runs round a rectangle, along rows and columns only")
	var astray: Array[String] = []
	for p: Vector2i in ring:
		for c: Vector2i in CragsArchetype.car_cells(p):
			if not (w.keep_clear.has(c) and not w.empties.has(c) and (w.get_cell(c).type == LevelGen.Type.EMPTY or c == gondolas[0])):
				astray.append("%s %s%s" % [c, LevelGen.Type.keys()[w.get_cell(c).type], " (listed empty)" if w.empties.has(c) else ""])
	check(astray.is_empty(), "its corridor is open all the way round and kept clear of what is laid after %s" % ", ".join(astray))
	var nodes: Dictionary = Reach.footholds(w)
	check(ring.all(func(p: Vector2i) -> bool: return nodes.has(p) or p == gondolas[0]), "the whole circuit counts as somewhere to stand (riding it)")
	var shut: int = 0
	for i: int in range(gates.size()):
		var g: Vector2i = gates[i]
		check(w.is_ground(g + Vector2i.UP) and w.is_ground(g + Vector2i.DOWN), "station %d's doorway is a cell high (%s: over %s, under %s)" % [i, g, LevelGen.Type.keys()[w.get_cell(g + Vector2i.UP).type], LevelGen.Type.keys()[w.get_cell(g + Vector2i.DOWN).type]])
		var t: LevelGen.Type = w.get_cell(g).type
		if i == int(info["start"]):
			check(t == LevelGen.Type.EMPTY, "the station nearest the way in is open")
			continue
		check(t in Gondola.GATES, "station %d is shut by a %s" % [i, LevelGen.Type.keys()[t]])
		shut += 1
		if t == LevelGen.Type.SWITCH_GATE:
			var lever: Vector2i = w.get_cell(g).extra_info
			check(w.get_cell(lever).type == LevelGen.Type.SWITCH and w.get_cell(lever).extra_info == g, "its switch is out in the level")
		if t == LevelGen.Type.TOLL:
			check(int(w.get_cell(g).extra_info) == Rules.toll_price(absi(at.y)), "its toll is the price for the depth")
	check(shut == stops.size() - 1, "all its other stations are shut")


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
	check(all.size() == 1, "the level has a gondola")
	if all.is_empty():
		return
	var g: Gondola = all[0] as Gondola
	var start: int = g.at_station
	check(g.is_open(start) and range(g.stops.size()).filter(func(i: int) -> bool: return g.is_open(i)).size() == 1, "it waits at its one open station")
	await frames(10)
	check(not g.side_shut[0 if g.inner[start] < 0 else 1], "its side facing the level stands open")
	# In, and the lever: it runs on to the next station, its rider barred in.
	player.global_position = g.center() + Vector2(0, 40)
	player.velocity = Vector2.ZERO
	check(await until(func() -> bool: return g.has_rider() and player.is_on_floor()), "the wizard steps into the car")
	var next: int = int(g.next_station(g.s, 1)[0])
	g.pull()
	check(g.running and g.ridden and g.bound_for == next, "the lever sets it off to the next station")
	check(await until(func() -> bool: return g.sealed) and g.side_shut[0] and g.side_shut[1], "barring its rider in")
	var from: Vector2 = g.global_position
	await until(func() -> bool: return g.global_position.distance_to(from) > 300.0)
	var moved: Vector2 = (g.global_position - from).abs()
	check(minf(moved.x, moved.y) < 1.0, "it runs straight along a row or column")
	check(await until(func() -> bool: return not g.running, 40000), "and stops at the station")
	check(g.at_station == next and g.has_rider(), "the wizard still in it")
	check(g.foes.size() == g.foe_count and g.foes.all(func(f: Node2D) -> bool: return f.is_in_group(&"hex_target")), "it called up its wraiths on the way (%d)" % g.foe_count)
	await frames(10)
	check(g.sealed, "its bars stay down while they are about")
	for f: Node2D in g.foes:
		var wound: Wound = f.get_node("Wound") as Wound
		wound.hit(wound.hp, Vector2.RIGHT)
	check(await until(func() -> bool: return not g.sealed), "once they are put down, its bars lift")
	# Shut here and shut on: the lever balks, and the next pull takes it back.
	check(not g.is_open(next) and not g.is_open(int(g.next_station(g.s, 1)[0])), "this station is shut, and so is the next")
	g.pull()
	check(not g.running and g.next_dir == -1, "from one shut station it will not run on to the next")
	g.pull()
	check(g.running and g.bound_for == start, "it runs back to the open station")
	# Stopped on the way, it stands barred; pulled again, it heads back.
	await until(func() -> bool: return g.speed > 200.0)
	g.pull()
	check(not g.running and g.at_station < 0 and g.sealed, "the lever stops it between stations, barred")
	g.pull()
	check(g.running and g.bound_for == next, "and pulled again it heads back the way it came")
	g.pull()
	g.pull()
	check(g.running and g.bound_for == start, "and again")
	check(await until(func() -> bool: return not g.running and g.at_station == start, 40000), "back at the open station")
	await until(func() -> bool: return not g.sealed)
	# A toll gate lifts for its price.
	var tolls: Array[Node] = placed("toll_gate.tscn")
	check(not tolls.is_empty(), "the level has a toll gate")
	if not tolls.is_empty():
		var toll: TollGate = tolls[0] as TollGate
		player.collect(toll.price - player.coins.coins - 1)
		toll.pay()
		check(not toll.is_queued_for_deletion(), "a toll gate stays shut without its price")
		player.collect(1)
		toll.pay()
		check(toll.is_queued_for_deletion() and player.coins.coins == 0 and info.record().opened.has(toll.get_meta(&"cell")), "and lifts for good for it")
	# Open the next station and call the car there from its landing: it comes over empty.
	var gate_cell: Vector2i = g.gates[next]
	info.record().opened[gate_cell] = true
	for n: Node in info.map_elements.get_children():
		if n.get_meta(&"cell", Vector2i(-1, -1)) == gate_cell:
			n.queue_free()
	player.global_position = info.cell_position(gate_cell + Vector2i(g.inner[next], 0)) + Vector2(0, 20)
	player.velocity = Vector2.ZERO
	check(await until(func() -> bool: return g.running), "called from an opened station's landing, it sets off")
	check(not g.ridden and not g.sealed, "empty")
	check(await until(func() -> bool: return not g.running and g.at_station == next, 40000), "and comes to the wizard")
