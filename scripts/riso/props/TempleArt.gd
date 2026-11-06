class_name TempleArt
extends RisoProp
## A sky temple (Temple), its stylobate and roof of built stone laid in the level
## (SkyArchetype.build_temples) and printed with the masonry, in marble (RisoTerrain); this dresses
## it: its columns over its hall, its pediment over its roof, its lock and its altar. The lock is a
## row of medallions across its roof's face, one for each step of its sequence, an arrow on each the
## way that step's vane must point, lit in sun in turn as the steps are entered (Temple.progress),
## dark while not, flashing pink as the sequence breaks; the altar in the middle of its hall, a
## pedestal of pale stone, bears a ring with a pip lit for each; opened, the ring parts and a glow of
## sun hangs over it with a whale's shape in it. How the building is
## dressed is one of STYLES (`style`):
## - marble: fluted columns with capitals and bases, a triangular pediment with a cornice and a sun
##   disc in its middle;
## - overgrown: the marble, deep in growth: vines hanging in curtains from the roof and pediment,
##   ivy wound up the columns, moss along the cornice (leaves in moss: sun over the pale stone);
## - cloud: smooth rounded columns standing in heaps of cloud, cloud gathered at their tops, and a
##   rounded dome of a pediment with cloud over it;
## - ruin: the marble broken: two columns snapped short, drums fallen on the floor, a bite out of the
##   pediment and cracks through it.

const STYLES: Array[StringName] = [&"marble", &"overgrown", &"cloud", &"ruin"]
## How every temple is dressed (one of STYLES).
static var style: StringName = &"marble"
## A column's half-width, how far the pediment overhangs the roof, and how tall it rises (px).
const COLUMN: float = 22.0
const OVERHANG: float = 30.0
const PEDIMENT: float = 170.0


## The Temple it dresses.
var temple: Temple:
	get:
		return host as Temple


## The rock itself (its stone is the masonry's): printed as the rock is.
func of_the_rock() -> bool:
	return true


## Its temple's building (LevelGen.temples), or {} where it has none.
func _building() -> Dictionary:
	if temple == null or temple.map_info == null or temple.map_info.world == null or not host.has_meta(&"cell"):
		return {}
	var at: Vector2i = host.get_meta(&"cell")
	for b: Dictionary in temple.map_info.world.temples:
		if b["altar"] == at:
			return b
	return {}


func _draw_art() -> void:
	if temple == null:
		return
	var building: Dictionary = _building()
	if not building.is_empty():
		_dress(building)
		_frieze(building)
	_altar()


## Cell `c`'s middle, from the altar's.
func _at(c: Vector2i) -> Vector2:
	var altar: Vector2i = host.get_meta(&"cell")
	return Vector2(c - altar) * half * 2.0


## A number in [0, 1) for this temple, by `salt`.
func _h(box: Rect2i, salt: int) -> float:
	return RisoDecor.h(0, box.position, salt)


