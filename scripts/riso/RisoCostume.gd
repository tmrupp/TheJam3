class_name RisoCostume
extends RefCounted
## The Fool, the traveler the player is printed as, on the wizard's own canvas (RisoWizard) and
## driven by its cloth springs. Their spell, health, dash and lantern marks come from the player
## and run, not the costume.

## Health beads stay countable, with extra hearts on a second, lower strand.
const BEADS_PER_ROW: int = 3
## A spell's last seconds blink pink.
const SPELL_WARN: float = 1.5
## The spell changes the entire cloth bundle's width, hanging length and weighted side.
const BINDLE_FORMS: Dictionary = {
	&"": Vector3(4.9, 5.0, 0.0), &"hex": Vector3(4.9, 5.2, -0.5),
	&"astral": Vector3(4.0, 6.2, 0.4),
	&"levitate": Vector3(3.6, 6.8, -0.8), &"awareness": Vector3(5.5, 4.8, 0.6),
	&"rift": Vector3(5.1, 5.4, -1.0), &"warp": Vector3(4.6, 5.8, 1.0),
	&"mend": Vector3(4.4, 6.0, 0.0), &"ferry": Vector3(5.9, 4.4, 0.3),
	&"slash": Vector3(4.2, 5.6, 0.9), &"nova": Vector3(5.3, 5.3, 0.0),
	&"push": Vector3(6.2, 4.0, -0.6), &"seeker": Vector3(4.6, 5.9, 0.5),
	&"lunge": Vector3(3.8, 6.4, -0.4),
}
## Where the Fool carries their lantern flame, in art units facing right.
const LANTERN_AT: Vector2 = Vector2(11.4, -7.8)
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
## How strongly the Fool follows the rig's body springs (bob, head lag, lean and the landing bow),
## as fractions of them. The tall, stiff poncho squashes and skews at full strength, since the bow
## swings points more the higher they are.
const MOTION: Vector4 = Vector4(0.45, 0.9, 0.6, 0.25)
## How far the Fool's hem follows the cloth springs, sideways and up. The hem swings freely
## while the body's own springs stay damped, so the poncho moves as cloth instead of skewing.
const FOOL_HEM_SWAY: Vector2 = Vector2(0.85, 0.55)
## The largest swing of one hem point, and the share of it the poncho's widest corners take.
const FOOL_HEM_REACH: float = 5.0
const FOOL_CORNER_SWAY: float = 0.3
## The Fool's walk: stride length (one full step of both feet), how high a foot lifts, and how wide
## the feet stand: long, slow, high steps, standing a little wide so its two boots stay apart.
const GAIT: Vector3 = Vector3(30.0, 3.6, 1.3)
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
## Snuffed at a font (MapInfo.flame_snuffed), the lantern is out but still protects: dark glass,
## night ink at this cover, with a pale crescent moon caught in it (the shade gates' mark, which a
## snuffed flame opens) and a charred wick under it. Not pink, which is kept for danger.
const SNUFFED_GLASS: float = 0.85
const SNUFFED_MOON: float = 1.9
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
## Sitting (Player.is_sitting): the body sinks this far and the poncho spreads on the ground, the
## boots stick out in front, the lantern is set down beside them, and the free hand flips a coin.
const SIT_DROP: float = 5.0
const SIT_SPREAD: float = 1.25
const SIT_FEET: Array[Vector2] = [Vector2(2.4, 0.0), Vector2(6.0, 0.0)]
const SIT_LANTERN: Vector2 = Vector2(13.2, -3.6)
const COIN_HAND: Vector2 = Vector2(8.4, -10.5)
## How fast the Fool settles down and gets up again (share of the way per second).
const SIT_SPEED: Vector2 = Vector2(4.0, 7.0)
## The coin: radius, how high it is tossed, seconds per toss, share of a toss in the air, spin.
const COIN: Vector3 = Vector3(1.3, 9.0, 1.1)
const COIN_AIR: float = 0.72
const COIN_SPIN: float = 15.0
## The wizard supplies the feet, lean, cloth sway, head lag and drawing canvas.
var wizard: RisoWizard
## The current frame turns to face the player's way and follows the body's lean.
var frame: Transform2D
## Shapes of the figure take its momentary pink hurt flash together: each as [its bone, its shape].
var figure: Array[Array] = []
## The figure is printed through a rig (InkCanvas.rig): each part is drawn once, in its own space,
## and placed every frame by a bone (_place), the bow and the lean against a wall done by the rig's
## warp; only what changes shape (the poncho on its hem springs, the plume, the folds, a blink, the
## spell's fill) is drawn anew. The bone the shapes printed now are carried by.
var _bone: int = 0
## A bar of unit length and width along x from the origin, stretched over its bone (_place_bar).
const UNIT_BAR: PackedVector2Array = [Vector2(0, -0.5), Vector2(1, -0.5), Vector2(1, 0.5), Vector2(0, 0.5)]
## The parts that never change shape, each built once in its own space (_rest) and handed to the
## canvas as the very same array every print, so it keeps them without looking (keeps_shapes).
static var _rests: Dictionary = {}
## The names of the parts that differ by spell, by spell: [bag, crease0, crease1, glyph], and of the
## beads by count, by (most, held): [whole, spent]; worked out once, not every frame.
static var _spell_keys: Dictionary = {}
static var _bead_keys: Dictionary = {}


