extends TestKit
## The same view printed at full graphics and at light graphics (RisoPrint.graphics), side by side
## in graphics.png, at 1920x1080, and a close-up of each round the wizard in graphics_close.png.
## godot --path . --windowed --script res://tests/capture_graphics.gd

## How much of the window round the wizard the close-ups show.
const CLOSE: Vector2i = Vector2i(480, 270)


func run() -> void:
	window(Vector2i(1920, 1080))
	await boot(28)
	var riso: RisoPrint = RisoPrint.instance
	for i: int in range(420):
		await process_frame
	paused = true
	var shots: Array[Image] = []
	for mode: StringName in [&"full", &"light"]:
		riso.set_graphics(mode)
		for i: int in range(10):
			await process_frame
		shots.append(root.get_texture().get_image())
	riso.set_graphics(&"full")
	paused = false
	var size: Vector2i = shots[0].get_size()
	var half: Vector2i = size / 2
	var side: Image = Image.create(size.x, half.y, false, shots[0].get_format())
	var close: Image = Image.create(CLOSE.x * 4, CLOSE.y * 2, false, shots[0].get_format())
	var on_screen: Vector2 = root.get_final_transform() * root.canvas_transform * (player.global_position + Vector2(0, -40))
	var corner: Vector2i = (Vector2i(on_screen) - CLOSE / 2).clamp(Vector2i.ZERO, size - CLOSE)
	for k: int in range(2):
		var small: Image = shots[k].duplicate() as Image
		small.resize(half.x, half.y, Image.INTERPOLATE_LANCZOS)
		side.blit_rect(small, Rect2i(Vector2i.ZERO, half), Vector2i(k * half.x, 0))
		var zoom: Image = shots[k].get_region(Rect2i(corner, CLOSE))
		zoom.resize(CLOSE.x * 2, CLOSE.y * 2, Image.INTERPOLATE_NEAREST)
		close.blit_rect(zoom, Rect2i(Vector2i.ZERO, CLOSE * 2), Vector2i(k * CLOSE.x * 2, 0))
	save_still("graphics.png", side)
	save_still("graphics_close.png", close)
	RunState.delete_save()
	finish()
