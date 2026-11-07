extends RisoProp
## The shrine: two niches offering abilities and a bowl for mending, with their pop-ups.


## The Shrine it dresses.
var shrine: Shrine:
	get:
		return host as Shrine


func shines() -> bool:
	return true


## A light over the niches, between them.
func light() -> Array:
	return _light(Vector2(0, _ground() - 90.0), RisoLight.BEACON, RisoPrint.ACCENT)


## The shrine: a plinth across two cells carrying three stations side by side: two niches where
## an offered ability's mark floats over its tier pips, then the third station (Shrine.station): a
## bowl with an ember bead (mending, free), or at full health a medallion over the bowl (the boss
## ahead's mark ringed in pink, a relic's move, a skeleton key, a doorway with a chevron pointing on). Each one's price pops up over it as
## the wizard steps up to it, the third's with the key it takes beside it. Once used, the marks are gone
## and the trim dims; a bowl that told which way the boss lies keeps a pink chevron pointing it.
func _draw_art() -> void:
	var g: float = _ground()
	var used: bool = shrine.used()
	var bob: float = sin(t * 2.0 + phase) * 3.0
	# Station centres come from the scene (Boon, Boon2, Mend), packed across two cells.
	var xs: Array[float] = []
	for station: String in ["Boon", "Boon2", "Mend"]:
		xs.append((host.get_node(station) as Node2D).position.x * host.scale.x)
	# The plinth runs under all three: two niches, then the mending bowl.
	var left: float = xs[0] - 40.0
	var right: float = xs[2] + 40.0
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(left, g - 22, right - left, 22, 8)])
	ink.ink(RisoPrint.ACCENT, 0.35 if used else 1.0, [RisoShapes.rrect(left + 6, g - 27, right - left - 12, 7, 3.5)])
	for i: int in range(2):
		_shrine_niche(xs[i], i, g, bob * (1.0 if i == 0 else -1.0), used)
	var mx: float = xs[2]
	if used:
		_mend_bowl(mx, g, bob, false, true, 0)
		_told_way(mx, g, bob)
		return
	var m: Vector2 = Vector2(mx, g - 94 + bob * 0.8)
	var what: StringName = shrine.station()
	if what == &"mend" or what == &"":
		# Mending is free: the bowl's bead, and no price.
		_mend_bowl(mx, g, bob, what == &"", false, -1)
		return
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(mx - 9, g - 62, 18, 42, 6), RisoShapes.ellipse(Vector2(mx, g - 64), 24.0, 7.0, 22)])
	if what == &"relic":
		# A small relic medallion with the move of the relic it can point to.
		var move: StringName = shrine.relic_move()
		var disc: PackedVector2Array = RisoShapes.circle(m, 18.0, 24)
		ink.ink(RisoPrint.EYE, 0.25, [RisoShapes.circle(m, 28.0, 28)])
		ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.circle(m, 22.0, 24)])
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE], [disc])
		ink.ink(RisoPrint.ACCENT, 0.18, [disc], false)
		var fit: Transform2D = Transform2D(0.0, Vector2(0.55, 0.55), 0.0, m)
		var mark: Array[PackedVector2Array] = []
		for poly: PackedVector2Array in RisoGlyph.of(move, Vector2.ZERO, t):
			mark.append(fit * poly)
		ink.ink(RisoPrint.NIGHT, 1.0, mark, false)
	elif what == &"skeleton":
		# A skeleton key on a paper medallion.
		var plate: PackedVector2Array = RisoShapes.circle(m, 20.0, 24)
		ink.ink(RisoPrint.EYE, 0.25, [RisoShapes.circle(m, 28.0, 28)])
		ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.circle(m, 23.0, 24)])
		ink.knock(RisoPrint.ALL_PLATES, [plate])
		ink.ink(RisoPrint.NIGHT, 1.0, RisoMarks.key_shape(m + Vector2(0, -2), 0.75, KeyRing.SKELETON), false)
	elif what == &"door":
		# A way on: a doorway's arch on a paper medallion, a chevron in it pointing on (away from the
		# start), as a way on reads on the map.
		var plate: PackedVector2Array = RisoShapes.circle(m, 20.0, 24)
		ink.ink(RisoPrint.EYE, 0.25, [RisoShapes.circle(m, 28.0, 28)])
		ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.circle(m, 23.0, 24)])
		ink.knock(RisoPrint.ALL_PLATES, [plate])
		var doorway: PackedVector2Array = RisoShapes.arch(m.x - DOORWAY.x * 0.5, m.y - DOORWAY.y * 0.5, DOORWAY.x, DOORWAY.y)
		ink.ink(RisoPrint.NIGHT, 1.0, [doorway], false)
		var on: Vector2 = Vector2(0.0, float(NextWorldDef.away(shrine.map_info.coord.y)))
		var mark: Array[PackedVector2Array] = [RisoMarks.chevron(m + Vector2(0.0, 3.0) + on * 3.0, on, 0.45)]
		ink.knock(RisoPrint.ALL_PLATES, mark)
		ink.ink(RisoPrint.ACCENT, 1.0, mark, false)
	elif what == &"boss":
		# The boss ahead's seal, as on the door it seals (RisoMarks.boss_seal), in a pink halo: which
		# way it lies.
		ink.ink(RisoPrint.PINK, 0.25, [RisoShapes.circle(m, 28.0, 28)])
		RisoMarks.boss_seal(ink, m, BOSS_SEAL, 1.0, shrine.boss())
	var sp: float = _pop(2, Vector2(mx, g - 50))
	if sp > 0.0:
		var price: String = str(shrine.station_price())
		if shrine.keys_asked() <= 0:
			_plaque(price, Vector2(mx, g - POP_Y), 30, RisoPrint.ACCENT, sp)
		else:
			# The price and, beside it, the key it takes too, the pair centred over the station.
			var pw: float = _plaque_width(price, 30)
			var span: float = pw + KEY_GAP + KEY_PLAQUE.x
			var from: float = mx - span * 0.5 * sp
			_plaque(price, Vector2(from + pw * 0.5 * sp, g - POP_Y), 30, RisoPrint.ACCENT, sp)
			_key_plaque(Vector2(from + (pw + KEY_GAP + KEY_PLAQUE.x * 0.5) * sp, g - POP_Y), shrine.taken_key(), sp)


