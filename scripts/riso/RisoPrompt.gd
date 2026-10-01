extends Node2D
## Printed interaction prompt: a bare-paper disc with the interact key in night ink that
## pops up above an Interactable while the player is in reach. On doors it shows the key
## colour the door needs instead of the letter. Replaces the pixel-art prompt sprite.

var interactable: Node
var host: Node2D
var ink: InkCanvas
var label: Label
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
	ink = InkCanvas.new()
	add_child(ink)
	label = Label.new()
	label.add_theme_font_override("font", RisoTheme.serif())
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(60, 60)
	label.visibility_layer = RisoPrint.plate_mask(RisoPrint.NIGHT)
	label.text = _key_name()
	add_child(label)


func _key_name() -> String:
	for event: InputEvent in InputMap.action_get_events("Discover"):
		var key: InputEventKey = event as InputEventKey
		if key != null:
			var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			return OS.get_keycode_string(code)
	return "E"


func _process(delta: float) -> void:
	t += delta
	var near: bool = interactable != null and is_instance_valid(interactable) and bool(interactable.get("available")) and bool(interactable.get("touching"))
	shown = move_toward(shown, 1.0 if near else 0.0, delta * 6.0)
	ink.begin()
	var door: Node = host.get_parent() if host != null and host.name == "Unlock" else null
	# Doors, and locked side exits, show the key colour they need instead of the letter.
	var needs: int = int(door.get_meta(&"key_color", 0)) if door != null else (int(host.call("lock")) if host != null and host.has_method("lock") else -1)
	label.visible = shown > 0.05 and needs < 0
	if shown > 0.01:
		var pop: float = sin(shown * PI * 0.5) * (1.0 + 0.12 * sin(shown * PI))
		var at: Vector2 = Vector2(0, -118 + sin(t * 3.0) * 3.0)
		var disc: PackedVector2Array = RisoShapes.circle(at, 30.0 * pop, 28)
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW], [disc])
		ink.ink(RisoPrint.BLUE, 0.12, [disc], false)
		if needs >= 0 and pop > 0.3:
			var key: Array[PackedVector2Array] = [RisoShapes.crescent(at + Vector2(-8, 0), 10.0 * pop, Vector2(4.5, -2) * pop), RisoShapes.rrect(at.x - 6.0, at.y - 3.0, 22.0 * pop, 6.0 * pop, 3.0)]
			for plate: int in RisoPrint.key_inks(needs):
				ink.ink(plate, 1.0, key, false)
		label.position = at - label.size * 0.5
		label.scale = Vector2.ONE * pop
		label.pivot_offset = label.size * 0.5
	ink.finish()
