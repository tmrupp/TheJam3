extends TestKit
## The crags' lodestones and empowered casts (Lodestone, Empower, Spire; docs/REGIONS_PLAN.md §7).
## Laid out: a level dealt a lodestone (Rules.lodestone_at) holds it on a floor reached from the
## gondola's track without breaking cracked rock, mostly high on the cliff in sight of the track;
## a level dealt none holds none; every watchtower has a spire on its roof, and a cold tower is never
## a hoard tower nor on the bottom tier. In play: before any lodestone the Spell button casts at
## once, held or not; touching a lodestone tempers its spell (once, counted once, kept in the save)
## and sets the recharge to 60 s, which a second stone shortens to 45; held 0.4 s, a tempered spell
## casts empowered (the guard up on the press) and empowerment goes to recharge, while a quick press
## casts on letting go; a plain bolt only chips cracked rock, and each damage spell, empowered,
## breaks it its own way; a plain hit on a spire does nothing, an empowered bolt flips its tower's
## switch under the lock, a cold tower's switch balks until a strike on its spire wakes it; riding
## the gondola up inks the map round the car, and reaching the top station inks the levels round
## whole, and a lodestone there shows on the worlds map.
## godot --headless --path . --script res://tests/lodestone_test.gd

const WORLD: int = 28


func run() -> void:
	if not needs([&"crags"]):
		finish()
		return
	_placement()
	await boot(WORLD)
	player.end_invulnerable()
	player.health.max_health = 99
	player.health.health = 99
	var at: Vector2i = _play_level()
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	print("in %s, a lodestone of %s" % [at, Rules.lodestone_at(at)])
	# Enemies kept out of the bolts' way (and off the wizard).
	for foe: Node in get_nodes_in_group(&"hex_target"):
		if not foe is Spire:
			foe.remove_from_group(&"hex_target")
			foe.process_mode = Node.PROCESS_MODE_DISABLED
	await _touch()
	await _hold()
	await _breaks()
	await _spires()
	await _ride()
	finish()


## The first level from WORLD along crags row `row` that holds a lodestone.
func _lodestone_level(row: int) -> Vector2i:
	for x: int in range(WORLD, WORLD + Rules.LODESTONE_STRETCH):
		if Rules.lodestone_at(Vector2i(x, row)) != &"":
			return Vector2i(x, row)
	return Vector2i(WORLD, row)


## The level played in: the first lodestone level along the crags' first rows (as
## _lodestone_level goes) that has two watchtowers or more as well, for their spires (_spires), and
## cracked walls enough for every damage spell to break one (_breaks); else the first row's
## lodestone level.
func _play_level() -> Vector2i:
	for row: int in band_rows(&"crags", [0, 1, 2], false):
		for x: int in range(WORLD, WORLD + Rules.LODESTONE_STRETCH):
			var at: Vector2i = Vector2i(x, row)
			if Rules.lodestone_at(at) == &"":
				continue
			var w: LevelGen = build(at)
			if w == null or w.towers.filter(func(t: Dictionary) -> bool: return not t["hoard"] and t.has("spire")).size() < 2:
				continue
			var across: Array[Vector2i] = _laid_walls(w, true)
			var over: Array[Vector2i] = _laid_walls(w, false).filter(func(c: Vector2i) -> bool: return not across.has(c))
			if not across.is_empty() and across.size() + over.size() >= 6:
				return at
	return _lodestone_level(NextWorldDef.band_row(&"crags", 0))


func _placement() -> void:
	print("where lodestones stand")
	var levels: Array[Vector2i] = []
	for row: int in band_rows(&"crags", [0, 3, -1]):
		levels.append(_lodestone_level(row))
	var high_seen: int = 0
	for at: Vector2i in levels:
		var w: LevelGen = build(at)
		var v: Vector2i = w.lodestone
		var spell: StringName = Rules.lodestone_at(at)
		check(w.is_valid(v) and w.get_cell(v).type == LevelGen.Type.LODESTONE and StringName(w.get_cell(v).extra_info) == spell, "%s holds its lodestone (%s) at %s" % [at, spell, v])
		if not w.is_valid(v):
			continue
		var path: Array[Vector2i] = w.circuit["path"]
		check(w.reach_from(path[0]).has(v) and w.is_ground(v + Vector2i.DOWN) and not w.is_ground(v + Vector2i.UP), "on a floor reached from the track without breaking cracked rock")
		var upper: int = ceili(float(CragsArchetype.tier_count(w)) / 2.0)
		if CragsArchetype.tier_of(w, v.y) >= upper and CragsArchetype.in_sight_of_track(w, v):
			high_seen += 1
		var watch: Array[Dictionary] = w.towers.filter(func(t: Dictionary) -> bool: return not t["hoard"])
		check(watch.all(func(t: Dictionary) -> bool: return t.has("spire") and w.get_cell(t["spire"]).type == LevelGen.Type.SPIRE and (t["spire"] as Vector2i).y == (t["box"] as Rect2i).position.y - 1), "each of its %d watchtowers has a spire on its roof" % watch.size())
		check(w.towers.all(func(t: Dictionary) -> bool: return not t.get("cold", false) or (not t["hoard"] and CragsArchetype.tier_of(w, (t["box"] as Rect2i).end.y - 1) > 0)), "a cold tower is a watchtower above the bottom tier")
	check(high_seen >= levels.size() - 1, "high on the cliff, in sight of the track (%d of %d)" % [high_seen, levels.size()])
	var again: LevelGen = build(levels[0])
	check(again.lodestone == build(levels[0]).lodestone, "in the same place every build")
	var bare: Vector2i = Vector2i(levels[0].x + 1, levels[0].y)
	while Rules.lodestone_at(bare) != &"":
		bare.x += 1
	check(build(bare).objects_of(LevelGen.Type.LODESTONE).is_empty(), "a level dealt none holds none")


