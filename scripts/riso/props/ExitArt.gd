extends RisoProp
## A way out of the place: lit when open, dark with a price or a lock when not, with a chevron in
## the crown of its arch pointing where it leads.


## The size of the chevron in the arch's crown (RisoMarks.chevron).
const CHEVRON: float = 0.7

## The LevelExit it dresses.
var door: LevelExit:
	get:
		return host as LevelExit


func _init() -> void:
	# The price prints in the scene, so the wizard standing at the door is over it.
	text_in_scene = true


func _draw_art() -> void:
	# A doorway out of the level. Open exits are lit (cleared to paper, washed yellow, a star);
	# an unpaid deeper exit stays dark and prints its price. A chevron in the arch's crown shows where
	# it leads; what the door holds (a seal, a lock, a price, a star) sits below it.
	var which: int = door.exit
	var owed: int = door.price()
	var needs: int = door.lock()
	var pulse: float = 1.0 + 0.08 * sin(t * 2.5 + phase)
	var g: float = _ground()
	var opening: PackedVector2Array = RisoShapes.arch(-44, g - 110, 88, 110, 14)
	# Where it leads and how grand it is are up to the place (a side world's door, or its way on).
	var place: NextWorldDef = MapInfo.instance.here if MapInfo.instance != null else null
	var grand: bool = place != null and place.exit_grand(which)
	# A way on (the start's way up too) is framed pink; a way back or round, blue.
	var onward: bool = place.leads_on(which) if place != null else which == MapInfo.Exit.DEEPER
	var frame: int = RisoPrint.PINK if onward or grand else RisoPrint.BLUE
	if grand:
		# A grand door: a second, wider frame of accent round the pink one, and a falling cascade
		# of chevrons in its crown (below).
		ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.arch(-64, g - 132, 128, 132, 16)])
		ink.ink(RisoPrint.NIGHT, 0.5, [RisoShapes.arch(-58, g - 125, 116, 125, 15)], false)
	ink.ink(frame, 1.0, [RisoShapes.arch(-52, g - 118, 104, 118, 14)])
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], [opening])
	var star: PackedVector2Array = Transform2D(t * 0.4, Vector2(0, g - 56)) * RisoShapes.sparkle(Vector2.ZERO, 20.0 * pulse)
	if door.sealed() != &"":
		# Sealed by a boss (Bosses): dark, barred across by pink bars, with the boss's seal on them.
		ink.ink(RisoPrint.NIGHT, 1.0, [opening], false)
		ink.ink(RisoPrint.BLUE, 0.35, [opening], false)
		var bars: Array[PackedVector2Array] = []
		for k: int in range(3):
			bars.append(RisoShapes.rrect(-46, g - 74 + float(k) * 23.0, 92, 8, 4))
		ink.ink(RisoPrint.PINK, 0.85, bars, false)
		RisoMarks.boss_seal(ink, Vector2(0, g - 52), 20.0 * pulse)
	elif needs >= 0:
		# Locked: dark, with a lock in the colour of key it needs, as on the doors.
		ink.ink(RisoPrint.NIGHT, 1.0, [opening], false)
		ink.ink(RisoPrint.BLUE, 0.35, [opening], false)
		RisoMarks.padlock(ink, Vector2(0, g - 60), needs, 1.6, 1.0)
	elif owed > 0:
		ink.ink(RisoPrint.NIGHT, 1.0, [opening], false)
		ink.ink(RisoPrint.BLUE, 0.35, [opening], false)
		# The price on a bare-paper plaque, with a star above it.
		var plaque: PackedVector2Array = RisoShapes.rrect(-28, g - 58, 56, 36, 12)
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE], [plaque])
		ink.ink(RisoPrint.ACCENT, 0.2, [plaque], false)
		var mote: PackedVector2Array = Transform2D(t * 0.4, Vector2(0, g - 71)) * RisoShapes.sparkle(Vector2.ZERO, 9.0 * pulse)
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [mote])
		ink.ink(RisoPrint.ACCENT, 1.0, [mote], false)
	else:
		ink.ink(RisoPrint.EYE, 0.3, [opening], false)
		ink.ink(RisoPrint.EYE, 0.35, [RisoShapes.circle(Vector2(0, g - 56), 30.0 * pulse, 28)], false)
		ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT], [star])
		ink.ink(RisoPrint.EYE, 1.0, [star], false)
	# A chevron in the crown of the arch, pointing the way this exit leads (centred on `crown`).
	var dir: Vector2 = place.exit_dir(which) if place != null else Vector2.DOWN
	var crown: Vector2 = Vector2(0, g - 92)
	if grand:
		# Three chevrons falling one after another, fading as they drop: a long way down.
		for k: int in range(3):
			var u: float = fmod(t * 0.9 + float(k) / 3.0, 1.0)
			var c: Vector2 = crown + dir * ((u - 0.5) * 20.0 + 4.0 * CHEVRON)
			ink.ink(RisoPrint.PINK, 1.0 - u * 0.8, [RisoMarks.chevron(c, dir, CHEVRON * 0.85)])
	else:
		var bob: float = sin(t * 3.0 + phase) * 2.0
		ink.ink(frame, 1.0, [RisoMarks.chevron(crown + dir * (bob + 4.0 * CHEVRON), dir, CHEVRON)])
	if owed > 0:
		_text(str(owed), Vector2(0, g - 40), 34)