## Its columns, pediment and ornament, as `style` has them.
func _dress(building: Dictionary) -> void:
	var box: Rect2i = building["box"]
	var hall: Rect2i = building["hall"]
	var x0: int = box.position.x
	var x1: int = box.end.x - 1
	var top_y: float = _at(Vector2i(0, hall.position.y)).y - half
	var foot_y: float = _at(Vector2i(0, hall.end.y - 1)).y + half
	var roof_y: float = _at(Vector2i(0, box.position.y)).y - half
	var left: float = _at(Vector2i(x0, 0)).x - half
	var right: float = _at(Vector2i(x1, 0)).x + half
	var columns: Array[int] = [x0, x0 + 2, x1 - 2, x1]
	var broken: Array[int] = []
	if style == &"ruin":
		var first: int = int(_h(box, 1) * 4.0) % 4
		broken = [first, (first + 2) % 4]
	var stone: Array[PackedVector2Array] = []
	var shade: Array[PackedVector2Array] = []
	var cloud: Array[PackedVector2Array] = []
	for i: int in range(columns.size()):
		var cx: float = _at(Vector2i(columns[i], 0)).x
		if style == &"cloud":
			stone.append(RisoShapes.rrect(cx - COLUMN, top_y + 10.0, COLUMN * 2.0, foot_y - top_y - 20.0, COLUMN))
			shade.append(RisoShapes.rrect(cx + 4.0, top_y + 20.0, COLUMN - 8.0, foot_y - top_y - 40.0, 8.0))
			for k: int in range(4):
				var u: float = float(k) / 3.0 - 0.5
				cloud.append(RisoShapes.circle(Vector2(cx + u * 70.0, foot_y - 18.0 + absf(u) * 14.0), 30.0 - absf(u) * 18.0, 18))
				cloud.append(RisoShapes.circle(Vector2(cx + u * 56.0, top_y + 14.0 - absf(u) * 4.0), 22.0 - absf(u) * 12.0, 16))
			continue
		var top: float = top_y
		if broken.has(i):
			top = lerpf(top_y, foot_y, 0.35 + 0.3 * _h(box, 10 + i))
		stone.append(RisoShapes.rrect(cx - COLUMN, top + 16.0, COLUMN * 2.0, foot_y - top - 34.0, 2.0))
		shade.append(RisoShapes.rrect(cx + 6.0, top + 16.0, COLUMN - 10.0, foot_y - top - 34.0, 2.0))
		for f: int in range(2):
			var fx: float = cx - COLUMN * 0.4 + float(f) * COLUMN * 0.6
			shade.append(RisoShapes.rrect(fx - 1.5, top + 26.0, 3.0, foot_y - top - 54.0, 1.5))
		if broken.has(i):
			stone.append(PackedVector2Array([Vector2(cx - COLUMN, top + 18.0), Vector2(cx - 8.0, top + 4.0), Vector2(cx + 2.0, top + 14.0), Vector2(cx + 10.0, top - 2.0), Vector2(cx + COLUMN, top + 18.0)]))
		else:
			stone.append(RisoShapes.rrect(cx - COLUMN - 10.0, top, COLUMN * 2.0 + 20.0, 18.0, 4.0))
		stone.append(RisoShapes.rrect(cx - COLUMN - 10.0, foot_y - 18.0, COLUMN * 2.0 + 20.0, 18.0, 4.0))
	if style == &"ruin":
		for i: int in broken:
			var cx: float = _at(Vector2i(columns[i], 0)).x + (70.0 if i < 2 else -70.0)
			stone.append(RisoShapes.rrect(cx - 36.0, foot_y - 34.0, 72.0, 34.0, 14.0))
			shade.append(RisoShapes.rrect(cx - 36.0, foot_y - 12.0, 72.0, 12.0, 6.0))
	# The pediment over the roof: a triangle with a cornice; in the clouds, a rounded dome.
	var pediment: PackedVector2Array = PackedVector2Array()
	var apex: Vector2 = Vector2((left + right) * 0.5, roof_y - PEDIMENT)
	if style == &"cloud":
		for k: int in range(25):
			var a: float = PI + PI * float(k) / 24.0
			pediment.append(Vector2(apex.x + cos(a) * ((right - left) * 0.5 + OVERHANG * 0.5), roof_y + sin(a) * PEDIMENT * 0.85))
	else:
		pediment = PackedVector2Array([Vector2(left - OVERHANG, roof_y), apex, Vector2(right + OVERHANG, roof_y)])
		if style == &"ruin":
			# A bite out of one side of it.
			var bite: float = 0.25 + 0.3 * _h(box, 20)
			var on_left: bool = _h(box, 21) < 0.5
			var a: Vector2 = Vector2(left - OVERHANG, roof_y).lerp(apex, bite) if on_left else apex.lerp(Vector2(right + OVERHANG, roof_y), 1.0 - bite)
			var b: Vector2 = Vector2(left - OVERHANG, roof_y).lerp(apex, bite + 0.35) if on_left else apex.lerp(Vector2(right + OVERHANG, roof_y), 0.65 - bite)
			var dent: Vector2 = a.lerp(b, 0.5) + Vector2(0.0, 40.0)
			pediment = PackedVector2Array([Vector2(left - OVERHANG, roof_y), a, dent, b, apex, Vector2(right + OVERHANG, roof_y)]) if on_left else PackedVector2Array([Vector2(left - OVERHANG, roof_y), apex, b, dent, a, Vector2(right + OVERHANG, roof_y)])
	stone.append(pediment)
	ink.knock([RisoPrint.NIGHT], stone)
	ink.ink(RisoPrint.BLUE, 1.0, stone)
	ink.ink(RisoPrint.NIGHT, 0.06, stone, false)
	ink.ink(RisoPrint.NIGHT, 0.2, shade, false)
	if style != &"cloud":
		# Its cornice, and the sun disc in its middle.
		var cornice: PackedVector2Array = RisoShapes.rrect(left - OVERHANG - 6.0, roof_y - 12.0, right - left + 2.0 * OVERHANG + 12.0, 14.0, 4.0)
		ink.ink(RisoPrint.NIGHT, 0.18, [cornice], false)
		var disc: Vector2 = Vector2(apex.x, roof_y - PEDIMENT * 0.38)
		ink.ink(RisoPrint.ACCENT, 0.9, [RisoShapes.circle(disc, 26.0, 26)])
		ink.lift_ink([RisoPrint.ACCENT], 0.6, [RisoShapes.circle(disc, 12.0, 18)])
	if not cloud.is_empty() or style == &"cloud":
		for k: int in range(7):
			var u: float = float(k) / 6.0 - 0.5
			cloud.append(RisoShapes.circle(Vector2(apex.x + u * (right - left) * 0.9, roof_y - PEDIMENT * 0.85 * cos(u * PI * 0.95) + 6.0), 34.0 - absf(u) * 20.0, 18))
		ink.knock([RisoPrint.NIGHT, RisoPrint.ACCENT], cloud)
		ink.ink(RisoPrint.BLUE, 0.85, cloud)
	if style == &"ruin":
		var at: Vector2 = Vector2(lerpf(left, right, 0.3 + 0.4 * _h(box, 30)), roof_y - PEDIMENT * 0.3)
		var crack: PackedVector2Array = PackedVector2Array([at + Vector2(-40, -50), at + Vector2(-10, -10), at + Vector2(-20, 20), at + Vector2(20, 60), at + Vector2(10, 110)])
		ink.ink(RisoPrint.NIGHT, 0.7, RisoDecor.strip(crack, 6.0, 2.0), false)
	if style == &"overgrown":
		_growth(box, roof_y, top_y, foot_y, left, right, apex, columns)


