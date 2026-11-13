extends TestKit
## Stills of the barriers (Barriers), one of each kind found over a few worlds and garden rows: the
## pocket, its thorns, its reward and the mark by its mouth (barriers/<move>.png), lit, the wizard
## out of the way.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_barriers.gd

const WORLDS: Array[int] = [28, 7, 99, 1003, 41, 63, 5, 17, 230, 77]


func run() -> void:
	window()
	var found: Dictionary = {}
	for world: int in WORLDS:
		for row: int in range(-Bands.garden_rows(), Bands.garden_rows() + 1):
			if Bosses.gate_at(row) != &"" or row == 0:
				continue
			var w: LevelGen = build(Vector2i(world, row))
			if w == null:
				continue
			for b: Barrier in w.barriers:
				if not found.has(int(b.kind)):
					found[int(b.kind)] = Vector2i(world, row)
	await boot(28)
	Health.invincible = true
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	for kind: int in found:
		await go(found[kind])
		player.set_physics_process(false)
		var b: Barrier = info.world.barriers[0]
		var middle: Vector2 = Vector2.ZERO
		for c: Vector2i in b.open:
			middle += info.cell_position(c)
		middle /= float(b.open.size())
		player.global_position = middle + Vector2(0, -2000)
		camera.limit_left = -10000000
		camera.limit_top = -10000000
		camera.limit_right = 10000000
		camera.limit_bottom = 10000000
		camera.global_position = middle
		camera.reset_smoothing()
		info.loader.wake_around(middle)
		info.ink_whole_map()
		await frames(30)
		save_still("barriers/%s.png" % Barriers.MOVE[kind])
	finish()
