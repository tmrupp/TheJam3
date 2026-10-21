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
	## Handed over already in triangles (mesh), as the lights' fades are: never triangulated here.
	var premade: bool = false
	## Its binding in a rig (InkCanvas.rig): -2 none; a bone, its shapes drawn in that bone's space;
	## -1 a chain (`bind_key`), each point carried by the bones `binder` names for it (see
	## InkCanvas.on_chain). And each triangulated point's bones as the rig's shader reads them
	## (RisoInkOp.bone_code).
	var bind: int = -2
	var bind_key: int = 0
	var binder: Callable
	var bone_uv: PackedVector2Array = PackedVector2Array()
	## The array of shapes it was made from, as handed over (see InkCanvas.keeps_shapes).
	var source: Array[PackedVector2Array] = []
	var source_alphas: Array[PackedFloat32Array] = []

	func _init(from_polys: Array[PackedVector2Array], from_alphas: Array[PackedFloat32Array]) -> void:
		polys = from_polys.duplicate(true)
		alphas = from_alphas.duplicate(true)

	## A shape already in triangles: `mesh_indices` into `mesh_points`, each point's cover in
	## `mesh_covers`.
	static func mesh(mesh_points: PackedVector2Array, mesh_indices: PackedInt32Array, mesh_covers: PackedFloat32Array) -> Shape:
		var shape: Shape = Shape.new([] as Array[PackedVector2Array], [] as Array[PackedFloat32Array])
		shape.premade = true
		shape.points = mesh_points
		shape.indices = mesh_indices
		shape.point_alphas = mesh_covers
		return shape

	## Whether these are the same shapes and cover (and, in a rig, the same binding).
	func same_as(other_polys: Array[PackedVector2Array], other_alphas: Array[PackedFloat32Array], other_bind: int = -2, other_key: int = 0) -> bool:
		return not premade and bind == other_bind and bind_key == other_key and polys == other_polys and alphas == other_alphas

	## Whether this is the same mesh (see mesh).
	func same_mesh(mesh_points: PackedVector2Array, mesh_indices: PackedInt32Array, mesh_covers: PackedFloat32Array) -> bool:
		return premade and points == mesh_points and indices == mesh_indices and point_alphas == mesh_covers

	## Work the triangles out for world scale `at_px` (pixels per unit, squared), unless they are.
	## Every polygon goes into one triangle array, drawn with a single command: one draw call per
	## op and plate however many shapes it holds (the terrain holds thousands).
	func triangulate(at_px: float) -> void:
		if premade or at_px == px:
			return
		px = at_px
		points = PackedVector2Array()
		indices = PackedInt32Array()
		point_alphas = PackedFloat32Array()
		bone_uv = PackedVector2Array()
		var any_graded: bool = not alphas.is_empty()
		# A rig's shapes are in their bones' own spaces, whose scale says nothing of their size here.
		var tiny: float = 8.0 if bind == -2 else 0.0
		for i: int in range(polys.size()):
			var poly: PackedVector2Array = polys[i]
			if poly.size() < 3 or absf(RisoInkOp._area(poly)) * px < tiny:
				continue
			var graded: bool = i < alphas.size() and alphas[i].size() == poly.size()
			# Triangles and convex quads (books, planks, most of the decor) need no triangulator.
			var tris: PackedInt32Array
			if poly.size() == 3:
				tris = RisoInkOp.TRI
			elif poly.size() == 4 and RisoInkOp._convex(poly):
				tris = RisoInkOp.QUAD
			else:
				tris = Geometry2D.triangulate_polygon(poly)
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

	## Each point's bones for the rig's shader (see bone_uv), once its triangles are worked out.
	func bind_points() -> void:
		bone_uv = PackedVector2Array()
		if bind == -2:
			return
		bone_uv.resize(points.size())
		if bind >= 0:
			bone_uv.fill(RisoInkOp.bone_code(PackedFloat32Array([bind, 1.0])))
			return
		for k: int in range(points.size()):
			bone_uv[k] = RisoInkOp.bone_code(RisoInkOp.bones_of(binder.call(points[k])))

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


