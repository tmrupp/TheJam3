extends TestKit
## The frame counter (RisoPrint.fps_label): in debug runs it shows frames a second and the frame's
## time in the window's top right corner; switched off on the F7 panel, or out of debug runs, it is
## hidden.
## godot --headless --path . --script res://tests/fps_counter_test.gd


func run() -> void:
	await boot(28)
	var riso: RisoPrint = RisoPrint.instance
	MapInfo.debug = false
	for i: int in range(10):
		await process_frame
	check(not riso.fps_label.visible, "hidden out of debug runs")
	MapInfo.debug = true
	for i: int in range(60):
		await process_frame
	check(riso.fps_label.visible and riso.fps_label.text.contains("fps") and riso.fps_label.text.contains("ms"), "in debug runs it counts frames: %s" % riso.fps_label.text)
	riso.show_fps = false
	await process_frame
	check(not riso.fps_label.visible, "switched off on the F7 panel, it hides")
	riso.show_fps = true
	MapInfo.debug = false
	RunState.delete_save()
	finish()
