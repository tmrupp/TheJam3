extends TestKit
## Drafts of the interact symbol side by side, for choosing one: each on the prompt's paper disc,
## through a tap (up, pressing, landed with its ring), close up and at the game's own size.
## Writes prompt_hands.png (close-ups, a row per tap phase, a column per draft) and
## prompt_hands_game.png (the same at play zoom).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_prompt_hands.gd

## The drafts, left to right.
const NAMES: Array[String] = ["now", "A rolls", "B glove", "C silhouette", "D slant"]
## How far apart the discs sit (UI units).
const GAP: float = 76.0

var camera: Camera2D
var sheet: HandSheet


## The discs and their hands, printed in the UI's canvas as a prompt is.
class HandSheet extends Node2D:
	var canvas: Node2D
	var ink: InkCanvas
	var tap: float = 0.0

	func _ready() -> void:
		z_index = 55
		z_as_relative = false
		canvas = RisoPrint.ui_canvas(self)
		canvas.z_index = 55
		canvas.z_as_relative = false
		ink = InkCanvas.new()
		ink.ui = true
		canvas.add_child(ink)

	func _process(_delta: float) -> void:
		canvas.global_transform = global_transform
		ink.begin()
		for i: int in range(NAMES.size()):
			var at: Vector2 = Vector2((float(i) - float(NAMES.size() - 1) * 0.5) * GAP, 0.0)
			var disc: PackedVector2Array = RisoShapes.circle(at, 30.0, 28)
			ink.knock(RisoPrint.ALL_PLATES, [disc])
			ink.ink(RisoPrint.BLUE, 0.12, [disc], false)
			var k: float = 0.95
			match i:
				0: _now(at, k, tap)
				1: _mitten(at, k, tap)
				2: _manicule(at, k, tap)
				3: _silhouette(at, k, tap)
				4: _sleeve(at, k, tap)
			_ring(at, k, tap, _tip(i))
		ink.finish()

	## Where each draft's fingertip is, in its own units.
	func _tip(i: int) -> Vector2:
		match i:
			0: return Vector2(-5.8, 17.0)
			4: return Vector2(-12.0, 17.0)
			_: return Vector2(-5.0, 18.5)

	func _frame(at: Vector2, k: float, tap: float) -> Transform2D:
		return Transform2D(0.0, Vector2(k, k), 0.0, at + Vector2(1.0, -1.0 + tap * 3.0) * k)

	## A bar `w` wide from `a` to `b`, its ends round.
	static func cap(a: Vector2, b: Vector2, w: float) -> PackedVector2Array:
		var long: float = a.distance_to(b) + w
		return Transform2D((b - a).angle(), (a + b) * 0.5) * RisoShapes.rrect(-long * 0.5, -w * 0.5, long, w, w * 0.5, 5)

	func _ring(at: Vector2, k: float, tap: float, tip_at: Vector2) -> void:
		var landed: float = clampf((tap - 0.6) / 0.4, 0.0, 1.0)
		if landed <= 0.0:
			return
		var tip: Vector2 = _frame(at, k, tap) * tip_at
		var r: float = (3.0 + 6.0 * landed) * k
		ink.ink(RisoPrint.ACCENT, 1.0 - landed * 0.6, [RisoShapes.ellipse(tip, r, r * 0.45, 20)], false)
		ink.knock([RisoPrint.ACCENT], [RisoShapes.ellipse(tip, r * 0.7, r * 0.3, 20)])

	## The hand as it is now.
	func _now(at: Vector2, k: float, tap: float) -> void:
		var xf: Transform2D = _frame(at, k, tap)
		var rolls: Array[PackedVector2Array] = []
		for f: int in range(3):
			rolls.append(xf * RisoShapes.rrect(-1.2 + 4.1 * float(f), -10.0, 3.4, 12.0 - 1.4 * float(f), 1.7))
		ink.ink(RisoPrint.BLUE, 1.0, [xf * RisoShapes.rrect(-9.0, -24.0, 19.0, 8.0, 2.5)], false)
		var inks: Array[PackedVector2Array] = [xf * RisoShapes.rrect(-9.0, -17.5, 19.0, 9.5, 4.0), xf * RisoShapes.rrect(-9.0, -10.0, 6.4, 26.0, 3.2), xf * (Transform2D(0.6, Vector2(-10.0, -10.5)) * RisoShapes.rrect(-2.4, -4.5, 4.8, 9.0, 2.4))]
		inks.append_array(rolls)
		ink.ink(RisoPrint.NIGHT, 1.0, inks, false)

	## The pose the drafts share, in the hand's own units (pointing down, the back of the hand to
	## us): a wide back of the hand, the index finger down its left side, the other three fingers
	## curled under in rolls stacked down beside it, each shorter, the thumb out to the left.
	func _pose(xf: Transform2D) -> Dictionary:
		var rolls: Array[PackedVector2Array] = []
		for f: int in range(3):
			rolls.append(xf * RisoShapes.rrect(-1.5, -8.5 + 4.0 * float(f), 11.5 - 1.8 * float(f), 4.2, 2.1, 4))
		var gaps: Array[PackedVector2Array] = [xf * RisoShapes.rrect(-2.2, -8.5, 0.8, 12.5, 0.4),
				xf * RisoShapes.rrect(-1.0, -4.65, 10.5, 0.75, 0.35),
				xf * RisoShapes.rrect(-1.0, -0.65, 8.7, 0.75, 0.35),
				xf * cap(Vector2(-7.6, -12.0), Vector2(-9.3, -7.5), 0.8)]
		return {
			"cuff": xf * RisoShapes.rrect(-9.0, -25.5, 18.5, 7.0, 2.5),
			"back": xf * RisoShapes.rrect(-9.5, -19.5, 19.5, 13.0, 5.5),
			"finger": xf * cap(Vector2(-5.0, -10.0), Vector2(-5.0, 15.5), 6.6),
			"thumb": xf * cap(Vector2(-7.5, -15.0), Vector2(-11.0, -6.0), 5.0),
			"rolls": rolls,
			"gaps": gaps,
			"nail": xf * RisoShapes.ellipse(Vector2(-5.0, 13.0), 1.6, 2.3, 10),
		}

	func _solid_hand(pose: Dictionary, plate: int, cuff_plate: int, cuff_cover: float) -> void:
		var cuff: Array[PackedVector2Array] = [pose["cuff"] as PackedVector2Array]
		ink.ink(cuff_plate, cuff_cover, cuff, false)
		var inks: Array[PackedVector2Array] = [pose["back"] as PackedVector2Array, pose["finger"] as PackedVector2Array, pose["thumb"] as PackedVector2Array]
		var rolls: Array[PackedVector2Array] = pose["rolls"]
		inks.append_array(rolls)
		ink.ink(plate, 1.0, inks, false)

	## A: the emoji's pointing hand, in night ink: the curled fingers as rolls with paper between
	## them, a cloth-blue cuff, a paper nail.
	func _mitten(at: Vector2, k: float, tap: float) -> void:
		var pose: Dictionary = _pose(_frame(at, k, tap))
		_solid_hand(pose, RisoPrint.NIGHT, RisoPrint.CLOTH, 1.0)
		var paper: Array[PackedVector2Array] = []
		for g: PackedVector2Array in pose["gaps"]:
			paper.append(g)
		paper.append(pose["nail"])
		ink.knock(RisoPrint.ALL_PLATES, paper)

	## B: the same hand gloved as the Fool's are: cloth-blue, a dark cuff, the rolls shaded with
	## night rather than parted with paper.
	func _manicule(at: Vector2, k: float, tap: float) -> void:
		var pose: Dictionary = _pose(_frame(at, k, tap))
		_solid_hand(pose, RisoPrint.CLOTH, RisoPrint.NIGHT, 0.9)
		var gaps: Array[PackedVector2Array] = pose["gaps"]
		ink.ink(RisoPrint.NIGHT, 0.5, gaps, false)
		var under: Array[PackedVector2Array] = []
		for r: PackedVector2Array in pose["rolls"]:
			under.append(r)
		ink.ink(RisoPrint.NIGHT, 0.2, under)
		var nail: Array[PackedVector2Array] = [pose["nail"] as PackedVector2Array]
		ink.knock(RisoPrint.ALL_PLATES, nail)

	## C: one soft silhouette, no inner lines: the hand reads by its shape alone, tipped as if
	## leaning in to press, a paper glint on its back.
	func _silhouette(at: Vector2, k: float, tap: float) -> void:
		var xf: Transform2D = _frame(at, k, tap) * Transform2D(-0.2, Vector2.ZERO)
		var pose: Dictionary = _pose(xf)
		_solid_hand(pose, RisoPrint.NIGHT, RisoPrint.CLOTH, 1.0)
		var paper: Array[PackedVector2Array] = [pose["nail"] as PackedVector2Array, xf * RisoShapes.ellipse(Vector2(3.0, -15.0), 3.2, 1.3, 12, -0.15)]
		ink.knock(RisoPrint.ALL_PLATES, paper)

	## D: A pointing down and in, on a slant, as a cursor does, a size larger.
	func _sleeve(at: Vector2, k: float, tap: float) -> void:
		var pose: Dictionary = _pose(_frame(at, k * 1.08, tap) * Transform2D(0.4, Vector2(0.0, 2.0)))
		_solid_hand(pose, RisoPrint.NIGHT, RisoPrint.CLOTH, 1.0)
		var paper: Array[PackedVector2Array] = []
		for g: PackedVector2Array in pose["gaps"]:
			paper.append(g)
		paper.append(pose["nail"])
		ink.knock(RisoPrint.ALL_PLATES, paper)


