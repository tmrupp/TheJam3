extends RisoProp
## A pool of acid (Acid).

## Where it prints (absolute z): its body just behind the rock (so the rock trims it to the open
## cells it fills), its surface over the wizard (so whatever is in it is seen in it).
const BODY_Z: int = -21
const FRONT_Z: int = 11
## Its body's ink: pink, and night over it, more the deeper (per row under its surface) up to DEEP.
const BODY_PINK: float = 0.45
const BODY_NIGHT: float = 0.42
const DEEP_STEP: float = 0.09
const DEEP: float = 0.45
## The tint over whatever is under its surface, and its surface's skin (px thick).
const TINT: float = 0.1
const SKIN: float = 9.0
## Its bubbles: how many to a cell of surface, how many more while it seethes (warning, flooding),
## and how fast they rise (px/s).
const BUBBLES: float = 0.35
const SEETHE: float = 1.2
const RISE_SPEED: float = 70.0

## Its surface and bubbles, over the wizard.
var front: InkCanvas


func _ready() -> void:
	super()
	ink.z_as_relative = false
	ink.z_index = BODY_Z
	front = InkCanvas.new()
	front.z_as_relative = false
	front.z_index = FRONT_Z
	add_child(front)


## Its surface moves all the time.
func every_frame() -> bool:
	return true


## It spreads over its basin (Acid.extent): it is in view if any of it is.
func view_rect() -> Rect2:
	return (host as Acid).extent() if host is Acid else Rect2()


## A pool of acid: a deep rose body filling the open cells under its surface, darker the deeper,
## behind the rock; over the wizard, a bright pink skin along its surface, heaving in slow waves,
## a faint pink over everything under it, and bubbles of bare paper rising through it and bursting,
## many more as it seethes before it floods and while it rises. Drained, it lies in its pits.
func _draw_art() -> void:
	front.begin()
	var a: Acid = host as Acid
	if a == null or a.map_info == null:
		front.finish()
		return
	var level: float = a.surface()
	var seethe: float = maxf(a.warning(), 1.0 if a.flooding() and a.level() < 1.0 and a.level() > 0.0 else 0.0)
	var waves: float = 1.0 + seethe
	var body: Array[PackedVector2Array] = []
	var deeps: Array[PackedVector2Array] = []
	var skins: Array[PackedVector2Array] = []
	var shades: Array[float] = []
	var bubbles: Array[PackedVector2Array] = []
	var glints: Array[PackedVector2Array] = []
	var box: Rect2i = a.basin
	for y: int in range(box.position.y, box.end.y):
		var row_top: float = a.map_info.cell_position(Vector2i(box.position.x, y)).y - a.cell.y * 0.5
		var row_bottom: float = row_top + a.cell.y
		if row_bottom <= level:
			continue
		var x: int = box.position.x
		while x < box.end.x:
			if not a.fills(Vector2i(x, y)):
				x += 1
				continue
			var x0: int = x
			while x < box.end.x and a.fills(Vector2i(x, y)):
				x += 1
			var left: float = a.map_info.cell_position(Vector2i(x0, y)).x - a.cell.x * 0.5
			var right: float = left + a.cell.x * float(x - x0)
			var surfaced: bool = level >= row_top and level < row_bottom
			var top: float = maxf(row_top, level)
			if surfaced:
				# The row its surface crosses: its top edge heaves.
				var poly: PackedVector2Array = PackedVector2Array()
				var skin: PackedVector2Array = PackedVector2Array()
				var under: PackedVector2Array = PackedVector2Array()
				var steps: int = maxi(2, int((right - left) / 24.0))
				for i: int in range(steps + 1):
					var px: float = lerpf(left, right, float(i) / float(steps))
					var py: float = maxf(row_top, level + _wave(px, waves))
					poly.append(to_local(Vector2(px, py)))
					skin.append(to_local(Vector2(px, py)))
				for i: int in range(steps, -1, -1):
					var px: float = lerpf(left, right, float(i) / float(steps))
					under.append(to_local(Vector2(px, maxf(row_top, level + _wave(px, waves)) + SKIN)))
				poly.append(to_local(Vector2(right, row_bottom)))
				poly.append(to_local(Vector2(left, row_bottom)))
				skin.append_array(under)
				body.append(poly)
				skins.append(skin)
				# A glint now and then along the skin.
				for i: int in range(x0, x):
					var gx: float = left + a.cell.x * (float(i - x0) + RisoShapes.hash1(float(i) * 3.7))
					var flick: float = sin(t * 1.7 + float(i) * 2.3)
					if flick > 0.4:
						glints.append(RisoShapes.almond(to_local(Vector2(gx, level + _wave(gx, waves) + 3.0)), 10.0 * flick, 2.0, 8))
			elif top < row_bottom:
				body.append(_box(left, top, right, row_bottom))
			# Rows wholly under the surface print darker, the deeper the more.
			if row_top > level:
				var deep: float = minf(DEEP, DEEP_STEP * (row_top - level) / a.cell.y)
				deeps.append(_box(left, row_top, right, row_bottom))
				shades.append(deep)
	if not body.is_empty():
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], body)
		ink.ink(RisoPrint.PINK, BODY_PINK, body, false)
		ink.ink(RisoPrint.NIGHT, BODY_NIGHT, body, false)
		for i: int in range(deeps.size()):
			ink.ink(RisoPrint.NIGHT, shades[i], [deeps[i]], false)
		_bubbles(bubbles, a, level, seethe)
		front.ink(RisoPrint.PINK, TINT, body, false)
		front.knock([RisoPrint.NIGHT, RisoPrint.BLUE], skins)
		front.ink(RisoPrint.PINK, 0.95, skins)
		front.knock(RisoPrint.ALL_PLATES, glints)
		front.knock([RisoPrint.NIGHT, RisoPrint.BLUE], bubbles)
		front.ink(RisoPrint.PINK, 0.35, bubbles, false)
	front.finish()


