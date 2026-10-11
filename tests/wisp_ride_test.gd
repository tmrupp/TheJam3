extends TestKit
## A wisp riding a crag gondola's car (Mover, WispArt, Gondola): standing in the car as it runs to
## its next station, it is carried with the car (Mover.carried) and stays on its floor all the way,
## never sunk more than a step of the car's into it nor lifted off it; and its body keeps lying
## along the floor (WispArt's path carried with it), never hanging behind it as the car rises.
## godot --headless --path . --script res://tests/wisp_ride_test.gd

## How far a wisp's middle stands over a floor (half its collision box), and how far either way it
## may be found from that while the car runs (a step of the car's at its fastest, which its floor
## runs ahead of the car's drawing by, and the car's swing).
const REST: float = 16.0
const SLACK: float = 12.0
## How far the path its body lies along may stray up or down (px) as it rides, past the height of
## the drop it turns round on (WispArt), which it may well do in the car.
const FLAT: float = 6.0


func run() -> void:
	await boot()
	player.set_physics_process(false)
	player.global_position = Vector2(-9000, -9000)
	info.coord = Vector2i(28, NextWorldDef.band_row(&"crags", 0))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	player.global_position = Vector2(-9000, -9000)
	var g: Gondola = placed("gondola.tscn")[0] as Gondola
	# The wizard hangs over the car, out of it, so the level about it stays awake (chunks sleep out of
	# view) and nobody rides.
	var over: Callable = func() -> void:
		player.global_position = g.center() + Vector2(0.0, -g.cell_px * 2.5)
	over.call()
	await frames(5)
	var wisp: Node2D = Placeables.scene(LevelGen.Type.ENEMY).instantiate() as Node2D
	LevelLoader.arm(wisp, info.here.depth)
	info.map_elements.add_child(wisp)
	wisp.global_position = g.center() + Vector2(40, 20)
	var mover: Mover = wisp.get_node("Mover") as Mover
	await until(func() -> bool: return mover.grounded)
	await frames(10)
	var art: WispArt = null
	for c: Node in wisp.get_children():
		if c is WispArt:
			art = c as WispArt
	var floor_at: Callable = func() -> float: return g.to_global(Vector2.ZERO).y - wisp.global_position.y
	check(absf(float(floor_at.call()) - REST) < 1.0, "a wisp stands on the car's floor (%.1f px over it)" % float(floor_at.call()))
	var from_car: Vector2 = g.center()
	var from_wisp: Vector2 = wisp.global_position
	var next: int = int(g.next_station(g.s, 1)[0])
	g.pull()
	check(g.running and g.bound_for == next, "the car sets off to its next station")
	var worst: Array[float] = [0.0, 0.0]
	var watch: Callable = func() -> void:
		over.call()
		if not is_instance_valid(wisp):
			return
		worst[0] = maxf(worst[0], absf(float(floor_at.call()) - REST))
		if art != null and art._trail.size() > 1:
			var lo: float = INF
			var hi: float = -INF
			for p: Vector2 in art._trail:
				lo = minf(lo, p.y)
				hi = maxf(hi, p.y)
			worst[1] = maxf(worst[1], hi - lo)
	process_frame.connect(watch)
	var arrived: bool = await within(func() -> bool: return not g.running, 30.0)
	process_frame.disconnect(watch)
	check(arrived, "and gets there")
	var rose: float = from_car.y - g.center().y
	check(rose > g.cell_px, "it rises (%.0f px)" % rose)
	check(is_instance_valid(wisp) and mover.grounded and absf((from_wisp.y - wisp.global_position.y) - rose) < SLACK, "the wisp rides up with it, carried (%.0f px)" % (from_wisp.y - wisp.global_position.y))
	check(worst[0] <= SLACK, "never sunk into its floor nor lifted off it on the way (at most %.1f px off)" % worst[0])
	var turn_high: float = 2.0 * WispArt.WISP_DROP_LEN * WispArt.wisp_drop_half()
	check(art != null and worst[1] <= turn_high + FLAT, "its body lies along the floor all the way (or round its turning drop), never hanging behind as it rises (its path at most %.1f px high, a turn's %.1f)" % [worst[1], turn_high])
	RunState.delete_save()
	finish()
