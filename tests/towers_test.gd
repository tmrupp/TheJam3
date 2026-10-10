extends TestKit
## The crags' towers (CragsArchetype.build_towers): every crag level has at least one, each tall and
## narrow, of built stone, standing on rock, a room of air on each storey (kept as interiors), the
## ground floor open through a doorway in either wall. Each floor over a room has a stair hole at
## one end, the ends taking turns, with a one-way ledge under it, so the wizard climbs it on their
## own hops (Reach) from the doorway to the top room, and on through the roof's hatch onto the roof
## for a watchtower, where a trapdoor shuts the hatch (opened only from below, trapdoor_test). A
## hoard tower is roofed over and holds stars in its top room; a watchtower's top room
## holds one of the level's keys, a switch for a gate nearby, or a mending bowl (MendWell), and those
## turn up across the levels. Every tower in the band's levels of several worlds is whole once the
## level is laid out: nothing later cracks, carves, fills or tunnels through its walls, floors,
## rooms, doorsteps, footing or the air over its roof, and nothing tall stands in its doorways. A rock-bug nest sits in a room under the top one, and more out on the cliff, away
## from the way in. The keeps' halls are interiors too. Two builds of a level are the same.
## godot --headless --path . --script res://tests/towers_test.gd


func run() -> void:
	var hoards: int = 0
	var watch: int = 0
	var rewards: Dictionary = {}
	for k: int in [0, 1, 2, 3, 5]:
		var at: Vector2i = Vector2i(28, NextWorldDef.band_row(&"crags", k))
		var w: LevelGen = build(at)
		print("row %d: %d towers" % [at.y, w.towers.size()])
		check(not w.towers.is_empty(), "row %d has towers" % at.y)
		for tower: Dictionary in w.towers:
			if tower["hoard"]:
				hoards += 1
			else:
				watch += 1
			_tower(w, tower)
			if not tower["hoard"] and tower.has("reward"):
				rewards[tower["reward"]] = int(rewards.get(tower["reward"], 0)) + 1
		_nests(w)
		check(w.interiors.size() > 0 and w.interiors.keys().all(func(v: Vector2i) -> bool: return not w.masonry.has(v)), "its buildings' air is kept as interiors, none of it masonry")
		var again: LevelGen = build(at)
		check(again.towers == w.towers and again.interiors == w.interiors, "the same every build")
	check(hoards > 0 and watch > 0, "watchtowers and hoard towers both turn up (%d and %d)" % [watch, hoards])
	# Rewards are dealt by the level: look further afield (other worlds' crags) for any not met yet.
	var kinds: Array[LevelGen.Type] = [LevelGen.Type.KEY, LevelGen.Type.SWITCH, LevelGen.Type.WELL]
	for world: int in range(29, 41):
		if kinds.all(func(kind: LevelGen.Type) -> bool: return rewards.has(kind)):
			break
		for k: int in range(NextWorldDef.BAND):
			for tower: Dictionary in build(Vector2i(world, NextWorldDef.band_row(&"crags", k))).towers:
				if not tower["hoard"] and tower.has("reward"):
					rewards[tower["reward"]] = int(rewards.get(tower["reward"], 0)) + 1
	print("rewards: %s" % rewards)
	for kind: LevelGen.Type in kinds:
		check(rewards.has(kind), "a tower's top room holds a %s somewhere" % LevelGen.Type.keys()[kind])
	check(not rewards.has(LevelGen.Type.DRAUGHT), "and never a draught (set aside)")
	_whole_everywhere()
	check(build(Vector2i(28, 0)).towers.is_empty(), "the garden has none")
	finish()


