extends RisoProp
## An ossuary door (OssuaryDoor): skulls stacked in staggered rows of COLUMNS across the doorway,
## one skull for each charge of darkness it drinks, built one of three ways (OssuaryDoor.Style;
## every door is built with a lintel, OssuaryDoor.STYLE, and the others are kept to compare):
## - an arch (ARCH): a square slab of blue stone, flush with the masonry over the doorway, with a
##   round-headed niche cut in it, its keystone paler, the skulls stacked in the niche;
## - a wall (WALL): no stone at all, the skulls stacked straight across the doorway, top to bottom,
##   long bones laid between the rows;
## - a lintel (LINTEL): two jambs and a lintel over them, flush with the masonry, a small skull
##   carved in the lintel, the skulls stacked between the jambs.
## Whichever, it fills its cell up to the stone over the doorway, so nothing shows round it. A skull
## still to be fed is dim bone, its sockets dark; a fed one is bright bone, its sockets brimming
## with darkness and a pale glint staring out of each. Behind the skulls the darkness poured in
## stands like water, its surface rippling, as high as the share of its fill it has had, so how
## much the door still wants reads from afar. Just after a pour the fed skulls flare and the
## surface heaves. Once it has had its fill it sinks into the floor and fades, and is gone.

## Skulls to a row, how big each is drawn against the room it has (0..1), and how far the rows
## stagger (a share of a skull's room).
const COLUMNS: int = 3
const SKULL: float = 0.8
const STAGGER: float = 0.18
## How far in from its cell's sides it stands (px), and how far up into the stone over the doorway
## it reaches (px), so no seam shows there.
const SIDE_INSET: float = 3.0
const OVERLAP: float = 3.0
## The stone of an arch or a lintel: blue under this much night ink; the dark of the niche the
## skulls stand in, and of a bare wall's gaps.
const STONE_NIGHT: float = 0.35
const NICHE_NIGHT: float = 0.75
## An arch: how far its niche stands in from the slab's sides and top (px), and the keystone's size
## (px) and how pale it is. The joints of its stone (px wide, ink lifted).
const ARCH_RIM: Vector2 = Vector2(11.0, 9.0)
const KEYSTONE: Vector2 = Vector2(18.0, 16.0)
const KEYSTONE_LIFT: float = 0.45
const JOINT_W: float = 2.5
const JOINT_LIFT: float = 0.3
## A lintel: its jambs' width and the lintel's height (px), and how pale its carved skull is.
const JAMB: float = 13.0
const LINTEL_H: float = 22.0
const CARVED: float = 0.5
## A wall: the long bones between its rows, how thick (px) and how pale.
const BONE_THICK: float = 5.0
const LONG_BONE: float = 0.38
## The darkness poured in: how much night ink it lays, how high its ripples run (px) and how fast.
const POOL: float = 0.9
const RIPPLE: float = 3.0
const RIPPLE_SPEED: float = 2.4
## Bone: an unfed skull's paper, a fed skull's, and the glint in a fed skull's sockets.
const BONE_DIM: float = 0.42
const BONE_FED: float = 0.95
const GLINT: float = 0.85
## After a pour: how long the fed skulls flare and the surface heaves (s), and how much higher it
## heaves (px).
const POUR_TIME: float = 0.8
const HEAVE: float = 7.0
## How far it has sunk when it is gone (a share of its height).
const SINK: float = 0.6


## The OssuaryDoor it dresses.
var door: OssuaryDoor:
	get:
		return host as OssuaryDoor

## This print's floor (px, in its frame), how far it has sunk (px) and how much it still prints.
var _g: float = 0.0
var _drop: float = 0.0
var _cover: float = 1.0


