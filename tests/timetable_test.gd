extends TestKit
## The institute's timetable (Timetable, SchoolBell, ExamDoor, Lectern, GlyphSeal; docs/REGIONS_PLAN.md
## §9). Laid out: each hall with a class is in session in some periods (the exam hall only in the
## last, a lecture hall or the library in one or two before it, never all), a door in each of their
## doorways, a lectern and a bell in each lecture hall, a bell in the library, the corridor's bell
## with the timetable's board near the way in, glyph seals just inside the exam hall's and the
## library's doorways asking for a spell a lecture hall's master teaches there; the same every
## build; where the wizard belongs. In play: a level is first met in its first period, under way; scholars turn on a
## wizard they see truant, and those near them with them, not the whole level; a ring moves on a
## period, starts passing time and calms them all; in passing time the corridors are the wizard's; a
## spell cast or a blow where they see it turns them anywhere; hall doors stand open only while their
## class is in session, the exam's only in the last period; going into a class in session ends
## passing time and sets its trial, the master's spell lent; another spell or a plain blow glances off
## the mock seal; leaving mid-trial gives back what was put down; passed, a tier more of the spell,
## kept for the run with the one put down; set once; a lectern takes up any spell taught; the level's
## glyph seals open only to their own spell and stay open; and the spells themselves on seals (a
## slash, not on a hex seal; a hex bolt from far off, not near; a seeker's bolt turned round; a nova;
## a push).
## godot --headless --path . --script res://tests/timetable_test.gd

const WORLD: int = 28
## The institute's levels laid out here: rows into its band (NextWorldDef.band_row), by world.
const LAID: Array[Vector2i] = [Vector2i(28, 0), Vector2i(28, 2), Vector2i(7, 3), Vector2i(99, 4), Vector2i(41, 1)]


func run() -> void:
	MapInfo.debug = false
	_laid_out()
	await _play()
	RunState.delete_save()
	finish()


# ------------------------------------------------------------------ laid out

