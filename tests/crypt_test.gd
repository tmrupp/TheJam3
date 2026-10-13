extends TestKit
## The cemetery's crypts and its light (docs/REGIONS_PLAN.md §7): one or two crypts a level, their
## insides collapsed from their own sample, walled in masonry with a doorway or two, nothing inside
## the wizard could drop into and not get out of, the same on every visit; the level's star cluster
## (or a hoard of stars) deep inside, skeletons asleep on its floors and a snuffing font by each doorway. In play: a font puts
## the flame out (unprotected) and a lantern lights it again; light falls where the flame sees, not
## through rock; wraiths freeze in it; a sleeping skeleton wakes in it, walks at the wizard and
## crumbles when stunned.
## godot --headless --path . --script res://tests/crypt_test.gd


func run() -> void:
	generation()
	await play()
	RunState.delete_save()
	finish()


## In play, in the cemetery's first level.
func play() -> void:
	await boot()
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"cemetery"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	print("in play")
	check(info.world.crypts.size() >= 1 and placed("snuffer.tscn").size() >= 1 and placed("skeleton_enemy.tscn").size() >= Crypts.SKELETONS_MIN, "its crypt, its fonts and its sleepers are there")

	print("snuffing and lighting")
	var font: Snuffer = placed("snuffer.tscn")[0] as Snuffer
	check(not info.run.vulnerable and font.can_snuff(), "the flame is lit, and the font can put it out")
	font.snuff()
	check(info.run.vulnerable and not font.can_snuff(), "the font puts it out: unprotected, and nothing more to put out")
	var lantern: Checkpoint = placed("checkpoint.tscn")[0] as Checkpoint
	check(info.light_lantern(lantern) and not info.run.vulnerable and font.can_snuff(), "a lantern lights it again")

	print("light")
	var run_at: Variant = _run(2)
	check(run_at != null, "a stretch of open floor two cells long, away from the lanterns")
	if run_at == null:
		return
	var a: Vector2i = run_at
	var b: Vector2i = a + Vector2i(2, 0)
	player.global_position = info.cell_position(a)
	await physics_frame
	check(Lamplight.at(info.cell_position(b)), "the lit flame lights the floor two cells on")
	var wall: Variant = _walled()
	if wall != null:
		player.global_position = info.cell_position(wall)
		await physics_frame
		check(not Lamplight.at(info.cell_position((wall as Vector2i) + Vector2i(2, 0))), "but not through the rock")
	player.global_position = info.cell_position(a)
	info.snuff(player.global_position)
	await physics_frame
	check(not Lamplight.at(info.cell_position(b)), "snuffed, it lights nothing")
	info.run.vulnerable = false

	print("a wraith freezes in light")
	var wraith: Node2D = _spawn("res://prefabs/wraith_enemy.tscn", b)
	await physics_frame
	await physics_frame
	var was: Vector2 = wraith.global_position
	await within(func() -> bool: return false, 1.0)
	var ghost: Wraith = wraith.get_node("Wraith") as Wraith
	check(ghost.shy and wraith.global_position.distance_to(was) < 1.0, "in the flame's light it freezes, cowering")
	info.snuff(player.global_position)
	check(await within(func() -> bool: return wraith.global_position.distance_to(player.global_position) < was.distance_to(player.global_position) - 30.0, 2.0), "snuffed, it comes on")
	wraith.queue_free()
	info.run.vulnerable = false

	print("a skeleton wakes in light")
	info.snuff(player.global_position)
	var sleeper: Node2D = _spawn("res://prefabs/skeleton_enemy.tscn", b)
	var bones: Skeleton = sleeper.get_node("Skeleton") as Skeleton
	await within(func() -> bool: return false, 1.0)
	check(bones.asleep, "in the dark it sleeps on")
	info.run.vulnerable = false
	check(await within(func() -> bool: return not bones.asleep, 0.5), "the flame's light wakes it")
	check(await within(func() -> bool: return bones.rising == 0.0 and bones.walking, Skeleton.RISE + 1.0), "it rises and walks")
	var far: float = absf(sleeper.global_position.x - player.global_position.x)
	await within(func() -> bool: return false, 0.4)
	check(absf(sleeper.global_position.x - player.global_position.x) < far, "at the wizard")
	Stunner.of(sleeper).stun(1.0)
	check(await until(gone(sleeper)), "a stun crumbles it")