## Vines hanging in curtains from the roof and pediment, ivy wound up the columns and moss along the
## cornice; leaves in moss.
func _growth(box: Rect2i, roof_y: float, top_y: float, foot_y: float, left: float, right: float, apex: Vector2, columns: Array[int]) -> void:
	var stems: Array[PackedVector2Array] = []
	var leaves: Array[PackedVector2Array] = []
	var n: int = 16
	for i: int in range(n):
		var x: float = lerpf(left - OVERHANG + 10.0, right + OVERHANG - 10.0, (float(i) + 0.5) / float(n))
		var length: float = (foot_y - top_y) * (0.2 + 0.7 * _h(box, 40 + i))
		var pts: PackedVector2Array = PackedVector2Array()
		for k: int in range(10):
			var u: float = float(k) / 9.0
			pts.append(Vector2(x + sin(u * 4.0 + float(i) * 1.7 + t * 0.5) * 9.0 * u, roof_y - 4.0 + u * length))
			if k >= 1:
				var side: float = 1.0 if k % 2 == 0 else -1.0
				leaves.append(Transform2D(side * 0.6, pts[k] + Vector2(side * 9.0, 0.0)) * RisoShapes.almond(Vector2.ZERO, 11.0, 6.0, 8))
		stems.append_array(RisoDecor.strip(pts, 4.0, 2.0))
	for c: int in columns:
		var cx: float = _at(Vector2i(c, 0)).x
		var pts: PackedVector2Array = PackedVector2Array()
		for k: int in range(17):
			var u: float = float(k) / 16.0
			pts.append(Vector2(cx + sin(u * TAU * 2.0) * (COLUMN + 4.0), lerpf(foot_y - 10.0, top_y + 20.0, u)))
			if k % 2 == 0:
				leaves.append(Transform2D(0.5 * sin(float(k)), pts[k] + Vector2(7.0, -2.0)) * RisoShapes.almond(Vector2.ZERO, 12.0, 6.5, 8))
		stems.append_array(RisoDecor.strip(pts, 4.0, 3.0))
	# Moss along the cornice and up the pediment's slopes.
	for k: int in range(22):
		var u: float = float(k) / 21.0
		var p: Vector2 = Vector2(left - OVERHANG, roof_y).lerp(apex, u * 2.0) if u < 0.5 else apex.lerp(Vector2(right + OVERHANG, roof_y), u * 2.0 - 1.0)
		leaves.append(RisoShapes.circle(p + Vector2(0.0, -4.0), 9.0 + 5.0 * _h(box, 80 + k), 10))
		leaves.append(RisoShapes.circle(Vector2(lerpf(left - OVERHANG, right + OVERHANG, u), roof_y - 6.0), 8.0, 10))
	ink.ink(RisoPrint.NIGHT, 0.6, stems, false)
	ink.knock([RisoPrint.NIGHT], leaves)
	ink.ink(RisoPrint.BLUE, 1.0, leaves)
	ink.ink(RisoPrint.ACCENT, 0.85, leaves, false)
	ink.ink(RisoPrint.NIGHT, 0.5, leaves, false)


