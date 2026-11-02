extends TestKit
## The sky's temples (Temple, SkyArchetype.build_temples): in some sky levels, not all, each a
## building of stone standing on an island (its floor carried down to the rock), roofed, its altar on
## its floor, its lock's sequence of Temple.LENGTH winds dealt with the level (repeats and all), its
## hoard of star clusters in its hall, the same every build. The lock's rule (Temple.step): the right
## way lights the next step, the wrong way starts again (from the first step, if that is the way).
## In play: its hoard hidden while it is shut; its lock entered by switching on the level's vanes,
## each the next step (switching one off enters nothing, a repeat is two of the same way in a row);
## breaking it resets it, with a flash; refusing while not all lit; then, all lit, opening for good,
## its hoard appearing, and showing where the whale is (meeting it, if it was not).
## godot --headless --path . --script res://tests/temple_test.gd


func run() -> void:
	if not needs([&"sky"]):
		finish()
		return
	print("laid out")
	var found: Vector2i = Vector2i.ZERO
	var levels: int = 0
	var temples: int = 0
	var lengths: Dictionary = {}
	var repeats: int = 0
	var bad: Array[String] = []
	for world: int in range(28, 32):
		for k: int in range(Bands.rows_of(&"sky")):
			var at: Vector2i = Vector2i(world, NextWorldDef.band_row(&"sky", k))
			var w: LevelGen = build(at)
			if w == null:
				continue
			levels += 1
			var held: Array[Vector2i] = w.objects_of(LevelGen.Type.TEMPLE)
			if held.is_empty():
				continue
			temples += 1
			var v: Vector2i = held[0]
			var winds: Array = w.get_cell(v).extra_info
			if held.size() != 1 or winds.size() < Temple.LENGTH.x or winds.size() > Temple.LENGTH.y or not winds.all(func(x: Variant) -> bool: return absi(int(x)) == 1):
				bad.append("%s: its sequence %s" % [at, winds])
			lengths[winds.size()] = true
			for i: int in range(1, winds.size()):
				if winds[i] == winds[i - 1]:
					repeats += 1
			var box: Rect2i = w.temples[0]["box"] if w.temples.size() == 1 else Rect2i()
			if box.size == Vector2i.ZERO or w.temples[0]["altar"] != v or not w.is_ground(v + Vector2i.DOWN):
				bad.append("%s: its altar not on its floor in its building" % at)
			else:
				# Its stylobate stands on the island: every column of it carried down to rock.
				for x: int in range(box.position.x, box.end.x):
					var c: Vector2i = Vector2i(x, box.end.y - 1)
					while w.masonry.has(c):
						c += Vector2i.DOWN
					if not w.is_ground(c):
						bad.append("%s: not standing on the island" % at)
						break
				if not range(box.position.x, box.end.x).all(func(x: int) -> bool: return w.masonry.has(Vector2i(x, box.position.y)) and w.masonry.has(Vector2i(x, box.end.y - 1))):
					bad.append("%s: no roof and floor of stone" % at)
			if str(build(at).get_cell(v).extra_info) != str(winds):
				bad.append("%s: not the same every build" % at)
			if found == Vector2i.ZERO:
				found = at
	check(temples > 0 and temples < levels and bad.is_empty(), "temples in %d of %d sky levels, each standing on an island, its sequence of %d to %d winds dealt, the same every build %s" % [temples, levels, Temple.LENGTH.x, Temple.LENGTH.y, bad])
	check(lengths.size() > 1 and repeats > 0, "sequences of %d lengths, with repeats in them (%d)" % [lengths.size(), repeats])
	check(Temple.step([1, 1, -1], 0, 1) == 1 and Temple.step([1, 1, -1], 1, 1) == 2 and Temple.step([1, 1, -1], 2, -1) == 3, "the right way lights the next step")
	check(Temple.step([1, 1, -1], 2, 1) == 1 and Temple.step([-1, 1], 1, -1) == 1 and Temple.step([1, -1], 1, 1) == 1 and Temple.step([-1, -1], 1, 1) == 0, "the wrong way starts it again (from the first step, if that is the way)")
	if found == Vector2i.ZERO:
		finish()
		return

	print("in play")
	await boot(found.x)
	info.coord = found
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	var temple: Temple = placed("temple.tscn")[0] as Temple
	# The wizard well over it (off its hoard), its chunk awake.
	player.global_position = temple.global_position + Vector2(0.0, -900.0)
	info.loader.wake_around(temple.global_position)
	var hoard: Array = info.world.temples[0]["hoard"]
	var steps: Array[int] = temple.sequence
	check(hoard.size() == SkyArchetype.TEMPLE_HOARD and _clusters(hoard) == 0, "its hoard (%d star clusters) is hidden while it is shut" % hoard.size())
	check(not temple.opened() and temple.progress() == 0 and str(temple.interaction_hint().get("text", "")) == "0 of %d winds" % steps.size(), "shut, none of its %d winds lit, and it says so" % steps.size())
	# All but the last entered, by switching on vanes (a new one for each step).
	for i: int in range(steps.size() - 1):
		_on(steps[i])
	check(temple.progress() == steps.size() - 1, "each vane switched on its way lights the next step (%d of %d)" % [temple.progress(), steps.size()])
	var off: int = info.record().temple_progress
	info.switch_vane(_last, steps[0])
	check(info.record().temple_progress == off, "switching one off enters nothing")
	await frames(2)
	_on(-steps[steps.size() - 1])
	await frames(2)
	check(temple.progress() <= 1 and temple.since_broken < 0.2, "the wrong way breaks the sequence: it starts again, with a flash")
	temple.use()
	check(not temple.opened(), "not all lit: it refuses")
	for i: int in range(steps.size() + 1):
		if temple.all_lit():
			break
		_on(steps[temple.progress()])
	check(temple.all_lit(), "entered whole: all lit")
	temple.use()
	await frames(2)
	check(temple.opened() and info.record().temple_open, "it opens, kept in the level record")
	check(_clusters(hoard) == hoard.size(), "and its hoard appears in its hall")
	check(info.run.whale_x != WhaleHunt.NONE and str(temple.interaction_hint().get("text", "")) == "the whale: world %d" % info.run.whale_x, "and shows where the whale is (world %d)" % info.run.whale_x)
	RunState.delete_save()
	finish()


## The last made-up vane switched on (see _on).
var _last: Vector2i = Vector2i.ZERO
var _made: int = 0


## Switch on a vane pointing `way`: a new one each time (made-up cells, off the level).
func _on(way: int) -> void:
	_made += 1
	_last = Vector2i(10000 + _made, 0)
	info.switch_vane(_last, way)


## How many of `cells` hold a star cluster in the scene.
func _clusters(cells: Array) -> int:
	var n: int = 0
	for node: Node in placed("star_cluster.tscn"):
		if cells.has(node.get_meta(&"cell", Vector2i(-1, -1))):
			n += 1
	return n