func _laid_out() -> void:
	print("laid out")
	var sessions_ok: bool = true
	var doors_ok: bool = true
	var furnished: bool = true
	var boards: int = 0
	var roomy: int = 0
	var seals_ok: bool = true
	var sealed: int = 0
	var same: bool = true
	var belongs_ok: bool = true
	for place: Vector2i in LAID:
		var at: Vector2i = Vector2i(place.x, NextWorldDef.band_row(&"institute", place.y))
		var w: LevelGen = build(at)
		check(w != null, "%s collapses" % at)
		if w == null:
			continue
		var again: LevelGen = build(at)
		if again == null or again.objects != w.objects:
			same = false
		var taught: Array[StringName] = Timetable.taught_in(w)
		for i: int in range(w.halls.size()):
			var hall: Dictionary = w.halls[i]
			var kind: StringName = hall["kind"]
			var inside: Rect2i = hall["inside"]
			var mask: int = Timetable.sessions(w, i)
			if kind == &"exam":
				sessions_ok = sessions_ok and mask == 1 << Timetable.EXAM_PERIOD
			elif kind in Timetable.TIMETABLED:
				sessions_ok = sessions_ok and mask > 0 and mask < (1 << Timetable.EXAM_PERIOD) - 1
			else:
				sessions_ok = sessions_ok and mask == 0
			if kind in Timetable.TIMETABLED:
				for d: Vector2i in hall["doors"]:
					if w.get_cell(d).type != LevelGen.Type.EXAM_DOOR or int(w.get_cell(d).extra_info) != i:
						doors_ok = false
			var lecterns: int = w.objects_of(LevelGen.Type.LECTERN).filter(func(v: Vector2i) -> bool: return inside.has_point(v)).size()
			var bells: int = w.objects_of(LevelGen.Type.SCHOOL_BELL).filter(func(v: Vector2i) -> bool: return inside.has_point(v)).size()
			match kind:
				&"lecture":
					furnished = furnished and lecterns == 1 and bells == 1
				&"library":
					furnished = furnished and bells == 1
			if kind in Timetable.SEALED and not taught.is_empty():
				var box: Rect2i = hall["box"]
				var want: StringName = Timetable.seal_of(w, i)
				seals_ok = seals_ok and want in taught
				for d: Vector2i in hall["doors"]:
					var c: Vector2i = d + Vector2i(1 if d.x == box.position.x else -1, 0)
					if w.get_cell(c).type == LevelGen.Type.GLYPH_SEAL and StringName(w.get_cell(c).extra_info) == want:
						sealed += 1
					else:
						seals_ok = false
			# Where the wizard belongs, by period and passing time.
			if kind == &"exam":
				for p: int in range(Timetable.PERIODS):
					belongs_ok = belongs_ok and not Timetable.belongs(w, p, true, inside.position)
			elif kind in Timetable.TIMETABLED:
				for p: int in range(Timetable.PERIODS):
					belongs_ok = belongs_ok and Timetable.belongs(w, p, false, inside.position) == Timetable.in_session(w, i, p)
		var out: Array[Vector2i] = w.objects_of(LevelGen.Type.SCHOOL_BELL).filter(func(v: Vector2i) -> bool: return Institute.hall_at(w, v) < 0)
		if out.size() == 1 and bool((w.get_cell(out[0]).extra_info as Dictionary)["board"]):
			boards += 1
			if SchoolBell.ceiling_over(w, out[0]) > Institute.BELL_ROOM:
				roomy += 1
		var corridor: Vector2i = w.free_floors()[0]
		belongs_ok = belongs_ok and Timetable.belongs(w, 0, true, corridor) and not Timetable.belongs(w, 0, false, corridor)
	check(sessions_ok, "the exam hall in session only in the last period, a lecture hall or the library in one or two before it, never all")
	check(doors_ok, "a door in every doorway of a hall with a class")
	check(furnished, "a lectern and a bell in each lecture hall, a bell in the library")
	check_eq(boards, LAID.size(), "one cord out in the corridors, under the great bell, with the timetable's board")
	check(roomy >= LAID.size() - 1, "where there is room over it for the great bell (%d of %d)" % [roomy, LAID.size()])
	check(seals_ok and sealed > 0, "glyph seals just inside the exam hall's and the library's doorways, asking for a spell taught there (%d)" % sealed)
	check(same, "laid out the same twice")
	check(belongs_ok, "the wizard belongs in the corridors in passing time and in a class in session, never in the exam hall")
	var plain: LevelGen = build(Vector2i(WORLD, NextWorldDef.band_row(&"cemetery", 1)))
	check(plain != null and not Timetable.kept_in(plain) and not Timetable.belongs(plain, 0, true, plain.free_floors()[0]), "no timetable out of the institute")


# ------------------------------------------------------------------ in play

func _play() -> void:
	await boot(WORLD)
	process_frame.connect(func() -> void: player.health.health = player.health.max_health)
	await _go(Vector2i(WORLD, NextWorldDef.first_depth(&"institute")))
	var rec: LevelRecord = info.record()
	check(rec.period == 0 and not rec.passing, "first met in its first period, under way")
	var bells: Array[Node] = placed("school_bell.tscn").filter(func(n: Node) -> bool: return (n as SchoolBell).board)
	check(bells.size() == 1, "the corridor's bell is there")
	if bells.is_empty():
		return
	var bell: SchoolBell = bells[0] as SchoolBell
	await _belonging(rec, bell)
	await _doors(rec, bell)
	await _trial(rec, bell)
	await _level_seal()
	await _spells()


