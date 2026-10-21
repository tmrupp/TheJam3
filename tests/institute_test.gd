extends TestKit
## The institute (docs/REGIONS_PLAN.md §7; Institute, Scholar, Abomination, Breach, ExamDoor, Lesson,
## Department, WayBack). Laid out: its halls of marble (no exam hall: the way on stays where the level
## laid it; the library's stacks, galleries of ledges, its book ladders under the lowest standing on
## its floor;
## classrooms, a floor and a gallery over it with a doorway at two ends at least, a class in each and
## a department's portal in the first of each department), nothing else laid in them, and the bell
## room, walled in marble with its great bell inside; breaches and classes out in the level, the same
## every build. In play: students cast bolts, some misfiring, the same way every time; each master casts
## its spell; a proctor shields the students round it; a librarian's hush silences the wizard's
## spells; abominations and scholars wound one another; a breach lets abominations out (up out of
## its crack, their feet on its floor) while the
## wizard is near; and a department's portal leads to a level of its band in the same world, with a way back that
## closes once used.
## godot --headless --path . --script res://tests/institute_test.gd

## The institute's levels laid out here: rows into its band (NextWorldDef.band_row), by world.
const LAID: Array[Vector2i] = [Vector2i(28, 0), Vector2i(28, 2), Vector2i(7, 4), Vector2i(99, 5)]
## What may be laid inside a hall.
const IN_HALLS: Array[LevelGen.Type] = [LevelGen.Type.EXAM_DOOR, LevelGen.Type.EXIT, LevelGen.Type.MASTER, LevelGen.Type.STUDENT,
	LevelGen.Type.PROCTOR, LevelGen.Type.LIBRARIAN, LevelGen.Type.DEPARTMENT, LevelGen.Type.PLATFORM, LevelGen.Type.COIN, LevelGen.Type.BOSS,
	LevelGen.Type.SCHOOL_BELL, LevelGen.Type.LECTERN, LevelGen.Type.STUDY_DESK, LevelGen.Type.TIMETABLE_BOARD, LevelGen.Type.ROLLING_LADDER]


func run() -> void:
	MapInfo.debug = false
	generation()
	await play()
	RunState.delete_save()
	finish()


# ------------------------------------------------------------------ laid out

