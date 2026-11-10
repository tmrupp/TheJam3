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


## The shrine: a plinth across two cells carrying its stations side by side: two niches where
## an offered ability's mark floats over its tier pips, a dial between them for drawing the boons
## again (_redraw_dial), then the third station (Shrine.station): a bowl with an ember bead
## (mending, free), or at full health a medallion over the bowl (a relic's move, a skeleton key, a
## doorway with a chevron pointing on); and at the far end a post with the boss ahead's seal
## (_way_post), for which way it lies. Each one's price pops up over it while the wizard is at it
## (the station they would use, so neighbours never pop up together), with the key it takes
## beside it where it takes one. Once used, the niches' marks and the bowl's are gone and the trim
## dims; the boss's post, which a use does not spend, keeps selling until it has told the way, and
## then keeps a pink chevron pointing it.
func _draw_art() -> void:
	var g: float = _ground()
	var used: bool = shrine.used()
	var bob: float = sin(t * 2.0 + phase) * 3.0
	# Station centres come from the scene, packed across two cells.
	var xs: Array[float] = []
	for station: String in ["Boon", "Boon2", "Mend", "Redraw", "Way"]:
		xs.append((host.get_node(station) as Node2D).position.x * host.scale.x)
	# The plinth runs under them all.
	var left: float = xs[0] - NICHE_HALF - 4.0
	var right: float = xs[4] + 26.0
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(left, g - 22, right - left, 22, 8)])
	ink.ink(RisoPrint.ACCENT, 0.35 if used else 1.0, [RisoShapes.rrect(left + 6, g - 27, right - left - 12, 7, 3.5)])
	for i: int in range(2):
		_shrine_niche(xs[i], i, g, bob * (1.0 if i == 0 else -1.0), used)
	_redraw_dial(xs[3], g, bob)
	_way_post(xs[4], g, bob)
	var mx: float = xs[2]
	if used:
		_mend_bowl(mx, g, bob, false, true, 0)
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
	var sp: float = _focus_pop(2, "Mend")
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
## The radius of the boss's seal on its post (_way_post).
const BOSS_SEAL: float = 15.0
## Half a niche's width (its arch), the size its offered mark is printed at, and the radius of the
## redraw dial between the niches.
const NICHE_HALF: float = 30.0
const NICHE_MARK: float = 0.62
const DIAL_R: float = 11.0


## How far a station's pop-up is shown (RisoProp._pop's ease, 0 hidden): only for the station the
## wizard would use now (`station`, a child of the shrine with an Interactable), so neighbours on
## the narrow plinth never pop up together.
func _focus_pop(i: int, station: String) -> float:
	var it: Interactable = host.get_node_or_null(station + "/Interactable") as Interactable
	var target: float = 1.0 if it != null and it.is_focused() else 0.0
	while pops.size() <= i:
		pops.append(0.0)
	pops[i] = move_toward(pops[i], target, _dt * 5.0)
	var p: float = pops[i] - 1.0
	return 0.0 if pops[i] < 0.02 else 1.0 + 2.7 * p * p * p + 1.7 * p * p


