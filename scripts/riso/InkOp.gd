extends Node2D
class_name RisoInkOp
## One ordered print operation on one or more ink plates: either lay ink (coverage in alpha)
## or lift ink (multiply blend, so the plate keeps 1 - coverage of what was there).


## The shapes an op prints, and their triangles once worked out. Ops printing the same shapes
## share one (ink, and the night it punches out of the plate below), so they are triangulated
## once; and an op keeps its shape while the art issues the same shapes again, as most art does
## frame after frame (the still parts of a moving figure, light while the wizard stands still).
class Shape extends RefCounted:
	## Its own copy of the shapes (art may reuse its arrays), and per-vertex cover by polygon
	## (none for flat ink).
	var polys: Array[PackedVector2Array]
	var alphas: Array[PackedFloat32Array]
	## The triangles, for the world scale they were worked out at (px; -1 until then): the points,
	## the triangles' indices into them, and each point's cover (-1 where the op's own cover
	## applies; empty when it applies to every point).
	var px: float = -1.0
	var points: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var point_alphas: PackedFloat32Array = PackedFloat32Array()

	func _init(from_polys: Array[PackedVector2Array], from_alphas: Array[PackedFloat32Array]) -> void:
		polys = from_polys.duplicate(true)
		alphas = from_alphas.duplicate(true)

	## Whether these are the same shapes and cover.
	func same_as(other_polys: Array[PackedVector2Array], other_alphas: Array[PackedFloat32Array]) -> bool:
		return polys == other_polys and alphas == other_alphas

	## Work the triangles out for world scale `at_px` (pixels per unit, squared), unless they are.
	## Every polygon goes into one triangle array, drawn with a single command: one draw call per
	## op and plate however many shapes it holds (the terrain holds thousands).
	func triangulate(at_px: float) -> void:
		if at_px == px:
			return
		px = at_px
		points = PackedVector2Array()
		indices = PackedInt32Array()
		point_alphas = PackedFloat32Array()
		var any_graded: bool = not alphas.is_empty()
		for i: int in range(polys.size()):
			var poly: PackedVector2Array = polys[i]
			if poly.size() < 3 or absf(RisoInkOp._area(poly)) * px < 8.0:
				continue
			var graded: bool = i < alphas.size() and alphas[i].size() == poly.size()
			var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
			if not tris.is_empty():
				_add(poly, tris)
				if graded:
					point_alphas.append_array(alphas[i])
				elif any_graded:
					_add_cover(poly.size(), -1.0)
				continue
			# Duplicate or self-crossing points defeat the triangulator; let Clipper untangle the
			# outline and fill the pieces flat (graded ink takes its mean cover).
			var mean: float = -1.0
			if graded:
				mean = 0.0
				for a: float in alphas[i]:
					mean += a
				mean /= float(alphas[i].size())
			for piece: PackedVector2Array in RisoInkOp._untangle(poly):
				var piece_tris: PackedInt32Array = Geometry2D.triangulate_polygon(piece)
				if piece_tris.is_empty():
					continue
				_add(piece, piece_tris)
				if any_graded:
					_add_cover(piece.size(), mean)

	func _add(poly: PackedVector2Array, tris: PackedInt32Array) -> void:
		var base: int = points.size()
		points.append_array(poly)
		if base == 0:
			indices.append_array(tris)
			return
		for idx: int in tris:
			indices.append(base + idx)

	func _add_cover(count: int, value: float) -> void:
		for k: int in range(count):
			point_alphas.append(value)


## What it prints (shared with the ops printing the same shapes, see Shape), how much (0..1), and
## whether it lifts ink rather than laying it.
var shape: Shape = null
var cover: float = 1.0
var lift: bool = false
## The shapes it prints, and their per-vertex cover (none for flat ink).
var polys: Array[PackedVector2Array]:
	get:
		return shape.polys if shape != null else [] as Array[PackedVector2Array]
var alphas: Array[PackedFloat32Array]:
	get:
		return shape.alphas if shape != null else [] as Array[PackedFloat32Array]
## The world scale it was last drawn at (see _draw), or -1 while a redraw is waiting.
var _px: float = -1.0


## Print `new_shape` from now on, redrawing only if that changes what it printed last: other
## shapes (not merely another copy of the same ones), cover, lift, or the world scale it is printed
## at (`px`, its global transform's determinant).
func print_shape(new_shape: Shape, new_cover: float, new_lift: bool, px: float) -> void:
	var changed: bool = _px < 0.0 or new_cover != cover or new_lift != lift or px != _px
	if new_shape != shape and not changed:
		changed = shape == null or not shape.same_as(new_shape.polys, new_shape.alphas)
	shape = new_shape
	cover = new_cover
	lift = new_lift
	if changed:
		_px = -1.0
		queue_redraw()


func _draw() -> void:
	# Areas are measured in world pixels: the wizard draws in its own small units.
	var px: float = absf(get_global_transform().determinant())
	_px = px
	if shape == null:
		return
	shape.triangulate(px)
	if shape.indices.is_empty():
		return
	var flat: Color = Color(1, 1, 1, 1.0 - cover if lift else cover)
	var colors: PackedColorArray = PackedColorArray()
	if shape.point_alphas.is_empty():
		# Without per-vertex cover, one colour serves every vertex.
		colors.append(flat)
	else:
		colors.resize(shape.point_alphas.size())
		for k: int in range(colors.size()):
			var a: float = shape.point_alphas[k]
			colors[k] = flat if a < 0.0 else Color(1, 1, 1, 1.0 - a if lift else a)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), shape.indices, shape.points, colors)


## Simple outlines covering `poly`, holes dropped (they are rare and tiny in practice).
static func _untangle(poly: PackedVector2Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var pieces: Array[PackedVector2Array] = Geometry2D.merge_polygons(poly, PackedVector2Array())
	var outer_cw: bool = false
	var biggest: float = -1.0
	for piece: PackedVector2Array in pieces:
		var a: float = absf(_area(piece))
		if a > biggest:
			biggest = a
			outer_cw = Geometry2D.is_polygon_clockwise(piece)
	for piece: PackedVector2Array in pieces:
		if piece.size() >= 3 and Geometry2D.is_polygon_clockwise(piece) == outer_cw:
			out.append(piece)
	return out


## Signed shoelace area (local units); shapes under a few pixels are skipped (they may not
## triangulate, and print nothing through the screen anyway).
static func _area(poly: PackedVector2Array) -> float:
	var a: float = 0.0
	var prev: Vector2 = poly[poly.size() - 1]
	for p: Vector2 in poly:
		a += prev.cross(p)
		prev = p
	return a * 0.5