func generation() -> void:
	print("laid out")
	var libraries: int = 0
	var lectures: int = 0
	var doors_ok: bool = true
	var kept: bool = true
	var tiers_ok: bool = true
	var book_ladders: bool = true
	var belfries: int = 0
	var belfry_ok: bool = true
	var stacks_ok: bool = true
	var depts_ok: bool = true
	var outside: int = 0
	var kits: Dictionary = {}
	var kits_placed: bool = true
	for place: Vector2i in LAID:
		var at: Vector2i = Vector2i(place.x, NextWorldDef.band_row(&"institute", place.y))
		var w: LevelGen = build(at)
		check(w != null, "%s collapses" % at)
		if w == null:
			continue
		var again: LevelGen = build(at)
		check(again != null and w.objects == again.objects and w.halls.size() == again.halls.size(), "%s: laid out the same twice" % at)
		for i: int in range(w.halls.size()):
			var hall: Dictionary = w.halls[i]
			var box: Rect2i = hall["box"]
			var inside: Rect2i = hall["inside"]
			var doors: Array = hall["doors"]
			# Walls of marble all round but for the doorways.
			for x: int in range(box.position.x, box.end.x):
				for y: int in range(box.position.y, box.end.y):
					var v: Vector2i = Vector2i(x, y)
					if not inside.has_point(v) and not doors.has(v) and not (w.is_ground(v) and w.masonry.has(v)):
						kept = false
					var type: LevelGen.Type = w.get_cell(v).type
					if w.objects.has(v) and not type in IN_HALLS:
						kept = false
			if doors.is_empty():
				doors_ok = false
			match hall["kind"]:
				&"library":
					libraries += 1
					var rows: Dictionary = {}
					for v: Vector2i in hall["floors"]:
						rows[v.y] = true
					if rows.size() < 3 or w.objects_of(LevelGen.Type.PLATFORM).filter(func(v: Vector2i) -> bool: return inside.has_point(v)).size() < inside.size.x:
						stacks_ok = false
					if w.objects_of(LevelGen.Type.LIBRARIAN).filter(func(v: Vector2i) -> bool: return inside.has_point(v)).is_empty():
						stacks_ok = false
					# Its book ladders, each hanging from the lowest gallery to the floor.
					var ladders: Array[Vector2i] = w.objects_of(LevelGen.Type.ROLLING_LADDER).filter(func(v: Vector2i) -> bool: return inside.has_point(v))
					if ladders.size() != Institute.BOOK_LADDERS:
						book_ladders = false
					for v: Vector2i in ladders:
						var extra: Array = w.get_cell(v).extra_info
						var foot: int = v.y + RollingLadder.hang(w, v, 1, int(extra[2]))
						if foot != inside.end.y or w.get_cell(v + Vector2i.UP).type != LevelGen.Type.PLATFORM:
							book_ladders = false
				&"lecture":
					lectures += 1
					var heights: Dictionary = {}
					for v: Vector2i in hall["floors"]:
						heights[v.y] = true
					if heights.size() != 2 or not heights.has(Institute.gallery_row(inside)) or doors.size() < Institute.MIN_DOORS:
						tiers_ok = false
					# Every classroom has its department's portal, all of a department's leading to
					# the same level.
					var portals: Array[Vector2i] = w.objects_of(LevelGen.Type.DEPARTMENT).filter(func(v: Vector2i) -> bool: return inside.has_point(v))
					if portals.size() != 1:
						depts_ok = false
					else:
						var extra: Array = w.get_cell(portals[0]).extra_info
						var dept_row: int = int(extra[1])
						if StringName(extra[0]) != hall["dept"] or NextWorldDef.archetype_at(dept_row) != Institute.DEPARTMENTS[hall["dept"]] or dept_row != Institute.department_row(Rules.def_for(at), hall["dept"], Institute.first_of(w, hall["dept"])):
							depts_ok = false
		# The bell room: walled in marble but for its doorways, its great bell on its floor.
		if w.belfry.has_area():
			belfries += 1
			var room: Rect2i = w.belfry.grow(1)
			for x: int in range(room.position.x, room.end.x):
				for y: int in range(room.position.y, room.end.y):
					var v: Vector2i = Vector2i(x, y)
					if not w.belfry.has_point(v) and w.is_ground(v) != w.masonry.has(v):
						belfry_ok = false
			var bells: Array[Vector2i] = w.objects_of(LevelGen.Type.SCHOOL_BELL).filter(func(v: Vector2i) -> bool: return w.belfry.has_point(v))
			belfry_ok = belfry_ok and bells.size() == 1 and bool((w.get_cell(bells[0]).extra_info as Dictionary)["great"]) and bells[0].y == w.belfry.end.y - 1
			belfry_ok = belfry_ok and Institute.hall_at(w, w.belfry.position) < 0
		outside += count_of(w, LevelGen.Type.BREACH) + count_of(w, LevelGen.Type.ABOMINATION)
		# Its decor: alchemy equipment in laboratories, ritual equipment in sanctums, out in its rooms.
		var solid: Dictionary = {}
		for x: int in range(w.size.x):
			for y: int in range(w.size.y):
				if w.is_ground(Vector2i(x, y)):
					solid[Vector2i(x, y)] = true
		var occupied: Dictionary = {}
		for v: Vector2i in w.objects:
			occupied[v] = true
		var decor_seed: int = Rules.level_seed(at.x, at.y)
		for item: Dictionary in RisoDecor.plan_institute(solid, occupied, decor_seed, Rect2i(Vector2i.ZERO, w.size), &"roots", w.masonry, w.interiors):
			var kind: StringName = item["kind"]
			if kind == &"alchemy" or kind == &"ritual":
				kits[kind] = true
				if RisoDecor.room_use(decor_seed, item["cell"]) != kind or w.interiors.has(item["cell"]):
					kits_placed = false
	check(doors_ok, "every hall has a doorway")
	check(libraries >= LAID.size() - 1 and stacks_ok, "a library: galleries of ledges, rows of floor over one another, its librarian")
	check(libraries > 0 and book_ladders, "every library has its %d book ladders, from its lowest gallery down to its floor" % Institute.BOOK_LADDERS)
	check(belfries == LAID.size() and belfry_ok, "a bell room in each level (%d of %d), walled in marble, its great bell inside it" % [belfries, LAID.size()])
	check(lectures >= LAID.size() * 3 and tiers_ok, "classrooms (%d in %d levels): a floor and a gallery, with %d doorways or more" % [lectures, LAID.size(), Institute.MIN_DOORS])
	check(depts_ok, "every classroom with its department's portal, all of a department's leading to the same level of the band it studies")
	check(kept, "walled in marble, and nothing else laid inside them")
	check(outside > 0, "breaches and abominations out in the level")
	check(kits.has(&"alchemy") and kits.has(&"ritual"), "laboratories hold alchemy equipment, and sanctums ritual equipment")
	check(kits_placed, "each only in its own kind of room, out of the halls")
	var gate: LevelGen = build(Vector2i(28, Bosses.row_of(&"beast")))
	check(gate != null and not Institute.chamber(gate).is_empty() and count_of(gate, LevelGen.Type.BOSS) == 1, "the beast's gate level has its chamber and its boss")


