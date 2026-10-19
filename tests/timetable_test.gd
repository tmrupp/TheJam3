extends TestKit
## The institute's timetable (Timetable, SchoolBell, ExamDoor, Lectern, GlyphSeal;
## docs/REGIONS_PLAN.md §9). Its rules: each department's ladder and cycle (blocks of a class, the
## next rung and a break, every third class empty), the tier taught rising with every ring, the beast
## fed by rings (more blows, quicker strikes, more souls). Laid out: each classroom steps through its
## department's cycle, one a ring, wrapping round, rooms starting at different stages; the library
## always open; a door in each doorway of a hall with a class, a lectern and a cord in each classroom,
## a cord in the library, the great bell's cord near the way in with room over it; glyph seals just
## inside the library's doorways asking for a damage spell taught there; the same every build; where
## the wizard belongs. In play: a level first met before any ring, in a period; scholars turn on a
## wizard they see truant, and those near them with them, not the whole level; a ring moves on a
## period, starts passing time, feeds the beast and calms them all; in passing time the corridors are
## the wizard's; a cast or a blow where they see it turns them; the bell rings once a period (not
## again in passing time, until the wizard goes into a class); hall doors stand open only while in
## session; every ring seats each class afresh, a master teaching its hall's subject, a hall with no
## class empty and trespassed in; an instructor far stronger than a master out in the level, its whole
## class turning with it; felled by an abomination it leaves nothing, felled by the wizard a paper of
## its subject at the top tier, once a room, stolen; going into a class starts it (passing time ends,
## its doors shut behind the wizard), staying in one as the bell rings starts nothing; the bell rung
## out in a class sends its exam paper (the subject at the tier taught) to the level its department's
## portal leads to, but not from a class whose master has turned on the wizard, nor from the
## corridors; a big move taught only to a wizard who has it, its class counted as attended all the
## same; sneaking into an empty hall, its lectern holds the next class's paper, lifted onto the ring
## once a period, stolen; a lectern as a pigeonhole; prerequisites (a wizard got in without them put
## back out) and resitting; the way on in the classroom furthest in, asking for another department's
## paper besides; the great bell in the corridors the way in opens on; abominations still during a class and acting up in passing time, the
## more for every ring; proctors walking the corridors in a period; the level's glyph seals opening
## only to their own spell; and the spells themselves on seals (a slash, not on a hex seal; a hex
## bolt; a seeker's bolt turned round; a nova; a push).
## godot --headless --path . --script res://tests/timetable_test.gd

const WORLD: int = 28
## The institute's levels laid out here: rows into its band (NextWorldDef.band_row), by world.
const LAID: Array[Vector2i] = [Vector2i(28, 0), Vector2i(28, 2), Vector2i(7, 3), Vector2i(99, 4), Vector2i(41, 1)]


func run() -> void:
	MapInfo.debug = false
	_rules()
	_laid_out()
	await _play()
	RunState.delete_save()
	finish()


# ------------------------------------------------------------------ rules

func _rules() -> void:
	print("rules")
	var taught: Dictionary = {}
	for dept: StringName in Institute.DEPARTMENTS:
		for a: StringName in Timetable.LADDERS[dept]:
			taught[a] = true
	check(Institute.MASTERIES.all(func(a: StringName) -> bool: return taught.has(a)), "every damage spell is taught somewhere")
	check([&"warp", &"rift", &"levitate", &"ferry", &"astral"].all(func(a: StringName) -> bool: return taught.has(a)), "and the moves cast from the movement slot")
	# Needs: round in a ring, one tier lower, nothing for tier I.
	check_eq([Timetable.needs(&"astronomy", 3), Timetable.needs(&"geology", 2), Timetable.needs(&"botany", 4), Timetable.needs(&"necrology", 2), Timetable.needs(&"astronomy", 1)],
		[[&"geology", 2], [&"botany", 1], [&"necrology", 3], [&"astronomy", 1], [&"", 0]], "a class asks for the next department round the ring, a tier lower; tier I asks for nothing")
	check_eq([Timetable.tier_taught(&"hex", 3), Timetable.tier_taught(&"warp", 4), Timetable.tier_taught(&"slash", 0)], [3, 3, 1], "a class teaches its department's tier, up to the spell's own top")
	var fed: RunState = RunState.new()
	fed.start(28)
	check(Beast.core_hp(fed) == Beast.CORE_HP and BeastSouls.count(fed) == BeastSouls.SOULS and Beast.attack_every(fed) > Beast.ATTACK_EVERY, "an unfed beast is weak: %d blows, %d soul, slow strikes" % [Beast.CORE_HP, BeastSouls.SOULS])
	fed.fed = 12
	check(Beast.core_hp(fed) == Beast.CORE_HP + 6 and BeastSouls.count(fed) == BeastSouls.SOULS + 4 and Beast.attack_every(fed) < Beast.ATTACK_EVERY * Beast.SLOWEST, "fed by 12 rings: 6 blows more, 4 souls more, quicker strikes")
	fed.fed = 999
	check(Beast.core_hp(fed) == Beast.CORE_HP + Beast.FED_BLOWS_MOST and BeastSouls.count(fed) == BeastSouls.SOULS + BeastSouls.FED_SOULS_MOST and Beast.attack_every(fed) >= Beast.ATTACK_EVERY * Beast.FASTEST - 0.001, "and no more than so much")


# ------------------------------------------------------------------ laid out