## The names of the spell's parts (see _spell_keys).
static func _keys_for(spell: StringName) -> Array[StringName]:
	if not _spell_keys.has(spell):
		var out: Array[StringName] = []
		for part: String in ["bag", "crease0", "crease1", "glyph"]:
			out.append(StringName(part + " " + str(spell)))
		_spell_keys[spell] = out
	return _spell_keys[spell]
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
## How far the Fool has sat down (0 standing, 1 seated), and how long the coin has been flipping.
var sit: float = 0.0
var coin_t: float = 0.0
## The last step's ground contact, fall speed and facing, for landings and turns.
var _was_ground: bool = true
var _fall: float = 0.0
var _facing: float = 1.0


## Keep the existing art node as the owner of all drawing and animation.
func _init(owner: RisoWizard) -> void:
	wizard = owner


## Draw the Fool. Their bag carries the damage slot's spell, and a pouch under it the utility
## slot's.
func draw() -> void:
	_follow()
	var facing: float = 1.0 if wizard.fs >= 0.0 else -1.0
	frame = Transform2D(lean, Vector2.ZERO) * Transform2D(0.0, Vector2(facing, 1), 0.0, Vector2.ZERO)
	figure.clear()
	var canvas: InkCanvas = wizard.body
	canvas.coverage = AstralProjection.PROJECTION_COVER if wizard.player.phasing else 1.0
	canvas.begin()
	# The bow above the waist and the lean against a wall (RisoWizard._smv), for the rig to do.
	var amount: float = wizard.bow * bow_scale()
	canvas.set_warp(Vector2(0.0, RisoWizard.WAIST), amount * facing if absf(amount) >= 0.0005 else 0.0, 18.0,
		wizard.wall, wizard.wall_side, RisoWizard.WALL_X - 3.5, 3.5)
	_fool()
	if not wizard.player.phasing and wizard.player.is_invulnerable() and int(wizard.t * 16.0) % 2 == 0:
		# Every shape cleared, then every shape inked, each carried by its own bone.
		var by_bone: Dictionary = {}
		for entry: Array in figure:
			if not by_bone.has(entry[0]):
				var polys: Array[PackedVector2Array] = []
				by_bone[entry[0]] = polys
			(by_bone[entry[0]] as Array[PackedVector2Array]).append(entry[1])
		for b: int in by_bone:
			canvas.on_bone(b)
			canvas.knock(RisoPrint.ALL_PLATES, by_bone[b])
		for b: int in by_bone:
			canvas.on_bone(b)
			canvas.ink(RisoPrint.EYE if wizard.parry_glory() else RisoPrint.PINK, 1.0, by_bone[b], false)
	canvas.finish()


## Where smoke starts, including the same lean, facing, bow and swing as the carried lantern.
func lantern_position() -> Vector2:
	_follow()
	var at: Vector2 = _lantern_hang() + Vector2(0, LANTERN_REACH - 2.0).rotated(_lantern_tilt())
	var facing: float = 1.0 if wizard.fs >= 0.0 else -1.0
	return wizard._smv(Transform2D(lean, Vector2.ZERO) * Vector2(at.x * facing, at.y))


## How seated the Fool looks, from 0 standing to 1 sitting.
func seated() -> float:
	return smoothstep(0.0, 1.0, sit)


## Where the lantern's bail hangs from: the glove while it is carried, the ground beside the boots
## while the Fool sits.
func _lantern_hang() -> Vector2:
	return _lantern_hand().lerp(SIT_LANTERN - Vector2(0, LANTERN_REACH), seated())