# ------------------------------------------------------------------ in play

func play() -> void:
	await boot()
	await _go(Vector2i(28, NextWorldDef.first_depth(&"institute")))
	player.set_physics_process(false)
	print("in play")
	check(placed("student.tscn").size() > 0 and placed("master.tscn").size() > 0 and placed("exam_door.tscn").size() > 0, "students, masters and hall doors are there")
	# A class under way: the corridors are no place for the wizard.
	info.record().passing = false
	await _students()
	await _hop()
	await _climb()
	info.record().passing = false
	await _apart()
	info.record().passing = false
	await _masters()
	await _staff()
	await _three_sides()
	await _department()


## A student's bolts, at the wizard: cast after a wind-up; some misfire, the same every time.
func _students() -> void:
	print("students")
	var spot: Vector2i = _open_floor()
	var s: Scholar = _spawn("student.tscn", spot + Vector2i(3, 0))
	player.global_position = info.cell_position(spot)
	var cast: bool = await within(func() -> bool: return s.casts > 0, Scholar.STUDENT_EVERY + 2.0)
	check(cast, "a student that sees the wizard casts at them")
	var fired: bool = s.misfired or info.map_elements.get_children().any(func(n: Node) -> bool: return n is Bullet and (n as Bullet).spell == &"student")
	check(fired, "a bolt, or a misfire")
	var rolls: Array[bool] = []
	for k: int in range(1, 41):
		rolls.append(RisoDecor.h(Scholar.MISFIRE_DEAL + k, spot, k) < Scholar.MISFIRE)
	var misfires: int = rolls.count(true)
	check(misfires > 0 and misfires < 40, "of forty casts, %d misfire" % misfires)
	s.queue_free()
	_clear_shots()


## A scholar walking up a step a cell high hops it: its figure (ScholarArt) rises and falls with its
## body through the hop, never jumping a cell at once (it was held on the floor it left until its
## body was a cell up, so it seemed to blink up the step).
func _hop() -> void:
	print("a hop up a step")
	var w: LevelGen = info.world
	var step: Variant = null
	for v: Vector2i in w.free_floors():
		# Its headroom inside the level, not off its edge.
		if v.y < 3:
			continue
		var r: Vector2i = v + Vector2i.RIGHT
		var open: bool = not w.is_ground(v + Vector2i.UP) and not w.is_ground(v + Vector2i(0, -2)) and not w.is_ground(r + Vector2i.UP) and not w.is_ground(r + Vector2i(0, -2))
		if w.is_ground(r) and open and not w.is_ground(v + Vector2i.LEFT) and w.is_ground(v + Vector2i(-1, 1)) and Institute.hall_at(w, v) < 0:
			step = v
			break
	if step == null:
		print("no step to hop here")
		return
	var at: Vector2i = step
	var s: Scholar = _spawn("student.tscn", at + Vector2i(-1, 0))
	# Nothing to fight, and its place past the step: it walks there.
	s.home_x = info.cell_position(at + Vector2i(3, -1)).x
	s.look_in = 999.0
	# Dressed in its art a moment after it is placed.
	var art: ScholarArt = null
	for k: int in range(10):
		await process_frame
		for c: Node in s.get_children():
			if c is ScholarArt:
				art = c as ScholarArt
		if art != null:
			break
	check(art != null, "its figure is there")
	if art == null:
		s.queue_free()
		return
	# Measured from the floor it lands on (it is placed mid-cell, and drops to its floor first).
	await until(func() -> bool: return s.grounded)
	var feet: float = s.global_position.y + art._feet()
	var start: float = feet
	var leap: float = 0.0
	for i: int in range(240):
		await physics_frame
		var now: float = s.global_position.y + art._feet()
		leap = maxf(leap, absf(now - feet))
		feet = now
	check(start - feet > 100.0, "it climbed the step (%.0f px)" % (start - feet))
	check(leap < 24.0, "its figure rose with its body, never jumping (at most %.0f px a frame)" % leap)
	s.queue_free()
	await frames(2)


