extends TestKit
## The garden's seeds, plants and small worms (GardenArchetype.finish, SeedPod, Plot, KeyRing.SEED,
## Wormlet): every garden
## level has one plot on a floor with air over it, and from row 1 seed pods grown out of its walls,
## apart and away from the way in, the same every build; no other band grows them. A pod spits seeds
## at the wizard in sight; only a seed of its own turned back wounds it (a plain blow glances off), and
## burst it drops a seed. A seed is carried one at a time and kept in the save. Planted at a plot, the
## plant grows by the furthest place reached from it (Plot.apart), and picked it gives a star cluster,
## a skeleton key, or a hyperspace door that stands on the plot, free, and leads into hyperspace and
## back. Plants are kept in the save, and gone with a new run. Small worms lie on floors from row 1,
## more toward the worm's gate; one stirs as the wizard comes near, the rock throbs, it bursts out
## near them, and one blow while it is out slays it for good. A plant grown big draws a swarm of them
## round its plot (Wormlet.SWARM), gone once it is picked.
## godot --headless --path . --script res://tests/garden_growth_test.gd


func run() -> void:
	_rules()
	_generation()
	await boot(28)
	await _pods()
	await _worms()
	await _plants()
	await _swarm()
	RunState.delete_save()
	finish()


## The plain rules: how far apart places are, the tiers, and the seed pocket.
func _rules() -> void:
	print("rules")
	check_eq(Plot.apart(Vector2i(28, 0), Vector2i(30, -3)), 5, "places apart: across plus up or down")
	var side: Vector2i = Worlds.side_at(Worlds.kind_of(Hyperspace), Vector2i(28, 2))
	check_eq(Plot.apart(side, Vector2i(28, 0)), 2, "a side world counts as the level its door is in")
	var tiers: Array[int] = []
	for d: int in [0, Plot.TIERS[0], Plot.TIERS[1] - 1, Plot.TIERS[1], Plot.TIERS[2]]:
		tiers.append(Plot.tier_of(d))
	check_eq(tiers, [0, 1, 1, 2, 3] as Array[int], "a sprout until gone, then stars, a skeleton key, a door")
	var ring: KeyRing = KeyRing.new()
	ring.set_seeds(5)
	check_eq(ring.seeds(), KeyRing.SEEDS_MOST, "at most %d seed carried" % KeyRing.SEEDS_MOST)
	check(ring.spend_seed() and ring.seeds() == 0 and not ring.spend_seed(), "a seed planted is used up")
	ring.free()
	# The leaves shrouding a seed pod or a bramble's bulb: shut at rest and early in its charge,
	# parting as it nears its next seed, wide apart as it spits, folding shut again after.
	var leaves: Array[float] = []
	for at: Vector2 in [Vector2(0.0, INF), Vector2(Bramble.LEAF_PART_FROM, INF), Vector2(0.8, INF), Vector2(1.0, INF), Vector2(0.0, 0.0), Vector2(0.0, Bramble.LEAF_CLOSE)]:
		leaves.append(snappedf(Bramble.leaves_parted(at.x, at.y), 0.01))
	check(leaves[0] == 0.0 and leaves[1] == 0.0 and leaves[2] > 0.0 and leaves[2] < 1.0 and leaves[3] == 1.0 and leaves[4] == 1.0 and leaves[5] == 0.0, "a pod's leaves part as it readies a seed and fold shut after it spits %s" % [leaves])
	# A small worm's segments meet with no gap where its body bends (humped as it inches, and turning
	# up out of a hole): across the body at each joint, every point is under one segment or another.
	var hump: Callable = func(u: float) -> Vector2: return Vector2((u - 0.5) * (Wormlet.LENGTH - WormletArt.INCH), -WormletArt.HUMP * sin(PI * u))
	var turn: Callable = func(u: float) -> Vector2: return WormletArt._bend(Vector2.ZERO, 1.0, (u - 0.5) * Wormlet.LENGTH)
	var bare: int = 0
	for pose: Callable in [hump, turn]:
		var segments: Array[PackedVector2Array] = []
		for i: int in range(WormletArt.SEGMENTS):
			var span: Vector2 = WormletArt.segment_span(i, 0.0, 1.0)
			segments.append(WormletArt.band(pose, span.x, span.y, Wormlet.GIRTH))
		for i: int in range(1, WormletArt.SEGMENTS):
			for du: float in [-0.004, 0.0, 0.004]:
				var u: float = float(i) / float(WormletArt.SEGMENTS) + du
				var normal: Vector2 = ((pose.call(u + 0.001) as Vector2) - (pose.call(u - 0.001) as Vector2)).normalized().orthogonal()
				for across: float in [-0.45, -0.25, 0.0, 0.25, 0.45]:
					var spot: Vector2 = (pose.call(u) as Vector2) + normal * across * Wormlet.GIRTH
					if not segments.any(func(poly: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(spot, poly)):
						bare += 1
	check_eq(bare, 0, "a small worm's segments leave no gap at their joints where it bends")


## Pods and plots as the garden's levels are laid out.
func _generation() -> void:
	print("generation")
	var pods: int = 0
	var plots_ok: bool = true
	var pods_ok: bool = true
	var levels: int = 0
	for world: int in [28, 7, 99]:
		for row: int in range(-Bands.garden_rows(), Bands.garden_rows() + 1):
			var at: Vector2i = Vector2i(world, row)
			var w: LevelGen = build(at)
			if w == null:
				continue
			levels += 1
			var plots: Array[Vector2i] = w.objects_of(LevelGen.Type.PLOT)
			plots_ok = plots_ok and plots.size() == 1 and w.ground_below(plots[0]) and not w.is_ground(plots[0] + Vector2i.UP)
			var here: Array[Vector2i] = w.objects_of(LevelGen.Type.POD)
			pods += here.size()
			if row == 0:
				pods_ok = pods_ok and here.is_empty()
			var start: Vector2i = w.exits[MapInfo.Exit.BACK]
			for v: Vector2i in here:
				var walled: bool = w.is_ground(v + Vector2i.LEFT) or w.is_ground(v + Vector2i.RIGHT)
				pods_ok = pods_ok and walled and LevelGen.dist(v, start) >= GardenArchetype.POD_CLEAR
				for q: Vector2i in here:
					pods_ok = pods_ok and (q == v or LevelGen.dist(q, v) >= GardenArchetype.POD_APART)
			if row == 1:
				check(build(at).objects == w.objects, "%s: the same every build" % at)
	check(plots_ok, "every garden level has one plot, on a floor with air over it (%d levels)" % levels)
	check(pods_ok and pods * 2 >= levels, "pods grow out of walls from row 1, apart and away from the way in (%d)" % pods)
	# Small worms: on free floors from row 1, apart and away from the way in, more toward the worm.
	var toward: int = 0
	var away: int = 0
	var worms_ok: bool = true
	var gate: int = Bosses.row_of(&"worm")
	for world: int in [28, 7, 99]:
		for row: int in range(-Bands.garden_rows(), Bands.garden_rows() + 1):
			var w: LevelGen = build(Vector2i(world, row))
			var here: Array[Vector2i] = w.objects_of(LevelGen.Type.WORMLET)
			if row == 0:
				worms_ok = worms_ok and here.is_empty()
			for v: Vector2i in here:
				worms_ok = worms_ok and w.ground_below(v) and LevelGen.dist(v, w.exits[MapInfo.Exit.BACK]) >= GardenArchetype.WORM_CLEAR
			if gate != 0 and signi(row) == signi(gate):
				toward += here.size()
			elif row != 0:
				away += here.size()
	check(worms_ok and away > 0, "small worms lie on floors from row 1, away from the way in (%d toward the worm, %d away)" % [toward, away])
	if gate != 0:
		check(toward > away, "more of them on the rows toward the worm's gate")
	if Bands.has(&"crags"):
		var crag: LevelGen = build(Vector2i(28, NextWorldDef.band_row(&"crags", 1)))
		check(crag.objects_of(LevelGen.Type.POD).is_empty() and crag.objects_of(LevelGen.Type.PLOT).is_empty(), "no other band grows them")


## A pod in play: it spits, shrugs off a plain blow, bursts to a parried one, and drops a seed.
func _pods() -> void:
	print("seed pods")
	# A pod with a floor in its sight near it, over the garden's rows near the start.
	var body: RigidBody2D = null
	var pod: SeedPod = null
	for row: int in range(1, Bands.garden_rows()):
		if build(Vector2i(28, row)).objects_of(LevelGen.Type.POD).is_empty():
			continue
		info.coord = Vector2i(28, row)
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		await settle()
		for n: Node in placed("seed_pod.tscn"):
			var b: RigidBody2D = n as RigidBody2D
			if await _stand_in_sight(b, b.get_node("SeedPod") as SeedPod):
				body = b
				pod = b.get_node("SeedPod") as SeedPod
				break
		if body != null:
			break
	check(body != null, "a garden pod near the start with a floor in its sight")
	if body == null:
		return
	var wound: Wound = body.get_node("Wound") as Wound
	check(wound != null and wound.parried_only, "only a parried seed wounds it")
	check(await within(func() -> bool: return pod.spat > 0, 6.0), "in sight, it spits a seed")
	var hp: int = wound.hp
	wound.hit(5, Vector2.LEFT)
	check_eq(wound.hp, hp, "a plain blow glances off its bark")
	# A seed of its own, met with the guard, flies home and wounds it: the wizard on a floor in its
	# sight, the level's other foes cleared away.
	for scene: String in ["shooter_enemy.tscn", "mover_enemy.tscn", "hopper_enemy.tscn"]:
		for foe: Node in placed(scene):
			foe.queue_free()
	# A seed of its own caught by the guard (its catch, Parry.parry, as a press in time makes it: the
	# timing of the press is tutorial_test's) flies home and wounds it.
	var wounded: Array[int] = [0]
	wound.hurt.connect(func(damage: int) -> void: wounded[0] += damage)
	var coming: Callable = func() -> Bullet:
		for n: Node in info.map_elements.get_children():
			var b: Bullet = n as Bullet
			if b != null and not b.is_queued_for_deletion() and b.seed:
				return b
		return null
	check(await within(func() -> bool: return coming.call() != null, 6.0), "it spits a seed at the wizard")
	var shot: Bullet = coming.call() as Bullet
	if shot != null:
		(player.get_node("Parry") as Parry).parry(1, Vector2.ZERO, shot.get_node("HitBox/Damager"))
		check(await within(func() -> bool: return wounded[0] > 0, 3.0), "caught by the guard, it flies home and wounds the pod")
	player.set_physics_process(false)
	# The rest of its hits, as parried seeds.
	if is_instance_valid(body) and not body.is_queued_for_deletion():
		HexBolt.parried_blow = true
		wound.hit(99, Vector2.LEFT)
		HexBolt.parried_blow = false
	check(not is_instance_valid(body) or await until(gone(body)), "parried seeds burst it")
	await settle()
	var seeds: Array[Node] = colored("key.tscn", KeyRing.SEED)
	check_eq(seeds.size(), 1, "and its seed falls")
	if seeds.is_empty():
		return
	player.global_position = (seeds[0] as Node2D).global_position
	still()
	check(await until(func() -> bool: return player.keyring.seeds() == 1), "touched, the seed is carried")
	check_eq(int(player.to_save().get("seeds", 0)), 1, "and kept in the save")
	player.set_physics_process(true)


## A small worm in play: hidden, it stirs as the wizard comes near, the rock throbs, it comes out,
## and one blow while it is out slays it for good.
func _worms() -> void:
	print("small worms")
	var at: Vector2i = Vector2i(-1, -1)
	for row: int in range(1, Bands.garden_rows()):
		if not build(Vector2i(28, row)).objects_of(LevelGen.Type.WORMLET).is_empty():
			at = Vector2i(28, row)
			break
	check(at.x >= 0, "a garden level near the start with a small worm")
	if at.x < 0:
		return
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	var found: Array[Node] = placed("wormlet.tscn")
	check(not found.is_empty(), "its worm is placed")
	if found.is_empty():
		return
	var body: RigidBody2D = found[0] as RigidBody2D
	var worm: Wormlet = body.get_node("Wormlet") as Wormlet
	var home: Vector2i = body.get_meta(&"cell")
	check(not worm.shown() and body.collision_layer == 0 and not body.is_in_group(&"hex_target"), "hidden in the rock, nothing touches it")
	check_eq((body.get_node("Wound") as Wound).hp, 1, "one hit point")
	# The wizard stands on its home's floor, still.
	player.global_position = info.cell_position(home)
	still()
	info.loader.wake_around(body.global_position)
	check(await within(func() -> bool: return worm.state == Wormlet.State.WARN, 6.0), "the wizard near, the rock throbs where it will come out")
	# Its warning is the boss's made smaller to a little more than its width: as flat as the boss's.
	var boss_r: float = (info.cell_position(Vector2i(1, 0)) - info.cell_position(Vector2i.ZERO)).x * Worm.GIRTH * 0.5
	var warn_r: float = Wormlet.GIRTH * 0.5 * WormletArt.WARN_WIDE
	check(is_equal_approx(WormletArt.warn_size(info) * boss_r, warn_r) and WormletArt.WARN_WIDE > 1.0, "its warning the boss's in shape, a little wider than it (%.0f px across, %.0f px at its tallest)" % [warn_r * 2.0, 38.0 * WormletArt.warn_size(info)])
	check(worm.face == info.cell_at(player.global_position) or worm.from_ceiling or LevelGen.dist(worm.face, info.cell_at(player.global_position)) <= Wormlet.FLOOR_REACH, "under the wizard (or over them)")
	# Shielded, so its touch's knock does not lift them too: only the bump sends them up.
	player.invulnerable.enable(true)
	var stood: Vector2 = player.global_position
	check(await within(func() -> bool: return worm.shown(), 3.0), "then it bursts out")
	check(not worm.burrows.is_empty(), "through a hole of its own")
	# Its holes are sunk a little into the rock: the ground heaped round one reaches into the face.
	if not worm.burrows.is_empty():
		var hole: Wormlet.Burrow = worm.burrows[0]
		var sink: float = Worm.HOLE_RIM * WormletArt.hole_size(info) * WormletArt.HOLE_SINK
		var back: Vector2i = Vector2i(roundi(-hole.out.x), roundi(-hole.out.y))
		var deepest: float = 0.0
		for poly: PackedVector2Array in Worm.clip_to_air(info, RisoShapes.circle(hole.mouth, 10.0, 16), hole.mouth, 20.0, back, sink):
			for v: Vector2 in poly:
				deepest = maxf(deepest, (v - hole.mouth).dot(-hole.out))
		check(sink > 0.0 and absf(deepest - sink) < 0.05, "its hole sunk %.1f px into the rock (the ground round it reaching %.1f px in)" % [sink, deepest])
	# Its holes are the boss's made smaller to its girth: as tall on it as the boss's on the boss.
	var rim: float = Worm.HOLE_RIM * WormletArt.hole_size(info)
	check(is_equal_approx(rim / (Wormlet.GIRTH * 0.5), Worm.HOLE_RIM / boss_r) and rim < Worm.HOLE_RIM * 0.6, "its hole as tall for its girth as the boss's (rim %.1f px on a %.0f px radius)" % [rim, Wormlet.GIRTH * 0.5])
	if not worm.from_ceiling and worm.face == info.cell_at(stood):
		check(await within(func() -> bool: return player.velocity.y < Wormlet.BUMP * 0.5, 0.2), "up out of the floor under the wizard, it knocks them up")
	player.end_invulnerable()
	check(body.collision_layer != 0 and body.is_in_group(&"hex_target"), "out, it can be struck")
	(body.get_node("Wound") as Wound).hit(1, Vector2.LEFT)
	check(await until(gone(body)), "one blow slays it")
	info._load_level()
	await settle()
	check(placed("wormlet.tscn").filter(func(n: Node) -> bool: return n.get_meta(&"cell") == home).is_empty(), "and it stays slain")


## A plant grown big draws a swarm of small worms round its plot: none for stars, Wormlet.SWARM for
## a white flower and a great bloom; picked, none.
func _swarm() -> void:
	print("the swarm")
	var home: Vector2i = Vector2i(28, 0)
	info.run.plants.erase(home)
	var counts: Array[int] = []
	for tier: int in range(1, 4):
		info.run.plants[home] = {"furthest": Plot.TIERS[tier - 1], "door": false}
		info.coord = home
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		await settle()
		counts.append(placed("wormlet.tscn", true).size())
	check_eq(counts, [Wormlet.SWARM[1], Wormlet.SWARM[2], Wormlet.SWARM[3]] as Array[int], "worms round the plot by what its plant bears: stars, a white flower, a great bloom")
	var plots: Array[Vector2i] = info.world.objects_of(LevelGen.Type.PLOT)
	var near: bool = placed("wormlet.tscn", true).all(func(n: Node) -> bool: return LevelGen.dist(n.get_meta(&"cell"), plots[0]) <= Wormlet.SWARM_REACH)
	check(near, "all within %d cells of the plot" % Wormlet.SWARM_REACH)
	info.run.plants.erase(home)
	info._load_level()
	await settle()
	check(placed("wormlet.tscn", true).is_empty(), "picked, no swarm")


## Stand the wizard on a floor out from pod `pod` (`body`) where it sees them: an empty cell on plain
## rock, no thorns beside it, a few cells out and down from the pod. Whether one was found.
func _stand_in_sight(body: RigidBody2D, pod: SeedPod) -> bool:
	var w: LevelGen = info.world
	var cell: Vector2i = body.get_meta(&"cell")
	for d: int in range(1, 7):
		for drop: int in range(-1, 6):
			var at: Vector2i = cell + Vector2i(pod.way) * d + Vector2i(0, drop)
			if not w.is_valid(at) or w.get_cell(at).type != LevelGen.Type.EMPTY or not w.is_valid(at + Vector2i.DOWN) or w.get_cell(at + Vector2i.DOWN).type != LevelGen.Type.GROUND:
				continue
			var thorny: bool = false
			for n: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i(-1, 1), Vector2i(1, 1)]:
				thorny = thorny or (w.is_valid(at + n) and w.get_cell(at + n).type == LevelGen.Type.SPIKES)
			if thorny:
				continue
			player.set_physics_process(true)
			player.global_position = info.cell_position(at)
			still()
			info.loader.wake_around(body.global_position)
			await settle(6)
			if pod.sees:
				return true
	return false


