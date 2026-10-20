extends TestKit
## Ink kept between frames (InkCanvas, RisoInkOp): an op re-issued with the same shapes keeps what
## it printed and is not drawn again; other shapes, another cover, or an array the art changed in
## place since are drawn again; ink and the night it punches out share one triangulation. And the
## shapes RisoShapes places from unit shapes land where working them out point by point puts them.
## No game scene.
## godot --headless --path . --script res://tests/ink_test.gd


func run() -> void:
	await _kept_between_frames()
	_unit_shapes()
	finish()


## A square `s` across at `at`.
static func square(at: Vector2, s: float) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(s, 0), at + Vector2(s, s), at + Vector2(0, s)])


## Print `polys` in blue at `cover` on `canvas` (one op, and the night it punches out), as art does
## each frame, and let it draw.
func print_frame(canvas: InkCanvas, polys: Array[PackedVector2Array], cover: float = 1.0) -> void:
	canvas.begin()
	canvas.ink(RisoPrint.BLUE, cover, polys)
	canvas.finish()
	await process_frame


## Whether `op` is waiting to be drawn again (see RisoInkOp._px).
static func redrawing(op: RisoInkOp) -> bool:
	return op._px < 0.0


func _kept_between_frames() -> void:
	var canvas: InkCanvas = InkCanvas.new()
	root.add_child(canvas)
	var art: Array[PackedVector2Array] = [square(Vector2.ZERO, 40.0), square(Vector2(60, 0), 30.0)]
	await print_frame(canvas, art)
	var ink: RisoInkOp = canvas._ops[0]
	var punch: RisoInkOp = canvas._ops[1]
	check(not redrawing(ink) and not redrawing(punch), "a first print is drawn")
	check(ink.shape == punch.shape, "ink and the night it punches out share their shapes")
	check_eq(ink.shape.indices.size(), 12, "two squares are four triangles")
	var printed: RisoInkOp.Shape = ink.shape

	# The same shapes again, built afresh as art builds them each frame.
	canvas.begin()
	canvas.ink(RisoPrint.BLUE, 1.0, [square(Vector2.ZERO, 40.0), square(Vector2(60, 0), 30.0)] as Array[PackedVector2Array])
	canvas.finish()
	check(not redrawing(ink) and not redrawing(punch), "the same shapes again are not drawn again")
	check(ink.shape == printed, "the op keeps the shapes it printed")
	await process_frame

	# The art's own array, changed in place since it was last printed: still drawn again.
	art[0][2] = Vector2(50, 50)
	canvas.begin()
	canvas.ink(RisoPrint.BLUE, 1.0, art)
	canvas.finish()
	check(redrawing(ink) and redrawing(punch), "an array changed in place is drawn again")
	check(ink.shape.polys[0][2] == Vector2(50, 50) and printed.polys[0][2] == Vector2(40, 40), "each print keeps its own copy of the shapes")
	await process_frame

	# Another cover, the same shapes: drawn again, with the triangles already worked out.
	var triangles: PackedInt32Array = ink.shape.indices
	await print_frame(canvas, art, 0.5)
	check(not redrawing(ink) and is_equal_approx(ink.cover, 0.5), "another cover is drawn")
	check(ink.shape.indices == triangles, "the same shapes keep their triangles")

	# Fewer ops this frame: the spare ones are hidden, and drawn again when used again.
	canvas.begin()
	canvas.finish()
	check(not ink.visible and not punch.visible, "ops not used this frame are hidden")
	await print_frame(canvas, art, 0.5)
	check(ink.visible and punch.visible and not redrawing(ink), "and shown and drawn again when used")
	canvas.queue_free()
	await process_frame


func _unit_shapes() -> void:
	var worst: float = 0.0
	for n: int in [3, 8, 12, 16, 20, 28, 48]:
		for rot: float in [0.0, 0.5, -2.0]:
			var c: Vector2 = Vector2(123.4, -56.7)
			var got: PackedVector2Array = RisoShapes.ellipse(c, 13.0, 7.5, n, rot)
			if rot == 0.0:
				check_eq(got.size(), n, "an ellipse of %d points" % n)
			for i: int in range(n):
				var t: float = TAU * float(i) / float(n)
				var p: Vector2 = Vector2(cos(t) * 13.0, sin(t) * 7.5)
				worst = maxf(worst, got[i].distance_to(c + Vector2(p.x * cos(rot) - p.y * sin(rot), p.x * sin(rot) + p.y * cos(rot))))
	for seg: int in [1, 2, 4, 6]:
		var got: PackedVector2Array = RisoShapes.rrect(10.0, 20.0, 40.0, 25.0, 6.0, seg)
		var corners: Array[Vector2] = [Vector2(44, 26), Vector2(44, 39), Vector2(16, 39), Vector2(16, 26)]
		var starts: Array[float] = [-PI * 0.5, 0.0, PI * 0.5, PI]
		var i: int = 0
		for k: int in range(4):
			for s: int in range(seg + 1):
				var t: float = starts[k] + (PI * 0.5) * float(s) / float(seg)
				worst = maxf(worst, got[i].distance_to(corners[k] + Vector2(cos(t), sin(t)) * 6.0))
				i += 1
		check_eq(got.size(), i, "a rounded rectangle, %d to a corner" % seg)
		var almond: PackedVector2Array = RisoShapes.almond(Vector2(3, 4), 20.0, 6.0, seg + 4)
		for k: int in range(seg + 5):
			var u: float = float(k) / float(seg + 4)
			worst = maxf(worst, almond[k].distance_to(Vector2(3, 4) + Vector2(-20.0 + 40.0 * u, -6.0 * 4.0 * u * (1.0 - u))))
		var sparkle: PackedVector2Array = RisoShapes.sparkle(Vector2(3, 4), 9.0, 1.5, seg)
		check_eq(sparkle.size(), 4 * seg, "a sparkle, %d to a side" % seg)
		worst = maxf(worst, sparkle[seg].distance_to(Vector2(3, 4) + Vector2(13.5, 0)))
	check(worst < 0.0001, "unit shapes land where working them out point by point puts them (off by %.7f px at most)" % worst)
