extends TestKit
## suite: full
## A barrier for each relic (Barriers, docs/REVIEW_PLAN.md §3), looked for over a few worlds and rows
## with `build` for a level holding each of the five rather than trusting one level: the shaft has
## its far wall thorned for its whole height and the wall by its way in bare rock; the sill's face
## is thorned under it and its top is rock; the throat has thorns over and under every cell of it;
## the curtain fills the mouth floor to roof; the sealed cell has rock all round it, thicker than a
## blink carries (when one is found: it fits fewest levels); each holds its reward; it keeps out of
## lifts' tracks, things' rooms and the walls pods grow from, and nothing dealt later lies in its
## pocket; the level is the same on two builds; its move is the nearest
## relic's (or the level's own deal); none is laid over a way on or in a gate level. Booted: the mark
## stands by the mouth and is on the level's map once seen, and goes once the move is known. No test
## asks that a barrier can or cannot be passed.
## godot --headless --path . --script res://tests/barriers_test.gd

## Where the barriers are looked for: up to this many worlds from world 28 on, and every row of the
## garden either side of the start (about one garden level in ten holds one, so a short garden, the
## demo's, wants more worlds), until FOUND kinds have turned up.
const WORLDS: int = 80
const FOUND: int = 4


func run() -> void:
	var found: Dictionary = {}
	for world: int in range(28, 28 + WORLDS):
		if found.size() >= FOUND:
			break
		for row: int in range(-Bands.garden_rows(), Bands.garden_rows() + 1):
			var at: Vector2i = Vector2i(world, row)
			var w: LevelGen = build(at)
			if w == null:
				continue
			if Bosses.gate_at(row) != &"" or row == 0:
				check(w.barriers.is_empty(), "%s: no barrier in a gate level or the start" % at) if not w.barriers.is_empty() else null
				continue
			for b: Barrier in w.barriers:
				if not found.has(int(b.kind)):
					found[int(b.kind)] = at
					_shape(at, w, b)
	# Few levels have room for a shape (Barriers._solid), and the sealed cell's thick walls fewest:
	# most kinds are found here; one not found is said, not failed.
	for kind: int in range(Barriers.MOVE.size()):
		print("  a %s barrier: %s" % [Barriers.MOVE[kind], found.get(kind, "none found in these levels")])
	check(found.size() >= 3, "most kinds are laid somewhere (%d of %d)" % [found.size(), Barriers.MOVE.size()])
	if not found.is_empty():
		await _booted(found.values()[0])
	finish()


## Barrier `b` in level `w` at `at` is shaped as its kind says, holds its reward, is the same on a
## second build, is made for the nearest relic's move, and stands on no way on.
func _shape(at: Vector2i, w: LevelGen, b: Barrier) -> void:
	var kind: int = b.kind
	var name: String = Barriers.MOVE[kind]
	print("%s at %s, its mouth %s" % [name, at, b.mouth])
	var again: LevelGen = build(at)
	check(again.objects == w.objects and again.barriers.size() == w.barriers.size(), "%s: the same on two builds" % name)
	check_eq(StringName(b.move), Barriers.move_for(at), "%s: made for the nearest relic's move, or the level's own" % name)
	var reward: Vector2i = b.reward
	check(w.get_cell(reward).type == LevelGen.Type.CLUSTER, "%s: its reward, a star cluster, at its far end" % name)
	var open: Array = b.open
	check(not w.exits.values().any(func(e: Vector2i) -> bool: return open.has(e)), "%s: on no way on" % name)
	var thorns: Array = b.thorns
	check(thorns.all(func(c: Vector2i) -> bool: return w.get_cell(c).type == LevelGen.Type.SPIKES), "%s: its thorns laid" % name)
	_keeps_out(name, w, b)
	var side: int = b.side
	var door: Vector2i = b.mouth + Vector2i(side, 0)
	match kind:
		Barriers.Kind.SHAFT:
			var far_ok: bool = true
			var near_ok: bool = true
			for up: int in range(Barriers.SHAFT_TALL):
				far_ok = far_ok and thorns.has(door + Vector2i(side * (Barriers.SHAFT_WIDE + 1), -up)) and w.is_ground(door + Vector2i(side * (Barriers.SHAFT_WIDE + 2), -up))
				if up > 0:
					near_ok = near_ok and w.is_ground(door + Vector2i(0, -up))
			check(far_ok, "shaft: its far wall thorned for its whole height")
			check(near_ok, "shaft: the wall by its way in bare rock")
		Barriers.Kind.SILL:
			var face: bool = true
			for up: int in range(Barriers.SILL_UP - 1):
				face = face and thorns.has(door + Vector2i(side * Barriers.SILL_WIDE, -up))
			check(face and w.is_ground(door + Vector2i(side * Barriers.SILL_WIDE, -(Barriers.SILL_UP - 1))), "sill: its face thorned under it, its top rock")
		Barriers.Kind.THROAT:
			var lined: bool = true
			for k: int in range(1, Barriers.THROAT_LONG + 1):
				var c: Vector2i = door + Vector2i(side * k, 0)
				lined = lined and thorns.has(c + Vector2i.UP) and thorns.has(c + Vector2i.DOWN) and w.get_cell(c).type == LevelGen.Type.EMPTY
			check(lined, "throat: thorns over and under every cell of it")
		Barriers.Kind.CURTAIN:
			var filled: bool = true
			for k: int in range(1, Barriers.CURTAIN_DEEP + 1):
				for up: int in range(2):
					filled = filled and thorns.has(door + Vector2i(side * k, -up))
			check(filled, "curtain: the mouth filled with thorns floor to roof")
		Barriers.Kind.SEALED:
			var sealed: bool = true
			for c: Vector2i in open:
				for dx: int in range(-Barriers.SEALED_WALL, Barriers.SEALED_WALL + 1):
					for dy: int in range(-Barriers.SEALED_WALL, Barriers.SEALED_WALL + 1):
						var n: Vector2i = c + Vector2i(dx, dy)
						if not open.has(n) and (n - b.mouth).x * side > 0:
							sealed = sealed and w.is_ground(n)
			check(sealed, "sealed cell: rock all round it, %d cells thick" % Barriers.SEALED_WALL)