## An abomination after its quarry hops a step a cell high, but at a wall two cells high (or more)
## it waits, facing it, rather than leaping at it again and again.
func _climb() -> void:
	print("an abomination at a step and a wall")
	var home: Vector2i = info.coord
	var found: Dictionary = _step_and_wall()
	# Not every level has both: look in the band's next levels.
	for k: int in range(1, 4):
		if not found.is_empty():
			break
		await _go(Vector2i(home.x, NextWorldDef.band_row(&"institute", k)))
		player.set_physics_process(false)
		found = _step_and_wall()
	check(not found.is_empty(), "a step and a wall to try")
	if not found.is_empty():
		await _climb_at(found["step"], found["step_way"], found["wall"], found["wall_way"])
	if info.coord != home:
		await _go(home)
		player.set_physics_process(false)


## A step a cell high and a wall two cells high (or more) out of the halls, each with a floor before it
## and the way up (+1 right, -1 left): {"step", "step_way", "wall", "wall_way"}, or {} if the level
## lacks either.
func _step_and_wall() -> Dictionary:
	var w: LevelGen = info.world
	var out: Dictionary = {}
	for v: Vector2i in w.free_floors():
		for way: int in [1, -1]:
			var r: Vector2i = v + Vector2i(way, 0)
			if Institute.hall_at(w, v) >= 0 or w.is_ground(v + Vector2i.UP) or w.is_ground(v + Vector2i(0, -2)) or w.is_ground(v - Vector2i(way, 0)) or not w.is_ground(v + Vector2i(-way, 1)) or not w.is_ground(r):
				continue
			if not out.has("step") and not w.is_ground(r + Vector2i.UP) and not w.is_ground(r + Vector2i(0, -2)):
				out["step"] = v
				out["step_way"] = way
			elif not out.has("wall") and w.is_ground(r + Vector2i.UP) and w.is_ground(r + Vector2i(0, -2)):
				out["wall"] = v
				out["wall_way"] = way
	return out if out.has("step") and out.has("wall") else {}


## An abomination after its quarry up the step at `step` (rising the way `step_way` points), then at
## the wall at `wall` (`wall_way`).
func _climb_at(step: Vector2i, step_way: int, wall: Vector2i, wall_way: int) -> void:
	# In passing time, when the abominations act up (Timetable), with no scholar about to fight them.
	info.record().passing = true
	for n: Node in get_nodes_in_group(&"scholar"):
		var at: Vector2 = (n as Node2D).global_position
		if at.distance_to(info.cell_position(step)) < 1500.0 or at.distance_to(info.cell_position(wall)) < 1500.0:
			n.queue_free()
	await frames(2)
	var thing: Abomination = _spawn_thing(step + Vector2i(-step_way, 0), 1)
	player.global_position = info.cell_position(step + Vector2i(4 * step_way, -1))
	await until(func() -> bool: return thing.grounded)
	var start: float = thing.global_position.y
	var climbed: bool = await within(func() -> bool: return thing.global_position.y < start - 100.0, 4.0)
	check(climbed and thing.quarry != null, "at a step a cell high, it hops up after its quarry")
	thing.queue_free()
	var d: float = float(wall_way)
	thing = _spawn_thing(wall + Vector2i(-wall_way, 0), 1)
	player.global_position = info.cell_position(wall + Vector2i(3 * wall_way, -2))
	await until(func() -> bool: return thing.grounded)
	var airborne: int = 0
	for i: int in range(180):
		await physics_frame
		if not thing.grounded:
			airborne += 1
	var at_wall: float = info.cell_position(wall).x
	check(thing.quarry != null and (thing.quarry.global_position.x - thing.global_position.x) * d > 0.0 and thing.facing * d > 0.0 and thing.global_position.x * d > at_wall * d - 40.0, "at a wall two cells high, its quarry beyond, it goes up to it and waits facing it")
	check(airborne == 0, "and never leaps at it")
	thing.queue_free()
	player.health.health = player.health.max_health
	await frames(2)


