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


## The interact symbol: a hand pointing down at the thing below, like a cursor clicking. A blue
## cuff, a night-ink fist with paper grooves between the curled fingers, a thumb, and the index
## finger reaching down. It taps: `tap` 0..1 pushes it down, and as the tip lands a ring of
## accent ink ripples out from it. Centred near `at`, `k` its size (1 full).
func _hand(at: Vector2, k: float, tap: float) -> void:
	var xf: Transform2D = Transform2D(0.0, Vector2(k, k), 0.0, at + Vector2(1.0, -1.0 + tap * 3.0) * k)
	var cuff: PackedVector2Array = xf * RisoShapes.rrect(-9.0, -24.0, 19.0, 8.0, 2.5)
	var back: PackedVector2Array = xf * RisoShapes.rrect(-9.0, -17.5, 19.0, 9.5, 4.0)
	# Three short curled fingers run alongside the extended index, with paper between them.
	var rolls: Array[PackedVector2Array] = []
	for finger_index: int in range(3):
		rolls.append(xf * RisoShapes.rrect(-1.2 + 4.1 * float(finger_index), -10.0, 3.4, 12.0 - 1.4 * float(finger_index), 1.7))
	var finger: PackedVector2Array = xf * RisoShapes.rrect(-9.0, -10.0, 6.4, 26.0, 3.2)
	var thumb: PackedVector2Array = xf * (Transform2D(0.6, Vector2(-10.0, -10.5)) * RisoShapes.rrect(-2.4, -4.5, 4.8, 9.0, 2.4))
	ink.ink(RisoPrint.BLUE, 1.0, [cuff], false)
	var hand_inks: Array[PackedVector2Array] = [back, finger, thumb]
	hand_inks.append_array(rolls)
	ink.ink(RisoPrint.NIGHT, 1.0, hand_inks, false)
	# The click: a ring spreading from the fingertip just after it lands.
	var landed: float = clampf((tap - 0.6) / 0.4, 0.0, 1.0)
	if landed > 0.0:
		var tip: Vector2 = xf * Vector2(-5.8, 17.0)
		var r: float = (3.0 + 6.0 * landed) * k
		var ring: PackedVector2Array = RisoShapes.ellipse(tip, r, r * 0.45, 20)
		ink.ink(RisoPrint.ACCENT, 1.0 - landed * 0.6, [ring], false)
		ink.knock([RisoPrint.ACCENT], [RisoShapes.ellipse(tip, r * 0.7, r * 0.3, 20)])


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
			elif bool(hint.get("switch", false)):
				ink.ink(RisoPrint.NIGHT, 1.0, RisoMarks.switch_emblem(at, pop), false)
			else:
				# A press about every 0.8 s: down quickly, a moment on the spot, then back up.
				var u: float = fmod(t * 1.25, 1.0)
				var tap: float = smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.55, 0.85, u))
				_hand(at, pop * 0.95, tap)
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
