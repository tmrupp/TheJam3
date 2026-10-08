extends TestKit
## The crags (CragsArchetype, docs/REGIONS_PLAN.md §7): their own sample (collapsed unturned),
## taller than wide, open (caverns), a structure pass (shafts, keeps and towers, kept as masonry),
## the same every build; their realm and decor (battlements and dressed stone on the masonry only);
## doors in their passages; rock-bugs; and the gondola's line: from near the bottom to near the top,
## straight up and up 45° diagonals only, carved and kept clear, counted as somewhere to stand, at
## least four stations, each a doorway onto a landing, all shut but one (by a door, a switch gate
## with its switch, or a toll gate). In play: its sides up while it stands; the lever sets it off
## with its rider barred in; a rock-bug comes out on its track, climbs in and is let off onto the
## rock when it stands with its sides up; a bug turns back at its barred sides while it runs; it
## never holds its rider; it may run from an open station to a shut one and back, never on from one
## shut station to the next; the lever stops it on the way (its sides lift) and sends it back; a
## placed rock-bug clings to rock, walks along it round its corners and, stunned, falls and clings
## again; a toll gate lifts for its price; and called from an opened station, it comes over empty.
## godot --headless --path . --script res://tests/crags_test.gd


func run() -> void:
	generation()
	await ride()
	RunState.delete_save()
	finish()


func generation() -> void:
	print("laid out")
	var diagonal: int = 0
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
		var bugs: Array[Vector2i] = w.objects_of(LevelGen.Type.BUG)
		check(not bugs.is_empty() and bugs.all(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.BUG), "row %d has rock-bugs (%d; each clings to the rock nearest, or falls to it)" % [at.y, bugs.size()])
		diagonal += _circuit(w, at)
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
	check(diagonal > 0, "some of its climbs are diagonal (%d steps)" % diagonal)


