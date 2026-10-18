class_name Institute
extends RefCounted
## The institute's halls and who is in them (docs/REGIONS_PLAN.md §7). Its levels are collapsed from
## a sample of rooms and corridors (InstituteArchetype); right after the caves are joined, build sets
## its halls into them, buildings of pale marble (LevelGen.masonry) a cell thick all round, the air
## inside them printed over dark panelling (LevelGen.interiors):
## - the library's stacks (LIBRARY_INSIDE): galleries of ledges one over another, GALLERY rows apart,
##   each with a stair gap at one end (the ends taking turns up the stacks) and a ledge under the gap,
##   so each is climbed in two of the wizard's own hops; long sight lines for casters.
## - classrooms, the lecture halls (LECTURE_INSIDE), up to LECTURES of them where they fit: small
##   rooms with a flat floor (the lectern at its front end, with the master, and in the first of
##   each department its portal, Department) and a gallery of one-way ledges GALLERY_UP rows over it
##   where the students sit. Each has a doorway at each end of its floor and of its gallery where a
##   passage finds open air (at least MIN_DOORS), so a classroom is a way through, not a dead end.
## - in the beast's gate levels alone (LevelGen.gate), first of all so it has the pick of the level,
##   the beast's chamber (CHAMBER_INSIDE): a long hall with a flat floor, in the lower half where it
##   fits, holding the beast (Beast, LevelGen.place_boss) and nothing else.
## Each is entered by a doorway a cell high through each side wall at its floor (a classroom's at
## its gallery too); a hall with a class in it (Timetable.TIMETABLED) has a door in each
## (ExamDoor), open while its class is in session. A passage two rows high is carved out from each
## doorway through the rock
## until it meets open air (at most DOOR_REACH cells; a side whose passage finds none has no
## doorway). Where each goes is the site walling over the least open air and needing the shortest
## passages (as a crypt's, Crypts), ties dealt by the seed. Its stone, inside and passages are kept
## whole (LevelGen.kept_whole) and out of the free cells, so nothing else is laid in it. Each is
## noted in LevelGen.halls as {"kind": &"library", &"lecture" or &"chamber", "box": the hall with its
## walls (Rect2i), "inside": the open box inside it (Rect2i), "doors": its doorways, "steps": the
## open cell outside each where its passage meets the air, "floors": where the wizard can stand
## inside (on its floor or its galleries), sorted, "front": which way a classroom faces from its
## lectern's wall (+1 the lectern at the left wall, -1 at the right; 0 for the rest), "dept": a
## classroom's department (DEPARTMENTS)}. Nothing in build or furnish draws from the world RNG: it is all hashed
## from the level seed. populate draws, as any archetype's own dressing does.

## The open box inside each kind of hall (cells across and down, not counting the walls).
const LIBRARY_INSIDE: Vector2i = Vector2i(12, 8)
const LECTURE_INSIDE: Vector2i = Vector2i(10, 5)
const CHAMBER_INSIDE: Vector2i = Vector2i(18, 6)
## How many classrooms a level tries to build (each only where it fits), the fewest doorways one
## has, and how much each doorway counts for a site, against each cell of open air it walls over
## (classrooms want to be ways through).
const LECTURES: int = 5
const MIN_DOORS: int = 2
const DOOR_WORTH: int = 12
## The library's galleries: one every GALLERY rows up from the floor, with a stair gap STAIR cells
## wide at one end.
const GALLERY: int = 3
const STAIR: int = 2
## A classroom's gallery: how many rows over its floor its ledges lie (the gallery's own floor a row
## over them).
const GALLERY_UP: int = 2
## The longest passage out from a doorway to open air (cells), and how much each cell of passage
## counts against a site, against each cell of open air it walls over.
const DOOR_REACH: int = 8
const PASSAGE_COST: int = 3
## Cells kept between a hall and another hall or anything kept whole.
const APART: int = 2
## Salts for the level seed: where each hall goes (ties), which way a classroom faces, which end
## the library's lowest gap is at, what each master has mastered and which department each lecture
## hall is and where its portal leads.
const SITE_DEAL: int = 6400
const RISE_DEAL: int = 6410
const GAP_DEAL: int = 6420
const MASTER_DEAL: int = 6430
const DEPT_DEAL: int = 6440
const ROW_DEAL: int = 6450