## The size of the doorway on the third station's medallion when it sells a way on, centred on it.
const DOORWAY: Vector2 = Vector2(20, 26)
## The radius of the boss's seal on the third station's medallion.
const BOSS_SEAL: float = 22.0
## The size of the plaque beside a price showing the key it also takes, and the gap between them,
## unscaled.
const KEY_PLAQUE: Vector2 = Vector2(64, 38)
const KEY_GAP: float = 6.0


## A plaque beside the third station's price with the key it takes besides (Shrine.taken_key): that
## key, or, with none carried, a faint common one. No words.
func _key_plaque(at: Vector2, color: int, s: float) -> void:
	var u: InkCanvas = _blank_plaque(at, KEY_PLAQUE, RisoPrint.BLUE, s)
	var shown: int = color if color >= 0 else 0
	u.ink(RisoPrint.NIGHT, 1.0 if color >= 0 else 0.3, RisoMarks.key_shape(at + Vector2(2.0, -2.0) * s, 0.6 * s, shown), false)


## A spent shrine whose column was told which way the boss ahead lies (Shrine.told_way): over the
## empty bowl, a pink chevron pointing left or right, or on toward the gate for this column.
func _told_way(mx: float, g: float, bob: float) -> void:
	var told: Variant = shrine.told_way()
	if told == null:
		return
	var way: int = told
	var dir: Vector2 = Vector2(float(way), 0.0)
	if way == 0:
		dir = Vector2(0.0, float(NextWorldDef.away(shrine.map_info.coord.y)))
	var mark: Array[PackedVector2Array] = [RisoMarks.chevron(Vector2(mx, g - 94 + bob * 0.8), dir, 0.9)]
	# Cut to paper first, so the pink reads over the dark.
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], mark)
	ink.ink(RisoPrint.PINK, 1.0, mark, false)


