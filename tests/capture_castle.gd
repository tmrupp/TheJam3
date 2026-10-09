extends TestKit
## Stills of a crag level's castle ruins in each of the built stone's looks (RisoTerrain.MASONRY_LOOKS),
## the camera on its biggest keep and zoomed out on the cliff round it; and of a falling stalactite
## (Stalactite): hanging, shaking, falling and growing back.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_castle.gd

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
	var keep: Vector2 = _castle()
	var riso: RisoPrint = RisoPrint.instance
	var zoom: Vector2 = camera.zoom
	for look: StringName in RisoTerrain.MASONRY_LOOKS:
		RisoTerrain.masonry_look = look
		riso.call("_rebuild_ground", info)
		camera.zoom = zoom
		await look_at(keep, "castle_%s.png" % look)
		camera.zoom = zoom * 0.45
		await look_at(keep, "castle_%s_wide.png" % look)
	camera.zoom = zoom
	RisoTerrain.masonry_look = &"sandstone"
	riso.call("_rebuild_ground", info)
	# A stalactite: hanging, shaking, falling, growing back.
	var all: Array[Node] = placed("stalactite.tscn")
	if not all.is_empty():
		var st: Stalactite = all[0] as Stalactite
		var at: Vector2 = st.home + Vector2(0.0, 120.0)
		player.set_physics_process(false)
		player.global_position = st.home + Vector2(Stalactite.REACH * 4.0, 256.0)
		await look_at(at, "stalactite_hanging.png")
		st.state = Stalactite.State.SHAKING
		st.timer = -100.0
		await look_at(at, "stalactite_shaking.png", false)
		st.state = Stalactite.State.FALLING
		st.set_physics_process(false)
		st.drop = 110.0
		st.position = st.home + Vector2(0.0, st.drop)
		await look_at(at, "stalactite_falling.png", false)
		st.state = Stalactite.State.REGROWING
		st.timer = Stalactite.REGROW * 0.5
		st.drop = 0.0
		st.position = st.home
		await look_at(at, "stalactite_regrowing.png", false)
	RunState.delete_save()
	finish()


## The middle of the level's biggest stretch of built stone (its keep), in world pixels.
func _castle() -> Vector2:
	var masonry: Dictionary = info.world.masonry
	var best: Vector2i = Vector2i.ZERO
	var most: int = -1
	for v: Vector2i in masonry:
		var n: int = 0
		for dx: int in range(-4, 5):
			for dy: int in range(-3, 4):
				n += 1 if masonry.has(v + Vector2i(dx, dy)) else 0
		if n > most:
			most = n
			best = v
	return info.cell_position(best)


## The camera on `at` for a moment (or at once, if not `wait`), then a still of the window as `file`.
func look_at(at: Vector2, file: String, wait: bool = true) -> void:
	for i: int in range(20 if wait else 4):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	save_still(file)