## What it prints (shared with the ops printing the same shapes, see Shape), how much (0..1: a
## flat shape's cover, and what a graded one's cover at each point is scaled by), and whether it
## lifts ink rather than laying it.
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
## Whether it is shown, the plates it is on and its material, as its canvas last set them: kept
## here so a canvas setting them again each print reads a field, not the engine (see
## InkCanvas._next_op).
var shown: bool = true
var layer: int = 1
var mat: Material = null
## Whether it prints just under its canvas (a wall punch, InkCanvas.punches_wall) rather than in it.
var under: bool = false


## Print `new_shape` from now on, redrawing only if that changes what it printed last: other
## shapes (not merely another copy of the same ones), cover, lift, or the world scale it is printed
## at (`px`, its global transform's determinant). `differs`: the shapes are already known to be
## other than the ones it printed (its canvas compared them), so they are not compared again.
func print_shape(new_shape: Shape, new_cover: float, new_lift: bool, px: float, differs: bool = false) -> void:
	var changed: bool = differs or _px < 0.0 or new_cover != cover or new_lift != lift or px != _px
	if new_shape != shape and not changed:
		if shape == null:
			changed = true
		elif new_shape.premade:
			changed = not shape.same_mesh(new_shape.points, new_shape.indices, new_shape.point_alphas)
		else:
			changed = not shape.same_as(new_shape.polys, new_shape.alphas)
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
	if shape.bind != -2 and shape.bone_uv.size() != shape.points.size():
		shape.bind_points()
	var flat: Color = Color(1, 1, 1, 1.0 - cover if lift else cover)
	var colors: PackedColorArray = PackedColorArray()
	if shape.point_alphas.is_empty():
		# Without per-vertex cover, one colour serves every vertex.
		colors.append(flat)
	else:
		colors.resize(shape.point_alphas.size())
		for k: int in range(colors.size()):
			var a: float = shape.point_alphas[k]
			colors[k] = flat if a < 0.0 else Color(1, 1, 1, 1.0 - a * cover if lift else a * cover)
	if shape.bind != -2:
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), shape.indices, shape.points, colors, shape.bone_uv)
	else:
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


## A binder's answer as bones and weights, [bone, weight, ...] (up to three): a Vector3 is two bones
## (a, b, a's share), an array is the pairs themselves.
static func bones_of(found: Variant) -> PackedFloat32Array:
	if found is Vector3:
		var v: Vector3 = found
		return PackedFloat32Array([v.x, v.z, v.y, 1.0 - v.z])
	return found as PackedFloat32Array


## Up to three bones and their weights ([bone, weight, ...]) as the rig's shader reads them from a
## point's UV (ink_rig.gdshaderinc): x = a + 128 b, y = c + 128 wa + 32768 wb, weights in 255ths.
static func bone_code(pairs: PackedFloat32Array) -> Vector2:
	var a: int = int(pairs[0])
	var wa: int = clampi(roundi(pairs[1] * 255.0), 0, 255)
	var b: int = int(pairs[2]) if pairs.size() > 2 else a
	var wb: int = clampi(roundi(pairs[3] * 255.0), 0, 255 - wa) if pairs.size() > 3 else 0
	var c: int = int(pairs[4]) if pairs.size() > 4 else b
	return Vector2(a + 128 * b, c + 128 * wa + 32768 * wb)


## A triangle's corners, and a convex quad's two triangles.
static var TRI: PackedInt32Array = PackedInt32Array([0, 1, 2])
static var QUAD: PackedInt32Array = PackedInt32Array([0, 1, 2, 0, 2, 3])


## Whether a quad is convex: it turns the same way at every corner.
static func _convex(q: PackedVector2Array) -> bool:
	var a: float = (q[1] - q[0]).cross(q[2] - q[1])
	var b: float = (q[2] - q[1]).cross(q[3] - q[2])
	var c: float = (q[3] - q[2]).cross(q[0] - q[3])
	var d: float = (q[0] - q[3]).cross(q[1] - q[0])
	return (a > 0.0 and b > 0.0 and c > 0.0 and d > 0.0) or (a < 0.0 and b < 0.0 and c < 0.0 and d < 0.0)


## Signed shoelace area (local units); shapes under a few pixels are skipped (they may not
## triangulate, and print nothing through the screen anyway).
static func _area(poly: PackedVector2Array) -> float:
	var a: float = 0.0
	var prev: Vector2 = poly[poly.size() - 1]
	for p: Vector2 in poly:
		a += prev.cross(p)
		prev = p
	return a * 0.5