## Row `at`'s gondola and its line, laid out as `w`; how many of its steps are diagonal comes back.
func _circuit(w: LevelGen, at: Vector2i) -> int:
	var gondolas: Array[Vector2i] = w.objects_of(LevelGen.Type.GONDOLA)
	check(gondolas.size() == 1, "row %d has a gondola" % at.y)
	if gondolas.size() != 1:
		return 0
	var info: Dictionary = w.get_cell(gondolas[0]).extra_info
	var path: Array[Vector2i] = info["path"]
	var stops: Array[int] = info["stops"]
	var gates: Array[Vector2i] = info["gates"]
	check(stops.size() >= CragsArchetype.STATIONS_MIN, "its line has %d stations" % stops.size())
	check(gondolas[0] == path[stops[int(info["start"])]], "its car waits at its open station")
	check(float(path[0].y) > float(w.size.y) * 0.7 and float(path[-1].y) < float(w.size.y) * 0.3, "it climbs from near the bottom of the level (row %d) to near its top (row %d)" % [path[0].y, path[-1].y])
	var diagonal: int = 0
	var steps_ok: bool = true
	for i: int in range(1, path.size()):
		var d: Vector2i = path[i] - path[i - 1]
		steps_ok = steps_ok and d in [Vector2i.UP, Vector2i(1, -1), Vector2i(-1, -1)]
		diagonal += 1 if d.x != 0 and d.y != 0 else 0
	check(steps_ok, "it only climbs, straight up or up a 45° diagonal (never flat, never in steps)")
	check(stops.all(func(k: int) -> bool: return (k == 0 or path[k] - path[k - 1] == Vector2i.UP) and (k == path.size() - 1 or path[k + 1] - path[k] == Vector2i.UP)), "at every station its track runs straight up")
	var astray: Array[String] = []
	for i: int in range(path.size()):
		for c: Vector2i in CragsArchetype.swept_cells(path[i], path[mini(i + 1, path.size() - 1)]):
			if not (w.keep_clear.has(c) and not w.empties.has(c) and (w.get_cell(c).type == LevelGen.Type.EMPTY or c == gondolas[0])):
				astray.append("%s %s" % [c, LevelGen.Type.keys()[w.get_cell(c).type]])
	check(astray.is_empty(), "the way it sweeps is open all along and kept clear of what is laid after %s" % ", ".join(astray))
	var nodes: Dictionary = Reach.footholds(w)
	check(path.all(func(p: Vector2i) -> bool: return nodes.has(p) or p == gondolas[0]), "its whole track counts as somewhere to stand (riding it)")
	var shut: int = 0
	for i: int in range(gates.size()):
		var g: Vector2i = gates[i]
		check(w.is_ground(g + Vector2i.UP) and w.is_ground(g + Vector2i.DOWN), "station %d's doorway is a cell high" % i)
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
	return diagonal


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
	check(not g.side_shut[0] and not g.side_shut[1] and g.shut[0] < 0.01, "standing, its sides are up")
	# In, and the lever: it runs on to the next station, its rider barred in.
	player.global_position = g.center() + Vector2(0, 40)
	player.velocity = Vector2.ZERO
	check(await until(func() -> bool: return g.has_rider() and player.is_on_floor()), "the wizard steps into the car")
	var next: int = int(g.next_station(g.s, 1)[0])
	g.pull()
	check(g.running and g.ridden and g.bound_for == next, "the lever sets it off to the next station")
	check(await until(func() -> bool: return g.sealed) and g.side_shut[0] and g.side_shut[1], "barring its rider in")
	var from: Vector2 = g.global_position
	check(await until(func() -> bool: return not g.running, 40000), "it runs up its track and stops at the station")
	check(g.global_position.y < from.y - 500.0, "up the cliff")
	check(g.at_station == next and g.has_rider(), "the wizard still in it")
	check(not g.sealed and not g.side_shut[0] and not g.side_shut[1], "standing, it never holds its rider: both sides lift")
	check(g.foes.size() == 1 and (g.foes[0] as Node2D).is_in_group(&"hex_target"), "it called one rock-bug out onto its track on the way")
	var climber: RockBug = (g.foes[0] as Node2D).get_node("RockBug") as RockBug
	check(await until(func() -> bool: return climber.mode == RockBug.Mode.CAR, 15000), "the rock-bug walks along the cable and climbs into the car")
	check(await until(func() -> bool: return climber.mode != RockBug.Mode.CAR, 15000) and climber.mode == RockBug.Mode.ROCK, "with its sides up, it walks off the car onto the rock (let off)")
	check(absf(climber.rb.global_position.x - g.global_position.x) > g.cell_px * 0.9, "beside the car")
	# Shut here and shut on: the lever balks, and the next pull takes it back.
	check(not g.is_open(next) and not g.is_open(int(g.next_station(g.s, 1)[0])), "this station is shut, and so is the next")
	g.pull()
	check(not g.running and g.next_dir == -1, "from one shut station it will not run on to the next")
	g.pull()
	check(g.running and g.bound_for == start, "it runs back to the open station")
	# A bug in the car while it runs turns back at its barred sides.
	check(await until(func() -> bool: return g.foes.size() == 2), "it calls another rock-bug out on this stretch")
	var rider: RockBug = (g.foes[1] as Node2D).get_node("RockBug") as RockBug
	await until(func() -> bool: return rider.mode == RockBug.Mode.CAR or not g.running, 15000)
	if g.running and rider.mode == RockBug.Mode.CAR:
		rider.car_x = rider._car_edge() - 1.0
		rider.way = 1
		await physics_frame
		await physics_frame
		check(not g.running or (rider.way == -1 and absf(rider.car_x) <= rider._car_edge() and rider.mode == RockBug.Mode.CAR), "a bug in the running car turns back at its barred side")
	check(await until(func() -> bool: return not g.running and g.at_station == start, 40000), "back at the open station")
	# Stopped on the way, its sides lift; pulled again, it heads back. (From the line's end the
	# lever's first pull balks, and the next goes the other way.)
	g.pull()
	if not g.running:
		g.pull()
	check(g.running and g.bound_for == next, "the lever sets it off again")
	await until(func() -> bool: return g.speed > 200.0)
	g.pull()
	check(not g.running and g.at_station < 0, "the lever stops it between stations")
	check(not g.side_shut[0] and not g.side_shut[1], "where its sides lift")
	g.pull()
	check(g.running and g.bound_for == start, "and pulled again it heads back the way it came")
	check(await until(func() -> bool: return not g.running and g.at_station == start, 40000), "back at the open station")
	await rock_bugs()
	# A toll gate lifts for its price (one placed here, if this level has none of its own).
	var tolls: Array[Node] = placed("toll_gate.tscn")
	if tolls.is_empty():
		var spare: TollGate = Placeables.scene(LevelGen.Type.TOLL).instantiate() as TollGate
		spare.set_meta(&"cell", Vector2i(-5, -5))
		info.map_elements.add_child(spare)
		spare.setup(info, Vector2i(-5, -5), Rules.toll_price(info.here.depth))
		tolls.append(spare)
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
	if info.world.get_cell(gate_cell).type == LevelGen.Type.SWITCH_GATE:
		# A switch gate is up while its switch is on.
		info.set_switch(info.world.get_cell(gate_cell).extra_info, true)
		for n: Node in info.map_elements.get_children():
			if n.get_meta(&"cell", Vector2i(-1, -1)) == gate_cell:
				(n as SwitchGate).set_up(true)
	else:
		info.record().opened[gate_cell] = true
		for n: Node in info.map_elements.get_children():
			if n.get_meta(&"cell", Vector2i(-1, -1)) == gate_cell:
				n.queue_free()
	player.global_position = info.cell_position(gate_cell + Vector2i(g.inner[next], 0)) + Vector2(0, 20)
	player.velocity = Vector2.ZERO
	check(await until(func() -> bool: return g.running), "called from an opened station's landing, it sets off")
	check(not g.ridden and not g.sealed, "empty")
	check(await until(func() -> bool: return not g.running and g.at_station == next, 40000), "and comes to the wizard")