## Abominations keep apart, as wisps do: two made on the same spot ease apart along the floor, and
## one going after the wizard behind another waits behind it rather than piling into it.
func _apart() -> void:
	print("abominations keep apart")
	# In passing time, when the abominations act up (Timetable).
	info.record().passing = true
	var at: Vector2i = _open_floor()
	# Nothing else about to get in the way: no scholar to fight them, no other foe on the floor.
	var here: Vector2 = info.cell_position(at + Vector2i(3, 0))
	for n: Node in info.map_elements.get_children():
		var foe: Node2D = n as Node2D
		if foe != null and (n is Scholar or n is Abomination or (n.has_meta(&"cell") and Placeables.has_flag(info.world.get_cell(n.get_meta(&"cell")).type, &"enemy"))) and foe.global_position.distance_to(here) < 1200.0:
			n.queue_free()
	await frames(2)
	var a: Abomination = _spawn_thing(at + Vector2i(2, 0), 1)
	var b: Abomination = _spawn_thing(at + Vector2i(2, 0), 1)
	player.phasing = true
	await until(func() -> bool: return a.grounded and b.grounded)
	var keep: float = (a.layout[0].z + b.layout[0].z) * Abomination.APART
	var blob: Vector3 = a.lobe_at(0)
	var round_blob: Rect2 = Rect2(a.global_position + Vector2(blob.x * a.facing - blob.z, blob.y + Abomination.FEET - blob.z), Vector2(blob.z, blob.z) * 2.0)
	check(SpellStrike.body_of(a).grow(1.0).encloses(round_blob), "an abomination's touch, and where it is struck, cover its blobs")
	check(await within(func() -> bool: return absf(a.global_position.x - b.global_position.x) >= keep * 0.9, 2.0), "two on one spot ease apart (%.0f px, keeping %.0f)" % [absf(a.global_position.x - b.global_position.x), keep])
	# After the wizard, off past another held still on the floor: it comes up behind it and stops.
	a.global_position = info.cell_position(at + Vector2i(3, 0))
	a.set_physics_process(false)
	b.global_position = info.cell_position(at)
	player.phasing = false
	player.global_position = info.cell_position(at + Vector2i(5, 0))
	var nearest: float = INF
	for i: int in range(360):
		await physics_frame
		if a.grounded and b.grounded and absf(a.global_position.y - b.global_position.y) < Abomination.SAME_FLOOR:
			nearest = minf(nearest, absf(a.global_position.x - b.global_position.x))
	check(nearest >= keep * 0.85 and nearest < keep * 1.5, "following another, it comes up behind it and waits there rather than piling in (at nearest %.0f px)" % nearest)
	a.queue_free()
	b.queue_free()
	player.health.health = player.health.max_health
	await frames(2)


## Each master casts its spell at the wizard: a bolt for hex and seeker (the seeker turning after
## them) that strikes them, and the rest up close, hurting them.
func _masters() -> void:
	print("masters")
	var spot: Vector2i = _open_floor()
	for a: StringName in Institute.MASTERIES:
		player.global_position = info.cell_position(spot)
		player.end_invulnerable()
		var m: Scholar = _spawn("master.tscn", spot + Vector2i(1 if a in [&"slash", &"nova", &"push"] else 3, 0), a)
		m.cast_in = 0.0
		var hp: int = player.health.health
		var done: bool = await within(func() -> bool: return m.casts > 0, Scholar.MASTER_WIND + 2.0)
		await frames(3)
		match a:
			&"hex", &"seeker":
				var shots: Array[Node] = info.map_elements.get_children().filter(func(n: Node) -> bool: return n is Bullet and (n as Bullet).spell == a)
				check(done and not shots.is_empty() and ((shots[0] as Bullet).homing != null) == (a == &"seeker"), "a %s master casts its bolt" % a)
				# Aimed at the middle of the wizard's body: once aimed over it, a bolt flew clean over
				# their head.
				var hit: bool = await within(func() -> bool: return player.health.health < hp, 3.0)
				check(hit, "a %s master's bolt strikes the wizard" % a)
			&"lunge":
				check(done, "a lunge master lunges along its floor")
			_:
				check(done and player.health.health < hp, "a %s master's spell hurts the wizard up close" % a)
		player.health.health = player.health.max_health
		m.queue_free()
		_clear_shots()
		await frames(2)


