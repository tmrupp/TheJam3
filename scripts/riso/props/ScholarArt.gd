extends CreatureArt
class_name ScholarArt
## The institute's people (Scholar), four figures told apart at a glance by their outline, their
## size, their ink and the way they move. Each has a dark hollow for a face with two flat paper
## eyes, no pupils, which turn wholly pink while it is turned on the wizard (Scholar.hostile);
## stunned, its eyes shut and stars circle over it. Drawn in px from its feet, facing right.
## - a student: small and round, a plum bean (pink over blue) of hood and cape on two paper legs,
##   a paper scarf round its neck whose tail streams behind as it scurries, bouncing. Its little
##   pink orb floats before it, comes forward and swells as it winds up a bolt, and sputters when
##   it misfires; scattering, it leans into its run and its eyes go small.
## - a master (the institute's wizard): tall and narrow, a pale floor-length gown with a pink hem
##   that glides rather than walks, a short mantle over the shoulders, and a great pink hat, wide
##   brimmed, its tall point trailing behind. Its orb floats at its back, pink with the mark of the
##   spell it has mastered (RisoGlyph) in paper; winding up, its arm comes up and the orb goes to its
##   hand. Its health is pink pips whirling round it like motes (MoteArt), hidden by it as they pass
##   behind, and the relic it carries hangs over its hat.
## - a proctor: a brown trapezium of a gown, narrow at the shoulders and broad at the floor, with a
##   paper sash across it, under a flat board of a cap wider than its shoulders with a pink tassel.
##   It marches, rocking from side to side, a staff taller than itself in its hand, headed with a
##   pink ring;
##   the staff lifts and pink links flash to those it shields.
## - a librarian: low and hunched forward, a pale tan hump with a bun at the back of its head, big
##   round paper spectacles and a closed book held before it. It shuffles, nodding over its book.
##   Round it the faint blue ring of its hush, rippling while it is up and swelling before it rises.
## - an instructor (a classroom's master, Scholar.instructor) teaching ferry stands on a raft (blue
##   planks, night under); projecting itself, PROJECTED_MOTES paper twinkles circle it.
##
## How it is printed, cheaply: each kind's figure is drawn once, at rest (a RigSheet, shared by every
## scholar of the kind), as a few layers, one per ink: everything it covers cleared to paper, then
## its blue, its pink and its night, each a single print whose shapes carry their own cover, then
## its paper details, and its eyes in pink while it is turned. A figure standing is five prints (a master nine, with its pips),
## where the figures before these took about thirty. Nothing is built again as it moves: every
## part is placed by the canvas's rig (InkCanvas.rig), and each layer is one shape for the whole
## figure, whose points say which part they belong to (RigSheet.code). Since a layer cannot hide what
## another has printed, the figures are designed for it: paper parts lie behind inked ones, darker
## parts in front of paler ones, and where two parts of one ink cross (a sleeve over a gown) the
## overprint is the sleeve's shade.

## The parts of a figure that move (its joints): each is placed every print (_pose), and each of a
## sheet's parts is carried by one, or by two blended along its height (cloth). After COUNT come a
## master's pips, two joints each (the pip behind the figure, and in front).
enum J {BODY, UP, HEM, HEAD, TIP, ARM, HELD, BOOT_A, BOOT_B, ORB, HALO, RING_A, RING_B, RING_C, WASH, COUNT}

