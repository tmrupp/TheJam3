class_name Institute
extends RefCounted
## The institute's halls and who is in them (docs/REGIONS_PLAN.md §7). Its levels are collapsed from
## a sample of rooms and corridors (InstituteArchetype); right after the caves are joined, build sets
## its halls into them, buildings of pale marble (LevelGen.masonry) a cell thick all round, the air
## inside them printed over dark panelling (LevelGen.interiors):
## - the library's stacks (LIBRARY_INSIDE): galleries of ledges one over another, GALLERY rows apart,
##   each with a stair gap at one end (the ends taking turns up the stacks) and a ledge under the gap,
##   so each is climbed in two of the wizard's own hops; long sight lines for casters. Under its
##   lowest gallery its book ladders (BOOK_LADDERS) stand on its floor, rolling along the gallery.
## - classrooms, the lecture halls (LECTURE_INSIDE), up to LECTURES of them where they fit: small
##   rooms with a flat floor (the lectern at its front end, with the master and its department's
##   portal, Department) and a gallery of one-way ledges GALLERY_UP rows over it
##   where the students sit. Each has a doorway at each end of its floor and of its gallery where a
##   passage finds open air (at least MIN_DOORS), so a classroom is a way through, not a dead end.
## - in every level with one of those (a timetable, Timetable.kept_in), last of all, the bell room
##   (BELFRY_INSIDE): a little room of its own for the first of the great bells (SchoolBell), a
##   doorway at its floor through each side wall where a passage finds open air. It is no hall (it
##   is not in LevelGen.halls, and the timetable reads it as the corridors): its open box is kept in
##   LevelGen.belfry.
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
const LIBRARY_INSIDE: Vector2i = Vector2i(18, 8)
## How many rows the library's ground floor stands under its first gallery, room for its timetable
## board (TimetableBoard) on the back wall over its floor and desk.
const LIBRARY_GROUND: int = 4
## Where the library's things stand on its floor: its timetable board in the middle, its reading desk
## (StudyDesk) before the board's right end, this many cells right of its middle; bookcases fill the
## rest of the floor either side, floor to ceiling.
const DESK_OUT: int = 4
## The library's book ladders (RollingLadder): BOOK_LADDERS of them hanging from its lowest gallery's
## edge to its floor, side by side along the gallery from a cell past its stair gap, each rolling
## over BOOK_TRACK cells, a cell apart.
const BOOK_LADDERS: int = 2
const BOOK_TRACK: int = 6
const LECTURE_INSIDE: Vector2i = Vector2i(10, 5)
## The bell room's open box (cells across and down, not counting the walls).
const BELFRY_INSIDE: Vector2i = Vector2i(3, 4)
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

## The timetable's bell and its cords (SchoolBell): the one great bell hangs in the bell room
## (BELFRY_INSIDE), in the middle of its floor, its cord hanging from it; out in the corridors
## CORRIDOR_BELLS_PER_K cords per 1000 cells (at least CORRIDOR_BELLS_LEAST, the bell room's counted
## among them) run up into the ceiling to it, each over a free floor with BELL_ROOM open cells over
## it (else any free floor) at least BELL_CLEAR cells from the way in: the first the nearest to the
## way in in the stretch of corridors it opens on (regions; anywhere out of the halls if that has
## no such floor), so a wizard just come in can ring it, at least BELL_APART cells from the bell
## room's (none so, and the bell room's stands for it), and each other as far from those already
## hung as can be, at least BELL_APART cells. And a cord in each lecture hall and the library, up
## into the ceiling. (A level whose bell room found no site hangs the great bell over the first
## corridor cord instead.)
const BELL_CLEAR: int = 3
const BELL_ROOM: int = 3
const CORRIDOR_BELLS_PER_K: float = 0.4
const CORRIDOR_BELLS_LEAST: int = 2
const BELL_APART: int = 12
## The way on (Timetable.way_on_hall): in the classroom the most classrooms away from the way in
## (way_on), on its floor this many cells from its lectern's wall.
const WAY_ON_SEAT: int = 7

