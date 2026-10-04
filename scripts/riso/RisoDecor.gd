extends Node2D
class_name RisoDecor
## Decor for the surface grotto: small printed props that make the rock feel lived in, never
## part of the gameplay.
## - Floors: grass tufts, moon-flowers, mushrooms, stones.
## - Ceilings: hanging roots, stalactites, ink drips (RisoAmbient drops ink from them).
## - Walls: vines down the rock face.
## A cemetery (NextWorldDef.archetype) has its own: headstones (rounded, gothic, cross-topped,
## broken, flat ledgers), crosses, obelisks, urns, angels, grave flowers, bare trees and dry grass
## on its floors, cobwebs and roots under its ceilings, ivy on its walls.
## Behind them, in a lighter ink on a layer of their own, fences run along stretches of floor
## (fence_runs): wooden pickets in the garden, iron railings between stone posts in a cemetery.
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
	[RisoPrint.BLUE, 0.8, false, false],    # 15 background fences
	[RisoPrint.NIGHT, 0.18, false, false],  # 16 their shade
]
## Slots printed on the background layer, behind the rest of the decor.
const BACK_SLOTS: Array[int] = [15, 16]
const KNOCK_ALL: Array[int] = [RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE]
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
const SWAY_KINDS: Array[StringName] = [&"tuft", &"roots", &"vine"]
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
static func plan(solid: Dictionary, occupied: Dictionary, level_seed: int, bounds: Rect2i, archetype: StringName = &"garden") -> Array[Dictionary]:
	if archetype == &"cemetery":
		var graves: Array[Dictionary] = plan_cemetery(solid, occupied, level_seed, bounds)
		for run: Dictionary in fence_runs(solid, occupied, level_seed, bounds):
			run["iron"] = true
			graves.append(run)
		return graves
	var out: Array[Dictionary] = fence_runs(solid, occupied, level_seed, bounds)
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
			if r < 0.42:
				kind = &"tuft"
			elif r < 0.58:
				kind = &"mushroom"
			elif r < 0.63:
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


## Background fences: along stretches of floor (open cells over rock, side by side on one row, none
## holding a structure) at least FENCE_MIN long, about half of them fenced, in lengths of up to
## FENCE_MAX cells with a gap between. Each is {kind: fence_run, cell: its first cell, cells: its
## cells, base: the rock under the first}.
const FENCE_MIN: int = 3
const FENCE_MAX: int = 6


