class_name RisoCostume
extends RefCounted
## Three travelers printed on the wizard's own canvas and driven by its cloth springs.
## Their spell, health, dash and lantern marks come from the player and run, not the costume.

## The broad glass dome and the spell chamber inside the cosmonaut's backpack.
const HELMET_RADIUS: float = 7.5
const FLASK_RADIUS: float = 4.1
## Health beads stay countable, with extra hearts on a second row or farther down the staff.
const BEAD_RADIUS: float = 1.05
const BEAD_GAP: float = 2.7
const BEADS_PER_ROW: int = 3
## A spell's last seconds blink pink, as on the original wizard's orb.
const SPELL_WARN: float = 1.5
## The spell changes the entire cloth bundle's width, hanging length and weighted side.
const BINDLE_FORMS: Dictionary = {
	&"": Vector3(4.9, 5.0, 0.0), &"hex": Vector3(4.9, 5.2, -0.5),
	&"astral": Vector3(4.0, 6.2, 0.4), &"parry": Vector3(5.7, 4.1, -0.2),
	&"levitate": Vector3(3.6, 6.8, -0.8), &"awareness": Vector3(5.5, 4.8, 0.6),
	&"rift": Vector3(5.1, 5.4, -1.0), &"warp": Vector3(4.6, 5.8, 1.0),
	&"mend": Vector3(4.4, 6.0, 0.0),
}
## The places the three travelers carry their lantern flame, in art units facing right.
const LANTERN_AT: Dictionary = {
	&"cosmonaut": Vector2(0, -8.5), &"shaman": Vector2(12, -30), &"fool": Vector2(10, -5.5),
}
## The wizard supplies the feet, lean, cloth sway, head lag and drawing canvas.
var wizard: RisoWizard
## The current frame turns to face the player's way and follows the body's lean.
var frame: Transform2D
## Shapes of the figure take its momentary pink hurt flash together.
var figure: Array[PackedVector2Array] = []


## Keep the existing art node as the owner of all drawing and animation.
func _init(owner: RisoWizard) -> void:
	wizard = owner


## Draw the selected traveler; the original wizard is drawn by RisoWizard itself.
func draw() -> void:
	var facing: float = 1.0 if wizard.fs >= 0.0 else -1.0
	frame = Transform2D(wizard.lean, Vector2.ZERO) * Transform2D(0.0, Vector2(facing, 1), 0.0, Vector2.ZERO)
	figure.clear()
	wizard.body.coverage = AstralProjection.PROJECTION_COVER if wizard.player.phasing else 1.0
	wizard.body.begin()
	_boots(facing)
	match wizard.character_style():
		&"cosmonaut": _cosmonaut()
		&"shaman": _shaman()
		&"fool": _fool()
	if not wizard.player.phasing and wizard.player.is_invulnerable() and int(wizard.t * 16.0) % 2 == 0:
		wizard.body.knock(RisoPrint.ALL_PLATES, figure)
		wizard.body.ink(RisoPrint.PINK, 1.0, figure, false)
	wizard.body.finish()


## Where smoke starts, including the same lean, facing and bow as the carried lantern.
func lantern_position() -> Vector2:
	var at: Vector2 = LANTERN_AT.get(wizard.character_style(), Vector2.ZERO)
	var facing: float = 1.0 if wizard.fs >= 0.0 else -1.0
	return wizard._smv(Transform2D(wizard.lean, Vector2.ZERO) * Vector2(at.x * facing, at.y - 2.0 + wizard.bob))


## Put a filled shape on its own ink, clearing the other plates beneath it.
func _solid(poly: PackedVector2Array, plate: int = RisoPrint.CLOTH, cover: float = 1.0, flash: bool = true) -> void:
	var shape: PackedVector2Array = wizard._sm(frame * poly)
	wizard.body.knock(RisoPrint.ALL_PLATES, [shape])
	wizard.body.ink(plate, cover, [shape], false)
	if flash:
		figure.append(shape)


## Add screened ink over a shape, for folds, glass and pools of light.
func _over(poly: PackedVector2Array, plate: int, cover: float) -> void:
	wizard.body.ink(plate, cover, [wizard._sm(frame * poly)])


## A pale paper shape with a small amount of yellow ink.
func _paper(poly: PackedVector2Array, tint: float = 0.15) -> void:
	_solid(poly, RisoPrint.EYE, tint, false)


