extends Node2D
class_name RisoPrompt
## Printed interaction prompt: a paper card with the interact control on it, pressed about every
## 0.8 s, that pops up above an Interactable while it is the focused one (the nearest the player is
## touching; see Interactable.focused): on a pad the small pad (RisoPad.draw_small: only the part of
## the pad the interact button is on, the face buttons as a diamond with it solid; the tutorial's
## cards show the whole pad, HintArt), on the keyboard the interact key's cap with its letter,
## whichever the player last used (RisoPad.pad). The object's interaction_hint
## supplies optional text, or the key or switch it needs, shown on a paper disc instead. It draws in
## the UI's canvas (RisoPrint.ui_canvas), printed finer than the scene, kept on this node.

var canvas: Node2D

var interactable: Interactable
var host: Node2D
var ink: InkCanvas
var shown: float = 0.0
var t: float = 0.0
var hint_label: Label
var key_label: Label
## The input action that interacts (Interactable).
const INTERACT: StringName = &"Discover"
## The interact control's size on the prompt: the small pad's scale (about a key cap's size), the key
## cap's (against HintArt's), and the paper round either.
const PAD_SCALE: float = 0.65
const KEY_SCALE: float = 0.75
const CARD_PAD: Vector2 = Vector2(8, 6)
## How big the seed a bare plot asks for is on its disc (times a key's size).
const SEED_SIZE: float = 1.3
## How far (px) the key cap sinks as it is pressed.
const KEY_SINK: float = 2.5


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
	key_label = Label.new()
	key_label.add_theme_font_override("font", RisoTheme.serif())
	key_label.add_theme_font_size_override("font_size", HintArt.LETTER_PX)
	key_label.add_theme_color_override("font_color", Color.WHITE)
	key_label.add_theme_color_override("font_outline_color", Color.WHITE)
	key_label.add_theme_constant_override("outline_size", 2)
	key_label.visibility_layer = RisoPrint.plate_mask(RisoPrint.NIGHT)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.visible = false
	canvas.add_child(key_label)


func _input(event: InputEvent) -> void:
	RisoPad.note_device(event)


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
	key_label.visible = false
	if shown > 0.01:
		var pop: float = sin(shown * PI * 0.5) * (1.0 + 0.12 * sin(shown * PI))
		var at: Vector2 = Vector2(0, -118 + sin(t * 3.0) * 3.0)
		var plain: bool = needs < 0 and not bool(hint.get("sealed", false)) and not bool(hint.get("switch", false))
		var paper: PackedVector2Array = _card(at, pop) if plain else RisoShapes.circle(at, 30.0 * pop, 28)
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE], [paper])
		ink.ink(RisoPrint.BLUE, 0.12, [paper], false)
		if pop > 0.3:
			if needs >= 0:
				if needs == KeyRing.SKELETON:
					# On the prompt's paper disc a bone-white key would vanish: print it in night.
					ink.ink(RisoPrint.NIGHT, 1.0, RisoMarks.key_shape(at, pop, needs), false)
				elif needs == KeyRing.SEED:
					# A seed (a bare plot's, Plot): printed as it lies, its seam and sprout its own inks.
					RisoPrint.ink_key(ink, needs, 1.0, RisoMarks.key_shape(at + Vector2(0, 3.0) * pop, pop * SEED_SIZE, needs))
				else:
					ink.ink_overprint(RisoPrint.key_inks(needs), 1.0, RisoMarks.key_shape(at, pop, needs))
			elif bool(hint.get("sealed", false)):
				# Sealed by a boss: only its death opens it.
				RisoMarks.boss_seal(ink, at, 16.0 * pop, 1.0, StringName(hint.get("boss", &"")))
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
				_interact(at, pop, tap)
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


## The paper card the interact control sits on, round `at` at pop `pop`.
func _card(at: Vector2, pop: float) -> PackedVector2Array:
	var size: Vector2 = (RisoPad.small_size(INTERACT) * PAD_SCALE if RisoPad.pad else Vector2(HintArt.CAP_W, HintArt.CAP_H) * KEY_SCALE) + CARD_PAD * 2.0
	size *= pop
	return RisoShapes.rrect(at.x - size.x * 0.5, at.y - size.y * 0.5, size.x, size.y, 9.0 * pop)


## The interact control on the card at `at`, pressed by `tap` (0 up .. 1 down): the small pad with
## its button solid, or the key's cap and letter, sinking as it is pressed, a ring spreading as it lands.
func _interact(at: Vector2, pop: float, tap: float) -> void:
	if RisoPad.pad:
		RisoPad.draw_small(ink, at, PAD_SCALE * pop, INTERACT, tap)
		return
	var s: float = KEY_SCALE * pop
	var c: Vector2 = at + Vector2(0, KEY_SINK * tap * s)
	var mid: Vector2 = RisoPad.key_cap(ink, c, HintArt.CAP_W * s, HintArt.CAP_H * s, HintArt.LIP * s, HintArt.CAP_ROUND * s)
	RisoPad.ring(ink, c + Vector2(0, HintArt.CAP_H * 0.5 * s), s, tap)
	key_label.text = HintArt.key_of(INTERACT)
	key_label.size = Vector2(HintArt.CAP_W, HintArt.CAP_H)
	key_label.scale = Vector2.ONE * s
	key_label.position = mid - key_label.size * s * 0.5
	key_label.visible = true
