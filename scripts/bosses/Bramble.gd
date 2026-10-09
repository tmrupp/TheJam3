class_name Bramble
extends Node2D
## The bramble (Bosses.GARDEN_UP): the boss of the garden's way up, fought in its gate level
## (docs/REGIONS_PLAN.md §6). The way up is a tall shaft of rock (BrambleShaft), and the bramble is
## rooted at its head: a knot of bark and thorns filling the head beside the landing the way on
## stands on, so nothing gets past it to the way on. Its roots run down the shaft's walls to:
## - its bulbs (BrambleBulb), BrambleShaft.BULBS.x to BULBS.y of them set in the walls, its weak
##   points: each takes BULB_HP hits from bolts or dashes (any strike wounds them, even one that only
##   stuns), and spits seeds at the wizard that a parry turns back into it;
## - its thorn vines (BrambleVine), rooted in the walls between: they lash out across the shaft and
##   pull back on a cadence, so the climb up the shaft's ledges is a matter of timing. A parried lash
##   recoils and stays back a while. Each vine feeds from the bulb nearest it, and withers for good
##   when that bulb bursts.
## Its health is its bulbs: one accent pip on the knot for each, put out as each bursts. When the
## last bursts the knot tears open and shrivels away (OPEN_TIME), the bramble is slain, and its relic
## waits on the landing beside the way on (MapInfo.boss_slain), whose seal lifts. A lantern death
## brings it back whole, as the level reloads. Nothing here draws from the world RNG: the shaft and
## everything set in it come from the level's layout, and the rest is hashed from its seed.

const HIT_BOX: PackedScene = preload("res://prefabs/hit_box.tscn")
## The hits each bulb takes.
const BULB_HP: int = 3
## How long the knot takes to tear open and shrivel away once the last bulb has burst.
const OPEN_TIME: float = 1.4
## How far past the knot (px) its thorns hurt.
const KNOT_REACH: float = 10.0
## The bark: its covers of blue and night; and the dark mass of the knot the stems twist over (a
## darker green than the rock, darker still than the open shaft). Roots down the walls: how far out of the rock face they
## wave (px), and how thick they are.
const BARK_BLUE: float = 0.9
const BARK_NIGHT: float = 0.55
const KNOT_BLUE: float = 0.75
const KNOT_NIGHT: float = 0.75
const ROOT_SWAY: float = 10.0
const ROOT_WIDTH: float = 16.0
## A bulb: its radius (px) when still, how much it swells as it readies a seed, and how long it
## flashes when struck and its husk's petals fly when it bursts.
const BULB_R: float = 40.0
const BULB_SWELL: float = 0.22
const FLASH_TIME: float = 0.18
const BURST_TIME: float = 0.45
## A vine: its stem's half width at the root and at the tip (px), its thorns' spacing and length.
const STEM_ROOT: float = 16.0
const STEM_TIP: float = 5.0
const THORN_EVERY: float = 26.0
const THORN_LEN: float = 18.0
## How many thick stems twist across the knot, and the salt for the level seed that bends them.
const KNOT_STEMS: int = 6
const KNOT_DEAL: int = 6660

var map_info: MapInfo
## Which boss it is (Bosses).
var boss: StringName = &""
## A cell's size in pixels, and the middle of cell (0, 0).
var cell: float = 64.0
var origin: Vector2 = Vector2.ZERO
## The shaft (BrambleShaft): its inside, and the knot (in pixels), and the relic's place.
var inside: Rect2i = Rect2i()
var knot_rect: Rect2 = Rect2()
var relic_at: Vector2 = Vector2.ZERO
var bulbs: Array[BrambleBulb] = []
var vines: Array[BrambleVine] = []
## The knot's body (it walls off the head of the shaft) and its thorns' touch.
var knot: StaticBody2D
var knot_box: HitBox
## Whether the knot is tearing open (the last bulb burst), how far (0 to 1), and whether it is slain.
var opening: bool = false
var open_u: float = 0.0
var slain: bool = false
var ink: InkCanvas
var t: float = 0.0
var level_seed: int = 0
## The knot's shapes (see _knot_parts), worked out once.
var _knot: Dictionary = {}


func _ready() -> void:
	# Over the terrain with the other things in a level (props, z 2).
	z_index = 2
	ink = InkCanvas.new()
	add_child(ink)


