class_name InstitutePlay
extends RefCounted
## The institute as it is played (docs/CODE_REVIEW.md 2.2): its timetable's periods and bells, who
## is enrolled where and belongs there, the classes attended and their papers, the lecterns, the
## hall doors, the departments and the way back from one; and its papers and lessons wherever they
## are met (a paper studied at a lantern or the library's desk, a spell put back as a paper, a
## master's lesson left where it fell). The rules are Timetable's, scene-free;
## this plays them out in the level being played, over its record. MapInfo keeps one (`institute`)
## and hands it the moments (level_ready as a level is built, arrived as the wizard stands in it,
## step each physics step); the institute's prefabs call it through MapInfo.institute.

## The game's session, which this plays in.
var info: MapInfo


func _init(session: MapInfo) -> void:
	info = session


# ------------------------------------------------------------------ the moments MapInfo hands over

## A level is about to be built in the scene: what was the last level's is let go.
func level_begun () -> void:
	exam_doors.clear()


## The level is built: its lessons with something still on them stand, the papers waiting here are
## laid, and the way back from a department stands.
func level_ready () -> void:
	_spawn_lessons()
	_lay_papers()
	_spawn_way_back()


## The wizard is about to be set down in the level: they are in no classroom yet.
func arriving () -> void:
	class_hall = -1
	_outside_at = Vector2.INF


## The wizard stands at cell `at`: come out of a department into a classroom, they are in it by right.
func arrived (at: Vector2i) -> void:
	if _from_department:
		class_hall = Timetable.hall_inside(info.world, at)


## Arriving is over, with or without a wizard.
func settled () -> void:
	_from_department = false


## Time passes (every physics step, whatever is being played): the great bell rings out.
func tick (delta: float) -> void:
	since_bell += delta


## A physics step with the wizard in a level: where they are by the timetable (_watch_timetable).
func step () -> void:
	_watch_timetable()

## The hall doors of the level being played (ExamDoor), by cell: whether each is up now.
var exam_doors: Dictionary = {}

## A classroom's master (Scholar.instructor) fell to the wizard's own blow at `pos`, teaching `a`: it
## leaves a paper of `a` at the spell's top tier, once a classroom (`hall`, InstituteRecord.prizes), if the
## institute teaches `a` to the wizard (teaches). The prize for beating a class at its strongest, and
## stolen (KeyRing.stolen). Teaching a big move the wizard has not found (Relics.MOVES), it leaves
## that move's relic instead (relic_left).
func instructor_fell (hall: int, pos: Vector2, a: StringName) -> void:
	var rec: LevelRecord = info.record()
	if a == &"" or rec.institute.prizes.has(hall):
		return
	rec.institute.prizes[hall] = true
	# A big move the wizard has not found: its relic, so the institute can be where it is found.
	if not teaches(a):
		info.relic_left(pos, a, false)
		return
	var code: int = KeyRing.stolen(KeyRing.paper(a, Abilities.max_tier(a)))
	info._spawn_dropped_key.call_deferred(rec.drop_key(pos, code), pos, code)
	info.save_run()


## The great bell: how long it rings out once rung (seconds), the institute shaking with it at first
## as hard as BELL_SHAKE (px) and less as it fades; and the seconds since it was last rung (the art).
const BELL_TIME: float = 3.0
const BELL_SHAKE: float = 5.0
var since_bell: float = 99.0
## How fast the abominations grow and launch in passing time (MapInfo.surge): SURGE_LEAST times their
## own pace before any ring in their level, and SURGE_PER_RING more for every period rung out there.
const SURGE_LEAST: float = 0.5
const SURGE_PER_RING: float = 0.25
## Field papers: how far (cells) from a field level's way in its waiting papers lie, at least (where
## the level allows), and the salt for the run seed that deals their floors.
const PAPER_CLEAR: int = 10
const PAPER_DEAL: int = Salts.INSTITUTE_PLAY_PAPER * Salts.STRIDE
## A lectern's paper lifted in a period is kept by its hall and the rings (InstituteRecord.lifted): this
## many rings to a hall.
const LIFT_KEY: int = 10000
## No field level (a hall with no department's portal).
const NO_FIELD: Vector2i = Vector2i(-99999, -99999)

## Whether the level being played keeps the institute's timetable (Timetable.kept_in).
func timetabled () -> bool:
	return info.world != null and Timetable.kept_in(info.world)

