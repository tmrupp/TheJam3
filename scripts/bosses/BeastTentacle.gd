class_name BeastTentacle
extends Node2D
## One of the eldritch beast's striking tentacles (Beast): idle until the beast strikes with it
## (strike), then it shows where it will come (WARN: a pink swelling in the floor where it will burst
## up, or a coil at the beast's flank before it lashes along the floor), shoots out to its full
## reach (GROW), holds there writhing (HOLD) and pulls back (PULL). Only while it is out does it
## hurt (its HitBox, as long as it is). Its touch is the beast's: a parry catches it as a blow at the
## beast (Parry), stunning the beast, and while the beast is stunned it whips back out of sight.
## Printed by itself: pink flesh with paper suckers, tapering to its tip. Nothing here draws from
## any RNG.

const HIT_BOX: PackedScene = preload("res://prefabs/hit_box.tscn")
## Its cadence (seconds): showing where it will come, shooting out, holding, pulling back.
const WARN: float = 0.75
const GROW: float = 0.2
const HOLD: float = 0.7
const PULL: float = 0.4
const PERIOD: float = WARN + GROW + HOLD + PULL
## How much of its drawn thickness its touch takes, at its base (it tapers to a share of it at its
## tip, TIP).
const TOUCH_SHARE: float = 0.8
const TIP: float = 0.3
## Shorter than this (px) it does not hurt.
const TOUCH_MIN: float = 24.0
## How fast it whips back while the beast is stunned (its full length a second, times).
const RECOIL_RATE: float = 6.0
## How far it writhes to either side of its line (px), and how many points it is drawn through.
const WRITHE: float = 12.0
const POINTS: int = 12

## The beast it belongs to, the way it shoots out, its full reach (px) and its thickness (px).
var beast: Beast
var way: Vector2 = Vector2.UP
var full: float = 300.0
var thick: float = 50.0
## Seconds into its strike (-1 while idle), and how long it is now (px).
var t: float = -1.0
var length: float = 0.0
var hit_box: HitBox
var ink: InkCanvas
var _box: RectangleShape2D = RectangleShape2D.new()
## Its own clock, for the writhing.
var _clock: float = 0.0


func _init(of: Beast) -> void:
	beast = of
	hit_box = HIT_BOX.instantiate() as HitBox
	hit_box.name = "HitBox"
	add_child(hit_box)
	# Its own shape: the prefab's is shared by every hit box.
	(hit_box.get_node("CollisionShape2D") as CollisionShape2D).shape = _box
	# Its touch is the beast's, so a parry strikes and stuns the beast.
	(hit_box.get_node("Damager") as Damager).attacker = of
	_box.size = Vector2(1.0, thick)


func _ready() -> void:
	z_index = 1
	ink = InkCanvas.new()
	add_child(ink)


## Strike from `root` (world), shooting out the way `out` points, `reach` px long and `wide` px thick.
func strike(root: Vector2, out: Vector2, reach: float, wide: float) -> void:
	global_position = root
	way = out.normalized()
	full = reach
	thick = wide
	hit_box.rotation = way.angle()
	t = 0.0
	length = 0.0


## Whether it is striking now (from its warning to pulling back in).
func busy() -> bool:
	return t >= 0.0


## Stop at once (the beast is dying).
func stop() -> void:
	t = -1.0
	length = 0.0


## Where it is in its strike: &"idle", &"warn", &"grow", &"hold" or &"pull", and how far through it
## (0 to 1).
func phase() -> Array:
	if t < 0.0:
		return [&"idle", 0.0]
	var u: float = t
	for part: Array in [[&"warn", WARN], [&"grow", GROW], [&"hold", HOLD]]:
		if u < float(part[1]):
			return [part[0], u / float(part[1])]
		u -= float(part[1])
	return [&"pull", clampf(u / PULL, 0.0, 1.0)]


## Whether it is whipped back by the beast's stun (a parry).
func recoiled() -> bool:
	return beast != null and beast.stunner.stunned()


## Whether it is out far enough to hurt.
func hurts() -> bool:
	return busy() and not recoiled() and length >= TOUCH_MIN and beast != null and not beast.dying()


func _physics_process(delta: float) -> void:
	_clock += delta
	if t >= 0.0:
		if recoiled():
			length = move_toward(length, 0.0, full * RECOIL_RATE * delta)
			if length <= 0.0:
				t = -1.0
		else:
			# A harder preset strikes faster (Difficulty.haste).
			t += delta * Difficulty.haste()
			var state: Array = phase()
			var u: float = state[1]
			match state[0]:
				&"warn":
					length = 0.0
				&"grow":
					length = full * (1.0 - (1.0 - u) * (1.0 - u))
				&"hold":
					length = full
				&"pull":
					length = full * (1.0 - u * u)
			if t >= PERIOD:
				t = -1.0
				length = 0.0
	_box.size = Vector2(maxf(length, 1.0), thick * TOUCH_SHARE)
	(hit_box.get_node("CollisionShape2D") as CollisionShape2D).position = Vector2(length * 0.5, 0.0)
	var off: bool = not hurts()
	if hit_box.collision != null and hit_box.collision.disabled != off:
		hit_box.collision.set_deferred("disabled", off)


## A pink swelling where it will come while it warns; then the tentacle itself, pink with paper
## suckers down its middle, writhing as it holds, tapering to its tip.
func _process(_delta: float) -> void:
	if ink == null:
		return
	ink.begin()
	var state: Array = phase()
	if state[0] == &"warn":
		var u: float = state[1]
		var side: Vector2 = way.orthogonal()
		# A swelling: flat along the ground it comes out of, growing and throbbing.
		var swell: PackedVector2Array = RisoShapes.ellipse(Vector2.ZERO, thick * (0.5 + 0.7 * u), thick * (0.15 + 0.25 * u) * (1.0 + 0.15 * sin(_clock * 30.0)), 18, side.angle())
		ink.ink(RisoPrint.PINK, 0.35 + 0.5 * u, [swell])
		var bits: Array[PackedVector2Array] = []
		for i: int in range(4):
			var k: float = (float(i) - 1.5) / 1.5
			var at: Vector2 = side * k * thick * 0.7 + way * (6.0 + 22.0 * u * fposmod(_clock * 2.0 + float(i) * 0.37, 1.0))
			bits.append(RisoShapes.circle(at, 3.0 + 2.0 * u, 8))
		ink.ink(RisoPrint.PINK, 0.9, bits)
	elif length > 1.0:
		var side: Vector2 = way.orthogonal()
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in range(POINTS):
			var k: float = float(i) / float(POINTS - 1)
			var bend: float = sin(_clock * 9.0 + k * 5.0) * WRITHE * k
			pts.append(way * length * k + side * bend)
		var body: Array[PackedVector2Array] = RisoDecor.strip(pts, thick, thick * TIP)
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], body)
		ink.ink(RisoPrint.PINK, 1.0, body, false)
		ink.ink(RisoPrint.BLUE, 0.4, body, false)
		# Its suckers: paper dots down it, smaller toward the tip.
		var suckers: Array[PackedVector2Array] = []
		for i: int in range(1, POINTS - 2, 2):
			var k: float = float(i) / float(POINTS - 1)
			suckers.append(RisoShapes.circle(pts[i], thick * 0.13 * (1.0 - k * 0.6), 10))
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], suckers)
	ink.finish()