## How far its surface heaves at `x` (world), `waves` times as much as it lies still.
func _wave(x: float, waves: float) -> float:
	return (sin(x * 0.011 + t * 1.6) * 3.0 + sin(x * 0.027 - t * 2.3) * 2.0) * waves


## A rectangle from (`left`, `top`) to (`right`, `bottom`) (world), in its own frame.
func _box(left: float, top: float, right: float, bottom: float) -> PackedVector2Array:
	var a: Vector2 = to_local(Vector2(left, top))
	var b: Vector2 = to_local(Vector2(right, bottom))
	return PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])


## Bubbles rising up its columns: in each column of open cells under its surface, from the
## column's floor to the surface, each a ring of paper on a fixed track that swells and bursts as it
## reaches the top; `seethe` (0..1) brings more.
func _bubbles(out: Array[PackedVector2Array], a: Acid, level: float, seethe: float) -> void:
	var box: Rect2i = a.basin
	for x: int in range(box.position.x, box.end.x):
		# The column's floor: the bottom of its run of open cells down from the surface's row.
		var y: int = a.map_info.cell_at(Vector2(a.map_info.cell_position(Vector2i(x, 0)).x, level)).y
		y = maxi(y, box.position.y)
		if not a.fills(Vector2i(x, y)):
			continue
		while y + 1 < box.end.y and a.fills(Vector2i(x, y + 1)):
			y += 1
		var bottom: float = a.map_info.cell_position(Vector2i(x, y)).y + a.cell.y * 0.5
		var span: float = bottom - level
		if span < 12.0:
			continue
		var odds: float = BUBBLES + SEETHE * seethe
		var count: int = int(odds) + (1 if RisoShapes.hash1(float(x) * 7.13) < fmod(odds, 1.0) else 0)
		var cx: float = a.map_info.cell_position(Vector2i(x, y)).x
		for k: int in range(count):
			var seed_value: float = float(x * 37 + k * 11)
			var bx: float = cx + (RisoShapes.hash1(seed_value * 1.31) - 0.5) * a.cell.x * 0.8
			var u: float = fmod(t * RISE_SPEED / span + RisoShapes.hash1(seed_value * 2.71), 1.0)
			var by: float = bottom - 8.0 - u * (span - 8.0)
			var r: float = 4.0 + 5.0 * RisoShapes.hash1(seed_value * 5.3)
			if u > 0.92:
				r *= 1.0 + (u - 0.92) * 10.0
			var c: Vector2 = to_local(Vector2(bx + sin(t * 3.0 + seed_value) * 3.0, by))
			out.append_array(RisoShapes.ring(c, r * 0.6, r, 14))