## What a master may have mastered: one of the wizard's damage spells (Abilities), which it casts
## (Scholar) and teaches once beaten (Lesson).
const MASTERIES: Array[StringName] = [&"hex", &"seeker", &"slash", &"nova", &"push", &"lunge"]
## The departments and the band each studies (NextWorldDef's archetype names), in the order they
## are dealt to lecture halls.
const DEPARTMENTS: Dictionary = {
	&"botany": &"garden",
	&"necrology": &"cemetery",
	&"geology": &"crags",
	&"astronomy": &"sky",
}

## The timetable's great bell and its cords (SchoolBell): the bell hangs from the ceiling out in the
## corridors over the nearest free floor to the way in at least BELL_CLEAR cells from it with
## BELL_ROOM open cells over it (else any such floor), its cord hanging from it; and a cord in each
## lecture hall and the library, up into the ceiling.
const BELL_CLEAR: int = 3
const BELL_ROOM: int = 3

## Out in the level (populate), per 1000 cells: breaches abominations rise from (Breach), at least
## BREACH_CLEAR cells from the way in and BREACH_APART from one another; abominations already up;
## and small classes out of their halls (a master with CLASS students round it, within CLASS_REACH
## cells), CLASS_CLEAR from the way in and CLASS_APART from one another.
const BREACHES_PER_K: float = 0.5
const BREACH_CLEAR: int = 12
const BREACH_APART: int = 10
const ABOMINATIONS_PER_K: float = 0.5
const ABOMINATION_CLEAR: int = 10
const CLASSES_PER_K: float = 0.35
const CLASS: int = 3
const CLASS_REACH: int = 4
const CLASS_CLEAR: int = 10
const CLASS_APART: int = 12
## Proctors out with classes: one class in PROCTOR_EVERY has one.
const PROCTOR_EVERY: int = 2
## The stars on the library's top gallery.
const HOARD: int = 3
## Where a classroom's students sit on its gallery: cells from its lectern's wall.
const SEATS: Array[int] = [2, 5, 8]


# ------------------------------------------------------------------ building

## Build the halls into `w` (see the class description), then join the caves again round their walls.
static func build(w: LevelGen) -> void:
	if w.gate == &"beast":
		var low: Callable = func(box: Rect2i) -> bool: return box.position.y * 2 >= w.size.y
		var chamber_site: Dictionary = _site(w, CHAMBER_INSIDE, _flat_doors(CHAMBER_INSIDE), low)
		if chamber_site.is_empty():
			chamber_site = _site(w, CHAMBER_INSIDE, _flat_doors(CHAMBER_INSIDE), func(_box: Rect2i) -> bool: return true)
		if not chamber_site.is_empty():
			_raise(w, &"chamber", chamber_site, 0)
	var library: Dictionary = _site(w, LIBRARY_INSIDE, _flat_doors(LIBRARY_INSIDE), func(_box: Rect2i) -> bool: return true)
	if not library.is_empty():
		_raise(w, &"library", library, 0)
	for i: int in range(LECTURES):
		var front: int = 1 if posmod(Rules.level_seed(w.seed_for_colors, RISE_DEAL + i), 2) == 0 else -1
		var hall: Dictionary = _site(w, LECTURE_INSIDE, _lecture_doors(), func(_box: Rect2i) -> bool: return true, MIN_DOORS)
		if not hall.is_empty():
			_raise(w, &"lecture", hall, front)
	if not w.halls.is_empty():
		w.connect_caves()