func _laid_out() -> void:
	print("laid out")
	var turns_ok: bool = true
	var all_depts: bool = true
	var rhythms_ok: bool = true
	var sessions_ok: bool = true
	var doors_ok: bool = true
	var furnished: bool = true
	var greats: int = 0
	var roomy: int = 0
	var seals_ok: bool = true
	var sealed: int = 0
	var same: bool = true
	var belongs_ok: bool = true
	var way_on_ok: bool = true
	var bell_near: int = 0
	var cycles_ok: bool = true
	var phases: Dictionary = {}
	var apart_ok: bool = true
	for place: Vector2i in LAID:
		var at: Vector2i = Vector2i(place.x, NextWorldDef.band_row(&"institute", place.y))
		var w: LevelGen = build(at)
		check(w != null, "%s collapses" % at)
		if w == null:
			continue
		var again: LevelGen = build(at)
		if again == null or again.objects != w.objects:
			same = false
		var depts: Dictionary = {}
		for hall: Dictionary in w.halls:
			if hall["kind"] == &"lecture":
				depts[hall["dept"]] = true
		var rooms: int = w.halls.filter(func(h: Dictionary) -> bool: return h["kind"] == &"lecture").size()
		all_depts = all_depts and depts.size() == mini(rooms, Institute.DEPARTMENTS.size())
		var damage: Array[StringName] = Timetable.subjects_in(w).filter(func(a: StringName) -> bool: return a in Institute.MASTERIES)
		for i: int in range(w.halls.size()):
			var hall: Dictionary = w.halls[i]
			var kind: StringName = hall["kind"]
			var inside: Rect2i = hall["inside"]
			match kind:
				&"lecture":
					# A class while its department meets, none while it does not; its subjects one a
					# session (geology's two), all three over a few days, the same again a whole round on.
					var dept: StringName = hall["dept"]
					var seen: Dictionary = {}
					var span: int = Timetable.PERIODS * 3 * int(Timetable.HOLDS[dept])
					for r: int in range(span):
						var a: StringName = Timetable.subject(w, i, r)
						rhythms_ok = rhythms_ok and (a != &"") == Timetable.in_cycle(w, i, r) and Timetable.subject(w, i, r + span) == a
						if a != &"":
							turns_ok = turns_ok and (Timetable.LADDERS[dept] as Array).has(a)
							seen[a] = true
					turns_ok = turns_ok and seen.size() == 3
					var open: Array = range(Timetable.PERIODS).filter(func(r: int) -> bool: return Timetable.in_cycle(w, i, r))
					cycles_ok = cycles_ok and open.size() == Timetable.IN_SESSION and Timetable.meets(w, dept, open[0])
					phases[Timetable.phase(w, i)] = true
					if dept == &"geology":
						var firsts: Array = [0, 1, 2, 3, 4, 5].filter(func(r: int) -> bool: return Timetable.in_cycle(w, i, r))
						turns_ok = turns_ok and Timetable.subject(w, i, firsts[0]) == Timetable.subject(w, i, firsts[1])
				&"library":
					for r: int in range(Timetable.PERIODS):
						sessions_ok = sessions_ok and Timetable.in_session(w, i, r) and not Timetable.holds_class(w, i, r)
			if kind in Timetable.TIMETABLED:
				for d: Vector2i in hall["doors"]:
					if w.get_cell(d).type != LevelGen.Type.EXAM_DOOR or int(w.get_cell(d).extra_info) != i:
						doors_ok = false
			var lecterns: int = w.objects_of(LevelGen.Type.LECTERN).filter(func(v: Vector2i) -> bool: return inside.has_point(v)).size()
			var cords: int = w.objects_of(LevelGen.Type.SCHOOL_BELL).filter(func(v: Vector2i) -> bool: return inside.has_point(v)).size()
			match kind:
				&"lecture":
					furnished = furnished and lecterns == 1 and cords == 1
				&"library":
					furnished = furnished and cords == 1 and lecterns == 0
			if kind in Timetable.SEALED and not damage.is_empty():
				var box: Rect2i = hall["box"]
				var want: StringName = Timetable.seal_of(w, i)
				seals_ok = seals_ok and want in damage
				for d: Vector2i in hall["doors"]:
					var c: Vector2i = d + Vector2i(1 if d.x == box.position.x else -1, 0)
					if w.get_cell(c).type == LevelGen.Type.GLYPH_SEAL and StringName(w.get_cell(c).extra_info) == want:
						sealed += 1
					else:
						seals_ok = false
			# Where the wizard belongs, by period and passing time.
			for r: int in range(Timetable.PERIODS):
				match kind:
					&"lecture":
						belongs_ok = belongs_ok and Timetable.belongs(w, r, false, inside.position) == (Timetable.subject(w, i, r) != &"")
					&"library":
						belongs_ok = belongs_ok and Timetable.belongs(w, r, false, inside.position)
		var out: Array[Vector2i] = w.objects_of(LevelGen.Type.SCHOOL_BELL).filter(func(v: Vector2i) -> bool: return Institute.hall_at(w, v) < 0)
		if out.size() >= Institute.CORRIDOR_BELLS_LEAST and out.all(func(v: Vector2i) -> bool: return bool((w.get_cell(v).extra_info as Dictionary)["great"])):
			greats += 1
			if out.all(func(v: Vector2i) -> bool: return SchoolBell.ceiling_over(w, v) > Institute.BELL_ROOM):
				roomy += 1
		for b: Vector2i in out:
			for o: Vector2i in out:
				apart_ok = apart_ok and (b == o or LevelGen.dist(b, o) >= Institute.BELL_APART)
		var corridor: Vector2i = w.free_floors()[0]
		belongs_ok = belongs_ok and Timetable.belongs(w, 0, true, corridor) and not Timetable.belongs(w, 0, false, corridor)
		# The way on on the floor of a classroom, the one most classrooms in from the way in.
		var start: Vector2i = w.exits[MapInfo.Exit.BACK]
		var region: Dictionary = Institute.regions(w)
		var way: int = Timetable.way_on_hall(w)
		var deeper: Vector2i = w.exits[MapInfo.Exit.DEEPER]
		way_on_ok = way_on_ok and way >= 0 and (w.halls[way]["floors"] as Array).has(deeper) and w.get_cell(deeper).type == LevelGen.Type.EXIT
		var rooms_in: Dictionary = Institute.rooms_in(w, start)
		way_on_ok = way_on_ok and way >= 0 and rooms_in.has(way) and rooms_in.values().all(func(n: int) -> bool: return n <= int(rooms_in[way]))
		if not out.is_empty() and region.has(start) and out.any(func(v: Vector2i) -> bool: return region.get(v, -1) == region[start]):
			bell_near += 1
	check(turns_ok, "each classroom teaches its department's three subjects in turn, one a session (geology's held two)")
	check(all_depts, "every department has a classroom (where there are rooms enough), so every class's prerequisite is taught somewhere")
	check(rhythms_ok, "each classroom has a class exactly while in session in its cycle, the same again a round on")
	check(cycles_ok, "each classroom in session %d periods of %d, its department meeting then" % [Timetable.IN_SESSION, Timetable.PERIODS])
	check(phases.size() > 1, "classrooms start at different places in the cycle (%d)" % phases.size())
	check(sessions_ok, "the library always open (no class)")
	check(doors_ok, "a door in every doorway of a hall with a class")
	check(furnished, "a lectern and a cord in each classroom, a cord in the library")
	check_eq(greats, LAID.size(), "at least %d bells out in the corridors, each over its cord" % Institute.CORRIDOR_BELLS_LEAST)
	check(roomy >= LAID.size() - 1, "where there is room over them (%d of %d)" % [roomy, LAID.size()])
	check(apart_ok, "at least %d cells apart" % Institute.BELL_APART)
	check(way_on_ok, "the way on stands on the floor of a classroom, one of those the most classrooms in from the way in")
	check(bell_near >= LAID.size() - 1, "one in the corridors the way in opens on (%d of %d)" % [bell_near, LAID.size()])
	check(seals_ok and sealed > 0, "glyph seals just inside the library's doorways, asking for a damage spell taught there (%d)" % sealed)
	check(same, "laid out the same twice")
	check(belongs_ok, "the wizard belongs in the corridors in passing time, the library, and a class in session")
	var plain: LevelGen = build(Vector2i(WORLD, NextWorldDef.band_row(&"cemetery", 1)))
	check(plain != null and not Timetable.kept_in(plain) and not Timetable.belongs(plain, 0, true, plain.free_floors()[0]), "no timetable out of the institute")