## Whether the wizard is where they belong now (Timetable.belongs): false wherever there is no
## timetable, and anywhere while they carry a stolen paper (KeyRing.is_stolen).
func wizard_belongs () -> bool:
	if info.world == null or info.player == null or not is_instance_valid(info.player):
		return false
	if info.player.keyring.papers().any(func(code: int) -> bool: return KeyRing.is_stolen(code)):
		return false
	var rec: LevelRecord = info.record()
	var at: Vector2i = info.cell_at(info.player.global_position)
	if not Timetable.belongs(info.world, rec.institute.rings, rec.institute.passing, at):
		return false
	var hall: int = Timetable.hall_inside(info.world, at)
	return hall < 0 or info.world.halls[hall].kind != &"lecture" or enrolled(hall)

## Whether the wizard is enrolled in lecture hall `hall`'s class now (Timetable.needs): it has a
## class, and asks for nothing, or for a department whose subject they hold in a slot, or carry as an
## exam paper, at the tier it needs or higher.
func enrolled (hall: int) -> bool:
	var a: StringName = subject_of(hall)
	if a == &"" or info.player == null or not is_instance_valid(info.player):
		return false
	var need: Array = Timetable.needs(info.world.halls[hall].dept, tier_of(hall))
	if need[0] == &"":
		return true
	for b: StringName in Timetable.LADDERS[need[0]]:
		if Abilities.tier(info.player, b) >= int(need[1]):
			return true
	return info.player.keyring.papers().any(func(code: int) -> bool: return Timetable.dept_of(KeyRing.paper_spell(code)) == need[0] and KeyRing.paper_tier(code) >= int(need[1]))

## The exam paper the way on would take as the wizard goes through it (hand_in_way_on): of the exam
## papers carried (not spells held) of any department but its classroom's at
## Timetable.WAY_ON_PAPER or higher, the one of the lowest tier, oldest first. 0 when none is owed
## (no such classroom, or one taken here already, InstituteRecord.way_on_paid), -1 when one is owed and
## none is carried.
func way_on_due () -> int:
	var hall: int = Timetable.way_on_hall(info.world)
	if hall < 0 or info.record().institute.way_on_paid:
		return 0
	var best: int = -1
	for code: int in info.player.keyring.papers():
		var dept: StringName = Timetable.dept_of(KeyRing.paper_spell(code))
		if dept != &"" and dept != info.world.halls[hall].dept and KeyRing.paper_tier(code) >= Timetable.WAY_ON_PAPER:
			if best < 0 or KeyRing.paper_tier(code) < KeyRing.paper_tier(best):
				best = code
	return best

## The way on takes exam paper `code` (way_on_due) as the wizard goes through it, off the key ring
## for good; it asks for none again in this level (InstituteRecord.way_on_paid).
func hand_in_way_on (code: int) -> void:
	if code <= 0:
		return
	info.player.keyring.spend(code)
	info.record().institute.way_on_paid = true
	RisoFx.burst(&"gain", info.player.global_position + Vector2(0, -60), Vector2.ZERO, [Plate.ACCENT, Plate.NIGHT])
	info.save_run()

## What lecture hall `hall` teaches now (Timetable.subject; &"" for no class), and at what tier.
func subject_of (hall: int) -> StringName:
	return Timetable.subject(info.world, hall, info.record().institute.rings) if info.world != null else &""

func tier_of (hall: int) -> int:
	var a: StringName = subject_of(hall)
	return Timetable.tier_taught(a, int(dept_tiers()[info.world.halls[hall].dept])) if a != &"" else 0

## Whether the cord at `cell` can be rung now (SchoolBell): not within SchoolBell.RING_GAP of the last
## ring, and not the cord rung last (InstituteRecord.last_bell, as a crags tower flipped last cannot be
## flipped again), but for the cord of the classroom the wizard is shut in in class time: the class
## it began, it lets out (dismissing).
func bell_ready (cell: Vector2i) -> bool:
	if not timetabled() or since_bell < SchoolBell.RING_GAP:
		return false
	return cell != info.record().institute.last_bell or dismissing(cell)

## Whether ringing the cord at `cell` now would let out the class the wizard is in: class time, and
## the cord in the classroom they are in.
func dismissing (cell: Vector2i) -> bool:
	if info.record().institute.passing or info.player == null or not is_instance_valid(info.player):
		return false
	var hall: int = _classroom_of(info.cell_at(info.player.global_position))
	return hall >= 0 and _classroom_of(cell) == hall

