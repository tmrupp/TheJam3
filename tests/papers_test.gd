extends TestKit
## Exam papers (KeyRing.paper; docs/REGIONS_PLAN.md §9, the timetable): a paper sent to a lecture
## hall's field level (by attending its class, timetable_test) lies there, on a floor away from the
## way in, laid once and kept as a dropped key is; taken, it rides on the key ring and is kept through
## a death. Studied at a lantern (MapInfo.study, learn_paper): a paper's spell takes its slot and the
## one put out comes back as a paper, round and round; a paper of the spell held at no higher a tier
## teaches nothing, a higher one raises it with nothing back; the dash and the other moves too; a
## lesson's spell taken hands back the one it puts out as a paper (shrine_test, the shrine's); a
## lantern that studies burns out, teaching nothing more. An
## instructor (Scholar, a classroom's master) turned on the wizard moves as its subject does: a warp to
## another floor of its room, a rift between its two furthest floors, levitating over the floor,
## ferrying across it without a stop, projecting itself (unhurt meanwhile), and, aware, seeing the
## wizard through rock where another does not.
## godot --headless --path . --script res://tests/papers_test.gd

const WORLD: int = 28


func run() -> void:
	MapInfo.debug = false
	await boot(WORLD)
	process_frame.connect(func() -> void: player.health.health = player.health.max_health)
	await _field_trip()
	await _study()
	await _instructors()
	RunState.delete_save()
	finish()


## A paper sent to a field level lies there, away from the way in, once; taken, it is kept through a
## death.
func _field_trip() -> void:
	print("a field trip")
	var institute: Vector2i = Vector2i(WORLD, NextWorldDef.band_row(&"institute", 0))
	await _go(institute)
	var hall: int = -1
	for i: int in range(info.world.halls.size()):
		if info.world.halls[i]["kind"] == &"lecture":
			hall = i
			break
	check(hall >= 0, "a lecture hall")
	if hall < 0:
		return
	var field: Vector2i = info.field_of(hall)
	var code: int = KeyRing.paper(&"hex", 2)
	info.run.papers_out[field] = [code]
	await _go(field)
	var papers: Array[Node] = _papers(code)
	check_eq(papers.size(), 1, "the paper lies in the field level (%s)" % field)
	check(info.run.papers_out.is_empty(), "laid, it waits no more")
	if papers.is_empty():
		return
	var at: Vector2i = info.cell_at((papers[0] as Node2D).global_position)
	var start: Vector2i = info.world.exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	var far: bool = info.world.free_floors().any(func(v: Vector2i) -> bool: return LevelGen.dist(v, start) >= MapInfo.PAPER_CLEAR)
	check(not far or LevelGen.dist(at, start) >= MapInfo.PAPER_CLEAR, "on a floor at least %d cells from the way in" % MapInfo.PAPER_CLEAR)
	await _go(field)
	check_eq(_papers(code).size(), 1, "come back, it lies there still, once")
	player.global_position = (_papers(code)[0] as Node2D).global_position
	await frames(2)
	(_papers(code)[0] as KeyPickup).touch(player)
	await frames(2)
	check(player.keyring.has(code), "taken onto the key ring")
	await _go(field)
	check(_papers(code).is_empty(), "and gone from the level")
	info.player_died(player.global_position)
	await settle()
	check(player.keyring.has(code), "kept through a death, as keys are")
	player.keyring.spend(code)