## How many paper twinkles circle a projected instructor.
const PROJECTED_MOTES: int = 6
## A master's health pips (_pips): how far round it they whirl (px across, and up and down as they
## pass in front and behind), round its middle PIP_MIDDLE px up from its feet, the ring tipped by
## PIP_TILT (radians); how fast (radians a second); each pip's reach (px), and how far it bobs
## (px). No more than PIPS_MAX are shown (each takes two of the rig's bones).
const PIP_ORBIT: Vector2 = Vector2(52.0, 16.0)
const PIP_MIDDLE: float = 44.0
const PIP_TILT: float = -0.2
const PIP_WHIRL: float = 1.3
const PIP_SIZE: float = 10.0
const PIP_BOB: float = 3.0
const PIPS_MAX: int = 34
## How each kind walks: px walked a step (`stride`), how high it bobs on each (`bob`, px), how far
## its hem swings (`sway`, px), how far its feet reach and lift (`step`, `lift`, px), how much it
## rocks from foot to foot (`rock`, radians) and nods (`nod`, radians).
const GAIT: Dictionary = {
	&"student": {"stride": 44.0, "bob": 4.0, "sway": 3.0, "step": 6.0, "lift": 4.0, "rock": 0.0, "nod": 0.0},
	&"master": {"stride": 90.0, "bob": 0.8, "sway": 4.5, "step": 0.0, "lift": 0.0, "rock": 0.0, "nod": 0.02},
	&"proctor": {"stride": 64.0, "bob": 1.5, "sway": 1.2, "step": 7.0, "lift": 3.5, "rock": 0.04, "nod": 0.0},
	&"librarian": {"stride": 36.0, "bob": 1.2, "sway": 2.0, "step": 0.0, "lift": 0.0, "rock": 0.015, "nod": 0.09},
}
## The middle of each kind's body, px over its feet (a shield round it centres there), and the top
## of its head (its stun stars and a master's relic hang over it).
const MIDDLE: Dictionary = {&"student": 30.0, &"master": 50.0, &"proctor": 40.0, &"librarian": 36.0}
const CROWN: Dictionary = {&"student": Vector2(0, -66), &"master": Vector2(-4, -144), &"proctor": Vector2(2, -102), &"librarian": Vector2(0, -82)}
## What turns: the neck each kind nods about, what its hat's point, scarf's tail or tassel swings
## from, and the shoulder its arm is raised about (px, at rest).
const NECK: Dictionary = {&"student": Vector2(0, -36), &"master": Vector2(0, -82), &"proctor": Vector2(0, -68), &"librarian": Vector2(6, -42)}
const SWING: Dictionary = {&"student": Vector2(-12, -36), &"master": Vector2(0, -104), &"proctor": Vector2(2, -92), &"librarian": Vector2(-8, -64)}
const SHOULDER: Vector2 = Vector2(6, -74)
## A master's hand at rest (its orb goes to it as it winds up), and how far its arm comes up
## (radians).
const HAND: Vector2 = Vector2(13, -47)
const ARM_RAISE: float = 1.5
## The spell's orb: where it floats at rest by kind (px), where a student's goes as it winds up,
## how big it is (px) and how far it bobs; its halo's reach in orbs, and how much of its ink shows.
const ORB_AT: Dictionary = {&"student": Vector2(22, -50), &"master": Vector2(-28, -76)}
const ORB_CAST: Vector2 = Vector2(29, -40)
const ORB_R: Dictionary = {&"student": 7.5, &"master": 13.0}
const ORB_BOB: float = 2.5
const HALO: float = 1.6
const HALO_INK: float = 0.3
## How much more of the dark under a halo is lifted than pink is laid, so it glows on dark wood.
const HALO_CLEARS: float = 2.0
## A proctor's staff: how far it lifts (px) as it shields those round it, and its head (px, at rest).
const STAFF_LIFT: float = 10.0
const STAFF_HEAD: Vector2 = Vector2(36, -124)
## How far into the top of the floor a figure stands (px), so no gap shows under it where the
## floor's edge prints soft.
const SINK: float = 3.0
## The medallion of a relic a master carries (_relic_mark): its radius, and how far over its hat.
const RELIC_R: float = 15.0
const RELIC_RISE: float = 30.0
## A librarian's hush (_hush): how much ink its ring at its reach prints while the hush is down, and
## how long the hush takes to fade as it falls (seconds); how wide its rings are (px).
const HUSH_DOWN: float = 0.12
const HUSH_FADE: float = 0.35
const HUSH_RING: float = 2.5
## Cleared under a figure so its inks print true over whatever is behind, and under its paper
## details.
const UNDER: Array[int] = [RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE]
const PAPER: Array[int] = [RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK]
## Lifted from under an orb's halo, which is laid over whatever is there.
const UNDER_HALO: Array[int] = [RisoPrint.NIGHT, RisoPrint.BLUE]
## How much bigger a spell's mark (RisoGlyph, about 24 px from its middle to its edge) is drawn
## than a master's orb is across: the orb's radius over this.
const GLYPH: float = 32.0
## How far round a figure its parts may move from where they rest (px, from its feet), and how
## far a librarian's hush reaches (RigSheet.close).
const REACH: Rect2 = Rect2(-80, -170, 160, 200)
const FAR: Rect2 = Rect2(-450, -450, 900, 900)

## Eased: how much it is walking (0 to 1), its lean, and how far a master's arm is raised.
var walk: float = 0.0
var lean: float = 0.0
var raise: float = 0.0
## The sheets drawn so far, by kind (and a master's by its spell too).
static var _sheets: Dictionary = {}
## Where each joint is this print (J, then the pips').
var _joints: Array[Transform2D] = []
## How much ink a librarian's hush prints this print: its rings, and its wash (_hush).
var _hush_ink: Vector2 = Vector2.ZERO
## A joint shrunk to nothing: what it carries is not seen.
const GONE: Transform2D = Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)


var scholar: Scholar:
	get:
		return host as Scholar


func _ready() -> void:
	super()
	ink.rig()
	ink.keeps_shapes = true
	_joints.resize(J.COUNT + 2 * PIPS_MAX)


