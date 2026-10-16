extends RisoProp
class_name LessonArt
## A master's lesson (Lesson): a wooden lectern (blue, a night shade down its post) with an open
## book on its sloping top, paper pages with night lines, and over it the mark of the spell it
## teaches (RisoGlyph) floating in gold, bobbing in a soft halo, with a pip for the tier taking it
## gives. A spell a swap left on it floats there instead, at its tier. It shines (RisoLight).

## How high over the floor the mark floats (px), and its pips' size and spacing.
const MARK_Y: float = 150.0
const PIP_R: float = 4.5
const PIP_GAP: float = 13.0


func shines() -> bool:
	return true


func light() -> Array:
	return _light(Vector2(0, _ground() - MARK_Y), RisoLight.BEACON, RisoPrint.ACCENT)


## What it holds now, as [spell, tier] ([&"", 0] for nothing): its lesson's.
func _held() -> Array:
	var lesson: Lesson = host as Lesson
	return lesson.holds() if lesson != null and lesson.map_info != null else [&"", 0]


func _draw_art() -> void:
	var g: float = _ground()
	var post: PackedVector2Array = RisoShapes.rrect(-6.0, g - 70.0, 12.0, 70.0, 2.0)
	var foot: PackedVector2Array = RisoShapes.rrect(-22.0, g - 8.0, 44.0, 8.0, 2.0)
	var top: PackedVector2Array = PackedVector2Array([Vector2(-34, g - 74), Vector2(34, g - 86), Vector2(36, g - 76), Vector2(-32, g - 64)])
	ink.ink(RisoPrint.BLUE, 1.0, [post, foot, top])
	ink.ink(RisoPrint.NIGHT, 0.35, [RisoShapes.rrect(1.0, g - 70.0, 5.0, 70.0, 2.0)], false)
	var pages: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-30, g - 76), Vector2(-1, g - 84), Vector2(-1, g - 92), Vector2(-28, g - 86)]),
		PackedVector2Array([Vector2(1, g - 84), Vector2(30, g - 90), Vector2(30, g - 100), Vector2(1, g - 92)]),
	]
	ink.knock(RisoPrint.ALL_PLATES, pages)
	var lines: Array[PackedVector2Array] = []
	for i: int in range(3):
		var y: float = float(i) * 2.6
		lines.append(Spider.strand(Vector2(-25, g - 84 + y), Vector2(-5, g - 89 + y), 1.0))
		lines.append(Spider.strand(Vector2(5, g - 91 + y), Vector2(25, g - 95 + y), 1.0))
	ink.ink(RisoPrint.NIGHT, 0.6, lines, false)
	var held: Array = _held()
	var a: StringName = held[0]
	if a == &"":
		return
	var c: Vector2 = Vector2(0, g - MARK_Y + sin(t * 2.0 + phase) * 5.0)
	ink.ink(RisoPrint.ACCENT, 0.25, [RisoShapes.circle(c, 36.0, 28)])
	ink.ink(RisoPrint.ACCENT, 1.0, RisoGlyph.of(a, c, t))
	var tier: int = int(held[1])
	var pips: Array[PackedVector2Array] = []
	for i: int in range(tier):
		var p: Vector2 = c + Vector2((float(i) - float(tier - 1) * 0.5) * PIP_GAP, 40.0)
		pips.append(PackedVector2Array([p + Vector2(0, -PIP_R), p + Vector2(PIP_R, 0), p + Vector2(0, PIP_R), p + Vector2(-PIP_R, 0)]))
	ink.ink(RisoPrint.ACCENT, 1.0, pips)