## Studying papers at a lantern: swapped into the slot and back, upgrades, moves.
func _study() -> void:
	print("studying at a lantern")
	Abilities.set_tier(player, &"keyring", 2)
	player.keyring.clear()
	Abilities.set_tier(player, &"slash", 1)
	var at: Vector2 = player.global_position
	var hex: int = KeyRing.paper(&"hex", 3)
	player.keyring.take(hex)
	check(info.study(at), "a hex III paper studied")
	var slash_back: Array[int] = [KeyRing.paper(&"slash", 1)]
	check(Abilities.spell(player) == &"hex" and Abilities.tier(player, &"hex") == 3 and player.keyring.papers() == slash_back, "hex III takes the damage slot, and slash I comes back as a paper")
	check(info.study(at), "studied again")
	var hex_back: Array[int] = [hex]
	check(Abilities.spell(player) == &"slash" and Abilities.tier(player, &"slash") == 1 and player.keyring.papers() == hex_back, "slash is back, and the hex III paper with it: round and round")
	info.study(at)
	player.keyring.clear()
	player.keyring.take(KeyRing.paper(&"hex", 2))
	check(not info.study(at), "a hex II paper teaches a wizard who knows hex III nothing")
	player.keyring.take(KeyRing.paper(&"hex", 4))
	check(info.study(at) and Abilities.tier(player, &"hex") == 4, "a hex IV paper raises it")
	var stays: Array[int] = [KeyRing.paper(&"hex", 2)]
	check(player.keyring.papers() == stays, "with nothing back, the hex II paper still carried")
	player.keyring.clear()
	Abilities.set_tier(player, &"dash", 2)
	player.keyring.take(KeyRing.paper(&"warp", 2))
	info.study(at)
	var dash_back: Array[int] = [KeyRing.paper(&"dash", 2)]
	check(Abilities.spell(player, &"move") == &"warp" and player.keyring.papers() == dash_back, "a move too: warp II in, the dash back as a dash II paper")
	info.study(at)
	check(Abilities.spell(player, &"move") == &"dash" and Abilities.tier(player, &"dash") == 2, "and the dash learned again from it")
	player.keyring.clear()
	# A lantern: the first use lights it; used again, it studies.
	var lanterns: Array[Node] = info.map_elements.get_children().filter(func(n: Node) -> bool: return n is Checkpoint and not info.is_lantern_spent(n))
	if lanterns.is_empty():
		print("no lantern in this level to try")
	else:
		var lantern: Checkpoint = lanterns[0] as Checkpoint
		player.global_position = lantern.global_position
		await frames(2)
		player.keyring.take(KeyRing.paper(&"seeker", 1))
		var lit: bool = info.is_respawn_lantern(lantern)
		lantern.interacted()
		if not lit:
			check(info.is_respawn_lantern(lantern) and player.keyring.papers().size() == 1, "a lantern's first use lights it, studying nothing")
			lantern.interacted()
		check(Abilities.spell(player) == &"seeker", "used again, it studies the paper carried")
		check(info.is_lantern_spent(lantern) and not info.is_respawn_lantern(lantern) and info.run.vulnerable, "and burns out doing it: it protects no more")
		var carried: Array[int] = player.keyring.papers()
		lantern.interacted()
		check(Abilities.spell(player) == &"seeker" and player.keyring.papers() == carried, "burnt out, it teaches nothing more")
		info.run.vulnerable = false
	player.keyring.clear()
	print("a lesson")
	Abilities.set_tier(player, &"hex", 2)
	info.leave_lesson(info.cell_at(player.global_position), player.global_position, &"nova")
	await frames(2)
	var lessons: Array[Node] = placed("lesson.tscn")
	check(lessons.size() == 1, "a master's lesson")
	if not lessons.is_empty():
		(lessons[0] as Lesson).take()
		var hex_paper: Array[int] = [KeyRing.paper(&"hex", 2)]
		check(Abilities.spell(player) == &"nova" and player.keyring.papers() == hex_paper, "taken, nova takes the slot and the hex II comes back as a paper")
	player.keyring.clear()
	Abilities.set_tier(player, &"slash", 1)
	Abilities.set_tier(player, &"dash", 1)
	Abilities.set_tier(player, &"keyring", 0)