## The doorways of a hall with a flat floor `inside` big: one through each side wall at its floor,
## as [side, row in the box from its top].
static func _flat_doors(inside: Vector2i) -> Array:
	return [[-1, inside.y], [1, inside.y]]


## A classroom's doorways: through each side wall at its floor and at its gallery.
static func _lecture_doors() -> Array:
	var gallery: int = LECTURE_INSIDE.y - GALLERY_UP - 1
	return [[-1, LECTURE_INSIDE.y], [1, LECTURE_INSIDE.y], [-1, gallery], [1, gallery]]


## Where a hall with an open box `inside` big and doorways `spec` (see _flat_doors) goes, its box
## passing `test`: {"box", "doors": [[the doorway, the passage's cells (both rows), the step
## out]...]}, the site walling over the least open air and needing the shortest passages, each
## doorway past `least` counting DOOR_WORTH for it, ties dealt by the seed; {} if none fits (no site
## with at least `least` doorways that find open air).
static func _site(w: LevelGen, inside: Vector2i, spec: Array, test: Callable, least: int = 1) -> Dictionary:
	var size: Vector2i = inside + Vector2i(2, 2)
	var blocked: Dictionary = _blocked(w)
	var open_sum: PackedInt32Array = Crypts._sums(w, func(v: Vector2i) -> bool: return not w.is_ground(v))
	var blocked_sum: PackedInt32Array = Crypts._sums(w, func(v: Vector2i) -> bool: return blocked.has(v))
	var best: Dictionary = {}
	var best_score: int = 1 << 30
	var best_tie: int = 0
	for x: int in range(1, w.size.x - size.x):
		for y: int in range(1, w.size.y - size.y):
			var box: Rect2i = Rect2i(Vector2i(x, y), size)
			if not test.call(box) or Crypts._count(w, blocked_sum, box.grow(APART)) > 0:
				continue
			var score: int = Crypts._count(w, open_sum, box)
			if score - DOOR_WORTH * (spec.size() - least) > best_score:
				continue
			var doors: Array = _doors(w, box, spec, blocked)
			if doors.size() < maxi(least, 1):
				continue
			if least > 1:
				score -= DOOR_WORTH * (doors.size() - least)
			for door: Array in doors:
				score += (door[1] as Array).size() * PASSAGE_COST
			var tie: int = Rules.level_seed(w.seed_for_colors, SITE_DEAL + x * 131 + y)
			if score < best_score or (score == best_score and tie < best_tie):
				best_score = score
				best_tie = tie
				best = {"box": box, "doors": doors}
	return best


## The cells a hall keeps away from: what is kept whole or clear, every structure, the other halls.
static func _blocked(w: LevelGen) -> Dictionary:
	var out: Dictionary = {}
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			var v: Vector2i = Vector2i(x, y)
			if w.kept(v) or w.keep_clear.has(v) or w.structures.has(v):
				out[v] = true
	return out


## The doorways a hall in `box` would have, as `spec` asks (see _flat_doors): each side's whose
## passage out reaches open air within DOOR_REACH, as [the doorway, the passage's cells (both
## rows), the step out (the open cell it meets)].
static func _doors(w: LevelGen, box: Rect2i, spec: Array, blocked: Dictionary) -> Array:
	var out: Array = []
	for door: Array in spec:
		var side: int = door[0]
		var y: int = box.position.y + int(door[1])
		var wall: int = box.position.x if side < 0 else box.end.x - 1
		var cut: Array[Vector2i] = []
		var step: Variant = null
		for k: int in range(1, DOOR_REACH + 1):
			var c: Vector2i = Vector2i(wall + side * k, y)
			if c.x < 1 or c.x >= w.size.x - 1 or blocked.has(c) or blocked.has(c + Vector2i.UP):
				break
			if not w.is_ground(c):
				step = c
				break
			cut.append(c)
			if y - 1 >= 1:
				cut.append(c + Vector2i.UP)
		if step != null:
			out.append([Vector2i(wall, y), cut, step])
	return out


