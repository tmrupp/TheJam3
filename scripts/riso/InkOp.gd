extends Node2D
## One ordered print operation on one or more ink plates: either lay ink (coverage in alpha)
## or lift ink (multiply blend, so the plate keeps 1 - coverage of what was there).

var polys: Array[PackedVector2Array] = []
var alphas: Array[PackedFloat32Array] = []
var cover: float = 1.0
var lift: bool = false


func _draw() -> void:
	# Areas are measured in world pixels: the wizard draws in its own small units.
	var px: float = absf(get_global_transform().determinant())
	var flat: Color = Color(1, 1, 1, 1.0 - cover if lift else cover)
	# Every polygon goes into one triangle array, drawn with a single command: one draw call
	# per op and plate however many shapes it holds (the terrain holds thousands).
	var points: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	for i: int in range(polys.size()):
		var poly: PackedVector2Array = polys[i]
		if poly.size() < 3 or absf(_area(poly)) * px < 8.0:
			continue
		var graded: bool = i < alphas.size() and alphas[i].size() == poly.size()
		var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
		if not tris.is_empty():
			var base: int = points.size()
			points.append_array(poly)
			for k: int in range(poly.size()):
				colors.append(Color(1, 1, 1, 1.0 - alphas[i][k] if lift else alphas[i][k]) if graded else flat)
			for idx: int in tris:
				indices.append(base + idx)
			continue
		# Duplicate or self-crossing points defeat the triangulator; let Clipper untangle the
		# outline and fill the pieces flat (graded ink takes its mean cover).
		var c: Color = flat
		if graded:
			var mean: float = 0.0
			for a: float in alphas[i]:
				mean += a
			mean /= float(alphas[i].size())
			c = Color(1, 1, 1, 1.0 - mean if lift else mean)
		for piece: PackedVector2Array in _untangle(poly):
			var piece_tris: PackedInt32Array = Geometry2D.triangulate_polygon(piece)
			if piece_tris.is_empty():
				continue
			var base: int = points.size()
			points.append_array(piece)
			for k: int in range(piece.size()):
				colors.append(c)
			for idx: int in piece_tris:
				indices.append(base + idx)
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colors)


## Simple outlines covering `poly`, holes dropped (they are rare and tiny in practice).
func _untangle(poly: PackedVector2Array) -> Array[PackedVector2Array]:
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
func _area(poly: PackedVector2Array) -> float:
	var a: float = 0.0
	var n: int = poly.size()
	for i: int in range(n):
		a += poly[i].x * poly[(i + 1) % n].y - poly[(i + 1) % n].x * poly[i].y
	return a * 0.5
