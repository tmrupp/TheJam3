extends TestKit
## Stills of the crags' towers (CragsArchetype.build_towers): for a few crag levels, the camera on
## each tower, zoomed out to take it all in, and on its top room close up; then, for the first
## watchtower, the wizard stood (physics on) on each ledge of its stair from the bottom up, and on
## its roof, so the climb shows step by step (tower_climb_<i>.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_towers.gd

var camera: Camera2D


func run() -> void:
	window()
	await boot(28)
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.health.max_health = 99
	player.health.health = 99
	var zoom: Vector2 = camera.zoom
	for k: int in [0, 4]:
		info.coord = Vector2i(28, NextWorldDef.band_row(&"crags", k))
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		await settle()
		player.set_physics_process(false)
		var n: int = 0
		for tower: Dictionary in info.world.towers:
			var box: Rect2i = tower["box"]
			var mid: Vector2 = (info.cell_position(box.position) + info.cell_position(box.end - Vector2i.ONE)) * 0.5
			player.global_position = info.cell_position(Vector2i(box.position.x - 1, box.end.y - 2))
			camera.zoom = zoom * 0.42
			await look_at(mid, "tower_%d_%d.png" % [k, n])
			camera.zoom = zoom
			await look_at(info.cell_position(box.position + Vector2i(box.size.x / 2, 2)), "tower_%d_%d_top.png" % [k, n])
			n += 1
		camera.zoom = zoom
	await climb(zoom)
	RunState.delete_save()
	finish()


## The camera on `at` for a moment, then a still of the window as `file`.
func look_at(at: Vector2, file: String) -> void:
	for i: int in range(20):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	save_still(file)


## The tallest watchtower's climb (see the description), in the crag level holding it, the camera
## held on the whole tower: the wizard dropped onto each ledge of its stair in turn, from the
## doorstep up, then onto its roof, and left to land there under physics.
func climb(zoom: Vector2) -> void:
	var best_k: int = -1
	var best: Rect2i = Rect2i()
	for k: int in range(6):
		info.coord = Vector2i(28, NextWorldDef.band_row(&"crags", k))
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		await settle()
		for tower: Dictionary in info.world.towers:
			var box: Rect2i = tower["box"]
			if not tower["hoard"] and box.size.y > best.size.y:
				best_k = k
				best = box
	if best_k < 0:
		return
	info.coord = Vector2i(28, NextWorldDef.band_row(&"crags", best_k))
	info._load_level()
	await settle()
	var tower: Dictionary = info.world.towers.filter(func(t: Dictionary) -> bool: return t["box"] == best)[0]
	var box: Rect2i = tower["box"]
	var ledges: Array = tower["ledges"]
	var steps: Array[Vector2i] = [Vector2i(box.position.x - 1, box.end.y - 2)]
	# Ledges are listed from the bottom floor up, STAIR to a floor.
	for i: int in range(0, ledges.size(), CragsArchetype.STAIR):
		steps.append((ledges[i] as Vector2i) + Vector2i.UP)
	@warning_ignore("integer_division")
	steps.append(Vector2i(box.position.x + box.size.x / 2, box.position.y - 1))
	camera.limit_left = -100000
	camera.limit_top = -100000
	camera.limit_right = 100000
	camera.limit_bottom = 100000
	var cell: float = info.cell_position(Vector2i(1, 0)).x - info.cell_position(Vector2i.ZERO).x
	camera.zoom = Vector2.ONE * (root.get_visible_rect().size.y * 0.85 / (float(box.size.y + 3) * cell))
	var mid: Vector2 = (info.cell_position(box.position + Vector2i.UP) + info.cell_position(box.end - Vector2i.ONE)) * 0.5
	print("climb: crags %d, tower %s" % [best_k, box])
	player.set_physics_process(true)
	for i: int in range(steps.size()):
		player.velocity = Vector2.ZERO
		player.global_position = info.cell_position(steps[i])
		await frames(30)
		print("step %d at %s: on floor %s, cell %s" % [i, steps[i], player.is_on_floor(), info.cell_at(player.global_position)])
		await look_at(mid, "tower_climb_%d.png" % i)
	camera.zoom = zoom
