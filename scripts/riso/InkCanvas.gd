class_name InkCanvas
extends Node2D
## Ordered list of ink operations, re-issued each time the art changes.
## Mirrors the HTML prototype: ink() lays coverage on a plate and, unless told otherwise,
## lifts the same coverage off the night plate; knock() clears plates to bare paper.

static var lift_material: CanvasItemMaterial
## The rig's shaders (see rig()): ink laid, and ink lifted.
const RIG_SHADER: Shader = preload("res://shaders/ink_rig.gdshader")
const RIG_LIFT_SHADER: Shader = preload("res://shaders/ink_rig_lift.gdshader")
## As many bones as a rig holds (ink_rig.gdshaderinc's RIG_BONES).
const RIG_BONES: int = 96
## Whether rigs place their shapes on the GPU (the vertex shader) or in script (each shape moved
## point by point as it is printed, as all art was before rigs): the two print the same, and the
## script way is kept to compare them by (tests/capture_rig_gif.gd) and to fall back on.
static var rig_on_gpu: bool = true

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

## Whether its punches (ink() punching the night out from under what it lays) also lift the wall's
## ink, the rock plate (BLUE), while the realm prints its open air as a wall (walls_behind): set on
## the things of the game (props, the wizard), so they print in their own inks over the institute's
## dark wood as they do over a night sky, rather than multiplied into it. The lift is put just under
## the canvas, so its own rock ink, laid before or after, is kept.
var punches_wall: bool = false
## Whether the realm being printed lays its rock ink over all its open air, as a back wall (an
## indoor realm, RisoTerrain.INDOOR_REALMS; set by RisoPrint.set_realm).
static var walls_behind: bool = false

## Whether the art never changes an array of shapes once it has handed it over (it hands over its
## rest shapes, built once, again every print): an op given the very same array as last time then
## keeps its shape without comparing it (see _emit).
var keeps_shapes: bool = false

## A rig (rig()): what it prints is drawn once in its rest pose and placed every frame by bones, so
## a figure that only moves or bends is not built, cut into triangles or sent to the renderer again.
## Each shape is bound to one bone (on_bone) or to two along a chain (on_chain); then the warp
## bends the whole figure (set_warp). Bone 0 is the canvas's own space, unmoved.
var rigged: bool = false
## The bones as last posed (basis as x.x, x.y, y.x, y.y; origin), how many this print has handed
## out (bone()), and the binding of what is printed next: a bone, or -1 for the chain, whose key
## and binder say which two bones each point is carried by.
var _bone_basis: PackedVector4Array = PackedVector4Array()
var _bone_origin: PackedVector2Array = PackedVector2Array()
var _bones_used: int = 1
var _bind: int = 0
var _chain_key: int = 0
var _chain: Callable
## The warp (see ink_rig.gdshaderinc): the bow (pivot x, pivot y, turn, length) and the lean
## against a wall (amount, side, knee, soft).
var _warp_bow: Vector4 = Vector4.ZERO
var _warp_wall: Vector4 = Vector4.ZERO
## The rig's materials (ink laid, lifted), its own, as each rig poses its own bones.
var rig_mix: ShaderMaterial
var rig_mul: ShaderMaterial


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
	_bones_used = 1
	_bind = 0


func finish() -> void:
	for i: int in range(_used, _ops.size()):
		var op: RisoInkOp = _ops[i]
		if op.shown:
			op.shown = false
			op.visible = false
	if rigged and rig_on_gpu:
		for m: ShaderMaterial in [rig_mix, rig_mul]:
			m.set_shader_parameter(&"bone_basis", _bone_basis)
			m.set_shader_parameter(&"bone_origin", _bone_origin)
			m.set_shader_parameter(&"warp_bow", _warp_bow)
			m.set_shader_parameter(&"warp_wall", _warp_wall)


