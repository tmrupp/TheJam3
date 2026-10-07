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
	&"cosmonaut": Vector2(0, -8.5), &"shaman": Vector2(12, -30), &"fool": Vector2(11.4, -7.8),
}
## How far above its flame the Fool's glove holds the lantern's bail.
const LANTERN_REACH: float = 6.2
## The Fool's poncho is broadest at the shoulders and narrows to a short, pointed hem.
const FOOL_SHOULDER: float = 10.5
const FOOL_HEM: Array[float] = [-6.4, -3.4, 0.0, 3.4, 6.4]
const FOOL_HEM_Y: Array[float] = [-6.6, -5.8, -5.2, -5.8, -6.6]
## Dark legs show between the hem and the boots.
const LEG_SHADE: float = 0.25
## The bindle pole rests on the front shoulder, where a glove grips it, and carries the bag behind.
const FOOL_POLE: Array[Vector2] = [Vector2(8.2, -18.0), Vector2(-18.0, -29.2)]
const FOOL_GRIP: Vector2 = Vector2(6.6, -18.7)
const FOOL_BINDLE: Vector2 = Vector2(-13.5, -21.0)
## Ink laid over the Fool's gloves and neck so they read against the poncho they come out of.
const GLOVE_SHADE: float = 0.4
## The Fool's head sits on a short neck above a collar that droops over the poncho's shoulders.
const FOOL_HEAD: Vector2 = Vector2(0.4, -24.8)
const FOOL_COLLAR_TOP: float = -20.6
## The neck is a little darker than the poncho, the collar a lighter layer of the same blue.
const NECK_SHADE: float = 0.2
const COLLAR_COVER: float = 0.7
## The necklace beads are larger than the other travelers' and hang along the collar's droop,
## spaced so they stay countable at the game's camera. Hearts past three hang on a second, longer
## strand, centred under the first: a pendant at four, a pair at five, three at six.
const FOOL_BEAD_RADIUS: float = 1.4
const FOOL_BEAD_GAP: float = 4.2
const FOOL_BEAD_SAG: float = 0.7
const FOOL_STRAND_DROP: float = 3.4
## How strongly each traveler follows the wizard's body springs (bob, head lag, lean and the
## landing bow), as fractions of the wizard's own. The Fool's tall, stiff poncho squashes and
## skews at full strength, since the bow swings points more the higher they are.
const MOTION: Dictionary = {
	&"fool": Vector4(0.45, 0.9, 0.6, 0.25),
}
## How far the Fool's hem follows the cloth springs, sideways and up. The hem swings freely
## while the body's own springs stay damped, so the poncho moves as cloth instead of skewing.
const FOOL_HEM_SWAY: Vector2 = Vector2(0.85, 0.55)
## The largest swing of one hem point, and the share of it the poncho's widest corners take.
const FOOL_HEM_REACH: float = 5.0
const FOOL_CORNER_SWAY: float = 0.3
## Each traveler's walk: stride length (one full step of both feet), how high a foot lifts, and
## how wide the feet stand. The Fool takes longer, slower, higher steps than the wizard, and
## stands a little wider so its two boots stay apart.
const GAIT: Dictionary = {
	&"fool": Vector3(30.0, 3.6, 1.3),
}
## The lantern and the bindle bag hang as pendulums: stiffness, damping, and how far the body's
## acceleration swings them. Light damping lets them sway on after the Fool stops.
const LANTERN_SPRING: Vector3 = Vector3(55.0, 1.8, 0.02)
const BINDLE_SPRING: Vector3 = Vector3(38.0, 1.5, 0.017)
## The bindle pole bounces about the glove that grips it, the bag end dipping on a landing.
const POLE_SPRING: Vector2 = Vector2(150.0, 7.0)
## The head nods back as the body speeds up and forward as it stops.
const HEAD_SPRING: Vector3 = Vector3(160.0, 10.0, 0.0015)
## How hard each part is driven by the walk, and kicked by a landing (per unit of fall speed).
const LANTERN_WALK: float = 40.0
const BINDLE_WALK: float = 22.0
const LANTERN_LAND: float = 0.005
const BINDLE_LAND: float = 0.004
const POLE_LAND: float = 0.0035
## How far the lantern hand swings forward and back with each stride, and the pole's bounce.
const HAND_SWING: float = 1.1
const POLE_BOUNCE: float = 0.03
## The widest each swinging part may go, in radians (the head's in art units).
const LANTERN_LIMIT: float = 0.9
const BINDLE_LIMIT: float = 0.8
const POLE_LIMIT: float = 0.25
const HEAD_LIMIT: float = 1.4
## A spent dash leaves the feather a pale grey, with a white vane.
const SPENT_FEATHER: float = 0.3
## Without spawn protection the lantern still glows, dimly and pink: its glass ink, the halo
## around it and the ember inside, which pulses slowly at this rate.
const UNLIT_GLASS: float = 0.3
const UNLIT_HALO: float = 0.1
const UNLIT_PULSE: float = 2.2
## Standing still, the Fool breathes (rate, depth in art units), the lantern and bag sway a
## little, and every few seconds the feather flicks (interval, length in seconds, size).
const BREATH: Vector2 = Vector2(1.9, 0.35)
const IDLE_SWAY: Vector2 = Vector2(1.3, 4.0)
const FEATHER_FLICK: Vector3 = Vector3(4.7, 0.7, 0.4)
## At a wall the lantern glove plants against it, this far in from the wall's face, at these
## heights when pushing and when climbing; the lantern then leans away from the wall.
const WALL_GLOVE: float = 1.7
const WALL_PLANT: Vector2 = Vector2(-14.5, -19.0)
const WALL_LANTERN_LEAN: float = 0.25
## The wizard supplies the feet, lean, cloth sway, head lag and drawing canvas.
var wizard: RisoWizard
## The current frame turns to face the player's way and follows the body's lean.
var frame: Transform2D
## Shapes of the figure take its momentary pink hurt flash together.
var figure: Array[PackedVector2Array] = []
## The body's bob, head height and lean, softened by the traveler's `MOTION`.
var bob: float = 0.0
var head_y: float = 0.0
var lean: float = 0.0
## The Fool's swinging parts, as angles (and the head's nod as an offset) with their speeds.
var lantern_a: float = 0.0
var lantern_v: float = 0.0
var bindle_a: float = 0.0
var bindle_v: float = 0.0
var pole_a: float = 0.0
var pole_v: float = 0.0
var head_x: float = 0.0
var head_v: float = 0.0
## The last step's ground contact, fall speed and facing, for landings and turns.
var _was_ground: bool = true
var _fall: float = 0.0
var _facing: float = 1.0


