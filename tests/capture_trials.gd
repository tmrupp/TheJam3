extends TestKit
## Stills of the classes' trials (TrialPiece, and GlyphSeal's mock seals): each subject's pieces laid
## out in a lecture hall of the institute (world 28, its first level), the whole hall and its floor
## end close up; and a few being done (a cord cut, the sigils caught, the stone shoved along).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_trials.gd

const SUBJECTS: Array[StringName] = [&"hex", &"slash", &"nova", &"push", &"lunge", &"levitate", &"ferry", &"astral", &"awareness", &"rift", &"warp"]

var camera: Camera2D
var hall: int = -1


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	await _go(Vector2i(28, NextWorldDef.first_depth(&"institute")))
	# The level's title card fades first.
	for i: int in range(540):
		await process_frame
	var rec: LevelRecord = info.record()
	for k: int in range(Timetable.PERIODS):
		for i: int in range(info.world.halls.size()):
			if info.subject_of(i) != &"" and info.master_in(i) != null:
				hall = i
				break
		if hall >= 0:
			break
		rec.passing = false
		info.since_bell = SchoolBell.RING_GAP
		info.ring_period()
		await frames(2)
	if hall < 0:
		print("no lecture hall in session")
		finish()
		return
	var box: Rect2i = info.world.halls[hall]["box"]
	for a: StringName in SUBJECTS:
		info.end_trial(false)
		rec.trials.clear()
		for n: Node in get_nodes_in_group(&"scholar"):
			(n as Scholar).calm()
		if a in Relics.MOVES:
			Abilities.set_tier(player, a, 1)
		player.global_position = _at(Vector2i(5, 0))
		info.begin_trial(hall, a)
		await frames(4)
		if a == &"awareness":
			(player.get_node("Awareness") as Awareness).ping()
		await _look(info.cell_position(box.get_center()), "trial_%s.png" % a, 0.95)
		await _look(_at(Vector2i(3, 1)), "trial_%s_close.png" % a, 1.7)
		match a:
			&"slash":
				var cord: TrialPiece = info.trial_pieces[1] as TrialPiece
				cord.struck(&"slash", cord.global_position, Vector2.RIGHT)
				await _look(_at(Vector2i(3, 1)), "trial_slash_cut.png", 1.7, 12)
			&"nova":
				var sigils: Array[TrialPiece] = (info.trial_pieces[0] as TrialPiece).ring
				for k: int in range(3):
					sigils[k].struck(&"nova", player.global_position, Vector2.RIGHT)
				await _look(_at(Vector2i(3, 1)), "trial_nova_some.png", 1.7, 4)
			&"push":
				var stone: TrialPiece = info.trial_pieces[0] as TrialPiece
				stone.struck(&"push", player.global_position, Vector2(signf(stone.goal_x - stone.start_x), 0.0))
				await _look(_at(Vector2i(3, 1)), "trial_push_shoved.png", 1.7, 12)
	info.end_trial(false)
	RunState.delete_save()
	finish()


## A spot in the hall (cells across from its lectern's wall, rows up from its floor).
func _at(at: Vector2i) -> Vector2:
	return info.cell_position(TrialPiece._in(info, hall, at))


func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)


## Hold the camera on `at` at `zoom` for `hold` frames, then save the still.
func _look(at: Vector2, file: String, zoom: float = 1.0, hold: int = 40) -> void:
	var was: Vector2 = camera.zoom
	for i: int in range(hold):
		camera.global_position = at
		camera.zoom = was * zoom
		camera.reset_smoothing()
		await process_frame
	save_still(file)
	camera.zoom = was