## Whether the wizard would attend classroom `hall`'s class were a bell rung now (class time
## beginning): in the classroom by right (class_hall), its class in session and the wizard enrolled.
func class_ready (hall: int) -> bool:
	return hall >= 0 and class_hall == hall and info.player != null and is_instance_valid(info.player) \
		and Timetable.hall_inside(info.world, info.cell_at(info.player.global_position)) == hall and subject_of(hall) != &"" and enrolled(hall)

## The lecture hall whose open box holds cell `v`, or -1.
func _classroom_of (v: Vector2i) -> int:
	var hall: int = Timetable.hall_inside(info.world, v)
	return hall if hall >= 0 and info.world.halls[hall].kind == &"lecture" else -1

## The cord at `cell` pulled (SchoolBell), if it can be rung (bell_ready): in passing time class time
## begins (_class_time), in class time it ends (ring_period), whoever rings it: a wizard shut in a
## classroom, or one truant in the halls. It is the cord rung last now. Every ring
## feeds the beast (RunState.fed) and shakes the institute while it rings out (BELL_TIME). Returns
## whether it rang.
func pull_cord (cell: Vector2i) -> bool:
	if not bell_ready(cell):
		return false
	info.record().institute.last_bell = cell
	if info.record().institute.passing:
		_class_time()
	else:
		ring_period()
	return true

## A bell rung in passing time: class time begins. A wizard in a classroom by right, its class in
## session and they enrolled in it, attends it (InstituteRecord.started, class_ready); anywhere else they
## are truant.
func _class_time () -> void:
	var rec: LevelRecord = info.record()
	rec.institute.passing = false
	var hall: int = _classroom_of(info.cell_at(info.player.global_position)) if info.player != null and is_instance_valid(info.player) else -1
	rec.institute.started = hall if class_ready(hall) else -1
	_rung()
	info.save_run()

## A bell rung: when, the beast fed, the institute shaking.
func _rung () -> void:
	since_bell = 0.0
	Wound.shake(BELL_SHAKE, BELL_TIME)
	info.run.fed += 1

## A bell rung in class time (pull_cord): the period is rung out (_end_period), the class attended if
## the wizard is still in the one they began class time in (_attend), and the classrooms' doors open
## to them again.
func ring_period () -> bool:
	_rung()
	_end_period(_attend())
	return true

## The wizard got out of classroom `hall` in class time, shut as it is (a warp, a rift): its class, if
## they began class time in it, is forfeit (InstituteRecord.started), and they are truant until a bell
## rings the period out.
func _left_class (hall: int) -> void:
	if info.record().institute.started == hall:
		info.record().institute.started = -1

## Class time over: the departments climb by what was attended, the level moves on a period and
## passing time begins; every class is seated afresh (_seat_classes) and every scholar calms down.
func _end_period (attended: StringName) -> void:
	var rec: LevelRecord = info.record()
	rec.institute.dept_tiers = Timetable.climb(dept_tiers(), attended, _meeting())
	rec.institute.rings += 1
	rec.institute.passing = true
	rec.institute.started = -1
	_seat_classes()
	for node: Node in info.get_tree().get_nodes_in_group(&"scholar"):
		(node as Scholar).calm()
	info.save_run()

## Every department's tier in the level now (InstituteRecord.dept_tiers, I for one not yet climbed).
func dept_tiers () -> Dictionary:
	var out: Dictionary = {}
	for dept: StringName in Timetable.LADDERS:
		out[dept] = int(info.record().institute.dept_tiers.get(dept, 1))
	return out

## Which departments meet in this level now (department -> whether it has a classroom here and
## meets this period, Timetable.meets).
func _meeting () -> Dictionary:
	var out: Dictionary = {}
	var rings: int = info.record().institute.rings
	for dept: StringName in Timetable.LADDERS:
		out[dept] = Timetable.meets(info.world, dept, rings)
	return out