## One tower's build and climb.
func _tower(w: LevelGen, tower: Dictionary) -> void:
	var box: Rect2i = tower["box"]
	var x0: int = box.position.x
	var x1: int = box.end.x - 1
	var roof: int = box.position.y
	var ground: int = box.end.y - 1
	var name_of: String = "tower at %s (%s)" % [box.position, "hoard" if tower["hoard"] else "watch"]
	var storeys: int = (box.size.y - 1) / CragsArchetype.STOREY
	check(box.size.x >= CragsArchetype.TOWER_WIDE.x and storeys >= CragsArchetype.TOWER_STOREYS.x, "%s: %d wide, %d storeys" % [name_of, box.size.x, storeys])
	# Standing on rock: under its footing, down from each column, rock within TOWER_FOOTING rows.
	var grounded: bool = true
	for x: int in range(x0, x1 + 1):
		var y: int = ground + 1
		while w.is_valid(Vector2i(x, y)) and w.masonry.has(Vector2i(x, y)):
			y += 1
		grounded = grounded and (not w.is_valid(Vector2i(x, y)) or w.is_ground(Vector2i(x, y)) or w.is_ground(Vector2i(x, y - 1)))
	check(grounded, "%s: stands on rock" % name_of)
	# Its ledges: one-way platforms under its stair holes.
	var holes: Array = tower["holes"]
	var ledges: Array = tower["ledges"]
	var ok_stair: bool = holes.size() == ledges.size() and holes.size() >= CragsArchetype.STAIR * (storeys - 1)
	for i: int in range(holes.size()):
		var hole: Vector2i = holes[i]
		ok_stair = ok_stair and not w.is_ground(hole) and w.get_cell(ledges[i]).type == LevelGen.Type.PLATFORM and ledges[i] == hole + Vector2i.DOWN
	check(ok_stair, "%s: a stair hole in each floor over a room, a ledge under each (%d)" % [name_of, holes.size()])
	# Climbed on the wizard's own hops from outside its doorway to its top room (and its roof).
	var nodes: Dictionary = Reach.footholds(w)
	var door: Vector2i = Vector2i(x0 - 1, ground - 1) if nodes.has(Vector2i(x0 - 1, ground - 1)) else Vector2i(x1 + 1, ground - 1)
	check(nodes.has(door), "%s: something to stand on outside its doorway" % name_of)
	# Only the tower and its doorsteps: so it is the stair inside that is climbed.
	var inside: Dictionary = {}
	for v: Vector2i in nodes:
		if v.x >= x0 - 1 and v.x <= x1 + 1 and v.y >= roof - 1 and v.y <= ground:
			inside[v] = nodes[v]
	var reach: Dictionary = {door: true}
	Reach.grow(w, inside, reach, [door], {}, {}, Reach.ACROSS, Reach.UP)
	var top: Array = tower["top"]
	check(top.any(func(v: Vector2i) -> bool: return reach.has(v)), "%s: its top room reached on the wizard's own hops" % name_of)
	if tower["hoard"]:
		check(w.is_ground(Vector2i(x0 + 1, roof)) and range(x0 + 1, x1).all(func(x: int) -> bool: return w.is_ground(Vector2i(x, roof))), "%s: roofed over" % name_of)
		var stars: int = top.filter(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.COIN).size()
		check(stars > 0, "%s: stars in its top room (%d)" % [name_of, stars])
	else:
		var on_roof: bool = range(x0, x1 + 1).any(func(x: int) -> bool: return reach.has(Vector2i(x, roof - 1)))
		check(on_roof, "%s: out through the hatch onto its roof" % name_of)
		check(holes.filter(func(v: Vector2i) -> bool: return v.y == roof).all(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.TRAPDOOR), "%s: a trapdoor in its roof's hatch" % name_of)
	# What it holds: a nest in a room below the top, and its reward in the top room, reached.
	var nest: bool = false
	for x: int in range(x0 + 1, x1):
		for y: int in range(roof + 1, ground):
			nest = nest or w.get_cell(Vector2i(x, y)).type == LevelGen.Type.NEST
	check(nest, "%s: a rock-bug nest inside" % name_of)
	if tower["hoard"] or not tower.has("reward"):
		return
	var reward: LevelGen.Type = tower["reward"]
	var held: Array = top.filter(func(v: Vector2i) -> bool: return w.get_cell(v).type == reward)
	# Over the floor, or over its stair hole (taken standing in the hole, on the ledge under it).
	check(reward in [LevelGen.Type.KEY, LevelGen.Type.SWITCH, LevelGen.Type.WELL] and not held.is_empty() and (reach.has(held[0]) or reach.has(held[0] + Vector2i.DOWN)), "%s: a %s in its top room, reached" % [name_of, LevelGen.Type.keys()[reward]])
	if reward == LevelGen.Type.SWITCH:
		var gate: Vector2i = w.get_cell(held[0]).extra_info
		check(w.get_cell(gate).type == LevelGen.Type.SWITCH_GATE and w.get_cell(gate).extra_info == held[0], "%s: the switch and its gate know each other" % name_of)
	if reward == LevelGen.Type.WELL:
		check(w.is_ground(held[0] + Vector2i.DOWN), "%s: its mending bowl stands on the floor" % name_of)
	if reward == LevelGen.Type.KEY:
		check(held[0] != w.start_key and w.get_cell(held[0]).extra_info != null, "%s: its key is one the level deals, dealt a colour" % name_of)


