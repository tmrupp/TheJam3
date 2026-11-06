extends TestKit
## Stills of the practice range (PracticeRange, PracticeTally): its way in as the wizard arrives,
## the tally at the top left (practice_arrival.png); the whole of it from far out
## (practice_overview.png); and its bays close up: the wisps and hoppers (practice_wisps.png), the
## watchers and the shields (practice_watchers.png), the abominations and crossbows
## (practice_crossbows.png), and the nest and the birds (practice_birds.png), the foes held still.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_practice.gd

var camera: Camera2D


func run() -> void:
	window()
	await boot(28)
	MapInfo.debug = true
	Health.invincible = true
	PracticeTally.still = true
	camera = main.get_node("Camera2D") as Camera2D
	info.coord = Worlds.side_at(Worlds.kind_of(PracticeRange), Vector2i(28, 1))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	# Let the place's title pass.
	await frames(200)
	save_still("practice_arrival.png")
	player.get_node("CameraControl").set_process(false)
	player.set_physics_process(false)
	await overview_still("practice_overview.png", 2)
	await _look(Vector2i(24, 9), "practice_wisps.png", 0.7)
	await _look(Vector2i(50, 9), "practice_watchers.png", 0.7)
	await _look(Vector2i(76, 9), "practice_crossbows.png", 0.7)
	await _look(Vector2i(102, 8), "practice_birds.png", 0.7)
	PracticeTally.still = false
	Health.invincible = false
	MapInfo.debug = false
	RunState.delete_save()
	finish()


## The camera on cell `at` (zoomed by `zoom`) for a moment, then a still of the window as `file`.
func _look(at: Vector2i, file: String, zoom: float = 1.0) -> void:
	var was: Vector2 = camera.zoom
	camera.zoom = was * zoom
	var spot: Vector2 = info.cell_position(at)
	info.loader.wake_around(spot)
	for i: int in range(30):
		camera.global_position = spot
		camera.reset_smoothing()
		await process_frame
	save_still(file)
	camera.zoom = was
