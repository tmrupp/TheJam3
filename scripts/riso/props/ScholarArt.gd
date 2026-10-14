extends CreatureArt
class_name ScholarArt
## The institute's people (Scholar), printed after the original wizard the player once was: a
## robe flaring to a hem that swings as they walk, a collar and a sleeve to the hand, a faceless
## dark head with two lit eyes, a floppy pointed hat with a brim and a band (but for the students,
## who go bareheaded), and a spell's orb floating at the shoulder. Drawn in the wizard's own art units (from its feet, facing right),
## SIZE[kind] px each. By kind:
## - a student: small and bareheaded, in a plum gown (pink over blue), a pink orb that
##   swells and brightens as it winds up a bolt and sputters when it misfires; scattering, it
##   leans away and its eyes go small.
## - a master: tall, in a pale gown edged in pink with a pink stole, its hat taller, its orb pink
##   with the mark of the spell it has mastered (RisoGlyph) knocked to paper on it, and its tier
##   of health as pips over its hat; winding up, its hand comes up and the orb goes to it.
## - a proctor: a brown gown under a flat-topped wooden cap with a tassel, leaning on a tall staff headed
##   with a pink ring, the links to those it shields flashing as it shields them.
## - a librarian: in pale tan, hooded, no hat, round paper spectacles over its eyes, a book held open before it,
##   and round it the ring of its hush, faint blue, rippling.
## Pink is danger, so every eye's pupil and every spell is pink. Stunned, stars circle over the
## hat and its eyes shut.

## Px per art unit, by kind.
const SIZE: Dictionary = {&"student": 2.7, &"master": 3.5, &"proctor": 3.0, &"librarian": 2.9}
## The hem's points across, in art units, and how far a stride is (px walked a step).
const HEMX: Array[float] = [-8.8, -4.5, 0.0, 4.5, 8.8]
const STRIDE: float = 70.0
## Cleared under the robe and hat so their inks print true over whatever is behind.
const UNDER: Array[int] = [RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE]

## How much bigger a spell's mark (RisoGlyph, about 24 px from its middle to its edge) is drawn
## than a master's orb is across: the orb's radius over this.
const GLYPH: float = 32.0

## Eased: how much it is walking (0 to 1), and its lean.
var walk: float = 0.0
var lean: float = 0.0


var scholar: Scholar:
	get:
		return host as Scholar


## A shield round it centres on its body, not its feet.
func guard_center() -> Vector2:
	if host == null:
		return global_position
	return host.global_position + Vector2(0, -14.0 * float(SIZE.get(scholar.kind, 3.0)) + _ground())