## Keep the existing art node as the owner of all drawing and animation.
func _init(owner: RisoWizard) -> void:
	wizard = owner


## Draw the selected traveler; the original wizard is drawn by RisoWizard itself.
func draw() -> void:
	_follow()
	var facing: float = 1.0 if wizard.fs >= 0.0 else -1.0
	frame = Transform2D(lean, Vector2.ZERO) * Transform2D(0.0, Vector2(facing, 1), 0.0, Vector2.ZERO)
	figure.clear()
	wizard.body.coverage = AstralProjection.PROJECTION_COVER if wizard.player.phasing else 1.0
	wizard.body.begin()
	if wizard.character_style() != &"fool":
		_boots(facing)
	match wizard.character_style():
		&"cosmonaut": _cosmonaut()
		&"shaman": _shaman()
		&"fool": _fool()
	if not wizard.player.phasing and wizard.player.is_invulnerable() and int(wizard.t * 16.0) % 2 == 0:
		wizard.body.knock(RisoPrint.ALL_PLATES, figure)
		wizard.body.ink(RisoPrint.PINK, 1.0, figure, false)
	wizard.body.finish()


## Where smoke starts, including the same lean, facing, bow and swing as the carried lantern.
func lantern_position() -> Vector2:
	_follow()
	var at: Vector2 = LANTERN_AT.get(wizard.character_style(), Vector2.ZERO) + Vector2(0, bob - 2.0)
	if wizard.character_style() == &"fool":
		var hand: Vector2 = _lantern_hand()
		at = hand + Vector2(0, LANTERN_REACH - 2.0).rotated(lantern_a)
	var facing: float = 1.0 if wizard.fs >= 0.0 else -1.0
	return wizard._smv(Transform2D(lean, Vector2.ZERO) * Vector2(at.x * facing, at.y))


## The way the head faces. It turns as soon as the player turns, a few frames before the body
## swings round, so a turn reads as looking first and then following.
func head_facing() -> float:
	var sprite: Node2D = wizard.player.sprite if wizard.player != null else null
	if sprite != null and sprite.scale.x != 0.0:
		return signf(sprite.scale.x)
	return 1.0 if wizard.fs >= 0.0 else -1.0