func run() -> void:
	window()
	await boot()
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	camera = main.get_node("Camera2D") as Camera2D
	var base: Vector2 = camera.zoom
	sheet = HandSheet.new()
	info.map_elements.add_child(sheet)
	var spot: Vector2 = player.global_position + Vector2(0, -900)
	sheet.global_position = spot
	player.global_position = Vector2(-9000, -9000)
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	# Close up: a row per tap phase.
	camera.zoom = base * 4.6
	var rows: Array[Image] = []
	for tap: float in [0.0, 0.55, 0.85]:
		sheet.tap = tap
		camera.global_position = spot
		camera.reset_smoothing()
		await frames(3)
		var whole: Image = root.get_texture().get_image()
		rows.append(whole.get_region(Rect2i(0, (whole.get_height() - 300) / 2, whole.get_width(), 300)))
	var out: Image = Image.create(rows[0].get_width(), 300 * rows.size(), false, rows[0].get_format())
	for r: int in range(rows.size()):
		out.blit_rect(rows[r], Rect2i(Vector2i.ZERO, rows[r].get_size()), Vector2i(0, 300 * r))
	save_still("prompt_hands.png", out)
	# At the game's own zoom.
	camera.zoom = base
	sheet.tap = 0.0
	camera.global_position = spot
	camera.reset_smoothing()
	await frames(3)
	var game: Image = root.get_texture().get_image()
	save_still("prompt_hands_game.png", game.get_region(Rect2i((game.get_width() - 520) / 2, (game.get_height() - 120) / 2, 520, 120)))
	finish()