## Belonging: seen truant, scholars turn, with those near them; a ring calms them; passing time; a
## cast and a blow where they see it.
func _belonging(rec: LevelRecord, bell: SchoolBell) -> void:
	print("where the wizard belongs")
	# A stretch of floor for the wizard and a scholar, with another floor near the scholar hidden from
	# the wizard by rock.
	var floor_at: Vector2i = Vector2i(-1, -1)
	var hidden: Vector2i = Vector2i(-1, -1)
	for v: Vector2i in _stretches(3, 1):
		hidden = _hidden_near(info.cell_position(v + Vector2i(2, 0)), info.cell_position(v))
		if hidden.x >= 0:
			floor_at = v
			break
	check(hidden.x >= 0, "a floor near a scholar, out of the wizard's sight")
	if hidden.x < 0:
		return
	player.global_position = info.cell_position(floor_at)
	var near: Scholar = _spawn("student.tscn", floor_at + Vector2i(2, 0))
	var by: Scholar = _spawn("student.tscn", hidden)
	check(await within(func() -> bool: return near.roused, 1.0), "seen truant in the corridors in a period, a scholar turns on the wizard")
	check(by.roused and not by.sees(player), "and those near it with it, out of the wizard's sight")
	var calm: int = 0
	for n: Node in get_nodes_in_group(&"scholar"):
		if (n as Node2D).global_position.distance_to(player.global_position) > 2500.0 and not (n as Scholar).roused:
			calm += 1
	check(calm > 0, "not the whole level: %d far off stay calm" % calm)
	await _ring(bell)
	check(rec.period == 1 and rec.passing, "a ring: the next period, and passing time")
	check(info.since_bell < MapInfo.BELL_TIME, "the great bell rings out")
	for n: Node in placed("school_bell.tscn"):
		var cord: SchoolBell = n as SchoolBell
		if cord.reach != SchoolBell.ceiling_over(info.world, cord.get_meta(&"cell")) or cord.reach < 2:
			check(false, "a cord at %s reaches its ceiling" % cord.get_meta(&"cell"))
	(placed("school_bell.tscn").filter(func(n: Node) -> bool: return not (n as SchoolBell).board)[0] as SchoolBell).ring()
	check(rec.period == 1, "another cord pulled at once rings it no more")
	check(not near.roused and not by.roused, "and every scholar calms down")
	await within(func() -> bool: return false, 0.6)
	check(near.sees(player) and not near.roused and not near.hostile(), "in passing time the corridors are the wizard's: one that sees them leaves them be")
	check(Abilities.cast(player), "the wizard casts a spell")
	check(near.roused, "where it sees: it turns on them anyway")
	await _ring(bell)
	check(not near.roused, "rung again, calm")
	SpellStrike.strike(by, Vector2.RIGHT, 0)
	check(by.roused, "struck, it turns")
	near.queue_free()
	by.queue_free()
	await _ring(bell)


## Hall doors follow the timetable: open while in session; the exam's only in the last period. Each
## is looked at with the wizard outside it (far off, a door sleeps with its chunk, and settles as
## the wizard comes near).
func _doors(rec: LevelRecord, bell: SchoolBell) -> void:
	print("hall doors")
	var ok: bool = true
	var exam_ok: bool = true
	var doors: Dictionary = {}
	for n: Node in placed("exam_door.tscn"):
		doors[(n as ExamDoor).cell] = n
	for k: int in range(Timetable.PERIODS):
		for i: int in range(info.world.halls.size()):
			var hall: Dictionary = info.world.halls[i]
			if not hall["kind"] in Timetable.TIMETABLED:
				continue
			var open: bool = Timetable.in_session(info.world, i, rec.period)
			if hall["kind"] == &"exam" and open != (rec.period == Timetable.EXAM_PERIOD):
				exam_ok = false
			for j: int in range((hall["doors"] as Array).size()):
				var door: ExamDoor = doors.get(hall["doors"][j]) as ExamDoor
				if door == null:
					ok = false
					continue
				player.global_position = info.cell_position(hall["steps"][j])
				if not await within(func() -> bool: return door.shut() != open, 1.5):
					ok = false
		await _ring(bell)
	check(ok, "every hall's doors stand open while its class is in session, shut while it is not")
	check(exam_ok, "the exam's only in the last period")


