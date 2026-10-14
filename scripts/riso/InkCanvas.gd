class_name InkCanvas
extends Node2D
## Ordered list of ink operations, re-issued each time the art changes.
## Mirrors the HTML prototype: ink() lays coverage on a plate and, unless told otherwise,
## lifts the same coverage off the night plate; knock() clears plates to bare paper.

static var lift_material: CanvasItemMaterial

var _ops: Array[RisoInkOp] = []
var _used: int = 0
## UI mode (the HUD, interaction prompts), for a canvas under RisoPrint.ui_canvas(): knocks also
## lay paper on the UI's paper plate, so the plaques and discs the UI sits on print as paper over
## the scene. Everything else prints as usual, in the UI's own, finer print.
var ui: bool = false
## Fraction of the canvas's ink and clearing to print, so a translucent figure leaves the
## scene beneath it visible on every plate.
var coverage: float = 1.0
## The shapes the last op printed, which the next shares if it prints the same (ink, then the night
## it punches out).
var _last_shape: RisoInkOp.Shape = null
## Its world scale this print (see RisoInkOp.print_shape), read at the first op (-1 until then):
## its ops sit untransformed under it, so they all share it.
var _px: float = -1.0


func _init() -> void:
	if lift_material == null:
		lift_material = CanvasItemMaterial.new()
		lift_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL


func _ready() -> void:
	# Plate viewports render an item only if every ancestor shares its layer.
	visibility_layer |= RisoPrint.all_ink_bits()
	RisoPrint.share_layers(self)


func begin() -> void:
	_used = 0
	_last_shape = null
	_px = -1.0


func finish() -> void:
	for i: int in range(_used, _ops.size()):
		if _ops[i].visible:
			_ops[i].visible = false


## Lay `cover` (0..1) of ink `plate` inside `polys`.
func ink(plate: int, cover: float, polys: Array[PackedVector2Array], punch: bool = true) -> void:
	if cover <= 0.001 or polys.is_empty():
		return
	_emit(RisoPrint.plate_mask(plate), false, cover, polys, [])
	if punch and plate != RisoPrint.NIGHT:
		_emit(RisoPrint.plate_mask(RisoPrint.NIGHT), true, cover, polys, [])


## Several inks printed over one another in the same shapes (the key colours), each in turn.
func ink_overprint(plates: Array[int], cover: float, polys: Array[PackedVector2Array]) -> void:
	for plate: int in plates:
		ink(plate, cover, polys, false)


## Ink with per-vertex coverage (for fades such as the dash smear), all of it scaled by `amount`.
func ink_graded(plate: int, polys: Array[PackedVector2Array], alphas: Array[PackedFloat32Array], punch: bool = true, amount: float = 1.0) -> void:
	if polys.is_empty() or amount <= 0.001:
		return
	_emit(RisoPrint.plate_mask(plate), false, amount, polys, alphas)
	if punch and plate != RisoPrint.NIGHT:
		_emit(RisoPrint.plate_mask(RisoPrint.NIGHT), true, amount, polys, alphas)


## Ink over a shape already cut into triangles (`indices` into `points`), each point's cover in
## `covers` scaled by `amount`: for big graded shapes worked out once and printed again and again,
## stronger or weaker (the lights' fades). Not punched out of the night.
func ink_mesh(plate: int, points: PackedVector2Array, indices: PackedInt32Array, covers: PackedFloat32Array, amount: float = 1.0) -> void:
	if indices.is_empty() or amount <= 0.001:
		return
	_emit_mesh(RisoPrint.plate_mask(plate), false, amount, points, indices, covers)


## Lift ink off `plates` over a shape already in triangles (see ink_mesh).
func lift_ink_mesh(plates: Array[int], points: PackedVector2Array, indices: PackedInt32Array, covers: PackedFloat32Array, amount: float = 1.0) -> void:
	if indices.is_empty() or amount <= 0.001:
		return
	var mask: int = 0
	for p: int in plates:
		mask |= RisoPrint.plate_mask(p)
	_emit_mesh(mask, true, amount, points, indices, covers)


## Clear the listed plates to paper inside `polys`.
func knock(plates: Array[int], polys: Array[PackedVector2Array]) -> void:
	if polys.is_empty():
		return
	var mask: int = 0
	for p: int in plates:
		mask |= RisoPrint.plate_mask(p)
	_emit(mask, true, 1.0, polys, [])
	if ui:
		_emit(RisoPrint.paper_mask(), false, 1.0, polys, [])


## Lift `cover` (0..1) of the ink already on `plates` inside `polys`: a partial knock, for light.
func lift_ink(plates: Array[int], cover: float, polys: Array[PackedVector2Array]) -> void:
	if cover <= 0.001 or polys.is_empty():
		return
	var mask: int = 0
	for p: int in plates:
		mask |= RisoPrint.plate_mask(p)
	_emit(mask, true, cover, polys, [])


## A partial knock with per-vertex coverage, for light or mist fading along a shape, all of it
## scaled by `amount`.
func lift_ink_graded(plates: Array[int], polys: Array[PackedVector2Array], alphas: Array[PackedFloat32Array], amount: float = 1.0) -> void:
	if polys.is_empty() or amount <= 0.001:
		return
	var mask: int = 0
	for p: int in plates:
		mask |= RisoPrint.plate_mask(p)
	_emit(mask, true, amount, polys, alphas)


## The next op, set to print on `mask`, laying or lifting.
func _next_op(mask: int, lift: bool) -> RisoInkOp:
	var op: RisoInkOp
	if _used < _ops.size():
		op = _ops[_used]
	else:
		op = RisoInkOp.new()
		add_child(op)
		_ops.append(op)
	_used += 1
	# Set only what differs: each setting reaches the renderer, for thousands of ops a frame.
	if not op.visible:
		op.visible = true
	if op.visibility_layer != mask:
		op.visibility_layer = mask
	var material_now: Material = lift_material if lift else null
	if op.material != material_now:
		op.material = material_now
	if _px < 0.0:
		_px = absf(get_global_transform().determinant())
	return op


func _emit(mask: int, lift: bool, cover: float, polys: Array[PackedVector2Array], alphas: Array[PackedFloat32Array]) -> void:
	var op: RisoInkOp = _next_op(mask, lift)
	# The same shapes as the last op, or as this op printed last time, are not copied or
	# triangulated again. A graded shape's cover at each point is scaled by the op's cover (and
	# the canvas's coverage) as it prints, so a fade that only grows stronger or weaker keeps it.
	var shape: RisoInkOp.Shape
	if _last_shape != null and _last_shape.same_as(polys, alphas):
		shape = _last_shape
	elif op.shape != null and op.shape.same_as(polys, alphas):
		shape = op.shape
	else:
		shape = RisoInkOp.Shape.new(polys, alphas)
	_last_shape = shape
	op.print_shape(shape, cover * coverage, lift, _px)


func _emit_mesh(mask: int, lift: bool, cover: float, points: PackedVector2Array, indices: PackedInt32Array, covers: PackedFloat32Array) -> void:
	var op: RisoInkOp = _next_op(mask, lift)
	var shape: RisoInkOp.Shape
	if _last_shape != null and _last_shape.same_mesh(points, indices, covers):
		shape = _last_shape
	elif op.shape != null and op.shape.same_mesh(points, indices, covers):
		shape = op.shape
	else:
		shape = RisoInkOp.Shape.mesh(points, indices, covers)
	_last_shape = shape
	op.print_shape(shape, cover * coverage, lift, _px)
