extends Node2D
## A door unlocking, printed: the panel swings aside on its hinge, the doorway fills with
## eye-yellow light, then the whole door fades from the sheet. Spawned where the door stood.

const DURATION: float = 0.9

var ground: float = 64.0
var key_color: int = 0
var t: float = 0.0
var ink: InkCanvas


func _ready() -> void:
	z_index = 2
	add_to_group(&"riso_art")
	ink = InkCanvas.new()
	add_child(ink)


func _process(delta: float) -> void:
	t += delta
	var u: float = clampf(t / DURATION, 0.0, 1.0)
	if u >= 1.0:
		queue_free()
		return
	var swing: float = clampf(u / 0.35, 0.0, 1.0)
	var fade: float = 1.0 - clampf((u - 0.45) / 0.55, 0.0, 1.0)
	var g: float = ground
	var opening: PackedVector2Array = RisoShapes.arch(-34, g - 114, 68, 114, 14)
	ink.begin()
	ink.ink(RisoPrint.BLUE, 0.5 * fade, [RisoShapes.arch(-44, g - 124, 88, 124, 14)])
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.ACCENT], [opening])
	ink.ink(RisoPrint.EYE, 0.55 * fade * swing, [opening], false)
	ink.ink(RisoPrint.EYE, 0.25 * fade * swing, [RisoShapes.circle(Vector2(0, g - 60), 70.0 * (0.6 + 0.4 * swing), 32)], false)
	# The panel narrows toward its left hinge as it swings open, keeping the lock colour.
	var w: float = 68.0 * (1.0 - swing * 0.9)
	if w > 2.0:
		var panel: PackedVector2Array = Transform2D(0.0, Vector2(w / 68.0, 1.0), 0.0, Vector2(-34, 0)) * RisoShapes.arch(0, g - 114, 68, 114, 14)
		ink.ink(RisoPrint.BLUE, fade, [panel], false)
	ink.finish()