## A rock-bug placed in the level: it clings to rock and walks along it; stunned, it falls, lands on
## rock and clings again.
func rock_bugs() -> void:
	print("rock-bugs")
	var bugs: Array[Node] = placed("rock_bug.tscn")
	check(not bugs.is_empty(), "the level has rock-bugs")
	if bugs.is_empty():
		return
	var bug: RockBug = (bugs[0] as Node2D).get_node("RockBug") as RockBug
	# The wizard a little way off, so its part of the level is awake.
	player.global_position = bug.rb.global_position + Vector2(600.0, -40.0)
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	var clinging: Callable = func() -> bool: return bug.mode == RockBug.Mode.ROCK and info.solid_at(bug.rb.global_position + Vector2(bug.normal) * (RockBug.BODY + 8.0))
	check(await until(clinging), "it clings to rock")
	var was: Vector2 = bug.rb.global_position
	await frames(90)
	check(bug.rb.global_position.distance_to(was) > 40.0, "it walks")
	var off_rock: int = 0
	for i: int in range(120):
		await physics_frame
		if bug.mode == RockBug.Mode.ROCK and bug.u >= 1.0 and not info.solid_at(bug.rb.global_position + Vector2(bug.to_normal) * (RockBug.BODY + 8.0)):
			off_rock += 1
	check(off_rock == 0, "along the rock, never letting go of it (round its corners too)")
	var height: float = bug.rb.global_position.y
	Stunner.of(bug.rb).stun(1.0)
	await physics_frame
	await physics_frame
	check(bug.mode == RockBug.Mode.FALLING or bug.normal == Vector2i.DOWN, "stunned, it lets go (or stays on the floor it stands on)")
	check(await until(func() -> bool: return bug.mode == RockBug.Mode.ROCK and not bug.stunned), "it lands on rock and clings again")
	check(bug.rb.global_position.y >= height - 1.0 and clinging.call(), "below where it let go, against rock")
	player.set_physics_process(true)
