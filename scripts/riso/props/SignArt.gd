extends RisoProp
class_name SignArt
## The signpost: a blue post with a paper board bearing the place marks (a globe for the world,
## a thick down arrow for depth), and, while the wizard stands by it, a card over it with this
## place's marks and numbers and the marks of the abilities known. No words.

## The Signpost it dresses.
var signpost: Signpost:
	get:
		return host as Signpost
## How open the card is, eased from 0 to 1 as the wizard comes near.
var open: float = 0.0
## The post and board, in world pixels from the ground, and the size of the marks on the board.
const POST: Vector2 = Vector2(10, 104)
const BOARD: Rect2 = Rect2(-46, -122, 92, 50)
const BOARD_MARK: float = 15.0
## One ability mark's slot on the card, and the size of a mark in it.
const SLOT: float = 36.0
const MARK: float = 0.5
## The card's place marks (half height) and numbers (font size), in world pixels.
const PLACE_R: float = 12.0
const NUMBER_PX: int = 32
## How far below the top of the view the card stays (world pixels), when the post is near it.
const CARD_MARGIN: float = 34.0


## The board carries the world and depth marks side by side; the card pops up above the wizard.
func _draw_art() -> void:
	var g: float = _ground()
	var post: PackedVector2Array = RisoShapes.rrect(-POST.x * 0.5, g - POST.y, POST.x, POST.y, 3)
	ink.ink(RisoPrint.BLUE, 1.0, [post])
	ink.ink(RisoPrint.NIGHT, 0.35, [RisoShapes.rrect(1, g - POST.y, POST.x * 0.5 - 1, POST.y, 2)], false)
	var board: PackedVector2Array = RisoShapes.rrect(BOARD.position.x, g + BOARD.position.y, BOARD.size.x, BOARD.size.y, 10)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], [board])
	ink.ink(RisoPrint.BLUE, 0.18, [board], false)
	var middle: float = g + BOARD.position.y + BOARD.size.y * 0.5
	RisoMarks.world_glyph(ink, Vector2(-BOARD_MARK - 3.0, middle), BOARD_MARK, RisoPrint.NIGHT, 0.85)
	RisoMarks.depth_glyph(ink, Vector2(BOARD_MARK + 3.0, middle), BOARD_MARK, RisoPrint.NIGHT, 0.85)
	open = move_toward(open, 1.0 if signpost.reading else 0.0, _dt * 5.0)
	if open < 0.02:
		return
	var p: float = open - 1.0
	var s: float = 1.0 + 2.7 * p * p * p + 1.7 * p * p
	var info: MapInfo = MapInfo.instance
	var player: Player = Stage.player()
	if info == null or player == null:
		return
	var place_at: Vector2 = Vector2(0, maxf(g - POP_Y, _view_top() + CARD_MARGIN))
	_place(info.coord, place_at, s)
	_abilities(player, place_at + Vector2(0, 50.0 * s), s)


## Place `at` on a plaque centred on `centre`: its marks and its two numbers.
func _place(at: Vector2i, centre: Vector2, s: float) -> void:
	var n: Vector3i = Rules.place_numbers(at)
	var texts: PackedStringArray = PackedStringArray([str(n.x), str(n.y)])
	var font: Font = RisoTheme.serif()
	var widths: Vector2 = Vector2(font.get_string_size(texts[0], HORIZONTAL_ALIGNMENT_LEFT, -1, NUMBER_PX).x,
			font.get_string_size(texts[1], HORIZONTAL_ALIGNMENT_LEFT, -1, NUMBER_PX).x) * s
	var r: float = PLACE_R * s
	var side: bool = Worlds.is_side(at)
	var w: float = RisoMarks.place_width(r, widths, side)
	var h: float = 40.0 * s
	var plate: PackedVector2Array = RisoShapes.rrect(centre.x - w * 0.5 - 11.0 * s, centre.y - h * 0.5, w + 22.0 * s, h, h * 0.35)
	var u: InkCanvas = _ui()
	u.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE], [plate])
	u.ink(RisoPrint.BLUE, 0.2, [plate], false)
	var xs: Vector2 = RisoMarks.place_marks(u, Vector2(centre.x - w * 0.5, centre.y), r, widths, side)
	_text(texts[0], Vector2(xs.x + widths.x * 0.5, centre.y), NUMBER_PX, s)
	_text(texts[1], Vector2(xs.y + widths.y * 0.5, centre.y), NUMBER_PX, s)


## The abilities known, as their marks on one plaque; a pip per tier past the first, and the spell
## in the slot underlined.
func _abilities(player: Player, at: Vector2, s: float) -> void:
	var owned: Array[StringName] = []
	for a: StringName in Abilities.ids():
		if Abilities.tier(player, a) > 0:
			owned.append(a)
	if owned.is_empty():
		return
	var w: float = (SLOT * float(owned.size()) + 22.0) * s
	var h: float = 44.0 * s
	var plate: PackedVector2Array = RisoShapes.rrect(at.x - w * 0.5, at.y - h * 0.5, w, h, h * 0.35)
	var u: InkCanvas = _ui()
	u.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE], [plate])
	u.ink(RisoPrint.BLUE, 0.2, [plate], false)
	var marks: Array[PackedVector2Array] = []
	var pips: Array[PackedVector2Array] = []
	for i: int in range(owned.size()):
		var a: StringName = owned[i]
		var n: int = Abilities.tier(player, a)
		var c: Vector2 = at + Vector2((float(i) - float(owned.size() - 1) * 0.5) * SLOT, -3.0) * s
		for poly: PackedVector2Array in RisoGlyph.of(a, Vector2.ZERO, t):
			marks.append(Transform2D(0.0, Vector2(MARK, MARK) * s, 0.0, c) * poly)
		if Abilities.is_spell(a):
			pips.append(RisoShapes.rrect(c.x - 12.0 * s, c.y + 14.0 * s, 24.0 * s, 3.0 * s, 1.5 * s))
		if n > 1:
			for k: int in range(n):
				pips.append(RisoShapes.circle(c + Vector2((float(k) - float(n - 1) * 0.5) * 7.0, 19.0) * s, 2.2 * s, 8))
	u.ink(RisoPrint.NIGHT, 1.0, marks, false)
	u.ink(RisoPrint.ACCENT, 1.0, pips, false)


## The top of the view, in this prop's pixels, so the card never opens off the sheet.
func _view_top() -> float:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return -INF
	var base: Vector2 = Vector2(get_window().content_scale_size)
	if base.y < 1.0:
		base = Vector2(320, 180)
	return to_local(Vector2(0, cam.get_screen_center_position().y - base.y / cam.zoom.y * 0.5)).y
