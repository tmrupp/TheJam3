extends TestKit
## Stills of the tutorial (Tutorial, ControlHint, HintArt): the run's first moment in it, the walk
## card up (tutorial_start.png); the whole hall from far out (tutorial_overview.png); each control
## card up with the wizard by it, on the keyboard (tutorial_<control>.png) and on a pad
## (tutorial_pad_<control>.png); and the start level it comes out into, by its door
## (tutorial_door.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_tutorial.gd

var camera: Camera2D


func run() -> void:
	window()
	await boot(28, true)
	DirAccess.remove_absolute(Tutorial.settings_path)
	Health.invincible = true
	camera = main.get_node("Camera2D") as Camera2D
	await frames(120)
	save_still("tutorial/tutorial_start.png")
	player.get_node("CameraControl").set_process(false)
	player.set_physics_process(false)
	await overview_still("tutorial/tutorial_overview.png", 3)
	for pad: bool in [false, true]:
		ControlHint.pad = pad
		for node: Node in placed("control_hint.tscn"):
			var hint: ControlHint = node as ControlHint
			var name: String = String(hint.action).to_lower()
			player.global_position = hint.global_position + Vector2(-90, 0)
			await _look(hint.global_position + Vector2(0, -120), "tutorial/%s.png" % _file(name, pad), 1.0)
	ControlHint.pad = false
	player.get_node("CameraControl").set_process(true)
	player.set_physics_process(true)
	info.travel(MapInfo.Exit.BACK)
	await settle()
	await frames(200)
	save_still("tutorial/tutorial_door.png")
	Health.invincible = false
	RunState.delete_save()
	DirAccess.remove_absolute(Tutorial.settings_path)
	finish()


func _file(name: String, pad: bool) -> String:
	return ("tutorial_pad_%s" if pad else "tutorial_%s") % name


## The camera on `spot` (zoomed by `zoom`) while the card there rises, then a still as `file`.
func _look(spot: Vector2, file: String, zoom: float = 1.0) -> void:
	var was: Vector2 = camera.zoom
	camera.zoom = was * zoom
	info.loader.wake_around(spot)
	for i: int in range(50):
		camera.global_position = spot
		camera.reset_smoothing()
		await process_frame
	save_still(file)
	camera.zoom = was