## A proctor shields the students round it; a librarian's hush, pulsing, silences the wizard's spells
## while it is up.
func _staff() -> void:
	print("staff")
	var spot: Vector2i = _open_floor()
	player.global_position = info.cell_position(spot) + Vector2(-2000, 0)
	var proctor: Scholar = _spawn("proctor.tscn", spot)
	var student: Scholar = _spawn("student.tscn", spot + Vector2i(2, 0))
	proctor.cast_in = 0.2
	check(await within(func() -> bool: return Shield.of(student) != null, 2.0), "a proctor shields a student near it")
	proctor.queue_free()
	student.queue_free()
	var librarian: Scholar = _spawn("librarian.tscn", spot)
	player.global_position = info.cell_position(spot) + Vector2(-120, 0)
	# Just after a pulse falls.
	await physics_frame
	librarian.hush_t = 0.05
	player.set_physics_process(true)
	await frames(3)
	check(not librarian.hush_up(), "a librarian's hush pulses: down for a while")
	check(await within(func() -> bool: return not player.is_drowsy(), 1.0), "and while it is down the wizard beside it is not drowsy")
	# On to just before it rises.
	librarian.hush_t = Scholar.HUSH_EVERY - Scholar.HUSH_ON - 0.1
	check(await within(func() -> bool: return librarian.hush_up(), 1.0), "then it rises")
	check(await within(func() -> bool: return player.is_drowsy(), 1.0), "and in it the wizard is drowsy, their spells silenced")
	player.set_physics_process(false)
	librarian.queue_free()
	await frames(2)
	player.set_physics_process(true)
	check(await within(func() -> bool: return not player.is_drowsy(), 1.0), "and out of it, not")
	player.set_physics_process(false)
	await frames(2)