## Going into a class ends passing time and sets its trial; leaving gives back the lent spell;
## passing gives a tier, kept; a lectern takes up any spell taught.
func _trial(rec: LevelRecord, bell: SchoolBell) -> void:
	print("a trial")
	var hall: int = -1
	for i: int in range(info.world.halls.size()):
		if info.world.halls[i]["kind"] == &"lecture" and info.master_in(i) != null:
			hall = i
			break
	check(hall >= 0, "a lecture hall with its master")
	if hall < 0:
		return
	var master: Scholar = info.master_in(hall)
	var a: StringName = master.ability
	# The wizard holds another spell, so the master's is lent.
	var other: StringName = Institute.MASTERIES[posmod(Institute.MASTERIES.find(a) + 1, Institute.MASTERIES.size())]
	Abilities.set_tier(player, other, 2)
	var rings: int = 0
	while not Timetable.in_session(info.world, hall, rec.period) and rings < Timetable.PERIODS:
		await _ring(bell)
		rings += 1
	check(rec.passing and Timetable.in_session(info.world, hall, rec.period), "rung to a period its class is in session, in passing time")
	var inside: Rect2i = info.world.halls[hall]["inside"]
	var rise: int = info.world.halls[hall]["rise"]
	var wall: int = inside.position.x if rise > 0 else inside.end.x - 1
	var spot: Vector2i = Vector2i(wall + rise * 5, inside.end.y - 1)
	player.global_position = info.cell_position(spot)
	check(await within(func() -> bool: return not rec.passing, 0.5), "going into a class in session ends passing time")
	check(await within(func() -> bool: return info.trial_hall == hall, 0.5), "its master sets a trial")
	check(Abilities.spell(player) == a and Abilities.tier(player, a) >= 1, "its spell, %s, lent to the wizard" % a)
	check_eq(info.trial_seals.size(), 1, "a mock seal of it at the lectern's wall")
	await within(func() -> bool: return false, 0.6)
	check(not master.roused, "the class leaves the wizard be")
	print("leaving mid-trial")
	player.global_position = bell.global_position
	check(await within(func() -> bool: return info.trial_hall < 0, 0.5), "leaving the hall leaves it unfinished")
	check(Abilities.spell(player) == other and Abilities.tier(player, other) == 2 and Abilities.tier(player, a) == 0, "what was put down given back, the lent spell taken away")
	# Out in the corridors in a period the wizard was truant: whoever saw them is calmed here, as by a
	# bell, without moving the period on.
	for n: Node in get_nodes_in_group(&"scholar"):
		(n as Scholar).calm()
	player.global_position = info.cell_position(spot)
	check(await within(func() -> bool: return info.trial_hall == hall, 0.5), "back in: the trial set again")
	var seal: GlyphSeal = info.trial_seals[0]
	seal.struck(&"", seal.global_position, 0.0)
	seal.struck(other, seal.global_position, 0.0)
	check(not seal.broken() and info.trial_hall == hall, "a plain blow or another spell glances off its seal")
	seal.struck(a, _from_far(seal), GlyphSeal.SEEKER_BEND + 0.1)
	check(info.trial_hall < 0 and rec.trials.has(hall), "its spell, used for what it does: the trial is passed")
	check(Abilities.spell(player) == a and Abilities.tier(player, a) == 1, "a tier of %s learned" % a)
	check(int(info.run.taught.get(a, 0)) == 1 and int(info.run.taught.get(other, 0)) == 2, "kept for the run, and the %s put down still known" % other)
	await frames(3)
	check(info.trial_hall < 0, "passed once, it sets it no more")
	print("a lectern")
	var lecterns: Array[Node] = placed("lectern.tscn").filter(func(n: Node) -> bool: return (n as Lectern).hall == hall)
	check(lecterns.size() == 1, "its lectern")
	if lecterns.is_empty():
		return
	var lectern: Lectern = lecterns[0] as Lectern
	check(lectern.holds() == [other, 2], "it gives back the %s, at its tier" % other)
	lectern.take()
	check(Abilities.spell(player) == other and Abilities.tier(player, other) == 2, "taken up, in the slot")
	check(lectern.holds() == [a, 1], "and the %s waits there in turn" % a)
	lectern.take()
	check(Abilities.spell(player) == a, "learning is permanent")
	player.global_position = bell.global_position
	await frames(2)