## A filled strap, stick or chain connector between two points; never an outline.
func _bar(a: Vector2, b: Vector2, width: float) -> PackedVector2Array:
	var n: Vector2 = (b - a).normalized().orthogonal() * width * 0.5
	return PackedVector2Array([a - n, b - n, b + n, a + n])


## The same planted, walking and wall-braced feet as the wizard, under simpler boots.
func _boots(facing: float) -> void:
	for foot: Vector2 in wizard._feet():
		var boot: PackedVector2Array = RisoShapes.rrect(-1.7, -3.6, 5.2, 3.8, 1.0)
		var at: Transform2D = Transform2D(wizard.lean, Vector2.ZERO) * Transform2D(0.0, Vector2(facing, 1), 0.0, foot)
		var shape: PackedVector2Array = wizard._sm(at * boot)
		wizard.body.knock(RisoPrint.ALL_PLATES, [shape])
		wizard.body.ink(RisoPrint.CLOTH, 1.0, [shape], false)
		figure.append(shape)
		_paper(RisoShapes.rrect(foot.x * facing - 1.6, foot.y - 3.5, 2.7, 0.9, 0.3), 0.25)


## Simple folded cloth whose back edge follows the existing hem's spring.
func _cloak(poncho: bool = false) -> PackedVector2Array:
	var sway: float = wizard.hem_x[0] * 0.45
	var lift: float = wizard.hem_y[0] * 0.35
	return PackedVector2Array([
		Vector2(-4, -19 + wizard.bob), Vector2(4, -19 + wizard.bob),
		Vector2(7, -13), Vector2(11 if poncho else 8, -3), Vector2(5, -5),
		Vector2(2, -2), Vector2(-1, -5), Vector2(-9 + sway, -2 + lift), Vector2(-11 + sway, -7 + lift), Vector2(-7, -14),
	])


## The unadorned suit, back cape, glass spell flask and pink dash antenna.
func _cosmonaut() -> void:
	var sway: float = wizard.hem_x[0] * 0.65
	var cape: PackedVector2Array = PackedVector2Array([
		Vector2(-3, -20), Vector2(-8, -18), Vector2(-17 + sway, -7 + wizard.hem_y[0] * 0.35),
		Vector2(-14 + sway, -2), Vector2(-7, -5), Vector2(-4, -13),
	])
	_solid(cape)
	_over(cape, RisoPrint.NIGHT, 0.25)
	_solid(RisoShapes.rrect(-5, -19 + wizard.bob, 11, 14, 3))
	_solid(RisoShapes.rrect(-4, -6, 3, 4, 0.8))
	_solid(RisoShapes.rrect(1, -6, 3, 4, 0.8))
	var flask: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([
		Vector2(-14, -27), Vector2(-10, -27), Vector2(-10, -24), Vector2(-6.7, -21),
		Vector2(-6.5, -15), Vector2(-10, -11.5), Vector2(-15, -12), Vector2(-18, -16),
		Vector2(-17, -21), Vector2(-14, -24),
	]))
	_solid(flask, RisoPrint.CLOTH, 0.35)
	_solid(RisoShapes.rrect(-14.2, -28.2, 4.7, 2.0, 0.5), RisoPrint.EYE, 0.35)
	_spell_area(RisoShapes.circle(Vector2(-12.3, -18.5), FLASK_RADIUS), Vector2(-12.3, -18.5), FLASK_RADIUS)
	_paper(RisoShapes.almond(Vector2(-15.6, -19.5), 0.85, 3.1, 10), 0.1)
	_solid(_bar(Vector2(-16.3, -12.8), Vector2(-6.8, -15.0), 1.5), RisoPrint.NIGHT)
	var head: Vector2 = Vector2(0.8, -24 + wizard.head_y)
	_solid(RisoShapes.circle(head, HELMET_RADIUS, 28), RisoPrint.CLOTH, 0.38)
	_solid(RisoShapes.ellipse(head + Vector2(0, 0.8), 5.4, 5.0), RisoPrint.NIGHT)
	_paper(RisoShapes.ellipse(head + Vector2(-4.2, -3.6), 1.35, 3.5, 16, 0.5), 0.1)
	_eyes(head + Vector2(1.5, 0.5))
	_solid(_bar(Vector2(-5.3, -18), Vector2(5.8, -18), 1.6), RisoPrint.NIGHT)
	var antenna: Vector2 = Vector2(-7.8 + wizard.tip_a, -34 + wizard.head_y)
	_solid(_bar(Vector2(-7, -22), Vector2(-8.7, -28), 0.65))
	_solid(_bar(Vector2(-8.7, -28), antenna, 0.65))
	_dash_light(antenna)
	_hand(Vector2(-8, -8.5))
	_hand(Vector2(8, -9.5))
	_health(Vector2(-BEAD_GAP, -13.8 + wizard.bob))
	_lantern(LANTERN_AT[&"cosmonaut"], false)