static func fence_runs(solid: Dictionary, occupied: Dictionary, level_seed: int, bounds: Rect2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# On rock inside the level (not its outer walls).
	var floor_at: Callable = func(v: Vector2i) -> bool: return bounds.has_point(v + Vector2i.DOWN) and not solid.has(v) and not occupied.has(v) and solid.has(v + Vector2i.DOWN)
	for y: int in range(bounds.position.y, bounds.end.y):
		var x: int = bounds.position.x
		while x < bounds.end.x:
			if not floor_at.call(Vector2i(x, y)):
				x += 1
				continue
			var from: int = x
			while x < bounds.end.x and floor_at.call(Vector2i(x, y)):
				x += 1
			if x - from < FENCE_MIN or h(level_seed, Vector2i(from, y), 50) >= 0.5:
				continue
			# Cut into lengths, leaving a cell's gap between them.
			var at: int = from + int(h(level_seed, Vector2i(from, y), 51) * 2.0)
			while x - at >= FENCE_MIN - 1:
				var long: int = mini(x - at, FENCE_MIN + int(h(level_seed, Vector2i(at, y), 52) * float(FENCE_MAX - FENCE_MIN + 1)))
				var cells: Array[Vector2i] = []
				for k: int in range(long):
					cells.append(Vector2i(at + k, y))
				out.append({"kind": &"fence_run", "cell": cells[0], "cells": cells, "base": cells[0] + Vector2i.DOWN})
				at += long + 1
	return out


## A cemetery's props (see plan).
static func plan_cemetery(solid: Dictionary, occupied: Dictionary, level_seed: int, bounds: Rect2i) -> Array[Dictionary]:
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
			var tall_room: bool = not solid.has(above + Vector2i.UP)
			var kind: StringName = &""
			if r < 0.2:
				kind = &"headstone"
			elif r < 0.26:
				kind = &"cross"
			elif r < 0.29 and tall_room:
				kind = &"obelisk"
			elif r < 0.32:
				kind = &"urn"
			elif r < 0.335 and tall_room:
				kind = &"angel"
			elif r < 0.36 and tall_room:
				kind = &"dead_tree"
			elif r < 0.41:
				kind = &"flowers"
			elif r < 0.6:
				kind = &"tuft"
			if kind != &"":
				out.append({"kind": kind, "cell": above, "base": v})
		if not solid.has(below) and not occupied.has(below):
			var r: float = h(level_seed, v, 2)
			var kind: StringName = &""
			if r < 0.14:
				kind = &"cobweb"
			elif r < 0.3:
				kind = &"roots"
			if kind != &"":
				out.append({"kind": kind, "cell": below, "base": v})
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
			var open: Vector2i = v + side
			if solid.has(open) or occupied.has(open) or not solid.has(above):
				continue
			if h(level_seed, v, 3 + side.x) < 0.08:
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
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i(2, 0), Vector2i(3, 0)]:
				occupied[c + d] = true
	var level_seed: int = MapInfo.level_seed(info.coord.x, info.coord.y)
	items = RisoDecor.plan(solid, occupied, level_seed, Rect2i(Vector2i.ZERO, info.world.size), info.here.archetype)
	# Nothing grows in some side worlds (NextWorldDef.grows).
	if not info.here.grows():
		items.clear()
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
			var tall: float = 1.0
			for part: Array in parts:
				for q: Vector2 in part[1]:
					tall = maxf(tall, absf(q.y - (at.y + (-half if hang else half))))
			item["tall"] = tall
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
		# The background fences on a canvas of their own, behind the rest.
		for back: bool in [true, false]:
			var canvas: InkCanvas = InkCanvas.new()
			add_child(canvas)
			canvas.z_index = -1 if back else 0
			canvases.append(canvas)
			canvas.begin()
			_print_slots(canvas, chunks[key], back)
			canvas.finish()


func _empty_slots() -> Array:
	var slots: Array = []
	for i: int in range(SLOTS.size()):
		var polys: Array[PackedVector2Array] = []
		slots.append(polys)
	return slots


## Print the slots into `canvas`: the background ones (BACK_SLOTS) when `back`, else the rest.
func _print_slots(canvas: InkCanvas, slots: Array, back: bool = false) -> void:
	for i: int in range(SLOTS.size()):
		var polys: Array[PackedVector2Array] = slots[i]
		if polys.is_empty() or (i in BACK_SLOTS) != back:
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
			var close: float = clampf(1.0 - absf(dx) / 130.0, 0.0, 1.0) * clampf(1.0 - absf(player.global_position.y - reach_y) / 130.0, 0.0, 1.0)
			if close > 0.0:
				# Leans away from the wizard, and is swept along the way they are going.
				var away: float = signf(dx) * (1.0 if not hang else -1.0)
				var sweep: float = clampf(player.velocity.x / 300.0, -1.0, 1.0) * (1.0 if not hang else -1.0)
				target = clampf(away * 0.16 + sweep * 0.2, -0.3, 0.3) * sqrt(close)
		var a: float = item["a"]
		var v: float = item["v"]
		# A light spring: brushed aside, it eases back with a small wobble.
		v += ((target - a) * 30.0 - v * 6.5) * dt
		a += v * dt
		item["a"] = a
		item["v"] = v
		var bend: float = a + sin(t * 1.3 + anchor.x * 0.013) * 0.03
		var tall: float = item["tall"]
		# Bend, don't skew: each point turns about the root by an angle that grows along the
		# plant, so stems curve and keep their length, and heads tilt with their tips.
		var turn: float = -bend if hang else bend
		for part: Array in item["parts"]:
			var poly: PackedVector2Array = part[1]
			var bent: PackedVector2Array = PackedVector2Array()
			bent.resize(poly.size())
			for k: int in range(poly.size()):
				var p: Vector2 = poly[k]
				var f: float = clampf(absf(p.y - anchor.y) / tall, 0.0, 1.0)
				bent[k] = anchor + (p - anchor).rotated(turn * f * (2.0 - f))
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
		&"tuft", &"mushroom", &"stones", &"headstone", &"cross", &"fence", &"dead_tree", &"obelisk", &"urn", &"angel", &"flowers":
			anchor = Vector2(c.x, c.y + half)
		&"roots", &"stalactite", &"drip", &"cobweb":
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
	if item["kind"] == &"tuft" and not firefly_spots.is_empty():
		firefly_spots[firefly_spots.size() - 1] = grow * firefly_spots[firefly_spots.size() - 1]


