extends TestKit
## The classes' trials (TrialPiece, and GlyphSeal's mock seals; MapInfo.begin_trial; docs/REGIONS_PLAN.md
## §9), every subject in a lecture hall of the institute: each laid out, a wrong use leaving it
## standing and its own spell used for what it does passing it, onto the exam's list at the tier
## taught. A hex's mock seal struck from far off, not near; a seeker's by a bolt that has turned; a
## slash's three cords each cut by a slash, not a nova; a nova's ring of sigils all caught in one
## nova, not some of them, nor by a slash; a push's stone shoved along its track to its mark, a cell
## a gust (not by a slash, and no further than its track); a lunge's hoop lunged through in the air,
## not from the floor; a levitate mark touched while floating, not standing; a ferry mark touched on
## the wizard's own raft; an astral mark in the stone touched by the projection; the awareness
## marks touched while sensing, not before; a rift's two marks each with an end of the wizard's rift
## opened on it; a warp's by warping out of the hall and coming back.
## godot --headless --path . --script res://tests/trials_test.gd

const WORLD: int = 28
## Every subject, in the order tried.
const SUBJECTS: Array[StringName] = [&"hex", &"seeker", &"slash", &"nova", &"push", &"lunge", &"levitate", &"ferry", &"astral", &"awareness", &"rift", &"warp"]

var hall: int = -1
var rec: LevelRecord


func run() -> void:
	MapInfo.debug = false
	await boot(WORLD)
	process_frame.connect(func() -> void: player.health.health = player.health.max_health)
	await _go(Vector2i(WORLD, NextWorldDef.first_depth(&"institute")))
	rec = info.record()
	player.collect(500)
	# A lecture hall whose class is in session, its master there.
	for k: int in range(Timetable.PERIODS):
		for i: int in range(info.world.halls.size()):
			if info.subject_of(i) != &"" and info.master_in(i) != null:
				hall = i
				break
		if hall >= 0:
			break
		rec.passing = false
		info.since_bell = SchoolBell.RING_GAP
		info.ring_period()
		await frames(2)
	check(hall >= 0, "a lecture hall with its class in session")
	if hall >= 0:
		for a: StringName in SUBJECTS:
			await _trial(a)
	RunState.delete_save()
	finish()


## The trial of `a`: set, a wrong use, the right one.
func _trial(a: StringName) -> void:
	print(a)
	info.end_trial(false)
	rec.trials.clear()
	for n: Node in get_nodes_in_group(&"scholar"):
		(n as Scholar).calm()
	player.phasing = false
	# The big moves are taught only to a wizard who has them.
	if a in Relics.MOVES:
		Abilities.set_tier(player, a, 1)
	player.global_position = _at(Vector2i(4, 0))
	info.begin_trial(hall, a)
	check(info.trial_hall == hall and info.trial_spell == a and not info.trial_pieces.is_empty(), "%s: its trial laid out (%d pieces)" % [a, info.trial_pieces.size()])
	if info.trial_hall != hall:
		return
	var tier: int = info.trial_tier
	await call("_" + String(a))
	await frames(2)
	# (Passed, the hall may set its own subject's trial at once: the wizard is still in its class.)
	check(int(rec.trials.get(a, 0)) == tier and info.trial_spell != a, "%s: used for what it does, the trial is passed (tier %d)" % [a, tier])
	player.phasing = false
	player.global_position = _at(Vector2i(4, 0))
	await frames(2)


func _hex() -> void:
	var seal: GlyphSeal = info.trial_pieces[0] as GlyphSeal
	seal.struck(&"hex", seal.global_position + Vector2(100, 0), 0.0)
	check(not seal.broken(), "hex: a bolt from near glances off")
	seal.struck(&"hex", seal.global_position + Vector2(GlyphSeal.HEX_FAR + 20.0, 0), 0.0)


func _seeker() -> void:
	var seal: GlyphSeal = info.trial_pieces[0] as GlyphSeal
	seal.struck(&"seeker", seal.global_position + Vector2(300, 0), 0.2)
	check(not seal.broken(), "seeker: a bolt flying straight at it glances off")
	seal.struck(&"seeker", seal.global_position + Vector2(300, 0), GlyphSeal.SEEKER_BEND + 0.2)


func _slash() -> void:
	var cords: Array[TrialPiece] = _pieces()
	check_eq(cords.size(), TrialPiece.CORDS_AT.size(), "slash: its cords")
	SpellStrike.strike(cords[0], Vector2.RIGHT, 1, &"nova", player.global_position)
	check(not cords[0].done, "slash: a nova does not cut a cord")
	for c: TrialPiece in cords:
		SpellStrike.strike(c, Vector2.RIGHT, 1, &"slash", c.global_position - Vector2(80, 0))