func _touch() -> void:
	print("touching a lodestone")
	var stones: Array[Node] = placed("lodestone.tscn")
	check(stones.size() == 1, "the level's lodestone stands in it")
	if stones.is_empty():
		return
	var stone: Lodestone = stones[0] as Lodestone
	var empower: Empower = Empower.of(player)
	check(empower != null and not empower.ready_now() and not is_finite(Empower.recharge()), "before any lodestone, nothing casts empowered")
	player.global_position = stone.global_position
	player.velocity = Vector2.ZERO
	check(await until(func() -> bool: return info.run.tempered.has(stone.spell)), "touched, it tempers %s" % stone.spell)
	check(info.run.lodestones.size() == 1 and info.run.lodestones.get(info.coord) == stone.spell and is_equal_approx(Empower.recharge(), 60.0), "it counts once: an empowered cast comes back in 60 s")
	check(not info.touch_lodestone(stone.spell) and info.run.lodestones.size() == 1, "touched again, it counts no more")
	info.run.touch_lodestone(info.coord + Vector2i(1, 0), &"hex")
	empower.wait = Rules.empower_recharge(1)
	empower.shorten()
	check(is_equal_approx(empower.wait, 45.0), "a second stone cuts what is left to 45 s")
	var data: Dictionary = info.run.to_save(info.coord, {})
	var back: RunState = RunState.new()
	back.from_save(data)
	check(back.tempered == info.run.tempered and back.lodestones == info.run.lodestones, "both kept in the save")
	player.global_position = info.cell_position(info.world.exits[MapInfo.Exit.BACK])
	await frames(4)


## Every hex bolt added to the level from now on.
var bolts: Array[HexBolt] = []


func _note_bolt(n: Node) -> void:
	if n is HexBolt:
		bolts.append(n as HexBolt)


func _hold() -> void:
	print("held, a tempered spell casts empowered")
	info.map_elements.child_entered_tree.connect(_note_bolt)
	for spell: StringName in Abilities.in_slot(&"damage"):
		info.run.tempered[spell] = true
	Abilities.set_tier(player, &"hex", 1)
	var hex: Hex = player.get_node("Hex") as Hex
	var parry: Parry = player.get_node("Parry") as Parry
	var empower: Empower = Empower.of(player)
	empower.wait = 0.0
	hex.refill()
	var guard: float = parry.raised_at
	Input.action_press(Abilities.SPELL_ACTION)
	await frames(4)
	check(bolts.is_empty() and empower.held >= 0.0, "pressed, it waits to see how long the button is held")
	check(parry.raised_at > guard, "the guard went up on the press")
	check(await within(func() -> bool: return not bolts.is_empty(), Empower.HOLD + 0.3) and bolts[0].empowered and bolts[0].bore == HexBolt.BORE, "held 0.4 s, an empowered bolt flies")
	check(absf(empower.wait - Empower.recharge()) < 0.5, "and empowerment goes to recharge (%.0f s)" % empower.wait)
	Input.action_release(Abilities.SPELL_ACTION)
	await frames(2)
	bolts.clear()
	hex.refill()
	Input.action_press(Abilities.SPELL_ACTION)
	await frames(3)
	check(bolts.size() == 1 and not bolts[0].empowered, "recharging, a press casts at once, as ever")
	Input.action_release(Abilities.SPELL_ACTION)
	await frames(2)
	bolts.clear()
	hex.refill()
	empower.wait = 0.0
	Input.action_press(Abilities.SPELL_ACTION)
	await frames(3)
	check(bolts.is_empty(), "ready, a quick press waits")
	Input.action_release(Abilities.SPELL_ACTION)
	await frames(3)
	check(bolts.size() == 1 and not bolts[0].empowered and empower.wait == 0.0, "and casts as ever on letting go, empowerment kept")
	bolts.clear()
	hex.refill()
	info.run.tempered.erase(&"hex")
	Input.action_press(Abilities.SPELL_ACTION)
	await frames(3)
	check(bolts.size() == 1 and not bolts[0].empowered, "a spell not tempered casts at once, held or not")
	Input.action_release(Abilities.SPELL_ACTION)
	info.run.tempered[&"hex"] = true
	await frames(2)