## A masked traveler whose staff carries both the lantern and its chain of health beads.
func _shaman() -> void:
	var cloak: PackedVector2Array = _cloak()
	_solid(cloak)
	_folds(Vector2(0, -15), 8.0)
	var staff: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([
		Vector2(10, 0), Vector2(11, -19), Vector2(9, -25), Vector2(10, -32),
		Vector2(13, -36), Vector2(14, -35), Vector2(11, -31), Vector2(11, -26),
		Vector2(13, -24), Vector2(12, -17), Vector2(11, 0),
	]))
	_solid(staff)
	_over(staff, RisoPrint.EYE, 0.25)
	_solid(_bar(Vector2(10, -26), Vector2(15, -26), 1.5), RisoPrint.NIGHT)
	_lantern(LANTERN_AT[&"shaman"], false)
	_health(Vector2(16, -23), true)
	_hand(Vector2(10.8, -13))
	_hand(Vector2(-9, -10))
	var center: Vector2 = Vector2(0, -25 + wizard.head_y)
	_solid(RisoShapes.tri(center + Vector2(-8, 0), center + Vector2(-3, -8), center + Vector2(5, 6)), RisoPrint.NIGHT)
	var mask: PackedVector2Array = mask_shape(Abilities.spell(wizard.player), center)
	_spell_area(mask, center, 6.0)
	var charm: Vector2 = center + Vector2(-7.5 + wizard.tip_a, 1.0)
	var ribbon: PackedVector2Array = RisoShapes.almond(charm + Vector2(-1, 3), 1.2, 4.2, 10)
	_solid(ribbon, RisoPrint.PINK if not wizard.player.dash.acted else RisoPrint.CLOTH)
	if not wizard.player.dash.acted:
		_over(ribbon, RisoPrint.PINK, 0.2)
		_paper(RisoShapes.almond(charm + Vector2(-1, 5), 0.6, 1.9), 0.1)


## A broad poncho, feathered beret, cloth spell bindle and real carried lantern.
func _fool() -> void:
	_solid(_cloak(true))
	_folds(Vector2(0, -16), 10.0)
	var pole: PackedVector2Array = _bar(Vector2(6, -20), Vector2(-18, -28), 0.8)
	_solid(pole)
	_over(pole, RisoPrint.EYE, 0.5)
	var spell: StringName = Abilities.spell(wizard.player)
	var at: Vector2 = Vector2(-13.5, -20.0)
	var bag: PackedVector2Array = bindle_shape(spell, at)
	_spell_area(bag, at, 4.9)
	_solid(RisoShapes.almond(at + Vector2(-1, -6), 2.0, 1.2, 10), RisoPrint.ROBE)
	_solid(RisoShapes.tri(at + Vector2(-1, -6), at + Vector2(-5, -7), at + Vector2(-4, -4)), RisoPrint.ROBE)
	_solid(RisoShapes.tri(at + Vector2(0, -6), at + Vector2(3, -8), at + Vector2(3, -5)), RisoPrint.ROBE)
	var form: Vector3 = BINDLE_FORMS.get(spell, BINDLE_FORMS[&""])
	_over(RisoShapes.almond(at + Vector2(-form.x * 0.5 + form.z, 0), 0.8, form.y * 0.65), RisoPrint.NIGHT, 0.2)
	_over(RisoShapes.almond(at + Vector2(form.x * 0.55 + form.z, 0.3), 0.6, form.y * 0.6), RisoPrint.NIGHT, 0.2)
	var head: Vector2 = Vector2(0.5, -23.5 + wizard.head_y)
	_paper(RisoShapes.smooth(PackedVector2Array([
		head + Vector2(-5, -3), head + Vector2(5, -3), head + Vector2(6, 2),
		head + Vector2(3, 4), head + Vector2(0, 2), head + Vector2(-5, 4),
	])), 0.2)
	_solid(RisoShapes.ellipse(head, 3.8, 3.6), RisoPrint.NIGHT)
	_eyes(head + Vector2(1.0, 0))
	_solid(RisoShapes.ellipse(head + Vector2(-0.8, -3.6), 6.8, 2.4, 24, -0.16 + wizard.hat_a))
	var feather: Vector2 = head + Vector2(-3.4 + wizard.tip_a * 2.0, -7.5)
	var plume: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([
		feather + Vector2(2, 4), feather + Vector2(-1, -1), feather + Vector2(-5, -4),
		feather + Vector2(-10, -3), feather + Vector2(-7, -7), feather + Vector2(-2, -6),
		feather + Vector2(2, -2),
	]))
	_solid(plume, RisoPrint.PINK if not wizard.player.dash.acted else RisoPrint.CLOTH)
	if not wizard.player.dash.acted:
		_over(plume, RisoPrint.PINK, 0.15)
		_paper(RisoShapes.tri(feather + Vector2(-7, -4), feather + Vector2(-3, -4.8), feather + Vector2(1, 1)), 0.1)
	_hand(Vector2(5, -19.5))
	_hand(Vector2(10, -10))
	_health(Vector2(-BEAD_GAP, -17.8 + wizard.bob))
	_lantern(LANTERN_AT[&"fool"], true)


