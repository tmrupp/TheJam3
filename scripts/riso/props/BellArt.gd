extends RisoProp
class_name BellArt
## A grave bell on its post, chained, free or rung (VaneArt prints the sky's vanes on the same
## chain).


## The Bell it dresses.
var bell: Bell:
	get:
		return host as Bell


## A grave bell on a post by a chasm (Bell): a post and crossbar in blue, the bell in accent ink
## hanging from it. Chained, a night-ink chain is wound round it and down to the post, held by a
## padlock in its key's colour or a plate with the switch emblem and the sigil its switch shares;
## struck, it rattles. Freed, the
## chain drops away and the bell sways in a soft halo, waiting. Rung, it swings hard and rings out
## in arcs that fade; one rung on an earlier visit hangs still and dim.
func _draw_art() -> void:
	var g: float = _ground()
	var rung: bool = bell.rung()
	var chained: bool = not bell.unchained()
	var since: float = bell.since_rung
	var rattle: float = bell.since_rattle
	var freed: float = bell.since_freed
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(-5.0, g - 150.0, 10.0, 150.0, 4.0), RisoShapes.rrect(-5.0, g - 150.0, 46.0, 9.0, 4.0)])
	var swing: float = sin(t * 1.4 + phase) * (0.015 if chained else 0.06)
	if rattle < 0.8:
		swing += sin(rattle * 38.0) * 0.12 * exp(-rattle * 5.0)
	if since >= 0.0 and since < 3.0:
		swing = sin(since * 9.0) * 0.6 * exp(-since * 1.2)
	elif rung:
		swing = 0.0
	var hang: Transform2D = Transform2D(swing, Vector2(2.0, 2.0), 0.0, Vector2(30.0, g - 141.0))
	if not rung and not chained:
		# Free and waiting to be rung: a soft halo, so it reads as something to use.
		ink.ink(RisoPrint.ACCENT, 0.18 + 0.06 * sin(t * 2.5 + phase), [RisoShapes.circle(Vector2(30.0, g - 100.0), 46.0, 28)])
	var body: PackedVector2Array = hang * RisoShapes.smooth(PackedVector2Array([Vector2(-4, 2), Vector2(-9, 12), Vector2(-11, 26), Vector2(-17, 36), Vector2(17, 36), Vector2(11, 26), Vector2(9, 12), Vector2(4, 2)]), 3)
	var cover: float = 0.55 if rung and since < 0.0 else 1.0
	ink.ink(RisoPrint.BLUE, 1.0, [hang * RisoShapes.rrect(-1.5, -2.0, 3.0, 6.0, 1.5)])
	ink.ink(RisoPrint.ACCENT, cover, [body])
	ink.ink(RisoPrint.NIGHT, 0.3, [hang * RisoShapes.smooth(PackedVector2Array([Vector2(3, 6), Vector2(9, 14), Vector2(11, 26), Vector2(17, 36), Vector2(6, 36)]), 3)], false)
	ink.ink(RisoPrint.NIGHT, 0.9, [hang * RisoShapes.circle(Vector2(-swing * 30.0, 40.0), 4.5, 10)], false)
	if chained or freed < 0.7:
		_bell_chain(hang, g, chained, freed)
	if since >= 0.0 and since < 1.6:
		var arcs: Array[PackedVector2Array] = []
		for k: int in range(3):
			var u: float = fmod(since * 1.4 + float(k) / 3.0, 1.0)
			for side: float in [0.0, PI]:
				arcs.append_array(RisoDecor.strip(RisoMarks.arc_points(hang * Vector2(0, 20), 26.0 + u * 70.0, side - 0.9, side + 0.9), 3.0, 3.0))
		ink.ink(RisoPrint.ACCENT, 0.7 * (1.0 - since / 1.6), arcs, false)


## The chain on a bell: wound twice across it, then pulled taut down to an iron ring set in the
## floor beside the post, where the padlock (or a switch's plate) closes it. Once freed it falls
## away and fades over `freed` seconds.
func _bell_chain(hang: Transform2D, g: float, chained: bool, freed: float) -> void:
	var drop: float = 0.0 if chained else freed * freed * 220.0
	var fade: float = 1.0 if chained else 1.0 - freed / 0.7
	var anchor: Vector2 = Vector2(66.0, g - 6.0)
	var lock_at: Vector2 = anchor + Vector2(0, -22.0)
	# The ring in the floor: an iron staple and its ring (iron prints in the rock's ink, which reads
	# against the night and over the bell alike).
	ink.ink(RisoPrint.BLUE, fade, [RisoShapes.rrect(anchor.x - 14.0, g - 5.0, 28.0, 6.0, 3.0)])
	ink.ink(RisoPrint.BLUE, fade, RisoDecor.strip(RisoMarks.loop_points(anchor + Vector2(0, -7.0), 9.0, 7.0, 0.0), 3.6, 3.6))
	var path: PackedVector2Array = PackedVector2Array([hang * Vector2(-13, 12), hang * Vector2(13, 22), hang * Vector2(-14, 30), hang * Vector2(14, 34), lock_at + Vector2(0, -8.0)])
	for i: int in range(path.size()):
		path[i] += Vector2(0, drop)
	RisoMarks.chain(ink, path, 26.0, 5.2, RisoPrint.BLUE, fade)
	var lock: int = bell.lock
	if lock >= 0:
		RisoMarks.padlock(ink, lock_at + Vector2(0, drop), lock, 1.7, fade)
	else:
		RisoMarks.switch_plate(ink, lock_at + Vector2(0, drop), 1.7, fade, Sigils.of(host))
