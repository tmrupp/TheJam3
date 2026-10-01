extends Node2D
class_name RisoDecor
## Decor for the surface grotto: small printed props that make the rock feel lived in, never
## part of the gameplay.
## - Floors: grass tufts, moon-flowers, mushrooms, stones.
## - Ceilings: hanging roots, stalactites, ink drips (RisoAmbient drops ink from them).
## - Walls: vines down the rock face.
## Plants (tufts, flowers, roots, vines) are drawn live, only on screen, so they can sway: a slow
## idle breeze, and a springy push away from the wizard as they pass.
## Every choice is a hash of the level seed and the cell, so a level always wears the same
## decor for everyone; the world's RNG is never touched. Decor keeps clear of any cell holding
## an object, and prints only in blue, night, moss (accent over blue) and bare paper: pink is
## danger, yellow is reward, glow is the wizard's.

const CHUNK: int = 16

## Draw order and ink for each kind of mark. [plate, cover, knock, punch]
const SLOTS: Array[Array] = [
	[RisoPrint.NIGHT, 0.0, false, false],   # 0-3 unused (the rock stays plain)
	[RisoPrint.NIGHT, 0.0, false, false],
	[RisoPrint.BLUE, 0.0, false, false],
	[RisoPrint.BLUE, 0.0, false, false],
	[RisoPrint.BLUE, 1.0, false, true],     # 4 roots, stalactites, drips, vines, stems
	[RisoPrint.NIGHT, 0.3, false, false],   # 5 their shade
	[RisoPrint.ACCENT, 0.85, false, false], # 6 moss over blue: tufts, leaves, vine leaves
	[RisoPrint.BLUE, 1.0, false, true],     # 7 moss bases (blue under the accent)
	[RisoPrint.NIGHT, 1.0, true, false],    # 8 paper: petals, mushroom stems and spots
	[RisoPrint.BLUE, 0.2, false, false],    # 9 petal tint
	[RisoPrint.NIGHT, 0.7, false, false],   # 10 flower hearts
	[RisoPrint.BLUE, 1.0, false, true],     # 11 mushroom caps
	[RisoPrint.BLUE, 0.85, false, true],    # 12 stones
	[RisoPrint.NIGHT, 0.35, false, false],  # 13 stone shade
	[RisoPrint.NIGHT, 1.0, true, false],    # 14 paper spots on the caps
]
const KNOCK_ALL: Array[int] = [RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW]
const KNOCK_ROCK: Array[int] = [RisoPrint.BLUE, RisoPrint.NIGHT]
const STRUCTURES: Array[String] = ["level_exit.tscn", "shrine.tscn", "door.tscn", "checkpoint.tscn", "spikes.tscn",
	"portal.tscn", "inkwell.tscn", "moving_platform.tscn"]

## The plan: one entry per prop, {kind, cell, at (world), seed}.
var items: Array[Dictionary] = []
## Where RisoAmbient hangs its life: fireflies over plants, ink drops under drips.
var firefly_spots: PackedVector2Array = PackedVector2Array()
var drip_spots: PackedVector2Array = PackedVector2Array()
## Where each drip's drop lands (the floor below it, or a few cells down).
var drip_ends: PackedFloat32Array = PackedFloat32Array()
var _solid: Dictionary = {}
var canvases: Array[InkCanvas] = []
## Plants that sway: indexes into `items`, each item holding its polygons ("parts"), the point it
## grows from ("anchor"), whether it hangs ("hang") and its spring ("a", "v").
const SWAY_KINDS: Array[StringName] = [&"tuft", &"flower", &"roots", &"vine"]
var swaying: Array[int] = []
var live: InkCanvas
var t: float = 0.0
var half: float = 64.0


func _ready() -> void:
	z_index = -15
	z_as_relative = false
	add_to_group(&"riso_art")
	visible = RisoPrint.is_on()
	live = InkCanvas.new()
	add_child(live)


## A stable 0..1 hash of the level seed, a cell and a salt.
static func h(level_seed: int, v: Vector2i, salt: int) -> float:
	var x: int = MapInfo.level_seed(level_seed ^ (salt * 2654435), v.x * 7919 + v.y * 104729 + salt)
	return float(x % 100000) / 100000.0