func _draw_art() -> void:
	var sunk: float = door.sunk if door != null else 0.0
	if sunk >= 1.0:
		return
	var style: OssuaryDoor.Style = door.style if door != null else OssuaryDoor.STYLE
	var fill: int = door.fill if door != null else 9
	var fed: int = door.poured() if door != null else 4
	var since: float = door.poured_at if door != null else INF
	var fresh: float = 1.0 - clampf(since / POUR_TIME, 0.0, 1.0)
	_g = _ground()
	_drop = sunk * SINK * half * 2.0
	_cover = 1.0 - sunk
	var w: float = half - SIDE_INSET
	var top: float = _g - half * 2.0 - OVERLAP
	# Where the skulls stand: the whole doorway, or the niche cut in the stone, and how high their
	# rows may climb in it (an arch's head is left to the stone).
	var niche: PackedVector2Array
	var room_top: float = top
	match style:
		OssuaryDoor.Style.ARCH:
			var slab: PackedVector2Array = RisoShapes.rrect(-w, top, w * 2.0, _g - top, 0.0)
			var nw: float = w - ARCH_RIM.x
			var crown: float = top + OVERLAP + ARCH_RIM.y
			niche = RisoShapes.arch(-nw, crown, nw * 2.0, _g - crown, 16)
			room_top = crown + nw * 0.35
			_stone([slab])
			_joints([
				RisoShapes.rrect(-w, _g - half * 0.9, ARCH_RIM.x - 1.0, JOINT_W, 0.0),
				RisoShapes.rrect(w - ARCH_RIM.x + 1.0, _g - half * 0.9, ARCH_RIM.x - 1.0, JOINT_W, 0.0),
			])
			_ink_dark(niche)
			var key: PackedVector2Array = PackedVector2Array([Vector2(-KEYSTONE.x * 0.5, top + OVERLAP), Vector2(KEYSTONE.x * 0.5, top + OVERLAP), Vector2(KEYSTONE.x * 0.32, crown + KEYSTONE.y - ARCH_RIM.y), Vector2(-KEYSTONE.x * 0.32, crown + KEYSTONE.y - ARCH_RIM.y)])
			_lift([key], KEYSTONE_LIFT)
		OssuaryDoor.Style.LINTEL:
			var jambs: Array[PackedVector2Array] = [
				RisoShapes.rrect(-w, top, JAMB, _g - top, 0.0),
				RisoShapes.rrect(w - JAMB, top, JAMB, _g - top, 0.0),
				RisoShapes.rrect(-w, top, w * 2.0, LINTEL_H + OVERLAP, 0.0),
			]
			niche = RisoShapes.rrect(-w + JAMB, top + LINTEL_H + OVERLAP, (w - JAMB) * 2.0, _g - top - LINTEL_H - OVERLAP, 0.0)
			room_top = top + LINTEL_H + OVERLAP
			_stone(jambs)
			_joints([RisoShapes.rrect(-w, top + LINTEL_H + OVERLAP - JOINT_W, w * 2.0, JOINT_W, 0.0)])
			_ink_dark(niche)
			var c: Vector2 = Vector2(0, top + OVERLAP + LINTEL_H * 0.5)
			_lift([RisoShapes.circle(c + Vector2(0, -1.5), 7.5, 14), RisoShapes.rrect(c.x - 4.5, c.y + 3.5, 9.0, 5.0, 1.2)], CARVED)
		_:
			niche = RisoShapes.rrect(-w, top, w * 2.0, _g - top, 0.0)
			room_top = top + OVERLAP
			_ink_dark(niche)
	_pool(niche, fed, fill, fresh, room_top)
	_skulls(niche, fill, fed, fresh, room_top, style == OssuaryDoor.Style.WALL)


## Stone (blue under STONE_NIGHT), hiding what is behind it.
func _stone(polys: Array[PackedVector2Array]) -> void:
	var at: Array[PackedVector2Array] = _placed(polys)
	ink.lift_ink(RisoPrint.ALL_PLATES, _cover, at)
	ink.ink(RisoPrint.BLUE, _cover, at, false)
	ink.ink(RisoPrint.NIGHT, STONE_NIGHT * _cover, at, false)


## The dark the skulls stand in, hiding what is behind it.
func _ink_dark(poly: PackedVector2Array) -> void:
	var at: Array[PackedVector2Array] = _placed([poly])
	ink.lift_ink(RisoPrint.ALL_PLATES, _cover, at)
	ink.ink(RisoPrint.BLUE, _cover, at, false)
	ink.ink(RisoPrint.NIGHT, NICHE_NIGHT * _cover, at, false)


## Pale joints in the stone.
func _joints(polys: Array[PackedVector2Array]) -> void:
	_lift(polys, JOINT_LIFT)


## `amount` of the night and blue lifted in `polys`, as it sinks.
func _lift(polys: Array[PackedVector2Array], amount: float) -> void:
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], amount * _cover, _placed(polys))


## The darkness poured in, standing in `niche` as high as `fed` of `fill` of the room from the floor
## up to `room_top`.
func _pool(niche: PackedVector2Array, fed: int, fill: int, fresh: float, room_top: float) -> void:
	if fed <= 0:
		return
	var level: float = _g - (_g - room_top) * float(fed) / float(maxi(fill, 1)) - HEAVE * fresh
	var w: float = half
	var surface: PackedVector2Array = PackedVector2Array()
	var n: int = 12
	for k: int in range(n + 1):
		var x: float = lerpf(w, -w, float(k) / float(n))
		surface.append(Vector2(x, level + sin(x * 0.09 + t * RIPPLE_SPEED + phase) * RIPPLE * (1.0 + fresh)))
	surface.append(Vector2(-w, _g))
	surface.append(Vector2(w, _g))
	ink.ink(RisoPrint.NIGHT, POOL * _cover, _placed(Geometry2D.intersect_polygons(niche, surface)), false)