## Abominations and scholars wound one another; a breach lets them out while the wizard is near.
func _three_sides() -> void:
	print("three sides")
	# In passing time, when the abominations act up (Timetable).
	info.record().passing = true
	var spot: Vector2i = _open_floor()
	player.global_position = info.cell_position(spot) + Vector2(0, -6000)
	player.phasing = true
	var student: Scholar = _spawn("student.tscn", spot)
	var thing: Abomination = _spawn_thing(spot + Vector2i(1, 0))
	var hp: int = (student.get_node("Wound") as Wound).hp
	check(await within(func() -> bool: return not is_instance_valid(student) or (student.get_node("Wound") as Wound).hp < hp, Abomination.BITE_EVERY * 3.0), "an abomination bites a student")
	if is_instance_valid(student):
		student.queue_free()
	if is_instance_valid(thing):
		thing.queue_free()
	await frames(2)
	var caster: Scholar = _spawn("student.tscn", spot)
	var prey: Abomination = _spawn_thing(spot + Vector2i(4, 0))
	prey.set_physics_process(false)
	var prey_hp: int = (prey.get_node("Wound") as Wound).hp
	check(await within(func() -> bool: return not is_instance_valid(prey) or (prey.get_node("Wound") as Wound).hp < prey_hp, Scholar.STUDENT_EVERY * 4.0), "a student's bolts wound an abomination")
	if is_instance_valid(prey):
		prey.queue_free()
	caster.queue_free()
	_clear_shots()
	var breaches: Array[Node] = placed("breach.tscn")
	check(not breaches.is_empty(), "breaches in the level")
	if breaches.is_empty():
		return
	var breach: Breach = breaches[0] as Breach
	var before: int = get_nodes_in_group(&"abomination").size()
	player.global_position = breach.global_position + Vector2(-300, 0)
	check(await within(func() -> bool: return breach.brood.size() > 0, Breach.FIRST + Breach.SURGE + 1.0), "with the wizard near, a breach lets an abomination out")
	check(breach.brood.all(func(n: Node2D) -> bool: return n.is_in_group(&"abomination")) and before >= 0, "and it is about, an abomination like any")
	var floor_y: float = breach.global_position.y + float(info.tile_map.tile_set.tile_size.y) * info.tile_map.global_scale.y * 0.5
	check(not breach.brood.is_empty() and absf(breach.brood[0].global_position.y + Abomination.FEET - floor_y) < 6.0, "coming up out of the crack, its feet on the floor, not over it")
	for n: Node2D in breach.brood:
		n.queue_free()
	await frames(2)
	print("multiplying")
	var first: Abomination = _spawn_thing(spot, 1)
	var count: Callable = func() -> int: return get_nodes_in_group(&"abomination").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size()
	check(first.lobes == 1, "one out of a breach starts as a single blob")
	check(await within(func() -> bool: return is_instance_valid(first) and first.lobes > 1, Abomination.GROW_EVERY * (1.0 + Abomination.GROW_SPREAD) / info.surge() + 1.0), "left alone, it grows another")
	var wound: Wound = first.get_node("Wound") as Wound
	var lobes: int = first.lobes
	wound.hit(1, Vector2.UP)
	await physics_frame
	check_eq(first.lobes, lobes - 1, "a wound bursts one blob")
	check(Abomination.LAUNCH_EVERY > Abomination.GROW_EVERY, "it launches less often than it grows")
	wound.hp = Abomination.SPLIT - 1
	await physics_frame
	first.grow()
	first.grow()
	check_eq(first.lobes, Abomination.SPLIT, "it grows no further than %d blobs" % Abomination.SPLIT)
	first.grow_in = 99.0
	first.launch_in = 0.0
	check(await within(func() -> bool: return first.tell() >= 0.0, 0.5), "at %d, its launch come round, it braces: the tell" % Abomination.SPLIT)
	check(first.lobes == Abomination.SPLIT, "nothing launched during the tell")
	check(await within(func() -> bool: return first.lobes < Abomination.SPLIT, Abomination.TELL + 0.5), "then it launches its top blob")
	check(first.lobes == Abomination.SPLIT - 1 and first.launch_in > Abomination.GROW_EVERY, "one blob fewer, its next launch a long way off")
	var flown: Array[Node] = get_nodes_in_group(&"abomination").filter(func(n: Node) -> bool: return n != first and not n.has_meta(&"cell") and (n as Abomination).flying())
	check(flown.size() == 1 and (flown[0] as Abomination).lobes == 1, "a single blob, in flight")
	if flown.size() == 1:
		var blob: Abomination = flown[0] as Abomination
		var from: Vector2 = blob.flight[0]
		var to: Vector2 = blob.flight[2]
		var heights: Array[float] = []
		var landed: Callable = func() -> bool:
			heights.append(blob.global_position.y)
			return not blob.flying()
		check(await within(landed, Abomination.FLIGHT + 0.5), "it flies its arc and lands")
		var top: float = heights.min()
		check(top < minf(from.y, to.y) - Abomination.ARC * 0.8, "rising over both ends on the way (%.0f px over the higher)" % (minf(from.y, to.y) - top))
		check(blob.lobes == 1 and blob.grounded, "landed, a one-blob abomination on the floor")
	wound.hp = Abomination.SPLIT - 1
	for i: int in range(Abomination.MOST + 4):
		wound.hp = Abomination.SPLIT
		first.lobes = wound.hp
		first.shed()
	await frames(2)
	check(count.call() <= Abomination.MOST, "but never more than %d about in a level" % Abomination.MOST)
	for n: Node in get_nodes_in_group(&"abomination"):
		if not n.has_meta(&"cell"):
			n.queue_free()
	await frames(2)
	print("slime")
	player.phasing = false
	player.global_position = info.cell_position(spot + Vector2i(4, 0))
	var crawler: Abomination = _spawn_thing(spot, 2)
	crawler.grow_in = 99.0
	check(await within(func() -> bool: return crawler.slime != null and is_instance_valid(crawler.slime) and crawler.slime.smears.size() >= 3, 4.0), "crawling, it leaves a trail of slime")
	var trail: Slime = crawler.slime
	var smear: Vector4 = trail.smears[trail.smears.size() - 1]
	crawler.queue_free()
	player.end_invulnerable()
	player.health.health = player.health.max_health
	var wizard_hp: int = player.health.health
	# Standing still: no knock left over from before, kept while its physics was off.
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	player.global_position = Vector2(smear.x, smear.y - Slime.FEET - 4.0)
	check(await within(func() -> bool: return player.health.health < wizard_hp, 1.0), "fresh slime hurts the wizard in it")
	player.set_physics_process(false)
	player.health.health = player.health.max_health
	check(await within(func() -> bool: return not is_instance_valid(trail), Slime.LIFE + 1.0), "and it fades, gone once its abomination is")
	for n: Node in get_nodes_in_group(&"abomination"):
		if not n.has_meta(&"cell"):
			n.queue_free()
	player.phasing = false
	await frames(2)


