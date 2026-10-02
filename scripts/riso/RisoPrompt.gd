extends Node2D
## Printed interaction prompt: a bare-paper disc with an interact symbol (a pointing hand, tapping)
## in night ink that pops up above an Interactable while it is the focused one (the nearest the
## player is touching; see Interactable.focused). On doors it shows the key colour the door needs
## instead. Replaces the pixel-art prompt sprite. It draws in the UI's canvas
## (RisoPrint.ui_canvas), printed finer than the scene, kept on this node.

var canvas: Node2D

var interactable: Node
var host: Node2D
var ink: InkCanvas
var shown: float = 0.0
var t: float = 0.0


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
	var near: bool = interactable != null and is_instance_valid(interactable) and interactable.has_method("is_focused") and bool(interactable.call("is_focused"))
	shown = move_toward(shown, 1.0 if near else 0.0, delta * 6.0)
	ink.begin()
	var door: Node = host.get_parent() if host != null and host.name == "Unlock" else null
	# Doors, and locked side exits, show the key colour they need instead of the hand.
	var needs: int = int(door.get_meta(&"key_color", 0)) if door != null else (int(host.call("lock")) if host != null and host.has_method("lock") else -1)
	if shown > 0.01:
		var pop: float = sin(shown * PI * 0.5) * (1.0 + 0.12 * sin(shown * PI))
		var at: Vector2 = Vector2(0, -118 + sin(t * 3.0) * 3.0)
		var disc: PackedVector2Array = RisoShapes.circle(at, 30.0 * pop, 28)
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE], [disc])
		ink.ink(RisoPrint.BLUE, 0.12, [disc], false)
		if pop > 0.3:
			if needs >= 0:
				var key: Array[PackedVector2Array] = [RisoShapes.crescent(at + Vector2(-8, 0), 10.0 * pop, Vector2(4.5, -2) * pop), RisoShapes.rrect(at.x - 6.0, at.y - 3.0, 22.0 * pop, 6.0 * pop, 3.0)]
				ink.ink_overprint(RisoPrint.key_inks(needs), 1.0, key)
			else:
				# A press about every 0.8 s: down quickly, a moment on the spot, then back up.
				var u: float = fmod(t * 1.25, 1.0)
				var tap: float = smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.55, 0.85, u))
				_hand(at, pop * 0.95, tap)
	ink.finish()