## The mending station at x = `mx` over ground `g`: a bowl on a post and, unless `used`, an ember
## bead floating over it like the HUD's health beads (dimmer while `full`: nothing to mend), its
## `price` popping up over it while the wizard stands at it (none for a price under 0: free, as the
## shrine's is). The shrine's third
## station, and a mending bowl standing on its own (MendWellArt).
func _mend_bowl(mx: float, g: float, bob: float, full: bool, used: bool, price: int) -> void:
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(mx - 9, g - 62, 18, 42, 6), RisoShapes.ellipse(Vector2(mx, g - 64), 24.0, 7.0, 22)])
	if used:
		return
	var m: Vector2 = Vector2(mx, g - 94 + bob * 0.8)
	ink.ink(RisoPrint.EYE, 0.12 if full else 0.25, [RisoShapes.circle(m, 25.0, 28)])
	var bead: PackedVector2Array = RisoShapes.circle(m, 12.0, 22)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], [bead])
	ink.ink(RisoPrint.EYE, 0.5 if full else 1.0, [bead], false)
	ink.ink(RisoPrint.PINK, 0.35, [bead], false)
	ink.knock([RisoPrint.EYE, RisoPrint.PINK], [RisoShapes.circle(m + Vector2(-3.5, -3.5), 4.0, 12)])
	var s: float = _pop(2, Vector2(mx, g - 50))
	if s > 0.0 and price >= 0:
		_plaque(str(price), Vector2(mx, g - POP_Y), 30, RisoPrint.PINK, s)


## One of the shrine's two niches at x = `cx`: the ability's mark floating over its tier pips and,
## while the wizard is at it, a pop-up with the tier it teaches as a numeral and its price (the mark
## says which ability), under it what a cast costs for a spell that costs stars, and over it the
## swap mark when it would replace the spell in the slot (whose paper then comes back). No words.
func _shrine_niche(cx: float, i: int, g: float, bob: float, used: bool) -> void:
	ink.ink(RisoPrint.BLUE, 0.5, [RisoShapes.arch(cx - 36, g - 122, 72, 100, 12)])
	var niche: PackedVector2Array = RisoShapes.arch(cx - 29, g - 115, 58, 93, 12)
	ink.knock([RisoPrint.BLUE], [niche])
	ink.ink(RisoPrint.NIGHT, 1.0, [niche], false)
	var c: Vector2 = Vector2(cx, g - 84 + bob)
	if used:
		return
	var a: StringName = shrine.offer(i)
	if a == &"":
		return
	var next: int = shrine.offer_tier(i)
	_niche_mark(a, c, i, next, cx, g)
	# Its tier and price pop up over the niche only while the wizard stands at it.
	var s: float = _pop(i, Vector2(cx, g - 50))
	if s <= 0.0:
		return
	_plaque("%s · %d" % [Abilities.roman(next), shrine.offer_price(i)], Vector2(cx, g - POP_Y), 30, RisoPrint.ACCENT, s)
	var per_cast: int = Abilities.cast_price(a, shrine.depth())
	if per_cast > 0:
		# A spell that costs stars to cast shows what a cast costs under its price, by a spark.
		_cast_plaque(str(per_cast), Vector2(cx, g - POP_Y + 38.0 * s), 20, s)
	if shrine.swap(i):
		_swap_plaque(Vector2(cx, g - POP_Y - 40.0 * s), s)


## An ability's mark floating in a shrine niche at `c`, over `pips_n` tier pips (the shrine's own
## light shines on it, see light).
func _niche_mark(a: StringName, c: Vector2, i: int, pips_n: int, cx: float, g: float) -> void:
	# The mark at 0.75 size, to fit the narrower niche.
	var fit: Transform2D = Transform2D(0.0, Vector2(0.75, 0.75), 0.0, c)
	var mark: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in RisoGlyph.of(a, Vector2.ZERO, t):
		mark.append(fit * poly)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], mark)
	ink.ink(RisoPrint.ACCENT, 1.0, mark, false)
	if a == &"vigor":
		ink.ink(RisoPrint.PINK, 0.4, mark, false)
	var pips: Array[PackedVector2Array] = []
	for k: int in range(pips_n):
		pips.append(RisoShapes.circle(Vector2(cx + float(k) * 10.0 - float(pips_n - 1) * 5.0, g - 52.0), 3.2, 10))
	ink.ink(RisoPrint.ACCENT, 1.0, pips)
