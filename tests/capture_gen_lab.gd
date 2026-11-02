extends TestKit
## Stills of the generation lab (tools/gen_lab): as it opens, on the garden's first row down; after
## a stroke of rock painted across its sample, to see that the grid follows the edit; one of its
## levels looked at whole in the game, then played from there; and the lab again after coming back
## (Backspace), as it was left. Written to ../art-captures/riso-frames/gen_lab/.
## godot --path . --windowed --resolution 1600x900 --script res://tests/capture_gen_lab.gd
## suite: window


func run() -> void:
	window(Vector2i(1600, 900))
	RunState.save_path = "user://%s.save" % test_name()
	var lab: Control = (load("res://tools/gen_lab/gen_lab.tscn") as PackedScene).instantiate() as Control
	root.add_child(lab)
	var status: Label = lab.get("_status")
	check(await until(func() -> bool: return status.text.contains(" settled"), 120000), "the lab lays out its first levels (%s)" % status.text)
	var shown: int = (lab.get("_cells") as Array).size()
	check(shown == int((lab.get("_count") as SpinBox).value), "as many as asked (%d)" % shown)
	await frames(2)
	save_still("gen_lab/opened.png")
	var sample: Image = lab.get("sample")
	@warning_ignore("integer_division")
	var middle: int = sample.get_height() / 2
	for x: int in range(sample.get_width()):
		lab.call("paint", Vector2i(x, middle), 1)
	check(String(lab.get("_sample_note").text).contains("edited"), "painting marks the sample edited")
	await until(func() -> bool: return not status.text.contains(" settled"), 5000)
	check(await until(func() -> bool: return status.text.contains(" settled"), 120000), "and the levels are laid out again (%s)" % status.text)
	await frames(2)
	save_still("gen_lab/painted.png")

	print("in the game")
	var chosen: Dictionary = (lab.get("_cells") as Array)[0]
	lab.set("_chosen", chosen)
	lab.call("_enter_game", true)
	check(await until(func() -> bool: return bool(lab.get("_looking")), 60000), "Look in game opens the game on the level, looking at it whole")
	var info: MapInfo = MapInfo.instance
	check(info != null and info.coord == chosen["at"] and info.world == chosen["level"], "the level played is the one made in the lab (%s)" % [info.coord if info != null else null])
	await frames(30)
	save_still("gen_lab/look.png")
	lab.call("_play_from_look")
	var wizard: Player = Stage.player()
	check(wizard.is_physics_processing() and is_equal_approx(Stage.camera().zoom.x, 0.25), "P plays from there, at the game's own view")
	await frames(60)
	save_still("gen_lab/play.png")
	var back: InputEventKey = InputEventKey.new()
	back.keycode = KEY_BACKSPACE
	back.physical_keycode = KEY_BACKSPACE
	back.pressed = true
	Input.parse_input_event(back)
	check(await until(func() -> bool: return lab.visible and MapInfo.instance == null, 10000), "Backspace closes the game and shows the lab again")
	check((lab.get("_cells") as Array).size() == shown and String(lab.get("_sample_note").text).contains("edited"), "as it was left: its levels and its edited sample")
	check(RunState.save_path == "user://%s.save" % test_name(), "the save path is put back")
	await frames(10)
	save_still("gen_lab/back.png")
	lab.queue_free()
	await process_frame
	RunState.delete_save()
	finish()
