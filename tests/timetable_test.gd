extends TestKit
## The institute's timetable (Timetable, SchoolBell, ExamDoor, Lectern, ExamPrize, GlyphSeal;
## docs/REGIONS_PLAN.md §9). Its rules: each department's rotation of subjects (a period each, one
## empty), the tier taught rising with every ring, the beast fed by rings (more blows, quicker
## strikes, more souls). Laid out: each lecture hall's class steps through its department's subjects,
## one a ring, wrapping round; the library always open, the exam hall only in the last period; a door
## in each doorway of a hall with a class, a lectern and a cord in each lecture hall, a cord in the
## library, the great bell's cord near the way in with room over it; glyph seals just inside the exam
## hall's and the library's doorways asking for a damage spell taught there; the same every build;
## where the wizard belongs. In play: a level first met before any ring, in a period; scholars turn on
## a wizard they see truant, and those near them with them, not the whole level; a ring moves on a
## period, starts passing time, feeds the beast and calms them all; in passing time the corridors are
## the wizard's; a cast or a blow where they see it turns them; the bell rings once a period (not
## again in passing time, until the wizard goes into a class); hall doors stand open only while in
## session; every ring seats each class afresh, a master teaching its hall's subject, a hall with no
## class empty and trespassed in; a class's master felled by the wizard passes its trial, by an
## abomination nothing, and it is back at the next ring; going into a class ends passing time and
## sets its trial at the tier taught, the spell lent; leaving it unfinished gives back what was put
## down; passed, its subject goes on the exam's list, the wizard learning nothing yet; a move's trial
## set with its marks; an exam prize learned, and a lectern giving back what was put down;
## abominations still during a class and acting up in passing time, the more for every ring; proctors
## walking the corridors in a period; the level's glyph seals opening only to their own spell; and the
## spells themselves on seals (a slash, not on a hex seal; a hex bolt from far off, not near; a
## seeker's bolt turned round; a nova; a push).
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
	var turns_ok: bool = true
	var taught: Dictionary = {}
	for dept: StringName in Institute.DEPARTMENTS:
		var turn: Array = Timetable.ROTATIONS.get(dept, [])
		turns_ok = turns_ok and turn.size() == Timetable.PERIODS and turn.count(&"") == 1
		for a: StringName in turn:
			if a != &"":
				turns_ok = turns_ok and Abilities.is_spell(a)
				taught[a] = true
	check(turns_ok, "each department teaches a spell a period, one period empty")
	check(Institute.MASTERIES.all(func(a: StringName) -> bool: return taught.has(a)), "every damage spell is taught somewhere")
	check([&"warp", &"rift", &"levitate", &"ferry", &"astral"].all(func(a: StringName) -> bool: return taught.has(a)), "and the moves cast from the movement slot")
	check_eq([Timetable.tier_taught(&"hex", 0), Timetable.tier_taught(&"hex", 1), Timetable.tier_taught(&"hex", 9), Timetable.tier_taught(&"levitate", 9)], [1, 2, 4, 3], "every ring teaches a tier higher, up to each spell's top")
	var fed: RunState = RunState.new()
	fed.start(28)
	check(Beast.core_hp(fed) == Beast.CORE_HP and BeastSouls.count(fed) == BeastSouls.SOULS and is_equal_approx(Beast.attack_every(fed), Beast.ATTACK_EVERY), "an unfed beast as ever")
	fed.fed = 8
	check(Beast.core_hp(fed) == Beast.CORE_HP + 4 and BeastSouls.count(fed) == BeastSouls.SOULS + 2 and Beast.attack_every(fed) < Beast.ATTACK_EVERY, "fed by 8 rings: 4 blows more, 2 souls more, quicker strikes")
	fed.fed = 999
	check(Beast.core_hp(fed) == Beast.CORE_HP + Beast.FED_BLOWS_MOST and BeastSouls.count(fed) == BeastSouls.SOULS + BeastSouls.FED_SOULS_MOST and Beast.attack_every(fed) >= Beast.ATTACK_EVERY * Beast.FASTEST - 0.001, "and no more than so much")


# ------------------------------------------------------------------ laid out

