class_name AbominationArt
extends CreatureArt
## An abomination (Abomination): a cluster of breathing pink gumdrops (a round dome on sides that
## flare out to a flat foot, `gumdrop`; the central one's foot on the floor, each budding one's
## turned toward the blob it grew from, Abomination.parents), as many as it has health, laid
## out by its own shape (Abomination.layout: a big central blob on the floor, the others grown
## mostly off it, each its own size), each with its eyes where its shape put them (one or two, paper
## with night pupils, looking about and now and then blinking) and tentacles curling and
## groping up and out from it, kept over the floor where they reach it, writhing faster while it crawls, each its own length and width. It rolls a
## little as it crawls. A new blob swells into place as it grows; a burst one leaves a pink splash.
## Braced to launch a blob (its tell), the cluster quivers and squats while its top blob swells and
## throbs, a pink glow growing round it; launched, a bare blob with no tentacles tumbles along its arc. It lurches as it
## bites and grows up out of the floor as it rises from a breach. Its night underside sits on the
## floor. Stunned, stars circle over it and its eyes shut.
##
## How it is printed, cheaply: every part is drawn once, at rest, when it is first printed (a
## RigSheet of its own, as each abomination has its own shape), and after that only placed by the
## canvas's rig (InkCanvas.rig), a joint for its underside, each blob, each eye and each pupil, and
## three for each tentacle (its root, its middle and its tip, the tentacle bending between them):
## nothing is built again as it moves (_pose).

## How long (seconds) a new blob takes to swell into place, and how far over the floor its tentacles
## keep (px): one that would reach under it is turned up, at its middle and at its tip.
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
## Its joints, by number (each has a bone of the rig's): the canvas's own, its underside, then one
## a blob, EYES an eye for each blob's whites and as many for their pupils, and three a tentacle.
## TENTACLES is the most tentacles it can have (Abomination.BASE_ARMS, LOBE_ARMS), which is as many
## as the rig has bones for.
const J_FRAME: int = 0
const J_UNDER: int = 1
const J_LOBE: int = 2
const EYES: int = 2
const J_WHITE: int = J_LOBE + Abomination.SPLIT
const J_PUPIL: int = J_WHITE + Abomination.SPLIT * EYES
const J_ARM: int = J_PUPIL + Abomination.SPLIT * EYES
const TENTACLES: int = 21
const JOINTS: int = J_ARM + 3 * TENTACLES
## How wide its underside is drawn at rest (px, half; its joint stretches it to the cluster), how
## many pieces a tentacle is cut into along its length, how wide its tip is (px), how far each
## piece turns as it curls (radians, at most), and how thin a shut eye is (px, half).
const UNDER_HALF: float = 100.0
const ARM_CUTS: int = 6
const ARM_TIP: float = 1.5
const ARM_TURN: float = 0.225
const SHUT: float = 0.7
## How far round it its parts may move from where they rest (px; RigSheet.close).
const REACH: Rect2 = Rect2(-180, -200, 360, 260)
## A joint shrunk to nothing: what it carries is not seen.
const GONE: Transform2D = Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)

## The cluster at rest, drawn when it is first printed, and each of its tentacles: the blob it
## grows from and Abomination.arms' Vector4 for it.
var _sheet: RigSheet = null
var _arm_lobe: PackedInt32Array = PackedInt32Array()
var _arm: Array[Vector4] = []
## Where each joint is this print.
var _joints: Array[Transform2D] = []


func _ready() -> void:
	super()
	ink.rig()
	ink.keeps_shapes = true
	_joints.resize(JOINTS)
	_joints.fill(GONE)
	_joints[J_FRAME] = Transform2D.IDENTITY