## The cracked walls (not a secret room's) with open air beside them along their row (`across`), or
## else over or under them: [the wall's cell, the cell the wizard stands in by it], in order.
func _walls(across: bool) -> Array:
	var out: Array = []
	for n: Node in placed("cracked_wall.tscn"):
		if n.has_meta(&"secret"):
			continue
		var c: Vector2i = n.get_meta(&"cell")
		var sides: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN]
		if across:
			sides = [Vector2i.LEFT, Vector2i.RIGHT]
		for s: Vector2i in sides:
			var stand: Vector2i = c + s
			if info.world.is_valid(stand) and info.world.get_cell(stand).type == LevelGen.Type.EMPTY:
				out.append([c, stand])
				break
	return out


## The cracked walls laid in `w` (secret rooms' aside) with an empty cell beside them (`across`) or
## over or under them, as _walls finds them in play.
static func _laid_walls(w: LevelGen, across: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var sides: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN]
	if across:
		sides = [Vector2i.LEFT, Vector2i.RIGHT]
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			var c: Vector2i = Vector2i(x, y)
			var cell: LevelGen.Cell = w.get_cell(c)
			if cell.type != LevelGen.Type.CRACKED or cell.extra_info != null:
				continue
			if sides.any(func(s: Vector2i) -> bool: return w.is_valid(c + s) and w.get_cell(c + s).type == LevelGen.Type.EMPTY):
				out.append(c)
	return out


func _breaks() -> void:
	print("each spell breaks cracked rock its own way")
	# The lunge takes a wall along its row first; the rest any (from beside it, or from over it).
	var across: Array = _walls(true)
	var over: Array = _walls(false).filter(func(p: Array) -> bool: return not across.any(func(q: Array) -> bool: return q[0] == p[0]))
	check(not across.is_empty() and across.size() + over.size() >= 6, "cracked walls to break (%d beside, %d over or under)" % [across.size(), over.size()])
	player.set_physics_process(false)
	for spell: StringName in [&"lunge", &"hex", &"seeker", &"slash", &"nova", &"push"]:
		var walls: Array = across if not across.is_empty() else over
		if spell != &"lunge" and not over.is_empty():
			walls = over
		if walls.is_empty():
			break
		var pick: Array = walls.pop_front()
		var wall: Vector2i = pick[0]
		var stand: Vector2i = pick[1]
		var dir: Vector2 = Vector2(wall - stand)
		Abilities.set_tier(player, spell, 1)
		var node: Node = player.get_node(String(Abilities.ABILITIES[spell]["node"]))
		player.global_position = info.cell_position(stand) + Vector2(0, 16 - 31)
		if dir.x != 0.0:
			player.sprite.scale.x = absf(player.sprite.scale.x) * signf(dir.x)
		info.loader.wake_around(player.global_position)
		await frames(4)
		if spell in [&"hex", &"slash"]:
			_ready_spell(node)
			node.call(&"cast", dir, false)
			await frames(30)
			check(CrackedWall.at(self, wall) != null, "%s, plain, leaves it standing" % spell)
		_ready_spell(node)
		match spell:
			&"nova":
				node.call(&"cast", true)
			&"lunge":
				node.call(&"cast", dir.x, true)
			_:
				node.call(&"cast", dir, true)
		var broke: bool = await until(func() -> bool: return CrackedWall.at(self, wall) == null, 3000)
		check(broke and (info.record().broken as Dictionary).has(wall), "%s, empowered, breaks it (for good)" % spell)
	player.set_physics_process(true)


## Make the spell `node` ready to cast again.
func _ready_spell(node: Node) -> void:
	if node is Hex:
		(node as Hex).refill()
	else:
		node.set(&"wait", 0.0)