## The lantern's swing, settling upright as it is set down.
func _lantern_tilt() -> float:
	return lantern_a * (1.0 - seated())


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


## The Fool's walk (see `GAIT`).
func gait() -> Vector3:
	return GAIT


## Swing the Fool's lantern, bindle, pole and head on their own springs, once per physics step.
## They are driven by the body's acceleration, the walk and landings, never by the level RNG.
func step(dt: float) -> void:
	if dt <= 0.0:
		return
	var sitting: bool = wizard.player.is_sitting()
	sit = move_toward(sit, 1.0 if sitting else 0.0, dt * (SIT_SPEED.x if sitting else SIT_SPEED.y))
	coin_t = coin_t + dt if sit >= 1.0 else 0.0
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
	var hand: Vector2 = LANTERN_AT + Vector2(stride, bob - LANTERN_REACH)
	# At a wall ahead, the glove plants on it: shoulder high when pushing, reaching up in turn
	# while climbing.
	var plant: Vector2 = Vector2(RisoWizard.WALL_X - WALL_GLOVE, WALL_PLANT.x + bob * 0.5)
	if not wizard.pg:
		plant.y = WALL_PLANT.y + sin(wizard.climb_y * 0.3 + 1.6) * 1.6
	return hand.lerp(plant, _wall_ahead())


## The current frame turned by `angle` about a point, for parts that swing from it.
func _turned(pivot: Vector2, angle: float) -> Transform2D:
	return frame * Transform2D(angle, pivot) * Transform2D(0.0, -pivot)


## Take the body's springs at the Fool's strength.
func _follow() -> void:
	var m: Vector4 = MOTION
	bob = wizard.bob * m.x
	# Sitting lowers the head with the body, in full: only the springs' own motion is softened.
	bob += (sin(wizard.t * BREATH.x) - 1.0) * BREATH.y * _idle()
	var settle: float = SIT_DROP * seated()
	head_y = bob + (wizard.head_y - bob) * m.y + settle
	bob += settle
	lean = wizard.lean * m.z


## How much of the rig's landing bow the Fool takes.
func bow_scale() -> float:
	return MOTION.w


## Part `key` in its rest pose, built the first time it is asked for (see _build_rest).
static func _rest(key: StringName) -> Array[PackedVector2Array]:
	var made: Variant = _rests.get(key)
	if made == null:
		made = _build_rest(key)
		_rests[key] = made
	return made