## A glyph seal of the level's own: another spell glances; its own, used literally, breaks it, for
## good.
func _level_seal() -> void:
	print("the level's glyph seals")
	var seals: Array[Node] = placed("glyph_seal.tscn").filter(func(n: Node) -> bool: return not (n as GlyphSeal).mock and not (n as GlyphSeal).broken())
	check(not seals.is_empty(), "the level's glyph seals are there")
	if seals.is_empty():
		return
	var own: GlyphSeal = seals[0] as GlyphSeal
	var cell: Vector2i = own.get_meta(&"cell")
	check(info.solid_at(own.global_position), "barring the way")
	var wrong: StringName = Institute.MASTERIES[posmod(Institute.MASTERIES.find(own.spell) + 1, Institute.MASTERIES.size())]
	own.struck(wrong, _from_far(own), GlyphSeal.SEEKER_BEND + 0.1)
	check(not own.broken(), "another spell glances off")
	own.struck(own.spell, _from_far(own), GlyphSeal.SEEKER_BEND + 0.1)
	check(own.broken() and info.record().opened.has(cell) and not info.solid_at(own.global_position), "its own, used literally, breaks it")
	await _go(info.coord)
	check(placed("glyph_seal.tscn").all(func(n: Node) -> bool: return n.get_meta(&"cell") != cell), "and it stays open")


## The spells themselves on seals: only its own spell opens a seal, used literally: a slash; a hex
## bolt from far off, not from near; a seeker's bolt cast away and turning round to it; a nova; a push.
func _spells() -> void:
	print("glyph seals and the spells")
	var floor_at: Vector2i = _open_floor(5, 1)
	Abilities.set_tier(player, &"slash", 1)
	var seal: GlyphSeal = _seal(&"hex", floor_at + Vector2i(1, 0))
	# Up against it, as near as its slab lets the wizard stand.
	player.global_position = seal.global_position - Vector2(90.0, 0)
	await frames(2)
	(player.get_node("Slash") as Slash).cast(Vector2.RIGHT)
	check(not seal.broken(), "a hex seal: slashed, the blow glances off")
	seal.queue_free()
	seal = _seal(&"slash", floor_at + Vector2i(1, 0))
	await frames(2)
	(player.get_node("Slash") as Slash).wait = 0.0
	(player.get_node("Slash") as Slash).cast(Vector2.RIGHT)
	check(seal.broken(), "a slash seal: slashed, it breaks")
	# A hex bolt: from near it glances off; from far off it breaks.
	Abilities.set_tier(player, &"hex", 1)
	seal = _seal(&"hex", floor_at + Vector2i(4, 0))
	player.global_position = info.cell_position(floor_at + Vector2i(2, 0))
	await frames(2)
	var hex: Hex = player.get_node("Hex") as Hex
	hex.refill()
	var bolt: Node2D = hex.cast(Vector2.RIGHT)
	await until(gone(bolt))
	check(is_instance_valid(seal) and not seal.broken(), "a hex seal: a bolt from near glances off")
	player.global_position = info.cell_position(floor_at)
	await frames(2)
	hex.refill()
	bolt = hex.cast(Vector2.RIGHT)
	await until(gone(bolt))
	check(not is_instance_valid(seal) or seal.broken(), "from far off, it breaks")
	# A seeker's bolt cast up, away from it, turns round to it (with room over the floor to turn in).
	Abilities.set_tier(player, &"seeker", 1)
	var high: Vector2i = _open_floor(4, 2)
	player.global_position = info.cell_position(high)
	seal = _seal(&"seeker", high + Vector2i(3, 0))
	await frames(2)
	# Nothing else near for it to turn to.
	for n: Node in get_nodes_in_group(&"hex_target"):
		if n != seal and (n as Node2D).global_position.distance_to(player.global_position) < HexBolt.SEEK * 2.0:
			n.queue_free()
	await frames(2)
	var bolts: Array[HexBolt] = (player.get_node("Seeker") as Seeker).cast(Vector2.UP)
	check(not bolts.is_empty() and await until(gone(bolts[0])), "a seeker's bolt cast up, away from it")
	check(not is_instance_valid(seal) or seal.broken(), "turns round to it, and it breaks")
	player.global_position = info.cell_position(floor_at)
	# A nova all round, and a push.
	for spell: StringName in [&"nova", &"push"]:
		Abilities.set_tier(player, spell, 1)
		seal = _seal(spell, floor_at + Vector2i(1, 0))
		player.global_position = seal.global_position - Vector2(90.0, 0)
		await frames(2)
		var node: Node = player.get_node(String(Abilities.ABILITIES[spell]["node"]))
		if node is Nova:
			(node as Nova).cast()
		else:
			(node as Push).cast(Vector2.RIGHT)
		check(seal.broken(), "a %s seal: struck by a %s, it breaks" % [spell, spell])