## A floor cell with `n` more open floor cells to its right in a row (open over them too), more than
## RESPAWN_REACH from every lantern, or null.
func _run(n: int) -> Variant:
	var w: LevelGen = info.world
	for v: Vector2i in w.free_floors():
		var ok: bool = true
		for k: int in range(n + 1):
			var c: Vector2i = v + Vector2i(k, 0)
			if not w.is_valid(c) or w.is_ground(c) or not w.ground_below(c) or w.is_ground(c + Vector2i.UP):
				ok = false
				break
		if ok and _far_from_lanterns(info.cell_position(v)):
			return v
	return null


## An open cell with rock a cell to its right and open air past it, away from the lanterns, or null.
func _walled() -> Variant:
	var w: LevelGen = info.world
	for x: int in range(1, w.size.x - 3):
		for y: int in range(1, w.size.y - 1):
			var v: Vector2i = Vector2i(x, y)
			if not w.is_ground(v) and w.is_ground(v + Vector2i(1, 0)) and not w.is_ground(v + Vector2i(2, 0)) and _far_from_lanterns(info.cell_position(v)):
				return v
	return null


func _far_from_lanterns(p: Vector2) -> bool:
	for n: Node in placed("checkpoint.tscn"):
		if (n as Node2D).global_position.distance_to(p) < RisoLight.RESPAWN_REACH + 100.0:
			return false
	return true


## A new `scene` set at cell `v` of the level (an enemy, armed as one placed with it).
func _spawn(scene: String, v: Vector2i) -> Node2D:
	var node: Node2D = (load(scene) as PackedScene).instantiate() as Node2D
	LevelLoader.arm(node, info.here.depth)
	info.map_elements.add_child(node)
	node.global_position = info.cell_position(v)
	return node


func generation() -> void:
	print("generation")
	var c0: int = NextWorldDef.first_depth(&"cemetery")
	var twos: int = 0
	for at: Vector2i in [Vector2i(28, c0), Vector2i(28, c0 + 2), Vector2i(7, c0 + 4), Vector2i(99, c0 + 5), Vector2i(3, NextWorldDef.band_row(&"cemetery", 3))]:
		var started: int = Time.get_ticks_msec()
		var w: LevelGen = build(at)
		var took: int = Time.get_ticks_msec() - started
		check(w != null, "%s lays out" % at)
		if w == null:
			continue
		check(w.patches.size() == Crypts.INSIDES.size() and (w.patches[0] as Array).size() == Crypts.INSIDES[0].x, "%s: its crypts' insides are collapsed with it" % at)
		check(w.crypts.size() >= 1 and w.crypts.size() <= 2 and w.crypts.size() <= Crypts.wanted(w), "%s: %d crypt(s) (%d wanted), laid out in %d ms" % [at, w.crypts.size(), Crypts.wanted(w), took])
		if w.crypts.size() == 2:
			twos += 1
		var again: LevelGen = build(at)
		check(w.objects == again.objects and w.grounds == again.grounds, "%s: the same every time" % at)
		for i: int in range(w.crypts.size()):
			_crypt(w, at, w.crypts[i], i == 0 and Rules.def_for(at).gate == &"necromancer")
	print("ok %d of the levels have two crypts" % twos)
	var garden: LevelGen = build(Vector2i(28, 1))
	check(garden.patches.is_empty() and garden.crypts.is_empty(), "a garden level has no crypts")