## Whether, and how far, the Fool is pressed against a wall in front of it (0 to 1).
func _wall_ahead() -> float:
	var facing: float = 1.0 if wizard.fs >= 0.0 else -1.0
	return wizard.wall if wizard.wall_side == facing else 0.0


## How still the Fool is: 1 standing on the ground, 0 walking or in the air.
func _idle() -> float:
	return (1.0 - wizard.sp) if wizard.pg else 0.0


## Every few seconds of standing, the feather gives a quick flick and settles.
func _flick() -> float:
	var u: float = fposmod(wizard.t + 1.7, FEATHER_FLICK.x) / FEATHER_FLICK.y
	if u >= 1.0:
		return 0.0
	return sin(u * TAU * 1.5) * (1.0 - u) * FEATHER_FLICK.z * _idle()


## The Fool's current swing of bag and lantern, for silhouettes that should match the figure.
func swing() -> Vector2:
	return Vector2(bindle_a, lantern_a)


## This traveler's walk (see `GAIT`); the wizard's own otherwise.
func gait() -> Vector3:
	return GAIT.get(wizard.character_style(), Vector3(RisoWizard.STRIDE, RisoWizard.STEP_LIFT, 1.0))


## Swing the Fool's lantern, bindle, pole and head on their own springs, once per physics step.
## They are driven by the body's acceleration, the walk and landings, never by the level RNG.
func step(dt: float) -> void:
	if wizard.character_style() != &"fool" or dt <= 0.0:
		return
	var facing: float = 1.0 if wizard.fs >= 0.0 else -1.0
	if facing != _facing:
		# A turn mirrors the figure; the parts keep swinging the same way in the world.
		lantern_a = -lantern_a
		lantern_v = -lantern_v
		bindle_a = -bindle_a
		bindle_v = -bindle_v
		head_x = -head_x
		head_v = -head_v
		_facing = facing
	var push: float = clampf(wizard.ax, -3000.0, 3000.0) * facing
	var walk: float = sin(_phase() * TAU) * wizard.sp
	var kick: float = clampf(_fall, 0.0, 400.0) if wizard.pg and not _was_ground else 0.0
	_was_ground = wizard.pg
	_fall = wizard.pvy
	var idle: float = sin(wizard.t * IDLE_SWAY.x) * IDLE_SWAY.y * _idle()
	lantern_v += (-LANTERN_SPRING.x * lantern_a - LANTERN_SPRING.y * lantern_v + LANTERN_SPRING.z * push + LANTERN_WALK * walk + idle) * dt
	lantern_v -= kick * LANTERN_LAND
	# Against a wall ahead, the lantern leans back from it rather than swinging into it.
	var low: float = lerpf(-LANTERN_LIMIT, WALL_LANTERN_LEAN, _wall_ahead())
	lantern_a = clampf(lantern_a + lantern_v * dt, low, LANTERN_LIMIT)
	if lantern_a <= low:
		lantern_v = maxf(lantern_v, 0.0)
	bindle_v += (-BINDLE_SPRING.x * bindle_a - BINDLE_SPRING.y * bindle_v + BINDLE_SPRING.z * push - BINDLE_WALK * walk - idle * 0.6) * dt
	bindle_v -= kick * BINDLE_LAND
	bindle_a = clampf(bindle_a + bindle_v * dt, -BINDLE_LIMIT, BINDLE_LIMIT)
	pole_v += (-POLE_SPRING.x * pole_a - POLE_SPRING.y * pole_v) * dt
	pole_v -= kick * POLE_LAND
	pole_a = clampf(pole_a + pole_v * dt, -POLE_LIMIT, POLE_LIMIT)
	head_v += (-HEAD_SPRING.x * head_x - HEAD_SPRING.y * head_v - HEAD_SPRING.z * push) * dt
	head_x = clampf(head_x + head_v * dt, -HEAD_LIMIT, HEAD_LIMIT)


## Where the walk is in its stride, from 0 to 1.
func _phase() -> float:
	return fposmod(wizard.dist / gait().x, 1.0)


## The lantern hand at the poncho's widest corner, swinging forward and back with the stride.
func _lantern_hand() -> Vector2:
	var stride: float = sin(_phase() * TAU) * HAND_SWING * wizard.sp
	var hand: Vector2 = LANTERN_AT[&"fool"] + Vector2(stride, bob - LANTERN_REACH)
	# At a wall ahead, the glove plants on it: shoulder high when pushing, reaching up in turn
	# while climbing.
	var plant: Vector2 = Vector2(RisoWizard.WALL_X - WALL_GLOVE, WALL_PLANT.x + bob * 0.5)
	if not wizard.pg:
		plant.y = WALL_PLANT.y + sin(wizard.climb_y * 0.3 + 1.6) * 1.6
	return hand.lerp(plant, _wall_ahead())