## Every tower in every row of the band in several worlds is whole once its level is laid out (see
## _faults).
func _whole_everywhere() -> void:
	var towers: int = 0
	var faulty: Array[String] = []
	for world: int in [28, 7, 99, 51]:
		for k: int in range(NextWorldDef.BAND):
			var at: Vector2i = Vector2i(world, NextWorldDef.band_row(&"crags", k))
			var w: LevelGen = build(at)
			if w == null:
				continue
			for tower: Dictionary in w.towers:
				towers += 1
				var faults: Array[String] = _faults(w, tower)
				if not faults.is_empty():
					faulty.append("%s tower at %s: %s" % [at, (tower["box"] as Rect2i).position, ", ".join(faults.slice(0, 4))])
	for f: String in faulty:
		print("  ", f)
	check(towers > 20 and faulty.is_empty(), "every tower is whole once its level is laid out (%d towers, %d not)" % [towers, faulty.size()])


## What is wrong with `tower` in `w`, laid out: a floor (or roof) broken but for its stair holes, a
## room or the air over the roof filled, a wall broken but for its doorways and windows (or one
## opening onto rock), cracked stone, the ground row or the rock under it gone, a doorstep filled, a
## ledge under a stair hole missing, or something set in a doorway.
func _faults(w: LevelGen, tower: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var box: Rect2i = tower["box"]
	var x0: int = box.position.x
	var x1: int = box.end.x - 1
	var roof: int = box.position.y
	var ground: int = box.end.y - 1
	var holes: Array = tower["holes"]
	var stone: Callable = func(v: Vector2i) -> bool: return w.is_ground(v) or w.get_cell(v).type == LevelGen.Type.CRACKED
	for y: int in range(roof, ground + 1):
		for x: int in range(x0, x1 + 1):
			var v: Vector2i = Vector2i(x, y)
			if w.get_cell(v).type == LevelGen.Type.CRACKED:
				out.append("cracked %s" % v)
	for x: int in [x0 - 1, x1 + 1]:
		if w.get_cell(Vector2i(x, ground)).type == LevelGen.Type.CRACKED:
			out.append("cracked %s" % Vector2i(x, ground))
	for y: int in range(roof, ground, CragsArchetype.STOREY):
		for x: int in range(x0, x1 + 1):
			var v: Vector2i = Vector2i(x, y)
			if not holes.has(v) and not stone.call(v):
				out.append("floor broken %s" % v)
		for r: int in [y + 1, y + 2]:
			for x: int in range(x0 + 1, x1):
				if w.is_ground(Vector2i(x, r)):
					out.append("room filled %s" % Vector2i(x, r))
	for y: int in range(roof, ground + 1):
		for x: int in [x0, x1]:
			var v: Vector2i = Vector2i(x, y)
			if stone.call(v):
				continue
			var opening: bool = y == ground - 1 or ((y - roof) % CragsArchetype.STOREY == 2)
			if not opening:
				out.append("wall broken %s" % v)
			elif w.is_ground(v + (Vector2i.LEFT if x == x0 else Vector2i.RIGHT)):
				out.append("opening onto rock %s" % v)
			elif w.get_cell(v).type != LevelGen.Type.EMPTY:
				out.append("%s in a doorway %s" % [LevelGen.Type.keys()[w.get_cell(v).type], v])
	for x: int in range(x0 - 1, x1 + 2):
		if not stone.call(Vector2i(x, ground)) or (w.is_valid(Vector2i(x, ground + 1)) and not stone.call(Vector2i(x, ground + 1))):
			out.append("not standing %s" % Vector2i(x, ground))
	for x: int in [x0 - 1, x1 + 1]:
		for y: int in [ground - 1, ground - 2]:
			if w.is_ground(Vector2i(x, y)):
				out.append("doorstep filled %s" % Vector2i(x, y))
	for v: Vector2i in tower["ledges"]:
		if w.get_cell(v).type != LevelGen.Type.PLATFORM:
			out.append("ledge gone %s" % v)
	for x: int in range(x0, x1 + 1):
		for d: int in range(1, CragsArchetype.ROOF_AIR + 1):
			if w.is_ground(Vector2i(x, roof - d)):
				out.append("roof buried %s" % Vector2i(x, roof - d))
	return out


## The nests out on the cliff: some, none near the way in.
func _nests(w: LevelGen) -> void:
	var start: Vector2i = w.exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	var nests: Array[Vector2i] = w.objects_of(LevelGen.Type.NEST)
	var out: Array[Vector2i] = nests.filter(func(v: Vector2i) -> bool: return not w.structures.has(v))
	check(out.size() > 0 and nests.all(func(v: Vector2i) -> bool: return LevelGen.dist(v, start) >= CragsArchetype.NEST_CLEAR) and out.all(func(v: Vector2i) -> bool: return w.is_ground(v + Vector2i.DOWN)), "%d nests, %d out on the cliff, all on floors away from the way in" % [nests.size(), out.size()])