## The dial between the niches for drawing the boons again (Shrine.buy_redraw): a ring broken by
## an arrowhead, turning slowly, in the accent while it can be drawn and faint with no key carried;
## its stars and the key it takes pop up over it. Nothing once the shrine is spent or where its
## boons cannot be drawn again.
func _redraw_dial(cx: float, g: float, bob: float) -> void:
	if not shrine.can_redraw():
		return
	var c: Vector2 = Vector2(cx, g - 64 - bob * 0.5)
	var key: int = shrine.redraw_key()
	var cover: float = 1.0 if key >= 0 else 0.3
	var turn: float = t * 0.8
	var ring: PackedVector2Array = PackedVector2Array()
	var steps: int = 16
	for k: int in range(steps + 1):
		var a: float = turn + 0.5 + (TAU - 1.3) * float(k) / float(steps)
		ring.append(c + Vector2.from_angle(a) * DIAL_R)
	var ends: float = turn + 0.5 + TAU - 1.3
	var tip: Vector2 = c + Vector2.from_angle(ends) * DIAL_R
	var along: Vector2 = Vector2.from_angle(ends + PI * 0.5)
	var head: PackedVector2Array = PackedVector2Array([tip + along * 7.0, tip + along.orthogonal() * 5.0 - along * 2.0, tip - along.orthogonal() * 5.0 - along * 2.0])
	var marks: Array[PackedVector2Array] = RisoDecor.strip(ring, 3.0, 3.0)
	marks.append(head)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], marks)
	ink.ink(RisoPrint.ACCENT, cover, marks, false)
	var s: float = _focus_pop(3, "Redraw")
	if s > 0.0:
		var price: String = str(shrine.redraw_price())
		var pw: float = _plaque_width(price, 30)
		var span: float = pw + KEY_GAP + KEY_PLAQUE.x
		var from: float = cx - span * 0.5 * s
		_plaque(price, Vector2(from + pw * 0.5 * s, g - POP_Y), 30, RisoPrint.ACCENT, s)
		_key_plaque(Vector2(from + (pw + KEY_GAP + KEY_PLAQUE.x * 0.5) * s, g - POP_Y), key, s)


## The post at the shrine's far end for which way the boss ahead lies (Shrine.buy_way): the boss's
## seal (as on the door it seals, RisoMarks.boss_seal) in a pink halo while it sells, its stars
## popping up over it (no key); once this column was told, a pink chevron pointing the way (left,
## right, or on toward the gate for this column). Nothing with no living boss ahead.
func _way_post(cx: float, g: float, bob: float) -> void:
	var told: Variant = shrine.told_way()
	if not shrine.sells_way() and told == null:
		return
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(cx - 6, g - 52, 12, 32, 5)])
	var m: Vector2 = Vector2(cx, g - 72 + bob * 0.6)
	if told != null:
		var way: int = told
		var dir: Vector2 = Vector2(float(way), 0.0)
		if way == 0:
			dir = Vector2(0.0, float(NextWorldDef.away(shrine.map_info.coord.y)))
		var mark: Array[PackedVector2Array] = [RisoMarks.chevron(m, dir, 0.6)]
		# Cut to paper first, so the pink reads over the dark.
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], mark)
		ink.ink(RisoPrint.PINK, 1.0, mark, false)
		return
	ink.ink(RisoPrint.PINK, 0.25, [RisoShapes.circle(m, BOSS_SEAL + 6.0, 24)])
	RisoMarks.boss_seal(ink, m, BOSS_SEAL, 1.0, shrine.boss())
	var s: float = _focus_pop(4, "Way")
	if s > 0.0:
		_plaque(str(shrine.boss_price()), Vector2(cx, g - POP_Y), 30, RisoPrint.PINK, s)
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
	var s: float = _focus_pop(2, "Mend") if host.has_node("Mend/Interactable") else _pop(2, Vector2(mx, g - 50))
	if s > 0.0 and price >= 0:
		_plaque(str(price), Vector2(mx, g - POP_Y), 30, RisoPrint.PINK, s)


## One of the shrine's two niches at x = `cx`: the ability's mark floating over its tier pips and,
## while the wizard is at it, a pop-up with the tier it teaches as a numeral and its price (the mark
## says which ability), under it what a cast costs for a spell that costs stars, and over it the
## swap mark when it would replace the spell in the slot (whose paper then comes back). No words.
func _shrine_niche(cx: float, i: int, g: float, bob: float, used: bool) -> void:
	ink.ink(RisoPrint.BLUE, 0.5, [RisoShapes.arch(cx - NICHE_HALF, g - 122, NICHE_HALF * 2.0, 100, 12)])
	var niche: PackedVector2Array = RisoShapes.arch(cx - NICHE_HALF + 6.0, g - 115, NICHE_HALF * 2.0 - 12.0, 93, 12)
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
	var s: float = _focus_pop(i, "Boon" if i == 0 else "Boon2")
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
	# The mark made smaller, to fit the narrow niche.
	var fit: Transform2D = Transform2D(0.0, Vector2(NICHE_MARK, NICHE_MARK), 0.0, c)
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