## A shield round it centres on its body, not its feet.
func guard_center() -> Vector2:
	if host == null:
		return global_position
	return host.global_position + Vector2(0, _feet() - float(MIDDLE.get(scholar.kind, 36.0)))


## Where its feet are (px below where it stands): the bottom of its body, so it rises and falls
## through a hop up a step as its body does. (The floor of the cell it stands in, as most props are
## drawn on, held it on the floor it left until it was a cell up, then lifted it there at once, so
## it seemed to blink up the step rather than jump it.)
func _feet() -> float:
	var shape: CollisionShape2D = host.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var box: RectangleShape2D = shape.shape as RectangleShape2D if shape != null else null
	if box == null:
		return _ground()
	return shape.position.y + box.size.y * 0.5 * absf(shape.scale.y)


func _draw_art() -> void:
	var s: Scholar = scholar
	if s == null:
		return
	var kind: StringName = s.kind
	var sheet: RigSheet = ScholarArt.sheet_of(kind, s.ability if kind == &"master" else &"")
	var wind: float = s.wind_up()
	var stunned: bool = s.stunned()
	var scared: bool = s.scatter > 0.0
	var root: Transform2D = _pose(s, kind, wind, stunned, scared)
	# Each part's bones, in the sheet's order, so they are the ones its points name.
	for spec: Vector4 in sheet.slots:
		ink.bone(_joints[int(spec.x)])
		if spec.x != spec.y:
			ink.bone(_joints[int(spec.y)])
	ink.on_chain(sheet.key, sheet.bind)
	if kind == &"master":
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], sheet.of(&"pips_back"))
		ink.ink(RisoPrint.PINK, 0.75, sheet.of(&"pips_back"), false)
	ink.knock(UNDER, sheet.of(&"under"))
	ink.ink_graded(RisoPrint.BLUE, sheet.of(&"blue"), sheet.cover_of(&"blue"), false)
	if sheet.shapes.has(&"pink"):
		ink.ink_graded(RisoPrint.PINK, sheet.of(&"pink"), sheet.cover_of(&"pink"), false)
	ink.ink_graded(RisoPrint.NIGHT, sheet.of(&"night"), sheet.cover_of(&"night"), false)
	ink.knock(PAPER, sheet.of(&"paper_shut" if stunned else (&"paper_small" if scared else &"paper_open")))
	if s.hostile():
		# Turned on the wizard: its eyes wholly pink.
		ink.ink(RisoPrint.PINK, 1.0, sheet.of(&"eyes_shut" if stunned else (&"eyes_small" if scared else &"eyes_open")), false)
	if kind == &"master":
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], sheet.of(&"pips_front"))
		ink.ink(RisoPrint.PINK, 1.0, sheet.of(&"pips_front"), false)
	if kind == &"librarian":
		ink.ink(RisoPrint.BLUE, _hush_ink.x, sheet.of(&"rings"), false)
		ink.ink(RisoPrint.BLUE, _hush_ink.y, sheet.of(&"wash"), false)
	# What comes and goes is printed last, so the prints before it stay as they are.
	if sheet.shapes.has(&"halo"):
		var flare: float = clampf(1.0 - s.since_cast / 0.25, 0.0, 1.0)
		var glow: float = HALO_INK * maxf(maxf(wind, 0.0), flare)
		if glow > 0.0 and not (s.misfired and s.since_cast < 0.4):
			ink.lift_ink(UNDER_HALO, minf(1.0, glow * HALO_CLEARS), sheet.of(&"halo"))
			ink.ink(RisoPrint.PINK, glow, sheet.of(&"halo"), false)
	ink.on_bone(0)
	if s.misfired and s.since_cast < 0.4 and ORB_R.has(kind):
		# Sputtering: a dull, broken orb where the bright one was.
		ink.ink(RisoPrint.NIGHT, 0.6, [RisoShapes.circle(_joints[J.ORB].origin, float(ORB_R[kind]) * 0.8, 14)], false)
	_instructor(s, _feet())
	if kind == &"proctor" and s.since_shield < 0.5:
		_links(s, _joints[J.HELD] * STAFF_HEAD)
	var crown: Vector2 = root * (CROWN.get(kind, Vector2(0, -80)) as Vector2)
	if kind == &"master":
		_relic_mark(crown, s)
	if stunned:
		_stun_mark(crown + Vector2(0, -12))