## Its lock, where it is seen from afar: a medallion for each step of its sequence across its roof's
## face, as many as fit, an arrow on each the way that step's vane must point. One lit (temple.progress) is a sun
## disc glowing, its arrow knocked to paper; one not yet lit is dark, its arrow faint. As the
## sequence breaks (temple.since_broken) the medallions flash pink and go dark.
func _frieze(building: Dictionary) -> void:
	var box: Rect2i = building["box"]
	@warning_ignore("integer_division")
	var roof: Vector2 = _at(Vector2i((box.position.x + box.end.x - 1) / 2, box.position.y))
	var lit: int = temple.progress()
	var broke: float = clampf(1.0 - temple.since_broken / 0.6, 0.0, 1.0)
	var shake: float = sin(temple.since_refused * 40.0) * 4.0 * exp(-temple.since_refused * 6.0)
	var n: int = temple.sequence.size()
	var span: float = float(box.size.x) * half * 2.0 - 60.0
	var gap: float = minf(92.0, span / float(maxi(1, n)))
	var r: float = gap * 0.38
	for i: int in range(n):
		var c: Vector2 = Vector2(roof.x + (float(i) - float(n - 1) * 0.5) * gap + shake, roof.y)
		var disc: PackedVector2Array = RisoShapes.circle(c, r, 24)
		var arrow: Transform2D = Transform2D(0.0, Vector2(float(temple.sequence[i]) * r / 21.0, r / 21.0), 0.0, c)
		var shape: Array[PackedVector2Array] = [arrow * RisoShapes.rrect(-9.0, -2.5, 11.0, 5.0, 1.5), arrow * RisoShapes.tri(Vector2(1.0, -7.5), Vector2(11.0, 0.0), Vector2(1.0, 7.5))]
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [disc])
		if i < lit:
			var pulse: float = 0.5 + 0.5 * sin(t * 2.4 + float(i))
			ink.ink(RisoPrint.ACCENT, 0.22 + 0.1 * pulse, [RisoShapes.circle(c, r * 1.5, 24)], false)
			ink.ink(RisoPrint.ACCENT, 1.0, [disc])
			ink.knock([RisoPrint.ACCENT], shape)
		else:
			ink.ink(RisoPrint.NIGHT, 0.75, [disc])
			ink.lift_ink([RisoPrint.NIGHT], 0.45, shape)
			if broke > 0.0:
				ink.ink(RisoPrint.PINK, 0.85 * broke, [disc], false)


func shines() -> bool:
	return true


