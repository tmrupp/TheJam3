extends TestKit
## The bosses' marks side by side (RisoMarks.boss_mark), on the dark of a level: each boss's seal as
## a sealed way on wears it (RisoMarks.boss_seal, the top row), its trophy as a stand holds it
## (RisoMarks.trophy, the middle row), and its mark alone in pink as the map draws it, with no disc
## (the bottom row); close up in boss_marks.png and at the game's own zoom in boss_marks_game.png.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_boss_marks.gd

## The bosses, left to right.
const BOSSES: Array[StringName] = [&"worm", &"bramble", &"golem", &"necromancer", &"beast", &"whale"]
## How far apart the marks sit, across and down (px), and how big each row's are: a seal's radius
## (as on a sealed way on), a trophy's (as on a stand), and the bare mark's unit.
const GAP: Vector2 = Vector2(64, 60)
const SEAL_R: float = 20.0
const TROPHY_R: float = 22.0
const BARE_U: float = 14.0

var camera: Camera2D


## The sheet, printed on a canvas of its own.
class MarkSheet extends Node2D:
	var ink: InkCanvas

	func _ready() -> void:
		ink = InkCanvas.new()
		add_child(ink)

	## Print every row.
	func print_marks() -> void:
		ink.begin()
		for i: int in range(BOSSES.size()):
			var x: float = (float(i) - float(BOSSES.size() - 1) * 0.5) * GAP.x
			RisoMarks.boss_seal(ink, Vector2(x, 0.0), SEAL_R, 1.0, BOSSES[i])
			RisoMarks.trophy(ink, Vector2(x, GAP.y), TROPHY_R, 1.0, BOSSES[i])
			var mark: Array = RisoMarks.boss_mark(BOSSES[i], Vector2(x, GAP.y * 2.0), BARE_U)
			ink.ink(RisoPrint.PINK, 1.0, mark[0], false)
			ink.knock([RisoPrint.PINK], mark[1])
			if not (mark[2] as Array).is_empty():
				ink.ink(RisoPrint.PINK, 1.0, mark[2], false)
		ink.finish()


func run() -> void:
	window()
	await boot()
	freeze()
	player.get_node("CameraControl").set_process(false)
	camera = main.get_node("Camera2D") as Camera2D
	var base: Vector2 = camera.zoom
	var sheet: MarkSheet = MarkSheet.new()
	info.map_elements.add_child(sheet)
	var spot: Vector2 = player.global_position + Vector2(0, -900)
	sheet.global_position = spot
	player.global_position = Vector2(-9000, -9000)
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	await frames(2)
	for zoom: float in [3.0, 1.0]:
		camera.zoom = base * zoom
		camera.global_position = spot + Vector2(0, GAP.y)
		camera.reset_smoothing()
		for i: int in range(3):
			sheet.print_marks()
			await process_frame
		var whole: Image = root.get_texture().get_image()
		var size: Vector2i = Vector2i(1200, 600) if zoom > 1.0 else Vector2i(420, 220)
		var still: Image = whole.get_region(Rect2i((whole.get_size() - size) / 2, size))
		save_still("boss_marks.png" if zoom > 1.0 else "boss_marks_game.png", still)
	finish()