## Work out every prop for a level (pure: the same inputs always give the same plan).
static func plan(solid: Dictionary, occupied: Dictionary, level_seed: int, bounds: Rect2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cells: Array = solid.keys()
	cells.sort()
	for v: Vector2i in cells:
		if not bounds.has_point(v):
			continue
		var above: Vector2i = v + Vector2i.UP
		var below: Vector2i = v + Vector2i.DOWN
		if not solid.has(above) and not occupied.has(above):
			var r: float = h(level_seed, v, 1)
			var kind: StringName = &""
			if r < 0.3:
				kind = &"tuft"
			elif r < 0.42:
				kind = &"flower"
			elif r < 0.49:
				kind = &"mushroom"
			elif r < 0.54:
				kind = &"stones"
			if kind != &"":
				out.append({"kind": kind, "cell": above, "base": v})
		if not solid.has(below) and not occupied.has(below):
			var r: float = h(level_seed, v, 2)
			var kind: StringName = &""
			if r < 0.24:
				kind = &"roots"
			elif r < 0.34:
				kind = &"stalactite"
			elif r < 0.4:
				kind = &"drip"
			if kind != &"":
				out.append({"kind": kind, "cell": below, "base": v})
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
			var open: Vector2i = v + side
			if solid.has(open) or occupied.has(open) or not solid.has(above):
				continue
			if h(level_seed, v, 3 + side.x) < 0.12:
				out.append({"kind": &"vine", "cell": open, "base": v, "side": side.x})
	return out


## Rebuild for the level MapInfo has just laid out.
func rebuild(info: MapInfo, cracked_positions: Array[Vector2] = []) -> void:
	var tm: TileMap = info.tile_map
	half = float(tm.tile_set.tile_size.x) * tm.global_scale.x * 0.5
	var solid: Dictionary = {}
	for v: Vector2i in tm.get_used_cells(0):
		solid[v] = true
	for p: Vector2 in cracked_positions:
		solid[info.cell_at(p)] = true
	var occupied: Dictionary = {}
	for node: Node in info.map_elements.get_children():
		if not (node is Node2D) or node.is_queued_for_deletion():
			continue
		# Only structures keep decor away; plants can grow under a floating star or beside a wisp.
		var file: String = node.scene_file_path.get_file()
		if not file in STRUCTURES:
			continue
		var c: Vector2i = node.get_meta(&"cell", info.cell_at((node as Node2D).global_position))
		occupied[c] = true
		# Tall things (exits, shrines, lanterns, doors) keep their neighbours clear too.
		if file in ["level_exit.tscn", "shrine.tscn", "checkpoint.tscn", "door.tscn"]:
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i(2, 0)]:
				occupied[c + d] = true
	var level_seed: int = MapInfo.level_seed(info.coord.x, info.coord.y)
	items = RisoDecor.plan(solid, occupied, level_seed, Rect2i(Vector2i.ZERO, info.world.size))
	_solid = solid
	firefly_spots = PackedVector2Array()
	drip_spots = PackedVector2Array()
	drip_ends = PackedFloat32Array()
	var chunks: Dictionary = {}
	swaying.clear()
	for index: int in range(items.size()):
		var item: Dictionary = items[index]
		var v: Vector2i = item["cell"]
		if item["kind"] in SWAY_KINDS:
			var own: Array = _empty_slots()
			var at: Vector2 = tm.to_global(tm.map_to_local(v))
			_draw_item(item, at, own, level_seed)
			var parts: Array = []
			for i: int in range(own.size()):
				for poly: PackedVector2Array in own[i]:
					parts.append([i, poly])
			var hang: bool = item["kind"] in [&"roots", &"vine"]
			item["parts"] = parts
			item["hang"] = hang
			item["anchor"] = Vector2(at.x - float(item.get("side", 0)) * half, at.y + (-half if hang else half))
			item["a"] = 0.0
			item["v"] = 0.0
			swaying.append(index)
			continue
		var key: Vector2i = Vector2i(floori(float(v.x) / CHUNK), floori(float(v.y) / CHUNK))
		if not chunks.has(key):
			chunks[key] = _empty_slots()
		var c: Vector2 = tm.to_global(tm.map_to_local(v))
		_draw_item(item, c, chunks[key], level_seed)
	for canvas: InkCanvas in canvases:
		canvas.queue_free()
	canvases.clear()
	for key: Vector2i in chunks:
		var canvas: InkCanvas = InkCanvas.new()
		add_child(canvas)
		canvases.append(canvas)
		canvas.begin()
		_print_slots(canvas, chunks[key])
		canvas.finish()