## Where every joint is this print (_joints), from how it walks (GAIT) and what it is doing; its
## body's own placing comes back (px from its feet, facing right, to the canvas).
func _pose(s: Scholar, kind: StringName, wind: float, stunned: bool, scared: bool) -> Transform2D:
	var gait: Dictionary = GAIT.get(kind, GAIT[&"student"]) as Dictionary
	walk = move_toward(walk, 1.0 if s.walking else 0.0, _dt * 6.0)
	var lean_to: float = (-0.12 if wind >= 0.0 else 0.0) + (0.16 if scared else 0.0) + walk * 0.05
	lean = move_toward(lean, lean_to, _dt * 1.5)
	raise = move_toward(raise, smoothstep(0.0, 0.6, wind) if wind >= 0.0 else 0.0, _dt * 6.0)
	var ph: float = s.walked / float(gait["stride"])
	var stride: float = sin(ph * TAU)
	var rock: float = stride * float(gait["rock"]) * walk
	var root: Transform2D = Transform2D(0.0, Vector2(s.facing, 1.0), 0.0, Vector2(0, _feet() + SINK)) * Transform2D(lean + rock, Vector2.ZERO)
	var bob: float = -absf(sin(ph * PI)) * float(gait["bob"]) * walk + sin(t * 1.6 + phase) * 0.8
	var sway: float = float(gait["sway"])
	var up: Transform2D = root * Transform2D(0.0, Vector2(0, bob))
	_joints[J.BODY] = root
	_joints[J.UP] = up
	_joints[J.HEM] = root * Transform2D(0.0, Vector2((stride - 0.6) * sway * walk + sin(t * 1.3 + phase) * 0.8, 0))
	var nod: float = stride * float(gait["nod"]) * walk + sin(t * 1.1 + phase) * float(gait["nod"]) * 0.5
	var head: Transform2D = up * ScholarArt._turn(nod, NECK.get(kind, Vector2.ZERO) as Vector2)
	_joints[J.HEAD] = head
	# What trails: a hat's point leans back as it walks and comes forward as it winds up; a scarf's
	# tail lifts and flutters; a tassel swings.
	var trail: float = 0.0
	match kind:
		&"student":
			trail = 0.55 * walk + sin(t * 7.0 + phase) * 0.12 * (0.4 + walk)
		&"master":
			trail = -0.2 * walk + sin(t * 1.7 + phase) * 0.07 + 0.3 * raise
		&"proctor":
			trail = sin(t * 2.0 + phase) * 0.1 - stride * 0.15 * walk
	_joints[J.TIP] = head * ScholarArt._turn(trail, SWING.get(kind, Vector2.ZERO) as Vector2)
	var arm: Transform2D = up * ScholarArt._turn(-ARM_RAISE * raise + stride * 0.12 * walk, SHOULDER)
	_joints[J.ARM] = arm
	match kind:
		&"proctor":
			# Its staff is planted, and lifts as it shields.
			_joints[J.HELD] = root * Transform2D(0.0, Vector2(0, -STAFF_LIFT * clampf(1.0 - s.since_shield / 0.5, 0.0, 1.0)))
		_:
			_joints[J.HELD] = up * Transform2D(0.0, Vector2(0, sin(t * 1.1 + phase + 1.0) * 1.2))
	for side: int in range(2):
		var at: float = ph * TAU + (PI if side == 1 else 0.0)
		_joints[J.BOOT_A + side] = root * Transform2D(0.0, Vector2(sin(at) * float(gait["step"]), -maxf(0.0, cos(at)) * float(gait["lift"])) * walk)
	if ORB_R.has(kind):
		# The orb: floating, bobbing; winding up it comes to the hand (a student's, before it) and
		# swells; just cast, its halo flares. It is not mirrored with the figure (its mark reads).
		var rest: Vector2 = (ORB_AT[kind] as Vector2) + Vector2(0, sin(t * 2.2 + phase) * ORB_BOB)
		var cast: Vector2 = ORB_CAST if kind == &"student" else SHOULDER + (HAND - SHOULDER).rotated(-ARM_RAISE * raise) + Vector2(7, -3)
		var size: float = 1.0
		var c: Vector2 = up * rest
		if wind >= 0.0:
			c = up * rest.lerp(cast, smoothstep(0.0, 0.5, wind))
			size += 0.35 * wind
		var flare: float = clampf(1.0 - s.since_cast / 0.25, 0.0, 1.0)
		var sputter: bool = s.misfired and s.since_cast < 0.4
		_joints[J.ORB] = Transform2D(Vector2.ZERO, Vector2.ZERO, c) if sputter else Transform2D(0.0, Vector2(size, size), 0.0, c)
		_joints[J.HALO] = Transform2D(0.0, Vector2(size, size) * (1.0 + flare / HALO), 0.0, c)
	if kind == &"master":
		_pips(root, s)
	if kind == &"librarian":
		_hush_ink = _hush(s)
	return root


## A turn of `a` radians about `pivot`.
static func _turn(a: float, pivot: Vector2) -> Transform2D:
	return Transform2D(a, pivot - pivot.rotated(a))