func _laid_out() -> void:
	print("laid out")
	var turns_ok: bool = true
	var sessions_ok: bool = true
	var doors_ok: bool = true
	var furnished: bool = true
	var greats: int = 0
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
		var damage: Array[StringName] = Timetable.subjects_in(w).filter(func(a: StringName) -> bool: return a in Institute.MASTERIES)
		for i: int in range(w.halls.size()):
			var hall: Dictionary = w.halls[i]
			var kind: StringName = hall["kind"]
			var inside: Rect2i = hall["inside"]
			match kind:
				&"lecture":
					var day: Array = []
					for r: int in range(Timetable.PERIODS):
						day.append(Timetable.subject(w, i, r))
						turns_ok = turns_ok and Timetable.subject(w, i, r + Timetable.PERIODS) == day[r]
						# A rotation, one a ring: the next subject is the department's next.
						var turn: Array = Timetable.ROTATIONS[hall["dept"]]
						turns_ok = turns_ok and Timetable.subject(w, i, r + 1) == turn[(turn.find(day[r]) + 1) % turn.size()]
					turns_ok = turns_ok and day.count(&"") == 1
				&"library":
					for r: int in range(Timetable.PERIODS):
						sessions_ok = sessions_ok and Timetable.in_session(w, i, r) and not Timetable.holds_class(w, i, r)
				&"exam":
					for r: int in range(Timetable.PERIODS):
						sessions_ok = sessions_ok and Timetable.in_session(w, i, r) == (r == Timetable.EXAM_PERIOD)
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
					furnished = furnished and cords == 1
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
					&"exam":
						belongs_ok = belongs_ok and not Timetable.belongs(w, r, true, inside.position)
					&"lecture":
						belongs_ok = belongs_ok and Timetable.belongs(w, r, false, inside.position) == (Timetable.subject(w, i, r) != &"")
					&"library":
						belongs_ok = belongs_ok and Timetable.belongs(w, r, false, inside.position)
		var out: Array[Vector2i] = w.objects_of(LevelGen.Type.SCHOOL_BELL).filter(func(v: Vector2i) -> bool: return Institute.hall_at(w, v) < 0)
		if out.size() == 1 and bool((w.get_cell(out[0]).extra_info as Dictionary)["great"]):
			greats += 1
			if SchoolBell.ceiling_over(w, out[0]) > Institute.BELL_ROOM:
				roomy += 1
		var corridor: Vector2i = w.free_floors()[0]
		belongs_ok = belongs_ok and Timetable.belongs(w, 0, true, corridor) and not Timetable.belongs(w, 0, false, corridor)
	check(turns_ok, "each lecture hall's class steps through its department's subjects, one a ring, wrapping round, one period empty")
	check(sessions_ok, "the library always open (no class), the exam hall in session only in the last period")
	check(doors_ok, "a door in every doorway of a hall with a class")
	check(furnished, "a lectern and a cord in each lecture hall, a cord in the library")
	check_eq(greats, LAID.size(), "one cord out in the corridors, under the great bell")
	check(roomy >= LAID.size() - 1, "where there is room over it for the great bell (%d of %d)" % [roomy, LAID.size()])
	check(seals_ok and sealed > 0, "glyph seals just inside the exam hall's and the library's doorways, asking for a damage spell taught there (%d)" % sealed)
	check(same, "laid out the same twice")
	check(belongs_ok, "the wizard belongs in the corridors in passing time, the library, and a class in session; never the exam hall")
	var plain: LevelGen = build(Vector2i(WORLD, NextWorldDef.band_row(&"cemetery", 1)))
	check(plain != null and not Timetable.kept_in(plain) and not Timetable.belongs(plain, 0, true, plain.free_floors()[0]), "no timetable out of the institute")


# ------------------------------------------------------------------ in play

func _play() -> void:
	await boot(WORLD)
	process_frame.connect(func() -> void: player.health.health = player.health.max_health)
	await _go(Vector2i(WORLD, NextWorldDef.first_depth(&"institute")))
	var rec: LevelRecord = info.record()
	check(rec.rings == 0 and not rec.passing, "first met before any ring, in a period")
	var cords: Array[Node] = placed("school_bell.tscn").filter(func(n: Node) -> bool: return (n as SchoolBell).great)
	check(cords.size() == 1, "the great bell's cord is there")
	if cords.is_empty():
		return
	var bell: SchoolBell = cords[0] as SchoolBell
	await _belonging(rec, bell)
	await _once_a_period(rec, bell)
	await _doors(rec, bell)
	await _classes(rec, bell)
	await _trial(rec, bell)
	await _move_trial(rec, bell)
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


