extends TestKit
## The interact prompt's control (RisoPrompt) through a press (up, coming down, landing, landed with
## its ring), on the keyboard (the interact key's cap) along the top and on a pad (the small pad,
## RisoPad.draw_small, its interact button solid) along the bottom, close up in prompt_control.png
## and at the game's own zoom in prompt_control_game.png.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_prompt_control.gd

## The press at each card, left to right.
const TAPS: Array[float] = [0.0, 0.4, 0.75, 1.0]
## How far apart the cards sit, across and down (UI units).
const GAP: Vector2 = Vector2(124, 104)

var camera: Camera2D


## The cards, printed in the UI's canvas as a prompt is, each a prompt of its own (keyboard, pad).
class PromptSheet extends Node2D:
	var prompts: Array[RisoPrompt] = []

	func _ready() -> void:
		for row: int in range(2):
			for i: int in range(TAPS.size()):
				var p: RisoPrompt = RisoPrompt.new()
				add_child(p)
				p.position = Vector2((float(i) - float(TAPS.size() - 1) * 0.5) * GAP.x, float(row) * GAP.y + 118.0)
				prompts.append(p)

	## Print every card at its press, the top row on the keyboard and the bottom on a pad.
	func print_cards() -> void:
		for k: int in range(prompts.size()):
			var p: RisoPrompt = prompts[k]
			var at: Vector2 = Vector2(0, -118)
			RisoPad.pad = k >= TAPS.size()
			p.set_process(false)
			p.canvas.global_transform = p.global_transform
			p.ink.begin()
			var paper: PackedVector2Array = p._card(at, 1.0)
			p.ink.knock(RisoPrint.ALL_PLATES, [paper])
			p.ink.ink(RisoPrint.BLUE, 0.12, [paper], false)
			p._interact(at, 1.0, TAPS[k % TAPS.size()])
			p.ink.finish()
		RisoPad.pad = false


func run() -> void:
	window()
	await boot()
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	camera = main.get_node("Camera2D") as Camera2D
	var base: Vector2 = camera.zoom
	var sheet: PromptSheet = PromptSheet.new()
	info.map_elements.add_child(sheet)
	var spot: Vector2 = player.global_position + Vector2(0, -900)
	sheet.global_position = spot
	player.global_position = Vector2(-9000, -9000)
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	await frames(2)
	for zoom: float in [3.6, 1.0]:
		camera.zoom = base * zoom
		camera.global_position = spot + Vector2(0, GAP.y * 0.5)
		camera.reset_smoothing()
		for i: int in range(3):
			sheet.print_cards()
			await process_frame
		var whole: Image = root.get_texture().get_image()
		var size: Vector2i = Vector2i(1280, 640) if zoom > 1.0 else Vector2i(400, 200)
		var still: Image = whole.get_region(Rect2i((whole.get_size() - size) / 2, size))
		save_still("prompt_control.png" if zoom > 1.0 else "prompt_control_game.png", still)
	finish()