func _draw_art() -> void:
	var s: Scholar = scholar
	if s == null:
		return
	var kind: StringName = s.kind
	var k: float = float(SIZE.get(kind, 3.0))
	var g: float = _ground()
	var f: float = s.facing
	walk = move_toward(walk, 1.0 if s.walking else 0.0, _dt * 6.0)
	var wind: float = s.wind_up()
	var stunned: bool = s.stunned()
	var scared: bool = s.scatter > 0.0
	var lean_to: float = (-0.12 if wind >= 0.0 else 0.0) + (0.14 if scared else 0.0) + walk * 0.05
	lean = move_toward(lean, lean_to, _dt * 1.5)
	# Art units, from the feet, facing right (mirrored to face left).
	var xf: Transform2D = Transform2D(0.0, Vector2(f * k, k), 0.0, Vector2(0, g)) * Transform2D(lean, Vector2.ZERO)
	var ph: float = s.walked / STRIDE
	var bob: float = absf(sin(ph * PI)) * 0.8 * walk + sin(t * 1.6 + phase) * 0.25
	var hem: Array[Vector2] = []
	for i: int in range(5):
		var swing: float = sin(ph * TAU + float(i) * 0.7) * 1.3 * walk + sin(t * 1.3 + phase + float(i)) * 0.35
		hem.append(Vector2(HEMX[i] + swing - walk * 0.8, -1.0 - absf(swing) * 0.25))
	var shoulders: float = -15.9 + bob
	if kind == &"master":
		shoulders -= 2.0
	var robe: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([
		Vector2(-2.4, shoulders), Vector2(-4.8, shoulders + 1.1), Vector2(-6.3 + (hem[0].x + 8.8) * 0.45, -8.4 + bob * 0.5),
		Vector2(hem[0].x - 0.5, hem[0].y + 0.3), hem[1], hem[2], hem[3], Vector2(hem[4].x + 0.5, hem[4].y + 0.3),
		Vector2(6.3 + (hem[4].x - 8.8) * 0.45, -8.4 + bob * 0.5), Vector2(4.8, shoulders + 1.1), Vector2(2.4, shoulders)]))
	var back_shade: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([
		Vector2(-0.8, shoulders + 2.1), Vector2(-4.3, -10.0 + bob * 0.6), Vector2(hem[0].x + 0.9, hem[0].y - 0.2),
		Vector2(hem[1].x, hem[1].y - 0.3), Vector2(-1.6 + hem[1].x * 0.3, -7.0 + bob * 0.5)]))
	var folds: Array[PackedVector2Array] = []
	for i: int in [1, 2, 3]:
		var top: Vector2 = Vector2(HEMX[i] * 0.3, shoulders + 2.9)
		var w: float = 0.9 + absf(float(i - 2)) * 0.25
		var mid: Vector2 = (top + hem[i]) * 0.5
		folds.append(xf * RisoShapes.smooth(PackedVector2Array([top + Vector2(-0.15, 0), mid + Vector2(-w * 0.45, 0), hem[i] + Vector2(-w, -0.3),
			hem[i] + Vector2(0, -1.4), hem[i] + Vector2(w, -0.3), mid + Vector2(w * 0.45, 0), top + Vector2(0.15, 0)]), 3))
	# The hand: swinging as it walks; raised toward its foe as it winds up.
	var swing_hand: float = -sin(ph * TAU) * 1.7 * walk
	var hand: Vector2 = Vector2(4.4 + swing_hand, -9.2 + bob * 0.8)
	if wind >= 0.0:
		hand = hand.lerp(Vector2(9.5, -15.5 + bob), smoothstep(0.0, 0.6, wind))
	if scared:
		hand = Vector2(5.5, -19.0 + bob)
	var sleeve: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([
		Vector2(0.8, shoulders + 1.5), Vector2(4.2, shoulders + 2.3), hand + Vector2(1.9, -0.2),
		hand + Vector2(0.9, 2.0), hand + Vector2(-1.4, 1.7), Vector2(1.6, -9.8 + bob)]))
	var collar: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([
		Vector2(-4.9, shoulders + 1.0), Vector2(-3.2, shoulders - 1.7), Vector2(-0.8, shoulders - 0.5), Vector2(0.8, shoulders - 0.5),
		Vector2(3.2, shoulders - 1.7), Vector2(4.9, shoulders + 1.0), Vector2(0, shoulders + 2.3)]))
	var head_y: float = shoulders - 2.6
	var face: PackedVector2Array = RisoShapes.ellipse(Vector2(0.35, head_y), 3.8, 3.3, 22)
	var boots: Array[PackedVector2Array] = []
	for side: float in [-1.0, 1.0]:
		var step: float = sin(ph * TAU + (0.0 if side < 0.0 else PI)) * 2.2 * walk
		var lift: float = maxf(0.0, cos(ph * TAU + (0.0 if side < 0.0 else PI))) * 1.2 * walk
		boots.append(xf * _boot(Vector2(side * 2.4 + step, -lift)))
	var robe_m: PackedVector2Array = xf * robe
	ink.ink(RisoPrint.NIGHT, 1.0, boots, false)
	ink.ink(RisoPrint.BLUE, 1.0, boots, false)
	ink.knock(UNDER, [robe_m])
	_gown(kind, [robe_m], 1.0)
	ink.ink(RisoPrint.NIGHT, 0.2, [xf * back_shade], false)
	ink.ink(RisoPrint.NIGHT, 0.4, folds, false)
	if kind == &"master":
		_stole(xf, shoulders, hem)
	# The face: a dark hollow with two lit eyes, pink pupils.
	var face_m: PackedVector2Array = xf * face
	ink.ink(RisoPrint.NIGHT, 1.0, [face_m], false)
	ink.ink(RisoPrint.BLUE, 1.0, [face_m], false)
	_eyes(xf, head_y, stunned, scared, kind == &"librarian")
	ink.knock(UNDER, [xf * collar])
	_gown(kind, [xf * collar], 0.8)
	ink.ink(RisoPrint.NIGHT, 0.22, [xf * collar], false)
	ink.knock(UNDER, [xf * sleeve])
	_gown(kind, [xf * sleeve], 1.0)
	ink.ink(RisoPrint.NIGHT, 0.22, [xf * sleeve], false)
	var crown: Vector2 = _headwear(kind, xf, head_y, s)
	match kind:
		&"proctor":
			_staff(xf, hand, s)
		&"librarian":
			_book(xf, hand)
			_hush(s)
		_:
			_orb(kind, xf, hand, wind, s)
	if kind == &"master":
		_pips(xf * (crown + Vector2(0, -3.5)), s)
	if stunned:
		_stun_mark(xf * (crown + Vector2(0, -4.0)))


