extends RisoProp
## A way out of the place: lit when open, dark with a price or a lock when not, with a chevron
## pointing where it leads.


## The LevelExit it dresses.
var door: LevelExit:
	get:
		return host as LevelExit


func _draw_art() -> void:
	# A doorway out of the level. Open exits are lit (cleared to paper, washed yellow, a star);
	# an unpaid deeper exit stays dark and prints its price. A chevron shows where it leads.
	var which: int = door.exit
	var owed: int = door.price()
	var needs: int = door.lock()
	var pulse: float = 1.0 + 0.08 * sin(t * 2.5 + phase)
	var g: float = _ground()
	var opening: PackedVector2Array = RisoShapes.arch(-44, g - 110, 88, 110, 14)
	# Where it leads and how grand it is are up to the place (a side world's door, or its way on).
	var place: NextWorldDef = MapInfo.instance.here if MapInfo.instance != null else null
	var grand: bool = place != null and place.exit_grand(which)
	var frame: int = RisoPrint.PINK if which == MapInfo.Exit.DEEPER or grand else RisoPrint.BLUE
	if grand:
		# A grand door: a second, wider frame of accent round the pink one, and a falling cascade
		# of chevrons over it (below).
		ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.arch(-64, g - 132, 128, 132, 16)])
		ink.ink(RisoPrint.NIGHT, 0.5, [RisoShapes.arch(-58, g - 125, 116, 125, 15)], false)
	ink.ink(frame, 1.0, [RisoShapes.arch(-52, g - 118, 104, 118, 14)])
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], [opening])
	var star: PackedVector2Array = Transform2D(t * 0.4, Vector2(0, g - 58)) * RisoShapes.sparkle(Vector2.ZERO, 20.0 * pulse)
	if needs >= 0:
		# Locked: dark, with a lock in the colour of key it needs, as on the doors.
		ink.ink(RisoPrint.NIGHT, 1.0, [opening], false)
		ink.ink(RisoPrint.BLUE, 0.35, [opening], false)
		RisoMarks.padlock(ink, Vector2(0, g - 68), needs, 1.6, 1.0)
	elif owed > 0:
		ink.ink(RisoPrint.NIGHT, 1.0, [opening], false)
		ink.ink(RisoPrint.BLUE, 0.35, [opening], false)
		# The price on a bare-paper plaque, with a star above it.
		var plaque: PackedVector2Array = RisoShapes.rrect(-28, g - 62, 56, 38, 12)
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE], [plaque])
		ink.ink(RisoPrint.ACCENT, 0.2, [plaque], false)
		var mote: PackedVector2Array = Transform2D(t * 0.4, Vector2(0, g - 82)) * RisoShapes.sparkle(Vector2.ZERO, 13.0 * pulse)
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [mote])
		ink.ink(RisoPrint.ACCENT, 1.0, [mote], false)
	else:
		ink.ink(RisoPrint.EYE, 0.3, [opening], false)
		ink.ink(RisoPrint.EYE, 0.35, [RisoShapes.circle(Vector2(0, g - 58), 30.0 * pulse, 28)], false)
		ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT], [star])
		ink.ink(RisoPrint.EYE, 1.0, [star], false)
	# Chevron above the arch, pointing the way this exit leads.
	var dir: Vector2 = place.exit_dir(which) if place != null else Vector2.DOWN
	var bob: float = sin(t * 3.0 + phase) * 3.0
	var at: Vector2 = Vector2(0, g - 140) + dir * bob
	var side: Vector2 = Vector2(-dir.y, dir.x)
	if grand:
		# Three chevrons falling one after another, fading as they drop: a long way down.
		for k: int in range(3):
			var u: float = fmod(t * 0.9 + float(k) / 3.0, 1.0)
			var c: Vector2 = Vector2(0, g - 196) + dir * (u * 60.0)
			ink.ink(RisoPrint.PINK, 1.0 - u * 0.8, [RisoMarks.chevron(c, dir, 1.0)])
	else:
		var chevron: PackedVector2Array = PackedVector2Array([at + dir * 10.0, at + side * 22.0 - dir * 12.0, at + side * 16.0 - dir * 18.0,
			at - dir * 2.0, at - side * 16.0 - dir * 18.0, at - side * 22.0 - dir * 12.0])
		ink.ink(frame, 1.0, [chevron])
	if owed > 0:
		_text(str(owed), Vector2(0, g - 43), 34)
