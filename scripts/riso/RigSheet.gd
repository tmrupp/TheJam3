class_name RigSheet
extends RefCounted
## A figure drawn once, at rest, for a canvas's rig (InkCanvas.rig) to place: its parts (slots),
## each carried by one of the art's joints or by two blended along its height, and its layers of
## shapes, one layer a print. Every point of a shape is marked with the part it belongs to (code),
## so one print holds every part of a layer and the rig still knows which bones carry each point
## (bind, handed to InkCanvas.on_chain). The art asks the canvas for each part's bones in the
## sheet's order every print, so a part's bones are always the same ones (base). ScholarArt keeps a
## sheet a kind, shared by every scholar of the kind.

## Each part: the joint that carries it at height `z` (its rest y, px) and the one at `w`, as
## Vector4(joint, other joint, y, other y); one joint twice for a part that does not bend.
var slots: Array[Vector4] = []
## The first of each part's bones (a canvas hands its bones out in order from 1, and the art asks
## for each part's in turn, so a part's bones are the same every print).
var base: PackedInt32Array = PackedInt32Array()
## Its layers by name: the shapes of each, and each shape's cover (empty: the print's own).
var shapes: Dictionary = {}
var covers: Dictionary = {}
## What tells its chain from another's (InkCanvas.on_chain), and how many sheets there are.
var key: int = 0
static var count: int = 0

func _init() -> void:
	RigSheet.count += 1
	key = 7000 + RigSheet.count

## A new part carried by joint `a`, or bending from `a` at height `ya` to `b` at `yb`.
func slot(a: int, b: int = -1, ya: float = 0.0, yb: float = 1.0) -> int:
	slots.append(Vector4(a, a if b < 0 else b, ya, yb))
	return slots.size() - 1

## The shapes of layer `layer` (none yet: an empty list, kept).
func of(layer: StringName) -> Array[PackedVector2Array]:
	if not shapes.has(layer):
		var polys: Array[PackedVector2Array] = []
		var alphas: Array[PackedFloat32Array] = []
		shapes[layer] = polys
		covers[layer] = alphas
	return shapes[layer]

## Each shape's cover in layer `layer`.
func cover_of(layer: StringName) -> Array[PackedFloat32Array]:
	of(layer)
	return covers[layer]

## Shape `poly` of part `part` goes on layer `layer`, at `cover` (below zero: the print's own,
## for a layer printed flat).
func add(layer: StringName, part: int, poly: PackedVector2Array, cover: float = -1.0) -> void:
	var coded: PackedVector2Array = PackedVector2Array()
	coded.resize(poly.size())
	for i: int in range(poly.size()):
		coded[i] = RigSheet.code(poly[i], part)
	of(layer).append(coded)
	if cover >= 0.0:
		var alphas: PackedFloat32Array = PackedFloat32Array()
		alphas.resize(poly.size())
		alphas.fill(cover)
		cover_of(layer).append(alphas)

## A point marked as part `part`'s: its x rounded to a quarter px, and the part written into
## what is left below that (512ths), where it changes nothing seen. So one shape holds every
## part of a layer, and each point still says whose it is (bind).
static func code(p: Vector2, part: int) -> Vector2:
	return Vector2(floorf(p.x * 4.0 + 0.5) / 4.0 + float(part) / 512.0, p.y)

## The part a point was marked as (code).
static func part_of(p: Vector2) -> int:
	var f: float = p.x * 4.0
	return roundi((f - floorf(f + 0.004)) * 128.0)

## The sheet is drawn: count its bones, and give every layer a peg (a sliver of no area from
## corner to corner of `reach`, round the figure, or of `far` for the layers named in `wide`) so
## the renderer knows how far the figure reaches when its parts move from where they rest.
func close(reach: Rect2, wide: Array[StringName], far: Rect2) -> void:
	var next: int = 1
	for spec: Vector4 in slots:
		base.append(next)
		next += 1 if spec.x == spec.y else 2
	for layer: StringName in shapes:
		var box: Rect2 = far if layer in wide else reach
		var graded: bool = not cover_of(layer).is_empty()
		add(layer, 0, PackedVector2Array([box.position, box.position, box.end]), 0.0 if graded else -1.0)

## The bones that carry rest point `p`, for the rig (InkCanvas.on_chain).
func bind(p: Vector2) -> Variant:
	var part: int = clampi(RigSheet.part_of(p), 0, slots.size() - 1)
	var spec: Vector4 = slots[part]
	if spec.x == spec.y:
		return PackedFloat32Array([base[part], 1.0])
	return Vector3(base[part], base[part] + 1, 1.0 - clampf((p.y - spec.z) / (spec.w - spec.z), 0.0, 1.0))
