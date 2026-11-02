extends TestKit
## The institute's students' days (Students): each period a student goes to a class in session then
## or the library, walking there in passing time along floors, up jumps and off edges, through the
## classroom doors, which open for them, or blinking there where it cannot walk; in class time it
## stays where it got to; and a level comes back with its students where their days have taken them.
## godot --headless --path . --script res://tests/students_test.gd


func run() -> void:
	if not needs([&"institute"]):
		finish()
		return
	_days()
	await boot()
	await _walking()
	finish()


## The days alone, laid out without the scene.
func _days() -> void:
	print("students' days")
	var moved: int = 0
	var stayed: int = 0
	var walked: int = 0
	var good: bool = true
	var walks: bool = true
	for world: int in [28, 7, 99]:
		for row: int in band_rows(&"institute", [0, 1], false):
			var w: LevelGen = build(Vector2i(world, row))
			for origin: Vector2i in w.objects_of(LevelGen.Type.STUDENT):
				var at: Vector2i = origin
				for r: int in range(Timetable.PERIODS * 2):
					var next: Vector2i = Students.next_seat(w, origin, r, at)
					var hall: int = Timetable.hall_inside(w, next)
					# Where it goes is a class in session then or the library.
					good = good and hall >= 0 and (w.halls[hall]["kind"] == &"library" or Timetable.in_session(w, hall, r))
					# Walking there, a step at a time, where it walks.
					var from: Vector2i = at
					var way: Array[Vector2i] = Students.route(w, at, next)
					for c: Vector2i in way:
						walks = walks and Students.steps_from(w, from).has(c)
						from = c
					if not way.is_empty():
						walked += 1
					if hall != Timetable.hall_inside(w, at):
						moved += 1
					else:
						stayed += 1
					at = next
				good = good and Students.seat_at(w, origin, Timetable.PERIODS * 2 - 1) == at
	check(good, "each period a student goes to a class in session or the library")
	check(walks, "walking there along floors, up jumps and off edges")
	check(moved > stayed * 3, "students change classes (%d moves, %d stays)" % [moved, stayed])
	check(walked > 0 and walked < moved, "on foot where they can, blinking where they cannot (%d of %d moves walked)" % [walked, moved])


## In play: walking in passing time, the doors opening for them, still in class time, and back where
## their days took them.
func _walking() -> void:
	print("students walking")
	var at: Vector2i = _walk_level()
	await _go(at)
	var rec: LevelRecord = info.record()
	check(rec.passing, "a level is first met in passing time")
	player.set_physics_process(false)
	player.end_invulnerable()
	var students: Array[Scholar] = []
	for n: Node in placed("student.tscn"):
		students.append(n as Scholar)
	# The student with the shortest walk to its first class through a classroom door (else any walk),
	# watched as it goes: the wizard over it, so its chunk is awake.
	var doors: Dictionary = {}
	for n: Node in placed("exam_door.tscn"):
		doors[(n as ExamDoor).cell] = n
	var w: LevelGen = info.world
	var best: Scholar = null
	var door: ExamDoor = null
	var best_way: Array[Vector2i] = []
	for s: Scholar in students:
		var way: Array[Vector2i] = Students.route(w, s.origin, Students.next_seat(w, s.origin, rec.rings, s.origin))
		var through: ExamDoor = null
		for c: Vector2i in way:
			if doors.has(c):
				through = doors[c] as ExamDoor
		if way.is_empty() or (door != null and through == null):
			continue
		if best == null or (through != null and door == null) or way.size() < best_way.size():
			best = s
			door = through
			best_way = way
	check(best != null, "a student with a walk to its first class")
	if best == null:
		return
	var goal: Vector2i = best_way[-1]
	player.global_position = best.global_position + Vector2(0, -600)
	await until(func() -> bool: return best.shuffling(), 3000)
	check(best.shuffling(), "in passing time it sets out for its class")
	# (A lambda keeps its own copy of a local, so what it sees is kept in a dictionary.)
	var seen: Dictionary = {"opened": false}
	var arrived: bool = await within(func() -> bool:
		player.global_position = best.global_position + Vector2(0, -600)
		if door != null and not door.shut():
			seen["opened"] = true
		return not best.shuffling(), 120.0)
	check(arrived and info.cell_at(best.global_position) == goal, "and walks there (%d cells)" % best_way.size())
	if door != null:
		check(bool(seen["opened"]), "the classroom door on its way opens for it")
	# Class time: they stay where they are (one out walking still, in a chunk awake, LevelLoader).
	var other: Scholar = null
	for s: Scholar in students:
		if s != best and is_instance_valid(s) and s.shuffling() and s.can_process():
			other = s
	rec.passing = false
	await frames(5)
	if other != null:
		# (Landed first, if class time caught it in a jump.)
		await until(func() -> bool: return other.grounded, 3000)
		var stood: Vector2 = other.global_position
		await frames(60)
		check(not other.shuffling() and other.global_position.distance_to(stood) < 4.0, "in class time a student stays where it got to")
	# Back in the level later, in class time: each student in its class of the period.
	var placed_at: Dictionary = {}
	for s: Scholar in students:
		if is_instance_valid(s):
			placed_at[s.origin] = Students.seat_at(info.world, s.origin, rec.rings)
	await _go(at)
	var right: bool = true
	for n: Node in placed("student.tscn"):
		var s: Scholar = n as Scholar
		if placed_at.has(s.origin):
			right = right and info.cell_at(s.global_position) == placed_at[s.origin]
	check(right and not placed_at.is_empty(), "come back in class time, each student is in its class of the period")
	rec.passing = true


func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()


## The first of a few institute levels (ordinary ones, by world) where a student has a walk to its
## first class from where it was laid, as the level is first met (no bell rung yet): not every level
## has one, however the band is tuned.
func _walk_level() -> Vector2i:
	for world: int in [28, 7, 99, 3, 41]:
		for row: int in band_rows(&"institute", [0, 1, 2], false):
			var at: Vector2i = Vector2i(world, row)
			var w: LevelGen = build(at)
			if w == null:
				continue
			for origin: Vector2i in w.objects_of(LevelGen.Type.STUDENT):
				if not Students.route(w, origin, Students.next_seat(w, origin, 0, origin)).is_empty():
					return at
	return Vector2i(28, NextWorldDef.band_row(&"institute", 0))
