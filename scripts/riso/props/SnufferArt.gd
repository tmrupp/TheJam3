extends RisoProp
## A snuffing font (Snuffer): a stone basin on a short pedestal, its lip bare paper, brimming with
## black water, a bright candle snuffer's cone hung over it from a crook. While the wizard's flame
## is lit, a glint spreads across the water and a thread of cold air rises from it; while it is
## out, the water lies still.


## The Snuffer it dresses.
var font: Snuffer:
	get:
		return host as Snuffer


## How big it is drawn, against the sizes its shapes are drawn at.
const SCALE: float = 1.35


func _draw_art() -> void:
	var g: float = _ground()
	var waiting: bool = font != null and font.can_snuff()
	var xf: Transform2D = Transform2D(0.0, Vector2.ONE * SCALE, 0.0, Vector2(0, g))
	# The pedestal and its foot, in blue stone, lit down its left side with bare paper.
	var foot: PackedVector2Array = xf * RisoShapes.rrect(-22.0, -10.0, 44.0, 10.0, 3.0)
	var stem: PackedVector2Array = xf * PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(7, -44), Vector2(-7, -44)])
	var bowl: PackedVector2Array = xf * RisoShapes.smooth(PackedVector2Array([Vector2(-30, -58), Vector2(30, -58), Vector2(25, -48), Vector2(12, -42), Vector2(-12, -42), Vector2(-25, -48)]), 2)
	ink.ink(RisoPrint.BLUE, 1.0, [foot, stem, bowl])
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.55, [xf * RisoShapes.rrect(-6.0, -42.0, 3.0, 30.0, 1.5)])
	# Its lip, bare paper, round the black water brimming in it.
	var lip: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(0, -58), 31.0, 6.5, 28)
	var water: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(0, -58), 26.0, 4.0, 28)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.9, [lip])
	ink.knock([RisoPrint.BLUE], [water])
	ink.ink(RisoPrint.NIGHT, 1.0, [water], false)
	if waiting:
		# A glint spreading across the water, and a thin thread of cold air rising from it.
		var k: float = fmod(t * 0.6 + phase, 1.0)
		var glint: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(-4.0 + 6.0 * k, -58), 3.0 + 16.0 * k, 0.8 + 2.2 * k, 20)
		ink.lift_ink([RisoPrint.NIGHT], 0.6 * (1.0 - k), [glint])
		RisoMarks.smoke_thread(ink, Transform2D(0.0, Vector2(0, g - 62.0 * SCALE)), t + phase, 46.0, 2.6, 4.0, false)
	# The snuffer: a bright cone hung over the water from a crook, its handle up the post.
	var post: PackedVector2Array = xf * RisoShapes.rrect(20.0, -98.0, 3.0, 42.0, 1.5)
	var arm: PackedVector2Array = xf * RisoShapes.rrect(2.0, -100.0, 21.0, 3.0, 1.5)
	ink.ink(RisoPrint.NIGHT, 1.0, [post, arm])
	var sway: float = sin(t * 1.4 + phase) * 0.12
	var cone: PackedVector2Array = xf * (Transform2D(sway, Vector2(3, -98)) * RisoShapes.smooth(PackedVector2Array([Vector2(0, 0), Vector2(7, 16), Vector2(9, 19), Vector2(-9, 19), Vector2(-7, 16)]), 2))
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.95, [cone])
	ink.ink(RisoPrint.BLUE, 0.3, [cone], false)