## Build a hall of `kind` at `site` (from _site) into `w`, facing `front` (a classroom), and note it
## in LevelGen.halls.
static func _raise(w: LevelGen, kind: StringName, site: Dictionary, front: int) -> void:
	var box: Rect2i = site["box"]
	var inside: Rect2i = box.grow(-1)
	for x: int in range(box.position.x, box.end.x):
		for y: int in range(box.position.y, box.end.y):
			var v: Vector2i = Vector2i(x, y)
			if inside.has_point(v):
				_open_at(w, v)
				w.interiors[v] = true
			else:
				_rock_at(w, v)
				w.masonry[v] = true
	var doors: Array[Vector2i] = []
	var steps: Array[Vector2i] = []
	var passages: Array[Vector2i] = []
	for door: Array in site["doors"]:
		_open_at(w, door[0])
		w.masonry.erase(door[0])
		for c: Vector2i in door[1]:
			_open_at(w, c)
			passages.append(c)
		doors.append(door[0])
		steps.append(door[2])
	var hall: Dictionary = {"kind": kind, "box": box, "inside": inside, "doors": doors, "steps": steps, "floors": [], "front": front, "dept": &""}
	match kind:
		&"library":
			_stacks(w, inside)
		&"lecture":
			_gallery(w, inside)
			hall["dept"] = _deal_dept(w)
	for x: int in range(box.position.x, box.end.x):
		for y: int in range(box.position.y, box.end.y):
			w.kept_whole[Vector2i(x, y)] = true
			w.structures[Vector2i(x, y)] = &"hall"
			w.empties.erase(Vector2i(x, y))
	for c: Vector2i in passages:
		w.kept_whole[c] = true
		w.empties.erase(c)
		w.kept_whole[c + Vector2i.DOWN] = true
	for v: Vector2i in steps:
		w.kept_whole[v] = true
		w.kept_whole[v + Vector2i.DOWN] = true
	var floors: Array[Vector2i] = []
	for x: int in range(inside.position.x, inside.end.x):
		for y: int in range(inside.position.y, inside.end.y):
			var v: Vector2i = Vector2i(x, y)
			if not w.is_ground(v) and w.get_cell(v).type == LevelGen.Type.EMPTY and (w.is_ground(v + Vector2i.DOWN) or w.get_cell(v + Vector2i.DOWN).type == LevelGen.Type.PLATFORM):
				floors.append(v)
	hall["floors"] = floors
	w.halls.append(hall)
	# A hall with a class in it has a door in each doorway (ExamDoor), kept by the timetable.
	if kind in Timetable.TIMETABLED:
		for door: Vector2i in doors:
			w.put(door, LevelGen.Type.EXAM_DOOR, w.halls.size() - 1)


## The library's stacks in `inside`: a gallery of ledges every GALLERY rows up from its floor, all
## across but for a stair gap STAIR cells wide at one end (the lowest's end dealt by the seed, then
## taking turns), with a ledge under the gap in the top row of the storey below.
static func _stacks(w: LevelGen, inside: Rect2i) -> void:
	var bottom: int = inside.end.y - 1
	var left: bool = posmod(Rules.level_seed(w.seed_for_colors, GAP_DEAL), 2) == 0
	var g: int = bottom - (GALLERY - 1)
	while g > inside.position.y + 1:
		for x: int in range(inside.position.x, inside.end.x):
			var in_gap: bool = x < inside.position.x + STAIR if left else x >= inside.end.x - STAIR
			if in_gap:
				w.put(Vector2i(x, g + 1), LevelGen.Type.PLATFORM)
			else:
				w.put(Vector2i(x, g), LevelGen.Type.PLATFORM)
		left = not left
		g -= GALLERY