# ------------------------------------------------------------------ in play

func _play() -> void:
	await boot(WORLD)
	process_frame.connect(func() -> void: player.health.health = player.health.max_health)
	await _go(Vector2i(WORLD, NextWorldDef.first_depth(&"institute")))
	var rec: LevelRecord = info.record()
	check(rec.rings == 0 and rec.passing, "first met before any ring, in passing time")
	var cords: Array[Node] = placed("school_bell.tscn").filter(func(n: Node) -> bool: return (n as SchoolBell).great)
	check(cords.size() >= Institute.CORRIDOR_BELLS_LEAST, "the corridor bells' cords are there (%d)" % cords.size())
	if cords.size() < 2:
		return
	var bell: SchoolBell = cords[0] as SchoolBell
	await _belonging(rec, bell)
	await _bells(rec, cords[0] as SchoolBell, cords[1] as SchoolBell)
	await _doors(rec, bell)
	await _classes(rec, bell)
	await _attend(rec, bell)
	await _sneak(rec, bell)
	await _prereqs(rec, bell)
	await _climbing(rec, bell)
	await _way_on(rec, bell)
	await _abominations(rec)
	await _proctor(rec, bell)
	await _level_seal()
	await _spells()


## Belonging: seen truant, scholars turn, with those near them; a ring calms them and feeds the
## beast; passing time; a cast and a blow where they see it.
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
	# A class under way.
	rec.passing = false
	var near: Scholar = _spawn("student.tscn", floor_at + Vector2i(2, 0))
	var by: Scholar = _spawn("student.tscn", hidden)
	check(await within(func() -> bool: return near.roused, 1.0), "seen truant in the corridors in a period, a scholar turns on the wizard")
	check(by.roused and not by.sees(player), "and those near it with it, out of the wizard's sight")
	var calm: int = 0
	for n: Node in get_nodes_in_group(&"scholar"):
		if (n as Node2D).global_position.distance_to(player.global_position) > 2500.0 and not (n as Scholar).roused:
			calm += 1
	check(calm > 0, "not the whole level: %d far off stay calm" % calm)
	var fed: int = info.run.fed
	await _ring(bell)
	check(rec.rings == 1 and rec.passing, "a ring: the next period, and passing time")
	check(info.run.fed == fed + 1, "the beast fed")
	check(info.since_bell < MapInfo.BELL_TIME, "the great bell rings out")
	for n: Node in placed("school_bell.tscn"):
		var cord: SchoolBell = n as SchoolBell
		if cord.reach != SchoolBell.ceiling_over(info.world, cord.get_meta(&"cell")) or cord.reach < 2:
			check(false, "a cord at %s reaches its ceiling" % cord.get_meta(&"cell"))
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


## The bells: passing time, class time, passing time... Any bell rung in passing time begins class
## time, the wizard out in the halls truant; rung again by them in the halls, passing time comes back
## and the period is over; no cord twice running. A classroom's door stays shut until the wizard
## walks up to it. In a classroom as a bell rings, they attend its class; a bell will not ring it out
## from inside; walking out ends it, no bell. In class time other classrooms are shut to them; got
## into a class in session anyway (a warp), they are late: not truant, attending nothing.
func _bells(rec: LevelRecord, a: SchoolBell, b: SchoolBell) -> void:
	print("the bells")
	player.global_position = a.global_position
	await frames(2)
	rec.last_bell = Vector2i(-1, -1)
	var rings: int = rec.rings
	var fed: int = info.run.fed
	check(rec.passing, "passing time to begin with")
	info.since_bell = SchoolBell.RING_GAP
	a.ring()
	await frames(2)
	check(not rec.passing and rec.started < 0 and rec.rings == rings and info.run.fed == fed + 1, "a bell rung in passing time: class time, the beast fed")
	check(not info.wizard_belongs() and a.spent(), "out in the halls the wizard is truant; that cord was rung last")
	info.since_bell = SchoolBell.RING_GAP
	a.ring()
	check(not rec.passing, "pulled again at once, it does not ring")
	info.since_bell = SchoolBell.RING_GAP
	b.ring()
	await frames(2)
	check(rec.passing and rec.rings == rings + 1 and not a.spent() and b.spent(), "another rung by them in the halls: passing time, the period over")
	var hall: int = _hall_with_class()
	if hall < 0:
		for i: int in range(info.world.halls.size()):
			if info.subject_of(i) != &"":
				var need: Array = Timetable.needs(info.world.halls[i]["dept"], info.tier_of(i))
				player.keyring.take(KeyRing.paper(Timetable.LADDERS[need[0]][0], need[1]))
				hall = i
				break
	if hall < 0:
		return
	var doors: Array[Node] = placed("exam_door.tscn").filter(func(n: Node) -> bool: return (n as ExamDoor).hall == hall)
	if not doors.is_empty():
		var door: ExamDoor = doors[0] as ExamDoor
		var box: Rect2i = info.world.halls[hall]["box"]
		var out: int = -1 if door.cell.x == box.position.x else 1
		player.global_position = info.cell_position(door.cell + Vector2i(out * (ExamDoor.NEAR + 3), 0))
		check(await within(func() -> bool: return door.shut(), 1.0), "its classroom open to them, a door stays shut while they are a few steps off")
		player.global_position = info.cell_position(door.cell + Vector2i(out, 0))
		check(await within(func() -> bool: return not door.shut(), 1.0), "and opens as they walk up to it")
	player.global_position = _in_hall(hall)
	await frames(2)
	check(rec.passing and info.class_hall == hall, "going in starts nothing")
	info.since_bell = SchoolBell.RING_GAP
	a.ring()
	await frames(2)
	check(not rec.passing and rec.started == hall and rec.rings == rings + 1 and info.wizard_belongs(), "a bell rung (struck from in the classroom): class time, and they attend its class")
	var other: int = -1
	for i: int in range(info.world.halls.size()):
		if i != hall and info.subject_of(i) != &"" and info.enrolled(i):
			other = i
	if other >= 0:
		check(not info.hall_door_up(other), "in class time another classroom is shut to them")
	check(info.hall_door_up(hall), "its own lets them out")
	info.since_bell = SchoolBell.RING_GAP
	b.ring()
	check(not rec.passing, "a bell will not ring the class out from inside it")
	player.global_position = b.global_position
	await frames(2)
	check(rec.passing and rec.started < 0 and rec.rings == rings + 2, "walking out of the class ends it: passing time, the next period, no bell")
	rec.last_bell = Vector2i(-1, -1)
	info.since_bell = SchoolBell.RING_GAP
	a.ring()
	await frames(2)
	var late: int = _hall_with_class()
	if late >= 0 and not rec.passing:
		player.global_position = _in_hall(late)
		await frames(2)
		check(info.wizard_belongs() and rec.started < 0 and info.class_hall == late, "got into a class in session in class time (a warp): late, no longer truant, attending nothing")
		player.global_position = b.global_position
		await frames(2)
		check(rec.passing and rec.rings == rings + 3, "walking out of it, passing time")
	player.keyring.clear()
	if not rec.passing:
		await _ring(b)
	for n: Node in get_nodes_in_group(&"scholar"):
		(n as Scholar).calm()
	await frames(2)


