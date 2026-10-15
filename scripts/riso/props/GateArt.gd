extends RisoProp
## A portcullis: a door (its lock in the key colour it needs), a switch gate (the switch's emblem
## and its sigil, which the switch that lifts it shares), a toll gate (no lock: its price on a
## paper plaque over its cross-rail) or a gondola station's gate (a toll gate's portcullis, worked
## by the towers: a lamp on its top beam lit while its station is on; where it stands on the line
## is on the station's board over the doorway, StationArt). A door is still (printed once); a switch gate or a station's gate
## winches up and down (SwitchGate.lift), and a toll gate's plaque is printed in the UI's canvas as
## an exit's price is.

## A station gate's lamp (radius).
const LAMP: float = 8.0


func still() -> bool:
	return kind == &"door"


func _draw_art() -> void:
	if kind == &"toll":
		var g: float = _ground()
		RisoMarks.portcullis(ink, g, half, RisoMarks.NO_LOCK, 0.0, 1.0)
		_plaque(str((host as TollGate).price), Vector2(0, g - half - 4.0), 30, RisoPrint.ACCENT)
		return
	var gate: SwitchGate = host as SwitchGate
	if gate != null and gate.station >= 0:
		_station_gate(gate)
		return
	# A switch gate shows the switch's emblem and sigil where a door shows its lock.
	RisoMarks.portcullis(ink, _ground(), half, -1 if kind == &"gate" else int(host.get_meta(&"key_color", 0)), gate.lift if gate != null else 0.0, 1.0, Sigils.of(host))


## A gondola station's gate (see the class description): the toll gate's portcullis and its lamp.
func _station_gate(gate: SwitchGate) -> void:
	var g: float = _ground()
	var info: MapInfo = gate.map_info
	var on: bool = info != null and info.station_on(gate.station)
	RisoMarks.portcullis(ink, g, half, RisoMarks.NO_LOCK, gate.lift, 1.0)
	# The lamp on the top beam: lit while the station is on, dark while it is off.
	var top: float = g - 2.0 * half
	var lamp: PackedVector2Array = RisoShapes.circle(Vector2(0, top + 5.0), LAMP, 16)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [lamp])
	if on:
		ink.ink(RisoPrint.ACCENT, 0.35, [RisoShapes.circle(Vector2(0, top + 5.0), LAMP + 5.0, 18)], false)
		ink.ink(RisoPrint.ACCENT, 1.0, [lamp], false)
		ink.knock([RisoPrint.ACCENT], [RisoShapes.circle(Vector2(-2.0, top + 3.0), 2.2, 8)])
	else:
		ink.ink(RisoPrint.NIGHT, 0.9, [lamp], false)