## Out in the level (populate), per 1000 cells: breaches abominations rise from (Breach), at least
## BREACH_CLEAR cells from the way in and BREACH_APART from one another; abominations already up;
## and small classes out of their halls (a master with CLASS students round it, within CLASS_REACH
## cells), CLASS_CLEAR from the way in and CLASS_APART from one another.
const BREACHES_PER_K: float = 0.5
const BREACH_CLEAR: int = 12
const BREACH_APART: int = 10
const ABOMINATIONS_PER_K: float = 0.25
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
	if Timetable.kept_in(w):
		var belfry: Dictionary = _site(w, BELFRY_INSIDE, _flat_doors(BELFRY_INSIDE), func(_box: Rect2i) -> bool: return true)
		if not belfry.is_empty():
			_raise(w, &"belfry", belfry, 0)
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
## in LevelGen.halls (the bell room, &"belfry", in LevelGen.belfry instead).
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
	if kind == &"belfry":
		w.belfry = inside
		return
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
## taking turns), with a ledge under the gap in the top row of the storey below; and its book ladders.
static func _stacks(w: LevelGen, inside: Rect2i) -> void:
	var bottom: int = inside.end.y - 1
	var left: bool = posmod(Rules.level_seed(w.seed_for_colors, GAP_DEAL), 2) == 0
	var g: int = bottom - LIBRARY_GROUND
	_book_ladders(w, inside, g, left)
	while g > inside.position.y + 1:
		for x: int in range(inside.position.x, inside.end.x):
			var in_gap: bool = x < inside.position.x + STAIR if left else x >= inside.end.x - STAIR
			if in_gap:
				w.put(Vector2i(x, g + 1), LevelGen.Type.PLATFORM)
			else:
				w.put(Vector2i(x, g), LevelGen.Type.PLATFORM)
		left = not left
		g -= GALLERY


## The library's book ladders in `inside` (see BOOK_LADDERS), under its lowest gallery at row `g`,
## whose stair gap is at its left end if `left`: each in the cell under the gallery's edge, its step
## level with the gallery (a rise of one cell), its foot on the floor.
static func _book_ladders(w: LevelGen, inside: Rect2i, g: int, left: bool) -> void:
	var from: int = inside.position.x + STAIR + 1 if left else inside.position.x
	var end: int = inside.end.x if left else inside.end.x - STAIR - 1
	for i: int in range(BOOK_LADDERS):
		var x: int = from + i * (BOOK_TRACK + 2)
		if x + BOOK_TRACK >= end:
			break
		w.put(Vector2i(x, g + 1), LevelGen.Type.ROLLING_LADDER, [1, Vector2i(1, 0), BOOK_TRACK, 1])


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


## The stretches of corridor in `w`: each open cell out of the classrooms, by the stretch it lies in
## (a number), joined through anything but rock and the classrooms' doors (locked doors, gates and
## glyph seals do not part them, so the stretches are the same before those are laid and after). A
## wizard gets from one stretch to another only through the classrooms.
static func regions(w: LevelGen) -> Dictionary:
	var walls: Array[LevelGen.Type] = [LevelGen.Type.GROUND, LevelGen.Type.EXAM_DOOR]
	var open: Callable = func(v: Vector2i) -> bool:
		if not w.is_valid(v) or w.get_cell(v).type in walls:
			return false
		var hall: int = hall_at(w, v)
		return hall < 0 or w.halls[hall]["kind"] != &"lecture"
	var out: Dictionary = {}
	var next: int = 0
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			var v: Vector2i = Vector2i(x, y)
			if out.has(v) or not open.call(v):
				continue
			var stack: Array[Vector2i] = [v]
			out[v] = next
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n: Vector2i = c + d
					if not out.has(n) and open.call(n):
						out[n] = next
						stack.append(n)
			next += 1
	return out