## Hall doors follow the timetable: open while in session (the library always; a classroom's to a
## wizard enrolled). Each is looked at with the wizard outside it (far off, a door sleeps with its
## chunk, and settles as the wizard comes near).
func _doors(rec: LevelRecord, bell: SchoolBell) -> void:
	print("hall doors")
	var ok: bool = true
	var doors: Dictionary = {}
	for n: Node in placed("exam_door.tscn"):
		doors[(n as ExamDoor).cell] = n
	var paper: int = KeyRing.paper(&"hex", 1)
	player.keyring.take(paper)
	for k: int in range(Timetable.PERIODS):
		for i: int in range(info.world.halls.size()):
			var hall: Dictionary = info.world.halls[i]
			if not hall["kind"] in Timetable.TIMETABLED:
				continue
			var open: bool = Timetable.in_session(info.world, i, rec.rings) and (hall["kind"] != &"lecture" or info.enrolled(i))
			for j: int in range((hall["doors"] as Array).size()):
				var door: ExamDoor = doors.get(hall["doors"][j]) as ExamDoor
				if door == null:
					ok = false
					continue
				var box: Rect2i = hall["box"]
				var d: Vector2i = hall["doors"][j]
				player.global_position = info.cell_position(d + Vector2i(-1 if d.x == box.position.x else 1, 0))
				if not await within(func() -> bool: return door.shut() != open, 1.5):
					ok = false
				if hall["kind"] == &"lecture" and door.subject() != info.subject_of(i):
					ok = false
		await _ring(bell)
	player.keyring.spend(paper)
	check(ok, "every hall's doors stand open while it is in session (a classroom's to a wizard enrolled), shut while it is not, showing what it teaches now")


## Every ring seats each class afresh: its master teaching the hall's subject now, a hall with no
## class empty and trespassed in. A class's master (an instructor) is far stronger than one out in the
## level, and turning on the wizard it turns its whole class; felled by an abomination it leaves
## nothing and is back at the next ring; felled by the wizard it leaves a paper of its subject at the
## top tier, once a room.
func _classes(rec: LevelRecord, bell: SchoolBell) -> void:
	print("classes seated by the bell")
	player.global_position = bell.global_position
	var ok: bool = true
	var empty: int = -1
	for k: int in range(Timetable.PERIODS):
		await _ring(bell)
		for i: int in range(info.world.halls.size()):
			if info.world.halls[i]["kind"] != &"lecture":
				continue
			var box: Rect2i = info.world.halls[i]["box"]
			var seated: Array[Node] = get_nodes_in_group(&"scholar").filter(func(n: Node) -> bool: return box.has_point((n as Scholar).cell) and not n.is_queued_for_deletion())
			var a: StringName = info.subject_of(i)
			if a == &"":
				ok = ok and seated.is_empty()
				if empty < 0:
					empty = i
					# In a period, in a hall with no class: trespassing.
					rec.passing = false
					player.global_position = _in_hall(i)
					await frames(2)
					check(not info.wizard_belongs(), "in a hall with no class, the wizard is trespassing")
					player.global_position = bell.global_position
			else:
				var m: Scholar = info.master_in(i)
				ok = ok and m != null and m.ability == a and seated.size() > 1
	check(ok, "every ring seats each class afresh: its master teaching the hall's subject now, a hall with no class empty")
	print("a class's master felled")
	var hall: int = await _ring_to(bell, func(a: StringName) -> bool: return info.teaches(a))
	if hall < 0:
		return
	var a: StringName = info.subject_of(hall)
	var m: Scholar = info.master_in(hall)
	check(m.instructor() and (m.get_node("Wound") as Wound).hp >= int(Scholar.HP[&"master"]) + Scholar.INSTRUCTOR_HP and m.haste() > 1.0, "a classroom's master is an instructor: far tougher, and quicker")
	var box: Rect2i = info.world.halls[hall]["box"]
	m.rouse()
	var room: Array[Node] = get_nodes_in_group(&"scholar").filter(func(n: Node) -> bool: return box.has_point(info.cell_at((n as Node2D).global_position)))
	check(room.size() > 1 and room.all(func(n: Node) -> bool: return (n as Scholar).roused), "turning on the wizard, its whole class turns with it (%d)" % room.size())
	for n: Node in get_nodes_in_group(&"scholar"):
		(n as Scholar).calm()
	m.wizard_blow = false
	(m.get_node("Wound") as Wound).hit(99, Vector2.UP)
	await frames(2)
	check(placed("lesson.tscn").is_empty(), "felled by an abomination, a class's master leaves nothing")
	await _ring(bell)
	check(info.master_in(hall) != null or info.subject_of(hall) == &"", "and the class is seated again at the next ring")
	hall = await _ring_to(bell, func(s: StringName) -> bool: return info.teaches(s))
	if hall < 0:
		return
	a = info.subject_of(hall)
	m = info.master_in(hall)
	var at: Vector2 = m.global_position
	m.wizard_blow = true
	(m.get_node("Wound") as Wound).hit(99, Vector2.UP)
	await frames(3)
	var prize: int = KeyRing.stolen(KeyRing.paper(a, Abilities.max_tier(a)))
	var lying: Array[Node] = placed("key.tscn").filter(func(n: Node) -> bool: return (n as KeyPickup).key_color() == prize)
	check(lying.size() == 1 and (lying[0] as Node2D).global_position.distance_to(at) < 200.0 and placed("lesson.tscn").is_empty(), "felled by the wizard, the %s instructor leaves a stolen %s %d paper where it fell, no lesson" % [a, a, Abilities.max_tier(a)])
	await _ring(bell)
	for k: int in range(Timetable.PERIODS * 3):
		if info.master_in(hall) != null:
			break
		await _ring(bell)
	var again: Scholar = info.master_in(hall)
	if again != null:
		again.wizard_blow = true
		(again.get_node("Wound") as Wound).hit(99, Vector2.UP)
		await frames(3)
	check(placed("key.tscn").filter(func(n: Node) -> bool: return KeyRing.is_paper((n as KeyPickup).key_color())).size() == 1, "beaten again, it leaves nothing more: once a room")
	for n: Node in lying:
		n.queue_free()
	await frames(2)