## Two warm eye slits in an otherwise anonymous face.
func _eyes(at: Vector2) -> void:
	var blink: bool = fposmod(wizard.t, 3.9) < 0.11
	for dx: float in [-1.4, 1.4]:
		_paper(RisoShapes.ellipse(at + Vector2(dx, 0), 0.6, 0.25 if blink else 1.0, 10), 0.85)


## A small glove without a sleeve or arm; the Fool's poncho supports its nearby hands.
func _hand(at: Vector2) -> void:
	_solid(RisoShapes.rrect(at.x - 1.7, at.y - 1.5, 3.4, 3.3, 1.2))
	_over(RisoShapes.rrect(at.x - 1.2, at.y - 0.1, 2.2, 0.5, 0.2), RisoPrint.NIGHT, 0.25)


## A few broad folds rather than ornament on the cloth.
func _folds(top: Vector2, reach: float) -> void:
	for side: float in [-1.0, 1.0]:
		_over(RisoShapes.tri(top + Vector2(side * 1.2, 0), Vector2(side * reach, -4), Vector2(side * 3.8, -6)), RisoPrint.NIGHT, 0.25)


## All heart positions remain present, glowing when filled and dark when lost.
func _health(at: Vector2, chain: bool = false) -> void:
	for i: int in range(wizard.player.health.max_health):
		var offset: Vector2 = Vector2(float(i % BEADS_PER_ROW) * BEAD_GAP, float(i / BEADS_PER_ROW) * BEAD_GAP)
		if chain:
			offset = Vector2(0, float(i) * (BEAD_GAP + 0.5))
			_solid(_bar(at + offset + Vector2(0, -2.0), at + offset, 0.3), RisoPrint.EYE, 0.5, false)
		var bead: Vector2 = at + offset
		if i < wizard.player.health.health:
			if chain:
				_over(RisoShapes.circle(bead, BEAD_RADIUS * 1.8), RisoPrint.EYE, 0.15)
			_paper(RisoShapes.circle(bead, BEAD_RADIUS, 12), 0.12)
		else:
			_solid(RisoShapes.circle(bead, BEAD_RADIUS, 12), RisoPrint.NIGHT, 1.0, false)


## Spawn protection is a warm flame; without it the same lantern holds only a charred wick.
func _lantern(at: Vector2, carried: bool) -> void:
	var lit: bool = MapInfo.instance != null and not MapInfo.instance.run.vulnerable
	if carried:
		_solid(_bar(at + Vector2(-1.3, -4.0), at + Vector2(-1.3, -2.5), 0.65))
		_solid(_bar(at + Vector2(1.3, -4.0), at + Vector2(1.3, -2.5), 0.65))
		_solid(_bar(at + Vector2(-1.3, -4.0), at + Vector2(1.3, -4.0), 0.65))
	_solid(RisoShapes.rrect(at.x - 2.7, at.y - 3, 5.4, 6.0, 1.7), RisoPrint.NIGHT)
	if lit:
		_over(RisoShapes.circle(at, 4.7), RisoPrint.EYE, 0.12)
		var flame: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([
			at + Vector2(0, -3.2), at + Vector2(1.0, -1), at + Vector2(1.7, -1.5),
			at + Vector2(2.0, 1.5), at + Vector2(0, 2.4), at + Vector2(-1.9, 1.3), at + Vector2(-1.0, -1.2),
		]))
		_paper(flame, 0.1)
		_over(RisoShapes.almond(at + Vector2(0, 0.7), 0.8, 1.2), RisoPrint.EYE, 0.85)
	else:
		_solid(RisoShapes.rrect(at.x - 0.4, at.y + 0.7, 0.8, 1.4, 0.2), RisoPrint.CLOTH)
	if carried:
		_solid(_bar(at + Vector2(-2.8, -2.8), at + Vector2(2.8, -2.8), 1.0))
		_solid(_bar(at + Vector2(-2.8, 2.6), at + Vector2(2.8, 2.6), 1.0))