## The bell rings once a period: not again in passing time, until the wizard goes into a class.
func _once_a_period(rec: LevelRecord, bell: SchoolBell) -> void:
	print("the bell rings once a period")
	player.global_position = bell.global_position
	rec.passing = false
	info.since_bell = SchoolBell.RING_GAP
	check(info.ring_period() and rec.passing, "rung in a period, passing time begins")
	var rings: int = rec.rings
	var other: SchoolBell = placed("school_bell.tscn").filter(func(n: Node) -> bool: return not (n as SchoolBell).great)[0] as SchoolBell
	info.since_bell = SchoolBell.RING_GAP
	other.ring()
	var hall: int = _hall_with_class()
	if hall >= 0:
		check(rec.rings == rings, "pulled again in passing time, it does not ring: the wizard must go into a class first")
		player.global_position = _in_hall(hall)
		check(await within(func() -> bool: return not rec.passing, 0.5), "going into a class ends passing time")
		info.since_bell = SchoolBell.RING_GAP
		other.ring()
		check(rec.rings == rings + 1, "and then it rings again")
	else:
		check(rec.rings == rings + 1, "with no lecture hall's class in session, it rings again at once")
	player.global_position = bell.global_position
	await frames(2)


## Hall doors follow the timetable: open while in session (the library always); the exam's only in
## the last period. Each is looked at with the wizard outside it (far off, a door sleeps with its
## chunk, and settles as the wizard comes near).
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
			var open: bool = Timetable.in_session(info.world, i, rec.rings)
			if hall["kind"] == &"exam" and open != (Timetable.period(rec.rings) == Timetable.EXAM_PERIOD):
				exam_ok = false
			for j: int in range((hall["doors"] as Array).size()):
				var door: ExamDoor = doors.get(hall["doors"][j]) as ExamDoor
				if door == null:
					ok = false
					continue
				player.global_position = info.cell_position(hall["steps"][j])
				if not await within(func() -> bool: return door.shut() != open, 1.5):
					ok = false
				if hall["kind"] == &"lecture" and door.subject() != info.subject_of(i):
					ok = false
		await _ring(bell)
	check(ok, "every hall's doors stand open while it is in session, shut while it is not, showing what it teaches now")
	check(exam_ok, "the exam's only in the last period")


## Every ring seats each class afresh: its master teaching the hall's subject now, a hall with no
## class empty and trespassed in. A class's master felled by an abomination passes nothing and is back
## at the next ring; felled by the wizard, its trial is passed, and it leaves no lesson.
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
	m.wizard_blow = false
	(m.get_node("Wound") as Wound).hit(99, Vector2.UP)
	await frames(2)
	check(not rec.trials.has(a) and placed("lesson.tscn").is_empty(), "felled by an abomination, a class's master passes nothing and leaves nothing")
	await _ring(bell)
	check(info.master_in(hall) != null or info.subject_of(hall) == &"", "and the class is seated again at the next ring")
	hall = await _ring_to(bell, func(s: StringName) -> bool: return info.teaches(s))
	if hall < 0:
		return
	a = info.subject_of(hall)
	m = info.master_in(hall)
	m.wizard_blow = true
	(m.get_node("Wound") as Wound).hit(99, Vector2.UP)
	await frames(2)
	check(int(rec.trials.get(a, 0)) == info.tier_of(hall) and placed("lesson.tscn").is_empty(), "felled by the wizard, it passes its trial at the tier taught (%s %d), and leaves no lesson" % [a, info.tier_of(hall)])
	rec.trials.clear()