## Attending: a class started by its cord leaves the wizard be; rung out from the corridors, its exam
## paper is sent to the level its department's portal leads to. A class whose master has turned on
## the wizard sends none, nor does a ring with no class started.
func _attend(rec: LevelRecord, bell: SchoolBell) -> void:
	print("attending a class")
	check(not info.teaches(&"levitate") and info.teaches(&"warp"), "a big move (levitate) is taught only to a wizard who has it; warp to anyone")
	Abilities.set_tier(player, &"levitate", 1)
	check(info.teaches(&"levitate"), "levitate, once found, is taught")
	Abilities.set_tier(player, &"levitate", 0)
	player.global_position = bell.global_position
	var hall: int = await _ring_to(bell, func(s: StringName) -> bool: return info.teaches(s))
	check(hall >= 0, "a lecture hall with a class")
	if hall < 0:
		return
	var a: StringName = info.subject_of(hall)
	var tier: int = info.tier_of(hall)
	check(tier == Timetable.tier_taught(a, int(info.dept_tiers()[info.world.halls[hall]["dept"]])), "taught at its department's tier (%d)" % tier)
	var field: Vector2i = info.field_of(hall)
	check(field != MapInfo.NO_FIELD and field.x == info.coord.x and field.y != info.coord.y, "its department's portal leads to a field level (%s)" % field)
	info.run.papers_out.clear()
	check(await _start(hall), "its cord rung inside, the class starts")
	await within(func() -> bool: return false, 0.6)
	var master: Scholar = info.master_in(hall)
	check(master != null and not master.roused, "the class leaves the wizard be")
	var rings: int = rec.rings
	await _leave(bell)
	check(rec.rings == rings + 1 and rec.passing, "walking out, the class is over: passing time, the next period")
	check(info.run.papers_out.get(field, []) == [KeyRing.paper(a, tier)], "its paper (%s %d) sent to the field level" % [a, tier])
	print("a class turned on the wizard, and the corridors")
	info.run.papers_out.clear()
	player.global_position = bell.global_position
	hall = await _ring_to(bell, func(s: StringName) -> bool: return info.teaches(s))
	if hall < 0:
		return
	await _start(hall)
	info.master_in(hall).rouse()
	await _leave(bell)
	check(info.run.papers_out.is_empty(), "a class whose master has turned on the wizard sends no paper")
	player.global_position = bell.global_position
	await frames(2)
	await _ring(bell)
	check(info.run.papers_out.is_empty(), "nor does a ring with no class started")
	await frames(2)


## Sneaking: an empty lecture hall's lectern holds the paper of its next class, at the tier taught
## after the next ring, lifted onto the ring once a period; then the lectern gives back spells put down
## (learning is permanent).
func _sneak(rec: LevelRecord, bell: SchoolBell) -> void:
	print("sneaking")
	player.global_position = bell.global_position
	var hall: int = -1
	for k: int in range(Timetable.PERIODS * 2):
		await _ring(bell)
		for i: int in range(info.world.halls.size()):
			if info.world.halls[i]["kind"] == &"lecture" and info.subject_of(i) == &"" and info.lectern_paper(i) != 0:
				hall = i
				break
		if hall >= 0:
			break
	check(hall >= 0, "an empty lecture hall whose next class is taught")
	if hall < 0:
		return
	var next: StringName = Timetable.subject(info.world, hall, rec.rings + 1)
	var code: int = KeyRing.paper(next, Timetable.tier_taught(next, int(info.dept_tiers()[info.world.halls[hall]["dept"]])))
	check_eq(info.lectern_paper(hall), code, "its lectern holds the next class's paper (%s %d)" % [next, KeyRing.paper_tier(code)])
	var lecterns: Array[Node] = placed("lectern.tscn").filter(func(n: Node) -> bool: return (n as Lectern).hall == hall)
	check(lecterns.size() == 1, "its lectern")
	if lecterns.is_empty():
		return
	var lectern: Lectern = lecterns[0] as Lectern
	# In by right: stayed on after the class rang out.
	info.class_hall = hall
	player.global_position = _in_hall(hall)
	await frames(2)
	check(lectern.paper() == code and lectern.holds() == [next, KeyRing.paper_tier(code)], "the lectern shows it")
	lectern.take()
	check(player.keyring.has(KeyRing.stolen(code)), "lifted onto the key ring, stolen")
	check(not info.wizard_belongs(), "carrying it, the wizard belongs nowhere")
	player.keyring.spend(KeyRing.stolen(code))
	check(info.lectern_paper(hall) == 0 and lectern.paper() == 0, "once a period: put down, it is not there again")
	print("a pigeonhole")
	var mine: int = KeyRing.paper(&"hex", 2)
	player.keyring.take(mine)
	lectern.take()
	check(not player.keyring.has(mine) and lectern.paper() == mine, "a paper carried left on the lectern")
	lectern.take()
	check(player.keyring.has(mine) and lectern.paper() == 0, "and taken back")
	lectern.take()
	var theirs: int = KeyRing.paper(&"slash", 1)
	player.keyring.take(theirs)
	lectern.take()
	check(player.keyring.has(mine) and not player.keyring.has(theirs) and lectern.paper() == theirs, "the paper picked up last swapped for the one it holds")
	check(int(rec.pigeonholes.get(hall, 0)) == theirs, "kept in the level's record")
	player.keyring.spend(mine)
	rec.pigeonholes.erase(hall)
	player.global_position = bell.global_position
	for n: Node in get_nodes_in_group(&"scholar"):
		(n as Scholar).calm()
	await frames(2)