## A master's health as pips whirling round it like motes (see the class description): one a point
## of health, spaced round for its full health, so a pip lost leaves a gap in the ring. Each pip is
## drawn twice at rest, behind the figure (printed before it, a shade fainter, so the body hides it)
## and in front; of the two, the one on the other side of the ring is shrunk to nothing.
func _pips(root: Transform2D, s: Scholar) -> void:
	var wound: Wound = s.get_node_or_null("Wound") as Wound
	var hp: int = mini(wound.hp, PIPS_MAX) if wound != null else 0
	var full: int = clampi(hp, int(Scholar.HP[&"master"]), PIPS_MAX)
	var middle: Vector2 = root * Vector2(0, -PIP_MIDDLE)
	for i: int in range(PIPS_MAX):
		var back: int = J.COUNT + 2 * i
		_joints[back] = GONE
		_joints[back + 1] = GONE
		if i >= hp:
			continue
		var a: float = t * PIP_WHIRL + phase + TAU * float(i) / float(full)
		var depth: float = sin(a)
		var at: Vector2 = middle + Vector2(cos(a) * PIP_ORBIT.x, depth * PIP_ORBIT.y).rotated(PIP_TILT) + Vector2(0, sin(t * 3.0 + phase + float(i) * 1.7) * PIP_BOB)
		var size: float = 0.85 + 0.15 * depth
		_joints[back + (0 if depth < 0.0 else 1)] = Transform2D(sin(t * 1.7 + phase + float(i)) * 0.45, Vector2(size, size), 0.0, at)


## A librarian's hush: a faint blue ring at its reach, with two ripples running in to it.
## It pulses (Scholar.hush_up): down, only a faint ring at its reach (HUSH_DOWN); swelling, a ring
## closing in on its reach, darker as it comes; up, the ring and ripples over a faint blue wash; and
## as it falls, the wash and ripples fading over HUSH_FADE seconds. The rings are drawn once, at
## its reach, and sized by their joints, which are placed here; how much ink the rings and the wash
## print comes back (x, y).
func _hush(s: Scholar) -> Vector2:
	var c: Vector2 = to_local(s.global_position + Vector2(0, -Scholar.AIM))
	var into: float = s.hush_t - (Scholar.HUSH_EVERY - Scholar.HUSH_ON)
	var up: float = 1.0 if s.hush_up() else (clampf(1.0 - s.hush_t / HUSH_FADE, 0.0, 1.0) if s.hush_t >= 0.0 else 0.0)
	var cover: float = 0.35 * up
	var sizes: Array[float] = [1.0, 0.0, 0.0]
	if up <= 0.0:
		var swell: float = s.hush_swell()
		sizes[0] = 1.0 + 0.3 * (1.0 - swell) if swell > 0.0 else 1.0
		cover = HUSH_DOWN + 0.3 * swell
	else:
		for i: int in range(3):
			sizes[i] = 1.0 - 0.35 * fposmod(maxf(into, 0.0) * 0.4 + float(i) / 3.0, 1.0)
	for i: int in range(3):
		_joints[J.RING_A + i] = Transform2D(0.0, Vector2(sizes[i], sizes[i]), 0.0, c)
	_joints[J.WASH] = Transform2D(0.0, c)
	return Vector2(cover, 0.06 * up)


## An instructor's marks (see the class description): a raft at its feet `g` while it ferries, paper
## twinkles round it while it is projected.
func _instructor(s: Scholar, g: float) -> void:
	if s.move == &"":
		return
	if s.move == &"ferry":
		var raft: Array[PackedVector2Array] = []
		for i: int in range(4):
			raft.append(RisoShapes.rrect(-46.0 + float(i) * 23.5, g - 2.0, 21.0, 12.0, 3.0))
		ink.knock(UNDER, raft)
		ink.ink(RisoPrint.BLUE, 1.0, raft)
		ink.ink(RisoPrint.NIGHT, 0.5, [RisoShapes.rrect(-48.0, g + 6.0, 96.0, 6.0, 3.0)], false)
	if s.projected > 0.0:
		var motes: Array[PackedVector2Array] = []
		for k: int in range(PROJECTED_MOTES):
			var a: float = TAU * float(k) / float(PROJECTED_MOTES) + t * 2.4
			motes.append(Transform2D(t * 3.0 + float(k), Vector2(0, g - 60.0) + Vector2(cos(a) * 58.0, sin(a) * 78.0)) * RisoShapes.sparkle(Vector2.ZERO, 7.0))
		ink.lift_ink(RisoPrint.ALL_PLATES, 1.0, motes)


## A proctor shielding those round it: faint pink links flash from its staff's head (`from`) to them.
func _links(s: Scholar, from: Vector2) -> void:
	var u: float = 1.0 - s.since_shield / 0.5
	var links: Array[PackedVector2Array] = []
	for node: Node in s.get_tree().get_nodes_in_group(&"scholar"):
		var o: Scholar = node as Scholar
		if o == null or o == s or Shield.of(o) == null or o.global_position.distance_to(s.global_position) > Scholar.SHIELD_REACH:
			continue
		links.append(RisoShapes.strand(from, to_local(o.global_position + Vector2(0, -40)), 3.0))
	ink.ink(RisoPrint.PINK, 0.6 * u, links)