# ------------------------------------------------------------------ helpers

## Ring `bell`, as soon as it can be rung again.
func _ring(bell: SchoolBell) -> void:
	info.since_bell = SchoolBell.RING_GAP
	bell.ring()
	await frames(2)


## A point far enough off from `seal` for a hex bolt cast there (GlyphSeal.HEX_FAR).
func _from_far(seal: GlyphSeal) -> Vector2:
	return seal.global_position + Vector2(GlyphSeal.HEX_FAR + 20.0, 0)


## A glyph seal asking for `spell` at `v`, as one laid with the level.
func _seal(spell: StringName, v: Vector2i) -> GlyphSeal:
	var seal: GlyphSeal = (load("res://prefabs/glyph_seal.tscn") as PackedScene).instantiate() as GlyphSeal
	seal.setup(info, v, spell)
	info.map_elements.add_child(seal)
	seal.global_position = info.cell_position(v)
	return seal


func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)


## The first stretch of open floor `length` cells long with `head` rows of headroom (see _stretches):
## its left cell.
func _open_floor(length: int, head: int) -> Vector2i:
	var all: Array[Vector2i] = _stretches(length, head)
	check(not all.is_empty(), "an open stretch of floor %d long to test on" % length)
	return all[0] if not all.is_empty() else info.world.free_floors()[0]


## Every stretch of floor `length` cells long with `head` rows of headroom, out of the halls, with
## nothing solid and no foe laid on it: their left cells, in order.
func _stretches(length: int, head: int) -> Array[Vector2i]:
	var w: LevelGen = info.world
	var out: Array[Vector2i] = []
	for y: int in range(w.size.y):
		for x: int in range(w.size.x):
			var ok: bool = true
			for k: int in range(length):
				var c: Vector2i = Vector2i(x + k, y)
				ok = ok and not _blocks(w, c) and not Placeables.has_flag(w.get_cell(c).type, &"enemy") and w.is_ground(c + Vector2i.DOWN) and Institute.hall_at(w, c) < 0
				for u: int in range(1, head + 1):
					ok = ok and not _blocks(w, c + Vector2i.UP * u)
				if not ok:
					break
			if ok:
				out.append(Vector2i(x, y))
	return out


## Whether cell `c` of `w` holds something solid (rock, a ledge, a door or gate, a seal), or is out
## of the level.
func _blocks(w: LevelGen, c: Vector2i) -> bool:
	return not w.is_valid(c) or w.get_cell(c).type in [LevelGen.Type.GROUND, LevelGen.Type.PLATFORM, LevelGen.Type.MOVING_PLATFORM, LevelGen.Type.DOOR,
		LevelGen.Type.SWITCH_GATE, LevelGen.Type.CRACKED, LevelGen.Type.SPIKES, LevelGen.Type.LIGHT_GATE, LevelGen.Type.EXAM_DOOR, LevelGen.Type.TRAPDOOR,
		LevelGen.Type.GLYPH_SEAL]


## A free floor within reach of a scholar at `at` turning (Scholar.ROUSE_REACH), out of the halls,
## where rock hides it from a wizard at `wizard`, or (-1, -1).
func _hidden_near(at: Vector2, wizard: Vector2) -> Vector2i:
	for v: Vector2i in info.world.free_floors():
		var p: Vector2 = info.cell_position(v)
		if p.distance_to(at) <= Scholar.ROUSE_REACH * 0.9 and Institute.hall_at(info.world, v) < 0 and not SpellStrike.clear(p + Vector2(0, -Scholar.EYE), wizard):
			return v
	return Vector2i(-1, -1)


func _spawn(scene: String, v: Vector2i) -> Scholar:
	var node: Scholar = (load("res://prefabs/" + scene) as PackedScene).instantiate() as Scholar
	LevelLoader.arm(node, info.here.depth)
	info.map_elements.add_child(node)
	node.global_position = info.cell_position(v)
	node.setup(info, v, {"ability": &"", "hall": -1})
	return node