## The skulls in `niche`, filled from the bottom row up as darkness settles, their rows climbing to
## `room_top`; on a bare wall, long bones laid between the rows.
func _skulls(niche: PackedVector2Array, fill: int, fed: int, fresh: float, room_top: float, bones: bool) -> void:
	var box: Rect2 = Rect2(niche[0], Vector2.ZERO)
	for p: Vector2 in niche:
		box = box.expand(p)
	var rows: int = ceili(float(fill) / float(COLUMNS))
	var room: Vector2 = Vector2(box.size.x / float(COLUMNS), (_g - room_top) / float(maxi(rows, 1)))
	var r: float = minf(room.x, room.y) * 0.5 * SKULL
	var dim: Array[PackedVector2Array] = []
	var bright: Array[PackedVector2Array] = []
	var sockets: Array[PackedVector2Array] = []
	var brims: Array[PackedVector2Array] = []
	var glints: Array[PackedVector2Array] = []
	var long: Array[PackedVector2Array] = []
	if bones:
		for row: int in range(1, rows):
			var y: float = _g - room.y * float(row)
			long.append(RisoShapes.rrect(box.position.x + 4.0, y - BONE_THICK * 0.5, box.size.x - 8.0, BONE_THICK, BONE_THICK * 0.5))
			for end: float in [box.position.x + 6.0, box.end.x - 6.0]:
				long.append(RisoShapes.circle(Vector2(end, y - BONE_THICK * 0.4), BONE_THICK * 0.6, 8))
				long.append(RisoShapes.circle(Vector2(end, y + BONE_THICK * 0.4), BONE_THICK * 0.6, 8))
	for i: int in range(fill):
		@warning_ignore("integer_division")
		var row: int = i / COLUMNS
		var col: int = i % COLUMNS
		var stagger: float = room.x * STAGGER * (1.0 if row % 2 == 1 else -1.0)
		var c: Vector2 = Vector2(box.position.x + room.x * (float(col) + 0.5) + stagger, _g - room.y * (float(row) + 0.5))
		var skull: Array[PackedVector2Array] = [RisoShapes.circle(c + Vector2(0, -r * 0.12), r * 0.82, 16), RisoShapes.rrect(c.x - r * 0.45, c.y + r * 0.35, r * 0.9, r * 0.5, r * 0.15)]
		var eyes: Array[PackedVector2Array] = [RisoShapes.circle(c + Vector2(-r * 0.33, -r * 0.08), r * 0.24, 10), RisoShapes.circle(c + Vector2(r * 0.33, -r * 0.08), r * 0.24, 10)]
		var nose: PackedVector2Array = RisoShapes.tri(c + Vector2(0, r * 0.12), c + Vector2(-r * 0.1, r * 0.32), c + Vector2(r * 0.1, r * 0.32))
		if i < fed:
			bright.append_array(skull)
			brims.append_array(eyes)
			brims.append(nose)
			for e: int in range(2):
				glints.append(RisoShapes.circle(c + Vector2((-1.0 if e == 0 else 1.0) * r * 0.3, -r * 0.13), r * 0.08, 6))
		else:
			dim.append_array(skull)
			sockets.append_array(eyes)
			sockets.append(nose)
	ink.lift_ink(RisoPrint.ALL_PLATES, LONG_BONE * _cover, _placed(long))
	ink.lift_ink(RisoPrint.ALL_PLATES, BONE_DIM * _cover, _placed(dim))
	ink.ink(RisoPrint.NIGHT, _cover * 0.8, _placed(sockets), false)
	if not bright.is_empty():
		ink.lift_ink(RisoPrint.ALL_PLATES, minf(1.0, BONE_FED + 0.05 * fresh) * _cover, _placed(bright))
		ink.ink(RisoPrint.NIGHT, _cover, _placed(brims), false)
		var glint: float = GLINT * (0.75 + 0.25 * sin(t * 2.0 + phase)) + (1.0 - GLINT) * fresh
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], glint * _cover, _placed(glints))


## `polys` sunk as far as it has sunk, cut off at the floor.
func _placed(polys: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	if _drop <= 0.0:
		return polys
	var ground: PackedVector2Array = RisoShapes.rrect(-half * 2.0, _g - half * 4.0, half * 4.0, half * 4.0, 0.0)
	var out: Array[PackedVector2Array] = []
	var down: Transform2D = Transform2D(0.0, Vector2(0, _drop))
	for p: PackedVector2Array in polys:
		out.append_array(Geometry2D.intersect_polygons(down * p, ground))
	return out