## The period ended: the wizard attended the class they began class time in (InstituteRecord.started),
## if they are in it still (class_hall; back from a field trip or never gone) and its master is there
## and not turned on them (beaten or crossed, it expels them). One whose subject the institute cannot teach
## them (teaches: a relic's move they lack) counts all the same, with no paper. A paper of its
## subject carried at a lower tier is graded up to the tier taught, there in hand (resitting);
## otherwise its exam paper (its subject at the tier taught, KeyRing.paper) waits in the level its
## department's portal leads to (field_of; RunState.papers_out, laid there by _lay_papers). Returns the
## department attended (what the departments climb by, Timetable.climb), or &"" for none.
func _attend () -> StringName:
	if info.player == null or not is_instance_valid(info.player):
		return &""
	var hall: int = info.record().institute.started
	if info.record().institute.passing or hall < 0 or hall != class_hall or hall >= info.world.halls.size() or info.world.halls[hall].kind != &"lecture":
		return &""
	var a: StringName = subject_of(hall)
	var m: Scholar = master_in(hall)
	var to: Vector2i = field_of(hall)
	if a == &"" or m == null or m.roused:
		return &""
	var dept: StringName = info.world.halls[hall].dept
	if not teaches(a):
		return dept
	var tier: int = tier_of(hall)
	for code: int in info.player.keyring.papers():
		if KeyRing.paper_spell(code) == a and KeyRing.paper_tier(code) < tier:
			info.player.keyring.replace(code, KeyRing.paper(a, tier))
			RisoFx.burst(&"gain", info.player.global_position + Vector2(0, -60), Vector2.ZERO, [Plate.ACCENT, Plate.GLOW])
			return dept
	if to != NO_FIELD:
		var waiting: Array = info.run.papers_out.get(to, [])
		waiting.append(KeyRing.paper(a, tier))
		info.run.papers_out[to] = waiting
		RisoFx.burst(&"gain", info.player.global_position + Vector2(0, -60), Vector2.ZERO, [Plate.ACCENT, Plate.BLUE])
	return dept

## The level lecture hall `hall`'s department's portals lead to (Department: every classroom of a
## department leads to the same level, Institute.first_of), or NO_FIELD.
func field_of (hall: int) -> Vector2i:
	var dept: StringName = info.world.halls[hall].dept
	for v: Vector2i in info.world.objects_of(LevelGen.Type.DEPARTMENT):
		var extra: Array = info.world.get_cell(v).extra_info as Array
		if StringName(extra[0]) == dept:
			return Vector2i(info.coord.x, int(extra[1]))
	return NO_FIELD

## The exam papers waiting in this level (RunState.papers_out, from classes attended), laid on its
## floors as keys left lying are (LevelRecord.dropped; LevelGen.floors_proper, none in a vault or a
## barrier's pocket), each at least PAPER_CLEAR cells from the way in where the level allows, dealt
## by the run seed.
func _lay_papers () -> void:
	var waiting: Array = info.run.papers_out.get(info.coord, [])
	if waiting.is_empty() or info.world == null:
		return
	info.run.papers_out.erase(info.coord)
	var start: Vector2i = info.world.exits.get(Ways.Exit.BACK, Vector2i(-1, -1))
	var floors: Array[Vector2i] = info.world.floors_proper()
	var far: Array[Vector2i] = floors.filter(func(v: Vector2i) -> bool: return LevelGen.dist(v, start) >= PAPER_CLEAR)
	if far.is_empty():
		far = floors
	if far.is_empty():
		return
	var rec: LevelRecord = info.record()
	for k: int in range(waiting.size()):
		var code: int = waiting[k]
		var v: Vector2i = far[posmod(Rules.level_seed(info.run.run_seed, PAPER_DEAL + code * 31 + k + info.coord.x * 977 + info.coord.y * 131), far.size())]
		var at: Vector2 = info.cell_position(v)
		info._spawn_dropped_key(rec.drop_key(at, code), at, code)
	info.save_run()

## Sneaking: the exam paper lecture hall `hall`'s lectern holds while the hall is empty (its class
## away): its next class's, at the tier taught after the next ring, once a period (InstituteRecord.lifted),
## and only one the institute teaches the wizard; else 0.
func lectern_paper (hall: int) -> int:
	if info.world == null or hall < 0 or hall >= info.world.halls.size() or info.world.halls[hall].kind != &"lecture" or subject_of(hall) != &"":
		return 0
	var rec: LevelRecord = info.record()
	if rec.institute.lifted.has(hall * LIFT_KEY + rec.institute.rings):
		return 0
	var next: StringName = Timetable.subject(info.world, hall, rec.institute.rings + 1)
	if next == &"" or not teaches(next):
		return 0
	return KeyRing.paper(next, Timetable.tier_taught(next, int(dept_tiers()[info.world.halls[hall].dept])))

## The paper on lecture hall `hall`'s lectern now: one left there (InstituteRecord.pigeonholes), else,
## while the room is empty, the next class's (lectern_paper); 0 for none.
func lectern_slot (hall: int) -> int:
	var rec: LevelRecord = info.record()
	if rec.institute.pigeonholes.has(hall):
		return int(rec.institute.pigeonholes[hall])
	var code: int = lectern_paper(hall)
	return code if code != 0 and not info.player.keyring.has(code) else 0

