extends Node2D
## A trip through a portal, printed: the wizard's silhouette, in their glow ink like the dash
## afterimages, is drawn thin and pulled into the heart of the departure portal on an inward
## ripple, while the far portal rings outward with a spray of eye-yellow motes as the
## wizard steps out (RisoWizard pops them out tall and springs them back). Spawned by
## RisoPrint.portal_used; presentation only.

const DURATION: float = 1.0
## The departure plays over the first DEPART seconds; the arrival runs the whole time, long
## enough to still be playing once the camera has caught up with a long jump.
const DEPART: float = 0.35
const MOTES_IN: int = 5
const MOTES_OUT: int = 8
## The silhouette's middle over its feet, in art units (RisoProp.ghost_shape).
const MID: float = 19.0
const PAPER_LIFT: Array[int] = [RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK]

var from_center: Vector2
var to_center: Vector2
var from_feet: Vector2
var facing: float = 1.0
var art_scale: float = 3.2
var radius: float = RisoProp.PORTAL_RADIUS
var ring: int = RisoPrint.ACCENT
var t: float = 0.0
var ink: InkCanvas


func _ready() -> void:
	z_index = 3
	add_to_group(&"riso_art")
	ink = InkCanvas.new()
	ink.top_level = true
	add_child(ink)


func _process(delta: float) -> void:
	t += delta
	if t >= DURATION:
		queue_free()
		return
	ink.begin()
	_depart(t / DEPART)
	_arrive(t / DURATION)
	ink.finish()


func _depart(e: float) -> void:
	if e >= 1.0:
		return
	var pull: float = e * e
	var width: float = 1.0 - pull
	if width > 0.08:
		var mid: Vector2 = (from_feet + Vector2(0, -MID * art_scale)).lerp(from_center, pull)
		var at: Transform2D = Transform2D(0.0, Vector2(art_scale * width, art_scale * (1.0 + 0.5 * e)), 0.0, mid) * Transform2D(0.0, Vector2(0, MID))
		ink.ink(RisoPrint.GLOW, 0.8 * (1.0 - e * e), RisoProp.ghost_shape(at, facing))
	var r: float = lerpf(radius - 6.0, 6.0, 1.0 - (1.0 - e) * (1.0 - e))
	var band: Array[PackedVector2Array] = _annulus(from_center, r, 3.0)
	ink.lift_ink(PAPER_LIFT, 0.6 * (1.0 - e), band)
	ink.ink(ring, 0.9 * (1.0 - e), band, false)
	var motes: Array[PackedVector2Array] = []
	for k: int in range(MOTES_IN):
		var a: float = TAU * float(k) / float(MOTES_IN) + e * 2.6
		motes.append(RisoShapes.circle(from_center + Vector2(cos(a), sin(a)) * radius * 1.3 * (1.0 - pull), 2.5 + 1.5 * (1.0 - e), 10))
	ink.ink(RisoPrint.EYE, 0.9, motes)


func _arrive(e: float) -> void:
	if e <= 0.0 or e >= 1.0:
		return
	var out: float = 1.0 - pow(1.0 - e, 3.0)
	var fade: float = 1.0 - e
	ink.ink(ring, 0.25 * fade * fade, [RisoShapes.circle(to_center, lerpf(radius * 0.4, radius, out), 32)], false)
	var band: Array[PackedVector2Array] = _annulus(to_center, lerpf(8.0, radius + 30.0, out), 1.5 + 3.0 * fade)
	ink.lift_ink(PAPER_LIFT, 0.7 * fade, band)
	ink.ink(ring, 0.9 * fade, band, false)
	var motes: Array[PackedVector2Array] = []
	var size: float = 3.4 * fade
	if size > 1.5:
		for k: int in range(MOTES_OUT):
			var a: float = TAU * (float(k) + 0.35) / float(MOTES_OUT)
			motes.append(RisoShapes.circle(to_center + Vector2(cos(a), sin(a)) * lerpf(radius * 0.3, radius + 46.0, out), size, 10))
	ink.ink(RisoPrint.EYE, 0.9, motes)


func _annulus(c: Vector2, r: float, w: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if r - w <= 1.0:
		return out
	for segment: int in range(24):
		var from: Vector2 = Vector2.from_angle(TAU * float(segment) / 24.0)
		var to: Vector2 = Vector2.from_angle(TAU * float(segment + 1) / 24.0)
		out.append(PackedVector2Array([c + from * (r - w), c + from * (r + w), c + to * (r + w), c + to * (r - w)]))
	return out