## Give the canvas a rig (see rigged), its bones all at rest.
func rig() -> void:
	rigged = true
	_bone_basis.resize(RIG_BONES)
	_bone_origin.resize(RIG_BONES)
	for i: int in range(RIG_BONES):
		_bone_basis[i] = Vector4(1, 0, 0, 1)
		_bone_origin[i] = Vector2.ZERO
	rig_mix = ShaderMaterial.new()
	rig_mix.shader = RIG_SHADER
	rig_mul = ShaderMaterial.new()
	rig_mul.shader = RIG_LIFT_SHADER


## A new bone this print, placed by `xf` (from its own space to the canvas's), and its number.
func bone(xf: Transform2D) -> int:
	var i: int = mini(_bones_used, RIG_BONES - 1)
	_bones_used = i + 1
	_bone_basis[i] = Vector4(xf.x.x, xf.x.y, xf.y.x, xf.y.y)
	_bone_origin[i] = xf.origin
	return i


## Bone `i` placed by `xf` this print (one handed out by bone(), moved again).
func set_bone(i: int, xf: Transform2D) -> void:
	_bone_basis[i] = Vector4(xf.x.x, xf.x.y, xf.y.x, xf.y.y)
	_bone_origin[i] = xf.origin


## What is printed next is drawn in bone `b`'s own space and carried by it (0: the canvas's).
func on_bone(b: int) -> void:
	_bind = b


## What is printed next is carried by up to three bones a point, blended: `binder` names them for a
## point of the rest pose, as Vector3(bone a, bone b, a's share) or as [bone, weight, ...] (up to
## three pairs, the weights summing to 1). `key` tells one chain from another (shapes bound to the
## same points by the same key are not bound again).
func on_chain(key: int, binder: Callable) -> void:
	_bind = -1
	_chain_key = key
	_chain = binder


## The warp this print (see ink_rig.gdshaderinc): the bow, turning points above `pivot` by `turn`
## times their height over it in `length`s, squared; the lean against a wall on `side`, `amount`
## of the way, flat past `knee`, softened over `soft`. Zero turn and amount: none.
func set_warp(pivot: Vector2, turn: float, length: float, amount: float, side: float, knee: float, soft: float) -> void:
	_warp_bow = Vector4(pivot.x, pivot.y, turn, length)
	_warp_wall = Vector4(amount, side, knee, soft)


