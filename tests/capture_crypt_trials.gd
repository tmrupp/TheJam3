extends TestKit
## Stills of the trials in the cemetery's crypts (Crypts.TRIALS) and their prizes: for each level
## looked at, each trial with the wizard's flame lighting it from its middle, and the crypt's prize
## (a skeleton key, a large font or the resurrection rite), a grave mark (Resurrect), and the whole level with the crypts'
## darkness lifted (RisoLight.crypts_dark), to see their layout; it prints each crypt's box (CRYPT)
## and the level's size (LEVEL), for cropping them out. Written as
## trial_<world>_<row>_<n>_<kind>.png, prize_<world>_<row>_<n>_<kind>.png and
## crypts_<world>_<row>.png.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_crypt_trials.gd -- 28,5 3,6
## suite: window

var camera: Camera2D


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	var places: Array[Vector2i] = []
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split(",")
		if parts.size() == 2:
			places.append(Vector2i(int(parts[0]), int(parts[1])))
	if places.is_empty():
		places = [Vector2i(28, NextWorldDef.band_row(&"cemetery", 1)), Vector2i(3, NextWorldDef.band_row(&"cemetery", 2))]
	var first: bool = true
	for at: Vector2i in places:
		await _go(at)
		if first:
			# Wait out the region's title.
			await create_timer(5.0).timeout
			first = false
		for n: int in range(info.world.crypts.size()):
			var crypt: Dictionary = info.world.crypts[n]
			var tag: String = "%d_%d_%d" % [at.x, at.y, n]
			for trial: Dictionary in crypt.get("trials", []):
				var rect: Rect2i = trial["rect"]
				var mid: Vector2 = info.cell_position(rect.get_center())
				player.global_position = mid
				await _look(mid, "trial_%s_%s.png" % [tag, trial["kind"]], 1.6)
			if crypt.has("prize"):
				var v: Vector2i = crypt["prize"]
				player.global_position = info.cell_position(v) + Vector2(-90, 0)
				await _look(info.cell_position(v) + Vector2(0, -40), "prize_%s_%s.png" % [tag, Crypts.prize_kind(info.world.seed_for_colors, n)], 2.2)
			print("CRYPT %s %s" % [tag, crypt["box"]])
		# The whole level with the crypts' darkness lifted, to crop each crypt out of (see CRYPT).
		RisoLight.crypts_dark = false
		await overview_still("crypts_%d_%d.png" % [at.x, at.y], 4)
		RisoLight.crypts_dark = true
		print("LEVEL %d_%d %s" % [at.x, at.y, info.world.size])
	# A grave mark (Resurrect), raised where the wizard stands, in the dark.
	Abilities.set_tier(player, Crypts.RITE, 1)
	player.set_physics_process(true)
	var clear: Array = (info.world.crypts[0]["floors"] as Array).filter(func(v: Vector2i) -> bool:
		return info.world.get_cell(v).type == LevelGen.Type.EMPTY and info.world.get_cell(v + Vector2i.LEFT).type == LevelGen.Type.EMPTY and info.world.get_cell(v + Vector2i.RIGHT).type == LevelGen.Type.EMPTY)
	player.global_position = info.cell_position(clear[0])
	await until(func() -> bool: return player.is_on_floor())
	Abilities.cast(player, &"utility")
	player.set_physics_process(false)
	var mark: Node2D = placed("grave_mark.tscn")[0] as Node2D
	player.global_position = mark.global_position + Vector2(-110, 0)
	await _look(mark.global_position + Vector2(-50, -50), "grave_mark.png", 2.2)
	RunState.delete_save()
	finish()


func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)


## Hold the camera on `at` at `zoom` for a while, then save the still.
func _look(at: Vector2, file: String, zoom: float = 1.0) -> void:
	var was: Vector2 = camera.zoom
	for i: int in range(40):
		camera.global_position = at
		camera.zoom = was * zoom
		camera.reset_smoothing()
		await process_frame
	save_still(file)
	camera.zoom = was
