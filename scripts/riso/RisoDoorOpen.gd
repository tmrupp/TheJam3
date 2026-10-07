extends Node2D
class_name RisoDoorOpen
## A portcullis opening, printed: the grate winches up into its header with a little shudder,
## a puff of blue dust lifts from the floor, then the whole gate fades from the sheet. Spawned
## where the door stood.

const DURATION: float = 1.1

var ground: float = 64.0
var half: float = 64.0
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
	# Ease up with a small catch near the start, as if the chain takes the weight.
	var rise: float = clampf(u / 0.6, 0.0, 1.0)
	rise = rise * rise * (3.0 - 2.0 * rise)
	var shudder: float = sin(u * 60.0) * 2.0 * (1.0 - rise)
	var fade: float = 1.0 - clampf((u - 0.6) / 0.4, 0.0, 1.0)
	ink.begin()
	var dust: Array[PackedVector2Array] = []
	for k: int in range(5):
		var x: float = -44.0 + 22.0 * float(k)
		dust.append(RisoShapes.circle(Vector2(x + sin(float(k) * 2.3) * 6.0, ground - 6.0 - rise * 10.0), 6.0 + rise * 8.0, 12))
	ink.ink(RisoPrint.BLUE, 0.3 * (1.0 - rise) * fade, dust)
	RisoMarks.portcullis(ink, ground + shudder, half, key_color, rise, fade)
	ink.finish()
