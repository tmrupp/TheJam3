extends TestKit
## The interact hand (RisoPrompt.draw_hand) on the prompt's paper disc through a tap (up, coming
## down, landing, landed with its ring), whole discs side by side, close up in prompt_hands.png and
## at the game's own zoom in prompt_hands_game.png.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_prompt_hands.gd

## The tap at each disc, left to right.
const TAPS: Array[float] = [0.0, 0.4, 0.75, 1.0]
## How far apart the discs sit (UI units).
const GAP: float = 72.0

var camera: Camera2D


## The discs and their hands, printed in the UI's canvas as a prompt is.
class HandSheet extends Node2D:
	var canvas: Node2D
	var ink: InkCanvas

	func _ready() -> void:
		z_index = 55
		z_as_relative = false
		canvas = RisoPrint.ui_canvas(self)
		canvas.z_index = 55
		canvas.z_as_relative = false
		ink = InkCanvas.new()
		ink.ui = true
		canvas.add_child(ink)

	func _process(_delta: float) -> void:
		canvas.global_transform = global_transform
		ink.begin()
		for i: int in range(TAPS.size()):
			var at: Vector2 = Vector2((float(i) - float(TAPS.size() - 1) * 0.5) * GAP, 0.0)
			var disc: Array[PackedVector2Array] = [RisoShapes.circle(at, 30.0, 28)]
			ink.knock(RisoPrint.ALL_PLATES, disc)
			ink.ink(RisoPrint.BLUE, 0.12, disc, false)
			RisoPrompt.draw_hand(ink, at, 1.0, TAPS[i])
		ink.finish()


func run() -> void:
	window()
	await boot()
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	camera = main.get_node("Camera2D") as Camera2D
	var base: Vector2 = camera.zoom
	var sheet: HandSheet = HandSheet.new()
	info.map_elements.add_child(sheet)
	var spot: Vector2 = player.global_position + Vector2(0, -900)
	sheet.global_position = spot
	player.global_position = Vector2(-9000, -9000)
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	for zoom: float in [4.6, 1.0]:
		camera.zoom = base * zoom
		camera.global_position = spot
		camera.reset_smoothing()
		await frames(3)
		var whole: Image = root.get_texture().get_image()
		var size: Vector2i = Vector2i(1280, 320) if zoom > 1.0 else Vector2i(320, 80)
		var still: Image = whole.get_region(Rect2i((whole.get_size() - size) / 2, size))
		save_still("prompt_hands.png" if zoom > 1.0 else "prompt_hands_game.png", still)
	finish()