## Each instructor's move (see the class description), in a classroom emptied for it.
func _instructors() -> void:
	print("the instructors' moves")
	await _go(Vector2i(WORLD, NextWorldDef.band_row(&"institute", 0)))
	var index: int = -1
	for i: int in range(info.world.halls.size()):
		if info.world.halls[i]["kind"] == &"lecture":
			index = i
			break
	check(index >= 0, "a classroom")
	if index < 0:
		return
	var inside: Rect2i = info.world.halls[index]["inside"]
	var box: Rect2i = info.world.halls[index]["box"]
	for n: Node in get_nodes_in_group(&"scholar"):
		if box.has_point(info.cell_at((n as Node2D).global_position)):
			n.queue_free()
	var bottom: int = inside.end.y - 1
	var cell_px: float = info.cell_position(Vector2i(1, 0)).x - info.cell_position(Vector2i(0, 0)).x
	# The wizard on the room's floor at one end, an instructor at the other.
	var wizard_at: Vector2 = info.cell_position(Vector2i(inside.position.x + 1, bottom))
	var spot: Vector2i = Vector2i(inside.end.x - 3, bottom)
	# In by right, as if they had gone in to its class (MapInfo.keep_out would put them back out).
	info.class_hall = index
	player.global_position = wizard_at
	await frames(2)

	print("warp")
	var ex: Scholar = _instructor(&"warp", spot, index)
	var floors: Array[Vector2i] = ex.floors()
	check(floors.size() > 1, "the room has floors to warp to (%d)" % floors.size())
	var from: Vector2 = ex.global_position
	check(await within(func() -> bool: return ex.global_position.distance_to(from) > cell_px * 1.5, Scholar.MOVE_EVERY + 2.0), "a warp instructor warps")
	check(info.cell_at(ex.global_position) in floors or info.cell_at(ex.global_position + Vector2(0, -8)) in floors, "to a floor of its room")
	ex.queue_free()

	print("rift")
	ex = _instructor(&"rift", spot, index)
	floors = ex.floors()
	var ends: Array[float] = [info.cell_position(floors[0]).x, info.cell_position(floors[floors.size() - 1]).x]
	var at_end: Callable = func(k: int) -> bool: return absf(ex.global_position.x - ends[k]) < cell_px * 0.5
	check(await within(func() -> bool: return at_end.call(1), Scholar.MOVE_EVERY + 2.0), "a rift instructor rifts to one end of its room")
	check(await within(func() -> bool: return at_end.call(0), Scholar.MOVE_EVERY + 2.0), "and back to the other")
	var landed: float = ex.global_position.y
	await within(func() -> bool: return false, 0.5)
	check(ex.global_position.y >= landed and ex.global_position.y > info.cell_position(floors[0]).y, "standing on the floor there, not wedged in the wall (%s, landed %.0f, floor %s)" % [ex.global_position, landed, info.cell_position(floors[0])])
	ex.queue_free()

	print("levitate")
	ex = _instructor(&"levitate", spot, index)
	var floor_y: float = info.cell_position(spot).y
	check(await within(func() -> bool: return ex.global_position.y < floor_y - Scholar.HOVER * 0.7, 2.0), "a levitating instructor hovers over the floor")
	await within(func() -> bool: return false, 1.0)
	check(ex.global_position.y < floor_y - Scholar.HOVER * 0.7, "and stays up")
	ex.queue_free()

	print("ferry")
	ex = _instructor(&"ferry", spot, index)
	var xs: Array[float] = []
	var record_x: Callable = func() -> bool:
		xs.append(ex.global_position.x)
		return false
	await within(record_x, 6.0)
	var lo: float = xs.min()
	var hi: float = xs.max()
	check(hi - lo > cell_px * 3.0, "a ferrying instructor crosses its room (%.0f px)" % (hi - lo))
	check(xs[xs.size() - 1] < hi - 1.0 or xs[xs.size() - 1] > lo + 1.0, "without a stop")
	var turned: bool = false
	for k: int in range(2, xs.size()):
		turned = turned or signf(xs[k] - xs[k - 1]) * signf(xs[k - 1] - xs[k - 2]) < 0.0
	check(turned, "turning at its ends")
	ex.queue_free()

	print("astral")
	ex = _instructor(&"astral", spot, index)
	var wound: Wound = ex.get_node("Wound") as Wound
	check(await within(func() -> bool: return ex.projected > 0.0, Scholar.MOVE_EVERY + 2.0), "an astral instructor projects itself")
	var hp: int = wound.hp
	wound.hit(1, Vector2.UP)
	check_eq(wound.hp, hp, "and is unhurt while projected")
	check(await within(func() -> bool: return ex.projected <= 0.0, Scholar.ASTRAL_TIME + 1.0), "until the projection runs out")
	wound.hit(1, Vector2.UP)
	check_eq(wound.hp, hp - 1, "then a blow wounds it")
	ex.queue_free()

	print("awareness")
	var aware: Scholar = _instructor(&"awareness", spot, index)
	var plain: Scholar = _instructor(&"hex", spot + Vector2i(-1, 0), index)
	await frames(2)
	var eye: Vector2 = aware.eye()
	var hidden: Vector2 = Vector2.INF
	for v: Vector2i in info.world.free_floors():
		var p: Vector2 = info.cell_position(v)
		if p.distance_to(eye) < float(Scholar.SIGHT[&"master"]) * 0.8 and not SpellStrike.clear(eye, p):
			hidden = p
			break
	check(hidden != Vector2.INF, "a floor near the room hidden from it by rock")
	if hidden != Vector2.INF:
		player.global_position = hidden
		await frames(2)
		check(aware.sees(player) and not plain.sees(player), "an aware instructor sees the wizard through rock; another does not")
	aware.queue_free()
	plain.queue_free()
	player.global_position = wizard_at
	await frames(2)


# ------------------------------------------------------------------ helpers

## The papers of `code` lying in the level.
func _papers(code: int) -> Array[Node]:
	return placed("key.tscn").filter(func(n: Node) -> bool: return (n as KeyPickup).key_color() == code)


## An instructor of classroom `hall` teaching `a` at cell `v`, turned on the wizard.
func _instructor(a: StringName, v: Vector2i, hall: int) -> Scholar:
	var node: Scholar = (load("res://prefabs/master.tscn") as PackedScene).instantiate() as Scholar
	LevelLoader.arm(node, info.here.depth)
	info.map_elements.add_child(node)
	node.global_position = info.cell_position(v)
	node.setup(info, v, {"ability": a, "hall": hall})
	node.ability = a
	node.move = &"" if a in Institute.MASTERIES else a
	node.roused = true
	return node


func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