## Lecture hall `hall`'s lectern used from `at`: the paper the wizard picked up last goes onto it, and
## the one it held (lectern_slot) comes onto the ring; either may be missing. A next class's paper
## lifted is gone from it for the period (InstituteRecord.lifted), and stolen (KeyRing.stolen).
func lectern_swap (hall: int, at: Vector2) -> void:
	var rec: LevelRecord = info.record()
	var held: int = lectern_slot(hall)
	var papers: Array[int] = info.player.keyring.papers()
	var mine: int = papers[-1] if not papers.is_empty() else 0
	if (held == 0 and mine == 0) or held == mine:
		return
	if held != 0 and not rec.institute.pigeonholes.has(hall):
		rec.institute.lifted[hall * LIFT_KEY + rec.institute.rings] = true
		held = KeyRing.stolen(held)
	if mine != 0:
		info.player.keyring.spend(mine)
		rec.institute.pigeonholes[hall] = mine
	else:
		rec.institute.pigeonholes.erase(hall)
	if held != 0:
		give_paper(held, at)
	else:
		info.save_run()

## Exam paper `code` taken at `at`: onto the ring, as a key is (one put off a full ring is left
## lying at `at`, KeyRing.take).
func give_paper (code: int, at: Vector2) -> void:
	var had: int = info.player.keyring.take(code)
	if had >= 0:
		var rec: LevelRecord = info.record()
		var id: int = rec.drop_key(at, had)
		info._spawn_dropped_key.call_deferred(id, at, had)
	RisoFx.burst(&"gain", at + Vector2(0, -40), Vector2.ZERO, [Plate.ACCENT, Plate.BLUE])
	info.save_run()

## Whether the scholar laid at cell `v` is away now: a lecture hall's master or proctor while the hall
## has no class (LevelLoader.place_cell leaves it out). Students keep days of their own (Students).
func class_away (v: Vector2i) -> bool:
	if not timetabled():
		return false
	var hall: int = Timetable.hall_inside(info.world, v)
	return hall >= 0 and info.world.halls[hall].kind == &"lecture" and subject_of(hall) == &""

## Every lecture hall's staff seated afresh, as the bell has just rung: its master and proctor go (a
## fallen one is not slain any more), and, where the hall has a class now, they are placed again, the
## master teaching the hall's new subject. The students keep their own days (Students): they walk on
## to their next classes, and a fallen one is back, setting out from its last class.
func _seat_classes () -> void:
	if info.map_elements == null or not is_instance_valid(info.map_elements):
		return
	var rec: LevelRecord = info.record()
	for v: Vector2i in info.world.objects:
		if info.world.type_at(v) == LevelGen.Type.STUDENT and rec.slain.has(v):
			rec.slain.erase(v)
			info.loader.place_cell(v, info.world.get_cell(v))
	for i: int in range(info.world.halls.size()):
		if info.world.halls[i].kind != &"lecture":
			continue
		var box: Rect2i = info.world.halls[i].box
		for node: Node in info.get_tree().get_nodes_in_group(&"scholar"):
			var s: Scholar = node as Scholar
			if s != null and s.kind != &"student" and box.has_point(s.cell) and not s.is_queued_for_deletion():
				s.get_parent().remove_child(s)
				s.queue_free()
		for v: Vector2i in info.world.objects:
			if box.has_point(v) and info.world.type_at(v) in [LevelGen.Type.MASTER, LevelGen.Type.PROCTOR]:
				rec.slain.erase(v)
				if subject_of(i) != &"":
					info.loader.place_cell(v, info.world.get_cell(v))

## Whether hall `hall`'s doors would let the wizard through (ExamDoor, which opens a classroom's only
## as they walk up to it): the library's while it is in session (always); a classroom's only in
## passing time, from inside always, from outside to a wizard enrolled in its class in session. In
## class time every classroom is shut, both ways: a wizard in one stays until a bell rings the period
## out (ring_period; its own cord lets them out, dismissing), and one outside until the same.
func hall_door_up (hall: int) -> bool:
	if info.world == null or hall < 0 or hall >= info.world.halls.size():
		return true
	var rec: LevelRecord = info.record()
	var open: bool = Timetable.in_session(info.world, hall, rec.institute.rings)
	if info.world.halls[hall].kind == &"lecture":
		if not rec.institute.passing:
			return false
		var inside: bool = info.player != null and is_instance_valid(info.player) and Timetable.hall_inside(info.world, info.cell_at(info.player.global_position)) == hall
		return inside or (open and enrolled(hall))
	return open