func _draw_art() -> void:
	var a: Abomination = host as Abomination
	if a == null or a.layout.is_empty():
		return
	if _sheet == null:
		_sheet = _build(a)
	var n: int = clampi(a.lobes, 1, a.layout.size())
	var tell: float = a.tell()
	var xf: Transform2D = _pose(a, n, tell)
	for joint: Transform2D in _joints:
		ink.bone(joint)
	if tell >= 0.0:
		var top: Transform2D = _joints[J_LOBE + n - 1]
		ink.on_bone(0)
		ink.ink(RisoPrint.PINK, 0.15 + 0.3 * tell, [RisoShapes.circle(top.origin, a.layout[n - 1].z * absf(top.get_scale().y) * (1.6 + 0.6 * tell), 22)])
	ink.on_chain(_sheet.key, _sheet.bind)
	# Its underside, dark on the floor, under its tentacles (none while it flies).
	ink.ink(RisoPrint.NIGHT, 0.6, _sheet.of(&"under"), false)
	# Its tentacles, then its blobs over them, each on paper so they print the same pink over the
	# wood behind.
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], _sheet.of(&"arms"))
	ink.ink(RisoPrint.BLUE, 0.45, _sheet.of(&"arms"), false)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], _sheet.of(&"body"))
	ink.ink(RisoPrint.PINK, 1.0, _sheet.of(&"all"), false)
	ink.ink(RisoPrint.BLUE, 0.3, _sheet.of(&"body"), false)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], _sheet.of(&"whites"))
	ink.ink(RisoPrint.NIGHT, 1.0, _sheet.of(&"pupils"), false)
	# What comes and goes is printed last, so the prints before it stay as they are.
	ink.on_bone(0)
	var lost: float = a.t - a.lost_at
	if lost < 0.35:
		# A blob just burst: a pink splash where it was.
		var gone: Vector3 = a.lobe_at(n)
		var drops: Array[PackedVector2Array] = []
		for i: int in range(6):
			var d: Vector2 = Vector2.from_angle(float(i) * TAU / 6.0 + 0.4)
			drops.append(xf * RisoShapes.circle(Vector2(gone.x, gone.y) + d * (6.0 + lost * 90.0), 3.5 * (1.0 - lost / 0.35) + 0.5, 8))
		ink.ink(RisoPrint.PINK, 1.0, drops)
	if a.stunned():
		var top_y: float = 0.0
		for i: int in range(n):
			top_y = minf(top_y, a.layout[i].y - a.layout[i].z * 1.05)
		_stun_mark(xf * Vector2(0, top_y - 20.0))