func _empty_slots() -> Array:
	var slots: Array = []
	for i: int in range(SLOTS.size()):
		var polys: Array[PackedVector2Array] = []
		slots.append(polys)
	return slots


func _print_slots(canvas: InkCanvas, slots: Array) -> void:
	for i: int in range(SLOTS.size()):
		var polys: Array[PackedVector2Array] = slots[i]
		if polys.is_empty():
			continue
		var slot: Array = SLOTS[i]
		if bool(slot[2]):
			canvas.knock(KNOCK_ALL if i == 8 or i == 14 else KNOCK_ROCK, polys)
		else:
			canvas.ink(int(slot[0]), float(slot[1]), polys, bool(slot[3]))


## How far a plant leans at `anchor` (radians-ish shear), for tests and drawing.
func lean(index: int) -> float:
	return float(items[index].get("a", 0.0))


func _process(delta: float) -> void:
	t += delta
	live.begin()
	var cam: Camera2D = get_viewport().get_camera_2d()
	var player: Player = get_node_or_null("/root/Main/Player") as Player
	if cam == null or swaying.is_empty():
		live.finish()
		return
	var view: Rect2 = RisoLight.view_rect(self, cam).grow(200.0)
	var slots: Array = _empty_slots()
	var dt: float = minf(delta, 0.05)
	for index: int in swaying:
		var item: Dictionary = items[index]
		var anchor: Vector2 = item["anchor"]
		if not view.has_point(anchor):
			continue
		var hang: bool = item["hang"]
		# The push: away from the wizard, and along with them, while they brush past.
		var target: float = 0.0
		if player != null:
			var reach_y: float = anchor.y + (90.0 if hang else -70.0)
			var dx: float = anchor.x - player.global_position.x
			var close: float = clampf(1.0 - absf(dx) / 170.0, 0.0, 1.0) * clampf(1.0 - absf(player.global_position.y - reach_y) / 150.0, 0.0, 1.0)
			if close > 0.0:
				# Leans away from the wizard, and is swept along the way they are going.
				var away: float = signf(dx) * (1.0 if not hang else -1.0)
				var sweep: float = clampf(player.velocity.x / 300.0, -1.0, 1.0) * (1.0 if not hang else -1.0)
				target = clampf(away * 0.55 + sweep * 0.6, -0.9, 0.9) * sqrt(close)
		var a: float = item["a"]
		var v: float = item["v"]
		# A soft spring with little damping: pushed over, it whips back and wobbles to rest.
		v += ((target - a) * 38.0 - v * 3.5) * dt
		a += v * dt
		item["a"] = a
		item["v"] = v
		var bend: float = a + sin(t * 1.3 + anchor.x * 0.013) * 0.07
		for part: Array in item["parts"]:
			var poly: PackedVector2Array = part[1]
			var bent: PackedVector2Array = PackedVector2Array()
			bent.resize(poly.size())
			for k: int in range(poly.size()):
				var p: Vector2 = poly[k]
				var h: float = (p.y - anchor.y) if hang else (anchor.y - p.y)
				bent[k] = Vector2(p.x + bend * h, p.y)
			(slots[int(part[0])] as Array[PackedVector2Array]).append(bent)
	_print_slots(live, slots)
	live.finish()


# ------------------------------------------------------------------ the props

func _r(level_seed: int, v: Vector2i, salt: int) -> float:
	return RisoDecor.h(level_seed, v, salt)