## Barrier `b` in `w` keeps out of what else is laid (docs/CODE_REVIEW.md 1.3, 1.4): none of its
## cells, nor its mouth, is in a lift's body or track or a thing's room (Placeables.size); every
## seed pod and vine still grows from a wall; and nothing dealt once the level is laid out can lie
## in its pocket (LevelGen.floors_proper).
func _keeps_out(name: String, w: LevelGen, b: Barrier) -> void:
	var taken: Dictionary = {b.mouth: true}
	for c: Vector2i in b.rock:
		taken[c] = true
	var crossed: Array[String] = []
	var hanging: Array[Vector2i] = []
	for v: Vector2i in w.objects:
		var t: LevelGen.Type = w.type_at(v)
		var cells: Array[Vector2i] = []
		if t == LevelGen.Type.MOVING_PLATFORM:
			var lift: Array = w.get_cell(v).extra_info
			var run: int = lift[0]
			var axis: Vector2i = lift[1]
			var travel: int = lift[2]
			for k: int in range(1, run):
				cells.append(v + Vector2i(k, 0))
			for k: int in range(1, travel + 1):
				if axis.x != 0:
					cells.append(v + Vector2i(run - 1 + k, 0))
				else:
					for j: int in range(run):
						cells.append(v + Vector2i(j, k))
		var room: Vector2i = Placeables.size(t)
		for dx: int in range(room.x):
			for dy: int in range(room.y):
				if dx != 0 or dy != 0:
					cells.append(v + Vector2i(dx, -dy))
		for c: Vector2i in cells:
			if taken.has(c):
				crossed.append("%s at %s" % [LevelGen.Type.keys()[t], v])
		if (t == LevelGen.Type.POD or t == LevelGen.Type.VINE) and not w.is_ground(v + Vector2i.LEFT) and not w.is_ground(v + Vector2i.RIGHT):
			hanging.append(v)
	check(crossed.is_empty(), "%s: in no lift's track or thing's room %s" % [name, crossed])
	check(hanging.is_empty(), "%s: every seed pod and vine still on its wall %s" % [name, hanging])
	var pocket: Array = b.open
	check(not w.floors_proper().any(func(v: Vector2i) -> bool: return pocket.has(v)), "%s: nothing dealt later lies in its pocket" % name)


## In the game: the mark by the mouth, on the map once seen, gone once the move is known.
func _booted(at: Vector2i) -> void:
	print("booted")
	await boot(28)
	await go(at)
	var marks: Array[Node] = placed("barrier_mark.tscn")
	check_eq(marks.size(), info.world.barriers.size(), "a mark by each barrier's mouth")
	if marks.is_empty():
		return
	var mark: BarrierMark = marks[0] as BarrierMark
	var b: Barrier = info.world.barriers[0]
	check(mark.move == StringName(b.move) and info.world.is_ground(mark.on_rock), "for its move, printed on the rock over its way in")
	await process_frame
	check(mark.showing, "showing while the move is not known")
	info.reveal(b.mouth)
	var map: Node = main.get_node("RisoMap")
	map.call("_build_textures_for", info.world, info.seen(), info.record().broken)
	check(info.is_seen(b.mouth), "its mouth seen, it is on the level's map")
	# Its chunk awake, as with the wizard by it (a chunk far from the view sleeps).
	info.loader.wake_around(mark.global_position)
	Abilities.set_tier(player, StringName(b.move), 1)
	await frames(3)
	check(Abilities.tier(player, StringName(b.move)) > 0 and not mark.showing, "gone once the move is known")
	RunState.delete_save()
