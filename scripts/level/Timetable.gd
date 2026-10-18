class_name Timetable
extends RefCounted
## The institute's timetable (docs/REGIONS_PLAN.md §7 and §9): its band-wide puzzle, as light is the
## cemetery's and the tower switches are the crags'. There is no clock: nothing in it happens until
## its great bell is rung (SchoolBell) or the wizard goes somewhere.
## - Each ring of the bell moves the level on a period (a level is first met before any ring, under
##   way) and starts passing time; the wizard going into a class in session ends it (holds_class),
##   and the period begins. The bell rings once a period: after a ring it is silent until passing
##   time is over (unless no class is in session anywhere, any_class). How many times it has rung
##   and whether it is passing time are kept in the level's record (LevelRecord.rings, passing).
## - Each classroom keeps its department (Institute.DEPARTMENTS), whose three subjects are a ladder
##   (LADDERS: its first, then the two each asking for the one before), and steps through them by
##   its cycle (cycle, subject): blocks of PERIODS rings, each two classes of neighbouring rungs and
##   then a break with no class, the block after starting a rung higher (hex, seeker, break; seeker,
##   warp, break; warp, hex, break; and round). So every third class is empty, and the first class
##   of a block teaches what the second asks for (but in the block wrapping round to the first rung),
##   so two rings in one room climb a rung. Where a classroom starts in its cycle is dealt by
##   the seed, so rooms are a stage or more apart. Every ring raises the tier taught in the level
##   (tier_taught). The library is always open. A hall's doors (ExamDoor) stand open while it is in
##   session and are shut while it is not.
## - Where the wizard belongs (belongs): in the corridors (anywhere out of the halls) in passing
##   time, in the library, and in a classroom whose class is in session. Anywhere else (the
##   corridors in a period, a classroom with no class, the beast's chamber) they are truant, and the
##   scholars who see them there turn on them (Scholar.rouse) until the next bell.
## - Prerequisites (prereq): each class asks for the rung before it on its department's ladder, at a
##   tier one less than it teaches (need), known or carried as an exam paper; a department's first
##   subject asks for nothing. A classroom's doors open only to a wizard enrolled so
##   (MapInfo.enrolled), and only one enrolled belongs in it.
## - Exam papers (KeyRing.paper): a wizard enrolled in a class as the bell rings it out has attended
##   it, and its paper (the subject at the tier taught) waits in the level its department's portal
##   leads to (MapInfo._attend), to be fetched and carried on the key ring; one carried of that
##   subject at a lower tier is graded up in hand instead (resitting). Each classroom's lectern holds
##   a paper left there (a pigeonhole, LevelRecord.pigeonholes); while the room is empty and its slot
##   bare, the next class's paper lies there to be lifted (sneaking, MapInfo.lectern_paper). A
##   class's master beaten by the wizard leaves a paper of its subject at the top tier, once a room
##   (MapInfo.instructor_fell). Papers are learned at lanterns (MapInfo.learn_paper).
## - The library's doorways are barred just inside by glyph seals (GlyphSeal) asking for a damage
##   spell some classroom here teaches (seal_of), so a level can be got through from within itself.
## Nothing here draws from any RNG: it is all hashed from the level seed.

## How many rings a block of a classroom's cycle lasts: two classes and a break (see the class
## description).
const PERIODS: int = 3
## The halls with a class in them, which keep the timetable.
const TIMETABLED: Array[StringName] = [&"lecture", &"library"]
## The halls whose doorways are barred by glyph seals.
const SEALED: Array[StringName] = [&"library"]
## Each department's ladder of subjects: its first (a damage spell, asking for nothing), then the two
## that each ask for the one before.
const LADDERS: Dictionary = {
	&"astronomy": [&"hex", &"seeker", &"warp"],
	&"geology": [&"slash", &"lunge", &"rift"],
	&"botany": [&"push", &"levitate", &"ferry"],
	&"necrology": [&"nova", &"astral", &"awareness"],
}
## Salts for the level seed: where each classroom starts in its cycle, and which spell the seals ask
## for.
const ROTATION_DEAL: int = 6470
const SEAL_DEAL: int = 6480


## Department `dept`'s cycle (see the class description): a block of PERIODS rings for each rung of
## its ladder, the rung and the one after it and then a break (&""), round its whole ladder.
static func cycle(dept: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var ladder: Array = LADDERS.get(dept, [])
	for k: int in range(ladder.size()):
		out.append(ladder[k])
		out.append(ladder[(k + 1) % ladder.size()])
		out.append(&"")
	return out


## The subject a class of `a` asks for first (see the class description): the rung before it on its
## department's ladder; &"" for a department's first subject (or one no department teaches).
static func prereq(a: StringName) -> StringName:
	for dept: StringName in LADDERS:
		var ladder: Array = LADDERS[dept]
		var k: int = ladder.find(a)
		if k > 0:
			return ladder[k - 1]
	return &""


## The tier of its prerequisite a class teaching at `tier` asks for: one less, but at least I.
static func need(tier: int) -> int:
	return maxi(1, tier - 1)


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


## What classroom `hall` of `w` teaches after `rings` rings: its department's subject then (cycle,
## from a place dealt by the seed), or &"" for no class (and for any other hall).
static func subject(w: LevelGen, hall: int, rings: int) -> StringName:
	if hall < 0 or hall >= w.halls.size() or w.halls[hall]["kind"] != &"lecture":
		return &""
	var turn: Array[StringName] = cycle(w.halls[hall]["dept"])
	if turn.is_empty():
		return &""
	var start: int = posmod(Rules.level_seed(w.seed_for_colors, ROTATION_DEAL + hall), turn.size())
	return turn[posmod(start + rings, turn.size())]


## The tier of `a` taught after `rings` rings: one more for every ring, up to its top.
static func tier_taught(a: StringName, rings: int) -> int:
	return mini(1 + maxi(rings, 0), Abilities.max_tier(a)) if Abilities.ABILITIES.has(a) else 0


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


## Every subject the classrooms of `w` teach over their cycles, in the halls' order, each once.
static func subjects_in(w: LevelGen) -> Array[StringName]:
	var out: Array[StringName] = []
	for i: int in range(w.halls.size()):
		for r: int in range(PERIODS * 3):
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