## Opened, a light where the whale's glow hangs over the altar.
func light() -> Array:
	if temple == null or not temple.opened():
		return []
	return _light(Vector2(0.0, _ground() - 170.0), RisoLight.BEACON, RisoPrint.ACCENT)


## The altar: a pedestal with the lock on its face, a ring with a pip for each wind of the sequence
## lit in sun as it is; opened, the ring stands open and a glow with a whale's shape hangs over it.
func _altar() -> void:
	var g: float = _ground()
	var pedestal: Array[PackedVector2Array] = [RisoShapes.rrect(-56.0, g - 118.0, 112.0, 16.0, 5.0), RisoShapes.rrect(-40.0, g - 104.0, 80.0, 90.0, 4.0), RisoShapes.rrect(-60.0, g - 16.0, 120.0, 16.0, 5.0)]
	ink.knock([RisoPrint.NIGHT], pedestal)
	ink.ink(RisoPrint.BLUE, 1.0, pedestal)
	ink.ink(RisoPrint.NIGHT, 0.2, [RisoShapes.rrect(14.0, g - 104.0, 26.0, 90.0, 4.0)], false)
	var open: bool = temple.opened()
	var lit: int = temple.progress()
	var n: int = temple.sequence.size()
	var broke: float = clampf(1.0 - temple.since_broken / 0.6, 0.0, 1.0)
	var c: Vector2 = Vector2(0.0, g - 62.0)
	# The ring: shut, a dark ring with its keyway; open, parted at the top.
	var ring: Array[PackedVector2Array] = []
	var gap: float = 0.9 if open else 0.0
	for k: int in range(20):
		var a0: float = -PI * 0.5 + gap * 0.5 + (TAU - gap) * float(k) / 20.0
		var a1: float = -PI * 0.5 + gap * 0.5 + (TAU - gap) * float(k + 1) / 20.0
		ring.append(PackedVector2Array([c + Vector2.from_angle(a0) * 22.0, c + Vector2.from_angle(a1) * 22.0, c + Vector2.from_angle(a1) * 15.0, c + Vector2.from_angle(a0) * 15.0]))
	ink.ink(RisoPrint.NIGHT, 0.75, ring, false)
	if not open:
		ink.ink(RisoPrint.NIGHT, 0.8, [RisoShapes.circle(c + Vector2(0.0, -3.0), 4.0, 10), RisoShapes.tri(c + Vector2(-3.0, 0.0), c + Vector2(3.0, 0.0), c + Vector2(0.0, 9.0))], false)
	var pips: Array[PackedVector2Array] = []
	var dark: Array[PackedVector2Array] = []
	for i: int in range(n):
		# Over the ring, from the left.
		var a: float = -PI * 0.5 + (float(i) - float(n - 1) * 0.5) * (2.6 / float(maxi(1, n - 1)))
		var pip: PackedVector2Array = RisoShapes.circle(c + Vector2.from_angle(a) * 32.0, 4.0, 10)
		if i < lit:
			pips.append(pip)
		else:
			dark.append(pip)
	ink.knock([RisoPrint.NIGHT], pips)
	ink.ink(RisoPrint.ACCENT, 1.0, pips)
	ink.ink(RisoPrint.NIGHT, 0.6, dark, false)
	if broke > 0.0:
		ink.ink(RisoPrint.PINK, 0.85 * broke, dark, false)
	if open:
		var glow: float = clampf(temple.since_open / 0.8, 0.0, 1.0) if temple.since_open >= 0.0 else 1.0
		var w: Vector2 = Vector2(0.0, g - 170.0 + sin(t * 1.4) * 5.0)
		ink.ink(RisoPrint.NIGHT, 0.8 * glow, [RisoShapes.ellipse(w, 22.0, 10.0, 16), RisoShapes.tri(w + Vector2(18.0, 0.0), w + Vector2(32.0, -10.0), w + Vector2(32.0, 10.0))], false)


## It dresses its whole building: in view if any of that is.
func view_rect() -> Rect2:
	return Rect2(host.global_position + Vector2(-700.0, -900.0), Vector2(1400.0, 1100.0)) if host != null else Rect2()
