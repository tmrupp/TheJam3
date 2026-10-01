extends Node2D
## Small life, only where the camera looks: paper-white fireflies drifting over the flowers and
## grass (fading in and out, never yellow: yellow is reward), and drops
## of ink falling from the ceiling drips and splashing where they land.

const FIREFLIES: int = 14
const DRIPS: int = 6
const KNOCK_ALL: Array[int] = [RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW]

var decor: Node2D
var light: Node2D
var ink: InkCanvas
var t: float = 0.0
## How many of each were drawn last frame (for tests).
var counts: Dictionary = {"fireflies": 0, "moths": 0, "drops": 0}


func _ready() -> void:
	z_index = 4
	z_as_relative = false
	add_to_group(&"riso_art")
	visible = RisoPrint.is_on()
	ink = InkCanvas.new()
	add_child(ink)


func _process(delta: float) -> void:
	t += delta
	ink.begin()
	counts = {"fireflies": 0, "moths": 0, "drops": 0}
	var cam: Camera2D = get_viewport().get_camera_2d()
	var info: MapInfo = MapInfo.instance
	if cam == null or info == null or info.world == null or decor == null:
		ink.finish()
		return
	var view: Rect2 = RisoLight.view_rect(self, cam).grow(80.0)
	_fireflies(view)
	_drops(view)
	ink.finish()


func _fireflies(view: Rect2) -> void:
	var spots: PackedVector2Array = decor.get("firefly_spots")
	var dots: Array[PackedVector2Array] = []
	var halos: Array[PackedVector2Array] = []
	var strengths: Array[float] = []
	for i: int in range(spots.size()):
		if dots.size() >= FIREFLIES:
			break
		var ph: float = RisoShapes.hash1(float(i) * 1.37 + spots[i].x * 0.01)
		if ph > 0.45 or not view.has_point(spots[i]):
			continue
		var p: Vector2 = spots[i] + Vector2(sin(t * 0.6 + ph * 9.0) * 34.0, sin(t * 0.9 + ph * 5.0) * 18.0 - 10.0)
		var glow: float = pow(clampf(sin(t * 1.3 + ph * 20.0), 0.0, 1.0), 1.5)
		if glow < 0.05:
			continue
		dots.append(RisoShapes.circle(p, 2.4, 8))
		halos.append(RisoShapes.circle(p, 9.0, 14))
		strengths.append(glow)
	for i: int in range(dots.size()):
		ink.lift_ink(KNOCK_ALL, strengths[i], [dots[i]])
	ink.ink(RisoPrint.BLUE, 0.15, halos, false)
	counts["fireflies"] = dots.size()


func _drops(view: Rect2) -> void:
	var spots: PackedVector2Array = decor.get("drip_spots")
	var ends: PackedFloat32Array = decor.get("drip_ends")
	var drops: Array[PackedVector2Array] = []
	var splashes: Array[PackedVector2Array] = []
	var shown: int = 0
	for i: int in range(spots.size()):
		if shown >= DRIPS or not view.has_point(spots[i]):
			continue
		shown += 1
		var ph: float = RisoShapes.hash1(float(i) * 2.9 + spots[i].x * 0.007)
		var period: float = 2.4 + ph * 3.0
		var u: float = fmod(t / period + ph, 1.0)
		var fall: float = ends[i] - spots[i].y
		if u < 0.3:
			var y: float = spots[i].y + pow(u / 0.3, 2.0) * fall
			drops.append(RisoShapes.smooth(PackedVector2Array([Vector2(spots[i].x, y - 6), Vector2(spots[i].x + 3, y + 1), Vector2(spots[i].x, y + 4), Vector2(spots[i].x - 3, y + 1)])))
		elif u < 0.4:
			var s: float = (u - 0.3) / 0.1
			for side: float in [-1.0, 1.0]:
				splashes.append(RisoShapes.circle(Vector2(spots[i].x + side * (3.0 + s * 9.0), ends[i] - 2.0 - sin(s * PI) * 6.0), 1.8, 6))
	ink.ink(RisoPrint.BLUE, 1.0, drops)
	ink.ink(RisoPrint.BLUE, 0.7, splashes)
	counts["drops"] = shown