## A plot in the start level: planted, grown by distance, picked for each reward in turn.
func _plants() -> void:
	print("plants")
	var home: Vector2i = Vector2i(28, 0)
	info.coord = home
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	var plot: Plot = _plot()
	check(plot != null, "the start level has its plot")
	if plot == null:
		return
	player.keyring.set_seeds(1)
	check(plot.can_plant(), "carrying a seed, the plot takes it")
	plot.use()
	check(plot.planted() and player.keyring.seeds() == 0 and plot.tier() == 0, "planted, a sprout, the seed used up")
	check(not plot.can_pick(), "nothing to pick until the wizard has gone away")
	check(RunState.read_save().get("plants", {}).has(home), "the plant is kept in the save")
	# Stars: a place or two away.
	info.run.reached(home + Vector2i(1, 1))
	info.run.reached(home)
	check_eq(plot.tier(), 1, "two places away and back: it bears stars")
	var clusters: int = placed("star_cluster.tscn").size()
	plot.use()
	check(placed("star_cluster.tscn").size() == clusters + 1 and not plot.planted(), "picked: a star cluster, the plot bare again")
	# A skeleton key: further.
	player.keyring.set_seeds(1)
	plot.use()
	info.run.reached(home + Vector2i(Plot.TIERS[1], 0))
	check_eq(plot.tier(), 2, "%d places away: a skeleton key" % Plot.TIERS[1])
	plot.use()
	await settle()
	check(not colored("key.tscn", KeyRing.SKELETON).is_empty(), "picked, the skeleton key lies by it")
	# A hyperspace door: furthest.
	player.keyring.set_seeds(1)
	plot.use()
	info.run.reached(home + Vector2i(0, -Plot.TIERS[2]))
	check_eq(plot.tier(), 3, "%d places away: a hyperspace door" % Plot.TIERS[2])
	plot.use()
	await settle()
	var door_exit: int = Worlds.door(Worlds.kind_of(Hyperspace))
	var doors: Array[Node] = placed("level_exit.tscn").filter(func(n: Node) -> bool: return int(n.get("exit")) == door_exit)
	check(doors.size() == 1 and info.cell_at((doors[0] as Node2D).global_position) == info.plant_door_cell(), "picked, a hyperspace door stands on the plot")
	check_eq(info.here.price(door_exit, info.record()), 0, "free: the plant paid for it")
	check(plot.door() and not plot.can_plant() and not plot.can_pick(), "the plot is the door's now")
	info.travel(door_exit)
	await settle()
	check_eq(info.coord, Worlds.side_at(Worlds.kind_of(Hyperspace), home), "it leads into hyperspace")
	info.travel(MapInfo.Exit.BACK)
	await settle()
	check(info.coord == home and info.cell_at(player.global_position).distance_to(info.plant_door_cell()) < 2.0, "and back out by the door on its plot")
	# Kept through a reload of the place; gone with a new run.
	info._load_level()
	await settle()
	check_eq(placed("level_exit.tscn").filter(func(n: Node) -> bool: return int(n.get("exit")) == door_exit).size(), 1, "the door stands there on every visit")
	info.run.start(28)
	check(info.run.plants.is_empty(), "a new run starts with no plants")


func _plot() -> Plot:
	var plots: Array[Node] = placed("plot.tscn")
	return plots[0] as Plot if not plots.is_empty() else null
