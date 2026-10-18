class_name Timetable
extends RefCounted
## The institute's timetable (docs/REGIONS_PLAN.md §7 and §9): its band-wide puzzle, as light is the
## cemetery's and the tower switches are the crags'. There is no clock: nothing in it happens until
## its great bell is rung (SchoolBell) or the wizard goes somewhere.
## - Each ring of the bell moves the level on a period (a level is first met before any ring, under
##   way) and starts passing time; the wizard going into a class in session starts it: passing time
##   ends, the period begins, and the classroom's doors shut behind them until the bell rings it out
##   (MapInfo.hall_door_up; each classroom has a cord of its own). Only going in starts a class:
##   staying in a classroom as the bell rings does not, and in passing time its doors let them out.
##   Every pull of a cord rings the bell and moves every class on, in a period or in passing time
##   (MapInfo.bell_ready). How many times it has rung and whether it is passing time are kept in the
##   level's record (LevelRecord.rings, passing).
## - The day is PERIODS periods, the rings counted round (period). Each classroom keeps its
##   department (Institute.DEPARTMENTS), and each department keeps its own rhythm (RHYTHMS: the periods
##   it meets in) and steps through its three subjects (LADDERS) one a session, or one every HOLDS
##   sessions, from a place dealt by the seed (subject): astronomy meets every period, a new subject
##   each; geology every period, each subject two (double periods); botany the first two, fallow in
##   the last; necrology only in the last, at dusk.
## - Each department has a tier in the level (LevelRecord.dept_tiers, I at first, up to TOP), the tier
##   its classes teach (tier_taught, up to each spell's own top). When the bell rings a period out,
##   each department that met in it climbs by its own rule or falls back to I (climb), as they stood
##   at the start of the period: botany rises when its class was attended; astronomy when another
##   class was; geology when it stood strictly below every other department meeting with it; and
##   necrology when another department crashed back to I from II or higher. A department that did
##   not meet neither moves nor counts; one at the top holds there. So no ring raises a tier by
##   itself: every climb is the wizard's doing, and most cost another. The library is always open. A hall's doors (ExamDoor) stand open while it is in
##   session and are shut while it is not.
## - Where the wizard belongs (belongs): in the corridors (anywhere out of the halls) in passing
##   time, in the library, and in a classroom whose class is in session. Anywhere else (the
##   corridors in a period, a classroom with no class, the beast's chamber) they are truant, and the
##   scholars who see them there turn on them (Scholar.rouse) until the next bell.
## - Prerequisites (needs, NEEDS): a class of tier II or higher asks for any subject of one other
##   department, at a tier one less than it teaches, held or carried as an exam paper; a class of
##   tier I asks for nothing. The four ask round in a ring (astronomy geology's, geology botany's,
##   botany necrology's, necrology astronomy's), so climbing goes from room to room. A classroom's
##   doors open only to a wizard enrolled so (MapInfo.enrolled), and only one enrolled belongs in it:
##   one who gets in any other way (a warp, a rift, a projection) is put back out (MapInfo.keep_out).
## - The way on (the deeper exit) stands in a classroom (way_on_hall), the one most classrooms away
##   from the way in (Institute.way_on), and that classroom asks besides for an exam paper of any
##   other department at WAY_ON_PAPER or higher (MapInfo.way_on_paper), so getting through means
##   sitting classes.
## - Exam papers (KeyRing.paper): a wizard who started a class (went into it) and is in it as the
##   bell rings it out has attended it, and its paper (the subject at the tier taught) waits in the
##   level its department's portal leads to (MapInfo._attend), to be fetched and carried on the key
##   ring; one carried of that subject at a lower tier is graded up in hand instead (resitting). A
##   class the wizard cannot be taught (a relic's move they lack) counts as attended all the same,
##   with no paper. Each classroom's lectern holds
##   a paper left there (a pigeonhole, LevelRecord.pigeonholes); while the room is empty and its slot
##   bare, the next class's paper lies there to be lifted (sneaking, MapInfo.lectern_paper). A
##   class's master beaten by the wizard leaves a paper of its subject at the top tier, once a room
##   (MapInfo.instructor_fell). Those two are stolen (KeyRing.stolen): while the wizard carries one,
##   they belong nowhere, and every scholar who sees them turns on them. Papers are learned at
##   lanterns (MapInfo.learn_paper).
## - The library's doorways are barred just inside by glyph seals (GlyphSeal) asking for a damage
##   spell some classroom here teaches (seal_of), so a level can be got through from within itself.
## Nothing here draws from any RNG: it is all hashed from the level seed.

