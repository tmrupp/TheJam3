extends TestKit
## suite: window (reads back the rendered screen, so it needs a real window: full run only)
## The print's imperfections are pinned to the world: with the sheet held still, moving the
## camera must slide the whole printed image by exactly the camera's pixel shift (grain,
## specks and halftone included), not leave the grain fixed to the screen.
## godot --path . --windowed --resolution 1280x720 --script res://tests/riso_pin_test.gd

## The most the print may differ, aligned to the world, between two views of it: the grain and
## the sheet's slow wobble leave about 0.02 even when it moves with the world exactly (aligned to
## the screen instead it differs by about 0.3), so 0.02 itself was right on the edge.
const PINNED_MAX: float = 0.05

## Pixels of `b` deep inside solid rock (the cell and its eight neighbours are ground): the
## parallax background never shows there, so the only change a camera move may cause is a shift.
func rock_pixels(tm: TileMap, view: Transform2D) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var inv: Transform2D = view.affine_inverse()
	# Below the HUD labels (they are screen-fixed by design).
	for y: int in range(230, 600, 3):
		for x: int in range(160, 1120, 3):
			var cell: Vector2i = tm.local_to_map(tm.to_local(inv * Vector2(x, y)))
			var solid: bool = true
			for oy: int in range(-1, 2):
				for ox: int in range(-1, 2):
					if tm.get_cell_source_id(0, cell + Vector2i(ox, oy)) == -1:
						solid = false
			if solid:
				out.append(Vector2i(x, y))
	return out


func diff(a: Image, b: Image, pts: Array[Vector2i], dx: int, dy: int) -> float:
	var total: float = 0.0
	for pt: Vector2i in pts:
		var ca: Color = a.get_pixel(pt.x + dx, pt.y + dy)
		var cb: Color = b.get_pixel(pt.x, pt.y)
		total += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
	return total / float(maxi(1, pts.size()))


func run() -> void:
	window()
	await boot(28)
	var riso: RisoPrint = RisoPrint.instance
	riso.sheet_rate = 0.0
	riso.reprint_on_motion = false
	freeze()
	player.get_node("CameraControl").set_process(false)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	camera.position_smoothing_enabled = false
	camera.global_position = player.global_position
	for i: int in range(20):
		await process_frame
	var base: Vector2 = camera.global_position
	var a: Image = root.get_texture().get_image()
	var pin_a: Vector2 = riso.print_material.get_shader_parameter("pin")
	# Move by a whole number of screen pixels.
	var scale: float = (root.get_final_transform() * root.canvas_transform).get_scale().x
	camera.global_position = base + Vector2(48, 30) / scale
	for i: int in range(6):
		await process_frame
	var b: Image = root.get_texture().get_image()
	var pin_b: Vector2 = riso.print_material.get_shader_parameter("pin")
	var shift: Vector2i = Vector2i((pin_b - pin_a).round())
	var pts: Array[Vector2i] = rock_pixels(main.get_node("TileMap") as TileMap, root.get_final_transform() * root.canvas_transform)
	var pinned: float = diff(a, b, pts, shift.x, shift.y)
	var still: float = diff(a, b, pts, 0, 0)
	print("rock samples ", pts.size(), "  shift ", shift, "  diff when aligned to the world ", snappedf(pinned, 0.0001), "  diff aligned to the screen ", snappedf(still, 0.0001))
	check(pts.size() >= 200, "enough solid rock in view to compare (%d samples)" % pts.size())
	check(shift != Vector2i.ZERO, "the camera move shifts the print's pin")
	check(pinned <= PINNED_MAX and pinned * 4.0 <= still, "the print moves with the world, not the screen")
	finish()
