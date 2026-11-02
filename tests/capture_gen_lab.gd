extends TestKit
## Stills of the generation lab (tools/gen_lab): as it opens, on the garden's first row down, and
## after a stroke of rock painted across its sample, to see that the grid follows the edit. Written
## to ../art-captures/riso-frames/gen_lab/.
## godot --path . --windowed --resolution 1600x900 --script res://tests/capture_gen_lab.gd
## suite: window


func run() -> void:
	window(Vector2i(1600, 900))
	var lab: Control = (load("res://tools/gen_lab/gen_lab.tscn") as PackedScene).instantiate() as Control
	root.add_child(lab)
	var status: Label = lab.get("_status")
	check(await until(func() -> bool: return status.text.contains(" settled"), 120000), "the lab lays out its first levels (%s)" % status.text)
	var shown: int = (lab.get("_cells") as Array).size()
	check(shown == int((lab.get("_count") as SpinBox).value), "as many as asked (%d)" % shown)
	await frames(2)
	save_still("gen_lab/opened.png")
	var sample: Image = lab.get("sample")
	for x: int in range(sample.get_width()):
		lab.call("paint", Vector2i(x, sample.get_height() / 2), 1)
	check(String(lab.get("_sample_note").text).contains("edited"), "painting marks the sample edited")
	await until(func() -> bool: return not status.text.contains(" settled"), 5000)
	check(await until(func() -> bool: return status.text.contains(" settled"), 120000), "and the levels are laid out again (%s)" % status.text)
	await frames(2)
	save_still("gen_lab/painted.png")
	lab.queue_free()
	await process_frame
	finish()