func setup(info: MapInfo, _v: Vector2i, which: Variant) -> void:
	map_info = info
	boss = StringName(which)
	# It spans the whole shaft: never put to sleep with the chunk its cell is in.
	remove_meta(&"cell")
	var tm: TileMap = info.tile_map
	cell = float(tm.tile_set.tile_size.x) * tm.global_scale.x
	origin = info.cell_position(Vector2i.ZERO)
	var w: LevelGen = info.world
	level_seed = w.seed_for_colors
	var shaft: Dictionary = w.shaft
	if shaft.is_empty():
		return
	inside = shaft["inside"]
	relic_at = info.cell_position(shaft["relic"] as Vector2i)
	var k: Rect2i = shaft["knot"]
	knot_rect = Rect2(center(k.position) - Vector2.ONE * cell * 0.5, Vector2(k.size) * cell)
	_grow_knot()
	for b: Array in shaft["bulbs"]:
		var bulb: BrambleBulb = BrambleBulb.new(self, b[0], Vector2(b[1] as Vector2i), BULB_HP)
		bulb.name = "Bulb%d" % bulbs.size()
		add_child(bulb)
		bulb.place(face(b[0], b[1]), level_seed)
		bulbs.append(bulb)
	for v: Array in shaft["vines"]:
		var vine: BrambleVine = BrambleVine.new(self, v[0], Vector2(v[1] as Vector2i))
		vine.name = "Vine%d" % vines.size()
		add_child(vine)
		vine.place(face(v[0], v[1]), cell, level_seed)
		vine.bulb = LevelGen.best_of(bulbs, func(b: BrambleBulb) -> float: return b.global_position.distance_to(vine.global_position)) as BrambleBulb
		vines.append(vine)


## The middle of cell `v`.
func center(v: Vector2i) -> Vector2:
	return origin + Vector2(v) * cell


## The middle of the face of wall cell `wall` toward `out` (into the shaft).
func face(wall: Vector2i, out: Vector2i) -> Vector2:
	return center(wall) + Vector2(out) * cell * 0.5


## The knot: a solid body filling the head of the shaft beside the landing, and the touch of its
## thorns a little past it.
func _grow_knot() -> void:
	knot = StaticBody2D.new()
	knot.name = "Knot"
	# The environment's layer: the wizard stands on it and cannot get past it.
	knot.collision_layer = 4
	knot.collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = knot_rect.size
	shape.shape = rect
	knot.add_child(shape)
	add_child(knot)
	knot.global_position = knot_rect.get_center()
	knot_box = HIT_BOX.instantiate() as HitBox
	knot_box.name = "HitBox"
	var reach: RectangleShape2D = RectangleShape2D.new()
	reach.size = knot_rect.size + Vector2.ONE * KNOT_REACH * 2.0
	(knot_box.get_node("CollisionShape2D") as CollisionShape2D).shape = reach
	knot.add_child(knot_box)


## How many bulbs are left.
func bulbs_left() -> int:
	return bulbs.filter(func(b: BrambleBulb) -> bool: return b.alive).size()


## Bulb `bulb` has burst: the vines it fed wither, and with the last one the knot tears open.
func burst(bulb: BrambleBulb) -> void:
	if not bulb.alive:
		return
	bulb.pop()
	RisoFx.burst(&"gain", bulb.global_position, bulb.way, [RisoPrint.ACCENT, RisoPrint.PINK])
	Wound.shake(12.0, 0.25)
	for vine: BrambleVine in vines:
		if vine.bulb == bulb:
			vine.wither()
	if bulbs_left() == 0:
		_open()


## The last bulb has burst: every vine withers, and the knot tears open; nothing of it hurts now.
func _open() -> void:
	opening = true
	for vine: BrambleVine in vines:
		vine.wither()
	for part: CollisionShape2D in [knot.get_child(0) as CollisionShape2D, knot_box.collision]:
		if part != null:
			part.set_deferred("disabled", true)
	Wound.shake(16.0, 0.5)
	RisoFx.burst(&"hit", knot_rect.get_center(), Vector2.DOWN, [RisoPrint.PINK, RisoPrint.BLUE])


func _physics_process(delta: float) -> void:
	if not opening or slain:
		return
	open_u = minf(1.0, open_u + delta / OPEN_TIME)
	if open_u >= 1.0:
		_die()