## The relic a master carries (Scholar.relic), over its hat at `c`: a small medallion as a relic's
## own (RelicArt), an accent ring round a paper disc with the move's mark in night, bobbing.
func _relic_mark(c: Vector2, s: Scholar) -> void:
	if s.relic == &"":
		return
	var at: Vector2 = c + Vector2(0, -RELIC_RISE + sin(t * 2.0 + phase) * 2.0)
	var disc: PackedVector2Array = RisoShapes.circle(at, RELIC_R * 0.82, 24)
	ink.knock(UNDER, [RisoShapes.circle(at, RELIC_R, 24)])
	ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.circle(at, RELIC_R, 24)])
	ink.knock(UNDER, [disc])
	var mark: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in RisoGlyph.of(s.relic, Vector2.ZERO, t):
		mark.append(Transform2D(0.0, Vector2(RELIC_R / 36.0, RELIC_R / 36.0), 0.0, at) * poly)
	ink.ink(RisoPrint.NIGHT, 1.0, mark, false)


# ------------------------------------------------------------------ the figures at rest

## The sheet of a kind of scholar (a master's with the mark of spell `ability` on its orb), drawn
## the first time it is asked for.
static func sheet_of(kind: StringName, ability: StringName = &"") -> RigSheet:
	var id: StringName = kind if ability == &"" else StringName(String(kind) + " " + String(ability))
	if _sheets.has(id):
		return _sheets[id]
	var sh: RigSheet = RigSheet.new()
	# Every sheet's first part is the body's own, which the pegs are bound to.
	sh.slot(J.BODY)
	var wide: Array[StringName] = []
	match kind:
		&"master":
			_master(sh, ability)
		&"proctor":
			_proctor(sh)
		&"librarian":
			_librarian(sh)
			wide = [&"rings", &"wash"]
		_:
			_student(sh)
	sh.close(REACH, wide, FAR)
	_sheets[id] = sh
	return sh


## A closed, rounded shape through the points `flat` names (x, y, x, y...).
static func _curve(flat: Array[float], seg: int = 4) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(0, flat.size() - 1, 2):
		pts.append(Vector2(flat[i], flat[i + 1]))
	return RisoShapes.smooth(pts, seg)


## A solid part of part `part`: cleared to paper under it, then `blue`, `pink` and `night` of each
## ink (none of all three: bare paper).
static func _solid(sh: RigSheet, part: int, poly: PackedVector2Array, blue: float, pink: float = 0.0, night: float = 0.0) -> void:
	sh.add(&"under", part, poly)
	if blue > 0.0:
		sh.add(&"blue", part, poly, blue)
	if pink > 0.0:
		sh.add(&"pink", part, poly, pink)
	if night > 0.0:
		sh.add(&"night", part, poly, night)


## A paper detail over the inks, whatever the eyes are doing.
static func _paper(sh: RigSheet, part: int, poly: PackedVector2Array) -> void:
	for layer: StringName in [&"paper_open", &"paper_shut", &"paper_small"]:
		sh.add(layer, part, poly)


## A face: a dark hollow `hollow` on part `face`, and two flat paper eyes at `a` and `b`, `rx` by
## `ry`, open, shut to slits (stunned) or small (scared). Each is kept on a layer of its own too
## (eyes_open, eyes_shut, eyes_small), printed in pink over the paper while it is turned.
static func _face(sh: RigSheet, face: int, hollow: PackedVector2Array, a: Vector2, b: Vector2, rx: float, ry: float) -> void:
	_solid(sh, face, hollow, 1.0, 0.0, 1.0)
	for c: Vector2 in [a, b]:
		var shapes: Dictionary = {
			&"open": RisoShapes.ellipse(c, rx, ry, 12),
			&"shut": RisoShapes.rrect(c.x - rx, c.y - 0.7, rx * 2.0, 1.4, 0.6),
			&"small": RisoShapes.ellipse(c, rx * 0.55, ry * 0.55, 10),
		}
		for state: StringName in shapes:
			sh.add(StringName("paper_" + String(state)), face, shapes[state] as PackedVector2Array)
			sh.add(StringName("eyes_" + String(state)), face, shapes[state] as PackedVector2Array)