func _nova() -> void:
	var sigils: Array[TrialPiece] = _pieces()
	check_eq(sigils.size(), TrialPiece.SIGILS, "nova: its ring of sigils")
	for k: int in range(sigils.size() - 1):
		SpellStrike.strike(sigils[k], Vector2.RIGHT, 1, &"nova", player.global_position)
	await physics_frame
	await physics_frame
	check(sigils.all(func(s: TrialPiece) -> bool: return not s.done), "nova: all but one caught, none counts")
	for s: TrialPiece in sigils:
		SpellStrike.strike(s, Vector2.RIGHT, 1, &"slash", player.global_position)
	check(sigils.all(func(s: TrialPiece) -> bool: return not s.done), "nor does a slash")
	for s: TrialPiece in sigils:
		SpellStrike.strike(s, Vector2.RIGHT, 1, &"nova", player.global_position)


func _push() -> void:
	var stone: TrialPiece = _pieces()[0]
	var from: float = stone.global_position.x
	var toward: Vector2 = Vector2(signf(stone.goal_x - stone.start_x), 0.0)
	SpellStrike.strike(stone, toward, 0, &"slash", player.global_position)
	check(stone.global_position.x == from, "push: a slash does not move the stone")
	SpellStrike.strike(stone, -toward, 0, &"push", player.global_position)
	check(stone.global_position.x == from and not stone.done, "pushed away from its mark, it goes no further than its track")
	for k: int in range(TrialPiece.STONE_RUN):
		SpellStrike.strike(stone, toward, 0, &"push", player.global_position)
	check(absf(stone.global_position.x - stone.goal_x) < 1.0, "shoved %d cells along its track to the mark" % TrialPiece.STONE_RUN)


func _lunge() -> void:
	var hoop: TrialPiece = _pieces()[0]
	# Standing on the floor: the wizard's middle 31 px over it.
	player.global_position = _at(Vector2i(4, 0)) + Vector2(0, 64.0 - 31.0)
	SpellStrike.strike(hoop, Vector2.RIGHT, 1, &"lunge", player.global_position)
	check(not hoop.done, "lunge: from the floor, it does not count")
	player.global_position = hoop.global_position + Vector2(-40, 0)
	SpellStrike.strike(hoop, Vector2.RIGHT, 1, &"lunge", player.global_position)


func _levitate() -> void:
	var mark: TrialPiece = _pieces()[0]
	player.global_position = mark.global_position
	await frames(3)
	check(not mark.done, "levitate: there, but not floating, it does not count")
	(player.get_node("Levitate") as Levitate).start()
	await frames(3)
	(player.get_node("Levitate") as Levitate).stop()


func _ferry() -> void:
	var mark: TrialPiece = _pieces()[0]
	player.global_position = mark.global_position
	await frames(3)
	check(not mark.done, "ferry: there, but not on a raft, it does not count")
	(player.get_node("Ferry") as Ferry).cast_spell()
	await frames(6)


func _astral() -> void:
	var mark: TrialPiece = _pieces()[0]
	check(info.solid_at(mark.global_position), "astral: its mark sunk in the stone")
	player.global_position = mark.global_position
	await frames(3)
	check(not mark.done, "there, but not projected, it does not count")
	player.phasing = true
	await frames(3)


func _awareness() -> void:
	var marks: Array[TrialPiece] = _pieces()
	check(marks.size() == TrialPiece.AWARE_AT.size() and marks.all(func(m: TrialPiece) -> bool: return not m.shown()), "awareness: its marks, hidden")
	player.global_position = marks[0].global_position
	await frames(3)
	check(not marks[0].done, "touched without sensing, it does not count")
	(player.get_node("Awareness") as Awareness).ping()
	check(marks.all(func(m: TrialPiece) -> bool: return m.shown()), "sensing, they show")
	for m: TrialPiece in marks:
		player.global_position = m.global_position
		await frames(3)


func _rift() -> void:
	var marks: Array[TrialPiece] = _pieces()
	check_eq(marks.size(), TrialPiece.RIFT_AT.size(), "rift: its two marks")
	var rift: Rift = player.get_node("Rift") as Rift
	rift.set_tier(2)
	player.global_position = marks[0].global_position
	await frames(2)
	rift.cast()
	await frames(3)
	check(marks[0].done and not marks[1].done, "an end opened on the first: it is done, the other not")
	player.global_position = marks[1].global_position
	await frames(2)
	rift.cast()
	await frames(3)


func _warp() -> void:
	check(Abilities.cast(player, Abilities.slot_of(&"warp")), "warp: cast in the hall")
	await until(func() -> bool: return player.get_node_or_null("Warp") == null or not (player.get_node("Warp") as Warp).warping)
	await frames(3)
	check(info.trial_hall == hall and info.trial_away, "warped out, the trial waits for the wizard to come back")
	player.global_position = _at(Vector2i(4, 0))
	await frames(3)


## The trial's pieces laid by TrialPiece.lay.
func _pieces() -> Array[TrialPiece]:
	var out: Array[TrialPiece] = []
	for p: Node2D in info.trial_pieces:
		if p is TrialPiece:
			out.append(p as TrialPiece)
	return out


## A spot in the hall (cells across from its lectern's wall, rows up from its floor).
func _at(at: Vector2i) -> Vector2:
	return info.cell_position(TrialPiece._in(info, hall, at))


func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
