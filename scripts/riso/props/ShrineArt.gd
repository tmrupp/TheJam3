extends RisoProp
## The shrine: two niches offering abilities and a bowl for mending, with their pop-ups.


## The Shrine it dresses.
var shrine: Shrine:
	get:
		return host as Shrine


## The shrine: a plinth across two cells carrying three stations side by side: two niches where
## an offered ability's mark floats over its tier pips, then a bowl with an ember bead (mending).
## Each one's name and price pop up over it as the wizard steps up to it. Once used, the marks
## are gone and the trim dims.
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
		return
	var m: Vector2 = Vector2(mx, g - 94 + bob * 0.8)
	var full: bool = not shrine.can_mend()
	if not (full and (shrine.reads_relic() or shrine.sells_skeleton())):
		_mend_bowl(mx, g, bob, full, false, shrine.heal_price())
		return
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(mx - 9, g - 62, 18, 42, 6), RisoShapes.ellipse(Vector2(mx, g - 64), 24.0, 7.0, 22)])
	if full and shrine.reads_relic():
		# At full health: a small relic medallion with the move of the relic it can point to.
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
		var sr: float = _pop(2, Vector2(mx, g - 50))
		if sr > 0.0:
			_plaque("%s relic · where · %d" % [Abilities.label(move), shrine.relic_price()], Vector2(mx, g - POP_Y), 30, RisoPrint.ACCENT, sr)
		return
	if full and shrine.sells_skeleton():
		# At full health: a skeleton key on a paper medallion.
		var plate: PackedVector2Array = RisoShapes.circle(m, 20.0, 24)
		ink.ink(RisoPrint.EYE, 0.25, [RisoShapes.circle(m, 28.0, 28)])
		ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.circle(m, 23.0, 24)])
		ink.knock(RisoPrint.ALL_PLATES, [plate])
		ink.ink(RisoPrint.NIGHT, 1.0, RisoMarks.key_shape(m + Vector2(0, -2), 0.75, KeyRing.SKELETON), false)
		var sk: float = _pop(2, Vector2(mx, g - 50))
		if sk > 0.0:
			_plaque("skeleton key · %d" % shrine.skeleton_price(), Vector2(mx, g - POP_Y), 30, RisoPrint.ACCENT, sk)
		return


## The mending station at x = `mx` over ground `g`: a bowl on a post and, unless `used`, an ember
## bead floating over it like the HUD's health beads (dimmer while `full`: nothing to mend), its
## name and `price` popping up over it while the wizard stands at it. The shrine's third
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
	if s > 0.0:
		_plaque("mend · %d" % price, Vector2(mx, g - POP_Y), 30, RisoPrint.PINK, s)


## One of the shrine's two niches at x = `cx`: the ability's mark floating over its tier pips and,
## while the wizard is at it, a pop-up with its name, tier and price, topped by a "swap" tag when
## it would replace the spell in the slot.
## Once the shrine is spent, a spell a swap left here floats in its niche instead, its pop-up
## offering to take it back.
func _shrine_niche(cx: float, i: int, g: float, bob: float, used: bool) -> void:
	ink.ink(RisoPrint.BLUE, 0.5, [RisoShapes.arch(cx - 36, g - 122, 72, 100, 12)])
	var niche: PackedVector2Array = RisoShapes.arch(cx - 29, g - 115, 58, 93, 12)
	ink.knock([RisoPrint.BLUE], [niche])
	ink.ink(RisoPrint.NIGHT, 1.0, [niche], false)
	var c: Vector2 = Vector2(cx, g - 84 + bob)
	if used:
		# A spell left here by a swap waits in the niche, to be taken back free.
		var left: Array = shrine.left_spell(i)
		if left.is_empty():
			return
		_niche_mark(left[0], c, i, int(left[1]), cx, g)
		var sl: float = _pop(i, Vector2(cx, g - 50))
		if sl > 0.0:
			_plaque("%s %s · take back" % [Abilities.label(left[0]), Abilities.roman(int(left[1]))], Vector2(cx, g - POP_Y), 30, RisoPrint.ACCENT, sl)
			_plaque("swap", Vector2(cx, g - POP_Y - 40.0 * sl), 22, RisoPrint.PINK, sl)
		return
	var a: StringName = shrine.offer(i)
	if a == &"":
		return
	var next: int = shrine.offer_tier(i)
	_niche_mark(a, c, i, next, cx, g)
	# Name, tier and price pop up over the niche only while the wizard stands at it.
	var s: float = _pop(i, Vector2(cx, g - 50))
	if s <= 0.0:
		return
	_plaque("%s %s · %d" % [Abilities.label(a), Abilities.roman(next), shrine.offer_price(i)], Vector2(cx, g - POP_Y), 30, RisoPrint.ACCENT, s)
	var per_cast: int = Abilities.cast_price(a, shrine.depth())
	if per_cast > 0:
		# A spell that costs stars to cast says so under its price.
		_plaque("%d a cast" % per_cast, Vector2(cx, g - POP_Y + 38.0 * s), 20, RisoPrint.BLUE, s)
	if shrine.swap(i):
		_plaque("swap", Vector2(cx, g - POP_Y - 40.0 * s), 22, RisoPrint.PINK, s)


## An ability's mark floating in a shrine niche at `c`, in a soft halo, over `pips_n` tier pips.
func _niche_mark(a: StringName, c: Vector2, i: int, pips_n: int, cx: float, g: float) -> void:
	ink.ink(RisoPrint.ACCENT, 0.18, [RisoShapes.circle(c, 27.0 * (1.0 + 0.05 * sin(t * 3.0 + float(i))), 28)])
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