## Whether the abominations keep still now: during a class (a period, not passing time).
func abominations_quiet () -> bool:
	return timetabled() and not info.record().institute.passing

## How fast the abominations grow and launch now, in passing time: SURGE_LEAST before any ring, and
## SURGE_PER_RING more for every period rung out in the level.
func surge () -> float:
	return SURGE_LEAST + SURGE_PER_RING * float(info.record().institute.rings) if timetabled() else 1.0

## Whether the institute will teach `a` to the wizard: anything, but a big move (Relics.MOVES) or
## resurrect only to a wizard who already has it, in its slot or as a paper (relics and crypts are how
## those are found, Abilities.found_first).
func teaches (a: StringName) -> bool:
	return a != &"" and (not Abilities.found_first(a) or Abilities.tier(info.player, a) > 0 or info.player.keyring.papers().any(func(code: int) -> bool: return KeyRing.paper_spell(code) == a))

## The classroom the wizard is in by right, or -1: one they went into enrolled in its class (or came
## back into through a department's way back) and have not left since. Tests seating the wizard in a
## classroom set it. And where they last were out of every classroom, to be put back to (keep_out;
## INF for nowhere yet).
var class_hall: int = -1
var _outside_at: Vector2 = Vector2.INF
## Whether the wizard is coming back through a department's way back (way_back_travel), to the portal
## in the classroom they left by: they are back in it by right.
var _from_department: bool = false

## Where the wizard is, by the timetable: going into a classroom they are enrolled in, they are in it
## by right (class_hall: a bell rung there begins class time with them attending, class_ready; got in
## in class time, by a warp or a rift, they are late, belonging but attending nothing); getting into
## one they are not enrolled in any other way, they are put back out (keep_out). Getting out of a
## classroom in class time (its doors are shut, so by a warp or a rift) forfeits its class
## (_left_class). A projection drifting through is let be until it ends.
func _watch_timetable () -> void:
	if not timetabled():
		return
	var hall: int = Timetable.hall_inside(info.world, info.cell_at(info.player.global_position))
	if hall < 0 or info.world.halls[hall].kind != &"lecture":
		_outside_at = info.player.global_position
		if class_hall >= 0 and not info.player.phasing:
			var left: int = class_hall
			class_hall = -1
			if not info.record().institute.passing:
				_left_class(left)
		return
	if hall == class_hall or info.player.phasing:
		return
	if not enrolled(hall):
		keep_out(hall)
		return
	if class_hall >= 0 and not info.record().institute.passing:
		_left_class(class_hall)
	class_hall = hall

## The wizard, got into classroom `hall` without being enrolled in its class (a warp, a rift, a
## projection ending there), put back where they last were out of the classrooms, or else on the step
## outside its first doorway.
func keep_out (hall: int) -> void:
	var to: Vector2 = _outside_at
	if not to.is_finite():
		var steps: Array = info.world.halls[hall].steps
		to = info.cell_position(steps[0]) if not steps.is_empty() else info.player.global_position
	info.player.global_position = to
	info.player.velocity = Vector2.ZERO

## The master of hall `hall` standing in the level, or null.
func master_in (hall: int) -> Scholar:
	for node: Node in info.get_tree().get_nodes_in_group(&"master"):
		var m: Scholar = node as Scholar
		if m != null and m.hall == hall and not m.is_queued_for_deletion():
			return m
	return null

## Arriving through a department's portal (Department): at the way back it opens (WayBack), as a
## gate's traveller comes out of its partner.
const ARRIVE_WAY_BACK: int = -5

## Through a department's portal (Department) to level `to`, coming out of the way back that opens
## there (WayBack), near that level's way back, leading to the portal at `portal_cell` here. It
## lasts until it is used; using another department's portal moves it.
func department_travel (to: Vector2i, portal_cell: Vector2i) -> void:
	if info.travelling or info.run_ending > 0.0 or not Worlds.valid(to):
		return
	info.run.way_back = [to, Vector2.INF, info.coord, portal_cell]
	info.save_run()
	await info._pass(Vector2(0, signf(float(to.y - info.coord.y))), to)
	info._arrive(to, ARRIVE_WAY_BACK)