## The rest shapes of part `key`: a fixed part by name, or one that differs by spell or count,
## named with it ("bag hex", "beads 5 3 whole").
static func _build_rest(key: StringName) -> Array[PackedVector2Array]:
	var words: PackedStringArray = String(key).split(" ")
	match words[0]:
		"bar":
			return [UNIT_BAR]
		"boot":
			return [RisoShapes.rrect(-1.3, -4.4, 2.8, 3.8, 0.8), RisoShapes.smooth(PackedVector2Array([
				Vector2(-1.4, -1.6), Vector2(-1.5, 0), Vector2(2.6, 0),
				Vector2(3.4, -0.6), Vector2(2.8, -1.8), Vector2(1.2, -2.1),
			]))]
		"cuff":
			return [RisoShapes.rrect(-1.7, -5.0, 3.6, 1.4, 0.6)]
		"bag":
			return [bindle_shape(StringName(words[1]) if words.size() > 1 else &"", Vector2.ZERO)]
		"ties":
			return [RisoShapes.almond(Vector2(-1, -6), 2.0, 1.2, 10), RisoShapes.tri(Vector2(-1, -6), Vector2(-5, -7), Vector2(-4, -4)),
				RisoShapes.tri(Vector2(0, -6), Vector2(3, -8), Vector2(3, -5))]
		"crease0", "crease1":
			var form: Vector3 = BINDLE_FORMS.get(StringName(words[1]) if words.size() > 1 else &"", BINDLE_FORMS[&""])
			if words[0] == "crease0":
				return [RisoShapes.almond(Vector2(-form.x * 0.5 + form.z, 0), 0.8, form.y * 0.65)]
			return [RisoShapes.almond(Vector2(form.x * 0.55 + form.z, 0.3), 0.6, form.y * 0.6)]
		"hair":
			return [hair_shape(Vector2.ZERO)]
		"head":
			return [RisoShapes.ellipse(Vector2.ZERO, 3.8, 3.6)]
		"eyes":
			var shut: bool = words.size() > 1
			return [RisoShapes.ellipse(Vector2(-0.4, -0.2), 0.6, 0.25 if shut else 1.0, 10), RisoShapes.ellipse(Vector2(2.4, -0.2), 0.6, 0.25 if shut else 1.0, 10)]
		"collar":
			return [collar_shape(Vector2.ZERO)]
		"beret":
			return [RisoShapes.ellipse(Vector2.ZERO, 6.4, 2.5, 24)]
		"beads":
			var beads: Array[Vector2] = necklace(int(words[1]))
			var out: Array[PackedVector2Array] = []
			for i: int in range(beads.size()):
				if (i < int(words[2])) == (words[3] == "whole"):
					out.append(RisoShapes.circle(beads[i], FOOL_BEAD_RADIUS, 14))
			return out
		"glove":
			return [RisoShapes.rrect(-1.7, -1.5, 3.4, 3.3, 1.2)]
		"glove_line":
			return [RisoShapes.rrect(-1.2, -0.1, 2.2, 0.5, 0.2)]
		"bail":
			return [PackedVector2Array([Vector2(0.4, -3.6), Vector2(0.4, -LANTERN_REACH + 0.6), Vector2(-0.4, -LANTERN_REACH + 0.6), Vector2(-0.4, -3.6)])]
		"glow":
			return [RisoShapes.circle(Vector2.ZERO, 5.2)]
		"glass":
			return [RisoShapes.rrect(-2.5, -2.8, 5.0, 5.4, 1.4)]
		"flame":
			return [RisoShapes.smooth(PackedVector2Array([Vector2(0, -2.0), Vector2(1.2, 0.3), Vector2(0, 1.8), Vector2(-1.2, 0.3)]))]
		"halo":
			return [RisoShapes.circle(Vector2.ZERO, 5.0)]
		"ember":
			return [RisoShapes.almond(Vector2(0, 0.8), 0.7, 1.0, 8)]
		"moon":
			return [RisoShapes.crescent(Vector2(-0.3, -0.5), SNUFFED_MOON, Vector2(0.9, -0.5), 20)]
		"wick":
			return [RisoShapes.rrect(-0.3, 1.0, 0.6, 1.2, 0.2)]
		"lantern_ends":
			return [RisoShapes.rrect(-2.1, -4.0, 4.2, 1.6, 0.7), RisoShapes.rrect(-2.9, 2.2, 5.8, 1.4, 0.6)]
		"pupil":
			return [RisoShapes.ellipse(Vector2.ZERO, 4.9 * 0.13, 4.9 * 0.3, 14)]
	return []


## A bone for what is drawn next, placing it by `local` within the current frame (the body, a
## swinging part); the shapes drawn after are in that space.
func _place(local: Transform2D = Transform2D.IDENTITY) -> void:
	_bone = wizard.body.bone(frame * local)
	wizard.body.on_bone(_bone)


## A bone stretching UNIT_BAR into a strap, stick or connector `width` wide from `a` to `b`.
func _place_bar(a: Vector2, b: Vector2, width: float) -> void:
	_place(Transform2D(b - a, (b - a).normalized().orthogonal() * width, a))


## Put a filled shape on its own ink, clearing the other plates beneath it.
func _solid(poly: PackedVector2Array, plate: int = RisoPrint.CLOTH, cover: float = 1.0, flash: bool = true) -> void:
	wizard.body.knock(RisoPrint.ALL_PLATES, [poly])
	wizard.body.ink(plate, cover, [poly], false)
	if flash:
		figure.append([_bone, poly])


## Several filled shapes on one ink at once, each clearing the plates beneath it: for shapes that
## never overlap, or are solid (`cover` 1), which print the same together as one after another, in
## two ops rather than two each.
func _solids(polys: Array[PackedVector2Array], plate: int = RisoPrint.CLOTH, cover: float = 1.0, flash: bool = true) -> void:
	if polys.is_empty():
		return
	wizard.body.knock(RisoPrint.ALL_PLATES, polys)
	wizard.body.ink(plate, cover, polys, false)
	if flash:
		for poly: PackedVector2Array in polys:
			figure.append([_bone, poly])


## Add screened ink over a shape, for folds, glass and pools of light.
func _over(poly: PackedVector2Array, plate: int, cover: float) -> void:
	wizard.body.ink(plate, cover, [poly])