## How many periods a day has (see the class description).
const PERIODS: int = 3
## The halls with a class in them, which keep the timetable.
const TIMETABLED: Array[StringName] = [&"lecture", &"library"]
## The halls whose doorways are barred by glyph seals.
const SEALED: Array[StringName] = [&"library"]
## Each department's subjects, in the order it teaches them: its damage spell first.
const LADDERS: Dictionary = {
	&"astronomy": [&"hex", &"seeker", &"warp"],
	&"geology": [&"slash", &"lunge", &"rift"],
	&"botany": [&"push", &"levitate", &"ferry"],
	&"necrology": [&"nova", &"astral", &"awareness"],
}
## Each department's rhythm: the periods it meets in, and how many of its sessions each subject lasts.
const RHYTHMS: Dictionary = {
	&"astronomy": [0, 1, 2],
	&"geology": [0, 1, 2],
	&"botany": [0, 1],
	&"necrology": [2],
}
const HOLDS: Dictionary = {&"astronomy": 1, &"geology": 2, &"botany": 1, &"necrology": 1}
## The department whose paper each department's classes of tier II and up ask for (see the class
## description).
const NEEDS: Dictionary = {&"astronomy": &"geology", &"geology": &"botany", &"botany": &"necrology", &"necrology": &"astronomy"}
## The highest tier a department climbs to.
const TOP: int = 4
## The tier of the exam paper, of any department but its own, the classroom holding the way on asks
## for besides its class's own prerequisite (see the class description).
const WAY_ON_PAPER: int = 2
## Salts for the level seed: where each classroom starts in its department's subjects, and which
## spell the seals ask for.
const ROTATION_DEAL: int = 6470
const SEAL_DEAL: int = 6480


## Whether department `dept` meets in the period after `rings` rings (RHYTHMS).
static func meets(dept: StringName, rings: int) -> bool:
	return (RHYTHMS.get(dept, []) as Array).has(period(rings))


## How many times department `dept` has met before `rings` rings.
static func sessions_before(dept: StringName, rings: int) -> int:
	var days: Array = RHYTHMS.get(dept, [])
	@warning_ignore("integer_division")
	var whole: int = (maxi(rings, 0) / PERIODS) * days.size()
	return whole + days.filter(func(p: int) -> bool: return p < period(maxi(rings, 0))).size()


## The department that teaches `a`, or &"" for none.
static func dept_of(a: StringName) -> StringName:
	for dept: StringName in LADDERS:
		if (LADDERS[dept] as Array).has(a):
			return dept
	return &""


## What a class of department `dept` at `tier` asks for, as [the department, the tier]: one tier lower
## of NEEDS[dept]; [&"", 0] for a class of tier I.
static func needs(dept: StringName, tier: int) -> Array:
	if tier < 2 or not NEEDS.has(dept):
		return [&"", 0]
	return [NEEDS[dept], tier - 1]


## The departments' tiers after a period they stood at `tiers` (department -> tier), in which the
## wizard attended a class of department `attended` (&"" for none) and `meeting` (department -> bool)
## met (see the class description). Every rule reads the tiers as they stood at the start, and
## necrology last, the crashes of the others.
static func climb(tiers: Dictionary, attended: StringName, meeting: Dictionary) -> Dictionary:
	var out: Dictionary = tiers.duplicate()
	var crashed: bool = false
	var at: Callable = func(d: StringName) -> int: return int(tiers.get(d, 1))
	var met: Callable = func(d: StringName) -> bool: return bool(meeting.get(d, false))
	for dept: StringName in [&"botany", &"astronomy", &"geology"]:
		if not met.call(dept):
			continue
		var up: bool = false
		match dept:
			&"botany":
				up = attended == &"botany"
			&"astronomy":
				up = attended != &"" and attended != &"astronomy"
			&"geology":
				var others: Array = LADDERS.keys().filter(func(d: StringName) -> bool: return d != &"geology" and met.call(d))
				up = not others.is_empty() and others.all(func(d: StringName) -> bool: return at.call(d) > at.call(&"geology"))
		if up:
			out[dept] = mini(at.call(dept) + 1, TOP)
		else:
			crashed = crashed or at.call(dept) >= 2
			out[dept] = 1
	if met.call(&"necrology"):
		out[&"necrology"] = mini(at.call(&"necrology") + 1, TOP) if crashed else 1
	return out


## The classroom of `w` holding the way on (the deeper exit, Institute.way_on), or -1 for none.
static func way_on_hall(w: LevelGen) -> int:
	if not w.exits.has(MapInfo.Exit.DEEPER):
		return -1
	var hall: int = hall_inside(w, w.exits[MapInfo.Exit.DEEPER])
	return hall if hall >= 0 and w.halls[hall]["kind"] == &"lecture" else -1


## The damage spell of the department that teaches `a` (the first rung of its ladder), &"hex" for one
## no department teaches: what a class's master teaching a move casts (Scholar.spell_cast).
static func default_spell(a: StringName) -> StringName:
	for dept: StringName in LADDERS:
		var ladder: Array = LADDERS[dept]
		if ladder.has(a):
			return ladder[0]
	return &"hex"