## One crypt of level `w` (at `at`): walled, entered, its floors all got back out from, furnished
## (but for the necromancer's, `lair`).
func _crypt(w: LevelGen, at: Vector2i, crypt: Dictionary, lair: bool) -> void:
	var box: Rect2i = crypt["box"]
	var floors: Array[Vector2i] = crypt["floors"]
	var doors: Array[Vector2i] = crypt["doors"]
	check(box.size.x >= Crypts.INSIDES[1].x + 2 and box.size.y >= Crypts.INSIDES[1].y + 2, "%s: a crypt %s, bigger than a tower" % [at, box.size])
	check(not doors.is_empty() and doors.all(func(d: Vector2i) -> bool: return (d.x == box.position.x or d.x == box.end.x - 1) and not w.is_ground(d)), "%s: %d doorway(s) through its side walls" % [at, doors.size()])
	var walled: bool = true
	for x: int in range(box.position.x, box.end.x):
		for y: int in range(box.position.y, box.end.y):
			var v: Vector2i = Vector2i(x, y)
			var edge: bool = x == box.position.x or y == box.position.y or x == box.end.x - 1 or y == box.end.y - 1
			if edge and not doors.has(v) and not (w.is_ground(v) and w.masonry.has(v)):
				walled = false
	check(walled, "%s: walled all round in masonry" % at)
	var inside: Array[Vector2i] = crypt["inside"]
	check(inside.all(func(v: Vector2i) -> bool: return w.interiors.has(v) and not w.empties.has(v)), "%s: its %d open cells are inside, kept from the free cells" % [at, inside.size()])
	check(floors.size() >= 6, "%s: %d floors to stand on inside" % [at, floors.size()])
	# Every floor reached is got back out from: no pits (Crypts._fill_pits).
	var stand: Array[Vector2i] = doors.duplicate()
	stand.append_array(floors)
	var back: Array[Vector2i] = Crypts._hops(w, stand, doors, true)
	check(floors.all(func(v: Vector2i) -> bool: return back.has(v)), "%s: every floor reached inside is hopped back out from" % at)
	var cluster: bool = w.get_cell(crypt["deep"]).type in [LevelGen.Type.CLUSTER, LevelGen.Type.COIN]
	var sleepers: int = floors.filter(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.SKELETON).size()
	var fonts: int = 0
	for step: Vector2i in crypt["steps"]:
		for v: Vector2i in w.objects_of(LevelGen.Type.SNUFFER):
			if LevelGen.dist(v, step) <= Crypts.FONT_REACH and not box.has_point(v):
				fonts += 1
				break
	if lair:
		check(not cluster and sleepers == 0, "%s: the necromancer's crypt holds no cluster and no sleepers" % at)
	else:
		check(cluster and sleepers >= Crypts.SKELETONS_MIN, "%s: the level's star cluster (or a hoard of stars) at its deepest floor, %d skeletons asleep" % [at, sleepers])
	check(fonts >= 1, "%s: a snuffing font by %d of its %d doorway(s)" % [at, fonts, doors.size()])
	print(_drawn(w, box))


## The crypt in `box` drawn in text, for looking at (# rock, . air, S skeleton, * cluster, F font).
func _drawn(w: LevelGen, box: Rect2i) -> String:
	var out: String = ""
	for y: int in range(box.position.y - 2, box.end.y + 2):
		for x: int in range(box.position.x - 8, box.end.x + 8):
			var v: Vector2i = Vector2i(x, y)
			if not w.is_valid(v):
				out += " "
				continue
			match w.get_cell(v).type:
				LevelGen.Type.GROUND:
					out += "#"
				LevelGen.Type.SKELETON:
					out += "S"
				LevelGen.Type.CLUSTER:
					out += "*"
				LevelGen.Type.SNUFFER:
					out += "F"
				LevelGen.Type.EMPTY:
					out += "."
				_:
					out += "o"
		out += "\n"
	return out
