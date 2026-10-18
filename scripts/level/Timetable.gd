class_name Timetable
extends RefCounted
## The institute's timetable (docs/REGIONS_PLAN.md §7 and §9): its band-wide puzzle, as light is the
## cemetery's and the tower switches are the crags'. There is no clock: nothing in it happens until
## its great bell is rung (SchoolBell) or the wizard goes somewhere.
## - Each ring of the bell moves the level on a period (a level is first met before any ring, in its
##   first period, under way) and starts passing time; the wizard going into a class in session
##   ends it (holds_class), and the period begins. The bell rings once a period: after a ring it is
##   silent until passing time is over (unless no class is in session anywhere, any_class). How
##   many times it has rung and whether it is passing time are kept in the level's record
##   (LevelRecord.rings, passing); the period is the rings counted round PERIODS.
## - Each lecture hall keeps its department (Institute.DEPARTMENTS), and its class steps through
##   that department's subjects (ROTATIONS), one a ring, wrapping round, from a place in it dealt by
##   the seed (subject): a spell, or no class at all. Every ring raises the tier taught in the level
##   (tier_taught): a hex I class, rung, becomes a seeker II. The library is always open, the exam
##   hall in session only in the last period (EXAM_PERIOD). A hall's doors (ExamDoor) stand open
##   while it is in session and are shut while it is not.
## - Where the wizard belongs (belongs): in the corridors (anywhere out of the halls) in passing
##   time, in the library, and in a lecture hall whose class is in session. Anywhere else (the
##   corridors in a period, a lecture hall with no class, the exam hall, the beast's chamber) they
##   are truant, and the scholars who see them there turn on them (Scholar.rouse) until the next
##   bell.
## - A class in session sets a trial of its subject (MapInfo.begin_trial); the exam hall's doorways,
##   and the library's, are barred just inside by glyph seals (GlyphSeal) asking for a damage spell
##   some lecture hall here teaches (seal_of), so a level can be got through from within itself.
## Nothing here draws from any RNG: it is all hashed from the level seed.

## How many periods a day has, and the last, the exam's.
const PERIODS: int = 4
const EXAM_PERIOD: int = PERIODS - 1
## The halls with a class in them, which keep the timetable.
const TIMETABLED: Array[StringName] = [&"lecture", &"library", &"exam"]
## The halls whose doorways are barred by glyph seals.
const SEALED: Array[StringName] = [&"exam", &"library"]
## What each department teaches, a period each in turn (&"" for no class), PERIODS of them: a damage
## spell or two and a move or two of its realm's, and one period empty.
const ROTATIONS: Dictionary = {
	&"astronomy": [&"hex", &"seeker", &"warp", &""],
	&"geology": [&"slash", &"lunge", &"rift", &""],
	&"botany": [&"push", &"levitate", &"ferry", &""],
	&"necrology": [&"nova", &"astral", &"awareness", &""],
}
## Salts for the level seed: where each lecture hall starts in its department's rotation, and which
## spell the seals ask for.
const ROTATION_DEAL: int = 6470
const SEAL_DEAL: int = 6480


## The period after `rings` rings of the bell.
static func period(rings: int) -> int:
	return posmod(rings, PERIODS)


## What lecture hall `hall` of `w` teaches after `rings` rings: its department's subject then
## (ROTATIONS, from a place dealt by the seed), or &"" for no class (and for any other hall).
static func subject(w: LevelGen, hall: int, rings: int) -> StringName:
	if hall < 0 or hall >= w.halls.size() or w.halls[hall]["kind"] != &"lecture":
		return &""
	var turn: Array = ROTATIONS.get(w.halls[hall]["dept"], [])
	if turn.is_empty():
		return &""
	var start: int = posmod(Rules.level_seed(w.seed_for_colors, ROTATION_DEAL + hall), turn.size())
	return turn[posmod(start + rings, turn.size())]


## The tier of `a` taught after `rings` rings: one more for every ring, up to its top.
static func tier_taught(a: StringName, rings: int) -> int:
	return mini(1 + maxi(rings, 0), Abilities.max_tier(a)) if Abilities.ABILITIES.has(a) else 0


## Whether hall `hall` of `w` is in session after `rings` rings: a lecture hall with a subject, the
## library always, the exam hall in the last period.
static func in_session(w: LevelGen, hall: int, rings: int) -> bool:
	if hall < 0 or hall >= w.halls.size():
		return false
	match w.halls[hall]["kind"]:
		&"lecture":
			return subject(w, hall, rings) != &""
		&"library":
			return true
		&"exam":
			return period(rings) == EXAM_PERIOD
	return false


## Whether hall `hall` holds a class in session after `rings` rings (going into one ends passing
## time): a lecture hall with a subject, or the exam hall in its period. The library is open, but it
## is no class.
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
	return kind != &"exam" and kind in TIMETABLED and in_session(w, hall, rings)


## The master of hall `hall` in `w` (its cell), or (-1, -1) for none.
static func master_of(w: LevelGen, hall: int) -> Vector2i:
	for v: Vector2i in w.objects_of(LevelGen.Type.MASTER):
		var extra: Variant = w.get_cell(v).extra_info
		if extra is Dictionary and int((extra as Dictionary).get("hall", -1)) == hall:
			return v
	return Vector2i(-1, -1)


## Every subject the lecture halls of `w` teach over a day, in the halls' order, each once.
static func subjects_in(w: LevelGen) -> Array[StringName]:
	var out: Array[StringName] = []
	for i: int in range(w.halls.size()):
		for r: int in range(PERIODS):
			var a: StringName = subject(w, i, r)
			if a != &"" and not a in out:
				out.append(a)
	return out


## The spell the glyph seals barring hall `hall` of `w` ask for: a damage spell a lecture hall here
## teaches (subjects_in), dealt by the seed, the library's another than the exam hall's where there
## is another; &"" for a hall not sealed (SEALED), or when no lecture hall here teaches one.
static func seal_of(w: LevelGen, hall: int) -> StringName:
	var taught: Array[StringName] = subjects_in(w).filter(func(a: StringName) -> bool: return a in Institute.MASTERIES)
	if taught.is_empty() or hall < 0 or hall >= w.halls.size() or not w.halls[hall]["kind"] in SEALED:
		return &""
	var first: int = posmod(Rules.level_seed(w.seed_for_colors, SEAL_DEAL), taught.size())
	return taught[(first + (1 if w.halls[hall]["kind"] == &"library" else 0)) % taught.size()]
