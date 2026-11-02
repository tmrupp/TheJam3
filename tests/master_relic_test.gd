extends TestKit
## Relics in the institute won from masters (Relics; docs/DEEPER_PLAN.md §4e): an institute level
## holding a relic (Relics.at) has it carried by the master out in the level furthest from the way in
## (Institute.populate, LevelGen.relic_carrier), not laid in a secret room, a bone vault or the open,
## and the same every build. In play the carrier wears it; beaten by the wizard it leaves the relic
## where it fell, free, kept in the level's record until taken (MapInfo.relic_left); taken, it is the
## level's relic found, and the master carries it no more. An instructor teaching a big move the
## wizard has not found (levitate, astral) leaves that move's relic instead of a paper, which is not
## the level's relic.
## godot --headless --path . --script res://tests/master_relic_test.gd

## How many institute levels holding a relic the layout checks look at.
const LAID: int = 4


func run() -> void:
	if not needs([&"institute"]):
		finish()
		return
	MapInfo.debug = false
	var levels: Array[Vector2i] = _relic_levels()
	check(levels.size() >= 2, "institute levels holding a relic (%d)" % levels.size())
	if levels.size() < 2:
		finish()
		return
	_laid_out(levels)
	await _play(levels[0])
	RunState.delete_save()
	finish()


## Institute levels holding a relic, from the first rows of the band in the first worlds.
func _relic_levels() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for world: int in range(1, 400):
		for k: int in range(4):
			var at: Vector2i = Vector2i(world, NextWorldDef.band_row(&"institute", k))
			if Relics.at(at) != &"" and Bosses.gate_at(at.y) == &"":
				out.append(at)
				if out.size() >= LAID:
					return out
	return out


func _laid_out(levels: Array[Vector2i]) -> void:
	print("laid out")
	var carried: int = 0
	var furthest: bool = true
	var in_no_room: bool = true
	var same: bool = true
	for at: Vector2i in levels:
		var w: LevelGen = build(at)
		if w == null:
			continue
		var move: StringName = Relics.at(at)
		var c: Vector2i = w.relic_carrier
		if w.is_valid(c) and w.get_cell(c).type == LevelGen.Type.MASTER and StringName((w.get_cell(c).extra_info as Dictionary).get("relic", &"")) == move:
			carried += 1
		var start: Vector2i = w.exits[MapInfo.Exit.BACK]
		for v: Vector2i in w.objects_of(LevelGen.Type.MASTER):
			if int((w.get_cell(v).extra_info as Dictionary).get("hall", -1)) < 0 and LevelGen.dist(v, start) > LevelGen.dist(c, start):
				furthest = false
		if not w.objects_of(LevelGen.Type.RELIC).is_empty():
			in_no_room = false
		for secret: Dictionary in w.secrets:
			if (secret["rewards"] as Array).any(func(r: Array) -> bool: return r[1] == LevelGen.Type.RELIC):
				in_no_room = false
		var again: LevelGen = build(at)
		same = same and again != null and again.objects == w.objects and again.relic_carrier == c
	check_eq(carried, levels.size(), "in each, a master out in the level carries the level's relic")
	check(furthest, "the one furthest from the way in")
	check(in_no_room, "and no relic lies in a secret room, a bone vault or the open")
	check(same, "the same every build")


func _play(at: Vector2i) -> void:
	print("in play")
	await boot(at.x)
	process_frame.connect(func() -> void: player.health.health = player.health.max_health)
	await _go(at)
	var move: StringName = Relics.at(at)
	var carrier: Scholar = null
	for n: Node in get_nodes_in_group(&"scholar"):
		var s: Scholar = n as Scholar
		if s != null and s.relic != &"":
			carrier = s
	check(carrier != null and carrier.relic == move and carrier.cell == info.world.relic_carrier, "the carrier stands there, wearing the %s relic" % move)
	if carrier == null:
		return
	var tier: int = Abilities.tier(player, move)
	var pos: Vector2 = carrier.global_position
	carrier.wizard_blow = true
	(carrier.get_node("Wound") as Wound).hit(999, Vector2.UP)
	await frames(4)
	var left: Array[Node] = placed("relic.tscn").filter(func(n: Node) -> bool: return n.has_meta(&"left"))
	check(left.size() == 1 and (left[0] as Node2D).global_position.distance_to(pos) < 200.0 and placed("lesson.tscn").is_empty(), "beaten, it leaves the relic where it fell, no lesson")
	check(info.record().relics_left.size() == 1 and not info.relic_carried(), "kept in the level's record")
	if left.is_empty():
		return
	var relic: Relic = left[0] as Relic
	check_eq(relic.price(), 0, "free: the fight was its price")
	relic.take()
	await frames(2)
	check_eq(Abilities.tier(player, move), tier + 1, "taken, the wizard has %s a tier on" % move)
	check(info.run.relics_found.has(at) and info.record().relics_left.is_empty(), "the level's relic found")
	# Back again: the master carries it no more.
	await _go(Vector2i(at.x, at.y - 1))
	await _go(at)
	check(get_nodes_in_group(&"scholar").all(func(n: Node) -> bool: return (n as Scholar).relic == &"") and placed("relic.tscn").is_empty(), "back again, no master carries it, nor does it lie there")
	await _instructor(at)


## An instructor teaching a big move the wizard has not found leaves its relic, not a paper.
func _instructor(at: Vector2i) -> void:
	print("an instructor's relic")
	var bells: Array[Node] = placed("school_bell.tscn").filter(func(n: Node) -> bool: return (n as SchoolBell).great)
	if bells.is_empty():
		return
	var bell: SchoolBell = bells[0] as SchoolBell
	var hall: int = -1
	for k: int in range(Timetable.PERIODS * 4):
		for i: int in range(info.world.halls.size()):
			var a: StringName = info.subject_of(i)
			if a in Relics.MOVES and info.master_in(i) != null and Abilities.tier(player, a) == 0:
				hall = i
		if hall >= 0:
			break
		info.record().passing = false
		info.since_bell = SchoolBell.RING_GAP
		bell.ring()
		await frames(2)
	if hall < 0:
		print("  (no class of a move the wizard lacks met here)")
		return
	var move: StringName = info.subject_of(hall)
	player.keyring.clear()
	check(not info.teaches(move), "%s, not found, is not taught" % move)
	var found: Dictionary = info.run.relics_found.duplicate()
	var m: Scholar = info.master_in(hall)
	m.wizard_blow = true
	(m.get_node("Wound") as Wound).hit(999, Vector2.UP)
	await frames(4)
	var left: Array[Node] = placed("relic.tscn").filter(func(n: Node) -> bool: return n.has_meta(&"left"))
	var papers: Array[Node] = placed("key.tscn").filter(func(n: Node) -> bool: return KeyRing.is_paper((n as KeyPickup).key_color()))
	check(left.size() == 1 and (left[0] as Relic).holds()[0] == move and papers.is_empty(), "felled by the wizard, the %s instructor leaves its relic, no paper" % move)
	if left.is_empty():
		return
	(left[0] as Relic).take()
	await frames(2)
	check(Abilities.tier(player, move) == 1 and info.run.relics_found == found, "taken: %s at I, and not the level's relic" % move)


func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