## The department of the next classroom raised in `w`: the first few take every department once, in an
## order dealt by the seed (so each department's prerequisites are taught somewhere in the level,
## Timetable.NEEDS), any after them one dealt by the seed.
static func _deal_dept(w: LevelGen) -> StringName:
	var depts: Array = DEPARTMENTS.keys()
	var k: int = w.halls.filter(func(h: Dictionary) -> bool: return h["kind"] == &"lecture").size()
	if k >= depts.size():
		return depts[posmod(Rules.level_seed(w.seed_for_colors, DEPT_DEAL + k), depts.size())]
	var order: Array = depts.duplicate()
	order.sort_custom(func(a: StringName, b: StringName) -> bool: return Rules.level_seed(w.seed_for_colors, DEPT_DEAL + depts.find(a)) < Rules.level_seed(w.seed_for_colors, DEPT_DEAL + depts.find(b)))
	return order[k]


## A classroom's gallery in `inside`: a row of one-way ledges all across it, GALLERY_UP rows over
## its floor.
static func _gallery(w: LevelGen, inside: Rect2i) -> void:
	var row: int = inside.end.y - 1 - GALLERY_UP
	for x: int in range(inside.position.x, inside.end.x):
		w.put(Vector2i(x, row), LevelGen.Type.PLATFORM)


## A classroom's floor row and its gallery's (where students stand), in `inside`.
static func gallery_row(inside: Rect2i) -> int:
	return inside.end.y - 2 - GALLERY_UP


## The beast's chamber in `w` (LevelGen.halls), or {} when it has none (every level but the beast's
## gate levels).
static func chamber(w: LevelGen) -> Dictionary:
	for hall: Dictionary in w.halls:
		if hall["kind"] == &"chamber":
			return hall
	return {}


## The hall of `w` whose box holds cell `v`, as its index in LevelGen.halls, or -1.
static func hall_at(w: LevelGen, v: Vector2i) -> int:
	for i: int in range(w.halls.size()):
		if (w.halls[i]["box"] as Rect2i).has_point(v):
			return i
	return -1


# ------------------------------------------------------------------ dressing

## Out in the level: the breaches abominations rise from, abominations already up and small classes
## out of their halls (see the consts). Their spots are drawn, as any archetype's dressing is. The way
## on stays where the level laid it.
static func populate(w: LevelGen, _def: NextWorldDef) -> void:
	var start: Vector2i = w.exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	var floors: Array[Vector2i] = w.free_floors()
	var breaches: Array[Vector2i] = w.pick_apart(floors.filter(func(v: Vector2i) -> bool: return LevelGen.dist(v, start) >= BREACH_CLEAR and not w._crowds_exit(v)), w.foes_per_area(BREACHES_PER_K), BREACH_APART)
	w.put_each(breaches, LevelGen.Type.BREACH)
	floors = w.free_floors()
	w.put_each(w.pick_apart(floors.filter(func(v: Vector2i) -> bool: return LevelGen.dist(v, start) >= ABOMINATION_CLEAR), w.foes_per_area(ABOMINATIONS_PER_K), 4), LevelGen.Type.ABOMINATION)
	floors = w.free_floors()
	var heads: Array[Vector2i] = w.pick_apart(floors.filter(func(v: Vector2i) -> bool: return LevelGen.dist(v, start) >= CLASS_CLEAR and not w._crowds_exit(v)), w.per_area(CLASSES_PER_K), CLASS_APART)
	for i: int in range(heads.size()):
		var head: Vector2i = heads[i]
		w.put(head, LevelGen.Type.MASTER, {"ability": mastery(w, head), "hall": -1})
		var near: Array[Vector2i] = w.free_floors().filter(func(v: Vector2i) -> bool: return LevelGen.dist(v, head) <= CLASS_REACH and v.y == head.y)
		var class_cells: Array[Vector2i] = w.pick_apart(near, roundi(float(CLASS) * Difficulty.foes()), 2, [head])
		for j: int in range(class_cells.size()):
			var kind: LevelGen.Type = LevelGen.Type.PROCTOR if j == 0 and i % PROCTOR_EVERY == 0 else LevelGen.Type.STUDENT
			w.put(class_cells[j], kind)