## The current frame turned by `angle` about a point, for parts that swing from it.
func _turned(pivot: Vector2, angle: float) -> Transform2D:
	return frame * Transform2D(angle, pivot) * Transform2D(0.0, -pivot)


## Take the body's springs at this traveler's strength.
func _follow() -> void:
	var m: Vector4 = MOTION.get(wizard.character_style(), Vector4.ONE)
	bob = wizard.bob * m.x
	if wizard.character_style() == &"fool":
		bob += (sin(wizard.t * BREATH.x) - 1.0) * BREATH.y * _idle()
	head_y = bob + (wizard.head_y - bob) * m.y
	lean = wizard.lean * m.z


## How much of the wizard's landing bow this traveler takes.
func bow_scale() -> float:
	var m: Vector4 = MOTION.get(wizard.character_style(), Vector4.ONE)
	return m.w


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
		var at: Transform2D = Transform2D(lean, Vector2.ZERO) * Transform2D(0.0, Vector2(facing, 1), 0.0, foot)
		var shape: PackedVector2Array = wizard._sm(at * boot)
		wizard.body.knock(RisoPrint.ALL_PLATES, [shape])
		wizard.body.ink(RisoPrint.CLOTH, 1.0, [shape], false)
		figure.append(shape)
		_paper(RisoShapes.rrect(foot.x * facing - 1.6, foot.y - 3.5, 2.7, 0.9, 0.3), 0.25)