## The stretches of corridor (regions, `region`) classroom `hall` of `w` opens on.
static func opens_on(w: LevelGen, hall: int, region: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for step: Vector2i in w.halls[hall]["steps"]:
		if region.has(step) and not out.has(int(region[step])):
			out.append(int(region[step]))
	return out


## How far in each classroom of `w` is from cell `back`: the classrooms crossed to reach its doors
## through the corridors (regions), by its index in LevelGen.halls; classrooms never reached so are
## left out.
static func rooms_in(w: LevelGen, back: Vector2i) -> Dictionary:
	var region: Dictionary = regions(w)
	var crossed: Dictionary = {}
	if not region.has(back):
		return crossed
	var depth: Dictionary = {int(region[back]): 0}
	var frontier: Array[int] = [int(region[back])]
	while not frontier.is_empty():
		var later: Array[int] = []
		for g: int in frontier:
			for i: int in range(w.halls.size()):
				if w.halls[i]["kind"] != &"lecture" or crossed.has(i):
					continue
				var opens: Array[int] = opens_on(w, i, region)
				if not opens.has(g):
					continue
				crossed[i] = depth[g]
				for h: int in opens:
					if not depth.has(h):
						depth[h] = int(depth[g]) + 1
						later.append(h)
		frontier = later
	return crossed


## Where the way on stands in `w`, the way in at `back` (Timetable.way_on_hall): on the floor of the
## classroom the most classrooms in from the way in (rooms_in), the furthest from it of those,
## WAY_ON_SEAT cells from its lectern's wall; null for a level with no classroom reached so, or with
## the beast's chamber (its way on stays where it was laid). Nothing drawn: the level's layout
## decides it.
static func way_on(w: LevelGen, back: Vector2i) -> Variant:
	if not Timetable.kept_in(w) or not chamber(w).is_empty():
		return null
	var crossed: Dictionary = rooms_in(w, back)
	var best: int = -1
	var score: Callable = func(i: int) -> Vector2i:
		var off: Vector2i = (w.halls[i]["inside"] as Rect2i).get_center() - back
		return Vector2i(int(crossed[i]), off.x * off.x + off.y * off.y)
	for i: int in range(w.halls.size()):
		if crossed.has(i) and (best < 0 or score.call(i) > score.call(best)):
			best = i
	if best < 0:
		return null
	var hall: Dictionary = w.halls[best]
	var inside: Rect2i = hall["inside"]
	var front: int = hall["front"]
	var wall: int = inside.position.x if front > 0 else inside.end.x - 1
	return Vector2i(wall + front * WAY_ON_SEAT, inside.end.y - 1)


# ------------------------------------------------------------------ dressing

## Out in the level: the breaches abominations rise from, abominations already up and small classes
## out of their halls (see the consts). Their spots are drawn, as any archetype's dressing is. The
## level's relic, if it holds one, is carried by the master out in the level furthest from the way in.
static func populate(w: LevelGen, def: NextWorldDef) -> void:
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
	# The level's relic (Relics.at), carried by the master out in the level furthest from the way in
	# rather than laid in a secret room (LevelGen.relic_carrier): beaten, it leaves it (Scholar.relic).
	if def.relic != &"" and not heads.is_empty():
		var far: Vector2i = LevelGen.best_of(heads, func(v: Vector2i) -> float: return -float(LevelGen.dist(v, start)))
		(w.get_cell(far).extra_info as Dictionary)["relic"] = def.relic
		w.relic_carrier = far


## The first classroom of department `dept` in `w` (its index in LevelGen.halls, the one that deals
## where the department's portals lead), or -1 for none.
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
##   against the lectern's wall (every classroom of a department leading to the same level, the
##   one its first classroom deals), and students on the gallery (a proctor among them in every
##   other one);
## - the library: a librarian on its top gallery with HOARD stars, and a student on each gallery
##   below.
## Then the timetable's things (Timetable): a lectern (Lectern) and a bell's cord (SchoolBell) on each
## classroom's floor between its portal's place and its master; on the library's floor a cord at one
## end, its timetable board (TimetableBoard) in the middle on the back wall over it, and its reading
## desk (StudyDesk) before the board's right end; and the corridor bells over their cords (see BELL_CLEAR).
static func furnish(w: LevelGen, def: NextWorldDef) -> void:
	for i: int in range(w.halls.size()):
		var hall: Dictionary = w.halls[i]
		var inside: Rect2i = hall["inside"]
		var bottom: int = inside.end.y - 1
		match hall["kind"]:
			&"lecture":
				var front: int = hall["front"]
				var wall: int = inside.position.x if front > 0 else inside.end.x - 1
				# Every classroom has its department's portal, all of a department's leading to the
				# level its first classroom's deals.
				_place(w, Vector2i(wall + front, bottom), LevelGen.Type.DEPARTMENT, [hall["dept"], department_row(def, hall["dept"], first_of(w, hall["dept"]))])
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
				@warning_ignore("integer_division")
				_place(w, Vector2i(inside.position.x + inside.size.x / 2, bottom), LevelGen.Type.TIMETABLE_BOARD)
				@warning_ignore("integer_division")
				_place(w, Vector2i(inside.position.x + inside.size.x / 2 + DESK_OUT, bottom), LevelGen.Type.STUDY_DESK)
	var start: Vector2i = w.exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	var out: Array[Vector2i] = w.free_floors().filter(func(v: Vector2i) -> bool: return hall_at(w, v) < 0 and LevelGen.dist(v, start) >= BELL_CLEAR and not w._crowds_exit(v))
	var roomy_of: Callable = func(spots: Array[Vector2i]) -> Array[Vector2i]:
		var roomy: Array[Vector2i] = spots.filter(func(v: Vector2i) -> bool: return range(1, BELL_ROOM + 1).all(func(k: int) -> bool: return w.is_valid(v + Vector2i(0, -k)) and not w.is_ground(v + Vector2i(0, -k))))
		return roomy if not roomy.is_empty() else spots
	# The first nearest the way in, in the corridors it opens on.
	var region: Dictionary = regions(w)
	var near: Array[Vector2i] = out.filter(func(v: Vector2i) -> bool: return region.has(start) and region.get(v, -1) == region[start])
	var bells: Array[Vector2i] = []
	# The bell room's in the middle of its floor, counted among them.
	if w.belfry.has_area():
		@warning_ignore("integer_division")
		var room: Vector2i = Vector2i(w.belfry.position.x + w.belfry.size.x / 2, w.belfry.end.y - 1)
		_place(w, room, LevelGen.Type.SCHOOL_BELL, {"great": true})
		bells.append(room)
	var apart: Callable = func(v: Vector2i) -> int:
		var least: int = 1 << 20
		for b: Vector2i in bells:
			least = mini(least, LevelGen.dist(v, b))
		return least
	# (At least BELL_APART from the bell room's; none so, and the bell room's stands for it.)
	var first: Variant = LevelGen.best_of(roomy_of.call(near if not near.is_empty() else out), func(v: Vector2i) -> float: return float(LevelGen.dist(v, start)), func(v: Vector2i) -> bool: return apart.call(v) >= BELL_APART)
	if first == null and bells.is_empty():
		return
	if first != null:
		bells.append(first)
	# The rest each as far from those already hung as can be, at least BELL_APART from them.
	var pool: Array[Vector2i] = roomy_of.call(out)
	while bells.size() < maxi(CORRIDOR_BELLS_LEAST, w.per_area(CORRIDOR_BELLS_PER_K)):
		var next: Variant = LevelGen.best_of(pool, func(v: Vector2i) -> float: return -float(apart.call(v)), func(v: Vector2i) -> bool: return apart.call(v) >= BELL_APART)
		if next == null:
			break
		bells.append(next)
	for k: int in range(bells.size()):
		var v: Vector2i = bells[k]
		if w.get_cell(v).type != LevelGen.Type.SCHOOL_BELL:
			# Only the bell room holds the great bell (or, with no bell room, the first of these).
			_place(w, v, LevelGen.Type.SCHOOL_BELL, {"great": k == 0})


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