## Slain at once (the F7 panel's Slay boss, MapInfo.slay_boss): every bulb bursts, and it dies
## without waiting for the knot to tear open.
func slay() -> void:
	if slain:
		return
	for bulb: BrambleBulb in bulbs:
		burst(bulb)
	_die()


## It is slain: its relic waits on the landing beside the way on, and it is gone.
func _die() -> void:
	slain = true
	if map_info != null:
		map_info.boss_slain(boss, relic_at)
	queue_free()


# ------------------------------------------------------------------ the print

## Its roots down the walls, the vines, the bulbs, and the knot over them all: bark in blue and
## night, thorns and vines in pink (danger), bulbs in accent (its weak points). As the knot tears
## open everything fades.
func _process(delta: float) -> void:
	t += delta
	if ink == null or inside.size == Vector2i.ZERO:
		return
	ink.global_position = Vector2.ZERO
	ink.begin()
	var fade: float = 1.0 - open_u
	_draw_roots(fade)
	for vine: BrambleVine in vines:
		_draw_vine(vine, fade)
	for bulb: BrambleBulb in bulbs:
		_draw_bulb(bulb, fade)
	_draw_knot(fade)
	ink.finish()


## A root of bark creeping down the face of each wall, from the knot to the lowest bulb or vine on
## it, which they grow from.
func _draw_roots(fade: float) -> void:
	var roots: Array[PackedVector2Array] = []
	for side: int in [0, 1]:
		var wall_x: float = center(Vector2i(inside.position.x - 1 if side == 0 else inside.end.x, 0)).x
		var out: float = 1.0 if side == 0 else -1.0
		var low: float = knot_rect.end.y
		for vine: BrambleVine in vines:
			if signf(vine.way.x) == out:
				low = maxf(low, vine.global_position.y)
		for bulb: BrambleBulb in bulbs:
			if signf(bulb.way.x) == out:
				low = maxf(low, bulb.global_position.y)
		var left: PackedVector2Array = PackedVector2Array()
		var right: PackedVector2Array = PackedVector2Array()
		var y: float = knot_rect.position.y + 20.0
		while y <= low + 16.0:
			var k: float = clampf((low + 16.0 - y) / 120.0, 0.25, 1.0)
			var x: float = wall_x + out * (cell * 0.5 + ROOT_SWAY * (0.5 + 0.5 * sin(y * 0.035 + float(side) * 2.0)))
			var w: float = ROOT_WIDTH * k * (0.75 + 0.25 * sin(y * 0.09 + float(side)))
			left.append(Vector2(x - w * 0.5, y))
			right.append(Vector2(x + w * 0.5, y))
			y += 10.0
		right.reverse()
		left.append_array(right)
		if left.size() >= 4:
			roots.append(left)
	ink.lift_ink([RisoPrint.NIGHT], fade, roots)
	ink.ink(RisoPrint.BLUE, BARK_BLUE * fade, roots)
	ink.ink(RisoPrint.NIGHT, 0.3 * fade, roots, false)


