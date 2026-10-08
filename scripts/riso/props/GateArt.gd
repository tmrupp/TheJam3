extends RisoProp
## A portcullis: a door (its lock in the key colour it needs) or a switch gate (the switch's
## emblem and its sigil, which the switch that lifts it shares). Still: printed once.


func still() -> bool:
	return true


func _draw_art() -> void:
	# A switch gate shows the switch's emblem and sigil where a door shows its lock.
	RisoMarks.portcullis(ink, _ground(), half, -1 if kind == &"gate" else int(host.get_meta(&"key_color", 0)), 0.0, 1.0, Sigils.of(host))