## Going into a class sets its trial at the tier taught, the spell lent; leaving gives back what was
## put down; passed, its subject goes on the exam's list, the wizard learning nothing yet; the exam's
## prize learned, and a lectern giving back what was put down.
func _trial(rec: LevelRecord, bell: SchoolBell) -> void:
	print("a trial")
	var hall: int = await _ring_to(bell, func(s: StringName) -> bool: return s in Institute.MASTERIES)
	check(hall >= 0, "a lecture hall teaching a damage spell")
	if hall < 0:
		return
	var master: Scholar = info.master_in(hall)
	var a: StringName = info.subject_of(hall)
	var tier: int = info.tier_of(hall)
	check(tier == mini(1 + rec.rings, Abilities.max_tier(a)), "taught at tier %d after %d rings" % [tier, rec.rings])
	# The wizard holds another spell, so the master's is lent.
	var other: StringName = Institute.MASTERIES[posmod(Institute.MASTERIES.find(a) + 1, Institute.MASTERIES.size())]
	Abilities.set_tier(player, other, 2)
	Abilities.set_tier(player, a, 0)
	Abilities.set_tier(player, other, 2)
	check(rec.passing, "in passing time")
	var spot: Vector2 = _in_hall(hall)
	player.global_position = spot
	check(await within(func() -> bool: return not rec.passing, 0.5), "going into a class in session ends passing time")
	check(await within(func() -> bool: return info.trial_hall == hall, 0.5), "its master sets a trial")
	check(Abilities.spell(player) == a and Abilities.tier(player, a) == tier, "its subject, %s, lent at the tier taught" % a)
	check(not info.trial_pieces.is_empty(), "its pieces laid in the hall (%d)" % info.trial_pieces.size())
	await within(func() -> bool: return false, 0.6)
	check(master != null and not master.roused, "the class leaves the wizard be")
	print("leaving mid-trial")
	player.global_position = bell.global_position
	check(await within(func() -> bool: return info.trial_hall < 0, 0.5), "leaving the hall leaves it unfinished")
	check(Abilities.spell(player) == other and Abilities.tier(player, other) == 2 and Abilities.tier(player, a) == 0, "what was put down given back, the lent spell taken away")
	# Out in the corridors in a period the wizard was truant: whoever saw them is calmed here, as by a
	# bell, without moving the period on.
	for n: Node in get_nodes_in_group(&"scholar"):
		(n as Scholar).calm()
	player.global_position = spot
	check(await within(func() -> bool: return info.trial_hall == hall, 0.5), "back in: the trial set again")
	var first: Node2D = info.trial_pieces[0]
	for wrong: StringName in [&"", other]:
		if first is GlyphSeal:
			(first as GlyphSeal).struck(wrong, first.global_position, 0.0)
		else:
			(first as TrialPiece).struck(wrong, first.global_position, Vector2.RIGHT)
	check(first in info.trial_pieces and info.trial_hall == hall, "a plain blow or another spell glances off it")
	_use_pieces(a)
	check(int(rec.trials.get(a, 0)) == tier and info.trial_spell != a, "its spell, used for what it does: the trial is passed, on the exam's list at tier %d" % tier)
	check(Abilities.spell(player) == other and Abilities.tier(player, a) == 0, "a trial teaches nothing itself: the wizard still holds the %s" % other)
	await frames(3)
	check(info.trial_hall < 0, "passed at this tier, it sets it no more")
	print("the exam's prize, and a lectern")
	info.take_exam_prize(a, tier)
	check(Abilities.spell(player) == a and Abilities.tier(player, a) == tier, "the exam's prize: %s learned at tier %d" % [a, tier])
	check(int(info.run.taught.get(a, 0)) == tier and int(info.run.taught.get(other, 0)) == 2, "kept for the run, and the %s put down still known" % other)
	var lecterns: Array[Node] = placed("lectern.tscn").filter(func(n: Node) -> bool: return (n as Lectern).hall == hall)
	check(lecterns.size() == 1, "its lectern")
	if lecterns.is_empty():
		return
	var lectern: Lectern = lecterns[0] as Lectern
	check(lectern.holds() == [other, 2], "it gives back the %s, at its tier" % other)
	lectern.take()
	check(Abilities.spell(player) == other and Abilities.tier(player, other) == 2, "taken up, in the slot")
	check(lectern.holds() == [a, tier], "and the %s waits there in turn" % a)
	lectern.take()
	check(Abilities.spell(player) == a, "learning is permanent")
	player.global_position = bell.global_position
	await frames(2)