## Where every joint is this print (_joints), `n` blobs of it shown, `tell` of the way through its
## tell (-1: none); the cluster's own placing comes back (px from its feet, facing right, to the
## canvas).
func _pose(a: Abomination, n: int, tell: float) -> Transform2D:
	# Its feet are a fixed way under its body's middle (Abomination.FEET), wherever it is: not the
	# floor of its cell (_ground), which would pin a blob in flight, or one hopping a step, to the
	# bottom of each cell it passes through and drop it a row at a time.
	var g: float = Abomination.FEET
	var stunned: bool = a.stunned()
	var grow: float = maxf(0.05, 1.0 - clampf(a.rising / a.rise_time, 0.0, 1.0)) if a.rising > 0.0 and a.rise_time > 0.0 else 1.0
	var bite: float = clampf(1.0 - a.since_bite / 0.3, 0.0, 1.0)
	var f: float = a.facing
	var breath: float = 1.0 + 0.05 * sin(t * 2.6 + phase)
	var flying: bool = a.flying()
	var spin: float = t * 9.0 * f if flying else 0.0
	var base: Vector3 = a.layout[0]
	# A gentle roll as it crawls.
	var haul: float = sin(a.crawled * 0.06) * 2.0 if a.crawling else 0.0
	var quiver: Vector2 = Vector2(sin(t * 47.0), cos(t * 39.0)) * 2.5 * tell if tell >= 0.0 else Vector2.ZERO
	var squat: float = 1.0 - 0.12 * maxf(tell, 0.0)
	var xf: Transform2D = Transform2D(0.0, Vector2(f * grow, grow * squat), 0.0, Vector2(bite * 16.0 * f + haul * f, g) + quiver) * Transform2D(spin, Vector2(0, base.y)) * Transform2D(0.0, Vector2(0, -base.y))
	var swell: float = clampf((a.t - a.grew_at) / SWELL, 0.0, 1.0)
	# Each blob's middle and size now.
	var lumps: Array[Vector3] = []
	var low: float = 0.0
	for i: int in range(n):
		var l: Vector3 = a.layout[i]
		var k: float = swell if i == n - 1 and n > 1 else 1.0
		var wob: Vector2 = Vector2(sin(t * 1.9 + float(i) * 1.3), cos(t * 1.4 + float(i))) * 2.0
		var size: float = l.z * breath * (0.2 + 0.8 * k)
		if tell >= 0.0 and i == n - 1:
			# The blob about to go swells and throbs, faster and bigger as the launch comes.
			size *= 1.0 + 0.35 * tell + 0.12 * sin(t * lerpf(10.0, 26.0, tell))
		lumps.append(Vector3(l.x + wob.x, l.y * breath + wob.y, size))
		low = maxf(low, absf(l.x + wob.x) + size * 0.8)
	_joints[J_UNDER] = GONE if flying else xf * Transform2D(0.0, Vector2(maxf(base.z, low) / UNDER_HALF, 1.0), 0.0, Vector2(0, -4))
	for i: int in range(Abomination.SPLIT):
		if i >= n:
			_joints[J_LOBE + i] = GONE
			for k: int in range(EYES):
				_joints[J_WHITE + i * EYES + k] = GONE
				_joints[J_PUPIL + i * EYES + k] = GONE
			continue
		var l: Vector3 = lumps[i]
		var c: Vector2 = Vector2(l.x, l.y)
		var sk: float = l.z / maxf(1.0, a.layout[i].z)
		# Its foot toward the blob it budded from; the central blob's on the floor.
		var from: int = a.parents[i] if i < a.parents.size() else 0
		var turn: float = 0.0
		if from != i and from < n:
			var to: Vector2 = Vector2(lumps[from].x - l.x, lumps[from].y - l.y)
			if to.length() > 0.5:
				turn = to.angle() - PI * 0.5
		_joints[J_LOBE + i] = xf * Transform2D(turn, Vector2(sk, sk), 0.0, c)
		var mine: Array = a.eyes[i]
		for k: int in range(EYES):
			var white: int = J_WHITE + i * EYES + k
			var pupil: int = J_PUPIL + i * EYES + k
			if k >= mine.size():
				_joints[white] = GONE
				_joints[pupil] = GONE
				continue
			var eye: Vector3 = mine[k]
			var e: float = eye.z * sk
			var at: Vector2 = c + Vector2(eye.x, eye.y) * sk
			var blink: bool = fposmod(t * 0.7 + float(i) * 0.37 + float(k) * 0.53 + phase, 4.0) < 0.12
			if stunned or blink:
				_joints[white] = xf * Transform2D(0.0, Vector2(sk, SHUT / maxf(eye.z, 0.1)), 0.0, at)
				_joints[pupil] = GONE
				continue
			_joints[white] = xf * Transform2D(0.0, Vector2(sk, sk), 0.0, at)
			var look: Vector2 = Vector2(sin(t * 0.9 + float(i) * 2.1 + float(k)), cos(t * 1.1 + float(i) + float(k) * 1.7)) * e * 0.35
			_joints[pupil] = xf * Transform2D(0.0, Vector2(sk, sk), 0.0, at + look)
	# Tentacles: curling and groping round it, writhing faster as it crawls; none on a blob in
	# flight, which sprouts them as it lands.
	for k: int in range(_arm.size()):
		var j: int = J_ARM + 3 * k
		var lobe: int = _arm_lobe[k]
		if flying or lobe >= n:
			_joints[j] = GONE
			_joints[j + 1] = GONE
			_joints[j + 2] = GONE
			continue
		var arm: Vector4 = _arm[k]
		var l: Vector3 = lumps[lobe]
		var root: Vector2 = Vector2(l.x, l.y) + Vector2.from_angle(arm.x) * l.z * 0.85
		var s: float = t * (1.8 + arm.w * 0.15) * (1.6 if a.crawling else 1.0) + arm.w
		var reach: float = bite * 2.4 if root.x > 0.0 else 0.0
		var half: Vector2 = Vector2(0, -arm.y * 0.5)
		# The turns its pieces made one by one, summed over each half.
		var first: float = ARM_TURN * (sin(s) + sin(s + 0.7) + sin(s + 1.4) + reach)
		var second: float = ARM_TURN * (sin(s + 2.1) + sin(s + 2.8) + sin(s + 3.5) + reach)
		var from: Transform2D = Transform2D(arm.x + PI * 0.5, root)
		var middle: Transform2D = from * Transform2D(first, Vector2.ZERO)
		# Never through the floor: its middle, then its tip, is turned up to lie over it.
		middle = AbominationArt._over_floor(root, middle * half) * middle
		var tip: Transform2D = middle * Transform2D(second, half - half.rotated(second))
		tip = AbominationArt._over_floor(middle * half, tip * (half * 2.0)) * tip
		_joints[j] = xf * from
		_joints[j + 1] = xf * middle
		_joints[j + 2] = xf * tip
	return xf