## Screened ink over several shapes at once (a part's rest shapes, _rest).
func _overs(polys: Array[PackedVector2Array], plate: int, cover: float) -> void:
	wizard.body.ink(plate, cover, polys)


## A pale paper shape with a small amount of yellow ink.
func _paper(poly: PackedVector2Array, tint: float = 0.15) -> void:
	_solid(poly, RisoPrint.EYE, tint, false)


## A filled strap, stick or chain connector between two points; never an outline.
func _bar(a: Vector2, b: Vector2, width: float) -> PackedVector2Array:
	var n: Vector2 = (b - a).normalized().orthogonal() * width * 0.5
	return PackedVector2Array([a - n, b - n, b + n, a + n])


## The poncho's sloped shoulders, firm widest corner and narrow hem, facing right; the hem sways.
func _poncho() -> PackedVector2Array:
	var b: float = bob
	var hem: Array[Vector2] = []
	var s: float = seated()
	for i: int in range(5):
		hem.append(_hem(i) + Vector2(FOOL_HEM[i] * lerpf(1.0, SIT_SPREAD, s), FOOL_HEM_Y[i] + SIT_DROP * s))
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
	var feet: Array[Vector2] = wizard._feet()
	for k: int in range(feet.size()):
		var at: Vector2 = Vector2(feet[k].x * facing, feet[k].y).lerp(SIT_FEET[k], seated())
		_place_bar(at + Vector2(0.1, -4.2), Vector2(at.x * 0.6 + 0.2, -7.5 + b * 0.5), 2.4)
		_solids(_rest(&"bar"))
		_overs(_rest(&"bar"), RisoPrint.NIGHT, LEG_SHADE)
		_fool_boot(at)
	# The pole bounces about the gripping glove, and the bag swings from the pole's knot.
	var body: Transform2D = frame
	var grip: Vector2 = FOOL_GRIP + Vector2(0, b)
	frame = _turned(grip, pole_a + sin(_phase() * TAU * 2.0) * POLE_BOUNCE * wizard.sp)
	_place_bar(FOOL_POLE[0] + Vector2(0, b), FOOL_POLE[1] + Vector2(0, b), 0.8)
	_solids(_rest(&"bar"))
	_overs(_rest(&"bar"), RisoPrint.EYE, 0.5)
	var spell: StringName = Abilities.spell(wizard.player)
	var at: Vector2 = FOOL_BINDLE + Vector2(0, b)
	var knot: Vector2 = at + Vector2(-0.5, -6.5)
	frame = frame * Transform2D(bindle_a, knot) * Transform2D(0.0, -knot)
	_place(Transform2D(0.0, at))
	var keys: Array[StringName] = _keys_for(spell)
	_spell_area(_rest(keys[0]), Vector2.ZERO, 4.9)
	_solids(_rest(&"ties"), RisoPrint.ROBE)
	_overs(_rest(keys[1]), RisoPrint.NIGHT, 0.2)
	_overs(_rest(keys[2]), RisoPrint.NIGHT, 0.2)
	frame = body
	_place()
	_solid(_poncho())
	# Two long folds fall from each shoulder toward the narrow hem.
	for side: float in [-1.0, 1.0]:
		var hem: Vector2 = _hem(2 + int(side)) + Vector2(side * 3.4, -3.4)
		_over(RisoShapes.tri(Vector2(side * 4.6, -17.6 + b), Vector2(side * 7.6, -15.4 + b), hem), RisoPrint.NIGHT, 0.22)
	var head: Vector2 = FOOL_HEAD + Vector2(head_x, head_y)
	_place_bar(Vector2(0.2, FOOL_COLLAR_TOP + 1.5 + b), head + Vector2(0, 1.0), 2.8)
	_solids(_rest(&"bar"))
	_overs(_rest(&"bar"), RisoPrint.NIGHT, NECK_SHADE)
	# While it leads a turn, the head is drawn facing the new way, mirrored about its own centre.
	var looks: Transform2D = Transform2D(0.0, Vector2(head_facing() * facing, 1.0), 0.0, head) * Transform2D(0.0, -head)
	frame = body * looks
	_place(Transform2D(0.0, head))
	_solids(_rest(&"hair"), RisoPrint.EYE, 0.2, false)
	_solids(_rest(&"head"), RisoPrint.NIGHT)
	_eyes()
	frame = body
	_place(Transform2D(0.0, Vector2(0, b)))
	_solids(_rest(&"collar"), RisoPrint.CLOTH, COLLAR_COVER)
	frame = body * looks
	_place(Transform2D(wizard.hat_a * 0.6, head + Vector2(0, -3.9)))
	_solids(_rest(&"beret"))
	_place()
	var quill: Vector2 = head + Vector2(-1.6, -5.4)
	var sway: float = wizard.tip_a * facing + _flick()
	var plume: PackedVector2Array = plume_shape(quill, sway)
	var plate: int = feather_plate()
	var ready: bool = plate != RisoPrint.NIGHT
	if ready:
		_solid(plume, plate)
		_over(plume, plate, 0.15)
	else:
		_solid(plume, RisoPrint.NIGHT, SPENT_FEATHER)
	_paper(plume_shape(quill, sway, 0.35, 0.3), 0.1 if ready else 0.0)
	frame = body
	# The beads never touch, so the whole and the spent each print at once.
	_place(Transform2D(0.0, Vector2(0.2, FOOL_COLLAR_TOP + 2.6 + b)))
	var count: Vector2i = Vector2i(wizard.player.health.max_health, wizard.player.health.health)
	if not _bead_keys.has(count):
		_bead_keys[count] = [StringName("beads %d %d whole" % [count.x, count.y]), StringName("beads %d %d spent" % [count.x, count.y])]
	var bead_keys: Array = _bead_keys[count]
	_solids(_rest(bead_keys[0]), RisoPrint.EYE, 0.12, false)
	_solids(_rest(bead_keys[1]), RisoPrint.NIGHT, 1.0, false)
	# Both gloves come out of the poncho: one grips the pole on the shoulder, and one, at the poncho's
	# widest corner, holds the lantern's bail.
	_hand(grip, GLOVE_SHADE)
	# A short sleeve keeps the swinging lantern hand joined to the poncho's corner.
	# Sitting, it sets the lantern down beside its boots and that glove flips a coin instead.
	var hang: Vector2 = _lantern_hang()
	var hand: Vector2 = _lantern_hand().lerp(COIN_HAND, seated())
	_place_bar(Vector2(FOOL_SHOULDER - 1.6, -14.2 + b * 0.8), hand, 2.6)
	_solids(_rest(&"bar"))
	frame = _turned(hang, _lantern_tilt())
	_place(Transform2D(0.0, hang + Vector2(0, LANTERN_REACH)))
	_lantern(Vector2.ZERO, true)
	frame = body
	_hand(hand, GLOVE_SHADE)
	if sit >= 1.0:
		_coin(hand)


