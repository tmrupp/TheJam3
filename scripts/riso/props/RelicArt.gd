extends RisoProp
## A relic: a medallion with its move's mark over a small plinth, and its pop-up.


## The Relic it dresses.
var relic: Relic:
	get:
		return host as Relic


## A relic: a medallion (an accent ring round a disc of bare paper with the move's mark on it)
## floating over a small plinth in a ring of light, with three motes
## circling it; its name and tier pop up as the wizard steps up to it ("swap" too, when taking it
## would replace the spell in the slot).
func _draw_art() -> void:
	var g: float = _ground()
	var held: Array = relic.holds()
	var a: StringName = held[0]
	var bob: float = sin(t * 2.0 + phase) * 4.0
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(-30, g - 20, 60, 20, 6)])
	ink.ink(RisoPrint.NIGHT, 0.6, [RisoShapes.rrect(-20, g - 28, 40, 10, 4)])
	var c: Vector2 = Vector2(0, g - 86 + bob)
	var breathe: float = 1.0 + 0.06 * sin(t * 3.0 + phase)
	ink.ink(RisoPrint.EYE, 0.25, [RisoShapes.circle(c, 54.0 * breathe, 32)], false)
	# A medallion: a solid accent ring round a disc of bare paper, the move's mark on it.
	var disc: PackedVector2Array = RisoShapes.circle(c, 33.0, 32)
	ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.circle(c, 39.0, 32)])
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE], [disc])
	ink.ink(RisoPrint.ACCENT, 0.18, [disc], false)
	var fit: Transform2D = Transform2D(0.0, Vector2(1.05, 1.05), 0.0, c)
	var mark: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in RisoGlyph.of(a, Vector2.ZERO, t):
		mark.append(fit * poly)
	ink.ink(RisoPrint.NIGHT, 1.0, mark, false)
	var motes: Array[PackedVector2Array] = []
	for k: int in range(3):
		var ang: float = t * 1.4 + TAU * float(k) / 3.0
		motes.append(RisoShapes.sparkle(c + Vector2(cos(ang) * 52.0, sin(ang) * 18.0), 8.0))
	ink.ink(RisoPrint.ACCENT, 1.0, motes, false)
	var sl: float = _pop(0, Vector2(0, g - 50))
	if sl > 0.0:
		var owed: int = relic.price()
		var label: String = "%s %s" % [Abilities.label(a), Abilities.roman(int(held[1]))]
		_plaque(label + (" · %d" % owed if owed > 0 else " · take back"), Vector2(0, g - POP_Y), 30, RisoPrint.ACCENT, sl)
		var player: Player = Stage.player()
		if relic.swap():
			_plaque("swap", Vector2(0, g - POP_Y - 40.0 * sl), 22, RisoPrint.PINK, sl)
		elif owed > 0 and player != null and Abilities.tier(player, a) > 0:
			# A move already known: this relic raises it a tier.
			_plaque("upgrade" if Abilities.tier(player, a) < Abilities.max_tier(a) else "already mastered", Vector2(0, g - POP_Y - 40.0 * sl), 22, RisoPrint.BLUE, sl)
