class_name InkCanvas
extends Node2D
## Ordered list of ink operations, re-issued each time the art changes.
## Mirrors the HTML prototype: ink() lays coverage on a plate and, unless told otherwise,
## lifts the same coverage off the night plate; knock() clears plates to bare paper.

const InkOpScript: GDScript = preload("res://scripts/riso/InkOp.gd")
static var lift_material: CanvasItemMaterial

var _ops: Array[Node2D] = []
var _used: int = 0
## UI mode (the HUD, interaction prompts), for a canvas under RisoPrint.ui_canvas(): knocks also
## lay paper on the UI's paper plate, so the plaques and discs the UI sits on print as paper over
## the scene. Everything else prints as usual, in the UI's own, finer print.
var ui: bool = false


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


## Ink with per-vertex coverage (for fades such as the dash smear).
func ink_graded(plate: int, polys: Array[PackedVector2Array], alphas: Array[PackedFloat32Array], punch: bool = true) -> void:
	if polys.is_empty():
		return
	_emit(RisoPrint.plate_mask(plate), false, 1.0, polys, alphas)
	if punch and plate != RisoPrint.NIGHT:
		_emit(RisoPrint.plate_mask(RisoPrint.NIGHT), true, 1.0, polys, alphas)


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


## A partial knock with per-vertex coverage, for light or mist fading along a shape.
func lift_ink_graded(plates: Array[int], polys: Array[PackedVector2Array], alphas: Array[PackedFloat32Array]) -> void:
	if polys.is_empty():
		return
	var mask: int = 0
	for p: int in plates:
		mask |= RisoPrint.plate_mask(p)
	_emit(mask, true, 1.0, polys, alphas)


func _emit(mask: int, lift: bool, cover: float, polys: Array[PackedVector2Array], alphas: Array[PackedFloat32Array]) -> void:
	var op: Node2D
	if _used < _ops.size():
		op = _ops[_used]
	else:
		op = Node2D.new()
		op.set_script(InkOpScript)
		add_child(op)
		_ops.append(op)
	_used += 1
	op.visible = true
	op.visibility_layer = mask
	op.material = lift_material if lift else null
	op.set("polys", polys)
	op.set("alphas", alphas)
	op.set("cover", cover)
	op.set("lift", lift)
	op.queue_redraw()
