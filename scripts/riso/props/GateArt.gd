extends RisoProp
## A portcullis: a door (its lock in the key colour it needs), a switch gate (the switch's emblem
## and its sigil, which the switch that lifts it shares) or a toll gate (no lock: its price on a
## paper plaque over its cross-rail). A door is still (printed once); a switch gate winches up and
## down with its switch (SwitchGate.lift), and a toll gate's plaque is printed in the UI's canvas as
## an exit's price is.


func still() -> bool:
	return kind == &"door"


func _draw_art() -> void:
	if kind == &"toll":
		var g: float = _ground()
		RisoMarks.portcullis(ink, g, half, RisoMarks.NO_LOCK, 0.0, 1.0)
		_plaque(str((host as TollGate).price), Vector2(0, g - half - 4.0), 30, RisoPrint.ACCENT)
		return
	# A switch gate shows the switch's emblem and sigil where a door shows its lock.
	var gate: SwitchGate = host as SwitchGate
	RisoMarks.portcullis(ink, _ground(), half, -1 if kind == &"gate" else int(host.get_meta(&"key_color", 0)), gate.lift if gate != null else 0.0, 1.0, Sigils.of(host))
