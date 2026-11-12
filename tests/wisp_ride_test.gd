extends TestKit
## A wisp riding a crag gondola's car (Mover, WispArt, Gondola): standing in the car as it runs to
## its next station, it is carried with the car (Mover.carried) and stays on its floor all the way,
## never sunk more than a step of the car's into it nor lifted off it; and its body stays level
## (WispArt), never tipping into a fall as the car rises or sinks under it.
## godot --headless --path . --script res://tests/wisp_ride_test.gd

## How far a wisp's middle stands over a floor (half its collision box), and how far either way it
## may be found from that while the car runs: a step of the car's at its fastest (called, empty),
## which its floor runs ahead of the car's drawing by, and the car's floor tilted by its swing at
## most, SWING_REACH from its middle (where the wisp stands, give or take). A long diagonal at full
## speed swings it to the most it swings.
const REST: float = 16.0
const SWING_REACH: float = 48.0
var slack: float = Gondola.CALL_SPEED / 60.0 + SWING_REACH * sin(Gondola.SWING_MAX)
## How far its body may tip into a fall as it rides (WispArt._dive, 0 to 1): next to nothing.
const LEVEL: float = 0.05


func run() -> void:
	if not needs([&"crags"]):
		finish()
		return
	await boot()
	freeze()
	player.global_position = Vector2(-9000, -9000)
	await go(Vector2i(28, NextWorldDef.band_row(&"crags", 0)))
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
		if art != null:
			worst[1] = maxf(worst[1], art._dive)
	process_frame.connect(watch)
	var arrived: bool = await within(func() -> bool: return not g.running, 30.0)
	process_frame.disconnect(watch)
	check(arrived, "and gets there")
	var rose: float = from_car.y - g.center().y
	check(rose > g.cell_px, "it rises (%.0f px)" % rose)
	check(is_instance_valid(wisp) and mover.grounded and absf((from_wisp.y - wisp.global_position.y) - rose) < slack, "the wisp rides up with it, carried (%.0f px)" % (from_wisp.y - wisp.global_position.y))
	check(worst[0] <= slack, "never sunk into its floor nor lifted off it on the way (at most %.1f px off)" % worst[0])
	check(art != null and worst[1] <= LEVEL, "its body stays level all the way, never tipping into a fall (at most %.2f of one)" % worst[1])
	RunState.delete_save()
	finish()
