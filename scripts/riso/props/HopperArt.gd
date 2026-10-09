extends CreatureArt
## A hopper: a squat toad of a nightmare that curls and arches as it leaps.


## The hopper's bend and its thorns' (see _hopper): springs.
var hop_bend: float = 0.0
var hop_bend_v: float = 0.0
var thorn_a: float = 0.0
var thorn_v: float = 0.0


## The hopper: a squat pink toad of a nightmare with a ridge of thorns down its back and two
## paper eye slits. It curls forward as it crouches to leap (the slits narrow), arches through the
## air over its shadow, and is thrown forward as it lands, its thorns whipping after.
func _draw_art() -> void:
	var hop: Hopper = host.get_node_or_null("Hopper") as Hopper
	var facing: float = 1.0
	var crouch: float = -1.0
	var vel: Vector2 = Vector2.ZERO
	var grounded: bool = true
	var landed: float = 10.0
	var stunned: bool = false
	if hop != null:
		facing = hop.facing
		crouch = hop.crouch
		vel = hop.velocity
		grounded = hop.grounded
		landed = hop.since_landing
		stunned = hop.stunned
	# It bends rather than squashing: curled forward over its feet as it crouches, arched nose-up
	# rising and nose-down falling, thrown forward by its weight on landing, and its thorns whip
	# after the body on a looser spring.
	var bend_t: float = 0.0
	if stunned:
		bend_t = -0.1
	elif crouch >= 0.0:
		bend_t = 0.5 * crouch * crouch * (3.0 - 2.0 * crouch)
	elif not grounded:
		bend_t = clampf(vel.y / 700.0, -1.0, 1.0) * 0.32
	if grounded and landed < _dt * 1.5:
		hop_bend_v += 6.0
		thorn_v += 9.0
	hop_bend_v += ((bend_t - hop_bend) * 140.0 - hop_bend_v * 10.0) * _dt
	hop_bend += hop_bend_v * _dt
	thorn_v += ((hop_bend * 1.4 - thorn_a) * 60.0 - thorn_v * 4.0) * _dt
	thorn_a += thorn_v * _dt
	var k: float = 1.7
	var feet: Vector2 = Vector2(0, 16)
	var xf: Transform2D = Transform2D(0.0, Vector2(facing * k, k), 0.0, feet)
	if not grounded:
		var g: float = _ground()
		var high: float = clampf((g - feet.y) / 300.0, 0.0, 1.0)
		ink.ink(RisoPrint.NIGHT, 0.35 * (1.0 - high * 0.6), [RisoShapes.ellipse(Vector2(0, g - 3.0), 26.0 * (1.0 - high * 0.4), 5.0, 16)], false)
	var body: PackedVector2Array = xf * RisoMarks.bent(RisoShapes.smooth(PackedVector2Array([Vector2(-15, 0), Vector2(-16, -7), Vector2(-11, -15),
		Vector2(-2, -19), Vector2(8, -18), Vector2(15, -11), Vector2(17, -4), Vector2(15, 0)])), hop_bend, 19.0)
	var thorns: Array[PackedVector2Array] = []
	for spike: Array in [[Vector2(-13, -12), Vector2(-7, -17), Vector2(-13, -23)], [Vector2(-5, -18), Vector2(2, -19), Vector2(-3, -27)], [Vector2(3, -19), Vector2(9, -17), Vector2(6, -25)]]:
		# Each thorn turns about its base with the body, its tip trailing on its own spring.
		var a: Vector2 = RisoMarks.bent_v(spike[0], hop_bend, 19.0)
		var b: Vector2 = RisoMarks.bent_v(spike[1], hop_bend, 19.0)
		var base: Vector2 = (a + b) * 0.5
		var tip: Vector2 = base + ((spike[2] as Vector2) - ((spike[0] as Vector2) + (spike[1] as Vector2)) * 0.5).rotated(hop_bend + (thorn_a - hop_bend) * 0.8 + sin(t * 3.0 + phase) * 0.04)
		thorns.append(xf * RisoShapes.tri(a, b, tip))
	var feet_nubs: Array[PackedVector2Array] = [xf * RisoShapes.ellipse(Vector2(-9, 0), 4.0, 2.0, 10), xf * RisoShapes.ellipse(Vector2(9, 0), 4.0, 2.0, 10)]
	ink.ink(RisoPrint.NIGHT, 0.8, feet_nubs, false)
	ink.ink(RisoPrint.PINK, 1.0, thorns)
	ink.ink(RisoPrint.NIGHT, 0.45, thorns, false)
	ink.knock([RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW], [body])
	ink.ink(RisoPrint.PINK, 1.0, [body])
	ink.ink(RisoPrint.BLUE, 0.35, [body], false)
	var eyes: Array[PackedVector2Array] = []
	for e0: Vector2 in [Vector2(8.5, -11.5), Vector2(13.0, -10.5)]:
		var e: Vector2 = RisoMarks.bent_v(e0, hop_bend, 19.0)
		if stunned:
			eyes.append(xf * RisoShapes.rrect(e.x - 1.6, e.y - 0.3, 3.2, 0.6, 0.3, 2))
		elif crouch >= 0.0:
			eyes.append(xf * PackedVector2Array([e + Vector2(-1.8, -1.2), e + Vector2(1.8, 0.2), e + Vector2(1.6, 1.0), e + Vector2(-1.8, 0.2)]))
		else:
			eyes.append(xf * RisoShapes.ellipse(e, 1.4, 2.2, 12))
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE], eyes)
	if stunned:
		_stun_mark(xf * Vector2(0, -30))
