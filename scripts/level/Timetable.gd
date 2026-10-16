class_name Timetable
extends RefCounted
## The institute's timetable (docs/REGIONS_PLAN.md §7 and §9): its band-wide puzzle, as light is the
## cemetery's and the tower switches are the crags'. There is no clock: nothing in it happens until a
## bell is rung (SchoolBell) or the wizard goes somewhere.
## - A level's day is a cycle of PERIODS periods. A ring of its great bell (pulling any of its cords,
##   SchoolBell) moves the level on to the next and starts passing time; the wizard going into a hall
##   whose class is in session ends it, and the period begins. The period and whether it is passing time are kept in the level's record
##   (LevelRecord.period, passing); a level is first met in its first period, under way.
## - Each hall with a class (TIMETABLED) is in session in some periods and not others (sessions,
##   dealt from the level seed): a lecture hall or the library in one or two of the periods before
##   the last, the exam hall only in the last (EXAM_PERIOD). Its doors (ExamDoor) stand open while it
##   is in session and are shut while it is not; the exam hall's are shut once its exam begins, as
##   before.
## - Where the wizard belongs (belongs): in the corridors (anywhere out of the halls) in passing
##   time, and in a hall whose class is in session. Anywhere else (the corridors in a period, a hall
##   whose class is not in session, the exam hall, the beast's chamber) they are truant, and the
##   scholars who see them there turn on them (Scholar.rouse) until the next bell.
## - A lecture hall's class in session sets a trial of its master's spell (MapInfo.begin_trial); the
##   exam hall's doorways, and the library's, are barred just inside by glyph seals (GlyphSeal)
##   asking for a spell some lecture hall's master here teaches (seal_of), so a level can be got
##   through from within itself.
## Nothing here draws from any RNG: it is all hashed from the level seed.

## How many periods a day has, and the last, the exam's.
const PERIODS: int = 4
const EXAM_PERIOD: int = PERIODS - 1
## The halls with a class in them, which keep the timetable.
const TIMETABLED: Array[StringName] = [&"lecture", &"library", &"exam"]
## The halls whose doorways are barred by glyph seals.
const SEALED: Array[StringName] = [&"exam", &"library"]
## Salts for the level seed: when each hall is in session, and which spell its seals ask for.
const SESSION_DEAL: int = 6470
const SEAL_DEAL: int = 6480


## The periods hall `hall` of `w` is in session in, a bit each (bit p for period p): the exam hall
## only in EXAM_PERIOD; a lecture hall or the library in one or two of the periods before it, never
## all of them; 0 for any other hall.
static func sessions(w: LevelGen, hall: int) -> int:
	if hall < 0 or hall >= w.halls.size():
		return 0
	var kind: StringName = w.halls[hall]["kind"]
	if kind == &"exam":
		return 1 << EXAM_PERIOD
	if not kind in TIMETABLED:
		return 0
	var full: int = (1 << EXAM_PERIOD) - 1
	return 1 + posmod(Rules.level_seed(w.seed_for_colors, SESSION_DEAL + hall), full - 1)


## Whether hall `hall` of `w` is in session in period `period`.
static func in_session(w: LevelGen, hall: int, period: int) -> bool:
	return sessions(w, hall) & (1 << posmod(period, PERIODS)) != 0


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


## Whether the wizard belongs at cell `v` of `w` in period `period`, in passing time or not (see the
## class description; a doorway counts as the corridor). False wherever there is no timetable.
static func belongs(w: LevelGen, period: int, passing: bool, v: Vector2i) -> bool:
	if not kept_in(w):
		return false
	var hall: int = hall_inside(w, v)
	if hall < 0:
		return passing
	var kind: StringName = w.halls[hall]["kind"]
	return kind != &"exam" and kind in TIMETABLED and in_session(w, hall, period)


## The master of hall `hall` in `w` (its cell), or (-1, -1) for none.
static func master_of(w: LevelGen, hall: int) -> Vector2i:
	for v: Vector2i in w.objects_of(LevelGen.Type.MASTER):
		var extra: Variant = w.get_cell(v).extra_info
		if extra is Dictionary and int((extra as Dictionary).get("hall", -1)) == hall:
			return v
	return Vector2i(-1, -1)


## The spells the lecture halls' masters of `w` teach, in the halls' order.
static func taught_in(w: LevelGen) -> Array[StringName]:
	var out: Array[StringName] = []
	for i: int in range(w.halls.size()):
		if w.halls[i]["kind"] != &"lecture":
			continue
		var m: Vector2i = master_of(w, i)
		if m.x >= 0:
			out.append(StringName((w.get_cell(m).extra_info as Dictionary)["ability"]))
	return out


## The spell the glyph seals barring hall `hall` of `w` ask for: one a lecture hall's master here
## teaches (taught_in), dealt by the seed, the library's another than the exam hall's where there is
## another; &"" for a hall not sealed (SEALED), or when no lecture hall here teaches anything.
static func seal_of(w: LevelGen, hall: int) -> StringName:
	var taught: Array[StringName] = taught_in(w)
	if taught.is_empty() or hall < 0 or hall >= w.halls.size() or not w.halls[hall]["kind"] in SEALED:
		return &""
	var first: int = posmod(Rules.level_seed(w.seed_for_colors, SEAL_DEAL), taught.size())
	return taught[(first + (1 if w.halls[hall]["kind"] == &"library" else 0)) % taught.size()]
