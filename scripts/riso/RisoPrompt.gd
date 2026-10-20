extends Node2D
class_name RisoPrompt
## Printed interaction prompt: a bare-paper disc with an interact symbol (a pointing hand, tapping)
## in night ink that pops up above an Interactable while it is the focused one (the nearest the
## player is touching; see Interactable.focused). The object's interaction_hint supplies optional
## text or the key/switch it needs. Replaces the pixel-art prompt sprite. It draws in the UI's canvas
## (RisoPrint.ui_canvas), printed finer than the scene, kept on this node.

var canvas: Node2D

var interactable: Interactable
var host: Node2D
var ink: InkCanvas
var shown: float = 0.0
var t: float = 0.0
var hint_label: Label
## The interact hand (draw_hand), traced from a drawing of a pointing hand, pointing left in its
## own space, about 500 across (docs/mockups/interact-hand/ keeps it as an SVG, and the script that
## draws it): the curled little, ring and middle fingers, the hand with its index finger and wrist,
## and the thumb, each a closed outline of control points (RisoShapes.smooth's curve), all one
## ink. HAND_CUTS are the paper lines inside it, along the thumb's top and its underside (open
## curves, RisoShapes.smooth_open), HAND_GAP either side of the line. In the prompt it is turned
## to point down, HAND_SCALE of the drawing's size about HAND_MIDDLE; HAND_TIP is the fingertip,
## where the click ring spreads.
const HAND_PIECES: Array[Array] = [
	[Vector2(282, 345), Vector2(290, 395), Vector2(305, 428), Vector2(330, 446), Vector2(352, 432), Vector2(346, 398), Vector2(332, 362), Vector2(318, 340)],
	[Vector2(214, 340), Vector2(209, 398), Vector2(216, 444), Vector2(240, 461), Vector2(262, 446), Vector2(268, 392), Vector2(270, 340)],
	[Vector2(150, 342), Vector2(146, 398), Vector2(150, 428), Vector2(172, 439), Vector2(193, 426), Vector2(203, 380), Vector2(206, 342)],
	[Vector2(9.6, 215.3), Vector2(2.7, 197.3), Vector2(17.8, 187.4), Vector2(58.9, 166.1), Vector2(103.4, 152.1), Vector2(150, 142), Vector2(300, 152), Vector2(395, 190), Vector2(480, 222), Vector2(500, 222), Vector2(500, 383), Vector2(470, 392), Vector2(400, 392), Vector2(350, 384), Vector2(300, 338), Vector2(250, 296), Vector2(236, 270), Vector2(206, 222), Vector2(150, 198), Vector2(111.7, 199.3), Vector2(73.9, 207.4), Vector2(37.8, 222.1), Vector2(21.7, 230.2)],
	[Vector2(318, 248), Vector2(250, 268), Vector2(190, 288), Vector2(142, 300), Vector2(124, 322), Vector2(138, 346), Vector2(178, 350), Vector2(262, 334), Vector2(336, 318)],
]
const HAND_CUTS: Array[Array] = [
	[Vector2(232, 273), Vector2(262, 263), Vector2(296, 253), Vector2(326, 246)],
	[Vector2(160, 353), Vector2(205, 349), Vector2(262, 337), Vector2(324, 323)],
]
const HAND_GAP: float = 7.5
const HAND_SCALE: float = 0.094
const HAND_MIDDLE: Vector2 = Vector2(244.0, 300.0)
const HAND_TIP: Vector2 = Vector2(9.6, 215.3)


func _ready() -> void:
	host = get_parent() as Node2D
	if host != null and host.global_scale.x != 0.0:
		scale = Vector2.ONE / host.global_scale
	z_index = 55
	z_as_relative = false
	add_to_group(&"riso_art")
	visible = RisoPrint.is_on()
	canvas = RisoPrint.ui_canvas(self)
	canvas.z_index = 55
	canvas.z_as_relative = false
	ink = InkCanvas.new()
	ink.ui = true
	canvas.add_child(ink)
	hint_label = Label.new()
	hint_label.add_theme_font_override("font", RisoTheme.serif())
	hint_label.add_theme_font_size_override("font_size", 26)
	hint_label.add_theme_color_override("font_color", Color.WHITE)
	hint_label.add_theme_color_override("font_outline_color", Color.WHITE)
	hint_label.add_theme_constant_override("outline_size", 2)
	hint_label.visibility_layer = RisoPrint.plate_mask(RisoPrint.NIGHT)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.visible = false
	canvas.add_child(hint_label)


