extends TestKit
## Every ability's mark (RisoGlyph) side by side, a row to a slot (damage, movement, utility, then
## the perks), each on a paper card: large in night, and under it as the game prints it small,
## knocked to paper from a pink orb (a scholar's, the wizard's spell orb), in gold on night (a
## shrine's niche, a lesson) and at the HUD's size on paper.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_glyphs.gd

## The rows of the sheet: each slot's abilities in turn, then those that take none.
const ROWS: Array[StringName] = [&"damage", &"move", &"utility", &""]
## A card's size and the step from one card to the next (world units).
const CARD: float = 160.0
const STEP: float = 172.0
## How wide the sheet is (world units): the view is zoomed to show it all.
const SHEET_W: float = 1280.0
## Frames to wait before the still, so the level's title has faded.
const WAIT: int = 240
## How large the big mark and the small ones are, against the mark as drawn.
const BIG: float = 1.25
const SMALL: float = 0.62
const TINY: float = 0.36
## Radius of the orb and the disc the small marks sit on.
const ORB_R: float = 24.0


func run() -> void:
	window()
	await boot()
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	var base: Vector2 = Vector2(-4000, -4000)
	player.global_position = base + Vector2(-2000, 0)
	camera.limit_left = -1000000
	camera.limit_top = -1000000
	camera.limit_right = 1000000
	camera.limit_bottom = 1000000
	camera.global_position = base
	# The sheet, 1280 by 720 world units, fills the view.
	var view: Vector2 = Vector2(root.content_scale_size)
	if view.x < 1.0:
		view = Vector2(root.size)
	camera.zoom = Vector2.ONE * view.x / SHEET_W
	camera.reset_smoothing()
	var gallery: InkCanvas = InkCanvas.new()
	gallery.z_index = 5
	main.add_child(gallery)
	gallery.position = base
	gallery.begin()
	gallery.ink(RisoPrint.NIGHT, 1.0, [RisoShapes.rrect(-700, -400, 1400, 800, 0)], false)
	for row: int in range(ROWS.size()):
		var marks: Array[StringName] = Abilities.ids().filter(func(a: StringName) -> bool: return Abilities.slot_of(a) == ROWS[row])
		for col: int in range(marks.size()):
			var at: Vector2 = Vector2((float(col) - 3.0) * STEP, (float(row) - 1.5) * STEP)
			_card(gallery, marks[col], at)
	gallery.finish()
	await frames(WAIT)
	save_still("glyphs/glyph_sheet.png")
	finish()


## One ability's card, centred on `at`.
func _card(ink: InkCanvas, a: StringName, at: Vector2) -> void:
	var all: Array[int] = [RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT]
	ink.knock(all, [RisoShapes.rrect(at.x - CARD * 0.5, at.y - CARD * 0.5, CARD, CARD, 10)])
	ink.ink(RisoPrint.NIGHT, 1.0, _placed(a, at + Vector2(0, -26), BIG), false)
	var row_y: float = at.y + 46.0
	var orb: Vector2 = Vector2(at.x - 48.0, row_y)
	ink.ink(RisoPrint.PINK, 1.0, [RisoShapes.circle(orb, ORB_R, 28)])
	ink.knock(all, _placed(a, orb, SMALL))
	var niche: Vector2 = Vector2(at.x, row_y)
	ink.ink(RisoPrint.NIGHT, 1.0, [RisoShapes.circle(niche, ORB_R, 28)], false)
	ink.ink(RisoPrint.ACCENT, 1.0, _placed(a, niche, SMALL))
	ink.ink(RisoPrint.NIGHT, 1.0, _placed(a, Vector2(at.x + 48.0, row_y), TINY), false)


## Mark `a` scaled by `size` round `c`, as RisoGlyph.of draws it (not refitted).
func _placed(a: StringName, c: Vector2, size: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in RisoGlyph.of(a, Vector2.ZERO, 0.0):
		out.append(Transform2D(0.0, Vector2(size, size), 0.0, c) * poly)
	return out
