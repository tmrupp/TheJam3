extends CreatureArt
## An abomination (Abomination): a cluster of breathing pink gumdrops (a round dome on sides that
## flare out to a flat foot, `gumdrop`; the central one's foot on the floor, each budding one's
## turned toward the blob it grew from, Abomination.parents), as many as it has health, laid
## out by its own shape (Abomination.layout: a big central blob on the floor, the others grown
## mostly off it, each its own size), each with its eyes where its shape put them (one or two, paper
## with night pupils, looking about and now and then blinking) and tentacles curling and
## groping up and out from it, lying along the floor where they reach it, writhing faster while it crawls, each its own length and width. It rolls a
## little as it crawls. A new blob swells into place as it grows; a burst one leaves a pink splash.
## Braced to launch a blob (its tell), the cluster quivers and squats while its top blob swells and
## throbs, a pink glow growing round it; launched, a bare blob with no tentacles tumbles along its arc. It lurches as it
## bites and grows up out of the floor as it rises from a breach. Its night underside sits on the
## floor. Stunned, stars circle over it and its eyes shut.

## How long (seconds) a new blob takes to swell into place, and how far over the floor its tentacles
## keep (px): they lie along it rather than go through it.
const SWELL: float = 0.45
const FLOOR_GAP: float = 3.0
## A blob's gumdrop, as shares of its size (its radius as a disc would be): the dome's radius and
## how far below the middle its centre sits (a squat dome), how far down the flat foot is and how far
## out either side, and how round the foot's corners are.
const GUM_DOME: float = 0.88
const GUM_DOME_DOWN: float = 0.12
const GUM_FOOT_DOWN: float = 1.0
const GUM_FOOT_OUT: float = 1.0
const GUM_CORNER: float = 0.2