## The interact symbol: a hand pointing down at the thing below, like a cursor clicking. A flat
## shape of night ink, traced from a drawing: seen from the side, the wrist above, the index finger
## pointing down and curling in a little toward its tip, the thumb laid across the three curled
## fingers, which hang beside it, parted from the thumb by paper (HAND_PIECES, HAND_CUTS). It
## taps: `tap` 0..1 pushes it down, and as the tip lands a ring of accent ink ripples out from it.
## Centred near `at`, `k` its size (1 full). Drawn on `ink`.
static func draw_hand(ink: InkCanvas, at: Vector2, k: float, tap: float) -> void:
	_bake_hand()
	var xf: Transform2D = Transform2D(0.0, Vector2(k, k), 0.0, at + Vector2(0.0, tap * 3.0) * k)
	var shapes: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in _hand_shapes:
		shapes.append(xf * poly)
	ink.ink(RisoPrint.NIGHT, 1.0, shapes, false)
	var cuts: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in _hand_cuts:
		cuts.append(xf * poly)
	ink.knock([RisoPrint.NIGHT], cuts)
	# The click: a ring spreading from the fingertip just after it lands.
	var landed: float = clampf((tap - 0.6) / 0.4, 0.0, 1.0)
	if landed > 0.0:
		var tip: Vector2 = xf * _hand_point(HAND_TIP)
		var r: float = (3.0 + 6.0 * landed) * k
		var ring: PackedVector2Array = RisoShapes.ellipse(tip, r, r * 0.45, 20)
		ink.ink(RisoPrint.ACCENT, 1.0 - landed * 0.6, [ring], false)
		ink.knock([RisoPrint.ACCENT], [RisoShapes.ellipse(tip, r * 0.7, r * 0.3, 20)])


## The hand's shapes and cuts in the prompt's units (see HAND_PIECES), worked out the first time.
static var _hand_shapes: Array[PackedVector2Array] = []
static var _hand_cuts: Array[PackedVector2Array] = []


static func _bake_hand() -> void:
	if not _hand_shapes.is_empty():
		return
	for piece: Array in HAND_PIECES:
		var poly: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in RisoShapes.smooth(PackedVector2Array(piece)):
			poly.append(_hand_point(p))
		_hand_shapes.append(poly)
	for cut: Array in HAND_CUTS:
		var line: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in RisoShapes.smooth_open(PackedVector2Array(cut)):
			line.append(_hand_point(p))
		_hand_cuts.append_array(Geometry2D.offset_polyline(line, HAND_GAP * HAND_SCALE, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND))


## A point of the drawing (HAND_PIECES' space, pointing left) in the prompt's units: turned a
## quarter so it points down, scaled by HAND_SCALE about HAND_MIDDLE.
static func _hand_point(p: Vector2) -> Vector2:
	var d: Vector2 = (p - HAND_MIDDLE) * HAND_SCALE
	return Vector2(d.y, -d.x)


func _process(delta: float) -> void:
	t += delta
	canvas.global_transform = global_transform
	canvas.visible = is_visible_in_tree()
	var near: bool = interactable != null and is_instance_valid(interactable) and interactable.is_focused()
	shown = move_toward(shown, 1.0 if near else 0.0, delta * 6.0)
	ink.begin()
	var hint: Dictionary = interactable.prompt_hint() if interactable != null and is_instance_valid(interactable) else {}
	var needs: int = int(hint.get("key_color", -1))
	hint_label.visible = false
	if shown > 0.01:
		var pop: float = sin(shown * PI * 0.5) * (1.0 + 0.12 * sin(shown * PI))
		var at: Vector2 = Vector2(0, -118 + sin(t * 3.0) * 3.0)
		var disc: PackedVector2Array = RisoShapes.circle(at, 30.0 * pop, 28)
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE], [disc])
		ink.ink(RisoPrint.BLUE, 0.12, [disc], false)
		if pop > 0.3:
			if needs >= 0:
				if needs == KeyRing.SKELETON:
					# On the prompt's paper disc a bone-white key would vanish: print it in night.
					ink.ink(RisoPrint.NIGHT, 1.0, RisoMarks.key_shape(at, pop, needs), false)
				else:
					ink.ink_overprint(RisoPrint.key_inks(needs), 1.0, RisoMarks.key_shape(at, pop, needs))
			elif bool(hint.get("sealed", false)):
				# Sealed by a boss: only its death opens it.
				RisoMarks.boss_seal(ink, at, 16.0 * pop)
			elif bool(hint.get("switch", false)):
				# The switch emblem, and beside it the sigil of the switch to find (Sigils).
				var sigil_kind: int = int(hint.get("sigil", -1))
				if sigil_kind >= 0:
					ink.ink(RisoPrint.NIGHT, 1.0, RisoMarks.switch_emblem(at + Vector2(-11.0, 2.0) * pop, 0.8 * pop), false)
					ink.ink(RisoPrint.NIGHT, 1.0, RisoMarks.sigil(sigil_kind, at + Vector2(12.0, 0.0) * pop, 9.0 * pop), false)
				else:
					ink.ink(RisoPrint.NIGHT, 1.0, RisoMarks.switch_emblem(at, pop), false)
			else:
				# A press about every 0.8 s: down quickly, a moment on the spot, then back up.
				var u: float = fmod(t * 1.25, 1.0)
				var tap: float = smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.55, 0.85, u))
				draw_hand(ink, at, pop, tap)
			var text: String = str(hint.get("text", ""))
			if not text.is_empty():
				var w: float = RisoTheme.serif().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 22.0
				var centre: Vector2 = at + Vector2(0, -60)
				var plaque: PackedVector2Array = RisoShapes.rrect(centre.x - w * pop * 0.5, centre.y - 18.0 * pop, w * pop, 36.0 * pop, 10.0 * pop)
				ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE], [plaque])
				ink.ink(RisoPrint.BLUE, 0.2, [plaque], false)
				hint_label.text = text
				hint_label.size = Vector2(w, 36)
				hint_label.scale = Vector2.ONE * pop
				hint_label.position = centre - hint_label.size * pop * 0.5
				hint_label.visible = true
	ink.finish()