## A boot at `at` (art units).
func _boot(at: Vector2) -> PackedVector2Array:
	return Transform2D(0.0, at) * RisoShapes.smooth(PackedVector2Array([Vector2(-1.9, 0.1), Vector2(1.2, 0.1), Vector2(3.3, -0.1), Vector2(3.5, -1.2),
		Vector2(2.3, -2.0), Vector2(1.0, -2.2), Vector2(0.9, -4.0), Vector2(-1.6, -4.0), Vector2(-2.0, -1.6)]), 3)


## A gown's inks (`cover` of them), by kind, laid on paper (what is under it is knocked out first).
func _gown(kind: StringName, polys: Array[PackedVector2Array], cover: float) -> void:
	match kind:
		&"student":
			ink.ink(RisoPrint.PINK, 0.8 * cover, polys, false)
			ink.ink(RisoPrint.BLUE, 0.45 * cover, polys, false)
		&"master":
			ink.ink(RisoPrint.BLUE, 0.12 * cover, polys, false)
		&"proctor":
			ink.ink(RisoPrint.BLUE, 0.6 * cover, polys, false)
			ink.ink(RisoPrint.NIGHT, 0.12 * cover, polys, false)
		_:
			ink.ink(RisoPrint.BLUE, 0.32 * cover, polys, false)


## A master's stole: two pink bands down its front from the collar, and a pink edge along its hem.
func _stole(xf: Transform2D, shoulders: float, hem: Array[Vector2]) -> void:
	var bands: Array[PackedVector2Array] = []
	for x: float in [-1.6, 1.6]:
		bands.append(xf * RisoShapes.smooth(PackedVector2Array([Vector2(x - 0.7, shoulders + 1.0), Vector2(x + 0.7, shoulders + 1.0),
			Vector2(x * 1.6 + 0.8, -2.6), Vector2(x * 1.6 - 0.8, -2.6)]), 2))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], bands)
	ink.ink(RisoPrint.PINK, 1.0, bands, false)
	var edge: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in hem:
		edge.append(p + Vector2(0, -0.2))
	ink.ink(RisoPrint.PINK, 1.0, RisoDecor.strip(xf * edge, 2.2 * float(SIZE[&"master"]), 1.6 * float(SIZE[&"master"])), false)


