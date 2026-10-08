extends TestKit
## Stills of a crag level (world 28, the band's second row): where you arrive, the whole cliff
## zoomed out, the castle's decor (battlements, an arrow slit, a banner, a broken column, rubble), a
## door, a toll gate, and the gondola waiting at its open station, mid-run along its circuit (barred,
## its rock-bugs coming along the cable) and at the next station, shut by its gate, with a bug
## climbed in; and a rock-bug on the rock.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_crags.gd

var camera: Camera2D


func run() -> void:
	window()
	await boot(28)
	info.coord = Vector2i(28, NextWorldDef.band_row(&"crags", 1))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.health.max_health = 99
	player.health.health = 99
	await frames(30)
	await look(player.global_position + Vector2(0, -120), "crags_arrival.png")
	# The whole cliff, zoomed out.
	var zoom: Vector2 = camera.zoom
	camera.zoom = zoom * 0.25
	await look(info.cell_position(info.world.size / 2), "crags_whole.png")
	camera.zoom = zoom
	var decor: RisoDecor = main.get_node("RisoDecor") as RisoDecor
	for want: StringName in [&"battlement", &"slit", &"banner", &"column", &"rubble"]:
		for item: Dictionary in decor.items:
			if item["kind"] == want or item.has(String(want)):
				await look(info.cell_position(item["cell"]) + Vector2(0, -60), "crags_%s.png" % want)
				break
	var doors: Array[Node] = placed("door.tscn")
	if not doors.is_empty():
		await look((doors[0] as Node2D).global_position, "crags_door.png")
	# Rock-bugs clinging to the rock: one on a wall or a ceiling, if any are.
	var bugs: Array[Node] = placed("rock_bug.tscn")
	if not bugs.is_empty():
		var pick: RockBug = (bugs[0] as Node2D).get_node("RockBug") as RockBug
		for n: Node in bugs:
			var b: RockBug = (n as Node2D).get_node("RockBug") as RockBug
			if b.normal != Vector2i.DOWN:
				pick = b
				break
		await look(pick.rb.global_position, "crags_rockbug.png")
	# A toll gate shutting a station.
	var tolls: Array[Node] = placed("toll_gate.tscn")
	if not tolls.is_empty():
		await look((tolls[0] as Node2D).global_position + Vector2(-100, -40), "crags_toll.png")
	# The gondola waiting at its open station, then ridden: barred, its wraiths about, and at the
	# next station, shut by its gate.
	var gondolas: Array[Node] = placed("gondola.tscn")
	if not gondolas.is_empty():
		var g: Gondola = gondolas[0] as Gondola
		await look(g.center(), "crags_gondola.png")
		player.global_position = g.center() + Vector2(0, 40)
		player.velocity = Vector2.ZERO
		await until(func() -> bool: return g.has_rider() and player.is_on_floor())
		g.pull()
		await until(func() -> bool: return g.running and g.speed >= Gondola.RIDE_SPEED - 1.0)
		await frames(40)
		await look(g.center(), "crags_gondola_ride.png", false)
		await until(func() -> bool: return not g.running, 40000)
		await look(g.center() + Vector2(g.inner[g.at_station] * 120.0, 0), "crags_gondola_station.png", false)
		await until(func() -> bool: return g.foes.any(func(f: Node2D) -> bool: return (f.get_node("RockBug") as RockBug).mode == RockBug.Mode.CAR), 15000)
		await frames(30)
		await look(g.center(), "crags_gondola_bugs.png", false)
	RunState.delete_save()
	finish()


## The camera on `at` for a moment (or at once, if not `wait`), then a still of the window as `file`.
func look(at: Vector2, file: String, wait: bool = true) -> void:
	for i: int in range(20 if wait else 3):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	save_still(file)