## `polys` placed as the rig would place them, in script (rig_on_gpu off).
func _posed(polys: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in polys:
		var placed: PackedVector2Array
		if _bind >= 0:
			var b: Vector4 = _bone_basis[_bind]
			placed = Transform2D(Vector2(b.x, b.y), Vector2(b.z, b.w), _bone_origin[_bind]) * poly
		else:
			placed = PackedVector2Array()
			placed.resize(poly.size())
			for k: int in range(poly.size()):
				var v: Vector2 = poly[k]
				var pairs: PackedFloat32Array = RisoInkOp.bones_of(_chain.call(v))
				var p: Vector2 = Vector2.ZERO
				for j: int in range(0, pairs.size(), 2):
					var m: Vector4 = _bone_basis[int(pairs[j])]
					p += (Vector2(m.x * v.x + m.z * v.y, m.y * v.x + m.w * v.y) + _bone_origin[int(pairs[j])]) * pairs[j + 1]
				placed[k] = p
		out.append(_warped(placed))
	return out


## Points bowed and laid against the wall as the warp says (ink_rig.gdshaderinc, in script).
func _warped(poly: PackedVector2Array) -> PackedVector2Array:
	if _warp_bow.z == 0.0 and _warp_wall.x <= 0.001:
		return poly
	var pivot: Vector2 = Vector2(_warp_bow.x, _warp_bow.y)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(poly.size())
	for k: int in range(poly.size()):
		var p: Vector2 = poly[k]
		if _warp_bow.z != 0.0:
			var u: float = clampf((pivot.y - p.y) / _warp_bow.w, 0.0, 1.5)
			if u > 0.0:
				p = pivot + (p - pivot).rotated(_warp_bow.z * u * u)
		if _warp_wall.x > 0.001:
			var s: float = p.x * _warp_wall.y
			if s > _warp_wall.z:
				var flat_by: float = _warp_wall.w * tanh((s - _warp_wall.z) / _warp_wall.w)
				p = p.lerp(Vector2(_warp_wall.y * (_warp_wall.z + flat_by), p.y), _warp_wall.x)
		out[k] = p
	return out


## Lay `cover` (0..1) of ink `plate` inside `polys`.
func ink(plate: int, cover: float, polys: Array[PackedVector2Array], punch: bool = true) -> void:
	if cover <= 0.001 or polys.is_empty():
		return
	_emit(1 << (RisoPrint.PLATE_BIT0 + plate), false, cover, polys, [])
	if punch and plate != RisoPrint.NIGHT:
		_emit(1 << (RisoPrint.PLATE_BIT0 + RisoPrint.NIGHT), true, cover, polys, [], true)
		if punches_wall and walls_behind and plate != RisoPrint.BLUE:
			_emit(1 << (RisoPrint.PLATE_BIT0 + RisoPrint.BLUE), true, cover, polys, [], true, true)


## Several inks printed over one another in the same shapes (the key colours), each in turn.
func ink_overprint(plates: Array[int], cover: float, polys: Array[PackedVector2Array]) -> void:
	for plate: int in plates:
		ink(plate, cover, polys, false)


## Ink with per-vertex coverage (for fades such as the dash smear), all of it scaled by `amount`.
func ink_graded(plate: int, polys: Array[PackedVector2Array], alphas: Array[PackedFloat32Array], punch: bool = true, amount: float = 1.0) -> void:
	if polys.is_empty() or amount <= 0.001:
		return
	_emit(1 << (RisoPrint.PLATE_BIT0 + plate), false, amount, polys, alphas)
	if punch and plate != RisoPrint.NIGHT:
		_emit(1 << (RisoPrint.PLATE_BIT0 + RisoPrint.NIGHT), true, amount, polys, alphas, true)
		if punches_wall and walls_behind and plate != RisoPrint.BLUE:
			_emit(1 << (RisoPrint.PLATE_BIT0 + RisoPrint.BLUE), true, amount, polys, alphas, true, true)


## Ink over a shape already cut into triangles (`indices` into `points`), each point's cover in
## `covers` scaled by `amount`: for big graded shapes worked out once and printed again and again,
## stronger or weaker (the lights' fades). Not punched out of the night.
func ink_mesh(plate: int, points: PackedVector2Array, indices: PackedInt32Array, covers: PackedFloat32Array, amount: float = 1.0) -> void:
	if indices.is_empty() or amount <= 0.001:
		return
	_emit_mesh(1 << (RisoPrint.PLATE_BIT0 + plate), false, amount, points, indices, covers)


## Lift ink off `plates` over a shape already in triangles (see ink_mesh).
func lift_ink_mesh(plates: Array[int], points: PackedVector2Array, indices: PackedInt32Array, covers: PackedFloat32Array, amount: float = 1.0) -> void:
	if indices.is_empty() or amount <= 0.001:
		return
	var mask: int = 0
	for p: int in plates:
		mask |= 1 << (RisoPrint.PLATE_BIT0 + p)
	_emit_mesh(mask, true, amount, points, indices, covers)


## Clear the listed plates to paper inside `polys`.
func knock(plates: Array[int], polys: Array[PackedVector2Array]) -> void:
	if polys.is_empty():
		return
	var mask: int = 0
	for p: int in plates:
		mask |= 1 << (RisoPrint.PLATE_BIT0 + p)
	_emit(mask, true, 1.0, polys, [])
	if ui:
		_emit(RisoPrint.paper_mask(), false, 1.0, polys, [])


## Lift `cover` (0..1) of the ink already on `plates` inside `polys`: a partial knock, for light.
func lift_ink(plates: Array[int], cover: float, polys: Array[PackedVector2Array]) -> void:
	if cover <= 0.001 or polys.is_empty():
		return
	var mask: int = 0
	for p: int in plates:
		mask |= 1 << (RisoPrint.PLATE_BIT0 + p)
	_emit(mask, true, cover, polys, [])


## A partial knock with per-vertex coverage, for light or mist fading along a shape, all of it
## scaled by `amount`.
func lift_ink_graded(plates: Array[int], polys: Array[PackedVector2Array], alphas: Array[PackedFloat32Array], amount: float = 1.0) -> void:
	if polys.is_empty() or amount <= 0.001:
		return
	var mask: int = 0
	for p: int in plates:
		mask |= 1 << (RisoPrint.PLATE_BIT0 + p)
	_emit(mask, true, amount, polys, alphas)


## The next op, set to print on `mask`, laying or lifting, in the canvas or (`under`) just under it.
func _next_op(mask: int, lift: bool, under: bool = false) -> RisoInkOp:
	var op: RisoInkOp
	if _used < _ops.size():
		op = _ops[_used]
	else:
		op = RisoInkOp.new()
		add_child(op)
		_ops.append(op)
	_used += 1
	# Set only what differs: each setting reaches the renderer, for thousands of ops a frame. What
	# was set is kept on the op (shown, layer, mat), as reading it back from the engine costs.
	if not op.shown:
		op.shown = true
		op.visible = true
	if op.layer != mask:
		op.layer = mask
		op.visibility_layer = mask
	if op.under != under:
		op.under = under
		op.z_index = -1 if under else 0
	var material_now: Material
	if rigged and rig_on_gpu:
		material_now = rig_mul if lift else rig_mix
	else:
		material_now = lift_material if lift else null
	if op.mat != material_now:
		op.mat = material_now
		op.material = material_now
	if _px < 0.0:
		_px = absf(get_global_transform().determinant())
	return op


func _emit(mask: int, lift: bool, cover: float, polys: Array[PackedVector2Array], alphas: Array[PackedFloat32Array], again: bool = false, under: bool = false) -> void:
	var op: RisoInkOp = _next_op(mask, lift, under)
	# The same shapes as the last op, or as this op printed last time, are not copied or
	# triangulated again. A graded shape's cover at each point is scaled by the op's cover (and
	# the canvas's coverage) as it prints, so a fade that only grows stronger or weaker keeps it.
	# `again`: the very shapes the last op was just given (ink, then the night it punches out).
	# A rig in script places the shapes here, every print; on the GPU they stay in their rest pose,
	# bound to their bones.
	var bind: int = -2
	var key: int = 0
	if rigged:
		if rig_on_gpu:
			bind = _bind
			key = _chain_key if _bind == -1 else 0
		elif not again:
			polys = _posed(polys)
	var shape: RisoInkOp.Shape
	var fresh: bool = false
	if keeps_shapes and op.shape != null and is_same(op.shape.source, polys) and is_same(op.shape.source_alphas, alphas) and op.shape.bind == bind and op.shape.bind_key == key:
		# The very array it was given last time, from art that never changes one (keeps_shapes).
		_last_shape = op.shape
		op.print_shape(op.shape, cover * coverage, lift, _px)
		return
	if _last_shape != null and (again or _last_shape.same_as(polys, alphas, bind, key)):
		shape = _last_shape
	elif op.shape != null and op.shape.same_as(polys, alphas, bind, key):
		shape = op.shape
	else:
		shape = RisoInkOp.Shape.new(polys, alphas)
		shape.source = polys
		shape.source_alphas = alphas
		shape.bind = bind
		shape.bind_key = key
		if bind == -1:
			shape.binder = _chain
		fresh = true
	_last_shape = shape
	op.print_shape(shape, cover * coverage, lift, _px, fresh and op.shape != _last_shape)


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