## A bent strip from `a` along `pts`, `w0` wide at the start tapering to `w1`.
static func strip(pts: PackedVector2Array, w0: float, w1: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for i: int in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if a.distance_to(b) < 0.5:
			continue
		var n: Vector2 = (b - a).normalized().orthogonal()
		var wa: float = lerpf(w0, w1, float(i) / float(pts.size() - 1)) * 0.5
		var wb: float = lerpf(w0, w1, float(i + 1) / float(pts.size() - 1)) * 0.5
		out.append(PackedVector2Array([a - n * wa, b - n * wb, b + n * wb, a + n * wa]))
	return out


## Props on floors, ceilings and walls are drawn at a sketch size, then grown by PROP_SCALE
## around where they grow from, so they read next to the wizard.
const PROP_SCALE: float = 2.0


func _draw_item(item: Dictionary, c: Vector2, slots: Array, s: int) -> void:
	var before: Array[int] = []
	for slot: Array in slots:
		before.append(slot.size())
	_sketch_item(item, c, slots, s)
	var anchor: Variant = null
	match item["kind"]:
		&"tuft", &"flower", &"mushroom", &"stones":
			anchor = Vector2(c.x, c.y + half)
		&"roots", &"stalactite", &"drip":
			anchor = Vector2(c.x, c.y - half)
		&"vine":
			anchor = Vector2(c.x - float(item["side"]) * half, c.y - half)
	if anchor == null:
		return
	var grow: Transform2D = Transform2D(0.0, Vector2(PROP_SCALE, PROP_SCALE), 0.0, anchor) * Transform2D(0.0, -(anchor as Vector2))
	for i: int in range(slots.size()):
		var slot: Array = slots[i]
		for j: int in range(before[i], slot.size()):
			slot[j] = grow * (slot[j] as PackedVector2Array)
	# Spots for ambient life move with their props.
	if item["kind"] == &"drip" and not drip_spots.is_empty():
		drip_spots[drip_spots.size() - 1] = grow * drip_spots[drip_spots.size() - 1]
	if item["kind"] in [&"tuft", &"flower"] and not firefly_spots.is_empty():
		firefly_spots[firefly_spots.size() - 1] = grow * firefly_spots[firefly_spots.size() - 1]


func _sketch_item(item: Dictionary, c: Vector2, slots: Array, s: int) -> void:
	var v: Vector2i = item["cell"]
	var floor_y: float = c.y + half
	var ceil_y: float = c.y - half
	match item["kind"]:
		&"tuft":
			var x0: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.6
			var blades: int = 3 + int(_r(s, v, 11) * 4.0)
			for i: int in range(blades):
				var x: float = x0 + (float(i) - float(blades) * 0.5) * 5.0
				var tall: float = 12.0 + _r(s, v, 20 + i) * 16.0
				var lean: float = (_r(s, v, 30 + i) - 0.5) * 12.0
				var blade: PackedVector2Array = PackedVector2Array([Vector2(x - 2.4, floor_y + 2), Vector2(x + 2.4, floor_y + 2), Vector2(x + lean, floor_y - tall)])
				slots[7].append(blade)
				slots[6].append(blade)
			firefly_spots.append(Vector2(x0, floor_y - 30.0))
		&"flower":
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.5
			var tall: float = 34.0 + _r(s, v, 11) * 26.0
			var sway: float = (_r(s, v, 12) - 0.5) * 16.0
			var top: Vector2 = Vector2(x + sway, floor_y - tall)
			var stem: PackedVector2Array = PackedVector2Array([Vector2(x, floor_y + 2), Vector2(x + sway * 0.2, floor_y - tall * 0.4), Vector2(x + sway * 0.7, floor_y - tall * 0.8), top])
			slots[4].append_array(RisoDecor.strip(stem, 3.2, 2.0))
			var leaf_at: Vector2 = Vector2(x + sway * 0.2, floor_y - tall * 0.35)
			var leaf: PackedVector2Array = Transform2D(-0.6, leaf_at) * RisoShapes.almond(Vector2(7, 0), 8.0, 3.0, 8)
			slots[7].append(leaf)
			slots[6].append(leaf)
			# A three-petal cup of bare paper, faintly blue, with a dark heart.
			for k: int in range(3):
				var petal: PackedVector2Array = Transform2D(-0.55 + 0.55 * float(k), top) * RisoShapes.almond(Vector2(0, -7), 4.0, 8.0, 10)
				slots[8].append(petal)
				slots[9].append(petal)
			slots[10].append(RisoShapes.circle(top + Vector2(0, -2), 2.2, 8))
			firefly_spots.append(top + Vector2(0, -20))
		&"mushroom":
			var n: int = 1 + int(_r(s, v, 10) * 3.0)
			var x0: float = c.x + (_r(s, v, 11) - 0.5) * half * 0.5
			for i: int in range(n):
				var x: float = x0 + float(i) * 16.0 - float(n - 1) * 8.0
				var tall: float = 5.0 + _r(s, v, 20 + i) * 7.0
				var w: float = 16.0 + _r(s, v, 30 + i) * 10.0
				slots[8].append(RisoShapes.rrect(x - 2.8, floor_y - tall, 5.6, tall + 2.0, 2.4))
				var cap: PackedVector2Array = PackedVector2Array()
				for k: int in range(9):
					var a: float = PI + PI * float(k) / 8.0
					cap.append(Vector2(x, floor_y - tall) + Vector2(cos(a) * w * 0.5, sin(a) * w * 0.42))
				slots[11].append(cap)
				for k: int in range(2):
					slots[14].append(RisoShapes.circle(Vector2(x + (float(k) - 0.6) * w * 0.3, floor_y - tall - w * (0.16 + 0.06 * float(k))), 1.6, 6))
		&"stones":
			var x0: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.5
			for i: int in range(2 + int(_r(s, v, 11) * 2.0)):
				var w: float = 9.0 + _r(s, v, 20 + i) * 8.0
				var stone: PackedVector2Array = RisoShapes.ellipse(Vector2(x0 + float(i) * 10.0 - 8.0, floor_y - w * 0.3 - float(i % 2) * 5.0), w * 0.6, w * 0.38, 12)
				slots[12].append(stone)
				slots[13].append(stone)
		&"roots":
			for i: int in range(2 + int(_r(s, v, 10) * 3.0)):
				var x: float = c.x + (_r(s, v, 20 + i) - 0.5) * half * 0.8
				var long: float = 18.0 + _r(s, v, 30 + i) * 52.0
				var pts: PackedVector2Array = PackedVector2Array()
				for k: int in range(6):
					var f: float = float(k) / 5.0
					pts.append(Vector2(x + sin(f * 5.0 + float(i) * 2.0) * 4.0 * f, ceil_y - 2.0 + long * f))
				var root: Array[PackedVector2Array] = RisoDecor.strip(pts, 4.5, 1.2)
				slots[4].append_array(root)
				slots[5].append_array(root)
		&"stalactite":
			for i: int in range(1 + int(_r(s, v, 10) * 2.0)):
				var x: float = c.x + (_r(s, v, 20 + i) - 0.5) * half * 0.6
				var w: float = 10.0 + _r(s, v, 30 + i) * 10.0
				var long: float = 18.0 + _r(s, v, 40 + i) * 28.0
				var spike: PackedVector2Array = PackedVector2Array([Vector2(x - w * 0.5, ceil_y - 2), Vector2(x + w * 0.5, ceil_y - 2), Vector2(x + w * 0.1, ceil_y + long)])
				slots[4].append(spike)
				slots[5].append(PackedVector2Array([Vector2(x, ceil_y - 2), Vector2(x + w * 0.5, ceil_y - 2), Vector2(x + w * 0.1, ceil_y + long)]))
		&"drip":
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.5
			slots[4].append(RisoShapes.smooth(PackedVector2Array([Vector2(x - 6, ceil_y - 2), Vector2(x + 6, ceil_y - 2), Vector2(x + 2, ceil_y + 8), Vector2(x, ceil_y + 12), Vector2(x - 2, ceil_y + 8)])))
			drip_spots.append(Vector2(x, ceil_y + 12))
			var fall: int = 0
			while fall < 6 and not _solid.has(v + Vector2i(0, fall + 1)):
				fall += 1
			drip_ends.append(c.y + half + float(fall) * half * 2.0 - 2.0)
		&"vine":
			var side: float = float(item["side"])
			var wall_x: float = c.x - side * half
			var long: float = 32.0 + _r(s, v, 10) * 44.0
			var pts: PackedVector2Array = PackedVector2Array()
			for k: int in range(8):
				var f: float = float(k) / 7.0
				pts.append(Vector2(wall_x + side * (3.0 + sin(f * 6.0) * 3.0), ceil_y + 4.0 + long * f))
			slots[4].append_array(RisoDecor.strip(pts, 3.2, 1.6))
			for k: int in range(1, 8):
				var flip: float = side * (1.0 if k % 2 == 0 else -0.5)
				var leaf: PackedVector2Array = Transform2D(flip * 0.9, pts[k]) * RisoShapes.almond(Vector2(flip * 5.0, 0), 5.5, 2.4, 8)
				slots[7].append(leaf)
				slots[6].append(leaf)