## Its eyes: knocked to paper with pink pupils looking at the wizard; shut while stunned, small
## while scattering; behind round paper spectacles for a librarian.
func _eyes(xf: Transform2D, head_y: float, stunned: bool, scared: bool, spectacles: bool) -> void:
	var at: Array[Vector2] = [Vector2(0.9 - 1.45, head_y), Vector2(0.9 + 1.45, head_y)]
	if spectacles:
		var rims: Array[PackedVector2Array] = []
		for c: Vector2 in at:
			var outer: PackedVector2Array = RisoShapes.circle(c, 1.6, 14)
			rims.append(xf * outer)
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], rims)
		ink.ink(RisoPrint.BLUE, 0.25, rims, false)
	var whites: Array[PackedVector2Array] = []
	for c: Vector2 in at:
		if stunned:
			whites.append(xf * RisoShapes.rrect(c.x - 1.0, c.y - 0.2, 2.0, 0.4, 0.2))
		else:
			whites.append(xf * RisoShapes.ellipse(c, 0.55 if scared else 1.0, 0.55 if scared else 0.95, 12))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], whites)
	if stunned:
		return
	var player: Player = Stage.player()
	var look: Vector2 = Vector2.ZERO
	if player != null:
		var d: Vector2 = player.global_position - host.global_position
		look = Vector2(clampf(absf(d.x) / 300.0, 0.0, 1.0) * 0.3, clampf(d.y / 300.0, -1.0, 1.0) * 0.25)
	var pupils: Array[PackedVector2Array] = []
	for c: Vector2 in at:
		pupils.append(xf * RisoShapes.circle(c + look, 0.3 if scared else 0.5, 8))
	ink.ink(RisoPrint.PINK, 1.0, pupils, false)


## What it wears on its head (see the class description); the point over its crown comes back (art
## units), where its marks hang.
func _headwear(kind: StringName, xf: Transform2D, head_y: float, s: Scholar) -> Vector2:
	var base: Vector2 = Vector2(0.05, head_y - 2.8)
	match kind:
		&"student":
			# Bareheaded: nothing over its dark head.
			return Vector2(0, head_y - 3.4)
		&"librarian":
			# A hood drawn over the head, back over the shoulders.
			var hood: PackedVector2Array = xf * RisoShapes.smooth(PackedVector2Array([Vector2(-4.4, head_y + 3.5), Vector2(-5.4, head_y - 1.0),
				Vector2(-3.4, head_y - 5.2), Vector2(1.4, head_y - 5.6), Vector2(4.6, head_y - 3.0), Vector2(4.9, head_y + 0.8),
				Vector2(3.6, head_y - 1.8), Vector2(0.4, head_y - 3.8), Vector2(-2.6, head_y - 2.0), Vector2(-3.0, head_y + 3.2)]), 2)
			ink.knock(UNDER, [hood])
			_gown(kind, [hood], 1.0)
			ink.ink(RisoPrint.NIGHT, 0.3, [hood], false)
			return Vector2(0, head_y - 5.6)
		&"proctor":
			# A flat cap: a band round the head, a square board on top, a tassel hanging from its
			# middle to one side.
			var band: PackedVector2Array = xf * RisoShapes.rrect(-3.6, head_y - 4.4, 7.2, 2.0, 0.6)
			var board: PackedVector2Array = xf * PackedVector2Array([Vector2(-6.4, head_y - 4.8), Vector2(0.2, head_y - 6.6), Vector2(6.6, head_y - 4.8), Vector2(0.0, head_y - 3.4)])
			ink.knock(UNDER, [band, board])
			ink.ink(RisoPrint.BLUE, 1.0, [band, board], false)
			ink.ink(RisoPrint.NIGHT, 0.45, [band], false)
			var sway: float = sin(t * 2.0 + phase) * 0.5
			var tassel: PackedVector2Array = xf * PackedVector2Array([Vector2(0.2, head_y - 5.2), Vector2(4.4 + sway, head_y - 4.0), Vector2(4.8 + sway, head_y - 0.8), Vector2(4.0 + sway, head_y - 0.8), Vector2(3.8 + sway, head_y - 3.6)])
			ink.ink(RisoPrint.PINK, 1.0, [tassel])
			return Vector2(0, head_y - 6.6)
	# A floppy pointed hat: its tip leans back from the way it walks and sways as it stands.
	var tall: float = 11.5 if kind == &"master" else 8.8
	var ta: float = 0.55 + 0.25 * walk + sin(t * 1.7 + phase) * 0.15 - (0.35 if s.wind_up() >= 0.0 else 0.0)
	var d2: Vector2 = Vector2(-sin(ta), -cos(ta))
	var pp: Vector2 = Vector2(cos(ta), -sin(ta))
	var tip: Vector2 = Vector2(d2.x * tall, -7.4 + d2.y * tall)
	var mh: Transform2D = xf * Transform2D(0.0, base)
	var cone: PackedVector2Array = mh * RisoShapes.smooth(PackedVector2Array([
		Vector2(-5.1, -0.25), Vector2(-3.1 + tip.x * 0.3, -7.3), tip - d2 * 1.6 - pp * 1.15, tip + d2 * 0.55,
		tip - d2 * 1.6 + pp * 1.15, Vector2(3.1 + tip.x * 0.3, -7.3), Vector2(5.1, -0.25), Vector2(0, 0.55)]))
	var brim: PackedVector2Array = mh * RisoShapes.ellipse(Vector2.ZERO, 9.2, 1.8, 28)
	var band: PackedVector2Array = mh * RisoShapes.smooth(PackedVector2Array([Vector2(-5.4, -0.3), Vector2(0, -0.1), Vector2(5.4, -0.3), Vector2(4.6, -3.3), Vector2(0, -3.5), Vector2(-4.6, -3.3)]))
	ink.knock(UNDER, [cone, brim])
	_gown(kind, [cone, brim], 1.0)
	ink.ink(RisoPrint.NIGHT, 0.22, [cone], false)
	ink.ink(RisoPrint.PINK, 1.0, [band], false)
	if kind == &"master":
		# The tip's bead, in paper.
		ink.knock(UNDER, [mh * RisoShapes.circle(tip - d2 * 0.4, 0.9, 10)])
	return base + tip