## A pink dash light stays independent of both spell and spawn protection.
func _dash_light(at: Vector2) -> void:
	var ready: bool = not wizard.player.dash.acted
	if ready:
		_over(RisoShapes.circle(at, 2.9 + wizard.flare_amount), RisoPrint.PINK, 0.2)
	_solid(RisoShapes.circle(at, 1.2, 12), RisoPrint.PINK if ready else RisoPrint.CLOTH, 1.0, false)
	if ready:
		_paper(RisoShapes.circle(at, 0.5, 10), 0.0)


## A large spell mark occupies its mask, fabric bundle or enclosed flask chamber.
func _spell_area(shape: PackedVector2Array, at: Vector2, radius: float) -> void:
	var spell: StringName = Abilities.spell(wizard.player)
	if spell == &"":
		_solid(shape)
		return
	var cover: float = wizard.body.coverage
	wizard.body.coverage = 1.0
	var charge: float = maxf(0.0, Abilities.readiness(wizard.player))
	var run: Vector2 = Abilities.running(wizard.player)
	var running: bool = run.x >= 0.0
	var ready: bool = charge >= 1.0 or running
	var plate: int = RisoPrint.ROBE
	if running and run.y < SPELL_WARN and fmod(wizard.t * lerpf(9.0, 3.0, run.y / SPELL_WARN), 1.0) < 0.6:
		plate = RisoPrint.PINK
	_solid(shape, plate, 1.0 if ready else 0.2)
	if not ready:
		_over(shape, RisoPrint.NIGHT, 0.5)
		for fill: PackedVector2Array in Geometry2D.intersect_polygons(shape, wizard._filled(at, radius, charge)):
			_solid(fill, plate, 0.65, false)
	var glyphs: Array[PackedVector2Array] = _glyph(spell, at, radius * 0.72)
	var printed: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in glyphs:
		printed.append(wizard._sm(frame * poly))
	wizard.body.lift_ink(RisoPrint.ALL_PLATES, 1.0 if ready else 0.25, printed)
	if running and run.x > 0.01:
		_over(wizard._arc(at, radius * 0.82, 0.3, run.x), RisoPrint.EYE, 0.9)
	var mend: Mend = wizard.player.get_node_or_null("Mend") as Mend
	if spell == &"mend" and mend != null:
		for i: int in range(mend.draughts()):
			_paper(RisoShapes.circle(at + Vector2((float(i) - 1.0) * 1.2, radius * 0.5), 0.35, 8))
	wizard.body.coverage = cover


## Fit the existing ability mark inside the visible spell area without losing its proportions.
func _glyph(spell: StringName, at: Vector2, radius: float) -> Array[PackedVector2Array]:
	var polys: Array[PackedVector2Array] = RisoGlyph.of(spell, Vector2.ZERO, wizard.t)
	var bounds: Rect2 = Rect2(polys[0][0], Vector2.ZERO)
	for poly: PackedVector2Array in polys:
		for p: Vector2 in poly:
			bounds = bounds.expand(p)
	var scale: float = radius * 2.0 / maxf(bounds.size.x, bounds.size.y)
	var out: Array[PackedVector2Array] = []
	var move: Transform2D = Transform2D(0, Vector2(scale, scale), 0, at - bounds.get_center() * scale)
	for poly: PackedVector2Array in polys:
		out.append(move * poly)
	return out