## The period after `rings` rings of the bell.
static func period(rings: int) -> int:
	return posmod(rings, PERIODS)


## What classroom `hall` of `w` teaches after `rings` rings: &"" while its department does not meet
## (meets), else its subject then, one a session (or HOLDS), from a place dealt by the seed; &"" for
## any other hall.
static func subject(w: LevelGen, hall: int, rings: int) -> StringName:
	if hall < 0 or hall >= w.halls.size() or w.halls[hall]["kind"] != &"lecture":
		return &""
	var dept: StringName = w.halls[hall]["dept"]
	var ladder: Array = LADDERS.get(dept, [])
	if ladder.is_empty() or not meets(dept, rings):
		return &""
	var start: int = posmod(Rules.level_seed(w.seed_for_colors, ROTATION_DEAL + hall), ladder.size())
	@warning_ignore("integer_division")
	var turn: int = sessions_before(dept, rings) / int(HOLDS.get(dept, 1))
	return ladder[posmod(start + turn, ladder.size())]


## The tier a class of `a` teaches while its department stands at `dept_tier`: that, up to the
## spell's own top.
static func tier_taught(a: StringName, dept_tier: int) -> int:
	return mini(maxi(dept_tier, 1), Abilities.max_tier(a)) if Abilities.ABILITIES.has(a) else 0


## Whether hall `hall` of `w` is in session after `rings` rings: a classroom with a subject, the
## library always.
static func in_session(w: LevelGen, hall: int, rings: int) -> bool:
	if hall < 0 or hall >= w.halls.size():
		return false
	match w.halls[hall]["kind"]:
		&"lecture":
			return subject(w, hall, rings) != &""
		&"library":
			return true
	return false


## Whether hall `hall` holds a class in session after `rings` rings (going into one ends passing
## time): a classroom with a subject. The library is open, but it is no class.
static func holds_class(w: LevelGen, hall: int, rings: int) -> bool:
	return hall >= 0 and hall < w.halls.size() and w.halls[hall]["kind"] != &"library" and in_session(w, hall, rings)


## Whether any class of `w` is in session after `rings` rings.
static func any_class(w: LevelGen, rings: int) -> bool:
	for i: int in range(w.halls.size()):
		if holds_class(w, i, rings):
			return true
	return false


## Whether `w` keeps a timetable at all (it has a hall with a class in it).
static func kept_in(w: LevelGen) -> bool:
	if w == null:
		return false
	for hall: Dictionary in w.halls:
		if hall["kind"] in TIMETABLED:
			return true
	return false


## The hall whose open box holds cell `v` of `w` (an index into LevelGen.halls), or -1 out of them
## (in their walls and doorways too).
static func hall_inside(w: LevelGen, v: Vector2i) -> int:
	for i: int in range(w.halls.size()):
		if (w.halls[i]["inside"] as Rect2i).has_point(v):
			return i
	return -1


## Whether the wizard belongs at cell `v` of `w` after `rings` rings, in passing time or not (see
## the class description; a doorway counts as the corridor). False wherever there is no timetable.
static func belongs(w: LevelGen, rings: int, passing: bool, v: Vector2i) -> bool:
	if not kept_in(w):
		return false
	var hall: int = hall_inside(w, v)
	if hall < 0:
		return passing
	var kind: StringName = w.halls[hall]["kind"]
	return kind in TIMETABLED and in_session(w, hall, rings)


## The master of hall `hall` in `w` (its cell), or (-1, -1) for none.
static func master_of(w: LevelGen, hall: int) -> Vector2i:
	for v: Vector2i in w.objects_of(LevelGen.Type.MASTER):
		var extra: Variant = w.get_cell(v).extra_info
		if extra is Dictionary and int((extra as Dictionary).get("hall", -1)) == hall:
			return v
	return Vector2i(-1, -1)


## Every subject the classrooms of `w` teach over a few days, in the halls' order, each once.
static func subjects_in(w: LevelGen) -> Array[StringName]:
	var out: Array[StringName] = []
	for i: int in range(w.halls.size()):
		for r: int in range(PERIODS * 6):
			var a: StringName = subject(w, i, r)
			if a != &"" and not a in out:
				out.append(a)
	return out


## The spell the glyph seals barring hall `hall` of `w` ask for: a damage spell a classroom here
## teaches (subjects_in), dealt by the seed; &"" for a hall not sealed (SEALED), or when no classroom
## here teaches one.
static func seal_of(w: LevelGen, hall: int) -> StringName:
	var taught: Array[StringName] = subjects_in(w).filter(func(a: StringName) -> bool: return a in Institute.MASTERIES)
	if taught.is_empty() or hall < 0 or hall >= w.halls.size() or not w.halls[hall]["kind"] in SEALED:
		return &""
	var first: int = posmod(Rules.level_seed(w.seed_for_colors, SEAL_DEAL), taught.size())
	return taught[first]
