class_name SpellMark
extends Node2D
## The mark a damage spell leaves where it was cast, a moment of spell light (accent ink) fading
## over LIFE seconds (Slash, Nova, Push, Lunge): a slash's crescent sweeping round its arc, a nova's
## ring swelling out, a push's gust of streaks blowing out across its cone, or a lunge's thrust
## streaking along its way. It prints on top of whatever it crosses (decor, rock, the night are
## lifted to paper under it first). Placed in the level; a mark given its caster (`caster`) moves with them
## (a slash, a nova and a push go wherever the wizard goes, so they never walk out of their own
## swing), and one without stays where it was cast (a lunge's, the trail of the thrust). An
## institute master's spells (Scholar) leave the same marks in pink, as danger.

## How long it shows (seconds), and how strongly it prints (and lifts what is under it).
const LIFE: float = 0.28
const COVER: float = 0.85
## A slash's crescent: how far out its inner edge is at its thick leading end (a share of its
## reach), and how quickly it thickens from the point at its trailing end (under 1: soon).
const SLASH_INNER: float = 0.5
const SLASH_TAPER: float = 0.6

## What it is (&"slash", &"nova", &"push" or &"lunge"), where it was cast from, the way it points, how far it
## reaches (px) and half its spread (radians).
var kind: StringName = &"slash"
var from: Vector2 = Vector2.ZERO
var dir: Vector2 = Vector2.RIGHT
var reach: float = 100.0
var half: float = PI * 0.33
## The plate it prints on: spell light (accent) for the wizard's, pink for a master's.
var plate: int = RisoPrint.ACCENT
## Who cast it, when it moves with them, and where it was cast from against them; null for a mark
## that stays put.
var caster: Node2D = null
var caster_off: Vector2 = Vector2.ZERO
var age: float = 0.0
var ink: InkCanvas


## A mark of `kind` from `at`, pointing `toward`, `far` px out and `spread` radians either way,
## printed on `plate_`, put in the level; moving with `by` (its caster), if given.
static func leave(kind_: StringName, at: Vector2, toward: Vector2, far: float, spread: float, plate_: int = RisoPrint.ACCENT, by: Node2D = null) -> SpellMark:
	var mark: SpellMark = SpellMark.new()
	mark.kind = kind_
	mark.plate = plate_
	mark.from = at
	mark.caster = by
	if by != null:
		mark.caster_off = at - by.global_position
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
	if caster != null and is_instance_valid(caster):
		from = caster.global_position + caster_off
	var u: float = age / LIFE
	var fade: float = 1.0 - u * u
	ink.begin()
	var shapes: Array[PackedVector2Array] = []
	var base: float = dir.angle()
	match kind:
		&"slash":
			# A crescent sweeping round the arc, thick at its leading edge and drawn out to a point
			# at its trailing one.
			var sweep: float = lerpf(-half, half, minf(1.0, u * 2.2))
			shapes.append(_crescent(from, reach * SLASH_INNER, reach, base - half, base + sweep))
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
	# Over everything under it (the decor, the rock's shading, the night): lifted to paper first,
	# so the mark prints on top rather than sinking into what it crosses.
	ink.lift_ink(RisoPrint.ALL_PLATES, COVER * fade, shapes)
	ink.ink(plate, COVER * fade, shapes)
	ink.finish()


## A crescent round `c` from angle `a0` (its trailing end, a point on radius `r1`) to `a1` (its
## leading end, as thick as from `r0` to `r1`), thickening along the way (SLASH_TAPER).
static func _crescent(c: Vector2, r0: float, r1: float, a0: float, a1: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = maxi(3, ceili(absf(a1 - a0) / 0.08))
	for i: int in range(n + 1):
		out.append(c + Vector2.from_angle(lerpf(a0, a1, float(i) / float(n))) * r1)
	for i: int in range(n - 1, 0, -1):
		var f: float = float(i) / float(n)
		out.append(c + Vector2.from_angle(lerpf(a0, a1, f)) * lerpf(r1, r0, pow(f, SLASH_TAPER)))
	return out


## A band round `c` from radius `r0` to `r1`, from angle `a0` to `a1`.
static func _band(c: Vector2, r0: float, r1: float, a0: float, a1: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = maxi(3, ceili(absf(a1 - a0) / 0.12))
	for i: int in range(n + 1):
		out.append(c + Vector2.from_angle(lerpf(a0, a1, float(i) / float(n))) * r1)
	for i: int in range(n, -1, -1):
		out.append(c + Vector2.from_angle(lerpf(a0, a1, float(i) / float(n))) * r0)
	return out