## A vine: out, a pink stem tapering from its root with thorns along both edges and a hooked tip,
## writhing; warning, pink shoots poking out of the rock, trembling; resting or recoiled, a dark
## bud at its root; withered, a short dry curl.
func _draw_vine(vine: BrambleVine, fade: float) -> void:
	var root: Vector2 = vine.global_position
	var xf: Transform2D = Transform2D(vine.way.angle(), root)
	if vine.withered and vine.length < 2.0:
		var curl: PackedVector2Array = PackedVector2Array()
		for n: int in range(9):
			var a: float = -0.4 + float(n) * 0.35
			curl.append(Vector2(10.0 + 18.0 * sin(a), -14.0 + 18.0 * cos(a)))
		for n: int in range(8, -1, -1):
			var a: float = -0.4 + float(n) * 0.35
			curl.append(Vector2(10.0 + 12.0 * sin(a), -14.0 + 12.0 * cos(a)))
		ink.lift_ink([RisoPrint.NIGHT], fade, [xf * curl])
		ink.ink(RisoPrint.BLUE, 0.7 * fade, [xf * curl])
		ink.ink(RisoPrint.NIGHT, 0.45 * fade, [xf * curl], false)
		return
	var bud: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(5.0, 0.0), 13.0, 20.0, 14)
	ink.ink(RisoPrint.BLUE, BARK_BLUE * fade, [bud])
	ink.ink(RisoPrint.NIGHT, BARK_NIGHT * fade, [bud], false)
	var state: Array = vine.phase()
	if vine.length < 2.0:
		if state[0] == &"warn" and not vine.recoiled():
			var u: float = state[1]
			var shoots: Array[PackedVector2Array] = []
			for n: int in range(3):
				var ang: float = (float(n) - 1.0) * 0.6 + 0.08 * sin(t * 37.0 + float(n) * 2.0)
				var tip: float = 22.0 + 34.0 * u
				var dir: Vector2 = Vector2.from_angle(ang)
				var side: Vector2 = dir.orthogonal() * 9.0
				shoots.append(xf * PackedVector2Array([side, dir * tip, -side]))
			ink.ink(RisoPrint.PINK, (0.55 + 0.45 * absf(sin(t * 14.0))) * fade, shoots)
		return
	# The stem, writhing, from the rock out to its tip.
	var length: float = vine.length
	var steps: int = maxi(4, ceili(length / 10.0))
	var top: PackedVector2Array = PackedVector2Array()
	var bottom: PackedVector2Array = PackedVector2Array()
	var spine: Array[Vector2] = []
	for n: int in range(steps + 1):
		var x: float = length * float(n) / float(steps)
		var k: float = x / maxf(length, 1.0)
		var y: float = sin(x * 0.04 - t * 9.0) * 9.0 * k
		var half: float = lerpf(STEM_ROOT, STEM_TIP, k)
		spine.append(Vector2(x, y))
		top.append(Vector2(x, y - half))
		bottom.append(Vector2(x, y + half))
	bottom.reverse()
	top.append_array(bottom)
	var thorns: Array[PackedVector2Array] = []
	var along: float = THORN_EVERY * 0.6
	var flip: float = 1.0
	while along < length - 4.0:
		var k: float = along / maxf(length, 1.0)
		var at: Vector2 = Vector2(along, sin(along * 0.04 - t * 9.0) * 9.0 * k)
		var half: float = lerpf(STEM_ROOT, STEM_TIP, k)
		var base: Vector2 = at + Vector2(0, flip * (half - 2.0))
		thorns.append(PackedVector2Array([base + Vector2(-9.0, 0), base + Vector2(5.0, flip * THORN_LEN), base + Vector2(9.0, 0)]))
		flip = -flip
		along += THORN_EVERY * 0.5
	# A hooked tip.
	var end: Vector2 = spine[spine.size() - 1]
	thorns.append(PackedVector2Array([end + Vector2(-7.0, -7.0), end + Vector2(18.0, -4.0), end + Vector2(4.0, 11.0)]))
	var stem: Array[PackedVector2Array] = [xf * top]
	var spikes: Array[PackedVector2Array] = []
	for th: PackedVector2Array in thorns:
		spikes.append(xf * th)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], fade, stem)
	ink.ink(RisoPrint.PINK, 0.8 * fade, stem)
	ink.ink(RisoPrint.NIGHT, 0.2 * fade, stem, false)
	ink.ink(RisoPrint.PINK, fade, spikes)