## A spell's orb `r` across on parts of its own (drawn about its own middle, which its joints
## place): a pink ball, the halo round it a ring that only meets it, and on it a paper gleam, or
## the mark of spell `ability`.
static func _orb(sh: RigSheet, r: float, ability: StringName) -> void:
	var orb: int = sh.slot(J.ORB)
	var halo: int = sh.slot(J.HALO)
	var core: PackedVector2Array = RisoShapes.circle(Vector2.ZERO, r, 18)
	_solid(sh, orb, core, 0.0, 1.0)
	for piece: PackedVector2Array in RisoShapes.ring(Vector2.ZERO, r, r * HALO, 24):
		sh.add(&"halo", halo, piece)
	if ability == &"":
		_paper(sh, orb, RisoShapes.circle(Vector2(-0.35, -0.35) * r, 0.36 * r, 10))
		return
	# Kept on the orb: a mark that reaches past it (a slash's blade) is cut to its edge.
	for poly: PackedVector2Array in RisoGlyph.of(ability, Vector2.ZERO, 0.0):
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(Transform2D(0.0, Vector2(r / GLYPH, r / GLYPH), 0.0, Vector2.ZERO) * poly, core):
			_paper(sh, orb, piece)


## A student (see the class description).
static func _student(sh: RigSheet) -> void:
	var cloak: int = sh.slot(J.UP, J.HEM, -34.0, -9.0)
	var face: int = sh.slot(J.HEAD)
	var tail: int = sh.slot(J.TIP)
	# Two paper legs, which the cloak's ink hides the tops of.
	_solid(sh, sh.slot(J.BOOT_A), RisoShapes.rrect(-10.0, -13.0, 8.0, 13.0, 3.0), 0.0)
	_solid(sh, sh.slot(J.BOOT_B), RisoShapes.rrect(2.0, -13.0, 8.0, 13.0, 3.0), 0.0)
	# The scarf's tail, paper, out from behind the cloak.
	_solid(sh, tail, _curve([-10, -39, -25, -37, -31, -30, -24, -30, -10, -32]), 0.0)
	_solid(sh, cloak, _curve([0, -61, 9, -58, 14, -49, 13, -38, 19, -22, 20, -11, 10, -8, 0, -9, -10, -8, -20, -11, -19, -22, -13, -38, -14, -49, -9, -58]), 0.6, 0.85)
	_face(sh, face, RisoShapes.ellipse(Vector2(3, -47), 8.5, 7.5, 20), Vector2(0.5, -47), Vector2(7, -47), 2.4, 2.7)
	_paper(sh, cloak, _curve([-13, -39, 0, -36.5, 13, -39, 13, -35, 0, -32, -13, -35], 3))
	_orb(sh, float(ORB_R[&"student"]), &"")


## A master, the mark of spell `ability` on its orb (see the class description).
static func _master(sh: RigSheet, ability: StringName) -> void:
	var gown: int = sh.slot(J.UP, J.HEM, -58.0, -1.0)
	var mantle: int = sh.slot(J.UP)
	var face: int = sh.slot(J.HEAD)
	var hat: int = sh.slot(J.HEAD, J.TIP, -106.0, -138.0)
	var arm: int = sh.slot(J.ARM)
	var pips: Array[int] = []
	for i: int in range(PIPS_MAX):
		pips.append(sh.slot(J.COUNT + 2 * i))
		sh.slot(J.COUNT + 2 * i + 1)
	# The gown is bare paper, the mantle and sleeve over it brown.
	_solid(sh, gown, _curve([-7, -82, -11, -76, -15, -50, -20, -24, -26, -4, -24, 0, -9, -1.5, 0, 0, 9, -1.5, 24, 0, 26, -4, 20, -24, 15, -50, 11, -76, 7, -82]), 0.0)
	sh.add(&"pink", gown, _curve([-25.5, -9, -9, -10.5, 0, -9, 9, -10.5, 25.5, -9, 24, 0, 9, -1.5, 0, 0, -9, -1.5, -24, 0], 2), 1.0)
	_solid(sh, mantle, _curve([-5, -85, -16, -79, -21, -64, -10, -60, 0, -63, 10, -60, 21, -64, 16, -79, 5, -85]), 0.6)
	_solid(sh, arm, _curve([3, -78, 10, -77, 16, -52, 13, -45, 8, -46, 5, -62]), 0.6)
	_face(sh, face, RisoShapes.ellipse(Vector2(2, -90), 9.5, 8.0, 20), Vector2(-1, -89.5), Vector2(6.5, -89.5), 2.6, 2.8)
	# The hat: a wide brim and a tall point, pink, with a paper band.
	_solid(sh, hat, RisoShapes.ellipse(Vector2(0.5, -98), 28.0, 5.0, 28), 0.0, 1.0)
	_solid(sh, hat, _curve([-13.5, -99, -9, -116, -8, -130, -6, -139, -3, -130, 5, -116, 13.5, -99, 0, -96]), 0.0, 1.0)
	_paper(sh, hat, _curve([-12.5, -103.5, 0, -102, 12.5, -103.5, 11, -109.5, 0, -108, -11, -109.5], 2))
	_orb(sh, float(ORB_R[&"master"]), ability)
	var pip: PackedVector2Array = RisoShapes.sparkle(Vector2.ZERO, PIP_SIZE)
	for i: int in range(PIPS_MAX):
		sh.add(&"pips_back", pips[i], pip)
		sh.add(&"pips_front", pips[i] + 1, pip)