## A department's portal: to a level of its band in the same world, coming out of the way back it
## opens there; the way back leads back to the portal and closes.
func _department() -> void:
	print("a department")
	var portals: Array[Node] = placed("department.tscn")
	check(not portals.is_empty(), "a department's portal in a lecture hall")
	if portals.is_empty():
		return
	var portal: Department = portals[0] as Department
	var portal_cell: Vector2i = portal.cell
	var from: Vector2i = info.coord
	var to: Vector2i = portal.destination()
	check(to.x == from.x and NextWorldDef.archetype_at(to.y) == portal.band(), "it leads to a level of %s in the same world (%s)" % [portal.band(), to])
	portal.use()
	await settle()
	check_eq(info.coord, to, "through it, the wizard is there")
	var backs: Array[Node] = placed("way_back.tscn")
	check(backs.size() == 1 and info.run.way_back.size() == 4, "a way back stands there")
	if backs.is_empty():
		return
	var at: Vector2 = (backs[0] as Node2D).global_position
	check_eq(info.cell_at(player.global_position), info.cell_at(at), "the wizard comes out of the way back, as out of a gate's partner")
	check(info.world.get_cell(info.cell_at(at) + Vector2i.UP).type == LevelGen.Type.EMPTY, "with open air over it: nothing stands on top of it")
	# On no other door, nor beside one: the prompt where the wizard comes out is the way back's.
	var spot: Vector2i = info.cell_at(at)
	var crowded: Array[Vector2i] = info.world.objects.filter(func(o: Vector2i) -> bool:
		var t: LevelGen.Type = info.world.get_cell(o).type
		return (Placeables.has_flag(t, &"stander") or t == LevelGen.Type.DOOR) and absi(o.x - spot.x) <= MapInfo.WAY_BACK_APART and absi(o.y - spot.y) <= 1)
	check(spot != info.world.exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1)) and crowded.is_empty(), "it stands clear of the level's way back and every other door (%s)" % [crowded])
	await frames(3)
	var focus: Node = Interactable.focused(self)
	check(focus != null and focus.get_parent() is WayBack, "the prompt where the wizard comes out is the way back's")
	await _go(Vector2i(from.x, 0))
	await _go(to)
	check(placed("way_back.tscn").size() == 1 and (placed("way_back.tscn")[0] as Node2D).global_position == at, "it lasts, where it was, until used")
	(placed("way_back.tscn")[0] as WayBack).use()
	await settle()
	check_eq(info.coord, from, "through it, back in the institute")
	check(info.cell_at(player.global_position) == portal_cell and info.run.way_back.is_empty(), "at the department's portal, the way back closed")


# ------------------------------------------------------------------ helpers

func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()


## Whether cell `c` of `w` holds something solid to sight and bolts (rock, a ledge, a gate).
func _blocks(w: LevelGen, c: Vector2i) -> bool:
	return w.get_cell(c).type in [LevelGen.Type.GROUND, LevelGen.Type.PLATFORM, LevelGen.Type.MOVING_PLATFORM, LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE,
		LevelGen.Type.CRACKED, LevelGen.Type.SPIKES, LevelGen.Type.LIGHT_GATE, LevelGen.Type.EXAM_DOOR, LevelGen.Type.TRAPDOOR]


## A stretch of open floor at least six cells long with headroom, out of the halls: its left cell.
func _open_floor() -> Vector2i:
	var w: LevelGen = info.world
	for v: Vector2i in w.free_floors():
		var ok: bool = true
		for k: int in range(-1, 7):
			var c: Vector2i = v + Vector2i(k, 0)
			if not w.is_valid(c) or _blocks(w, c) or not w.is_ground(c + Vector2i.DOWN) or _blocks(w, c + Vector2i.UP) or Institute.hall_at(w, c) >= 0:
				ok = false
				break
		if ok:
			return v + Vector2i(1, 0)
	return w.free_floors()[0]


func _spawn(scene: String, v: Vector2i, ability: StringName = &"") -> Scholar:
	var node: Scholar = (load("res://prefabs/" + scene) as PackedScene).instantiate() as Scholar
	LevelLoader.arm(node, info.here.depth)
	info.map_elements.add_child(node)
	node.global_position = info.cell_position(v)
	node.setup(info, v, {"ability": ability, "hall": -1})
	return node


## An abomination at `v`, of `lobes` blobs (or as one laid with the level, for 0).
func _spawn_thing(v: Vector2i, lobes: int = 0) -> Abomination:
	var node: Abomination = (load("res://prefabs/abomination.tscn") as PackedScene).instantiate() as Abomination
	LevelLoader.arm(node, info.here.depth)
	if lobes > 0:
		node.sprout(lobes)
	info.map_elements.add_child(node)
	node.global_position = info.cell_position(v)
	return node


func _clear_shots() -> void:
	for n: Node in info.map_elements.get_children():
		if n is Bullet:
			n.queue_free()