## Simple folded cloth whose back edge follows the existing hem's spring.
func _cloak() -> PackedVector2Array:
	var sway: float = wizard.hem_x[0] * 0.45
	var lift: float = wizard.hem_y[0] * 0.35
	return PackedVector2Array([
		Vector2(-4, -19 + wizard.bob), Vector2(4, -19 + wizard.bob),
		Vector2(7, -13), Vector2(8, -3), Vector2(5, -5),
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


## The poncho's sloped shoulders, firm widest corner and narrow hem, facing right; the hem sways.
func _poncho() -> PackedVector2Array:
	var b: float = bob
	var hem: Array[Vector2] = []
	for i: int in range(5):
		hem.append(_hem(i) + Vector2(FOOL_HEM[i], FOOL_HEM_Y[i]))
	var w: float = FOOL_SHOULDER
	var back: Vector2 = Vector2(-w + _hem(0).x * FOOL_CORNER_SWAY, -14.2 + b * 0.8)
	var front: Vector2 = Vector2(w + _hem(4).x * FOOL_CORNER_SWAY, -14.2 + b * 0.8)
	# Points sit on straight lines between corners, with a close pair at each widest corner,
	# so the smoothed sides run straight and taper instead of bulging like a pot.
	return RisoShapes.smooth(PackedVector2Array([
		Vector2(-3.5, -20.5 + b), Vector2(-6.8, -18.0 + b), Vector2(-w + 0.8, -15.4 + b * 0.8),
		back, back + Vector2(0.6, 1.4), (back + hem[0]) * 0.5, hem[0], hem[1], hem[2], hem[3], hem[4],
		(front + hem[4]) * 0.5, front + Vector2(-0.6, 1.4), front, Vector2(w - 0.8, -15.4 + b * 0.8), Vector2(6.8, -18.0 + b), Vector2(3.5, -20.5 + b),
	]))


## One hem point's spring, turned into the costume's facing-right frame (index 0 is the back).
func _hem(i: int) -> Vector2:
	var facing: float = 1.0 if wizard.fs >= 0.0 else -1.0
	var k: int = i if facing > 0.0 else 4 - i
	var y: float = wizard._soft(wizard.hem_y[k], 1.5) if wizard.hem_y[k] > 0.0 else wizard._soft(wizard.hem_y[k], 4.0)
	return Vector2(wizard._soft(wizard.hem_x[k] * FOOL_HEM_SWAY.x, FOOL_HEM_REACH) * facing, y * FOOL_HEM_SWAY.y)


## A broad poncho, feathered beret, cloth spell bindle and real carried lantern.
func _fool() -> void:
	var b: float = bob
	var facing: float = 1.0 if wizard.fs >= 0.0 else -1.0
	for foot: Vector2 in wizard._feet():
		var at: Vector2 = Vector2(foot.x * facing, foot.y)
		var leg: PackedVector2Array = _bar(at + Vector2(0.1, -4.2), Vector2(at.x * 0.6 + 0.2, -7.5 + b * 0.5), 2.4)
		_solid(leg)
		_over(leg, RisoPrint.NIGHT, LEG_SHADE)
		_fool_boot(at)
	# The pole bounces about the gripping glove, and the bag swings from the pole's knot.
	var body: Transform2D = frame
	var grip: Vector2 = FOOL_GRIP + Vector2(0, b)
	frame = _turned(grip, pole_a + sin(_phase() * TAU * 2.0) * POLE_BOUNCE * wizard.sp)
	var pole: PackedVector2Array = _bar(FOOL_POLE[0] + Vector2(0, b), FOOL_POLE[1] + Vector2(0, b), 0.8)
	_solid(pole)
	_over(pole, RisoPrint.EYE, 0.5)
	var spell: StringName = Abilities.spell(wizard.player)
	var at: Vector2 = FOOL_BINDLE + Vector2(0, b)
	var knot: Vector2 = at + Vector2(-0.5, -6.5)
	frame = frame * Transform2D(bindle_a, knot) * Transform2D(0.0, -knot)
	var bag: PackedVector2Array = bindle_shape(spell, at)
	_spell_area(bag, at, 4.9)
	_solid(RisoShapes.almond(at + Vector2(-1, -6), 2.0, 1.2, 10), RisoPrint.ROBE)
	_solid(RisoShapes.tri(at + Vector2(-1, -6), at + Vector2(-5, -7), at + Vector2(-4, -4)), RisoPrint.ROBE)
	_solid(RisoShapes.tri(at + Vector2(0, -6), at + Vector2(3, -8), at + Vector2(3, -5)), RisoPrint.ROBE)
	var form: Vector3 = BINDLE_FORMS.get(spell, BINDLE_FORMS[&""])
	_over(RisoShapes.almond(at + Vector2(-form.x * 0.5 + form.z, 0), 0.8, form.y * 0.65), RisoPrint.NIGHT, 0.2)
	_over(RisoShapes.almond(at + Vector2(form.x * 0.55 + form.z, 0.3), 0.6, form.y * 0.6), RisoPrint.NIGHT, 0.2)
	frame = body
	_solid(_poncho())
	# Two long folds fall from each shoulder toward the narrow hem.
	for side: float in [-1.0, 1.0]:
		var hem: Vector2 = _hem(2 + int(side)) + Vector2(side * 3.4, -3.4)
		_over(RisoShapes.tri(Vector2(side * 4.6, -17.6 + b), Vector2(side * 7.6, -15.4 + b), hem), RisoPrint.NIGHT, 0.22)
	var head: Vector2 = FOOL_HEAD + Vector2(head_x, head_y)
	var neck: PackedVector2Array = _bar(Vector2(0.2, FOOL_COLLAR_TOP + 1.5 + b), head + Vector2(0, 1.0), 2.8)
	_solid(neck)
	_over(neck, RisoPrint.NIGHT, NECK_SHADE)
	# While it leads a turn, the head is drawn facing the new way, mirrored about its own centre.
	var looks: Transform2D = Transform2D(0.0, Vector2(head_facing() * facing, 1.0), 0.0, head) * Transform2D(0.0, -head)
	frame = body * looks
	_paper(hair_shape(head), 0.2)
	_solid(RisoShapes.ellipse(head, 3.8, 3.6), RisoPrint.NIGHT)
	_eyes(head + Vector2(1.0, -0.2))
	frame = body
	var collar: PackedVector2Array = collar_shape(Vector2(0, b))
	_solid(collar, RisoPrint.CLOTH, COLLAR_COVER)
	frame = body * looks
	_solid(RisoShapes.ellipse(head + Vector2(0, -3.9), 6.4, 2.5, 24, wizard.hat_a * 0.6))
	var quill: Vector2 = head + Vector2(-1.6, -5.4)
	var sway: float = wizard.tip_a * facing + _flick()
	var plume: PackedVector2Array = plume_shape(quill, sway)
	var ready: bool = not wizard.player.dash.acted
	if ready:
		_solid(plume, RisoPrint.PINK)
		_over(plume, RisoPrint.PINK, 0.15)
	else:
		_solid(plume, RisoPrint.NIGHT, SPENT_FEATHER)
	_paper(plume_shape(quill, sway, 0.35, 0.3), 0.1 if ready else 0.0)
	frame = body
	var beads: Array[Vector2] = necklace(wizard.player.health.max_health)
	for i: int in range(beads.size()):
		var bead: Vector2 = beads[i] + Vector2(0.2, FOOL_COLLAR_TOP + 2.6 + b)
		if i < wizard.player.health.health:
			_paper(RisoShapes.circle(bead, FOOL_BEAD_RADIUS, 14), 0.12)
		else:
			_solid(RisoShapes.circle(bead, FOOL_BEAD_RADIUS, 14), RisoPrint.NIGHT, 1.0, false)
	# Both gloves come out of the poncho: one grips the pole on the shoulder, and one, at the poncho's
	# widest corner, holds the lantern's bail.
	_hand(grip, GLOVE_SHADE)
	# A short sleeve keeps the swinging lantern hand joined to the poncho's corner.
	var hand: Vector2 = _lantern_hand()
	_solid(_bar(Vector2(FOOL_SHOULDER - 1.6, -14.2 + b * 0.8), hand, 2.6))
	frame = _turned(hand, lantern_a)
	_lantern(hand + Vector2(0, LANTERN_REACH), true)
	frame = body
	_hand(hand, GLOVE_SHADE)


## A short boot with a rounded toe and a pale turned-down cuff, its sole on the foot's point.
func _fool_boot(at: Vector2) -> void:
	_solid(RisoShapes.rrect(at.x - 1.3, at.y - 4.4, 2.8, 3.8, 0.8))
	_solid(RisoShapes.smooth(PackedVector2Array([
		at + Vector2(-1.4, -1.6), at + Vector2(-1.5, 0), at + Vector2(2.6, 0),
		at + Vector2(3.4, -0.6), at + Vector2(2.8, -1.8), at + Vector2(1.2, -2.1),
	])))
	_paper(RisoShapes.rrect(at.x - 1.7, at.y - 5.0, 3.6, 1.4, 0.6), 0.25)


## Two warm eye slits in an otherwise anonymous face.
func _eyes(at: Vector2) -> void:
	var blink: bool = fposmod(wizard.t, 3.9) < 0.11
	for dx: float in [-1.4, 1.4]:
		_paper(RisoShapes.ellipse(at + Vector2(dx, 0), 0.6, 0.25 if blink else 1.0, 10), 0.85)


## A small glove without a sleeve or arm; the Fool's gloves are shaded darker than the poncho they leave.
func _hand(at: Vector2, shade: float = 0.0) -> void:
	var glove: PackedVector2Array = RisoShapes.rrect(at.x - 1.7, at.y - 1.5, 3.4, 3.3, 1.2)
	_solid(glove)
	if shade > 0.0:
		_over(glove, RisoPrint.NIGHT, shade)
	_over(RisoShapes.rrect(at.x - 1.2, at.y - 0.1, 2.2, 0.5, 0.2), RisoPrint.NIGHT, 0.25)


## A few broad folds rather than ornament on the cloth.
func _folds(top: Vector2, reach: float) -> void:
	for side: float in [-1.0, 1.0]:
		_over(RisoShapes.tri(top + Vector2(side * 1.2, 0), Vector2(side * reach, -4), Vector2(side * 3.8, -6)), RisoPrint.NIGHT, 0.25)


## All heart positions remain present, glowing when filled and dark when lost.
## A sag lowers the middle of each row, so beads hang along a drooping collar.
func _health(at: Vector2, chain: bool = false, radius: float = BEAD_RADIUS, gap: float = BEAD_GAP, sag: float = 0.0) -> void:
	for i: int in range(wizard.player.health.max_health):
		var col: float = float(i % BEADS_PER_ROW)
		var bend: float = 1.0 - pow(col - float(BEADS_PER_ROW - 1) * 0.5, 2.0)
		var offset: Vector2 = Vector2(col * gap, float(i / BEADS_PER_ROW) * gap + sag * bend)
		if chain:
			offset = Vector2(0, float(i) * (BEAD_GAP + 0.5))
			_solid(_bar(at + offset + Vector2(0, -2.0), at + offset, 0.3), RisoPrint.EYE, 0.5, false)
		var bead: Vector2 = at + offset
		if i < wizard.player.health.health:
			if chain:
				_over(RisoShapes.circle(bead, radius * 1.8), RisoPrint.EYE, 0.15)
			_paper(RisoShapes.circle(bead, radius, 14), 0.12)
		else:
			_solid(RisoShapes.circle(bead, radius, 14), RisoPrint.NIGHT, 1.0, false)


## Spawn protection is a warm flame; without it the same lantern holds only a charred wick.
func _lantern(at: Vector2, carried: bool) -> void:
	var lit: bool = MapInfo.instance != null and not MapInfo.instance.run.vulnerable
	if carried:
		_carried_lantern(at, lit)
		return
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


## A hand lantern on a short bail: cap, dark glass and base, with one plain teardrop of flame.
func _carried_lantern(at: Vector2, lit: bool) -> void:
	_solid(_bar(at + Vector2(0, -3.6), at + Vector2(0, -LANTERN_REACH + 0.6), 0.8))
	var glass: PackedVector2Array = RisoShapes.rrect(at.x - 2.5, at.y - 2.8, 5.0, 5.4, 1.4)
	if lit:
		_over(RisoShapes.circle(at, 5.2), RisoPrint.EYE, 0.12)
		_paper(glass, 0.3)
		_solid(RisoShapes.smooth(PackedVector2Array([
			at + Vector2(0, -2.0), at + Vector2(1.2, 0.3), at + Vector2(0, 1.8), at + Vector2(-1.2, 0.3),
		])), RisoPrint.EYE, 0.9, false)
	else:
		# Unprotected: a dim pink glow, slowly pulsing, around a small ember.
		var pulse: float = 0.5 + 0.5 * sin(wizard.t * UNLIT_PULSE)
		_over(RisoShapes.circle(at, 5.0), RisoPrint.PINK, UNLIT_HALO * (0.7 + 0.3 * pulse))
		_solid(glass, RisoPrint.PINK, UNLIT_GLASS * (0.8 + 0.2 * pulse), false)
		_solid(RisoShapes.almond(at + Vector2(0, 0.8), 0.7, 1.0, 8), RisoPrint.PINK, 0.85, false)
	_solid(RisoShapes.rrect(at.x - 2.1, at.y - 4.0, 4.2, 1.6, 0.7))
	_solid(RisoShapes.rrect(at.x - 2.9, at.y + 2.2, 5.8, 1.4, 0.6))


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
	if spell == &"awareness":
		# The open eye looks out through a dark, upright pupil.
		_solid(RisoShapes.ellipse(at, radius * 0.13, radius * 0.3, 14), RisoPrint.NIGHT, 1.0 if ready else 0.4, false)
	if running and run.x > 0.01:
		_over(wizard._arc(at, radius * 0.82, 0.3, run.x), RisoPrint.EYE, 0.9)
	var mend: Mend = wizard.player.get_node_or_null("Mend") as Mend
	if spell == &"mend" and mend != null:
		for i: int in range(mend.draughts()):
			_paper(RisoShapes.circle(at + Vector2((float(i) - 1.0) * 1.2, radius * 0.5), 0.35, 8))
	wizard.body.coverage = cover


## Fit the existing ability mark inside the visible spell area without losing its proportions.
## The travelers carry astral as a crescent moon, as on the concept sheets, rather than the ghost.
func _glyph(spell: StringName, at: Vector2, radius: float) -> Array[PackedVector2Array]:
	var polys: Array[PackedVector2Array] = RisoGlyph.of(spell, Vector2.ZERO, wizard.t)
	if spell == &"astral":
		polys = [RisoShapes.crescent(Vector2.ZERO, 20.0, Vector2(9.0, -6.0), 48)]
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


## Where each of `count` hearts hangs on the Fool's necklace, relative to the middle of the first
## strand: three along the collar, the rest centred on a longer strand below.
static func necklace(count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i: int in range(count):
		var strand: int = 0 if i < BEADS_PER_ROW else 1
		var n: int = mini(count, BEADS_PER_ROW) if strand == 0 else count - BEADS_PER_ROW
		var k: int = i - strand * BEADS_PER_ROW
		var x: float = (float(k) - float(n - 1) * 0.5) * FOOL_BEAD_GAP
		var bend: float = 1.0 - pow(x / FOOL_BEAD_GAP, 2.0)
		out.append(Vector2(x, float(strand) * FOOL_STRAND_DROP + FOOL_BEAD_SAG * float(1 + strand) * bend))
	return out


## Pale hair under the beret, in rounded tufts flicking out at both sides.
static func hair_shape(head: Vector2) -> PackedVector2Array:
	var tufts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in [
		Vector2(4.8, -3.4), Vector2(5.4, -1.0), Vector2(6.8, 0.9), Vector2(5.1, 1.0), Vector2(5.3, 3.1), Vector2(3.6, 2.1),
		Vector2(0, 2.4),
		Vector2(-3.6, 2.1), Vector2(-5.3, 3.1), Vector2(-5.1, 1.0), Vector2(-6.8, 0.9), Vector2(-5.4, -1.0), Vector2(-4.8, -3.4),
	]:
		tufts.append(head + p)
	return RisoShapes.smooth(tufts, 3)


## The Fool's collar: a straight neckline whose lower edge droops in a soft curve over the
## poncho's shoulders, deepest at the front of the chest.
static func collar_shape(at: Vector2) -> PackedVector2Array:
	var top: float = FOOL_COLLAR_TOP
	return RisoShapes.smooth(PackedVector2Array([
		at + Vector2(-4.0, top), at + Vector2(0.2, top + 0.6), at + Vector2(4.4, top),
		at + Vector2(7.4, top + 2.4), at + Vector2(5.0, top + 4.6), at + Vector2(0.2, top + 6.4),
		at + Vector2(-4.6, top + 4.6), at + Vector2(-7.0, top + 2.4),
	]))


## A long plume rising from the beret and curving back, widest past its middle and pointed at the
## tip; `sway` swings the tip. A smaller `scale` and a `shift` toward the tip give the pale vane.
static func plume_shape(base: Vector2, sway: float, scale: float = 1.0, shift: float = 0.0) -> PackedVector2Array:
	var tip: Vector2 = base + Vector2(-8.5 + sway * 1.6, -6.0 + absf(sway) * 0.6)
	var bend: Vector2 = base + Vector2(0.5 + sway * 0.6, -7.5)
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	for i: int in range(9):
		var u: float = lerpf(shift, 1.0 - shift * 0.4, float(i) / 8.0)
		var at: Vector2 = base.lerp(bend, u).lerp(bend.lerp(tip, u), u)
		var along: Vector2 = (bend - base).lerp(tip - bend, u).normalized()
		var width: float = 2.0 * scale * pow(sin(PI * minf(u * 1.15, 1.0)), 0.7) + 0.3 * scale
		left.append(at + along.orthogonal() * width)
		right.append(at - along.orthogonal() * width)
	right.reverse()
	left.append_array(right)
	return RisoShapes.smooth(left, 2)


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
## A live `pose` (the traveler's own costume) swings the Fool's bag and lantern to match the
## figure; without one, they hang at rest.
static func silhouette(style: StringName, at: Transform2D, facing: float, spell: StringName = &"", pose: RisoCostume = null) -> Array[PackedVector2Array]:
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
			local.append(RisoShapes.ellipse(FOOL_HEAD, 4.5, 4))
			local.append(RisoShapes.ellipse(FOOL_HEAD + Vector2(0, -3.9), 6.4, 2.5))
			local.append(plume_shape(FOOL_HEAD + Vector2(-1.6, -5.4), -0.35))
			local.append(collar_shape(Vector2.ZERO))
			var held: Vector2 = pose.swing() if pose != null else Vector2.ZERO
			var knot: Vector2 = FOOL_BINDLE + Vector2(-0.5, -6.5)
			local.append(Transform2D(held.x, knot) * Transform2D(0.0, -knot) * bindle_shape(spell, FOOL_BINDLE))
			local.append(PackedVector2Array([
				Vector2(-3.5, -20.5), Vector2(-FOOL_SHOULDER, -15), Vector2(FOOL_HEM[0], FOOL_HEM_Y[0]), Vector2(0, FOOL_HEM_Y[2]),
				Vector2(FOOL_HEM[4], FOOL_HEM_Y[4]), Vector2(FOOL_SHOULDER, -15), Vector2(3.5, -20.5),
			]))
			var hand: Vector2 = LANTERN_AT[&"fool"] + Vector2(0, -LANTERN_REACH)
			var lantern: PackedVector2Array = RisoShapes.rrect(hand.x - 2.9, hand.y, 5.8, LANTERN_REACH + 3.6, 1.5)
			local.append(Transform2D(held.y, hand) * Transform2D(0.0, -hand) * lantern)
			for side: float in [-1.0, 1.0]:
				var foot: Vector2 = Vector2(side * 1.9 * (GAIT[&"fool"] as Vector3).z, 0)
				local.append(RisoShapes.rrect(foot.x - 1.5, -5.0, 4.9, 5.0, 1.0))
	var out: Array[PackedVector2Array] = []
	var turn: Transform2D = at * Transform2D(0, Vector2(facing, 1), 0, Vector2.ZERO)
	for poly: PackedVector2Array in local:
		out.append(turn * poly)
	return out