## A proctor (see the class description).
static func _proctor(sh: RigSheet) -> void:
	var gown: int = sh.slot(J.UP, J.HEM, -50.0, 0.0)
	var chest: int = sh.slot(J.UP)
	var face: int = sh.slot(J.HEAD)
	var tassel: int = sh.slot(J.TIP)
	var staff: int = sh.slot(J.HELD)
	_solid(sh, staff, RisoShapes.rrect(STAFF_HEAD.x - 2.0, STAFF_HEAD.y + 6.0, 4.0, -STAFF_HEAD.y - 6.0, 1.5), 1.0)
	for piece: PackedVector2Array in RisoShapes.ring(STAFF_HEAD, 5.0, 9.5, 20):
		_solid(sh, staff, piece, 0.0, 1.0)
	# A trapezium: narrow at the shoulders, broad at the floor.
	_solid(sh, gown, _curve([-13, -67, -17, -60, -24, -32, -31, -5, -30, 0, 30, 0, 31, -5, 24, -32, 17, -60, 13, -67, 0, -68], 3), 1.0)
	_solid(sh, chest, _curve([6, -62, 15, -64, 39, -48, 36, -41, 30, -42, 8, -52]), 1.0)
	_paper(sh, gown, PackedVector2Array([Vector2(-18, -54), Vector2(-12, -65), Vector2(24, -29), Vector2(28, -11)]))
	_face(sh, face, RisoShapes.rrect(-8.0, -84.0, 20.0, 18.0, 6.0), Vector2(0, -75), Vector2(8, -75), 2.8, 1.9)
	# The cap: a band round the head and a flat board over it.
	_solid(sh, face, RisoShapes.rrect(-10.0, -90.0, 24.0, 8.0, 3.0), 1.0)
	_solid(sh, face, PackedVector2Array([Vector2(-31, -92), Vector2(2, -98.5), Vector2(35, -92), Vector2(2, -86)]), 1.0, 0.0, 0.4)
	_solid(sh, tassel, PackedVector2Array([Vector2(2, -93.5), Vector2(25, -89.5), Vector2(27, -73), Vector2(21, -73), Vector2(21, -86), Vector2(2, -90)]), 0.0, 1.0)


## A librarian (see the class description), and its hush's rings at its reach.
static func _librarian(sh: RigSheet) -> void:
	var hump: int = sh.slot(J.UP, J.HEM, -40.0, 0.0)
	var face: int = sh.slot(J.HEAD)
	var bun: int = sh.slot(J.TIP)
	var book: int = sh.slot(J.HELD)
	_solid(sh, hump, _curve([-20, 0, -24, -18, -21, -44, -10, -62, 4, -68, 16, -62, 21, -50, 18, -40, 15, -30, 19, -10, 18, 0, 0, 0]), 0.5)
	_solid(sh, bun, RisoShapes.circle(Vector2(-9, -70), 7.5, 16), 1.0)
	_solid(sh, book, _curve([8, -45, 17, -44, 27, -33, 23, -28, 10, -34]), 0.5)
	_face(sh, face, RisoShapes.ellipse(Vector2(9, -52), 10.0, 9.0, 20), Vector2(4.5, -52), Vector2(14, -52), 4.4, 4.4)
	# The book, closed: a dark cover, its pages' edge a paper strip along its front and foot, and a
	# paper label on the cover.
	var c: Vector2 = Vector2(27, -34)
	_solid(sh, book, RisoShapes.rrect(c.x - 9.0, c.y - 9.0, 18.0, 17.0, 2.0), 1.0, 0.0, 1.0)
	_paper(sh, book, PackedVector2Array([c + Vector2(6, -7.5), c + Vector2(8, -7.5), c + Vector2(8, 6.5), c + Vector2(-7.5, 6.5), c + Vector2(-7.5, 4.5), c + Vector2(6, 4.5)]))
	_paper(sh, book, RisoShapes.rrect(c.x - 5.5, c.y - 5.5, 8.0, 3.0, 0.8))
	# The hush: three rings and a wash, the sheet's last four parts (_hush).
	for joint: int in [J.RING_A, J.RING_B, J.RING_C]:
		var ring: int = sh.slot(joint)
		for piece: PackedVector2Array in RisoShapes.ring(Vector2.ZERO, Scholar.HUSH - HUSH_RING, Scholar.HUSH, 48):
			sh.add(&"rings", ring, piece)
	sh.add(&"wash", sh.slot(J.WASH), RisoShapes.circle(Vector2.ZERO, Scholar.HUSH, 48))
