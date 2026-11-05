extends TestKit
## Stills of the tutorial (Tutorial, ControlHint, HintArt): the run's first moment in it, the walk
## card up (tutorial_start.png); the whole hall from far out (tutorial_overview.png); each control
## card up with the wizard by it, on the keyboard (tutorial_<control>.png) and on a pad
## (tutorial_pad_<control>.png); the trophy stands, the first boss's trophy set, the second's
## carried, and a trophy waiting to be picked up (tutorial_trophies.png); a relic unlock lying there
## and two trailing the wizard (tutorial_unlock.png); the card of a won run
## (tutorial_won.png); and the start level it comes out into, by its door (tutorial_door.png).
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
	await _trophies()
	player.get_node("CameraControl").set_process(true)
	player.set_physics_process(true)
	info.travel(MapInfo.Exit.BACK)
	await settle()
	await frames(200)
	save_still("tutorial/tutorial_door.png")
	# The card of a won run, shown without ending the run (win_run would go back to the menu).
	info.won = true
	info.run_ending = MapInfo.WIN_SECONDS
	await frames(30)
	save_still("tutorial/tutorial_won.png")
	Health.invincible = false
	RunState.delete_save()
	DirAccess.remove_absolute(Tutorial.settings_path)
	finish()


## The stands: the first boss's trophy set, the second's carried (its stand glows), and a trophy
## waiting to be picked up over the floor before them.
func _trophies() -> void:
	var bosses: Array[StringName] = Bands.bosses()
	info.run.trophies[bosses[0]] = Trophy.SET
	info.run.trophies[bosses[1]] = Trophy.CARRIED
	var stands: Array[Node] = placed("trophy_stand.tscn")
	stands.sort_custom(func(a: Node, b: Node) -> bool: return (a as Node2D).global_position.x < (b as Node2D).global_position.x)
	var first: Vector2 = (stands[0] as Node2D).global_position
	var last: Vector2 = (stands[stands.size() - 1] as Node2D).global_position
	var waiting: Trophy = MapInfo.TROPHY.instantiate() as Trophy
	waiting.boss = bosses[0]
	info.map_elements.add_child(waiting)
	waiting.global_position = first + Vector2(-260, -40)
	player.global_position = last + Vector2(200, 0)
	await _look((first + last) * 0.5 + Vector2(-80, -120), "tutorial/tutorial_trophies.png", 1.0)
	waiting.queue_free()
	# A relic unlock lying by the stands, and two carried, trailing the wizard.
	var at: Vector2 = first + Vector2(-140, -60)
	info._spawn_dropped_key(info.record().drop_key(at, KeyRing.UNLOCK), at, KeyRing.UNLOCK)
	player.keyring.set_unlocks(2)
	player.global_position = first + Vector2(200, 0)
	await _look(first + Vector2(40, -100), "tutorial/tutorial_unlock.png", 1.6)
	player.keyring.set_unlocks(0)
	info.run.trophies.clear()


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