## The turn about `pivot` that brings `point` up to FLOOR_GAP over the floor (y 0, in the cluster's
## own space), on the side of the pivot it is on; none if it is over it already.
static func _over_floor(pivot: Vector2, point: Vector2) -> Transform2D:
	if point.y <= -FLOOR_GAP:
		return Transform2D.IDENTITY
	var arm: Vector2 = point - pivot
	var long: float = arm.length()
	if long < 0.5:
		return Transform2D.IDENTITY
	var rise: float = asin(clampf((-FLOOR_GAP - pivot.y) / long, -1.0, 1.0))
	var to: float = rise if arm.x >= 0.0 else PI - rise
	var by: float = wrapf(to - arm.angle(), -PI, PI)
	return Transform2D(by, pivot - pivot.rotated(by))


## The cluster of `a` at rest (see the class description): each part drawn round its own joint.
func _build(a: Abomination) -> RigSheet:
	var sh: RigSheet = RigSheet.new()
	sh.one_a_joint = true
	# The first part is the canvas's own, and holds nothing but the layers' pegs (RigSheet.close).
	sh.slot(J_FRAME)
	_arm_lobe.clear()
	_arm.clear()
	sh.add(&"under", sh.slot(J_UNDER), RisoShapes.ellipse(Vector2.ZERO, UNDER_HALF, 7.0, 18))
	for i: int in range(Abomination.SPLIT):
		var mine: Array = a.arms[i]
		for arm: Vector4 in mine:
			if _arm.size() >= TENTACLES:
				break
			var j: int = J_ARM + 3 * _arm.size()
			_arm_lobe.append(i)
			_arm.append(arm)
			var halves: Array[int] = [sh.slot(j, j + 1, 0.0, -arm.y * 0.5), sh.slot(j + 1, j + 2, -arm.y * 0.5, -arm.y)]
			for h: int in range(2):
				var piece: PackedVector2Array = AbominationArt._arm_piece(arm.y, arm.z, h)
				sh.add(&"arms", halves[h], piece)
				sh.add(&"all", halves[h], piece)
	for i: int in range(Abomination.SPLIT):
		var part: int = sh.slot(J_LOBE + i)
		var drop: PackedVector2Array = AbominationArt.gumdrop(Vector2.ZERO, a.layout[i].z)
		sh.add(&"body", part, drop)
		sh.add(&"all", part, drop)
		var mine: Array = a.eyes[i]
		for k: int in range(mini(mine.size(), EYES)):
			var eye: Vector3 = mine[k]
			sh.add(&"whites", sh.slot(J_WHITE + i * EYES + k), RisoShapes.circle(Vector2.ZERO, eye.z, 14))
			sh.add(&"pupils", sh.slot(J_PUPIL + i * EYES + k), RisoShapes.circle(Vector2.ZERO, eye.z * 0.45, 10))
	var far: Array[StringName] = []
	sh.close(REACH, far, REACH)
	return sh


## Half of a tentacle `long` px long and `wide` at its root, drawn straight up from its root at
## rest and tapering to ARM_TIP: its lower half (`half` 0) or its upper.
static func _arm_piece(long: float, wide: float, half: int) -> PackedVector2Array:
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	@warning_ignore("integer_division")
	var cuts: int = ARM_CUTS / 2
	for k: int in range(cuts + 1):
		var u: float = (float(half) + float(k) / float(cuts)) * 0.5
		var w: float = lerpf(wide, ARM_TIP, u) * 0.5
		left.append(Vector2(-w, -long * u))
		right.append(Vector2(w, -long * u))
	right.reverse()
	left.append_array(right)
	return left


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