## The spell's orb: at the shoulder away from the hand, bobbing; winding up it goes to the hand and
## swells. A student's is pink, brightening; a master's pink with its spell's mark knocked to paper on
## it. Just cast, it flares; a misfire sputters it.
func _orb(kind: StringName, xf: Transform2D, hand: Vector2, wind: float, s: Scholar) -> void:
	var rest: Vector2 = Vector2(-10.5, -17.5 + sin(t * 2.2 + phase) * 1.0)
	var at: Vector2 = rest
	var size: float = 3.0 if kind == &"student" else 3.9
	if wind >= 0.0:
		at = rest.lerp(hand + Vector2(2.5, -1.5), smoothstep(0.0, 0.5, wind))
		size *= 1.0 + 0.35 * wind
	var flare: float = clampf(1.0 - s.since_cast / 0.25, 0.0, 1.0)
	var c: Vector2 = xf * at
	var k: float = absf(xf.get_scale().y)
	if s.misfired and s.since_cast < 0.4:
		# Sputtering: a dull, broken orb.
		ink.ink(RisoPrint.NIGHT, 0.6, [RisoShapes.circle(c, size * k * 0.8, 14)], false)
		return
	ink.ink(RisoPrint.PINK, 0.25 + 0.25 * maxf(wind, flare), [RisoShapes.circle(c, size * k * (1.9 + flare), 20)])
	var core: PackedVector2Array = RisoShapes.circle(c, size * k, 18)
	ink.knock(UNDER, [core])
	ink.ink(RisoPrint.PINK, 1.0, [core], false)
	if kind == &"master" and s.ability != &"":
		var mark: Array[PackedVector2Array] = []
		# Kept on the orb: a mark that reaches past it (a slash's blade) is cut to its edge.
		for poly: PackedVector2Array in RisoGlyph.of(s.ability, Vector2.ZERO, t):
			mark.append_array(Geometry2D.intersect_polygons(Transform2D(0.0, Vector2(size * k / GLYPH, size * k / GLYPH), 0.0, c) * poly, core))
		ink.knock([RisoPrint.PINK, RisoPrint.NIGHT, RisoPrint.BLUE], mark)
	else:
		ink.knock([RisoPrint.PINK], [RisoShapes.circle(c + Vector2(-0.35, -0.35) * size * k, 0.4 * size * k, 10)])