## A bulb: a swelling teardrop of accent out of the rock face, cupped in bark, a paper gleam on it
## and its hits left as dark dots; it swells as it readies a seed and flashes pink when struck.
## Burst: a shrivelled husk, its petals flying for a moment.
func _draw_bulb(bulb: BrambleBulb, fade: float) -> void:
	var base: Vector2 = bulb.global_position - bulb.way * BrambleBulb.OUT
	var xf: Transform2D = Transform2D(bulb.way.angle(), base)
	var cup: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(7.0, 0.0), 20.0, BULB_R * 0.9, 16)
	if not bulb.alive:
		var since: float = t - bulb.burst_t
		var husk: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(18.0, 0.0), 20.0, 15.0, 14)
		ink.lift_ink([RisoPrint.NIGHT], fade, [cup, husk])
		ink.ink(RisoPrint.BLUE, BARK_BLUE * fade, [cup, husk])
		ink.ink(RisoPrint.NIGHT, 0.6 * fade, [cup], false)
		ink.ink(RisoPrint.NIGHT, 0.35 * fade, [husk], false)
		if since < BURST_TIME:
			var u: float = since / BURST_TIME
			var petals: Array[PackedVector2Array] = []
			for n: int in range(5):
				var dir: Vector2 = Vector2.from_angle((float(n) - 2.0) * 0.55)
				petals.append(xf * RisoShapes.ellipse(Vector2(22.0, 0.0) + dir * (25.0 + 70.0 * u), 13.0 * (1.0 - u), 7.0 * (1.0 - u), 10, dir.angle()))
			ink.ink(RisoPrint.ACCENT, 1.0 - u, petals)
		return
	var swell: float = 1.0 + BULB_SWELL * bulb.charge * bulb.charge + 0.04 * sin(t * 3.0 + float(bulb.cell.y))
	var r: float = BULB_R * swell
	var body: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(BrambleBulb.OUT * swell, 0.0), r * 0.95, r, 22)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], fade, [body])
	ink.ink(RisoPrint.ACCENT, fade, [body])
	var flash: float = clampf(1.0 - (t - bulb.struck_t) / FLASH_TIME, 0.0, 1.0)
	if flash > 0.0:
		ink.ink(RisoPrint.PINK, 0.8 * flash * fade, [body], false)
	# Its gleam, toward the open shaft.
	ink.lift_ink([RisoPrint.ACCENT], 0.7 * fade, [xf * RisoShapes.ellipse(Vector2(BrambleBulb.OUT * swell + r * 0.3, -r * 0.35), r * 0.22, r * 0.14, 10, 0.5)])
	ink.ink(RisoPrint.BLUE, BARK_BLUE * fade, [cup])
	ink.ink(RisoPrint.NIGHT, BARK_NIGHT * fade, [cup], false)
	# Its hits left, as dark dots down its middle.
	var dots: Array[PackedVector2Array] = []
	var n: int = bulb.hits_left()
	for j: int in range(n):
		var off: float = (float(j) - float(n - 1) * 0.5) * r * 0.5
		dots.append(xf * RisoShapes.circle(Vector2(BrambleBulb.OUT * swell + 2.0, off), r * 0.13, 8))
	ink.ink(RisoPrint.NIGHT, 0.85 * fade, dots, false)


## The knot: a dark tangle filling the head of the shaft, of thick stems twisted across one
## another, bristling with pink thorns (longest along its underside), and a row of accent pips on a
## dark knot-hole, one for each bulb (dark once burst). Tearing open, its two halves pull apart
## toward the walls and shrivel.
func _draw_knot(fade: float) -> void:
	var r: Rect2 = knot_rect
	if _knot.is_empty():
		_knot = _knot_parts(r)
	var parts: Dictionary = _knot
	if opening:
		# Each half pulls away toward its side and shrinks there.
		var torn: Dictionary = {}
		for key: String in parts:
			var none: Array[PackedVector2Array] = []
			torn[key] = none
		for side: int in [-1, 1]:
			var half: Rect2 = Rect2(r.position.x + (0.0 if side < 0 else r.size.x * 0.5), r.position.y - 40.0, r.size.x * 0.5, r.size.y + 80.0)
			var anchor: Vector2 = Vector2(r.position.x if side < 0 else r.end.x, r.position.y)
			var shrink: float = 1.0 - 0.6 * open_u
			var move: Transform2D = Transform2D(0.0, anchor + Vector2(float(side) * r.size.x * 0.3 * open_u, 0.0)) * Transform2D(0.0, Vector2.ONE * shrink, 0.0, Vector2.ZERO) * Transform2D(0.0, -anchor)
			var cut: PackedVector2Array = PackedVector2Array([half.position, Vector2(half.end.x, half.position.y), half.end, Vector2(half.position.x, half.end.y)])
			for key: String in parts:
				for poly: PackedVector2Array in parts[key]:
					for piece: PackedVector2Array in Geometry2D.intersect_polygons(poly, cut):
						(torn[key] as Array[PackedVector2Array]).append(move * piece)
		parts = torn
	ink.lift_ink([RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.BLUE, RisoPrint.NIGHT], fade, parts["mass"])
	ink.ink(RisoPrint.BLUE, KNOT_BLUE * fade, parts["mass"], false)
	ink.ink(RisoPrint.NIGHT, KNOT_NIGHT * fade, parts["mass"], false)
	ink.lift_ink([RisoPrint.NIGHT], fade, parts["stems"])
	ink.ink(RisoPrint.BLUE, BARK_BLUE * fade, parts["stems"])
	ink.ink(RisoPrint.NIGHT, 0.1 * fade, parts["stems"], false)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], fade, parts["thorns"])
	ink.ink(RisoPrint.PINK, fade, parts["thorns"])
	if opening:
		return
	# Its health: a pip for each bulb, in a row on a dark knot-hole low on the knot.
	var n: int = bulbs.size()
	var mid: Vector2 = Vector2(r.get_center().x, r.end.y - 46.0)
	var hole: PackedVector2Array = RisoShapes.rrect(mid.x - float(n) * 15.0 - 6.0, mid.y - 17.0, float(n) * 30.0 + 12.0, 34.0, 17.0)
	ink.knock([RisoPrint.BLUE], [hole])
	ink.ink(RisoPrint.NIGHT, 1.0, [hole], false)
	var lit: Array[PackedVector2Array] = []
	var out: Array[PackedVector2Array] = []
	for i: int in range(n):
		var pip: PackedVector2Array = RisoShapes.circle(mid + Vector2((float(i) - float(n - 1) * 0.5) * 30.0, 0.0), 10.0, 14)
		if bulbs[i].alive:
			lit.append(pip)
		else:
			out.append(pip)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], lit)
	ink.ink(RisoPrint.ACCENT, 1.0, lit)
	ink.ink(RisoPrint.BLUE, 0.5, out, false)