## The coin, tossed from the glove at `hand`, spinning (its width narrowing to an edge and back),
## caught, and tossed again: gold ink, with a paper glint as its face turns to the light.
func _coin(hand: Vector2) -> void:
	var u: float = fposmod(coin_t / COIN.z, 1.0)
	var a: float = u / COIN_AIR
	var lift: float = 4.0 * COIN.y * a * (1.0 - a) if a < 1.0 else 0.0
	var turn: float = cos(coin_t * COIN_SPIN) if a < 1.0 else 1.0
	_place(Transform2D(0.0, hand))
	var at: Vector2 = Vector2(0.2, -2.3 - lift)
	var face: PackedVector2Array = RisoShapes.ellipse(at, COIN.x * maxf(absf(turn), 0.18), COIN.x, 16)
	_solid(face, RisoPrint.ACCENT, 1.0, false)
	if absf(turn) > 0.55:
		_paper(RisoShapes.circle(at + Vector2(-0.35 * turn, -0.4), 0.42, 8), 0.0)


## A short boot with a rounded toe and a pale turned-down cuff, its sole on the foot's point.
func _fool_boot(at: Vector2) -> void:
	_place(Transform2D(0.0, at))
	_solids(_rest(&"boot"))
	_solids(_rest(&"cuff"), RisoPrint.EYE, 0.25, false)


## Two warm eye slits in an otherwise anonymous face (in the head's space), shut now and then.
func _eyes() -> void:
	var blink: bool = fposmod(wizard.t, 3.9) < 0.11
	_solids(_rest(&"eyes shut" if blink else &"eyes"), RisoPrint.EYE, 0.85, false)


## A small glove without a sleeve or arm; the Fool's gloves are shaded darker than the poncho they leave.
func _hand(at: Vector2, shade: float = 0.0) -> void:
	_place(Transform2D(0.0, at))
	_solids(_rest(&"glove"))
	if shade > 0.0:
		_overs(_rest(&"glove"), RisoPrint.NIGHT, shade)
	_overs(_rest(&"glove_line"), RisoPrint.NIGHT, 0.25)