## A master's health as pips over its hat: pink while whole, faint once lost.
func _pips(c: Vector2, s: Scholar) -> void:
	var wound: Wound = s.get_node_or_null("Wound") as Wound
	if wound == null:
		return
	var full: int = maxi(wound.hp, int(Scholar.HP[&"master"]))
	var whole: Array[PackedVector2Array] = []
	for i: int in range(wound.hp):
		var at: Vector2 = c + Vector2((float(i) - float(full - 1) * 0.5) * 13.0, 0)
		whole.append(PackedVector2Array([at + Vector2(0, -4.5), at + Vector2(4.5, 0), at + Vector2(0, 4.5), at + Vector2(-4.5, 0)]))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], whole)
	ink.ink(RisoPrint.PINK, 1.0, whole, false)


## A proctor's staff: a tall pole in its hand, headed with a pink ring; as it shields those round it,
## faint pink links flash out to them.
func _staff(xf: Transform2D, hand: Vector2, s: Scholar) -> void:
	var foot: Vector2 = Vector2(hand.x + 1.0, 0.0)
	var head: Vector2 = Vector2(hand.x + 1.0, -27.0)
	ink.ink(RisoPrint.BLUE, 1.0, [xf * RisoShapes.rrect(foot.x - 0.5, head.y, 1.0, -head.y, 0.4)])
	var ring: Array[PackedVector2Array] = []
	for piece: PackedVector2Array in RisoShapes.ring(head, 1.5, 2.6, 20):
		ring.append(xf * piece)
	ink.ink(RisoPrint.PINK, 1.0, ring)
	if s.since_shield < 0.5:
		var u: float = 1.0 - s.since_shield / 0.5
		var from: Vector2 = xf * head
		var links: Array[PackedVector2Array] = []
		for node: Node in s.get_tree().get_nodes_in_group(&"scholar"):
			var o: Scholar = node as Scholar
			if o == null or o == s or Shield.of(o) == null or o.global_position.distance_to(s.global_position) > Scholar.SHIELD_REACH:
				continue
			links.append(Spider.strand(from, to_local(o.global_position + Vector2(0, -40)), 3.0))
		ink.ink(RisoPrint.PINK, 0.6 * u, links)


## A librarian's book, held open before it: two paper pages with night lines on them.
func _book(xf: Transform2D, hand: Vector2) -> void:
	var c: Vector2 = hand + Vector2(1.5, -1.0)
	var pages: Array[PackedVector2Array] = [
		xf * PackedVector2Array([c + Vector2(-3.2, -1.6), c + Vector2(0, -1.0), c + Vector2(0, 2.0), c + Vector2(-3.2, 1.4)]),
		xf * PackedVector2Array([c + Vector2(0, -1.0), c + Vector2(3.2, -1.6), c + Vector2(3.2, 1.4), c + Vector2(0, 2.0)]),
	]
	ink.ink(RisoPrint.NIGHT, 1.0, [xf * PackedVector2Array([c + Vector2(-3.6, -1.9), c + Vector2(3.6, -1.9), c + Vector2(3.6, 1.8), c + Vector2(0, 2.5), c + Vector2(-3.6, 1.8)])], false)
	ink.knock(UNDER, pages)
	var lines: Array[PackedVector2Array] = []
	for i: int in range(3):
		var y: float = -0.6 + float(i) * 0.7
		lines.append(xf * RisoShapes.rrect(c.x - 2.7, c.y + y, 2.2, 0.22, 0.1))
		lines.append(xf * RisoShapes.rrect(c.x + 0.5, c.y + y, 2.2, 0.22, 0.1))
	ink.ink(RisoPrint.NIGHT, 0.6, lines, false)


## A librarian's hush: a faint blue ring at its reach, with two ripples running in to it.
func _hush(s: Scholar) -> void:
	var c: Vector2 = to_local(s.global_position + Vector2(0, -Scholar.AIM))
	var rings: Array[PackedVector2Array] = []
	for i: int in range(3):
		var u: float = fposmod(t * 0.4 + float(i) / 3.0, 1.0)
		var r: float = Scholar.HUSH * (1.0 - 0.35 * u)
		var w: float = 3.0 if i == 0 else 2.0
		rings.append_array(RisoShapes.ring(c, r - w, r, 48))
	ink.ink(RisoPrint.BLUE, 0.35, rings, false)
	ink.ink(RisoPrint.BLUE, 0.06, [RisoShapes.circle(c, Scholar.HUSH, 48)], false)