## The knot's shapes over rectangle `r`: its dark "mass", the "stems" twisted across it, and the
## "thorns" on them and along its underside. The same every visit (from the level seed).
func _knot_parts(r: Rect2) -> Dictionary:
	var box: PackedVector2Array = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var mass: Array[PackedVector2Array] = [box]
	var stems: Array[PackedVector2Array] = []
	var thorns: Array[PackedVector2Array] = []
	for i: int in range(KNOT_STEMS):
		var h: Callable = func(k: int) -> float: return RisoShapes.hash1(float(level_seed % 7919) * 0.37 + float(i) * 3.1 + float(k) * 1.7 + float(KNOT_DEAL))
		# From one side to the other, slanting up or down, bowed.
		var a: Vector2 = Vector2(r.position.x - 10.0, lerpf(r.position.y, r.end.y, float(h.call(0))))
		var b: Vector2 = Vector2(r.end.x + 10.0, lerpf(r.position.y, r.end.y, float(h.call(1))))
		var bow: Vector2 = (b - a).orthogonal().normalized() * (float(h.call(2)) - 0.5) * r.size.y * 0.6
		var width: float = lerpf(18.0, 30.0, float(h.call(3)))
		var top: PackedVector2Array = PackedVector2Array()
		var low: PackedVector2Array = PackedVector2Array()
		var steps: int = 14
		var flip: float = 1.0 if i % 2 == 0 else -1.0
		for m: int in range(steps + 1):
			var u: float = float(m) / float(steps)
			var at: Vector2 = a.lerp(b, u) + bow * 4.0 * u * (1.0 - u)
			var dir: Vector2 = (b - a + bow * 4.0 * (1.0 - 2.0 * u)).normalized()
			var side: Vector2 = dir.orthogonal() * width * 0.5 * (0.8 + 0.2 * sin(u * 9.0 + float(i)))
			top.append(at + side)
			low.append(at - side)
			# A thorn now and then, on alternate edges.
			if m % 3 == 1 and m < steps:
				flip = -flip
				var base: Vector2 = at + side * flip * 0.9
				var out: Vector2 = dir.orthogonal() * flip
				thorns.append(PackedVector2Array([base - dir * 9.0, base + out * 20.0 + dir * 4.0, base + dir * 9.0]))
		low.reverse()
		top.append_array(low)
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(top, box):
			stems.append(piece)
	thorns = thorns.filter(func(th: PackedVector2Array) -> bool: return r.grow(-4.0).has_point(th[1]))
	# Along its underside, pointing down the shaft.
	var count: int = maxi(3, int(r.size.x / 28.0))
	for n: int in range(count):
		var x: float = lerpf(r.position.x + 14.0, r.end.x - 14.0, (float(n) + 0.5) / float(count))
		var spike: float = 24.0 + 14.0 * RisoShapes.hash1(float(n) + float(level_seed % 97))
		var foot: float = r.end.y - 6.0
		thorns.append(PackedVector2Array([Vector2(x - 11.0, foot), Vector2(x + 2.0, foot + spike), Vector2(x + 11.0, foot)]))
	return {"mass": mass, "stems": stems, "thorns": thorns}
