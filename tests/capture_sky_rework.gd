extends TestKit
## Stills of the sky's rework: a balloon becalmed and then full with the level's wind set
## (sky_balloon_0.png, _1); a temple shut with two of its winds entered, then open (sky_temple_0.png,
## _1); the whale free, then trapped with its mouth open (sky_whale_0.png, _1); and its belly, the
## heart at the far end (sky_belly.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_sky_rework.gd

var camera: Camera2D


func run() -> void:
	window()
	await boot(28)
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.health.max_health = 99
	player.health.health = 99
	# A balloon.
	var sky: Vector2i = Vector2i(28, NextWorldDef.band_row(&"sky", 1))
	await _go(sky)
	var balloon: Balloon = placed("balloon.tscn")[0] as Balloon
	player.global_position = balloon.global_position + Vector2(-150.0, 0.0)
	await _look(balloon.global_position + Vector2(0.0, -180.0), "sky_balloon_0.png")
	info.record().vanes_on = {Vector2i(1, 1): 1, Vector2i(2, 1): 1}
	info.record().wind_way = 1
	await _look(balloon.global_position + Vector2(0.0, -180.0), "sky_balloon_1.png")
	# A temple.
	var with_temple: Vector2i = Vector2i.ZERO
	for world: int in range(28, 36):
		for k: int in range(NextWorldDef.BAND):
			var at: Vector2i = Vector2i(world, NextWorldDef.band_row(&"sky", k))
			if with_temple == Vector2i.ZERO and not build(at).objects_of(LevelGen.Type.TEMPLE).is_empty():
				with_temple = at
	await _go(with_temple)
	var temple: Temple = placed("temple.tscn")[0] as Temple
	info.record().temple_progress = 2
	player.global_position = temple.global_position + Vector2(-160.0, 0.0)
	await _look(temple.global_position + Vector2(64.0, -120.0), "sky_temple_0.png")
	info.record().temple_progress = temple.sequence.size()
	temple.use()
	await frames(50)
	await _look(temple.global_position + Vector2(64.0, -120.0), "sky_temple_1.png")
	# The whale, free and trapped.
	var row: int = WhaleHunt.row()
	info.run.whale_x = 28
	await _go(Vector2i(28, row))
	var whale: Whale = placed("whale.tscn")[0] as Whale
	player.global_position = Vector2(-9000, -9000)
	await _look(whale.global_position, "sky_whale_0.png", 0.6)
	for side: int in [-1, 1]:
		var rec: LevelRecord = info.run.record(Vector2i(28 + side, row))
		rec.vanes_on = {Vector2i(1, 1): -side}
		rec.wind_way = -side
	await _go(Vector2i(28, row))
	whale = placed("whale.tscn")[0] as Whale
	player.global_position = Vector2(-9000, -9000)
	await within(func() -> bool: return whale.gape > 0.9, Whale.MOUTH_EVERY + 2.0)
	await _look(whale.global_position, "sky_whale_1.png", 0.6)
	# Its belly.
	await _go(Worlds.side_at(Worlds.kind_of(Belly), Vector2i(28, row)))
	var heart: WhaleHeart = placed("whale_heart.tscn")[0] as WhaleHeart
	player.global_position = heart.global_position + Vector2(-500.0, 40.0)
	await _look(heart.global_position + Vector2(-300.0, -40.0), "sky_belly.png", 0.8)
	RunState.delete_save()
	finish()


## Load place `at` and wait for it.
func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)


## The camera on `at` (zoomed by `zoom`) for a moment, then a still of the window as `file`.
func _look(at: Vector2, file: String, zoom: float = 1.0) -> void:
	var was: Vector2 = camera.zoom
	camera.zoom = was * zoom
	info.loader.wake_around(at)
	for i: int in range(30):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	save_still(file)
	camera.zoom = was