## The first classroom of department `dept` in `w` (its index in LevelGen.halls, the one holding the
## department's portal), or -1 for none.
static func first_of(w: LevelGen, dept: StringName) -> int:
	for i: int in range(w.halls.size()):
		if w.halls[i]["kind"] == &"lecture" and w.halls[i]["dept"] == dept:
			return i
	return -1


## What the master at `v` has mastered (MASTERIES), dealt by the level seed.
static func mastery(w: LevelGen, v: Vector2i) -> StringName:
	return MASTERIES[posmod(Rules.level_seed(w.seed_for_colors, MASTER_DEAL + v.x * 977 + v.y), MASTERIES.size())]


## Where a lecture hall of department `dept` in level `def` leads: a row of the band the department
## studies (DEPARTMENTS), dealt by the level seed and the hall's number `i`, in the same world.
static func department_row(def: NextWorldDef, dept: StringName, i: int) -> int:
	var band: StringName = DEPARTMENTS.get(dept, &"garden")
	var roll: int = posmod(Rules.level_seed(def.gen_seed, ROW_DEAL + i), 1000)
	if band == &"garden":
		var rows: int = NextWorldDef.GARDEN_ROWS * 2 + 1
		return roll % rows - NextWorldDef.GARDEN_ROWS
	return NextWorldDef.band_row(band, roll % NextWorldDef.BAND)


## Last of all (so nothing else in the level moves for them), what each hall holds, on its free
## floors, with no draws from the world RNG:
## - a classroom: its master on the floor before the lectern, its department's portal (Department)
##   against the lectern's wall in the first classroom of each department (the others' papers go
##   to the same place), and students on the gallery (a proctor among them in every other one);
## - the library: a librarian on its top gallery with HOARD stars, and a student on each gallery
##   below.
## Then the timetable's things (Timetable): a lectern (Lectern) and a bell's cord (SchoolBell) on each
## classroom's floor between its portal's place and its master, a cord on the library's floor, a
## glyph seal (GlyphSeal) just inside each doorway of the library (out in the level the
## cell outside may hold anything), asking for the spell Timetable.seal_of deals, and the great bell
## out in the corridors over its cord (see BELL_CLEAR).
static func furnish(w: LevelGen, def: NextWorldDef) -> void:
	for i: int in range(w.halls.size()):
		var hall: Dictionary = w.halls[i]
		var inside: Rect2i = hall["inside"]
		var bottom: int = inside.end.y - 1
		match hall["kind"]:
			&"lecture":
				var front: int = hall["front"]
				var wall: int = inside.position.x if front > 0 else inside.end.x - 1
				if first_of(w, hall["dept"]) == i:
					_place(w, Vector2i(wall + front, bottom), LevelGen.Type.DEPARTMENT, [hall["dept"], department_row(def, hall["dept"], i)])
				# Its master teaches the hall's subject now (Timetable.subject; Scholar.setup).
				var head: Vector2i = Vector2i(wall + front * 5, bottom)
				_place(w, head, LevelGen.Type.MASTER, {"ability": Timetable.subject(w, i, 0), "hall": i})
				var seats: int = gallery_row(inside)
				for k: int in range(SEATS.size()):
					var kind: LevelGen.Type = LevelGen.Type.PROCTOR if k == SEATS.size() - 1 and i % PROCTOR_EVERY == 0 else LevelGen.Type.STUDENT
					_place(w, Vector2i(wall + front * SEATS[k], seats), kind)
			&"library":
				var tops: Array[int] = []
				for v: Vector2i in hall["floors"]:
					if not tops.has(v.y):
						tops.append(v.y)
				tops.sort()
				if tops.is_empty():
					continue
				var top: Array[Vector2i] = (hall["floors"] as Array[Vector2i]).filter(func(v: Vector2i) -> bool: return v.y == tops[0])
				if not top.is_empty():
					@warning_ignore("integer_division")
					_place(w, top[top.size() / 2], LevelGen.Type.LIBRARIAN)
					for k: int in range(mini(HOARD, top.size())):
						_place(w, top[k], LevelGen.Type.COIN)
				for r: int in range(1, tops.size()):
					var row: Array[Vector2i] = (hall["floors"] as Array[Vector2i]).filter(func(v: Vector2i) -> bool: return v.y == tops[r] and w.get_cell(v).type == LevelGen.Type.EMPTY)
					if not row.is_empty():
						@warning_ignore("integer_division")
						_place(w, row[(row.size() * 2) / 3], LevelGen.Type.STUDENT)
	_timetable(w)