## Back through the way back (WayBack) to the department's portal it was opened from; it closes.
func way_back_travel () -> void:
	if info.travelling or info.run_ending > 0.0 or info.run.way_back.size() < 4:
		return
	var to: Vector2i = info.run.way_back[2]
	var portal_cell: Vector2i = info.run.way_back[3]
	info.run.way_back = []
	await info._pass(Vector2(0, signf(float(to.y - info.coord.y))), to)
	info.arrival_pos = info.cell_position(portal_cell)
	_from_department = true
	info._arrive(to, -3)

## A way back's prefab (loaded when first needed).
const WAY_BACK: String = "res://prefabs/way_back.tscn"
## How far (cells) from the way back the way back from a department stands: at least, and at most
## where a floor that far off will do.
const WAY_BACK_NEAR: Vector2i = Vector2i(2, 8)
## How many cells of open air the way back from a department stands in, its own cell and those over it.
const WAY_BACK_AIR: int = 2
## How far (cells across) the way back from a department keeps from any other door or thing stood
## at (a level's ways, a door, a portal, a lantern...), so it is never on one and its prompt is
## never another's.
const WAY_BACK_APART: int = 2

## The way back from a department (RunState.way_back), if it opened in this place: on the free floor
## (LevelGen.floors_proper) nearest its way back, WAY_BACK_NEAR cells off, with open air over it as high as its arch
## (WAY_BACK_AIR cells, so nothing stands on top of it), and WAY_BACK_APART cells across from any
## other door or thing stood at (else the nearest such floor further off; else the nearest floor
## with that air, but never the way back's own cell), found the first time, then kept. The wizard
## comes through the department's portal out of it (ARRIVE_WAY_BACK).
func _spawn_way_back () -> void:
	var back: Array = info.run.way_back
	if back.size() < 4 or back[0] != info.coord or info.map_elements == null or info.world == null:
		return
	if back[1] == Vector2.INF:
		var spot: Vector2i = way_back_spot(info.world)
		back[1] = info.cell_position(spot)
	var node: WayBack = (load(WAY_BACK) as PackedScene).instantiate() as WayBack
	info.map_elements.add_child(node)
	node.global_position = back[1]
	node.setup(info)


## Where the way back from a department stands in level `w` (see _spawn_way_back).
static func way_back_spot (w: LevelGen) -> Vector2i:
	var from: Vector2i = w.exits.get(Ways.Exit.BACK, Vector2i.ZERO)
	# The cells too near something else that is stood at or passed through: a level's ways, doors,
	# portals, lanterns and the rest (Placeables' standers), gates; and the way back's own cell.
	var crowded: Dictionary = {}
	for o: Vector2i in w.objects:
		var t: LevelGen.Type = w.type_at(o)
		if Placeables.has_flag(t, &"stander") or t in [LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.STATION_GATE]:
			for dx: int in range(-WAY_BACK_APART, WAY_BACK_APART + 1):
				for dy: int in range(-1, 2):
					crowded[o + Vector2i(dx, dy)] = true
	var aired: Callable = func(v: Vector2i) -> bool:
		for k: int in range(1, WAY_BACK_AIR):
			if not w.is_valid(v + Vector2i(0, -k)) or w.type_at(v + Vector2i(0, -k)) != LevelGen.Type.EMPTY:
				return false
		return v != from
	var near: Callable = func(v: Vector2i) -> bool:
		var d: int = LevelGen.dist(v, from)
		return d >= WAY_BACK_NEAR.x and d <= WAY_BACK_NEAR.y and not crowded.has(v) and bool(aired.call(v))
	var apart: Callable = func(v: Vector2i) -> bool: return LevelGen.dist(v, from) >= WAY_BACK_NEAR.x and not crowded.has(v) and bool(aired.call(v))
	var floors: Array[Vector2i] = w.floors_proper()
	var score: Callable = func(v: Vector2i) -> int: return LevelGen.dist(v, from)
	for test: Callable in [near, apart, aired]:
		var spot: Variant = LevelGen.best_of(floors, score, test)
		if spot != null:
			return spot
	return from


# ------------------------------------------------------------------ papers and lessons

## Studying, at `at` (a lit lantern, Checkpoint, which it burns out; the library's desk,
## study_at_desk): the oldest paper carried that teaches something (learn_paper) is learned. Returns
## whether one was.
func study (at: Vector2) -> bool:
	if info.player == null or not is_instance_valid(info.player):
		return false
	for code: int in info.player.keyring.papers():
		if learn_paper(code, at):
			return true
	return false