func _spires() -> void:
	print("spires")
	var spires: Array[Node] = placed("spire.tscn")
	var watch: int = info.world.towers.filter(func(t: Dictionary) -> bool: return not t["hoard"] and t.has("spire")).size()
	check(spires.size() == watch and watch >= 2, "a spire on each watchtower (%d)" % watch)
	if spires.size() < 2:
		return
	var a: Spire = spires[0] as Spire
	var b: Spire = spires[1] as Spire
	var rec: LevelRecord = info.record()
	info.world.towers[a.tower]["cold"] = false
	info.last_tower = -1
	var before: int = rec.stations
	a.hex_hit(1, Vector2.RIGHT)
	check(rec.stations == before, "a plain hit rings off it and does nothing")
	var mask: int = int((info.world.get_cell(info.world.towers[a.tower]["switch"]).extra_info as Dictionary)["mask"])
	var from: Vector2 = a.head() + Vector2(-150.0, 0.0)
	if info.solid_at(from):
		from = a.head() + Vector2(150.0, 0.0)
	player.set_physics_process(false)
	player.global_position = from
	info.loader.wake_around(from)
	await frames(4)
	var bolt: HexBolt = HexBolt.new()
	bolt.dir = (a.head() - from).normalized()
	bolt.empowered = true
	info.map_elements.add_child(bolt)
	bolt.global_position = from
	check(await until(func() -> bool: return rec.stations != before, 3000) and rec.stations == before ^ mask, "an empowered bolt on its spire flips its tower's switch")
	check(info.last_tower == a.tower, "locking it as a hand would")
	a.empowered_hit(Vector2.RIGHT)
	check(rec.stations == before ^ mask, "struck again at once, nothing changes")
	# A cold tower.
	info.world.towers[b.tower]["cold"] = true
	rec.woken.erase(b.tower)
	var lever: TowerSwitch = null
	for n: Node in placed("tower_switch.tscn", true):
		if (n as TowerSwitch).tower == b.tower:
			lever = n as TowerSwitch
	check(lever != null and lever.cold() and b.cold(), "a cold tower's switch and spire")
	if lever == null:
		return
	var now: int = rec.stations
	lever.use()
	check(rec.stations == now, "its switch balks")
	b.empowered_hit(Vector2.RIGHT)
	check(rec.woken.has(b.tower) and not lever.cold() and rec.stations == now, "an empowered strike on its spire wakes it, flipping nothing")
	lever.use()
	check(rec.stations == now ^ lever.mask, "and its switch works from then on")
	# An empowered seeker turns onto a spire.
	info.last_tower = -1
	var seen_before: int = rec.stations
	var seeker: HexBolt = HexBolt.new()
	seeker.dir = Vector2.UP
	seeker.empowered = true
	seeker.seek = Seeker.TURN_II
	seeker.speed = Seeker.SPEED
	seeker.range_px = Seeker.RANGE
	info.map_elements.add_child(seeker)
	seeker.global_position = from
	check(await until(func() -> bool: return rec.stations != seen_before, 4000), "an empowered seeker loosed upward turns onto the spire and flips it")
	player.set_physics_process(true)


func _ride() -> void:
	print("riding the gondola up")
	var all: Array[Node] = placed("gondola.tscn")
	check(all.size() == 1, "the level has a gondola")
	if all.is_empty():
		return
	var g: Gondola = all[0] as Gondola
	var n: int = g.stops.size()
	info.record().stations = (1 << n) - 1
	g.s = g.stops_s[n - 2]
	g.at_station = n - 2
	g.next_dir = 1
	g._hang()
	await frames(2)
	player.set_physics_process(true)
	player.global_position = g.center() + Vector2(0, 40)
	player.velocity = Vector2.ZERO
	check(await until(func() -> bool: return g.has_rider() and player.is_on_floor()), "the wizard steps into the car")
	var round_here: Array[Vector2i] = info.here.neighbours().filter(func(c: Vector2i) -> bool: return not Worlds.is_side(c))
	check(round_here.all(func(c: Vector2i) -> bool: return info.run.visited(c) == null or not info.run.visited(c).mapped), "the levels round are not inked yet")
	var seen_at: int = info.seen_count()
	g.pull()
	check(await until(func() -> bool: return not g.running, 40000) and g.at_station == n - 1, "it runs up to the top station")
	check(info.seen_count() > seen_at + 20, "riding up inks the map round the car (%d cells more)" % (info.seen_count() - seen_at))
	check(round_here.size() >= 3 and round_here.all(func(c: Vector2i) -> bool: return info.run.visited(c) != null and info.run.visited(c).mapped), "at the top, the %d levels round are inked whole" % round_here.size())
	# A lodestone in one of them shows on the worlds map.
	var map: Node = main.get_node("RisoMap")
	var with_stone: Array[Vector2i] = round_here.filter(func(c: Vector2i) -> bool: return Rules.lodestone_at(c) != &"")
	check(round_here.all(func(c: Vector2i) -> bool: return bool(map.call(&"_lodestone_known", info, c)) == (Rules.lodestone_at(c) != &"")), "the worlds map knows the lodestones among them (%d)" % with_stone.size())
	var far: Vector2i = _lodestone_level(NextWorldDef.band_row(&"crags", 2))
	check(not bool(map.call(&"_lodestone_known", info, far)), "a lodestone in a level not inked is not on the map")
	info.ink_place(far)
	check(bool(map.call(&"_lodestone_known", info, far)), "inked, it is")