func _draw_art() -> void:
	var a: Abomination = host as Abomination
	if a == null or a.layout.is_empty():
		return
	# Its feet are a fixed way under its body's middle (Abomination.FEET), wherever it is: not the
	# floor of its cell (_ground), which would pin a blob in flight, or one hopping a step, to the
	# bottom of each cell it passes through and drop it a row at a time.
	var g: float = Abomination.FEET
	var stunned: bool = a.stunned()
	var grow: float = maxf(0.05, 1.0 - clampf(a.rising / a.rise_time, 0.0, 1.0)) if a.rising > 0.0 and a.rise_time > 0.0 else 1.0
	var bite: float = clampf(1.0 - a.since_bite / 0.3, 0.0, 1.0)
	var f: float = a.facing
	var breath: float = 1.0 + 0.05 * sin(t * 2.6 + phase)
	var tell: float = a.tell()
	var flying: bool = a.flying()
	var spin: float = t * 9.0 * f if flying else 0.0
	var base: Vector3 = a.layout[0]
	# A gentle roll as it crawls.
	var haul: float = sin(a.crawled * 0.06) * 2.0 if a.crawling else 0.0
	var quiver: Vector2 = Vector2(sin(t * 47.0), cos(t * 39.0)) * 2.5 * tell if tell >= 0.0 else Vector2.ZERO
	var squat: float = 1.0 - 0.12 * maxf(tell, 0.0)
	var xf: Transform2D = Transform2D(0.0, Vector2(f * grow, grow * squat), 0.0, Vector2(bite * 16.0 * f + haul * f, g) + quiver) * Transform2D(spin, Vector2(0, base.y)) * Transform2D(0.0, Vector2(0, -base.y))
	var n: int = clampi(a.lobes, 1, a.layout.size())
	var swell: float = clampf((a.t - a.grew_at) / SWELL, 0.0, 1.0)
	var lumps: Array[Vector3] = []
	for i: int in range(n):
		var l: Vector3 = a.layout[i]
		var k: float = swell if i == n - 1 and n > 1 else 1.0
		var wob: Vector2 = Vector2(sin(t * 1.9 + float(i) * 1.3), cos(t * 1.4 + float(i))) * 2.0
		var size: float = l.z * breath * (0.2 + 0.8 * k)
		if tell >= 0.0 and i == n - 1:
			# The blob about to go swells and throbs, faster and bigger as the launch comes.
			size *= 1.0 + 0.35 * tell + 0.12 * sin(t * lerpf(10.0, 26.0, tell))
		lumps.append(Vector3(l.x + wob.x, l.y * breath + wob.y, size))
	if tell >= 0.0:
		var top: Vector3 = lumps[n - 1]
		ink.ink(RisoPrint.PINK, 0.15 + 0.3 * tell, [xf * RisoShapes.circle(Vector2(top.x, top.y), top.z * (1.6 + 0.6 * tell), 22)])
	# Its underside, dark on the floor, under its tentacles (none while it flies).
	if not flying:
		var low: float = 0.0
		for l: Vector3 in lumps:
			low = maxf(low, absf(l.x) + l.z * 0.8)
		ink.ink(RisoPrint.NIGHT, 0.6, [xf * RisoShapes.ellipse(Vector2(0, -4), maxf(base.z, low), 7.0, 18)], false)
	# Tentacles: curling and groping round it, writhing faster as it crawls; none on a blob in
	# flight, which sprouts them as it lands.
	var tentacles: Array[PackedVector2Array] = []
	for i: int in range(0 if flying else n):
		var l: Vector3 = lumps[i]
		var list: Array = a.arms[i]
		for k: int in range(list.size()):
			var arm: Vector4 = list[k]
			var root_art: Vector2 = Vector2(l.x, l.y) + Vector2.from_angle(arm.x) * l.z * 0.85
			var ang: float = arm.x
			var at: Vector2 = root_art
			var pts: PackedVector2Array = PackedVector2Array()
			for j: int in range(7):
				pts.append(at)
				var curl: float = sin(t * (1.8 + arm.w * 0.15) * (1.6 if a.crawling else 1.0) + arm.w + float(j) * 0.7) * 0.5 + (bite * 0.4 if at.x > 0.0 else 0.0)
				ang += curl * 0.45
				at += Vector2.from_angle(ang) * arm.y / 6.0
				# Never through the floor: it lies along it and curls on.
				if at.y > -FLOOR_GAP:
					at.y = -FLOOR_GAP
					ang = lerp_angle(ang, 0.0 if cos(ang) >= 0.0 else PI, 0.6)
			for poly: PackedVector2Array in RisoDecor.strip(pts, arm.z, 1.5):
				tentacles.append(xf * poly)
	# On paper, as the body is, so they print the same pink over the wood behind.
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], tentacles)
	ink.ink(RisoPrint.PINK, 1.0, tentacles, false)
	ink.ink(RisoPrint.BLUE, 0.45, tentacles, false)
	var body: Array[PackedVector2Array] = []
	for i: int in range(lumps.size()):
		var l: Vector3 = lumps[i]
		# Its foot toward the blob it budded from; the central blob's on the floor.
		var from: int = a.parents[i] if i < a.parents.size() else 0
		var turn: float = 0.0
		if from != i:
			var to: Vector2 = Vector2(lumps[from].x - l.x, lumps[from].y - l.y)
			if to.length() > 0.5:
				turn = to.angle() - PI * 0.5
		var c: Vector2 = Vector2(l.x, l.y)
		body.append(xf * (Transform2D(turn, c) * gumdrop(Vector2.ZERO, l.z)))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], body)
	ink.ink(RisoPrint.PINK, 1.0, body, false)
	ink.ink(RisoPrint.BLUE, 0.3, body, false)
	# A blob just burst: a pink splash where it was.
	var lost: float = a.t - a.lost_at
	if lost < 0.35:
		var gone: Vector3 = a.lobe_at(n)
		var drops: Array[PackedVector2Array] = []
		for i: int in range(6):
			var d: Vector2 = Vector2.from_angle(float(i) * TAU / 6.0 + 0.4)
			drops.append(xf * RisoShapes.circle(Vector2(gone.x, gone.y) + d * (6.0 + lost * 90.0), 3.5 * (1.0 - lost / 0.35) + 0.5, 8))
		ink.ink(RisoPrint.PINK, 1.0, drops)
	var whites: Array[PackedVector2Array] = []
	var pupils: Array[PackedVector2Array] = []
	for i: int in range(lumps.size()):
		var l: Vector3 = lumps[i]
		var sk: float = l.z / maxf(1.0, a.layout[i].z)
		var mine: Array = a.eyes[i]
		for k: int in range(mine.size()):
			var eye: Vector3 = mine[k]
			var e: float = eye.z * sk
			var c: Vector2 = Vector2(l.x, l.y) + Vector2(eye.x, eye.y) * sk
			var blink: bool = fposmod(t * 0.7 + float(i) * 0.37 + float(k) * 0.53 + phase, 4.0) < 0.12
			if stunned or blink:
				whites.append(xf * RisoShapes.rrect(c.x - e, c.y - 0.7, e * 2.0, 1.4, 0.7))
				continue
			whites.append(xf * RisoShapes.circle(c, e, 14))
			var look: Vector2 = Vector2(sin(t * 0.9 + float(i) * 2.1 + float(k)), cos(t * 1.1 + float(i) + float(k) * 1.7)) * e * 0.35
			pupils.append(xf * RisoShapes.circle(c + look, e * 0.45, 10))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], whites)
	ink.ink(RisoPrint.NIGHT, 1.0, pupils, false)
	if stunned:
		var top_y: float = 0.0
		for l: Vector3 in lumps:
			top_y = minf(top_y, l.y - l.z)
		_stun_mark(xf * Vector2(0, top_y - 20.0))


## A gumdrop round `c` the size of a disc of radius `r`: a round dome (GUM_DOME), its sides flaring
## out and down to a flat foot (GUM_FOOT_DOWN under `c`, GUM_FOOT_OUT either side) with rounded
## corners, about as wide as it is tall.
static func gumdrop(c: Vector2, r: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var dome: Vector2 = c + Vector2(0, GUM_DOME_DOWN * r)
	for i: int in range(13):
		var a: float = PI + PI * float(i) / 12.0
		out.append(dome + Vector2(cos(a), sin(a)) * GUM_DOME * r)
	var foot: float = c.y + GUM_FOOT_DOWN * r
	var wide: float = GUM_FOOT_OUT * r
	var k: float = GUM_CORNER * r
	for side: float in [1.0, -1.0]:
		# Down the flaring side to the foot's corner, round it, and along the foot.
		var corner: Vector2 = Vector2(c.x + side * (wide - k), foot - k)
		var arc: PackedVector2Array = PackedVector2Array()
		for j: int in range(4):
			var a: float = float(j) / 3.0 * PI * 0.5
			arc.append(corner + Vector2(side * cos(a), sin(a)) * k)
		if side < 0.0:
			arc.reverse()
		out.append_array(arc)
	return out