## The timetable's things in `w` (see furnish), last of all.
static func _timetable(w: LevelGen) -> void:
	if not Timetable.kept_in(w):
		return
	for i: int in range(w.halls.size()):
		var hall: Dictionary = w.halls[i]
		var inside: Rect2i = hall["inside"]
		var bottom: int = inside.end.y - 1
		match hall["kind"]:
			&"lecture":
				var front: int = hall["front"]
				var wall: int = inside.position.x if front > 0 else inside.end.x - 1
				_place(w, Vector2i(wall + front * 2, bottom), LevelGen.Type.LECTERN, i)
				_place(w, Vector2i(wall + front * 3, bottom), LevelGen.Type.SCHOOL_BELL, {"great": false})
			&"library":
				_place(w, Vector2i(inside.position.x + 2, bottom), LevelGen.Type.SCHOOL_BELL, {"great": false})
		var spell: StringName = Timetable.seal_of(w, i)
		if spell == &"":
			continue
		var box: Rect2i = hall["box"]
		for door: Vector2i in hall["doors"]:
			var inward: int = 1 if door.x == box.position.x else -1
			_place(w, door + Vector2i(inward, 0), LevelGen.Type.GLYPH_SEAL, spell)
	var start: Vector2i = w.exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	var out: Array[Vector2i] = w.free_floors().filter(func(v: Vector2i) -> bool: return hall_at(w, v) < 0 and LevelGen.dist(v, start) >= BELL_CLEAR and not w._crowds_exit(v))
	var roomy: Array[Vector2i] = out.filter(func(v: Vector2i) -> bool: return range(1, BELL_ROOM + 1).all(func(k: int) -> bool: return w.is_valid(v + Vector2i(0, -k)) and not w.is_ground(v + Vector2i(0, -k))))
	var spot: Variant = LevelGen.best_of(roomy if not roomy.is_empty() else out, func(v: Vector2i) -> float: return float(LevelGen.dist(v, start)))
	if spot != null:
		_place(w, spot, LevelGen.Type.SCHOOL_BELL, {"great": true})


## A `type` holding `extra` at `v`, if it is still free open air.
static func _place(w: LevelGen, v: Vector2i, type: LevelGen.Type, extra: Variant = null) -> void:
	if w.is_valid(v) and w.get_cell(v).type == LevelGen.Type.EMPTY:
		w.objects.append(v)
		w.empties.erase(v)
		w.set_kind(v, type, extra)


## Rock at `v`, inside the level's edge.
static func _rock_at(w: LevelGen, v: Vector2i) -> void:
	if w.is_valid(v) and not w.is_ground(v):
		w._to_rock(v)


## Open air at `v`, inside the level's edge.
static func _open_at(w: LevelGen, v: Vector2i) -> void:
	if w.is_valid(v) and w.get_cell(v).type != LevelGen.Type.EMPTY:
		w._to_open(v)
