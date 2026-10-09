extends TestKit
## Stills of a falling stalactite in a crag level (world 28, the band's second row): hanging from
## its ceiling, shaking with the wizard under it, falling on them, and just shattered.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_stalactite.gd

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
	var all: Array[Node] = placed("stalactite.tscn")
	if all.is_empty():
		finish()
		return
	var st: Stalactite = all[0] as Stalactite
	var cell: float = float(info.tile_map.tile_set.tile_size.y) * info.tile_map.global_scale.y
	var middle: Vector2 = st.home + Vector2(0.0, cell * 1.2)
	# Hanging, the wizard off to the side.
	player.set_physics_process(false)
	player.global_position = st.home + Vector2(Stalactite.REACH * 3.0, cell * 2.0)
	await frames(30)
	await look(middle, "stalactite_hanging.png")
	# The wizard under it: it shakes, then falls. Slowed, and held still for each still, so the
	# moment is caught even where the window draws slowly.
	Engine.time_scale = 0.2
	player.global_position = st.home + Vector2(0.0, cell * 2.0)
	await until(func() -> bool: return st.state == Stalactite.State.SHAKING)
	await frames(2)
	await held(st, middle, "stalactite_shaking.png")
	await until(func() -> bool: return st.state == Stalactite.State.FALLING and st.drop > cell * 0.4)
	await held(st, middle, "stalactite_falling.png")
	await until(func() -> bool: return st.state == Stalactite.State.REGROWING, 5000)
	await look(middle, "stalactite_shattered.png", false)
	Engine.time_scale = 1.0
	player.set_physics_process(true)
	RunState.delete_save()
	finish()


## A still of `st` held where it is (its own motion stopped while the still is taken).
func held(st: Stalactite, at: Vector2, file: String) -> void:
	st.set_physics_process(false)
	await look(at, file, false)
	st.set_physics_process(true)


## Point the camera at `at` and save a still of it as `file` (letting the world settle a moment
## first when `wait`, or catching it as it is).
func look(at: Vector2, file: String, wait: bool = true) -> void:
	for i: int in range(20 if wait else 2):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	save_still(file)