## Prerequisites: a class of tier II or more asks for a paper of another department a tier lower
## (Timetable.needs): shut to a wizard who neither holds a spell of that department nor carries its
## paper at that tier, and they do not belong in it; a paper a tier lower is not enough; any subject
## of the department at that tier enrols them, and so does holding one. Resitting: a paper of the
## class's subject carried at a lower tier is graded up in hand, none sent away.
func _prereqs(rec: LevelRecord, bell: SchoolBell) -> void:
	print("prerequisites")
	player.global_position = bell.global_position
	var hall: int = -1
	for k: int in range(Timetable.PERIODS * 2):
		for i: int in range(info.world.halls.size()):
			var s: StringName = info.subject_of(i)
			if s != &"" and info.teaches(s) and info.master_in(i) != null and Abilities.max_tier(s) >= 3:
				hall = i
				break
		if hall >= 0:
			break
		await _ring(bell)
	check(hall >= 0, "a class to try")
	if hall < 0:
		return
	var dept: StringName = info.world.halls[hall]["dept"]
	rec.dept_tiers[dept] = 3
	var a: StringName = info.subject_of(hall)
	var tier: int = info.tier_of(hall)
	var need: Array = Timetable.needs(dept, tier)
	var ladder: Array = Timetable.LADDERS[need[0]]
	for b: StringName in ladder:
		Abilities.set_tier(player, b, 0)
	player.keyring.clear()
	check(not info.enrolled(hall) and not info.hall_door_up(hall), "%s %d asks for %s %d: none held nor carried, its doors stay shut" % [a, tier, need[0], need[1]])
	player.global_position = _in_hall(hall)
	await frames(2)
	check(Timetable.hall_inside(info.world, info.cell_at(player.global_position)) != hall, "got in another way (a warp), the wizard is put back out")
	if int(need[1]) > 1:
		var low: int = KeyRing.paper(ladder[0], int(need[1]) - 1)
		player.keyring.take(low)
		check(not info.enrolled(hall), "a %s paper a tier lower is not enough" % need[0])
		player.keyring.spend(low)
	var key: int = KeyRing.paper(ladder[2], need[1])
	player.keyring.take(key)
	check(info.enrolled(hall) and info.hall_door_up(hall), "carrying a %s %d paper (any subject of %s), enrolled: its doors open" % [ladder[2], need[1], need[0]])
	check(info.wizard_belongs(), "and the wizard belongs")
	player.keyring.spend(key)
	Abilities.set_tier(player, ladder[0], need[1])
	check(info.enrolled(hall), "holding %s %d does as well" % [ladder[0], need[1]])
	print("resitting")
	var old: int = KeyRing.paper(a, tier - 1)
	player.keyring.take(old)
	info.run.papers_out.clear()
	check(await _start(hall), "enrolled, the wizard goes in and starts the class")
	for n: Node in get_nodes_in_group(&"scholar"):
		(n as Scholar).calm()
	await _leave(bell)
	check(player.keyring.has(KeyRing.paper(a, tier)) and not player.keyring.has(old), "a %s %d paper carried in, rung out: graded up to %d in hand" % [a, tier - 1, tier])
	check(info.run.papers_out.is_empty(), "and none sent away")
	player.keyring.clear()
	Abilities.set_tier(player, ladder[0], 0)
	Abilities.set_tier(player, &"slash", 1)
	rec.dept_tiers.clear()
	player.global_position = bell.global_position
	for n: Node in get_nodes_in_group(&"scholar"):
		(n as Scholar).calm()
	await frames(2)


## The departments climb as the bell rings a period out (Timetable.climb, its rules checked in
## unit_test): rung with no class started, as nothing was attended; rung out of a class started, as
## that department was.
func _climbing(rec: LevelRecord, bell: SchoolBell) -> void:
	print("departments climbing")
	rec.dept_tiers = {&"astronomy": 2, &"botany": 2, &"geology": 1, &"necrology": 2}
	player.global_position = bell.global_position
	var before: Dictionary = info.dept_tiers()
	var meeting: Dictionary = info._meeting()
	await _ring(bell)
	check(info.dept_tiers() == Timetable.climb(before, &"", meeting), "rung from the corridors, they climb as nothing was attended (%s)" % [info.dept_tiers()])
	var hall: int = -1
	for k: int in range(Timetable.PERIODS * 2):
		for i: int in range(info.world.halls.size()):
			if info.subject_of(i) != &"" and info.teaches(info.subject_of(i)) and info.master_in(i) != null and info.enrolled(i):
				hall = i
				break
		if hall >= 0:
			break
		await _ring(bell)
	check(hall >= 0, "a class to attend")
	if hall < 0:
		return
	var dept: StringName = info.world.halls[hall]["dept"]
	await _start(hall)
	for n: Node in get_nodes_in_group(&"scholar"):
		(n as Scholar).calm()
	before = info.dept_tiers()
	meeting = info._meeting()
	await _leave(bell)
	check(info.dept_tiers() == Timetable.climb(before, dept, meeting), "rung out of a %s class, they climb as it was attended (%s)" % [dept, info.dept_tiers()])
	info.run.papers_out.clear()
	rec.dept_tiers.clear()
	# A class of a relic's move the wizard lacks: sat, it counts, with no paper.
	player.global_position = bell.global_position
	await frames(2)
	for m: StringName in Relics.MOVES:
		Abilities.set_tier(player, m, 0)
	hall = await _ring_to(bell, func(s: StringName) -> bool: return not info.teaches(s))
	if hall >= 0:
		dept = info.world.halls[hall]["dept"]
		var move: StringName = info.subject_of(hall)
		await _start(hall)
		for n: Node in get_nodes_in_group(&"scholar"):
			(n as Scholar).calm()
		before = info.dept_tiers()
		meeting = info._meeting()
		await _leave(bell)
		check(info.dept_tiers() == Timetable.climb(before, dept, meeting) and info.run.papers_out.is_empty(), "a %s class the wizard cannot be taught, sat: attended all the same, with no paper" % move)
	else:
		print("  (no class of a move the wizard lacks met here)")
	rec.dept_tiers.clear()
	player.global_position = bell.global_position
	for n: Node in get_nodes_in_group(&"scholar"):
		(n as Scholar).calm()
	await frames(2)