## Spawn protection is a warm flame; without it the same lantern holds only a charred wick.
func _lantern(at: Vector2, carried: bool) -> void:
	var lit: bool = MapInfo.instance != null and MapInfo.instance.flame_lit()
	if carried:
		_carried_lantern(lit, MapInfo.instance != null and MapInfo.instance.flame_snuffed())
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


## A hand lantern on a short bail (drawn in its own space, the flame at the origin): cap, dark
## glass and base, with one plain teardrop of flame; once `snuffed`, dark glass holding a pale
## crescent.
func _carried_lantern(lit: bool, snuffed: bool) -> void:
	_solids(_rest(&"bail"))
	if lit:
		_overs(_rest(&"glow"), RisoPrint.EYE, 0.12)
		_solids(_rest(&"glass"), RisoPrint.EYE, 0.3, false)
		_solids(_rest(&"flame"), RisoPrint.EYE, 0.9, false)
	elif snuffed:
		_solids(_rest(&"glass"), RisoPrint.NIGHT, SNUFFED_GLASS, false)
		_solids(_rest(&"moon"), RisoPrint.EYE, 0.0, false)
		_solids(_rest(&"wick"), RisoPrint.CLOTH, 1.0, false)
	else:
		# Unprotected: a dim pink glow, slowly pulsing, around a small ember.
		var pulse: float = 0.5 + 0.5 * sin(wizard.t * UNLIT_PULSE)
		_overs(_rest(&"halo"), RisoPrint.PINK, UNLIT_HALO * (0.7 + 0.3 * pulse))
		_solids(_rest(&"glass"), RisoPrint.PINK, UNLIT_GLASS * (0.8 + 0.2 * pulse), false)
		_solids(_rest(&"ember"), RisoPrint.PINK, 0.85, false)
	_solids(_rest(&"lantern_ends"))


## A large spell mark fills `shape`: the damage slot's spell, on the bag.
func _spell_area(bag: Array[PackedVector2Array], at: Vector2, radius: float) -> void:
	var shape: PackedVector2Array = bag[0]
	var spell: StringName = Abilities.spell(wizard.player)
	if spell == &"":
		_solids(bag)
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
	_solids(bag, plate, 1.0 if ready else 0.2)
	if not ready:
		_overs(bag, RisoPrint.NIGHT, 0.5)
		for fill: PackedVector2Array in Geometry2D.intersect_polygons(shape, wizard._filled(at, radius, charge)):
			_solid(fill, plate, 0.65, false)
	var key: StringName = _keys_for(spell)[3]
	if not _rests.has(key):
		_rests[key] = _glyph(spell, at, radius * 0.72)
	wizard.body.lift_ink(RisoPrint.ALL_PLATES, 1.0 if ready else 0.25, _rests[key])
	if spell == &"awareness":
		# The open eye looks out through a dark, upright pupil.
		_solids(_rest(&"pupil"), RisoPrint.NIGHT, 1.0 if ready else 0.4, false)
	if running and run.x > 0.01:
		_over(wizard._arc(at, radius * 0.82, 0.3, run.x), RisoPrint.EYE, 0.9)
	var mend: Mend = wizard.player.get_node_or_null("Mend") as Mend
	if spell == &"mend" and mend != null:
		for i: int in range(mend.draughts()):
			_paper(RisoShapes.circle(at + Vector2((float(i) - 1.0) * 1.2, radius * 0.5), 0.35, 8))
	wizard.body.coverage = cover


## Fit the existing ability mark inside the visible spell area without losing its proportions.
## The Fool carries astral as a crescent moon, as on the concept sheets, rather than the ghost.
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


## Shapes that only ever move, smoothed once at the origin (smoothing a moved outline is moving
## the smoothed one), by name: the hair, the collar, a boot's toe and each spell's bag.
static var _smoothed: Dictionary = {}


## `points` smoothed in `seg` steps, kept under `key`, then moved to `at`.
static func _moved(key: StringName, points: PackedVector2Array, seg: int, at: Vector2) -> PackedVector2Array:
	var shape: Variant = _smoothed.get(key)
	if shape == null:
		shape = RisoShapes.smooth(points, seg)
		_smoothed[key] = shape
	return Transform2D(0.0, at) * (shape as PackedVector2Array)


