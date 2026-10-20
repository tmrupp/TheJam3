extends TestKit
## Falling stalactites (Stalactite, CragsArchetype.place_stalactites): crag levels have them, each
## hanging from a ceiling of plain rock (not built stone) over open air, clear of the gondola's
## line, and other bands have none. In play: one hangs still, harmless, while the wizard is off to
## the side; with the wizard under it, it shakes, then falls, hurts on touch and shatters on them; it
## grows back and hangs again; and one that misses shatters on the floor below it.
## godot --headless --path . --script res://tests/stalactite_test.gd


func run() -> void:
	generation()
	await falling()
	RunState.delete_save()
	finish()


func generation() -> void:
	print("laid out")
	for k: int in [0, 2, 5]:
		var at: Vector2i = Vector2i(28, NextWorldDef.band_row(&"crags", k))
		var w: LevelGen = build(at)
		var all: Array[Vector2i] = w.objects_of(LevelGen.Type.STALACTITE)
		check(not all.is_empty(), "row %d has stalactites (%d)" % [at.y, all.size()])
		var bad: Array[String] = []
		for v: Vector2i in all:
			var hangs: bool = w.is_ground(v + Vector2i.UP) and not w.masonry.has(v + Vector2i.UP)
			var air: bool = range(1, CragsArchetype.STALACTITE_DROP + 1).all(func(d: int) -> bool: return not w.is_ground(v + Vector2i(0, d)) and not w.keep_clear.has(v + Vector2i(0, d)))
			if not hangs or not air or w.keep_clear.has(v):
				bad.append(str(v))
		check(bad.is_empty(), "each hangs from plain rock over open air, clear of the gondola's line %s" % ", ".join(bad))
	check(build(Vector2i(28, 0)).objects_of(LevelGen.Type.STALACTITE).is_empty(), "the garden has none")


func falling() -> void:
	await boot()
	info.coord = Vector2i(28, NextWorldDef.band_row(&"crags", 1))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.health.max_health = 99
	player.health.health = 99
	var all: Array[Node] = placed("stalactite.tscn")
	check(not all.is_empty(), "the level has stalactites")
	if all.is_empty():
		return
	var st: Stalactite = all[0] as Stalactite
	var cell: float = float(info.tile_map.tile_set.tile_size.y) * info.tile_map.global_scale.y
	print("hanging")
	# The wizard off to one side, held still where they are put.
	player.set_physics_process(false)
	player.global_position = st.home + Vector2(Stalactite.REACH * 3.0, cell * 2.0)
	await frames(30)
	check(st.state == Stalactite.State.HANGING and st.drop == 0.0, "with the wizard off to the side, it hangs still")
	check((st.get_node("CollisionShape2D") as CollisionShape2D).disabled, "and is harmless while it hangs")
	print("falling")
	# Past the untouchable moment after arriving (it runs out while the wizard moves), so the hit tells.
	player.set_physics_process(true)
	check(await until(func() -> bool: return not player.is_invulnerable(), 8000), "the wizard can be hurt")
	player.set_physics_process(false)
	var health: int = player.health.health
	player.global_position = st.home + Vector2(0.0, cell * 2.0)
	check(await until(func() -> bool: return st.state == Stalactite.State.SHAKING), "with the wizard under it, it shakes")
	var shook: int = Time.get_ticks_msec()
	check(await until(func() -> bool: return st.state == Stalactite.State.FALLING), "then falls")
	check(Time.get_ticks_msec() - shook >= int(Stalactite.SHAKE * 1000.0 * 0.8), "after shaking a moment")
	check(await until(func() -> bool: return st.state == Stalactite.State.REGROWING, 5000), "and shatters")
	check(player.health.health < health, "on the wizard, hurting them (%d to %d)" % [health, player.health.health])
	check(st.position == st.home and st.grown() < 0.2, "and grows back from the ceiling")
	# Out from under it while it regrows, or it shakes again the moment it hangs, too soon to see.
	player.global_position = st.home + Vector2(Stalactite.REACH * 3.0, cell * 2.0)
	check(await within(func() -> bool: return st.state == Stalactite.State.HANGING, Stalactite.REGROW + 4.0), "until it hangs whole again")
	print("missing")
	# Under it for a moment, then away: it falls on the floor beneath, and breaks there.
	player.global_position = st.home + Vector2(0.0, cell * 2.0)
	await until(func() -> bool: return st.state == Stalactite.State.SHAKING)
	player.global_position = st.home + Vector2(Stalactite.REACH * 4.0, cell * 2.0)
	health = player.health.health
	var deepest: Array[float] = [0.0]
	var watch: Callable = func() -> void: deepest[0] = maxf(deepest[0], st.drop)
	physics_frame.connect(watch)
	check(await until(func() -> bool: return st.state == Stalactite.State.REGROWING, 6000), "once it has started, it falls anyway, and shatters")
	physics_frame.disconnect(watch)
	var floor_y: float = st.home.y + deepest[0] + Stalactite.LENGTH
	check(deepest[0] >= cell * float(CragsArchetype.STALACTITE_DROP - 1) and info.solid_at(Vector2(st.home.x, floor_y + 40.0)), "on the rock below it (fell %.0f px)" % deepest[0])
	check(player.health.health == health, "missing the wizard")
	player.set_physics_process(true)