## The way on stands in a classroom, which opens on its class's own prerequisite like any other; the
## way on takes an exam paper of another department at Timetable.WAY_ON_PAPER as the wizard goes
## through: not one of its own department, not one a tier lower, not a spell held; the lowest it
## would take, once a level; with none it lets no one through.
func _way_on(rec: LevelRecord, bell: SchoolBell) -> void:
	print("the way on")
	var way: int = Timetable.way_on_hall(info.world)
	check(way >= 0, "the way on stands in a classroom")
	if way < 0:
		return
	player.global_position = bell.global_position
	player.keyring.clear()
	rec.dept_tiers.clear()
	for k: int in range(Timetable.PERIODS * 2):
		if info.subject_of(way) != &"":
			break
		await _ring(bell)
	if info.subject_of(way) == &"":
		return
	var own: StringName = info.world.halls[way]["dept"]
	var other: StringName = Timetable.NEEDS[own]
	check(info.tier_of(way) == 1 and info.enrolled(way) and info.hall_door_up(way), "a tier I class there opens to a wizard with no paper, like any other")
	check_eq(info.way_on_due(), -1, "but the way on would take a paper they lack")
	Abilities.set_tier(player, Timetable.LADDERS[other][0], Timetable.WAY_ON_PAPER)
	check_eq(info.way_on_due(), -1, "a spell held is not a paper")
	Abilities.set_tier(player, Timetable.LADDERS[other][0], 0)
	Abilities.set_tier(player, &"slash", 1)
	player.keyring.take(KeyRing.paper(Timetable.LADDERS[own][0], Timetable.WAY_ON_PAPER))
	check_eq(info.way_on_due(), -1, "nor is a paper of its own department")
	player.keyring.clear()
	player.keyring.take(KeyRing.paper(Timetable.LADDERS[other][1], Timetable.WAY_ON_PAPER - 1))
	check_eq(info.way_on_due(), -1, "nor one a tier lower")
	player.keyring.clear()
	var low: int = KeyRing.paper(Timetable.LADDERS[other][1], Timetable.WAY_ON_PAPER)
	var high: int = KeyRing.paper(Timetable.LADDERS[other][0], Timetable.WAY_ON_PAPER + 1)
	Abilities.set_tier(player, &"keyring", 1)
	player.keyring.take(high)
	player.keyring.take(low)
	check_eq(info.way_on_due(), low, "of a %s paper at %d and one at %d, it would take the lower" % [other, Timetable.WAY_ON_PAPER, Timetable.WAY_ON_PAPER + 1])
	info.hand_in_way_on(info.way_on_due())
	check(not player.keyring.has(low) and player.keyring.has(high) and rec.way_on_paid, "going through, it takes that paper, and only that")
	player.keyring.clear()
	Abilities.set_tier(player, &"keyring", 0)
	check_eq(info.way_on_due(), 0, "then it asks for none again here")
	rec.way_on_paid = false
	var exits: Array[Node] = placed("level_exit.tscn").filter(func(n: Node) -> bool: return (n as LevelExit).exit == MapInfo.Exit.DEEPER)
	if not exits.is_empty():
		var at: Vector2i = info.coord
		player.coins.coins = 99999
		(exits[0] as LevelExit).interacted()
		await frames(2)
		check(info.coord == at and not info.travelling, "with no paper it would take, the way on lets no one through")
	await frames(2)


## Abominations keep still during a class and act up in passing time, the more for every ring; a
## breach lets none out during a class.
func _abominations(rec: LevelRecord) -> void:
	print("abominations by the timetable")
	var at: Vector2i = _open_floor(5, 1)
	player.global_position = info.cell_position(at)
	rec.passing = false
	var thing: Abomination = _spawn_thing(at + Vector2i(4, 0), 1)
	await until(func() -> bool: return thing.grounded)
	var from: float = thing.global_position.x
	var lobes: int = thing.lobes
	await within(func() -> bool: return false, 1.5)
	check(absf(thing.global_position.x - from) < 4.0 and thing.lobes == lobes and thing.quarry == null, "during a class an abomination keeps still")
	rec.passing = true
	check(await within(func() -> bool: return thing.global_position.x < from - 30.0, 2.0), "in passing time it acts up, after the wizard")
	check(is_equal_approx(info.surge(), MapInfo.SURGE_LEAST + MapInfo.SURGE_PER_RING * float(rec.rings)), "growing and launching the sooner for every period rung out (%.2f times, %d rings)" % [info.surge(), rec.rings])
	check(Breach.every(0) > Breach.every(4) and Breach.every(99) == Breach.EVERY_LEAST, "and breaches letting them out the sooner too: every %.0f s before any ring, %.0f s after 4, %.0f s at most" % [Breach.every(0), Breach.every(4), Breach.EVERY_LEAST])
	thing.queue_free()
	var breaches: Array[Node] = placed("breach.tscn")
	if breaches.is_empty():
		return
	var breach: Breach = breaches[0] as Breach
	player.global_position = breach.global_position + Vector2(-300, 0)
	rec.passing = false
	await within(func() -> bool: return false, Breach.FIRST + Breach.SURGE + 0.5)
	check(breach.brood.is_empty(), "a breach lets none out during a class")
	rec.passing = true
	check(await within(func() -> bool: return not breach.brood.is_empty(), Breach.FIRST + Breach.SURGE + 1.0), "and in passing time does")
	for n: Node2D in breach.brood:
		n.queue_free()
	await frames(2)


## A proctor out in the corridors walks them during a class, and keeps its place in passing time.
func _proctor(rec: LevelRecord, bell: SchoolBell) -> void:
	print("proctors on their rounds")
	var at: Vector2i = _open_floor(5, 1)
	player.global_position = bell.global_position
	player.phasing = true
	var p: Scholar = _spawn("proctor.tscn", at + Vector2i(2, 0))
	rec.passing = false
	await until(func() -> bool: return p.grounded)
	var home: float = p.global_position.x
	check(await within(func() -> bool: return absf(p.global_position.x - home) > 100.0, 3.0), "during a class a proctor walks the corridors")
	rec.passing = true
	check(await within(func() -> bool: return absf(p.global_position.x - p.home_x) <= Scholar.HOME_SLACK + 4.0, 6.0), "in passing time it goes back to its place")
	p.queue_free()
	player.phasing = false