## Whether exam paper `code` would teach something learned now (learn_paper): a spell that takes a
## slot, not one held there already at that tier or higher.
func teaches_paper (code: int) -> bool:
	var a: StringName = KeyRing.paper_spell(code)
	if a == &"" or Abilities.slot_of(a) == &"" or info.player == null or not is_instance_valid(info.player):
		return false
	return not (Abilities.spell(info.player, Abilities.slot_of(a)) == a and Abilities.tier(info.player, a) >= KeyRing.paper_tier(code))


## The paper the library's desk (StudyDesk) would teach now, or 0: in class time, to a wizard in the
## library who has not studied there this period (InstituteRecord.studied), the oldest carried that
## teaches something (teaches_paper). Free: the price is the bell that began class time.
func desk_paper () -> int:
	if not timetabled() or info.player == null or not is_instance_valid(info.player):
		return 0
	var rec: LevelRecord = info.record()
	if rec.institute.passing or rec.institute.studied == rec.institute.rings:
		return 0
	var hall: int = Timetable.hall_inside(info.world, info.cell_at(info.player.global_position))
	if hall < 0 or info.world.halls[hall].kind != &"library":
		return 0
	for code: int in info.player.keyring.papers():
		if teaches_paper(code):
			return code
	return 0


## Study at the library's desk, at `at` (desk_paper): its paper learned, once this period. Returns
## whether one was.
func study_at_desk (at: Vector2) -> bool:
	var code: int = desk_paper()
	if code == 0 or not learn_paper(code, at):
		return false
	info.record().institute.studied = info.record().institute.rings
	info.save_run()
	return true


## Exam paper `code` learned, at `at`: its spell takes its slot at the paper's tier, and the spell it
## puts out of the slot comes back as a paper (put_back). A paper of the spell already held, at a tier
## no higher than it is known, teaches nothing (and stays on the ring). Returns whether it taught.
func learn_paper (code: int, at: Vector2) -> bool:
	if not teaches_paper(code):
		return false
	var a: StringName = KeyRing.paper_spell(code)
	var tier: int = KeyRing.paper_tier(code)
	var held: StringName = Abilities.spell(info.player, Abilities.slot_of(a))
	var held_tier: int = Abilities.tier(info.player, held) if held != &"" else 0
	info.player.keyring.spend(code)
	Abilities.set_tier(info.player, a, tier)
	if held != &"" and held != a:
		put_back(held, held_tier, at)
	RisoFx.burst(&"gain", at, Vector2.ZERO, [Plate.ACCENT, Plate.GLOW])
	Wound.shake(6.0, 0.15)
	info.save_run()
	return true


## Spell `a`, known at `tier`, put out of its slot (a lantern's study, a shrine's boon, a lesson): it
## comes back as an exam paper (KeyRing.paper), onto the key ring (one put off a full ring is left
## lying at `at`).
func put_back (a: StringName, tier: int, at: Vector2) -> void:
	if a != &"" and tier > 0:
		give_paper(KeyRing.paper(a, tier), at)


## A master fell at `pos`, having mastered `ability`: its lesson (Lesson) waits where it fell, once
## a master (the one at `cell`): beaten again after a death, it leaves nothing more.
func leave_lesson (cell: Vector2i, pos: Vector2, ability: StringName) -> void:
	var rec: LevelRecord = info.record()
	if ability == &"" or rec.institute.lessons.has(cell):
		return
	rec.institute.lessons[cell] = {"at": pos, "ability": ability, "taken": false, "left": []}
	_spawn_lesson(cell)
	info.save_run()


## Every lesson here with something still on it.
func _spawn_lessons () -> void:
	for cell: Vector2i in info.record().institute.lessons:
		_spawn_lesson(cell)


## A lesson's prefab (loaded when first needed, not preloaded: it would load in a circle).
const LESSON: String = "res://prefabs/lesson.tscn"


func _spawn_lesson (cell: Vector2i) -> void:
	var e: Dictionary = info.record().institute.lessons.get(cell, {})
	if e.is_empty() or (bool(e.get("taken", false)) and (e.get("left", []) as Array).is_empty()):
		return
	if info.map_elements == null or not is_instance_valid(info.map_elements):
		return
	var lesson: Lesson = (load(LESSON) as PackedScene).instantiate() as Lesson
	info.map_elements.add_child(lesson)
	# On the floor under where the master fell.
	var at: Vector2 = e["at"]
	lesson.global_position = info.cell_position(info.cell_at(at + Vector2(0, -8)))
	lesson.setup(info, cell)