## Each mask keeps a bold shape as well as the carried spell's ink and mark.
static func mask_shape(spell: StringName, at: Vector2) -> PackedVector2Array:
	match spell:
		&"awareness": return RisoShapes.almond(at, 7.0, 5.3)
		&"astral":
			return RisoShapes.smooth(PackedVector2Array([
				at + Vector2(0, -8), at + Vector2(6, -2), at + Vector2(6, 6),
				at + Vector2(3, 4), at + Vector2(1, 7), at + Vector2(-1, 4), at + Vector2(-4, 6), at + Vector2(-6, -2),
			]))
		&"levitate": return RisoShapes.ellipse(at, 4.8, 7.4)
		&"parry": return RisoShapes.smooth(PackedVector2Array([at + Vector2(-6, -5), at + Vector2(6, -5), at + Vector2(5, 3), at + Vector2(0, 7), at + Vector2(-5, 3)]))
		&"mend": return RisoShapes.almond(at, 5.4, 7.2)
		&"rift": return RisoShapes.smooth(PackedVector2Array([
			at + Vector2(-6, -6), at + Vector2(-1, -4), at + Vector2(6, -6),
			at + Vector2(5, 5), at + Vector2(0, 7), at + Vector2(-5, 5),
		]))
		&"warp": return RisoShapes.smooth(PackedVector2Array([
			at + Vector2(-6, -3), at + Vector2(-3, -7), at + Vector2(5, -7),
			at + Vector2(7, -1), at + Vector2(3, 7), at + Vector2(-6, 4),
		]))
		_: return PackedVector2Array([at + Vector2(0, -8), at + Vector2(6.2, 0), at + Vector2(0, 7), at + Vector2(-6.2, 0)])


## The whole cloth bundle changes its weighted folds and shape with the spell.
static func bindle_shape(spell: StringName, at: Vector2) -> PackedVector2Array:
	var form: Vector3 = BINDLE_FORMS.get(spell, BINDLE_FORMS[&""])
	var width: float = form.x
	var height: float = form.y
	var weight: float = form.z
	return RisoShapes.smooth(PackedVector2Array([
		at + Vector2(-0.8, -5.5), at + Vector2(0.9, -5.5), at + Vector2(width + weight, -1.4),
		at + Vector2(width + weight, height * 0.55), at + Vector2(2 + weight, height), at + Vector2(-2 + weight, height),
		at + Vector2(-width + weight, height * 0.55), at + Vector2(-width + weight, -1.4),
	]))


## Matching silhouettes for dash echoes, astral return points, ghosts and portal trips.
static func silhouette(style: StringName, at: Transform2D, facing: float, spell: StringName = &"") -> Array[PackedVector2Array]:
	var local: Array[PackedVector2Array] = []
	match style:
		&"cosmonaut":
			local.append(RisoShapes.rrect(-5, -19, 11, 16, 3))
			local.append(RisoShapes.circle(Vector2(0.8, -24), HELMET_RADIUS))
			local.append(RisoShapes.ellipse(Vector2(-12, -19), 5.5, 7))
			local.append(PackedVector2Array([Vector2(-4, -20), Vector2(-17, -7), Vector2(-13, -4), Vector2(-5, -8)]))
			local.append(RisoShapes.rrect(-8.5, -34, 0.8, 12, 0.3))
		&"shaman":
			local.append(mask_shape(spell, Vector2(0, -25)))
			local.append(RisoShapes.rrect(10, -34, 2, 34, 0.7))
			local.append(PackedVector2Array([Vector2(-4, -19), Vector2(4, -19), Vector2(9, -4), Vector2(-11, -3)]))
		&"fool":
			local.append(RisoShapes.ellipse(Vector2(0, -24), 4.5, 4))
			local.append(RisoShapes.ellipse(Vector2(-0.3, -27), 6.8, 2.4))
			local.append(RisoShapes.smooth(PackedVector2Array([Vector2(-2, -30), Vector2(-5, -35), Vector2(-13, -34), Vector2(-10, -38), Vector2(-5, -37)])))
			local.append(bindle_shape(spell, Vector2(-13.5, -20)))
			local.append(PackedVector2Array([Vector2(-4, -19), Vector2(4, -19), Vector2(10, -5), Vector2(-11, -3)]))
			local.append(RisoShapes.rrect(7.3, -8.5, 5.4, 6.0, 1.5))
	var out: Array[PackedVector2Array] = []
	var turn: Transform2D = at * Transform2D(0, Vector2(facing, 1), 0, Vector2.ZERO)
	for poly: PackedVector2Array in local:
		out.append(turn * poly)
	return out