## A glyph seal of the level's own: another spell or a plain blow glances; its own breaks it, for
## good.
func _level_seal() -> void:
	print("the level's glyph seals")
	var seals: Array[Node] = placed("glyph_seal.tscn").filter(func(n: Node) -> bool: return not (n as GlyphSeal).broken())
	check(not seals.is_empty(), "the level's glyph seals are there")
	if seals.is_empty():
		return
	var own: GlyphSeal = seals[0] as GlyphSeal
	var cell: Vector2i = own.get_meta(&"cell")
	check(info.solid_at(own.global_position), "barring the way")
	var wrong: StringName = Institute.MASTERIES[posmod(Institute.MASTERIES.find(own.spell) + 1, Institute.MASTERIES.size())]
	own.struck(wrong)
	check(not own.broken(), "another spell glances off")
	own.struck(&"")
	check(not own.broken(), "and a plain blow")
	own.struck(own.spell)
	check(own.broken() and info.record().opened.has(cell) and not info.solid_at(own.global_position), "its own breaks it")
	await _go(info.coord)
	check(placed("glyph_seal.tscn").all(func(n: Node) -> bool: return n.get_meta(&"cell") != cell), "and it stays open")


## The spells themselves on seals: only its own spell opens a seal: a slash; a hex bolt; a seeker's
## bolt cast away and turning round to it; a nova; a push.
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
	# A hex bolt breaks a hex seal.
	Abilities.set_tier(player, &"hex", 1)
	seal = _seal(&"hex", floor_at + Vector2i(4, 0))
	player.global_position = info.cell_position(floor_at)
	await frames(2)
	var hex: Hex = player.get_node("Hex") as Hex
	hex.refill()
	var bolt: Node2D = hex.cast(Vector2.RIGHT)
	await until(gone(bolt))
	check(not is_instance_valid(seal) or seal.broken(), "a hex seal: struck by a hex bolt, it breaks")
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

## Ring `bell` as the wizard would once in a class: passing time over, and the bell rung out.
## A period rung round from corridor bell `bell` (whichever cord was rung last), the wizard truant out
## of the classrooms: in passing time it rings class time in and then out; in class time just out.
func _ring(bell: SchoolBell) -> void:
	if info.record().passing:
		await _pull(bell)
	await _pull(bell)


## Pull `bell`'s cord, whichever was rung last.
func _pull(bell: SchoolBell) -> void:
	info.record().last_bell = Vector2i(-1, -1)
	info.since_bell = SchoolBell.RING_GAP
	bell.ring()
	await frames(2)


## The wizard walks out of the classroom they are in, to `bell`: the class, and the period, are over.
func _leave(bell: SchoolBell) -> void:
	player.global_position = bell.global_position
	await frames(2)


## The wizard into classroom `hall` and its cord rung: its class started. Returns whether it did.
func _start(hall: int) -> bool:
	player.global_position = _in_hall(hall)
	await frames(2)
	var cord: SchoolBell = _cord_in(hall)
	if cord == null:
		return false
	info.record().last_bell = Vector2i(-1, -1)
	info.since_bell = SchoolBell.RING_GAP
	cord.ring()
	await frames(1)
	return info.record().started == hall


## The cord on classroom `hall`'s floor, or null.
func _cord_in(hall: int) -> SchoolBell:
	for n: Node in placed("school_bell.tscn"):
		if Timetable.hall_inside(info.world, (n as SchoolBell).cell) == hall:
			return n as SchoolBell
	return null


## Ring `bell` until a lecture hall's class (with its master there, the wizard enrolled) teaches a
## subject `want` holds true of, at most two days of rings: that hall, or -1.
func _ring_to(bell: SchoolBell, want: Callable) -> int:
	for k: int in range(Timetable.PERIODS * 2):
		await _ring(bell)
		for i: int in range(info.world.halls.size()):
			var s: StringName = info.subject_of(i)
			if s != &"" and bool(want.call(s)) and info.master_in(i) != null and info.enrolled(i):
				return i
	return -1


## A lecture hall with a class in session now that the wizard is enrolled in, or -1.
func _hall_with_class() -> int:
	for i: int in range(info.world.halls.size()):
		if info.subject_of(i) != &"" and info.enrolled(i):
			return i
	return -1


## A spot on classroom `hall`'s floor, just past its master.
func _in_hall(hall: int) -> Vector2:
	var inside: Rect2i = info.world.halls[hall]["inside"]
	var front: int = info.world.halls[hall]["front"]
	var wall: int = inside.position.x if front > 0 else inside.end.x - 1
	return info.cell_position(Vector2i(wall + front * 6, inside.end.y - 1))


## An abomination at `v`, of `lobes` blobs.
func _spawn_thing(v: Vector2i, lobes: int) -> Abomination:
	var node: Abomination = (load("res://prefabs/abomination.tscn") as PackedScene).instantiate() as Abomination
	LevelLoader.arm(node, info.here.depth)
	node.sprout(lobes)
	info.map_elements.add_child(node)
	node.global_position = info.cell_position(v)
	return node


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
## its left cell. Any foe standing on it, or a cell off its ends, is cleared away first.
func _open_floor(length: int, head: int) -> Vector2i:
	var all: Array[Vector2i] = _stretches(length, head)
	check(not all.is_empty(), "an open stretch of floor %d long to test on" % length)
	if all.is_empty():
		return info.world.free_floors()[0]
	var from: Vector2 = info.cell_position(all[0] + Vector2i(-1, 0))
	var to: Vector2 = info.cell_position(all[0] + Vector2i(length, 0))
	for n: Node in info.map_elements.get_children():
		var foe: Node2D = n as Node2D
		if foe == null or not n.has_meta(&"cell") or not Placeables.has_flag(info.world.get_cell(n.get_meta(&"cell")).type, &"enemy"):
			continue
		if foe.global_position.x >= from.x - 64.0 and foe.global_position.x <= to.x + 64.0 and absf(foe.global_position.y - from.y) < 200.0:
			n.queue_free()
	return all[0]


## Every stretch of floor `length` cells long with `head` rows of headroom, out of the halls, with
## nothing solid on it (foes may stand there: _open_floor clears them): their left cells, in order.
func _stretches(length: int, head: int) -> Array[Vector2i]:
	var w: LevelGen = info.world
	var out: Array[Vector2i] = []
	for y: int in range(w.size.y):
		for x: int in range(w.size.x):
			var ok: bool = true
			for k: int in range(length):
				var c: Vector2i = Vector2i(x + k, y)
				ok = ok and not _blocks(w, c) and w.is_ground(c + Vector2i.DOWN) and Institute.hall_at(w, c) < 0
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