func _sketch_item(item: Dictionary, c: Vector2, slots: Array, s: int) -> void:
	var v: Vector2i = item["cell"]
	var floor_y: float = c.y + half
	var ceil_y: float = c.y - half
	match item["kind"]:
		&"tuft":
			# Three kinds of grass, picked per cell: a clump, tall reeds with seed heads, or a low
			# fuzz of many short blades.
			var x0: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.6
			var style: int = int(_r(s, v, 12) * 3.0)
			var blades: int = [3 + int(_r(s, v, 11) * 4.0), 2 + int(_r(s, v, 11) * 3.0), 6 + int(_r(s, v, 11) * 4.0)][style]
			var spread: float = [5.0, 6.5, 3.2][style]
			for i: int in range(blades):
				var x: float = x0 + (float(i) - float(blades) * 0.5) * spread
				var tall: float = [12.0 + _r(s, v, 20 + i) * 16.0, 26.0 + _r(s, v, 20 + i) * 18.0, 5.0 + _r(s, v, 20 + i) * 6.0][style]
				var lean: float = (_r(s, v, 30 + i) - 0.5) * [12.0, 8.0, 7.0][style]
				var base: float = [2.4, 1.5, 1.8][style]
				var blade: PackedVector2Array = PackedVector2Array([Vector2(x - base, floor_y + 2), Vector2(x + base, floor_y + 2), Vector2(x + lean, floor_y - tall)])
				slots[7].append(blade)
				slots[6].append(blade)
				if style == 1 and _r(s, v, 40 + i) < 0.6:
					var head: PackedVector2Array = RisoShapes.almond(Vector2(x + lean, floor_y - tall - 3.0), 1.8, 4.0, 8)
					slots[4].append(head)
			firefly_spots.append(Vector2(x0, floor_y - 30.0))
		&"mushroom":
			# Clusters of one to four, each a dome, a cone or a flat parasol, sized and tilted
			# per mushroom; domes and parasols are spotted.
			var n: int = 1 + int(_r(s, v, 10) * 4.0)
			var x0: float = c.x + (_r(s, v, 11) - 0.5) * half * 0.5
			for i: int in range(n):
				var x: float = x0 + float(i) * 14.0 - float(n - 1) * 7.0
				var style: int = int(_r(s, v, 50 + i) * 3.0)
				var tall: float = [5.0 + _r(s, v, 20 + i) * 7.0, 6.0 + _r(s, v, 20 + i) * 8.0, 11.0 + _r(s, v, 20 + i) * 9.0][style]
				var w: float = [16.0 + _r(s, v, 30 + i) * 10.0, 11.0 + _r(s, v, 30 + i) * 6.0, 20.0 + _r(s, v, 30 + i) * 10.0][style]
				var tilt: Transform2D = Transform2D((_r(s, v, 60 + i) - 0.5) * 0.4, Vector2(x, floor_y)) * Transform2D(0.0, Vector2(-x, -floor_y))
				slots[8].append(tilt * RisoShapes.rrect(x - 2.6, floor_y - tall, 5.2, tall + 2.0, 2.2))
				var top: Vector2 = Vector2(x, floor_y - tall)
				var cap: PackedVector2Array = PackedVector2Array()
				match style:
					0:
						for k: int in range(9):
							var a: float = PI + PI * float(k) / 8.0
							cap.append(top + Vector2(cos(a) * w * 0.5, sin(a) * w * 0.42))
					1:
						cap = RisoShapes.smooth(PackedVector2Array([top + Vector2(-w * 0.5, 1), top + Vector2(-w * 0.18, -w * 0.45), top + Vector2(0, -w * 0.85), top + Vector2(w * 0.18, -w * 0.45), top + Vector2(w * 0.5, 1)]))
					2:
						cap = RisoShapes.smooth(PackedVector2Array([top + Vector2(-w * 0.5, 1.5), top + Vector2(-w * 0.32, -w * 0.16), top + Vector2(w * 0.32, -w * 0.16), top + Vector2(w * 0.5, 1.5)]))
				slots[11].append(tilt * cap)
				if style != 1:
					var high: float = 0.16 if style == 0 else 0.07
					for k: int in range(2 + (1 if style == 2 else 0)):
						slots[14].append(tilt * RisoShapes.circle(top + Vector2((float(k) - 0.6) * w * 0.28, -w * (high + 0.05 * float(k % 2))), 1.6, 6))
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
		&"headstone":
			# Pale stone (bare paper, shaded down one side), leaning a little, in one of five shapes:
			# rounded, gothic (pointed), cross-topped, broken (its top snapped off at a slant), or a
			# flat ledger lying on the grave with a low stone at its head. Marks cut in blue.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.5
			var w: float = 18.0 + _r(s, v, 11) * 8.0
			var tall: float = 26.0 + _r(s, v, 12) * 14.0
			var tilt: Transform2D = Transform2D((_r(s, v, 13) - 0.5) * 0.3, Vector2(x, floor_y)) * Transform2D(0.0, Vector2(-x, -floor_y))
			var style: int = int(_r(s, v, 14) * 5.0)
			var stone: PackedVector2Array
			match style:
				1:
					stone = PackedVector2Array([Vector2(x - w * 0.5, floor_y + 2.0), Vector2(x - w * 0.5, floor_y - tall * 0.65), Vector2(x, floor_y - tall), Vector2(x + w * 0.5, floor_y - tall * 0.65), Vector2(x + w * 0.5, floor_y + 2.0)])
				2:
					stone = RisoShapes.rrect(x - w * 0.5, floor_y - tall * 0.7, w, tall * 0.7 + 2.0, 2.0)
					slots[8].append(tilt * RisoShapes.rrect(x - 2.6, floor_y - tall - 4.0, 5.2, tall * 0.4, 1.0))
					slots[8].append(tilt * RisoShapes.rrect(x - 7.0, floor_y - tall + 2.0, 14.0, 4.4, 1.0))
				3:
					var cut: float = (_r(s, v, 15) - 0.5) * 10.0
					stone = PackedVector2Array([Vector2(x - w * 0.5, floor_y + 2.0), Vector2(x - w * 0.5, floor_y - tall * 0.6 - cut), Vector2(x - w * 0.1, floor_y - tall * 0.5), Vector2(x + w * 0.15, floor_y - tall * 0.66), Vector2(x + w * 0.5, floor_y - tall * 0.55 + cut), Vector2(x + w * 0.5, floor_y + 2.0)])
				4:
					stone = RisoShapes.rrect(x - w * 0.7, floor_y - 6.0, w * 1.4, 8.0, 2.0)
					slots[8].append(tilt * RisoShapes.arch(x - w * 0.85, floor_y - tall * 0.55, w * 0.45, tall * 0.55 + 2.0, 8))
				_:
					stone = RisoShapes.arch(x - w * 0.5, floor_y - tall, w, tall + 2.0, 10)
			slots[8].append(tilt * stone)
			slots[13].append(tilt * Transform2D(0.0, Vector2(0.5, 1.0), 0.0, Vector2(x * 0.5 + w * 0.25, 0.0)) * stone)
			if style != 4 and style != 2:
				slots[4].append(tilt * RisoShapes.rrect(x - 1.1, floor_y - tall * 0.62, 2.2, w * 0.6, 0.6))
				slots[4].append(tilt * RisoShapes.rrect(x - w * 0.2, floor_y - tall * 0.62 + w * 0.15, w * 0.4, 2.2, 0.6))
		&"obelisk":
			# A tall tapering needle of stone on a base, its tip a little pyramid.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.4
			var tall: float = 58.0 + _r(s, v, 11) * 22.0
			slots[8].append(RisoShapes.rrect(x - 11.0, floor_y - 9.0, 22.0, 11.0, 2.0))
			var shaft: PackedVector2Array = PackedVector2Array([Vector2(x - 7.0, floor_y - 8.0), Vector2(x - 4.5, floor_y - tall), Vector2(x, floor_y - tall - 8.0), Vector2(x + 4.5, floor_y - tall), Vector2(x + 7.0, floor_y - 8.0)])
			slots[8].append(shaft)
			slots[13].append(PackedVector2Array([Vector2(x, floor_y - 8.0), Vector2(x, floor_y - tall - 8.0), Vector2(x + 4.5, floor_y - tall), Vector2(x + 7.0, floor_y - 8.0)]))
		&"urn":
			# An urn on a stone plinth.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.5
			slots[8].append(RisoShapes.rrect(x - 9.0, floor_y - 18.0, 18.0, 20.0, 1.5))
			slots[13].append(RisoShapes.rrect(x, floor_y - 18.0, 9.0, 20.0, 1.5))
			var urn: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([Vector2(x - 4.0, floor_y - 18.0), Vector2(x - 9.0, floor_y - 24.0), Vector2(x - 8.0, floor_y - 33.0), Vector2(x - 5.0, floor_y - 37.0), Vector2(x + 5.0, floor_y - 37.0), Vector2(x + 8.0, floor_y - 33.0), Vector2(x + 9.0, floor_y - 24.0), Vector2(x + 4.0, floor_y - 18.0)]), 3)
			slots[8].append(urn)
			slots[13].append(RisoShapes.rrect(x - 7.0, floor_y - 39.0, 14.0, 2.6, 1.0))
		&"angel":
			# A stone angel on a plinth, head bowed, wings folded up behind.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.3
			var face: float = 1.0 if _r(s, v, 11) < 0.5 else -1.0
			slots[8].append(RisoShapes.rrect(x - 12.0, floor_y - 12.0, 24.0, 14.0, 2.0))
			var robe: PackedVector2Array = PackedVector2Array([Vector2(x - 9.0, floor_y - 12.0), Vector2(x - 5.0, floor_y - 44.0), Vector2(x + 5.0, floor_y - 44.0), Vector2(x + 9.0, floor_y - 12.0)])
			var wing: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([Vector2(x - face * 2.0, floor_y - 42.0), Vector2(x - face * 16.0, floor_y - 58.0), Vector2(x - face * 13.0, floor_y - 38.0), Vector2(x - face * 8.0, floor_y - 26.0)]), 3)
			slots[8].append(wing)
			slots[13].append(wing)
			slots[8].append(robe)
			slots[8].append(RisoShapes.circle(Vector2(x + face * 2.0, floor_y - 49.0), 5.0, 14))
			slots[13].append(PackedVector2Array([Vector2(x, floor_y - 12.0), Vector2(x, floor_y - 44.0), Vector2(x + 5.0, floor_y - 44.0), Vector2(x + 9.0, floor_y - 12.0)]))
		&"flowers":
			# Grave flowers: a few stems, their heads drooping, pale petals.
			var x0: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.6
			for i: int in range(3 + int(_r(s, v, 11) * 3.0)):
				var x: float = x0 + (float(i) - 2.0) * 4.5
				var tall: float = 10.0 + _r(s, v, 20 + i) * 9.0
				var droop: float = (2.0 + _r(s, v, 30 + i) * 4.0) * (1.0 if i % 2 == 0 else -1.0)
				var stem: PackedVector2Array = PackedVector2Array([Vector2(x, floor_y + 1.0), Vector2(x + droop * 0.3, floor_y - tall), Vector2(x + droop, floor_y - tall + 3.0)])
				slots[4].append_array(RisoDecor.strip(stem, 1.6, 1.0))
				slots[8].append(RisoShapes.almond(Vector2(x + droop, floor_y - tall + 5.0), 2.6, 3.4, 8))
		&"fence_run":
			# Behind the rest: a fence the length of the run (BACK_SLOTS), drawn at full size (it is
			# not grown about one end like the other props).
			var k: float = PROP_SCALE
			var cells: Array = item["cells"]
			var x0: float = c.x - half
			var x1: float = c.x - half + float(cells.size()) * half * 2.0
			if not item.has("iron"):
				# Wooden pickets, rounded, over two rails; now and then one lost or leaning.
				var n: int = int((x1 - x0) / (10.0 * k))
				for i: int in range(n):
					if _r(s, v, 60 + i) < 0.07:
						continue
					var x: float = x0 + (5.0 + float(i) * 10.0) * k
					var tall: float = (26.0 + (_r(s, v, 100 + i) - 0.5) * 4.0) * k
					var lean: Transform2D = Transform2D((_r(s, v, 140 + i) - 0.5) * 0.25 if _r(s, v, 180 + i) < 0.15 else 0.0, Vector2(x, floor_y)) * Transform2D(0.0, Vector2(-x, -floor_y))
					slots[15].append(lean * RisoShapes.arch(x - 3.2 * k, floor_y - tall, 6.4 * k, tall + 2.0, 6))
				for rail: float in [21.0, 9.0]:
					slots[15].append(RisoShapes.rrect(x0 + 2.0, floor_y - rail * k, x1 - x0 - 4.0, 3.4 * k, 1.2 * k))
				slots[16].append(RisoShapes.rrect(x0 + 2.0, floor_y - 9.0 * k, x1 - x0 - 4.0, 3.4 * k, 1.2 * k))
			else:
				# Iron railings, spear-tipped, between stone posts at each end and every few cells.
				var n: int = int((x1 - x0) / (8.0 * k))
				for i: int in range(n):
					var x: float = x0 + (4.0 + float(i) * 8.0) * k
					var tall: float = 30.0 * k
					slots[15].append(RisoShapes.rrect(x - 1.0 * k, floor_y - tall, 2.0 * k, tall + 2.0, 0.8 * k))
					slots[15].append(RisoShapes.tri(Vector2(x - 2.2 * k, floor_y - tall + 2.0), Vector2(x + 2.2 * k, floor_y - tall + 2.0), Vector2(x, floor_y - tall - 5.0 * k)))
				for rail: float in [7.0, 24.0]:
					slots[15].append(RisoShapes.rrect(x0, floor_y - rail * k, x1 - x0, 2.2 * k, 0.8 * k))
				var posts: Array[float] = [x0 + 3.0 * k, x1 - 3.0 * k]
				for j: int in range(1, cells.size()):
					if j % 3 == 0:
						posts.append(x0 + float(j) * half * 2.0)
				for px: float in posts:
					slots[15].append(RisoShapes.rrect(px - 4.5 * k, floor_y - 36.0 * k, 9.0 * k, 36.0 * k + 2.0, 1.5 * k))
					slots[15].append(RisoShapes.rrect(px - 6.0 * k, floor_y - 40.0 * k, 12.0 * k, 5.0 * k, 1.5 * k))
					slots[16].append(RisoShapes.rrect(px, floor_y - 36.0 * k, 4.5 * k, 36.0 * k + 2.0, 1.5 * k))
		&"cross":
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.6
			var tall: float = 26.0 + _r(s, v, 11) * 12.0
			var tilt: Transform2D = Transform2D((_r(s, v, 13) - 0.5) * 0.35, Vector2(x, floor_y)) * Transform2D(0.0, Vector2(-x, -floor_y))
			var cross: Array[PackedVector2Array] = [tilt * RisoShapes.rrect(x - 2.0, floor_y - tall, 4.0, tall + 2.0, 1.0), tilt * RisoShapes.rrect(x - 7.0, floor_y - tall * 0.78, 14.0, 4.0, 1.0)]
			slots[8].append_array(cross)
			slots[13].append(cross[0])
		&"fence":
			# Iron railings: bars with spear tips over two rails, a cell wide.
			var x0: float = c.x - half * 0.8
			for i: int in range(5):
				var x: float = x0 + float(i) * half * 0.4
				var tall: float = 22.0 + (3.0 if i % 2 == 0 else 0.0)
				slots[4].append(RisoShapes.rrect(x - 1.1, floor_y - tall, 2.2, tall + 2.0, 0.8))
				slots[4].append(RisoShapes.tri(Vector2(x - 2.4, floor_y - tall + 1.0), Vector2(x + 2.4, floor_y - tall + 1.0), Vector2(x, floor_y - tall - 5.0)))
			for rail_y: float in [floor_y - 6.0, floor_y - 17.0]:
				slots[4].append(RisoShapes.rrect(x0 - 2.0, rail_y, half * 1.6 + 4.0, 2.0, 0.8))
			slots[5].append(RisoShapes.rrect(x0 - 2.0, floor_y - 6.0, half * 1.6 + 4.0, 2.0, 0.8))
		&"dead_tree":
			# A bare tree: a crooked trunk forking into thin branches.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.4
			var tall: float = 50.0 + _r(s, v, 11) * 26.0
			var bend: float = (_r(s, v, 12) - 0.5) * 16.0
			var trunk: PackedVector2Array = PackedVector2Array()
			for k: int in range(6):
				var f: float = float(k) / 5.0
				trunk.append(Vector2(x + bend * f * f + sin(f * 4.0) * 2.0, floor_y + 2.0 - tall * f))
			slots[4].append_array(RisoDecor.strip(trunk, 7.0, 2.2))
			slots[5].append_array(RisoDecor.strip(trunk, 3.5, 1.0))
			for b: int in range(3 + int(_r(s, v, 13) * 3.0)):
				var f: float = 0.45 + 0.5 * _r(s, v, 20 + b)
				var from: Vector2 = Vector2(x + bend * f * f, floor_y - tall * f)
				var side: float = 1.0 if b % 2 == 0 else -1.0
				var long: float = 10.0 + _r(s, v, 30 + b) * 16.0
				var branch: PackedVector2Array = PackedVector2Array([from, from + Vector2(side * long * 0.6, -long * 0.5), from + Vector2(side * long, -long * 0.9)])
				slots[4].append_array(RisoDecor.strip(branch, 2.4, 0.8))
		&"cobweb":
			# A web strung under the rock: paper threads, spokes and two rings.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.6
			var top: Vector2 = Vector2(x, ceil_y - 1.0)
			var reach: float = 14.0 + _r(s, v, 11) * 10.0
			var ends: Array[Vector2] = []
			for k: int in range(5):
				var a: float = PI * (0.1 + 0.8 * float(k) / 4.0)
				ends.append(top + Vector2(cos(a), sin(a)) * reach)
			for e: Vector2 in ends:
				slots[8].append_array(RisoDecor.strip(PackedVector2Array([top, e]), 1.0, 0.6))
			for ring: float in [0.45, 0.8]:
				for k: int in range(4):
					slots[8].append_array(RisoDecor.strip(PackedVector2Array([top.lerp(ends[k], ring), top.lerp(ends[k + 1], ring)]), 0.8, 0.8))
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
