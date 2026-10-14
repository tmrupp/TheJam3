class_name SpellMark
extends Node2D
## The mark a damage spell leaves where it was cast, a moment of spell light (accent ink) fading
## over LIFE seconds (Slash, Nova, Push, Lunge): a slash's crescent sweeping round its arc, a nova's
## ring swelling out, a push's gust of streaks blowing out across its cone, or a lunge's thrust
## streaking along its way. Placed in the level, so it stays where it was cast. An institute
## master's spells (Scholar) leave the same marks in pink, as danger.

## How long it shows (seconds).
const LIFE: float = 0.28

## What it is (&"slash", &"nova", &"push" or &"lunge"), where it was cast from, the way it points, how far it
## reaches (px) and half its spread (radians).
var kind: StringName = &"slash"
var from: Vector2 = Vector2.ZERO
var dir: Vector2 = Vector2.RIGHT
var reach: float = 100.0
var half: float = PI * 0.33
## The plate it prints on: spell light (accent) for the wizard's, pink for a master's.
var plate: int = RisoPrint.ACCENT
var age: float = 0.0
var ink: InkCanvas


## A mark of `kind` from `at`, pointing `toward`, `far` px out and `spread` radians either way,
## printed on `plate_`, put in the level.
static func leave(kind_: StringName, at: Vector2, toward: Vector2, far: float, spread: float, plate_: int = RisoPrint.ACCENT) -> SpellMark:
	var mark: SpellMark = SpellMark.new()
	mark.kind = kind_
	mark.plate = plate_
	mark.from = at
	mark.dir = toward
	mark.reach = far
	mark.half = spread
	var level: Node = MapInfo.instance.map_elements if MapInfo.instance != null and is_instance_valid(MapInfo.instance.map_elements) else null
	if level != null:
		level.add_child(mark)
	return mark


func _ready() -> void:
	ink = InkCanvas.new()
	ink.top_level = true
	ink.z_as_relative = false
	ink.z_index = 3
	add_child(ink)


func _process(delta: float) -> void:
	age += delta
	if age >= LIFE:
		queue_free()
		return
	var u: float = age / LIFE
	var fade: float = 1.0 - u * u
	ink.begin()
	var shapes: Array[PackedVector2Array] = []
	var base: float = dir.angle()
	match kind:
		&"slash":
			# A crescent sweeping round the arc, thick at its leading edge.
			var sweep: float = lerpf(-half, half, minf(1.0, u * 2.2))
			shapes.append(_band(from, reach * 0.55, reach, base - half, base + sweep))
		&"nova":
			var r: float = reach * (0.35 + 0.65 * sqrt(u))
			shapes.append(_band(from, r - 10.0, r, 0.0, TAU))
			for i: int in range(8):
				var a: float = TAU * float(i) / 8.0 + 0.2
				var d: Vector2 = Vector2.from_angle(a)
				shapes.append(Spider.strand(from + d * r * 0.55, from + d * r * 0.9, 4.0))
		&"push":
			for i: int in range(5):
				var a: float = base + lerpf(-half, half, (float(i) + 0.5) / 5.0)
				var d: Vector2 = Vector2.from_angle(a)
				var near: float = reach * (0.15 + 0.6 * u)
				shapes.append(Spider.strand(from + d * near, from + d * (near + reach * 0.35), 5.0 * (1.0 - u) + 1.5))
		&"lunge":
			# A thrust: a tapering streak along the way, its point running out ahead.
			var tip: Vector2 = from + dir * reach * minf(1.0, u * 2.5)
			var back: Vector2 = from + dir * reach * maxf(0.0, u * 1.6 - 0.4)
			var n: Vector2 = dir.orthogonal()
			shapes.append(PackedVector2Array([back + n * 1.5, tip - dir * 14.0 + n * 6.0, tip, tip - dir * 14.0 - n * 6.0, back - n * 1.5]))
	ink.ink(plate, 0.85 * fade, shapes)
	ink.finish()


## A band round `c` from radius `r0` to `r1`, from angle `a0` to `a1`.
static func _band(c: Vector2, r0: float, r1: float, a0: float, a1: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = maxi(3, ceili(absf(a1 - a0) / 0.12))
	for i: int in range(n + 1):
		out.append(c + Vector2.from_angle(lerpf(a0, a1, float(i) / float(n))) * r1)
	for i: int in range(n, -1, -1):
		out.append(c + Vector2.from_angle(lerpf(a0, a1, float(i) / float(n))) * r0)
	return out