## Pale hair under the beret, in rounded tufts flicking out at both sides.
static func hair_shape(head: Vector2) -> PackedVector2Array:
	return _moved(&"hair", PackedVector2Array([
		Vector2(4.8, -3.4), Vector2(5.4, -1.0), Vector2(6.8, 0.9), Vector2(5.1, 1.0), Vector2(5.3, 3.1), Vector2(3.6, 2.1),
		Vector2(0, 2.4),
		Vector2(-3.6, 2.1), Vector2(-5.3, 3.1), Vector2(-5.1, 1.0), Vector2(-6.8, 0.9), Vector2(-5.4, -1.0), Vector2(-4.8, -3.4),
	]), 3, head)


## The Fool's collar: a straight neckline whose lower edge droops in a soft curve over the
## poncho's shoulders, deepest at the front of the chest.
static func collar_shape(at: Vector2) -> PackedVector2Array:
	var top: float = FOOL_COLLAR_TOP
	return _moved(&"collar", PackedVector2Array([
		Vector2(-4.0, top), Vector2(0.2, top + 0.6), Vector2(4.4, top),
		Vector2(7.4, top + 2.4), Vector2(5.0, top + 4.6), Vector2(0.2, top + 6.4),
		Vector2(-4.6, top + 4.6), Vector2(-7.0, top + 2.4),
	]), 4, at)


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


## The ink the feather prints in: it is the movement slot. In its ability's glow ink (RisoPrint
## sets the glow plate's colour to it) while ready, dark (NIGHT) when spent or with nothing in the
## slot; in a running spell's last SPELL_WARN seconds it blinks, pink and dark, faster toward the end.
func feather_plate() -> int:
	var run: Vector2 = Abilities.running(wizard.player, &"move")
	if run.x >= 0.0 and run.y < SPELL_WARN:
		return RisoPrint.PINK if fmod(wizard.t * lerpf(9.0, 3.0, run.y / SPELL_WARN), 1.0) < 0.6 else RisoPrint.NIGHT
	return RisoPrint.GLOW if wizard.player.move_ready() else RisoPrint.NIGHT


## Where the bag hangs (the wizard's local space), for a puff from its knot.
func bag_position() -> Vector2:
	_follow()
	var facing: float = 1.0 if wizard.fs >= 0.0 else -1.0
	var knot: Vector2 = FOOL_BINDLE + Vector2(-0.5, -6.5 + bob)
	return wizard._smv(Transform2D(lean, Vector2.ZERO) * Vector2(knot.x * facing, knot.y))


## The whole cloth bundle changes its weighted folds and shape with the spell.
static func bindle_shape(spell: StringName, at: Vector2) -> PackedVector2Array:
	var form: Vector3 = BINDLE_FORMS.get(spell, BINDLE_FORMS[&""])
	var width: float = form.x
	var height: float = form.y
	var weight: float = form.z
	return _moved(StringName("bag " + str(spell)), PackedVector2Array([
		Vector2(-0.8, -5.5), Vector2(0.9, -5.5), Vector2(width + weight, -1.4),
		Vector2(width + weight, height * 0.55), Vector2(2 + weight, height), Vector2(-2 + weight, height),
		Vector2(-width + weight, height * 0.55), Vector2(-width + weight, -1.4),
	]), 4, at)


## The Fool's outline for dash echoes, astral return points, ghosts and portal trips. A live
## `pose` (their own costume) swings the bag and lantern to match the figure; without one, they hang
## at rest.
static func silhouette(at: Transform2D, facing: float, spell: StringName = &"", pose: RisoCostume = null) -> Array[PackedVector2Array]:
	var local: Array[PackedVector2Array] = []
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
	var hand: Vector2 = LANTERN_AT + Vector2(0, -LANTERN_REACH)
	var lantern: PackedVector2Array = RisoShapes.rrect(hand.x - 2.9, hand.y, 5.8, LANTERN_REACH + 3.6, 1.5)
	local.append(Transform2D(held.y, hand) * Transform2D(0.0, -hand) * lantern)
	for side: float in [-1.0, 1.0]:
		var foot: Vector2 = Vector2(side * 1.9 * GAIT.z, 0)
		local.append(RisoShapes.rrect(foot.x - 1.5, -5.0, 4.9, 5.0, 1.0))
	var out: Array[PackedVector2Array] = []
	var turn: Transform2D = at * Transform2D(0, Vector2(facing, 1), 0, Vector2.ZERO)
	for poly: PackedVector2Array in local:
		out.append(turn * poly)
	return out