## A move's trial: the move lent and its marks laid (trials_test passes every subject's); a big move
## taught only to a wizard who already has it.
func _move_trial(rec: LevelRecord, bell: SchoolBell) -> void:
	print("a move's trial")
	check(not info.teaches(&"levitate") and info.teaches(&"warp"), "a big move (levitate) is taught only to a wizard who has it; warp to anyone")
	Abilities.set_tier(player, &"levitate", 1)
	check(info.teaches(&"levitate"), "levitate, once found, is taught")
	Abilities.set_tier(player, &"levitate", 0)
	player.collect(200)
	var hall: int = await _ring_to(bell, func(s: StringName) -> bool: return s in [&"awareness", &"rift", &"warp"] and int(rec.trials.get(s, 0)) < Timetable.tier_taught(s, rec.rings))
	check(hall >= 0, "a class teaching a move or the utility spell")
	if hall < 0:
		return
	var a: StringName = info.subject_of(hall)
	var tier: int = info.tier_of(hall)
	var held: StringName = Abilities.spell(player, Abilities.slot_of(a))
	player.global_position = _in_hall(hall)
	check(await within(func() -> bool: return info.trial_hall == hall, 0.5), "its master sets a trial of %s" % a)
	check(Abilities.spell(player, Abilities.slot_of(a)) == a and Abilities.tier(player, a) == tier, "the %s lent at tier %d" % [a, tier])
	check(not info.trial_pieces.is_empty() and info.trial_pieces.all(func(n: Node2D) -> bool: return n is TrialPiece), "its marks laid in the hall")
	player.global_position = bell.global_position
	check(await within(func() -> bool: return info.trial_hall < 0, 0.5), "left, unfinished")
	check(Abilities.spell(player, Abilities.slot_of(a)) == held, "and what was held given back")
	player.global_position = bell.global_position
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
	check(is_equal_approx(info.surge(), 1.0 + MapInfo.SURGE_PER_RING * float(rec.rings)), "the sooner for every ring (%.1f times, %d rings)" % [info.surge(), rec.rings])
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

## Ring `bell` as the wizard would once in a class: passing time over, and the bell rung out.
func _ring(bell: SchoolBell) -> void:
	info.record().passing = false
	info.since_bell = SchoolBell.RING_GAP
	bell.ring()
	await frames(2)


## Ring `bell` until a lecture hall's class (with its master there) teaches a subject `want` holds
## true of, at most two days of rings: that hall, or -1.
func _ring_to(bell: SchoolBell, want: Callable) -> int:
	for k: int in range(Timetable.PERIODS * 2):
		await _ring(bell)
		for i: int in range(info.world.halls.size()):
			var s: StringName = info.subject_of(i)
			if s != &"" and bool(want.call(s)) and info.master_in(i) != null:
				return i
	return -1


## A lecture hall with a class in session now, or -1.
func _hall_with_class() -> int:
	for i: int in range(info.world.halls.size()):
		if info.subject_of(i) != &"":
			return i
	return -1


## A spot on lecture hall `hall`'s floor, past its master, short of its tiers.
func _in_hall(hall: int) -> Vector2:
	var inside: Rect2i = info.world.halls[hall]["inside"]
	var rise: int = info.world.halls[hall]["rise"]
	var wall: int = inside.position.x if rise > 0 else inside.end.x - 1
	return info.cell_position(Vector2i(wall + rise * 5, inside.end.y - 1))


## An abomination at `v`, of `lobes` blobs.
func _spawn_thing(v: Vector2i, lobes: int) -> Abomination:
	var node: Abomination = (load("res://prefabs/abomination.tscn") as PackedScene).instantiate() as Abomination
	LevelLoader.arm(node, info.here.depth)
	node.sprout(lobes)
	info.map_elements.add_child(node)
	node.global_position = info.cell_position(v)
	return node


## The trial under way's pieces each used as its spell, `a`, would use them (see TrialPiece): a mock
## seal struck from far off by a turned bolt, cords struck, the whole ring of sigils at once, the stone
## shoved along its track, the hoop lunged through from the air.
func _use_pieces(a: StringName) -> void:
	for piece: Node2D in info.trial_pieces.duplicate():
		if piece is GlyphSeal:
			(piece as GlyphSeal).struck(a, _from_far(piece as GlyphSeal), GlyphSeal.SEEKER_BEND + 0.1)
			continue
		var p: TrialPiece = piece as TrialPiece
		if p == null or p.done:
			continue
		match p.kind:
			TrialPiece.SIGIL:
				for s: TrialPiece in p.ring:
					s.struck(a, player.global_position, Vector2.RIGHT)
			TrialPiece.STONE:
				for k: int in range(TrialPiece.STONE_RUN):
					p.struck(a, player.global_position, Vector2(signf(p.goal_x - p.start_x), 0.0))
			TrialPiece.HOOP:
				player.global_position = p.global_position
				p.struck(a, player.global_position, Vector2.RIGHT)
			_:
				p.struck(a, player.global_position, Vector2.RIGHT)


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
